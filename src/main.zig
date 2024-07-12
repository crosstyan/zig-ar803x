const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");
const bb = @import("bb/c.zig");
const bt = @import("bb/t.zig");
const UsbPack = @import("bb/usbpack.zig").UsbPack;
const ManagedUsbPack = @import("bb/usbpack.zig").ManagedUsbPack;
const utils = @import("utils.zig");
const usb = @cImport({
    @cInclude("libusb.h");
});
const network = @import("network");

const BadEnum = utils.BadEnum;
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;
const XXHASH_SEED: u32 = 0x0;
const USB_MAX_PORTS = 8;
const TRANSFER_BUF_SIZE = 2048;
const DEFAULT_THREAD_STACK_SIZE = 16 * 1024 * 1024;
const MAX_SERIAL_SIZE = 32;
const REFRESH_CONTAINER_DEFAULT_CAP = 4;

const AppError = error{
    BadDescriptor,
    BadPortNumbers,
    BadEnum,
    Unknown,
};

const LibUsbError = error{
    IO,
    InvalidParam,
    Access,
    NoDevice,
    NotFound,
    Busy,
    Timeout,
    Overflow,
    Pipe,
    Interrupted,
    NoMem,
    NotSupported,
    Other,
    Unknown,
};

const TransmitError = error{
    Overflow,
    Busy,
};

const ClosedError = error{
    Closed,
};

pub fn libusb_error_2_set(err: c_int) LibUsbError {
    return switch (err) {
        usb.LIBUSB_ERROR_IO => LibUsbError.IO,
        usb.LIBUSB_ERROR_INVALID_PARAM => LibUsbError.InvalidParam,
        usb.LIBUSB_ERROR_ACCESS => LibUsbError.Access,
        usb.LIBUSB_ERROR_NO_DEVICE => LibUsbError.NoDevice,
        usb.LIBUSB_ERROR_NOT_FOUND => LibUsbError.NotFound,
        usb.LIBUSB_ERROR_BUSY => LibUsbError.Busy,
        usb.LIBUSB_ERROR_TIMEOUT => LibUsbError.Timeout,
        usb.LIBUSB_ERROR_OVERFLOW => LibUsbError.Overflow,
        usb.LIBUSB_ERROR_PIPE => LibUsbError.Pipe,
        usb.LIBUSB_ERROR_INTERRUPTED => LibUsbError.Interrupted,
        usb.LIBUSB_ERROR_NO_MEM => LibUsbError.NoMem,
        usb.LIBUSB_ERROR_NOT_SUPPORTED => LibUsbError.NotSupported,
        usb.LIBUSB_ERROR_OTHER => LibUsbError.Other,
        else => std.debug.panic("unknown libusb error code: {}", .{err}),
    };
}

fn LockedQueue(comptime T: type, comptime max_size: usize) type {
    const LockedQueueImpl = struct {
        const MAX_SIZE = max_size;
        const Self = @This();

        /// should be false until `deinit` is called
        _has_deinit: std.atomic.Value(bool),
        /// WARNING: don't use it directly
        _list: std.ArrayList(T),
        /// used when modifying the `_list`
        lock: RwLock = RwLock{},

        /// used with `cv` to signal the `dequeue`, different from `lock`
        mutex: Mutex = Mutex{},
        cv: std.Thread.Condition = std.Thread.Condition{},
        /// function to call when removing an element.
        /// Only useful when the queue is full, and needs to discard old
        /// elements.
        elem_dtor: ?*const fn (*T) void = null,

        pub fn init(alloc: std.mem.Allocator) Self {
            var l = std.ArrayList(T).init(alloc);
            l.ensureTotalCapacity(max_size) catch @panic("OOM");
            return Self{
                ._list = l,
                ._has_deinit = std.atomic.Value(bool).init(false),
            };
        }

        pub fn hasDeinit(self: *const @This()) bool {
            return self._has_deinit.load(std.builtin.AtomicOrder.unordered);
        }

        pub fn deinit(self: *@This()) void {
            self._has_deinit.store(true, std.builtin.AtomicOrder.unordered);
            self.cv.broadcast();
            self._list.deinit();
        }

        pub fn enqueue(self: *@This(), pkt: T) ClosedError!void {
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            {
                self.lock.lockShared();
                defer self.lock.unlockShared();
                while (self.lenNoCheck() >= MAX_SIZE) {
                    utils.logWithSrc(logz.warn(), @src())
                        .string("what", "full queue, discarding old element").log();
                    var elem = self._list.orderedRemove(0);
                    if (self.elem_dtor) |dtor| {
                        dtor(&elem);
                    }
                }
                self._list.append(pkt) catch @panic("OOM");
            }
            self.cv.signal();
        }

        inline fn lenNoCheck(self: *const @This()) usize {
            return self._list.items.len;
        }

        inline fn isEmptyNoCheck(self: *const @This()) bool {
            return self.lenNoCheck() == 0;
        }

        /// return the length of the queue
        pub inline fn len(self: *@This()) ClosedError!usize {
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            self.lock.lock();
            defer self.lock.unlock();
            return self.lenNoCheck();
        }

        /// return whether the queue is empty
        pub inline fn isEmpty(self: *@This()) ClosedError!bool {
            return try self.len() == 0;
        }

        pub fn peek(self: *@This()) ClosedError!?T {
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            self.lock.lock();
            defer self.lock.unlock();
            if (self._list.len == 0) {
                return null;
            } else {
                const ret = self._list.items[0];
                return ret;
            }
        }

        /// note that this function will block indefinitely
        /// until the queue is not empty
        pub fn dequeue(self: *@This()) ClosedError!T {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            while (self.isEmptyNoCheck()) {
                if (self.hasDeinit()) {
                    return ClosedError.Closed;
                }
                self.cv.wait(&self.mutex);
            }
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            self.lock.lockShared();
            defer self.lock.unlockShared();
            const ret = self._list.items[0];
            _ = self._list.orderedRemove(0);
            return ret;
        }
    };
    return LockedQueueImpl;
}

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

        pub fn deinit(self: *@This()) void {
            self.tx_transfer.deinit();
            self.rx_transfer.deinit();
            self.rx_queue.deinit();
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
        // somehow the `ctrl_queue` is not happy with allocated with allocator in
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
    pub inline fn receive(self: *@This()) ClosedError!ManagedUsbPack {
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

    fn initEndpoints(self: *@This()) void {
        for (self.endpoints) |*ep| {
            if (ep.direction == Direction.out and ep.transferType == TransferType.bulk) {
                self.initTransferTx(ep);
            } else if (ep.direction == Direction.in and ep.transferType == TransferType.bulk) {
                self.initTransferRx(ep);
            }
        }
    }

    /// doing status query before start forward loop,
    /// and it still NEEDS event loop running. Please call it in a separate thread.
    fn loopPrepare(self: *@This()) void {
        const BUFFER_SIZE = 8192;
        var stack_buf: [BUFFER_SIZE]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(stack_buf[0..]);
        var arena = std.heap.ArenaAllocator.init(fixed.allocator());
        defer arena.deinit();
        const stack_allocator = arena.allocator();

        const local_t = struct {
            stack_allocator: std.mem.Allocator,
            self: *DeviceContext,

            // payload should be a pointer to struct, or null
            pub fn query_common(cap: *@This(), reqid: u32, payload: anytype) !ManagedUsbPack {
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
                const data = try pack.marshal(cap.stack_allocator);
                defer cap.stack_allocator.free(data);
                try cap.self.transmit(data);

                return try cap.self.receive();
            }

            // like `query_common`, but with a slice payload
            pub fn query_common_slice(cap: *@This(), reqid: u32, payload: []const u8) !ManagedUsbPack {
                var pack = UsbPack{
                    .reqid = reqid,
                    .msgid = 0,
                    .sta = 0,
                };
                pack.ptr = payload.ptr;
                pack.len = @intCast(payload.len);
                const data = try pack.marshal(cap.stack_allocator);
                defer cap.stack_allocator.free(data);
                std.debug.print("data {s}\n", .{std.fmt.fmtSliceHexLower(data)});
                try cap.self.transmit(data);

                return try cap.self.receive();
            }

            // query status
            pub fn query_status(cap: *@This()) !void {
                var in = bb.bb_get_status_in_t{
                    .user_bmp = SLOT_BIT_MAP_MAX,
                };
                var mpk = try cap.query_common(bb.BB_GET_STATUS, &in);
                defer mpk.deinit();
                std.debug.assert(mpk.pack.sta == 0);
                const status = try mpk.dataAs(bb.bb_get_status_out_t);
                bt.logWithStatus(cap.self.withSrcLogger(logz.info(), @src()), &status).log();
            }

            // query system info (build time, version, etc.)
            pub fn query_info(cap: *@This()) !void {
                var mpk = try cap.query_common(bb.BB_GET_SYS_INFO, null);
                defer mpk.deinit();
                std.debug.assert(mpk.pack.sta == 0);
                const info = try mpk.dataAs(bb.bb_get_sys_info_out_t);
                const compile_time: [*:0]const u8 = @ptrCast(&info.compile_time);
                const soft_ver: [*:0]const u8 = @ptrCast(&info.soft_ver);
                const hard_ver: [*:0]const u8 = @ptrCast(&info.hardware_ver);
                const firmware_ver: [*:0]const u8 = @ptrCast(&info.firmware_ver);
                cap.self.withSrcLogger(logz.info(), @src())
                    .int("uptime", info.uptime)
                    .stringSafeZ("compile_time", compile_time)
                    .stringSafeZ("soft_ver", soft_ver)
                    .stringSafeZ("hard_ver", hard_ver)
                    .stringSafeZ("firmware_ver", firmware_ver).log();
            }

            pub fn subscribe_event(cap: *@This(), event: bt.Event) !void {
                const req = bt.subscribeRequestId(event);
                var mpk = try cap.query_common(req, null);
                defer mpk.deinit();
                std.debug.assert(mpk.pack.sta == 0);
                cap.self.withSrcLogger(logz.info(), @src())
                    .string("what", "subscribed event")
                    .string("event", @tagName(event)).log();
            }

            const sel_slot = bb.BB_SLOT_AP;
            const sel_port = 3;

            fn try_socket_open(cap: *@This()) !ManagedUsbPack {
                const req = bt.socketRequestId(.open, @intCast(sel_slot), @intCast(sel_port));
                const flag: u8 = @intCast(bb.BB_SOCK_FLAG_TX | bb.BB_SOCK_FLAG_RX);
                // see `session_socket.c:232`
                // TODO: create a wrapper struct
                const buf = &[_]u8{
                    flag, 0x00, 0x00, 0x00, // flags, with alignment
                    0x00, 0x08, 0x00, 0x00, // 2048 in `bb.bb_sock_opt_t.tx_buf_size`
                    0x00, 0x0c, 0x00, 0x00, // 3072 in `bb.bb_sock_opt_t.rx_buf_size`
                };
                const mpk = try cap.query_common_slice(req, buf);
                return mpk;
            }

            pub fn open_socket(cap: *@This()) !void {
                // note that sta == 0x0101 (i.e. 257) means already opened socket
                const ERROR_ALREADY_OPENED_SOCKET = 257;
                // -259 is a generic error code, I have no idea what's the exact meaning
                const ERROR_UNKNOWN = -259;
                _ = ERROR_UNKNOWN;

                var mpk = try cap.try_socket_open();
                defer mpk.deinit();
                const sta = mpk.pack.sta;
                if (sta == 0) {
                    cap.self.withSrcLogger(logz.info(), @src())
                        .int("slot", sel_slot)
                        .int("port", sel_port)
                        .string("what", "socket opened")
                        .log();
                    return;
                }
                if (sta == ERROR_ALREADY_OPENED_SOCKET) {
                    cap.self.withSrcLogger(logz.warn(), @src())
                        .int("slot", sel_slot)
                        .int("port", sel_port)
                        .string("what", "socket already opened")
                        .log();
                    try cap.close_socket();
                    cap.self.withSrcLogger(logz.warn(), @src())
                        .int("slot", sel_slot)
                        .int("port", sel_port)
                        .string("what", "close opened socket")
                        .log();

                    var i_mpk = try cap.try_socket_open();
                    defer i_mpk.deinit();
                    const i_sta = i_mpk.pack.sta;
                    if (i_sta == 0) {
                        cap.self.withSrcLogger(logz.warn(), @src())
                            .int("slot", sel_slot)
                            .int("port", sel_port)
                            .string("what", "reopen socket")
                            .log();
                        return;
                    } else {
                        std.debug.panic("failed to reopen socket, sta={d}", .{i_sta});
                    }
                }
                std.debug.panic("failed to open socket, sta={d}", .{sta});
            }

            pub fn close_socket(cap: *@This()) !void {
                const req = bt.socketRequestId(.close, @intCast(sel_slot), @intCast(sel_port));
                const flag: u8 = @intCast(bb.BB_SOCK_FLAG_TX | bb.BB_SOCK_FLAG_RX);
                const buf = &[_]u8{
                    flag, 0x00, 0x00, 0x00, // flags, with alignment
                    0x00, 0x08, 0x00, 0x00, // 2048 in `bb.bb_sock_opt_t.tx_buf_size`
                    0x00, 0x0c, 0x00, 0x00, // 3072 in `bb.bb_sock_opt_t.rx_buf_size`
                };
                var mpk = try cap.query_common_slice(req, buf);
                defer mpk.deinit();
                std.debug.assert(mpk.pack.sta == 0);
            }
        };

        var local = local_t{
            .stack_allocator = stack_allocator,
            .self = self,
        };
        local.query_status() catch unreachable;
        local.query_info() catch unreachable;
        local.subscribe_event(.link_state) catch unreachable;
        local.subscribe_event(.mcs_change) catch unreachable;
        local.subscribe_event(.chan_change) catch unreachable;
        local.open_socket() catch unreachable;

        utils.logWithSrc(self.withLogger(logz.info()), @src())
            .string("what", "preparing finished").log();
        // finally, we start the loop thread, after querying status
        // and set callback etc.
        self.initThreads();
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
    }

    pub fn sendLoop(self: *@This()) void {
        const BUFFER_SIZE = 4096;
        var stack_buf: [BUFFER_SIZE]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(stack_buf[0..]);
        var stack_allocator = fixed.allocator();
        while (true) {
            var in = bb.bb_get_status_in_t{
                .user_bmp = SLOT_BIT_MAP_MAX,
            };

            var pack = UsbPack{
                .reqid = bb.BB_GET_STATUS,
                .msgid = 0,
                .sta = 0,
            };
            pack.fillWith(&in) catch unreachable;

            const data = pack.marshal(stack_allocator) catch unreachable;
            defer stack_allocator.free(data);

            self.transmit(data) catch |e| {
                var lg = utils.logWithSrc(self.withLogger(logz.err()), @src());
                lg.err(e)
                    .string("what", "failed to transmit, exiting thread")
                    .log();
                return;
            };
            std.time.sleep(1000 * std.time.ns_per_ms);
        }
    }

    pub fn recvLoop(self: *@This()) void {
        while (true) {
            var mpk = self.receive() catch |e| {
                var lg = utils.logWithSrc(self.withLogger(logz.err()), @src());
                lg.err(e)
                    .string("what", "failed to dequeue, exiting thread")
                    .log();
                return;
            };
            defer mpk.deinit();
            var lg = utils.logWithSrc(self.withLogger(logz.info()), @src());
            lg.string("what", "received packet")
                .log();
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

pub fn logWithDevice(logger: logz.Logger, device: *usb.libusb_device, desc: *const usb.libusb_device_descriptor) logz.Logger {
    const vid = desc.idVendor;
    const pid = desc.idProduct;
    const bus = usb.libusb_get_bus_number(device);
    const port = usb.libusb_get_port_number(device);
    return logger
        .fmt("vid", "0x{x:0>4}", .{vid})
        .fmt("pid", "0x{x:0>4}", .{pid})
        .int("bus", bus)
        .int("port", port);
}

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
                    if (ret != 0) {
                        continue;
                    }
                    if (l_desc.idVendor == ARTO_RTOS_VID and l_desc.idProduct == ARTO_RTOS_PID) {
                        const dd = DeviceDesc.fromDevice(val) catch {
                            continue;
                        };
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
                _ = ctx_list.orderedRemove(index);
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

pub inline fn usbEndpointNum(ep_addr: u8) u8 {
    return ep_addr & 0x07;
}

pub inline fn usbEndpointTransferType(ep_attr: u8) u8 {
    return ep_attr & @as(u8, usb.LIBUSB_TRANSFER_TYPE_MASK);
}

const Direction = enum {
    in,
    out,
};

const TransferType = enum {
    control,
    isochronous,
    bulk,
    interrupt,
};

const Endpoint = struct {
    /// config index
    iConfig: u8,
    /// interface index
    iInterface: u8,
    addr: u8,
    number: u8,
    direction: Direction,
    transferType: TransferType,
    maxPacketSize: u16,

    pub fn fromDesc(iConfig: u8, iInterface: u8, ep: *const usb.libusb_endpoint_descriptor) AppError!Endpoint {
        const local_t = struct {
            pub inline fn addr_to_dir(addr: u8) BadEnum!Direction {
                const dir = addr & usb.LIBUSB_ENDPOINT_DIR_MASK;
                const r = switch (dir) {
                    usb.LIBUSB_ENDPOINT_IN => Direction.in,
                    usb.LIBUSB_ENDPOINT_OUT => Direction.out,
                    else => return BadEnum.BadEnum,
                };
                return r;
            }
            pub inline fn attr_to_transfer_type(attr: u8) BadEnum!TransferType {
                const r = switch (usbEndpointTransferType(attr)) {
                    usb.LIBUSB_TRANSFER_TYPE_CONTROL => TransferType.control,
                    usb.LIBUSB_TRANSFER_TYPE_ISOCHRONOUS => TransferType.isochronous,
                    usb.LIBUSB_TRANSFER_TYPE_BULK => TransferType.bulk,
                    usb.LIBUSB_TRANSFER_TYPE_INTERRUPT => TransferType.interrupt,
                    else => return BadEnum.BadEnum,
                };
                return r;
            }
        };
        return Endpoint{
            .iConfig = iConfig,
            .iInterface = iInterface,
            .addr = ep.bEndpointAddress,
            .number = usbEndpointNum(ep.bEndpointAddress),
            .direction = try local_t.addr_to_dir(ep.bEndpointAddress),
            .transferType = try local_t.attr_to_transfer_type(ep.bmAttributes),
            .maxPacketSize = ep.wMaxPacketSize,
        };
    }

    pub fn withLogger(self: *const Endpoint, logger: logz.Logger) logz.Logger {
        return logger
            .int("interface", self.iInterface)
            .int("endpoint", self.number)
            .fmt("address", "0x{x:0>2}", .{self.addr})
            .string("direction", @tagName(self.direction))
            .string("transfer_type", @tagName(self.transferType));
    }
};

pub fn getEndpoints(alloc: std.mem.Allocator, device: *usb.libusb_device, ldesc: *const usb.libusb_device_descriptor) []Endpoint {
    var ret: c_int = undefined;
    var list = std.ArrayList(Endpoint).init(alloc);
    defer list.deinit();
    const n_config = ldesc.bNumConfigurations;
    for (0..n_config) |i| {
        var config_: ?*usb.libusb_config_descriptor = undefined;
        ret = usb.libusb_get_config_descriptor(device, @intCast(i), &config_);
        if (ret != 0) {
            continue;
        }
        if (config_) |config| {
            const ifaces = config.interface[0..@intCast(config.bNumInterfaces)];
            for (ifaces) |iface_alt| {
                const iface_alts = iface_alt.altsetting[0..@intCast(iface_alt.num_altsetting)];
                if (iface_alts.len == 0) {
                    continue;
                }

                // I don't really care alternate setting. Take the first one
                const iface = iface_alts[0];
                const endpoints = iface.endpoint[0..@intCast(iface.bNumEndpoints)];
                for (endpoints) |ep| {
                    const app_ep = Endpoint.fromDesc(@intCast(i), iface.bInterfaceNumber, &ep) catch |e| {
                        logWithDevice(logz.err(), device, ldesc).err(e).log();
                        continue;
                    };
                    list.append(app_ep) catch @panic("OOM");
                }
            }
        }
    }
    return list.toOwnedSlice() catch @panic("OOM");
}

pub fn printEndpoints(vid: u16, pid: u16, endpoints: []const Endpoint) void {
    for (endpoints) |ep| {
        logz.info()
            .fmt("vid", "0x{x:0>4}", .{vid})
            .fmt("pid", "0x{x:0>4}", .{pid})
            .int("config", ep.iConfig)
            .int("interface", ep.iInterface)
            .int("endpoint", ep.number)
            .fmt("address", "0x{x:0>2}", .{ep.addr})
            .string("direction", @tagName(ep.direction))
            .string("transfer_type", @tagName(ep.transferType))
            .int("max_packet_size", ep.maxPacketSize).log();
    }
}

// libusb_fill_bulk_transfer
// https://libusb.sourceforge.io/api-1.0/group__libusb__asyncio.html
// https://libusb.sourceforge.io/api-1.0/libusb_io.html
//
// In the interest of being a lightweight library, libusb does not
// create threads and can only operate when your application is
// calling into it. Your application must call into libusb from it's
// main loop when events are ready to be handled, or you must use
// some other scheme to allow libusb to undertake whatever work
// needs to be done.
const TransferCallback = struct {
    alloc: std.mem.Allocator,
    /// reference, not OWNED
    dev: *DeviceContext,
    /// reference, not OWNED
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

        // resubmit the transfer
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

/// Get a string descriptor or return a default value
pub fn dynStringDescriptorOr(alloc: std.mem.Allocator, hdl: *usb.libusb_device_handle, idx: u8, default: []const u8) []const u8 {
    const BUF_SIZE = 128;
    var buf: [BUF_SIZE]u8 = undefined;
    const sz: c_int = usb.libusb_get_string_descriptor_ascii(hdl, idx, &buf, @intCast(buf.len));
    if (sz > 0) {
        var dyn_str = alloc.alloc(u8, @intCast(sz)) catch @panic("OOM");
        @memcpy(dyn_str, buf[0..@intCast(sz)]);
        dyn_str.len = @intCast(sz);
        return dyn_str;
    } else {
        var dyn_str = alloc.alloc(u8, default.len) catch @panic("OOM");
        @memcpy(dyn_str, default);
        dyn_str.len = default.len;
        return dyn_str;
    }
}

/// Print the manufacturer, product, serial number of a device.
/// If a string descriptor is not available, 'N/A' will be display.
fn printStrDesc(hdl: *usb.libusb_device_handle, desc: *const usb.libusb_device_descriptor) void {
    const local_t = struct {
        /// Get string descriptor or return a default value.
        /// Note that the caller must ensure the buffer is large enough.
        /// The return slice will be a slice of the buffer.
        pub fn get_string_descriptor_or(lhdl: *usb.libusb_device_handle, idx: u8, buf: []u8, default: []const u8) []const u8 {
            var lsz: c_int = undefined;
            lsz = usb.libusb_get_string_descriptor_ascii(lhdl, idx, buf.ptr, @intCast(buf.len));
            if (lsz > 0) {
                return buf[0..@intCast(lsz)];
            } else {
                return default;
            }
        }
    };

    const BUF_SIZE = 128;
    var manufacturer_buf: [BUF_SIZE]u8 = undefined;
    const manufacturer = local_t.get_string_descriptor_or(hdl, desc.iManufacturer, &manufacturer_buf, "N/A");

    var product_buf: [BUF_SIZE]u8 = undefined;
    const product = local_t.get_string_descriptor_or(hdl, desc.iProduct, &product_buf, "N/A");

    var serial_buf: [BUF_SIZE]u8 = undefined;
    const serial = local_t.get_string_descriptor_or(hdl, desc.iSerialNumber, &serial_buf, "N/A");
    logz.info()
        .fmt("vid", "0x{x:0>4}", .{desc.idVendor})
        .fmt("pid", "0x{x:0>4}", .{desc.idProduct})
        .string("manufacturer", manufacturer)
        .string("product", product)
        .string("serial", serial).log();
}

pub fn usbSpeedToString(speed: c_int) []const u8 {
    const r = switch (speed) {
        usb.LIBUSB_SPEED_UNKNOWN => "UNKNOWN",
        usb.LIBUSB_SPEED_LOW => "LOW",
        usb.LIBUSB_SPEED_FULL => "FULL",
        usb.LIBUSB_SPEED_HIGH => "HIGH",
        usb.LIBUSB_SPEED_SUPER => "SUPER",
        usb.LIBUSB_SPEED_SUPER_PLUS => "SUPER_PLUS",
        else => "INVALID",
    };
    return r;
}

const TransferStatus = enum {
    completed,
    err,
    timed_out,
    cancelled,
    stall,
    no_device,
    overflow,
};

pub fn transferStatusFromInt(status: c_uint) BadEnum!TransferStatus {
    return switch (status) {
        usb.LIBUSB_TRANSFER_COMPLETED => TransferStatus.completed,
        usb.LIBUSB_TRANSFER_ERROR => TransferStatus.err,
        usb.LIBUSB_TRANSFER_TIMED_OUT => TransferStatus.timed_out,
        usb.LIBUSB_TRANSFER_CANCELLED => TransferStatus.cancelled,
        usb.LIBUSB_TRANSFER_STALL => TransferStatus.stall,
        usb.LIBUSB_TRANSFER_NO_DEVICE => TransferStatus.no_device,
        usb.LIBUSB_TRANSFER_OVERFLOW => TransferStatus.overflow,
        else => return BadEnum.BadEnum,
    };
}

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
