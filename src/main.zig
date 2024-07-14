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
const Condition = std.Thread.Condition;

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

const ArtoStatus = bt.Status;

/// Select every possible slot (14 slot?).
/// Anyway it's a magic number.
///
/// `0b0011_1111_1111_1111`
const SLOT_BIT_MAP_MAX = 0x3fff;
const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;
const XXHASH_SEED: u32 = 0x0;
const USB_MAX_PORTS = 8;
const TRANSFER_BUF_SIZE = 3072;
const DEFAULT_THREAD_STACK_SIZE = 16 * 1024 * 1024;
const MAX_SERIAL_SIZE = 32;
const REFRESH_CONTAINER_DEFAULT_CAP = 4;
const BB_STA_OK = bt.STA_OK;
const LIBUSB_OK = helper.LIBUSB_OK;
const BB_SEL_SLOT = bb.BB_SLOT_0;
const BB_SEL_PORT = 3;
const BB_ERROR_ALREADY_OPENED_SOCKET = 257;
const BB_ERROR_UNSPECIFIED = -259;

const DeviceGPA = std.heap.GeneralPurposeAllocator(.{
    .thread_safe = true,
});
const UsbPackQueue = LockedQueue(ManagedUsbPack, 8);
const is_windows = builtin.os.tag == .windows;

/// A naive implementation of the observer pattern for `UsbPack`
///
/// See also
///   - https://wiki.commonjs.org/wiki/Promises
///   - https://promisesaplus.com/
///   - https://reactivex.io/intro.html
///
/// See also `UsbPack`
const PackObserverList = struct {
    pub const ObserverError = error{
        Existed,
        NotFound,
    };

    pub const OnDataFn = fn (*PackObserverList, *const UsbPack, *Observer) anyerror!void;
    pub const OnDataFnPtr = *const OnDataFn;

    pub const OnErrorFn = fn (*PackObserverList, *const UsbPack, *Observer, err: anyerror) void;
    pub const OnErrorFnPtr = *const OnErrorFn;
    pub const NullableOnErrorFnPtr = ?OnErrorFnPtr;

    pub const PredicateFn = fn (*const UsbPack, ?*anyopaque) bool;
    pub const PredicateFnPtr = *const PredicateFn;

    pub const Dtor = fn (*anyopaque) void;
    pub const NullableDtorPtr = ?*const Dtor;

    // Observer provider could use
    // reference counting in dtor
    const Observer = struct {
        predicate: PredicateFnPtr,
        /// the callback function SHOULD NOT block
        on_data: OnDataFnPtr,
        on_error: NullableOnErrorFnPtr,
        userdata: ?*anyopaque,
        dtor: NullableDtorPtr,

        /// hashing the pointer, don't ask me why it's useful
        pub fn xxhash(self: *const @This()) u32 {
            var h = std.hash.XxHash32.init(XXHASH_SEED);
            const predicate_addr = @intFromPtr(self.predicate);
            h.update(utils.anytype2Slice(&predicate_addr));
            const notify_addr = @intFromPtr(self.on_data);
            h.update(utils.anytype2Slice(&notify_addr));
            if (self.on_error) |ptr| {
                const on_error_addr = @intFromPtr(ptr);
                h.update(utils.anytype2Slice(&on_error_addr));
            }
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
    /// WARNING: DO NOT access this field directly
    _list: std.ArrayList(Observer),
    lk: RwLock = RwLock{},
    // ******** end fields ********

    const Self = @This();

    inline fn items(self: *const Self) []const Observer {
        return self._list.items;
    }

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{
            .allocator = alloc,
            ._list = std.ArrayList(Observer).init(alloc),
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
        on_error: NullableOnErrorFnPtr,
        userdata: ?*anyopaque,
        dtor: NullableDtorPtr,
    ) !void {
        const obs = Observer{
            .predicate = predicate,
            .on_data = on_data,
            .on_error = on_error,
            .userdata = userdata,
            .dtor = dtor,
        };
        const h = obs.xxhash();

        {
            self.lk.lock();
            defer self.lk.unlock();
            for (self._list.items) |*o| {
                if (o.xxhash() == h) {
                    return ObserverError.Existed;
                }
            }
        }

        self.lk.lockShared();
        defer self.lk.unlockShared();
        try self._list.append(obs);
    }

    /// dispatch the packet to the observers
    pub fn update(self: *@This(), pack: *const UsbPack) void {
        // explicit no lock here
        var cnt: usize = 0;
        for (self._list.items) |*o| {
            if (o.predicate(pack, o.userdata)) {
                o.on_data(self, pack, o) catch |e| {
                    if (o.on_error) |on_err| {
                        on_err(self, pack, o, e);
                    } else {
                        const h = o.xxhash();
                        pack.withLogger(utils.logWithSrc(logz.warn(), @src()).fmt("what", "unhandled observer(0x{x:0>4}) error", .{h})).err(e).log();
                    }
                };
                cnt += 1;
            }
        }

        if (cnt == 0) {
            pack.withLogger(utils.logWithSrc(logz.warn(), @src())).string("what", "no observer is notified").log();
        }
    }

    pub inline fn unsubscribe(self: *@This(), obs: *const Observer) ObserverError!void {
        return self.unsubscribeByHash(obs.xxhash());
    }

    /// unsubscribe an observer by hash
    pub fn unsubscribeByHash(self: *@This(), hash: u32) ObserverError!void {
        const NOT_FOUND: isize = -1;
        var idx: isize = NOT_FOUND;
        const len = self._list.items.len;

        // explicit no lock here
        for (self._list.items, 0..len) |*o, i| {
            const h = o.xxhash();
            if (h == hash) {
                idx = @intCast(i);
                break;
            }
        }
        if (idx == NOT_FOUND) {
            return ObserverError.NotFound;
        }

        self.lk.lockShared();
        var el = self._list.swapRemove(@intCast(idx));
        self.lk.unlockShared();
        el.deinit();
    }

    /// unsubscribe all observers
    pub fn unsubscribeAll(self: *@This()) void {
        self.lk.lockShared();
        defer self.lk.lockShared();
        for (self._list.items) |*o| {
            o.deinit();
        }
        self._list.deinit();
        self._list = std.ArrayList(Observer).init(self.allocator);
    }

    pub fn deinit(self: *@This()) void {
        for (self._list.items) |*o| {
            o.deinit();
        }
        self._list.deinit();
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

    /// the same as calling `DeviceContext.fromDeviceDesc`
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

const DeviceContext = struct {
    /// Transfer is a wrapper of `libusb_transfer`
    /// but with a closure and a closure destructor
    const Transfer = struct {
        self: *usb.libusb_transfer,
        /// [Packets and overflows](https://libusb.sourceforge.io/api-1.0/libusb_packetoverflow.html)
        ///
        /// > libusb and the underlying OS abstract out the packet concept,
        /// allowing you to request transfers of any size. Internally, the
        /// request will be divided up into correctly-sized packets. You do not
        /// have to be concerned with packet sizes, but there is one exception
        /// when considering overflows.
        ///
        /// > You will never see an overflow if your transfer buffer size is a
        /// multiple of the endpoint's packet size: the final packet will either
        /// fill up completely or will be only partially filled.
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

    const TxSync = struct {
        _is_free: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
        mutex: Mutex = Mutex{},
        cv: Condition = Condition{},

        pub inline fn setFree(self: *@This(), free: bool) void {
            self._is_free.store(free, std.builtin.AtomicOrder.unordered);
        }

        pub inline fn isFree(self: *const @This()) bool {
            return self._is_free.load(std.builtin.AtomicOrder.unordered);
        }
    };

    /// Transfer related context
    const TransferContext = struct {
        tx_transfer: Transfer,
        rx_transfer: Transfer,

        /// use to notify the completion of the transfer
        tx_sync: TxSync,
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

    const ArtoContext = struct {
        const NEVER_UPDATED = 0;
        _status: ArtoStatus = undefined,
        /// seconds UNIX timestamp when the status is updated
        _last_status_updated: i64 = NEVER_UPDATED,

        pub inline fn status(self: *const @This()) ?*const ArtoStatus {
            if (self._last_status_updated == NEVER_UPDATED) {
                return null;
            }
            return &self._status;
        }

        pub inline fn setWithBBStatus(self: *@This(), new_bb_status: *const bb.bb_get_status_out_t) !void {
            const new_status = try bt.Status.fromC(new_bb_status);
            self.setStatus(&new_status);
        }

        pub inline fn setStatus(self: *@This(), new_status: *const ArtoStatus) void {
            self._status = new_status.*;
            self._last_status_updated = std.time.timestamp();
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
    xfer: TransferContext,
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

    pub inline fn isTxReady(self: *const @This()) bool {
        return self.xfer.tx_sync.isFree();
    }

    pub inline fn status(self: *const @This()) ?*const ArtoStatus {
        return self.arto.status();
    }

    pub inline fn rxObservable(self: *@This()) *PackObserverList {
        return &self.xfer.rx_observable;
    }

    /// See `DeviceDesc`
    pub fn fromDeviceDesc(alloc: std.mem.Allocator, d: DeviceDesc) LibUsbError!@This() {
        var ret: c_int = undefined;
        var l_hdl: ?*usb.libusb_device_handle = null;
        // Internally, this function adds a reference
        ret = usb.libusb_open(d.dev, &l_hdl);
        if (ret != LIBUSB_OK) {
            const e = libusb_error_2_set(ret);
            d.withLogger(logz.err().string("err", "failed to open device").err(e)).log();
            return e;
        }
        std.debug.assert(l_hdl != null);
        var l_desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(d.dev, &l_desc);
        if (ret != LIBUSB_OK) {
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
            .xfer = undefined,
            .arto = ArtoContext{},
        };

        std.debug.assert(sn.len <= MAX_SERIAL_SIZE);
        @memcpy(dc._serial_buf[0..sn.len], sn);
        dc._serial_len = sn.len;

        const tx_transfer = usb.libusb_alloc_transfer(0);
        const rx_transfer = usb.libusb_alloc_transfer(0);
        std.debug.assert(tx_transfer != null);
        std.debug.assert(rx_transfer != null);
        dc.xfer.tx_transfer = Transfer{
            .self = tx_transfer,
        };
        dc.xfer.rx_transfer = Transfer{
            .self = rx_transfer,
        };
        // somehow the `rx_queue` is not happy with allocated with allocator in
        // the `DeviceContext`, which would cause a deadlock.
        // Interestingly, the deadlock is from the internal of GPA, needs to be
        // investigated further.
        dc.xfer.rx_queue = UsbPackQueue.init(alloc);
        return dc;
    }

    pub fn initialize(self: *@This()) LibUsbError!void {
        var ret: c_int = undefined;
        printStrDesc(self.mutHdl(), self.desc());
        printEndpoints(self.desc().idVendor, self.desc().idProduct, self.endpoints);
        if (!is_windows) {
            // https://libusb.sourceforge.io/api-1.0/group__libusb__self.html#gac35b26fef01271eba65c60b2b3ce1cbf
            ret = usb.libusb_set_auto_detach_kernel_driver(self.mutHdl(), 1);
            if (ret != LIBUSB_OK) {
                self.withLogger(logz.err())
                    .int("code", ret)
                    .string("err", "failed to set auto detach kernel driver")
                    .log();
                return libusb_error_2_set(ret);
            }
        }
        ret = usb.libusb_claim_interface(self.mutHdl(), 0);
        if (ret != LIBUSB_OK) {
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

    pub fn deinit(self: *Self) void {
        self._has_deinit.store(true, std.builtin.AtomicOrder.unordered);
        self.core.deinit();
        self.allocator().free(self.endpoints);
        self.xfer.deinit();
        const chk = self.gpa.deinit();
        if (chk != .ok) {
            std.debug.print("GPA thinks there are memory leaks when destroying device bus {} port {}\n", .{ self.bus, self.port });
        }
    }

    /// attach the device information to the logger
    pub inline fn withLogger(self: *const Self, logger: logz.Logger) logz.Logger {
        const s = self.serial();
        var lg = logger;
        if (s.len != 0) {
            lg = lg.string("serial_number", s);
        }
        if (self.status()) |sta| {
            lg = lg.string("role", @tagName(sta.role));
        }
        lg = lg.int("bus", self.bus)
            .int("port", self.port);
        return lg;
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

    pub const TransmitError = error{
        Overflow,
        Busy,
    };

    /// transmit the data to tx endpoint
    ///
    /// Tx transfer should be initialized (with `initTransferTx`) before calling this function.
    /// libusb event loop should have been started.
    ///
    /// Note that the data will be copy to the internal buffer, and will return
    /// `TransmitError.Overflow` if the data is too large. (See `TRANSFER_BUF_SIZE`)
    ///
    /// use `DeviceContext.unsafeBlockReceive` to receive the data coming from the device
    ///
    /// If you needs `UsbPack` to be sent, you should use `transmitWithPack` or `transmitSliceWithPack`,
    /// instead of calling this function directly.
    ///
    /// TODO: use a ring buffer to provide a queued transmit (useful for burst data)
    pub fn transmit(self: *@This(), data: []const u8) !void {
        if (self.hasDeinit()) {
            return ClosedError.Closed;
        }
        const transfer = &self.xfer.tx_transfer;
        if (data.len > transfer.buf.len) {
            return TransmitError.Overflow;
        }
        const ok = transfer.lk.tryLockShared();
        if (!ok) {
            return TransmitError.Busy;
        }
        errdefer transfer.lk.unlockShared();
        const target_slice = transfer.buf[0..data.len];
        @memcpy(target_slice, data);
        // `actual_length` is only useful for receiving data
        transfer.self.length = @intCast(data.len);
        const ret = usb.libusb_submit_transfer(transfer.self);
        if (ret != LIBUSB_OK) {
            return libusb_error_2_set(ret);
        }
        self.xfer.tx_sync.setFree(false);
    }

    /// wrap `payload` into `UsbPack` and `transmit` it.
    /// `payload` should be a pointer to struct, or null.
    /// Require `DeviceContext.transmit` could be called.
    pub fn transmitWithPack(self: *@This(), alloc: std.mem.Allocator, reqid: u32, payload: anytype) !void {
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
        try self.transmit(data);
    }

    /// wrap `payload` into `UsbPack` and `transmit` it.
    /// `payload` should be a slice.
    /// Require `DeviceContext.transmit` could be called.
    pub fn transmitSliceWithPack(self: *@This(), alloc: std.mem.Allocator, reqid: u32, payload: []const u8) !void {
        var pack = UsbPack{
            .reqid = reqid,
            .msgid = 0,
            .sta = 0,
        };
        pack.ptr = payload.ptr;
        pack.len = @intCast(payload.len);
        const data = try pack.marshal(alloc);
        defer alloc.free(data);
        try self.transmit(data);
    }

    /// write to the magical socket, requires an open socket
    pub fn transmitViaSocket(self: *@This(), payload: []const u8) !void {
        const alloc = self.allocator();
        const reqid = bt.socketRequestId(.write, BB_SEL_SLOT, BB_SEL_PORT);
        return self.transmitSliceWithPack(alloc, reqid, payload);
    }

    /// Wait for the completion of the TX transfer.
    /// It will keeps blocking until the transfer is completed
    pub fn waitForTxComplete(self: *@This()) void {
        if (self.hasDeinit()) {
            return;
        }
        var sync = &self.xfer.tx_sync;
        if (sync.isFree()) {
            return;
        }
        sync.mutex.lock();
        defer sync.mutex.unlock();
        while (!sync.isFree()) {
            sync.cv.wait(&sync.mutex);
        }
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
        return self.xfer.rx_queue.dequeue();
    }

    fn initTransferTx(self: *@This(), ep: *Endpoint) void {
        const alloc = self.allocator();
        var transfer: *Transfer = &self.xfer.tx_transfer;
        const cb = TransferCallback.init(
            alloc,
            self,
            transfer,
            ep.*,
        ) catch @panic("OOM");
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

    fn initTransferRx(self: *DeviceContext, ep: *Endpoint) void {
        var ret: c_int = undefined;
        const alloc = self.allocator();
        var transfer: *Transfer = &self.xfer.rx_transfer;
        const cb = TransferCallback.init(
            alloc,
            self,
            transfer,
            ep.*,
        ) catch @panic("OOM");
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
            LIBUSB_OK => transfer.lk.lockShared(),
            else => std.debug.panic("failed to submit transfer, code={d}", .{ret}),
        }
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
        var action = ActionCallback.init(self.allocator(), self) catch unreachable;

        // it's quite hard to design a promise chain without lambda/closure.
        //
        // we only needs a little push to start the chain
        // query_status.than(query_info).than(open_socket)
        action.query_status_send() catch unreachable;
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
        self.xfer.tx_thread = tx_thread;
        self.xfer.rx_thread = rx_thread;
        self.xfer.rx_observable = PackObserverList.init(self.allocator());
    }

    /// basically do nothing... for now
    /// reserve for future use
    fn sendLoop(self: *@This()) void {
        while (true) {
            if (self.hasDeinit()) {
                break;
            }
            if (self.status()) |sta| {
                switch (sta.role) {
                    .ap => {
                        self.transmitViaSocket("hello from AP") catch |e| {
                            const lg = self.withSrcLogger(logz.err(), @src());
                            lg.err(e)
                                .string("what", "failed to transmit via socket")
                                .log();
                        };
                        std.time.sleep(1500 * std.time.ns_per_ms);
                    },
                    .dev => {
                        self.transmitViaSocket("hello from DEV") catch |e| {
                            const lg = self.withSrcLogger(logz.err(), @src());
                            lg.err(e)
                                .string("what", "failed to transmit via socket")
                                .log();
                        };
                        std.time.sleep(500 * std.time.ns_per_ms);
                    },
                }
            } else {
                std.time.sleep(1000 * std.time.ns_per_ms);
            }
        }
    }

    /// notify every observer in the queue
    fn recvLoop(self: *@This()) void {
        while (true) {
            var mpk = self.unsafeBlockReceive() catch |e| {
                var lg = utils.logWithSrc(self.withLogger(logz.err()), @src());
                lg.err(e)
                    .string("what", "failed to dequeue, exiting thread")
                    .log();
                return;
            };
            defer mpk.deinit();
            var queue = &self.xfer.rx_observable;
            queue.update(&mpk.pack);
        }
    }
};

/// allocator for `DeviceContext` that would persist and `arena` for the temporary memory.
///
/// will mutate `ctx_list` in place.
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

const MagicSocketCallback = struct {
    allocator: std.mem.Allocator,
    /// reference, not OWNING
    dev: *DeviceContext,
    const Self = @This();

    const WriteSocketReqid = bt.socketRequestId(.write, BB_SEL_SLOT, BB_SEL_PORT);
    const ReadSocketReqid = bt.socketRequestId(.read, BB_SEL_SLOT, BB_SEL_PORT);

    const Observer = PackObserverList.Observer;

    pub fn as(ud: ?*anyopaque) *Self {
        return @alignCast(@ptrCast(ud.?));
    }

    pub fn init(alloc: std.mem.Allocator, dev: *DeviceContext) !*Self {
        var ret = try alloc.create(Self);
        ret.allocator = alloc;
        ret.dev = dev;
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.destroy(self);
    }

    pub fn subscribe_write(self: *@This(), subject: *PackObserverList) !void {
        const predicate = ActionCallback.make_reqid_predicate(WriteSocketReqid);
        try subject.subscribe(
            &predicate,
            &Self.write_on_data,
            null,
            self,
            @ptrCast(&Self.deinit),
        );
    }
    pub fn write_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = Self.as(ud);
        _ = sbj;
        if (pack.sta != BB_STA_OK) {
            self.dev.withSrcLogger(logz.err(), @src())
                .fmt("what", "bad socket write slot {} port {}", .{ BB_SEL_SLOT, BB_SEL_PORT })
                .int("sta", pack.sta).log();
            return;
        }
        self.dev.withSrcLogger(logz.debug(), @src())
            .fmt("what", "written socket slot {} port {}", .{ BB_SEL_SLOT, BB_SEL_PORT }).log();
    }

    pub fn subscribe_read(self: *@This(), subject: *PackObserverList) !void {
        const predicate = ActionCallback.make_reqid_predicate(ReadSocketReqid);
        try subject.subscribe(
            &predicate,
            &Self.read_on_data,
            null,
            self,
            @ptrCast(&Self.deinit),
        );
    }
    pub fn read_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = Self.as(ud);
        _ = sbj;
        if (pack.sta != BB_STA_OK) {
            self.dev.withSrcLogger(logz.err(), @src())
                .fmt("what", "bad socket read slot {} port {}", .{ BB_SEL_SLOT, BB_SEL_PORT })
                .int("sta", pack.sta)
                .log();
            return;
        }

        if (pack.data()) |data| {
            self.dev.withSrcLogger(logz.info(), @src())
                .fmt("what", "read socket slot {} port {}", .{ BB_SEL_SLOT, BB_SEL_PORT })
                .string("data", data)
                .log();
        } else |_| {}
    }
};

/// only used in `DeviceContext.loopPrepare`
const ActionCallback = struct {
    arena: std.heap.ArenaAllocator,
    /// reference, not OWNING
    dev: *DeviceContext,

    const Observer = PackObserverList.Observer;
    const Self = @This();

    pub inline fn as(ud: ?*anyopaque) *Self {
        return @alignCast(@ptrCast(ud.?));
    }

    pub fn init(alloc: std.mem.Allocator, dev: *DeviceContext) !*Self {
        var arena = std.heap.ArenaAllocator.init(alloc);
        var ret = try arena.allocator().create(Self);
        ret.arena = arena;
        ret.dev = dev;
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        var arena = self.arena;
        _ = arena.reset(.free_all);
        arena.deinit();
    }

    /// create a predicate that matches the request id
    pub fn make_reqid_predicate(comptime reqid: u32) PackObserverList.PredicateFn {
        return (struct {
            pub fn call(pack: *const UsbPack, _: ?*anyopaque) bool {
                return pack.reqid == reqid;
            }
        }).call;
    }

    /// make a generic short circuit error handler
    ///
    /// it will log the error and unsubscribe the observer, and than destroy the closure
    pub fn make_generic_error_handler(comptime what: []const u8) PackObserverList.OnErrorFn {
        return (struct {
            pub fn GenericErrorHandler(sbj: *PackObserverList, _: *const UsbPack, obs: *Observer, err: anyerror) void {
                const ud = obs.userdata;
                var self = Self.as(ud);
                self.dev.withSrcLogger(logz.err(), @src())
                    .err(err)
                    .string("what", what)
                    .log();
                std.debug.assert(obs.dtor == null);
                obs.dtor = @ptrCast(&Self.deinit);
                sbj.unsubscribe(obs) catch unreachable;
            }
        }).GenericErrorHandler;
    }

    /// listen to the magic socket write/read by creating callbacks
    pub fn listen_to_socket(self: *@This()) !void {
        const sbj = self.dev.rxObservable();
        var socket_cb_write = try MagicSocketCallback.init(self.dev.allocator(), self.dev);
        var socket_cb_read = try MagicSocketCallback.init(self.dev.allocator(), self.dev);
        try socket_cb_write.subscribe_write(sbj);
        try socket_cb_read.subscribe_read(sbj);
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

    pub fn query_status_send(self: *@This()) !void {
        var in = bb.bb_get_status_in_t{
            .user_bmp = SLOT_BIT_MAP_MAX,
        };
        try self.dev.transmitWithPack(self.arena.allocator(), bb.BB_GET_STATUS, &in);
        const predicate = Self.make_reqid_predicate(bb.BB_GET_STATUS);
        var subject = self.dev.rxObservable();
        subject.subscribe(
            &predicate,
            &Self.query_status_on_data,
            &Self.query_status_on_error,
            self,
            null,
        ) catch unreachable;
    }
    pub const query_status_on_error = Self.make_generic_error_handler("failed to query status");
    pub fn query_status_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = Self.as(ud);
        const status = try pack.dataAs(bb.bb_get_status_out_t);
        bt.logWithStatus(self.dev.withSrcLogger(logz.info(), @src()), &status).log();
        try self.dev.arto.setWithBBStatus(&status);
        // ***** and_then *****
        try self.query_info_send();

        sbj.unsubscribe(obs) catch unreachable;
    }

    pub fn query_info_send(self: *@This()) !void {
        try self.dev.transmitWithPack(self.arena.allocator(), bb.BB_GET_SYS_INFO, null);
        const predicate = Self.make_reqid_predicate(bb.BB_GET_SYS_INFO);
        var subject = self.dev.rxObservable();
        subject.subscribe(
            &predicate,
            &Self.query_info_on_data,
            &Self.query_info_on_error,
            self,
            null,
        ) catch unreachable;
    }
    pub const query_info_on_error = Self.make_generic_error_handler("failed to query info");
    pub fn query_info_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        std.debug.assert(pack.sta == BB_STA_OK);
        const ud = obs.userdata;
        var self = Self.as(ud);
        const info = try pack.dataAs(bb.bb_get_sys_info_out_t);

        const compile_time: [*:0]const u8 = @ptrCast(&info.compile_time);
        const soft_ver: [*:0]const u8 = @ptrCast(&info.soft_ver);
        const hard_ver: [*:0]const u8 = @ptrCast(&info.hardware_ver);
        const firmware_ver: [*:0]const u8 = @ptrCast(&info.firmware_ver);
        self.dev.withSrcLogger(logz.info(), @src())
            .int("uptime", info.uptime)
            .stringSafeZ("compile_time", compile_time)
            .stringSafeZ("soft_ver", soft_ver)
            .stringSafeZ("hard_ver", hard_ver)
            .stringSafeZ("firmware_ver", firmware_ver)
            .log();

        sbj.unsubscribe(obs) catch unreachable;

        // ***** and_then *****
        try self.subscribe_event_no_response(.link_state);
        self.dev.waitForTxComplete();
        try self.subscribe_event_no_response(.mcs_change);
        self.dev.waitForTxComplete();
        try self.subscribe_event_no_response(.chan_change);
        self.dev.waitForTxComplete();
        try self.open_socket_send();
    }

    /// subscribe an event, don't care if it's successful or not.
    /// I don't care the response.
    /// without closure it's become tedious.
    pub fn subscribe_event_no_response(self: *@This(), event: bt.Event) !void {
        const req = bt.subscribeRequestId(event);
        try self.dev.transmitWithPack(self.arena.allocator(), req, null);
    }

    const OpenRequestId = bt.socketRequestId(.open, @intCast(BB_SEL_SLOT), @intCast(BB_SEL_PORT));
    const OpenSocketError = error{
        AlreadyOpened,
        Unspecified,
    };

    fn try_socket_open(self: *@This()) !void {
        const flag: u8 = @intCast(bb.BB_SOCK_FLAG_TX | bb.BB_SOCK_FLAG_RX);
        // see `session_socket.c:232`
        const buf = &[_]u8{
            flag, 0x00, 0x00, 0x00, // flags, with alignment
            0x00, 0x08, 0x00, 0x00, // 2048 in `bb.bb_sock_opt_t.tx_buf_size`
            0x00, 0x0c, 0x00, 0x00, // 3072 in `bb.bb_sock_opt_t.rx_buf_size`
        };
        try self.dev.transmitSliceWithPack(self.arena.allocator(), OpenRequestId, buf);
    }

    pub fn open_socket_send(self: *@This()) !void {
        try self.try_socket_open();
        var subject = self.dev.rxObservable();
        const predicate = Self.make_reqid_predicate(OpenRequestId);
        subject.subscribe(
            &predicate,
            &Self.open_socket_on_data,
            &Self.open_socket_on_error,
            self,
            null,
        ) catch unreachable;
    }
    pub const open_socket_on_error = Self.make_generic_error_handler("failed to open socket");
    pub fn open_socket_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        // if we must handle these shit
        // we'd better make a state machine
        const ud = obs.userdata;
        var self = Self.as(ud);
        switch (pack.sta) {
            BB_STA_OK => {
                try self.listen_to_socket();
                self.dev.withSrcLogger(logz.info(), @src())
                    .int("slot", BB_SEL_SLOT)
                    .int("port", BB_SEL_PORT)
                    .string("what", "socket opened")
                    .log();
            },
            BB_ERROR_ALREADY_OPENED_SOCKET => {
                try self.listen_to_socket();
                self.dev.withSrcLogger(logz.info(), @src())
                    .int("slot", BB_SEL_SLOT)
                    .int("port", BB_SEL_PORT)
                    .string("what", "reuse opened socket")
                    .log();
            },
            BB_ERROR_UNSPECIFIED => return OpenSocketError.Unspecified,
            else => std.debug.panic("unexpected status {d}", .{pack.sta}),
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
    const Self = @This();

    pub fn init(alloc: std.mem.Allocator, dev: *DeviceContext, transfer: *DeviceContext.Transfer, endpoint: Endpoint) !*Self {
        var ret = try alloc.create(@This());
        ret.alloc = alloc;
        ret.dev = dev;
        ret.transfer = transfer;
        ret.endpoint = endpoint;
        return ret;
    }

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
        var sync = &self.dev.xfer.tx_sync;
        {
            sync.mutex.lock();
            defer sync.mutex.unlock();
            sync.setFree(true);
        }
        sync.cv.signal();
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
                mpk.pack.withLogger(lg).log();
                self.dev.xfer.rx_queue.enqueue(mpk.*) catch |e| {
                    lg = utils.logWithSrc(self.dev.withLogger(logz.err()), @src());
                    lg.err(e).string("what", "failed to enqueue").log();
                    mpk.deinit();
                };
            } else |err| {
                lg = utils.logWithSrc(self.dev.withLogger(logz.err()), @src());
                lg.string("what", "failed to unmarshal")
                    .fmt("data", "{any}", .{rx_buf})
                    .err(err)
                    .log();
            }
        }

        // resubmit
        const errc = usb.libusb_submit_transfer(trans);
        if (errc == LIBUSB_OK) {
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
                    std.debug.panic("failed to resubmit transfer: {}", .{err});
                },
                else => {
                    std.debug.panic("failed to resubmit transfer: {}", .{err});
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
    if (ret != LIBUSB_OK) {
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
        dev.initialize() catch |e| {
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
