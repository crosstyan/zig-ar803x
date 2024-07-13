const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");
const bb = @import("bb/c.zig");
const bt = @import("bb/t.zig");
const UsbPack = @import("bb/usbpack.zig").UsbPack;
const ManagedUsbPack = @import("bb/usbpack.zig").ManagedUsbPack;
const utils = @import("utils.zig");
const common = @import("app_common.zig");
const usb = @cImport({
    @cInclude("libusb.h");
});
const network = @import("network");
const helper = @import("libusb_helper.zig");
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;

const AppError = common.AppError;
const BadEnum = common.BadEnum;
const ClosedError = common.ClosedError;

const LockedQueue = utils.LockedQueue;

const LibUsbError = helper.LibUsbError;
const Endpoint = helper.Endpoint;
const Direction = helper.Direction;
const TransferType = helper.TransferType;
const getEndpoints = helper.getEndpoints;
const printEndpoints = helper.printEndpoints;
const transferStatusFromInt = helper.transferStatusFromInt;
const dynStringDescriptorOr = helper.dynStringDescriptorOr;
const printStrDesc = helper.printStrDesc;
const usbSpeedToString = helper.usbSpeedToString;
const libusb_error_2_set = helper.libusb_error_2_set;

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;
const XXHASH_SEED: u32 = 0x0;
const USB_MAX_PORTS = 8;
const TRANSFER_BUF_SIZE = 2048;
const DEFAULT_THREAD_STACK_SIZE = 16 * 1024 * 1024;
const MAX_SERIAL_SIZE = 32;
const REFRESH_CONTAINER_DEFAULT_CAP = 4;

/// A naive implementation of the observer pattern for `UsbPack`
///
/// See also `UsbPack`
const PackObserverList = struct {
    pub const ObserverError = error{
        Existed,
        NotFound,
    };
    pub const OnDataFnPtr = *const fn (*PackObserverList, *const UsbPack, *Observer) void;
    pub const PredicateFnPtr = *const fn (*const UsbPack, ?*anyopaque) bool;
    pub const NullableDtorPtr = ?*const fn (*anyopaque) void;

    // Observer provider could use
    // reference counting in dtor
    const Observer = struct {
        predicate: PredicateFnPtr,
        /// the callback function SHOULD NOT block
        on_data: OnDataFnPtr,
        userdata: ?*anyopaque,
        dtor: NullableDtorPtr,

        /// hashing the pointer, don't ask me why it's useful
        pub fn xxhash(self: *const @This()) u32 {
            var h = std.hash.XxHash32.init(XXHASH_SEED);
            const predicate_addr = @intFromPtr(self.predicate);
            h.update(utils.anytype2Slice(&predicate_addr));
            const notify_addr = @intFromPtr(self.on_data);
            h.update(utils.anytype2Slice(&notify_addr));
            if (self.userdata) |ptr| {
                const ud = @intFromPtr(ptr);
                h.update(utils.anytype2Slice(&ud));
            }
            if (self.dtor) |dtor| {
                const dtor_addr = @intFromPtr(dtor);
                h.update(utils.anytype2Slice(&dtor_addr));
            }
            return h.final();
        }

        pub fn deinit(self: *@This()) void {
            if (self.dtor) |dtor| {
                if (self.userdata) |ptr| {
                    dtor(ptr);
                }
            }
        }
    };

    // ******** fields ********
    allocator: std.mem.Allocator,
    list: std.ArrayList(Observer),
    lock: RwLock = RwLock{},
    // ******** end fields ********

    const Self = @This();

    pub fn items(self: *const Self) []const Observer {
        return self.list.items;
    }

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .allocator = alloc,
            .list = std.ArrayList(Observer).init(alloc),
        };
    }

    /// subscribe an observable as an observer
    ///
    ///   - `predicate`: a function to determine whether the observer should be notified
    ///   - `on_data`: the callback function when the observer is notified
    ///   - `userdata`: closure
    ///   - `dtor`: destructor for the closure, optional
    pub fn subscribe(
        self: *@This(),
        predicate: PredicateFnPtr,
        on_data: OnDataFnPtr,
        userdata: ?*anyopaque,
        dtor: NullableDtorPtr,
    ) !void {
        const obs = Observer{
            .predicate = predicate,
            .on_data = on_data,
            .userdata = userdata,
            .dtor = dtor,
        };
        const h = obs.xxhash();

        {
            self.lock.lock();
            defer self.lock.unlock();
            for (self.list.items) |*o| {
                if (o.xxhash() == h) {
                    return ObserverError.Existed;
                }
            }
        }

        self.lock.lockShared();
        defer self.lock.unlockShared();
        try self.list.append(obs);
    }

    /// dispatch the packet to the observers
    pub fn update(self: *@This(), managed_pack: *const ManagedUsbPack) void {
        self.lock.lock();
        defer self.lock.unlock();

        var cnt: usize = 0;
        for (self.list.items) |*o| {
            if (o.predicate(&managed_pack.pack, o.userdata)) {
                o.on_data(self, &managed_pack.pack, o);
                cnt += 1;
            }
        }

        if (cnt == 0) {
            var lg = logz.warn()
                .int("reqid", managed_pack.pack.reqid)
                .int("sta", managed_pack.pack.sta)
                .string("what", "no observer is notified");
            if (managed_pack.pack.data()) |data| {
                lg = lg.int("len", data.len)
                    .fmt("content", "{s}", .{std.fmt.fmtSliceHexLower(data)});
            } else |_| {}
            lg.log();
        }
    }

    pub inline fn unsubscribe(self: *@This(), obs: *const Observer) ObserverError!void {
        return self.unsubscribeByHash(obs.xxhash());
    }

    /// unsubscribe an observer by hash
    pub fn unsubscribeByHash(self: *@This(), hash: u32) ObserverError!void {
        var idx: isize = -1;
        const len = self.list.items.len;

        // explicit no lock here
        for (self.list.items, 0..len) |*o, i| {
            const h = o.xxhash();
            if (h == hash) {
                idx = @intCast(i);
                break;
            }
        }
        if (idx == -1) {
            return ObserverError.NotFound;
        }

        self.lock.lockShared();
        var el = self.list.swapRemove(@intCast(idx));
        self.lock.unlockShared();
        el.deinit();
    }

    /// unsubscribe all observers
    pub fn unsubscribeAll(self: *@This()) void {
        self.lock.lock();
        defer self.lock.unlock();
        for (self.list.items) |*o| {
            o.deinit();
        }
        self.list.deinit();
        self.list = std.ArrayList(Observer).init(self.allocator);
    }

    pub fn deinit(self: *@This()) void {
        for (self.list.items) |*o| {
            o.deinit();
        }
        self.list.deinit();
    }
};

/// DeviceDesc is a intermediate struct for device information.
/// Note that it's different from `libusb_device_descriptor`
/// and it could construct a `DeviceContext` from it.
const DeviceDesc = struct {
    const Self = @This();
    dev: *usb.libusb_device,
    vid: u16,
    pid: u16,
    bus: u8,
    port: u8,
    _ports_buf: [USB_MAX_PORTS]u8,
    _ports_len: usize,

    pub inline fn ports(self: *const Self) []const u8 {
        return self._ports_buf[0..self._ports_len];
    }

    pub fn fromDevice(dev: *usb.libusb_device) AppError!@This() {
        var desc: usb.libusb_device_descriptor = undefined;
        const err = usb.libusb_get_device_descriptor(dev, &desc);
        if (err != 0) {
            return AppError.BadDescriptor;
        }
        var ret = @This(){
            .dev = dev,
            .vid = desc.idVendor,
            .pid = desc.idProduct,
            .bus = usb.libusb_get_bus_number(dev),
            .port = usb.libusb_get_port_number(dev),
            ._ports_buf = undefined,
            ._ports_len = 0,
        };
        const sz = usb.libusb_get_port_numbers(dev, &ret._ports_buf, USB_MAX_PORTS);
        if (sz < 0) {
            return AppError.BadPortNumbers;
        }
        ret._ports_len = @intCast(sz);

        return ret;
    }

    /// the same as calling `DeviceContext.from_device_desc`
    pub inline fn toContext(self: @This(), alloc: std.mem.Allocator) LibUsbError!DeviceContext {
        return DeviceContext.fromDeviceDesc(alloc, self);
    }

    pub inline fn withLogger(self: *const @This(), logger: logz.Logger) logz.Logger {
        return logger
            .fmt("vid", "0x{x:0>4}", .{self.vid})
            .fmt("pid", "0x{x:0>4}", .{self.pid})
            .int("bus", self.bus)
            .int("port", self.port);
    }

    /// hash the device by bus, port, and ports
    pub fn xxhash(self: *const @This()) u32 {
        var h = std.hash.XxHash32.init(XXHASH_SEED);
        h.update(utils.anytype2Slice(&self.bus));
        h.update(utils.anytype2Slice(&self.port));
        h.update(self.ports());
        return h.final();
    }
};

/// the essential part of the USB device.
/// you could retrieve everything else from this
/// with libusb API
const DeviceHandles = struct {
    dev: *usb.libusb_device,
    hdl: *usb.libusb_device_handle,
    desc: usb.libusb_device_descriptor,

    const Self = @This();
    pub fn deinit(self: *Self) void {
        usb.libusb_close(self.hdl);
    }
};

/// Select every possible slot (14 slot?).
/// Anyway it's a magic number.
///
/// `0b0011_1111_1111_1111`
const SLOT_BIT_MAP_MAX = 0x3fff;
const is_windows = builtin.os.tag == .windows;

const DeviceGPA = std.heap.GeneralPurposeAllocator(.{
    .thread_safe = true,
});

const UsbPackQueue = LockedQueue(ManagedUsbPack, 8);

const DeviceContext = struct {
    /// Transfer is a wrapper of `libusb_transfer`
    /// but with a closure and a closure destructor
    const Transfer = struct {
        self: *usb.libusb_transfer,
        buf: [TRANSFER_BUF_SIZE]u8 = undefined,

        /// lock when `libusb_submit_transfer` is called.
        /// callback SHOULD be responsible for unlocking it.
        ///
        /// This mutex is mainly used in TX transfer.
        /// For RX transfer, the event loop is always polling and
        /// the transfer will be restarted after the callback is called.
        lk: RwLock = RwLock{},

        /// `user_data` in `libusb_transfer`
        _closure: ?*anyopaque = null,
        _closure_dtor: ?*const fn (*anyopaque) void = null,

        /// ONLY used in RX transfer
        pub inline fn written(self: *@This()) []const u8 {
            return self.buf[0..@intCast(self.self.actual_length)];
        }

        pub inline fn setCallback(self: *@This(), cb: *anyopaque, destructor: *const fn (*anyopaque) void) void {
            if (self._closure_dtor) |free| {
                if (self._closure) |ptr| {
                    free(ptr);
                }
            }
            self._closure = cb;
            self._closure_dtor = destructor;
        }

        pub fn deinit(self: *@This()) void {
            if (self._closure_dtor) |free| {
                if (self._closure) |ptr| {
                    free(ptr);
                }
            }
            usb.libusb_free_transfer(self.self);
        }
    };

    /// Artosyn specific context.
    /// like network, transfer, etc.
    const ArtoContext = struct {
        tx_transfer: Transfer,
        rx_transfer: Transfer,
        /// Note that the consumer should be responsible for
        /// RELEASING the packet after consuming it.
        rx_queue: UsbPackQueue,

        /// initialized in `initThreads`
        tx_thread: std.Thread,
        /// initialized in `initThreads`
        rx_thread: std.Thread,
        /// initialized in `initThreads`
        ///
        /// `rx_observable` will dispatch the packet to the observers,
        /// in rx thread
        ///
        /// Note that I'd use `subject` and `observable` interchangeably
        /// here, although in ReactiveX, they are different.
        ///
        /// See also
        ///   - https://rxjs.dev/guide/observable
        ///   - https://rxjs.dev/guide/subject
        rx_observable: PackObserverList,

        pub fn deinit(self: *@This()) void {
            self.tx_transfer.deinit();
            self.rx_transfer.deinit();
            self.rx_queue.deinit();
            self.rx_observable.deinit();
            self.tx_thread.join();
            self.rx_thread.join();
        }
    };

    const Self = @This();

    // ****** fields ******
    _has_deinit: std.atomic.Value(bool),
    gpa: DeviceGPA,
    core: DeviceHandles,
    bus: u8,
    port: u8,
    /// managed by `alloc`
    endpoints: []Endpoint,
    arto: ArtoContext,

    _ports_buf: [USB_MAX_PORTS]u8 = undefined,
    _ports_len: usize = 0,

    _serial_buf: [MAX_SERIAL_SIZE]u8 = undefined,
    _serial_len: usize = 0,
    // ****** end of fields ******

    pub inline fn ports(self: *const Self) []const u8 {
        return self._ports_buf[0..self._ports_len];
    }

    pub inline fn serial(self: *const Self) []const u8 {
        return self._serial_buf[0..self._serial_len];
    }

    pub inline fn allocator(self: *Self) std.mem.Allocator {
        return self.gpa.allocator();
    }

    pub inline fn dev(self: *const Self) *const usb.libusb_device {
        return self.core.dev;
    }

    pub inline fn mutDev(self: *Self) *usb.libusb_device {
        return self.core.dev;
    }

    pub inline fn hdl(self: *const Self) *const usb.libusb_device_handle {
        return self.core.hdl;
    }

    pub inline fn mutHdl(self: *Self) *usb.libusb_device_handle {
        return self.core.hdl;
    }

    pub inline fn desc(self: *const Self) *const usb.libusb_device_descriptor {
        return &self.core.desc;
    }

    pub inline fn hasDeinit(self: *const Self) bool {
        return self._has_deinit.load(std.builtin.AtomicOrder.unordered);
    }

    /// See `DeviceDesc`
    pub fn fromDeviceDesc(alloc: std.mem.Allocator, d: DeviceDesc) LibUsbError!@This() {
        var ret: c_int = undefined;
        var l_hdl: ?*usb.libusb_device_handle = null;
        // Internally, this function adds a reference
        ret = usb.libusb_open(d.dev, &l_hdl);
        if (ret != 0 or l_hdl == null) {
            const e = libusb_error_2_set(ret);
            d.withLogger(logz.err().string("err", "failed to open device").err(e)).log();
            return e;
        }
        var l_desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(d.dev, &l_desc);
        if (ret != 0) {
            const e = libusb_error_2_set(ret);
            d.withLogger(logz.err().err(e)).string("err", "failed to get device descriptor").log();
            return e;
        }

        const sn = dynStringDescriptorOr(alloc, l_hdl.?, l_desc.iSerialNumber, "");
        defer alloc.free(sn);

        var gpa = DeviceGPA{};
        const eps = getEndpoints(gpa.allocator(), d.dev, &l_desc);
        var dc = DeviceContext{
            ._has_deinit = std.atomic.Value(bool).init(true),
            .gpa = gpa,
            .core = DeviceHandles{
                .dev = d.dev,
                .hdl = l_hdl.?,
                .desc = l_desc,
            },
            .bus = d.bus,
            .port = d.port,
            ._ports_buf = d._ports_buf,
            ._ports_len = d._ports_len,
            .endpoints = eps,
            .arto = undefined,
        };

        if (sn.len > MAX_SERIAL_SIZE) {
            std.debug.panic("unexpected serial number {s} (len={d}, max={d})", .{ sn, sn.len, MAX_SERIAL_SIZE });
        }
        @memcpy(dc._serial_buf[0..sn.len], sn);
        dc._serial_len = sn.len;

        const tx_transfer = usb.libusb_alloc_transfer(0);
        const rx_transfer = usb.libusb_alloc_transfer(0);
        if (tx_transfer == null or rx_transfer == null) {
            std.debug.panic("device at bus {} port {} failed to allocate transfer, might be OOM", .{ d.bus, d.port });
        }
        dc.arto.tx_transfer = Transfer{
            .self = tx_transfer,
        };
        dc.arto.rx_transfer = Transfer{
            .self = rx_transfer,
        };
        // somehow the `rx_queue` is not happy with allocated with allocator in
        // the `DeviceContext`, which would cause a deadlock.
        // Interestingly, the deadlock is from the internal of GPA, needs to be
        // investigated further.
        dc.arto.rx_queue = UsbPackQueue.init(alloc);
        return dc;
    }

    pub fn deinit(self: *Self) void {
        self._has_deinit.store(true, std.builtin.AtomicOrder.unordered);
        self.core.deinit();
        self.allocator().free(self.endpoints);
        self.arto.deinit();
        const chk = self.gpa.deinit();
        if (chk != .ok) {
            std.debug.print("GPA thinks there are memory leaks when destroying device bus {} port {}\n", .{ self.bus, self.port });
        }
    }

    /// attach the device information to the logger
    pub inline fn withLogger(self: *const Self, logger: logz.Logger) logz.Logger {
        const s = self.serial();
        if (s.len != 0) {
            return logger
                .string("serial_number", s)
                .int("bus", self.bus)
                .int("port", self.port);
        } else {
            return logger
                .int("bus", self.bus)
                .int("port", self.port);
        }
    }

    pub inline fn withSrcLogger(self: *const Self, logger: logz.Logger, src: std.builtin.SourceLocation) logz.Logger {
        var lg = self.withLogger(logger);
        lg = utils.logWithSrc(lg, src);
        return lg;
    }

    /// hash the device by bus, port, and ports
    pub fn xxhash(self: *const Self) u32 {
        var h = std.hash.XxHash32.init(XXHASH_SEED);
        h.update(utils.anytype2Slice(&self.bus));
        h.update(utils.anytype2Slice(&self.port));
        h.update(self.ports());
        return h.final();
    }

    fn initTransferTx(self: *@This(), ep: *Endpoint) void {
        const alloc = self.allocator();
        var cb = alloc.create(TransferCallback) catch @panic("OOM");
        var transfer: *Transfer = &self.arto.tx_transfer;
        cb.alloc = alloc;
        cb.dev = self;
        cb.transfer = transfer;
        cb.endpoint = ep.*;
        usb.libusb_fill_bulk_transfer(
            transfer.self,
            self.mutHdl(),
            ep.addr,
            &transfer.buf,
            @intCast(transfer.buf.len),
            TransferCallback.tx,
            cb,
            100,
        );
        transfer.setCallback(cb, TransferCallback.dtorPtrTypeErased());
    }

    pub const TransmitError = error{
        Overflow,
        Busy,
    };

    /// transmit the data to tx endpoint
    ///
    /// `init_transfer_tx` should be called before this
    /// and the event loop should have started (you can't call this in the event
    /// loop thread)
    ///
    /// Note that the data will be copy to the internal buffer, and will return
    /// `TransmitError.Overflow` if the data is too large. (See `TRANSFER_BUF_SIZE`)
    ///
    /// use `arto.ctrl_queue` to receive the data coming from the device
    pub fn transmit(self: *@This(), data: []const u8) !void {
        if (self.hasDeinit()) {
            return ClosedError.Closed;
        }
        const transfer = &self.arto.tx_transfer;
        const ok = transfer.lk.tryLockShared();
        if (!ok) {
            return TransmitError.Busy;
        }
        if (data.len > transfer.buf.len) {
            return TransmitError.Overflow;
        }
        const target_slice = transfer.buf[0..data.len];
        @memcpy(target_slice, data);
        transfer.self.length = @intCast(data.len);
        const ret = usb.libusb_submit_transfer(transfer.self);
        if (ret != 0) {
            return libusb_error_2_set(ret);
        }
        var lg = utils.logWithSrc(self.withLogger(logz.debug()), @src());
        lg.string("what", "submitted transmit").log();
    }

    /// receive message from the IN endpoint (RX transfer)
    ///
    /// Note that the consumer is responsible for freeing the memory
    /// by calling `deinit` after receiving a packet.
    ///
    /// It's recommended to subscribe the observer to the `arto.obs_queue`, instead of
    /// calling this function directly.
    inline fn unsafeBlockReceive(self: *@This()) ClosedError!ManagedUsbPack {
        if (self.hasDeinit()) {
            return ClosedError.Closed;
        }
        return self.arto.rx_queue.dequeue();
    }

    fn initTransferRx(self: *DeviceContext, ep: *Endpoint) void {
        var ret: c_int = undefined;
        const l_alloc = self.allocator();
        var cb = l_alloc.create(TransferCallback) catch @panic("OOM");
        var transfer: *Transfer = &self.arto.rx_transfer;
        cb.alloc = l_alloc;
        cb.dev = self;
        cb.transfer = transfer;
        cb.endpoint = ep.*;
        // timeout 0
        // callback won't be called because of timeout
        usb.libusb_fill_bulk_transfer(
            transfer.self,
            self.mutHdl(),
            ep.addr,
            &transfer.buf,
            @intCast(transfer.buf.len),
            TransferCallback.rx,
            cb,
            0,
        );
        transfer.setCallback(cb, TransferCallback.dtorPtrTypeErased());

        ret = usb.libusb_submit_transfer(transfer.self);
        switch (ret) {
            0 => transfer.lk.lockShared(),
            else => {
                var lg = self.withLogger(logz.err());
                lg = utils.logWithSrc(ep.withLogger(lg), @src());
                lg.int("code", ret)
                    .string("what", "failed to submit transfer")
                    .log();
                @panic("failed to submit transfer");
            },
        }
    }

    pub fn rxObservable(self: *@This()) *PackObserverList {
        return &self.arto.rx_observable;
    }

    fn initEndpoints(self: *@This()) void {
        for (self.endpoints) |*ep| {
            if (ep.direction == Direction.out and ep.transferType == TransferType.bulk) {
                self.initTransferTx(ep);
            } else if (ep.direction == Direction.in and ep.transferType == TransferType.bulk) {
                self.initTransferRx(ep);
            }
        }
    }

    /// it still NEEDS event loop running. Please call it in a separate thread.
    fn loopPrepare(self: *@This()) void {
        // first, we start the loop thread,
        // for the running of observable
        self.initThreads();
        var local = ActionCallback.init(self.allocator(), self) catch unreachable;

        // it's quite hard to design a promise chain without lambda/closure.
        //
        // we only needs a little push to start the chain
        // query_status.than(query_info).than(open_socket)
        local.query_status_send() catch unreachable;
        utils.logWithSrc(self.withLogger(logz.info()), @src())
            .string("what", "preparing finished").log();
    }

    /// run `loopPrepare` in a separate thread
    fn runLoopPrepare(self: *@This()) void {
        const config = std.Thread.SpawnConfig{
            .stack_size = DEFAULT_THREAD_STACK_SIZE,
            .allocator = self.allocator(),
        };

        // expect it to exit soon
        var t_hdl = std.Thread.spawn(config, Self.loopPrepare, .{self}) catch unreachable;
        t_hdl.detach();
    }

    fn initThreads(self: *@This()) void {
        const config = std.Thread.SpawnConfig{
            .stack_size = DEFAULT_THREAD_STACK_SIZE,
            .allocator = self.allocator(),
        };
        const tx_thread = std.Thread.spawn(config, Self.sendLoop, .{self}) catch unreachable;
        const rx_thread = std.Thread.spawn(config, Self.recvLoop, .{self}) catch unreachable;
        self.arto.tx_thread = tx_thread;
        self.arto.rx_thread = rx_thread;
        self.arto.rx_observable = PackObserverList.init(self.allocator());
    }

    /// basically do nothing... for now
    /// reserve for future use
    pub fn sendLoop(self: *@This()) void {
        while (true) {
            if (self.hasDeinit()) {
                break;
            }
            std.time.sleep(1000 * std.time.ns_per_ms);
        }
    }

    /// notify every observer in the queue
    pub fn recvLoop(self: *@This()) void {
        while (true) {
            var mpk = self.unsafeBlockReceive() catch |e| {
                var lg = utils.logWithSrc(self.withLogger(logz.err()), @src());
                lg.err(e)
                    .string("what", "failed to dequeue, exiting thread")
                    .log();
                return;
            };
            defer mpk.deinit();
            var queue = &self.arto.rx_observable;
            queue.update(&mpk);
        }
    }

    pub fn init(self: *@This()) LibUsbError!void {
        var ret: c_int = undefined;
        printStrDesc(self.mutHdl(), self.desc());
        printEndpoints(self.desc().idVendor, self.desc().idProduct, self.endpoints);
        if (!is_windows) {
            // https://libusb.sourceforge.io/api-1.0/group__libusb__self.html#gac35b26fef01271eba65c60b2b3ce1cbf
            ret = usb.libusb_set_auto_detach_kernel_driver(self.mutHdl(), 1);
            if (ret != 0) {
                self.withLogger(logz.err())
                    .int("code", ret)
                    .string("err", "failed to set auto detach kernel driver")
                    .log();
                return libusb_error_2_set(ret);
            }
        }
        ret = usb.libusb_claim_interface(self.mutHdl(), 0);
        if (ret != 0) {
            self.withLogger(logz.err())
                .int("code", ret)
                .string("err", "failed to claim interface")
                .log();
            return libusb_error_2_set(ret);
        }
        self.initEndpoints();
        self._has_deinit.store(false, std.builtin.AtomicOrder.unordered);
        // we could call transmit/receive from now on, as long as the event loop is running

        self.runLoopPrepare();
        const speed = usb.libusb_get_device_speed(self.mutDev());
        self.withLogger(logz.info()).string("speed", usbSpeedToString(speed)).log();
    }
};

fn refreshDevList(allocator: std.mem.Allocator, arena: *std.heap.ArenaAllocator, ctx: *usb.libusb_context, ctx_list: *std.ArrayList(DeviceContext)) void {
    var c_device_list: [*c]?*usb.libusb_device = undefined;
    const sz = usb.libusb_get_device_list(ctx, &c_device_list);
    // See also
    // Device discovery and reference counting
    // in https://libusb.sourceforge.io/api-1.0/group__libusb__dev.html
    //
    // https://zig.news/kprotty/resource-efficient-thread-pools-with-zig-3291
    //
    // If the unref_devices parameter is set, the reference count of each device
    // in the list is decremented by 1
    defer usb.libusb_free_device_list(c_device_list, 1);
    const device_list = c_device_list[0..@intCast(sz)];

    const find_diff = struct {
        ctx_list: []const DeviceContext,

        /// Find the difference between `DeviceContext` the new polled device list from `libusb`.
        ///
        /// Note that the return array will be allocated with `alloc`
        /// and the caller is responsible for freeing the memory.
        ///
        ///   - left: devices that should be removed from the context list (`*const DeviceContext`)
        ///   - right: devices that should be added to the context list (`DeviceDesc` that could be used to init a device)
        pub fn call(
            self: *const @This(),
            arena_alloc: *std.heap.ArenaAllocator,
            poll_list: []const ?*usb.libusb_device,
        ) struct { std.ArrayList(*const DeviceContext), std.ArrayList(DeviceDesc) } {
            const alloc = arena_alloc.allocator();
            var ret: c_int = undefined;
            var filtered = std.ArrayList(DeviceDesc).init(alloc);
            defer filtered.deinit();
            for (poll_list) |device| {
                if (device) |val| {
                    var l_desc: usb.libusb_device_descriptor = undefined;
                    ret = usb.libusb_get_device_descriptor(val, &l_desc);
                    if (ret != 0) continue;
                    if (l_desc.idVendor == ARTO_RTOS_VID and l_desc.idProduct == ARTO_RTOS_PID) {
                        const dd = DeviceDesc.fromDevice(val) catch continue;
                        filtered.append(dd) catch @panic("OOM");
                    }
                }
            }

            var left = std.ArrayList(*const DeviceContext).init(alloc);
            left.ensureTotalCapacity(REFRESH_CONTAINER_DEFAULT_CAP) catch @panic("OOM");
            var right = std.ArrayList(DeviceDesc).init(alloc);
            right.ensureTotalCapacity(REFRESH_CONTAINER_DEFAULT_CAP) catch @panic("OOM");
            var inter = std.ArrayList(DeviceDesc).init(alloc);
            inter.ensureTotalCapacity(REFRESH_CONTAINER_DEFAULT_CAP) catch @panic("OOM");
            defer inter.deinit();

            // TODO: improve the performance by using a hash set or a hash map
            for (self.ctx_list) |*dc| {
                var found = false;
                const l_hash = dc.xxhash();
                inner: for (filtered.items) |dd| {
                    const r_hash = dd.xxhash();
                    if (l_hash == r_hash) {
                        found = true;
                        inter.append(dd) catch @panic("OOM");
                        break :inner;
                    }
                }

                if (!found) {
                    left.append(dc) catch @panic("OOM");
                }
            }

            for (filtered.items) |fdd| {
                var found = false;
                const r_hash = fdd.xxhash();
                inner: for (inter.items) |idd| {
                    const l_hash = idd.xxhash();
                    if (l_hash == r_hash) {
                        found = true;
                        break :inner;
                    }
                }

                if (!found) {
                    right.append(fdd) catch @panic("OOM");
                }
            }

            return .{ left, right };
        }
    };

    const l, const r = (find_diff{ .ctx_list = ctx_list.items }).call(arena, device_list);
    defer l.deinit();
    defer r.deinit();
    // destroy detached devices
    for (l.items) |ldc| {
        inner: for (ctx_list.items, 0..) |*rdc, index| {
            if (ldc == rdc) {
                rdc.withLogger(logz.warn().string("action", "removed")).log();
                rdc.deinit();
                _ = ctx_list.swapRemove(index);
                break :inner;
            }
        }
    }

    // open new devices
    for (r.items) |d| {
        const dc = d.toContext(allocator) catch |e| {
            d.withLogger(logz.err()).err(e).log();
            continue;
        };
        ctx_list.append(dc) catch @panic("OOM");
        d.withLogger(logz.info()).string("action", "added").log();
    }
}

/// only used in `DeviceContext.loopPrepare`
const ActionCallback = struct {
    arena: std.heap.ArenaAllocator,
    /// reference, not OWNING
    self: *DeviceContext,

    const Observer = PackObserverList.Observer;
    const Self = @This();

    pub inline fn as(ud: ?*anyopaque) *Self {
        return @alignCast(@ptrCast(ud.?));
    }

    pub fn init(alloc: std.mem.Allocator, ctx: *DeviceContext) !*Self {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var ret = try arena.allocator().create(@This());
        ret.arena = arena;
        ret.self = ctx;
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        var stk_arena = self.arena;
        stk_arena.allocator().destroy(self);
        _ = stk_arena.reset(.free_all);
        stk_arena.deinit();
    }

    // payload should be a pointer to struct, or null
    pub fn query_common(self: *@This(), reqid: u32, payload: anytype) !void {
        var alloc = self.arena.allocator();
        const P = @TypeOf(payload);

        var pack = UsbPack{
            .reqid = reqid,
            .msgid = 0,
            .sta = 0,
        };
        switch (@typeInfo(P)) {
            .Pointer => {
                try pack.fillWith(payload);
            },
            .Null => {}, // do nothing
            else => @compileError("`payload` must be a pointer type or null, found `" ++ @typeName(P) ++ "`"),
        }
        const data = try pack.marshal(alloc);
        defer alloc.free(data);
        try self.self.transmit(data);
    }

    // like `query_common`, but with a slice payload
    pub fn query_common_slice(cap: *@This(), reqid: u32, payload: []const u8) !void {
        var alloc = cap.arena.allocator();
        var pack = UsbPack{
            .reqid = reqid,
            .msgid = 0,
            .sta = 0,
        };
        pack.ptr = payload.ptr;
        pack.len = @intCast(payload.len);
        const data = try pack.marshal(alloc);
        defer alloc.free(data);
        std.debug.print("data {s}\n", .{std.fmt.fmtSliceHexLower(data)});
        try cap.self.transmit(data);
    }

    // an action being two part (functions)
    // first `*_send` should be call to push
    // the request to the device
    // then the observable will call `*_on_data` when
    // when the message is received
    //
    // other action could be executed in `*_on_data`,
    // like start a new subscription, etc.
    //
    // although it might confuse the reader,
    // as we don't have proper async/await support

    /// create a predicate that matches the request id
    pub fn make_reqid_predicate(comptime reqid: u32) fn (*const UsbPack, ?*anyopaque) bool {
        return (struct {
            pub fn call(pack: *const UsbPack, _: ?*anyopaque) bool {
                return pack.reqid == reqid;
            }
        }).call;
    }

    pub fn query_status_send(cap: *@This()) !void {
        var in = bb.bb_get_status_in_t{
            .user_bmp = SLOT_BIT_MAP_MAX,
        };
        try cap.query_common(bb.BB_GET_STATUS, &in);
        const predicate = Self.make_reqid_predicate(bb.BB_GET_STATUS);
        var subject = cap.self.rxObservable();
        subject.subscribe(
            &predicate,
            &Self.query_status_on_data,
            cap,
            null,
        ) catch unreachable;
    }

    pub fn query_status_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) void {
        const ud = obs.userdata;
        var cap = Self.as(ud);
        if (pack.dataAs(bb.bb_get_status_out_t)) |status| {
            bt.logWithStatus(cap.self.withSrcLogger(logz.info(), @src()), &status).log();
            // ***** and_then *****
            cap.query_info_send() catch @panic("OOM");
        } else |e| {
            cap.self.withSrcLogger(logz.err(), @src())
                .err(e)
                .string("what", "failed to parse status")
                .log();
            obs.dtor = @ptrCast(&Self.deinit);
        }
        sbj.unsubscribe(obs) catch unreachable;
    }

    pub fn query_info_send(cap: *@This()) !void {
        try cap.query_common(bb.BB_GET_SYS_INFO, null);
        const predicate = Self.make_reqid_predicate(bb.BB_GET_SYS_INFO);
        var subject = cap.self.rxObservable();
        subject.subscribe(
            &predicate,
            &Self.query_info_on_data,
            cap,
            null,
        ) catch unreachable;
    }

    pub fn query_info_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) void {
        std.debug.assert(pack.sta == 0);
        const ud = obs.userdata;
        var cap = Self.as(ud);
        if (pack.dataAs(bb.bb_get_sys_info_out_t)) |info| {
            const compile_time: [*:0]const u8 = @ptrCast(&info.compile_time);
            const soft_ver: [*:0]const u8 = @ptrCast(&info.soft_ver);
            const hard_ver: [*:0]const u8 = @ptrCast(&info.hardware_ver);
            const firmware_ver: [*:0]const u8 = @ptrCast(&info.firmware_ver);
            cap.self.withSrcLogger(logz.info(), @src())
                .int("uptime", info.uptime)
                .stringSafeZ("compile_time", compile_time)
                .stringSafeZ("soft_ver", soft_ver)
                .stringSafeZ("hard_ver", hard_ver)
                .stringSafeZ("firmware_ver", firmware_ver)
                .log();
            // ***** and_then *****
            cap.subscribe_event_no_response(.link_state) catch unreachable;
            cap.subscribe_event_no_response(.mcs_change) catch unreachable;
            cap.subscribe_event_no_response(.chan_change) catch unreachable;

            cap.open_socket_send() catch unreachable;
        } else |e| {
            cap.self.withSrcLogger(logz.err(), @src())
                .err(e)
                .string("what", "failed to parse system info")
                .log();
            obs.dtor = @ptrCast(&Self.deinit);
        }
        sbj.unsubscribe(obs) catch unreachable;
    }

    /// subscribe an event, don't care if it's successful or not.
    /// I don't care the response.
    /// without closure it's become tedious.
    pub fn subscribe_event_no_response(cap: *@This(), event: bt.Event) !void {
        const req = bt.subscribeRequestId(event);
        try cap.query_common(req, null);
    }

    const sel_slot = bb.BB_SLOT_AP;
    const sel_port = 3;
    // note that sta == 0x0101 (i.e. 257) means already opened socket
    const ERROR_ALREADY_OPENED_SOCKET = 257;
    // -259 is a generic error code, I have no idea what's the exact meaning
    const ERROR_UNKNOWN = -259;
    const OpenRequestId = bt.socketRequestId(.open, @intCast(sel_slot), @intCast(sel_port));

    fn try_socket_open(cap: *@This()) !void {
        const flag: u8 = @intCast(bb.BB_SOCK_FLAG_TX | bb.BB_SOCK_FLAG_RX);
        // see `session_socket.c:232`
        // TODO: create a wrapper struct
        const buf = &[_]u8{
            flag, 0x00, 0x00, 0x00, // flags, with alignment
            0x00, 0x08, 0x00, 0x00, // 2048 in `bb.bb_sock_opt_t.tx_buf_size`
            0x00, 0x0c, 0x00, 0x00, // 3072 in `bb.bb_sock_opt_t.rx_buf_size`
        };
        try cap.query_common_slice(OpenRequestId, buf);
    }

    pub fn open_socket_send(cap: *@This()) !void {
        try cap.try_socket_open();
        var subject = cap.self.rxObservable();
        const predicate = Self.make_reqid_predicate(OpenRequestId);
        subject.subscribe(
            &predicate,
            &Self.open_socket_on_data,
            cap,
            null,
        ) catch unreachable;
    }

    pub fn open_socket_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) void {
        // if we must handle these shit
        // we'd better make a state machine
        const ud = obs.userdata;
        var cap = Self.as(ud);
        if (pack.sta == 0) {
            cap.self.withSrcLogger(logz.info(), @src())
                .int("slot", sel_slot)
                .int("port", sel_port)
                .string("what", "socket opened")
                .log();
        } else if (pack.sta == ERROR_ALREADY_OPENED_SOCKET) {
            // leave it be
            cap.self.withSrcLogger(logz.warn(), @src())
                .int("slot", sel_slot)
                .int("port", sel_port)
                .string("what", "socket already opened")
                .log();
        } else {
            cap.self.withSrcLogger(logz.err(), @src())
                .int("slot", sel_slot)
                .int("port", sel_port)
                .int("sta", pack.sta)
                .string("what", "failed to open socket")
                .log();
            std.debug.panic("failed to open socket, sta={d}", .{pack.sta});
        }
        obs.dtor = @ptrCast(&Self.deinit);
        sbj.unsubscribe(obs) catch unreachable;
    }
};

/// See `libusb_fill_bulk_transfer`
///
///   - https://libusb.sourceforge.io/api-1.0/group__libusb__asyncio.html
///   - https://libusb.sourceforge.io/api-1.0/libusb_io.html
///
/// > In the interest of being a lightweight library, libusb does not
/// create threads and can only operate when your application is
/// calling into it. Your application must call into libusb from it's
/// main loop when events are ready to be handled, or you must use
/// some other scheme to allow libusb to undertake whatever work
/// needs to be done.
///
/// Only used in `DeviceContext.initTransferTx` and `DeviceContext.initTransferRx`
const TransferCallback = struct {
    alloc: std.mem.Allocator,
    /// reference, not OWNING
    dev: *DeviceContext,
    /// reference, not OWNING
    transfer: *DeviceContext.Transfer,
    endpoint: Endpoint,

    pub fn deinit(self: *@This()) void {
        self.alloc.destroy(self);
    }

    /// return a type-erased pointer to the destructor
    pub fn dtorPtrTypeErased() *const fn (*anyopaque) void {
        return @ptrCast(&@This().deinit);
    }

    /// just a notification of the completion or timeout of the transfer
    ///
    /// Note that the lock (`lk`) is assumed to be locked (by `DeviceContext.transmit`)
    pub fn tx(trans: [*c]usb.libusb_transfer) callconv(.C) void {
        if (trans == null) {
            @panic("null transfer");
        }
        const self: *@This() = @alignCast(@ptrCast(trans.*.user_data.?));
        self.transfer.lk.unlockShared();
        const status = transferStatusFromInt(trans.*.status) catch unreachable;

        var lg = utils.logWithSrc(self.dev.withLogger(logz.debug()), @src());
        lg = self.endpoint.withLogger(lg);
        lg.string("status", @tagName(status))
            .int("flags", trans.*.flags)
            .string("action", "transmit")
            .log();
        std.debug.assert(status == .completed);
    }

    /// basically it checks & unmarshal the packet received from the endpoint,
    /// and then enqueues it to the `rx_queue` in `DeviceContext` for further processing.
    pub fn rx(trans: [*c]usb.libusb_transfer) callconv(.C) void {
        if (trans == null) {
            @panic("null transfer");
        }
        const self: *@This() = @alignCast(@ptrCast(trans.*.user_data.?));
        const status = transferStatusFromInt(trans.*.status) catch unreachable;

        const rx_buf = self.transfer.written();
        self.transfer.lk.unlockShared();
        var lg = utils.logWithSrc(self.dev.withLogger(logz.debug()), @src());
        lg = self.endpoint.withLogger(lg);
        lg.string("status", @tagName(status))
            .int("flags", trans.*.flags)
            .string("action", "receive")
            .int("len", rx_buf.len)
            .log();

        if (rx_buf.len > 0) {
            var mpk_ = ManagedUsbPack.unmarshal(self.alloc, rx_buf);
            if (mpk_) |*mpk| {
                lg = utils.logWithSrc(self.dev.withLogger(logz.debug()), @src());
                lg = self.endpoint.withLogger(lg);
                mpk.pack.withLogger(lg)
                    .log();
                self.dev.arto.rx_queue.enqueue(mpk.*) catch |e| {
                    lg = utils.logWithSrc(self.dev.withLogger(logz.err()), @src());
                    lg.err(e).string("what", "failed to enqueue").log();
                    mpk.deinit();
                };
            } else |err| {
                lg = utils.logWithSrc(self.dev.withLogger(logz.err()), @src());
                lg = self.endpoint.withLogger(lg);
                lg.string("what", "failed to unmarshal")
                    .fmt("data", "{any}", .{rx_buf})
                    .err(err)
                    .log();
            }
        }

        // resubmit
        const errc = usb.libusb_submit_transfer(trans);
        if (errc == 0) {
            self.transfer.lk.lockShared();
        } else {
            const err = libusb_error_2_set(errc);
            lg = self.dev.withLogger(logz.err());
            lg = self.endpoint.withLogger(lg);
            lg.string("what", "failed to resubmit transfer")
                .err(err).log();
            switch (err) {
                LibUsbError.NoDevice => {
                    // upstream should monitor the device list
                    // and handle the device removal
                },
                LibUsbError.Busy => {
                    // should not happen, unless the transfer is be reused,
                    // which should NOT happen with lock
                    @panic("invalid precondition: busy transfer");
                },
                else => {
                    @panic("failed to resubmit transfer");
                },
            }
        }
    }
};

pub fn main() !void {
    // Use a separate allocator for logz
    var _logz_gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = false,
        .safety = false,
    }){};
    defer {
        _ = _logz_gpa.deinit();
    }
    try logz.setup(_logz_gpa.allocator(), .{
        .level = .Debug,
        .pool_size = 96,
        .buffer_size = 4096,
        .large_buffer_count = 8,
        .large_buffer_size = 16384,
        .output = .stdout,
        .encoding = .logfmt,
    });
    defer logz.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const alloc = gpa.allocator();
    defer {
        const chk = gpa.deinit();
        if (chk != .ok) {
            std.debug.print("GPA thinks there are memory leaks\n", .{});
        }
    }

    const pc_version = usb.libusb_get_version();
    const p_version: ?*const usb.libusb_version = @ptrCast(pc_version);
    if (p_version) |version| {
        logz.info().fmt("libusb version", "{}.{}.{}.{}", .{ version.major, version.minor, version.micro, version.nano }).log();
    } else {
        @panic("failed to get libusb version");
    }

    var ctx_: ?*usb.libusb_context = null;
    var ret: c_int = undefined;
    // https://libusb.sourceforge.io/api-1.0/libusb_contexts.html
    ret = usb.libusb_init_context(&ctx_, null, 0);
    if (ret != 0) {
        return std.debug.panic("libusb_init_context failed: {}", .{ret});
    }
    const ctx = ctx_.?;
    defer usb.libusb_exit(ctx);
    var device_list = std.ArrayList(DeviceContext).init(alloc);
    defer {
        for (device_list.items) |*dev| {
            dev.deinit();
        }
        device_list.deinit();
    }

    {
        const BUFFER_SIZE = REFRESH_CONTAINER_DEFAULT_CAP * (@sizeOf(*const DeviceContext) + @sizeOf(DeviceDesc) * 2) + 1024;
        var stack_buf: [BUFFER_SIZE]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(stack_buf[0..]);
        const stack_allocator = fixed.allocator();
        var arena = std.heap.ArenaAllocator.init(stack_allocator);
        defer {
            _ = arena.reset(.retain_capacity);
            arena.deinit();
        }
        // TODO: call it in a separate thread, looping
        refreshDevList(alloc, &arena, ctx, &device_list);
    }

    for (device_list.items) |*dev| {
        dev.init() catch |e| {
            dev.withLogger(logz.err()).err(e).log();
        };
    }

    // https://www.reddit.com/r/Zig/comments/wviq36/how_to_catch_signals_at_least_sigint/
    // https://www.reddit.com/r/Zig/comments/11mr0r8/defer_errdefer_and_sigint_ctrlc/
    const Sig = struct {
        var flag = std.atomic.Value(bool).init(true);

        const w = std.os.windows;
        pub fn ctrl_c_handler(dwCtrlType: w.DWORD) callconv(w.WINAPI) w.BOOL {
            if (dwCtrlType == w.CTRL_C_EVENT) {
                logz.info()
                    .string("action", "Ctrl-C received")
                    .log();
                flag.store(false, std.builtin.AtomicOrder.unordered);
                return 1;
            }
            return 0;
        }

        pub fn int_handle(sig: i32) callconv(.C) void {
            if (sig == std.c.SIG.INT) {
                logz.info()
                    .int("signal", sig)
                    .string("action", "SIGINT received")
                    .log();
                flag.store(false, std.builtin.AtomicOrder.unordered);
            }
        }

        pub inline fn is_run() bool {
            return flag.load(std.builtin.AtomicOrder.unordered);
        }
    };

    if (is_windows) {
        std.os.windows.SetConsoleCtrlHandler(Sig.ctrl_c_handler, true) catch unreachable;
    } else {
        // borrowed from
        // https://git.sr.ht/~delitako/nyoomcat/tree/main/item/src/main.zig#L109
        const act = std.posix.Sigaction{
            .handler = .{ .handler = Sig.int_handle },
            .mask = std.posix.empty_sigset,
            .flags = 0,
        };
        std.posix.sigaction(std.c.SIG.INT, &act, null) catch unreachable;
    }

    var tv = usb.timeval{
        .tv_sec = 0,
        .tv_usec = 0,
    };

    logz.info().string("action", "start event loop").log();
    // https://libusb.sourceforge.io/api-1.0/libusb_mtasync.html
    // https://stackoverflow.com/questions/45672717/how-to-force-a-libusb-event-so-that-libusb-handle-events-returns
    // https://libusb.sourceforge.io/api-1.0/group__libusb__poll.html
    while (Sig.is_run()) {
        _ = usb.libusb_handle_events_timeout_completed(ctx, &tv, null);
    }
}
