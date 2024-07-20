const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");
const bb = @import("bb/t.zig");
const c = bb.c;
const UsbPack = @import("bb/usbpack.zig").UsbPack;
const ManagedUsbPack = @import("bb/usbpack.zig").ManagedUsbPack;
const utils = @import("utils.zig");
const common = @import("app_common.zig");
const network = @import("network");
const helper = @import("libusb_helper.zig");
const usb = helper.c;
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
const UsbSpeed = helper.Speed;
const getEndpoints = helper.getEndpoints;
const printEndpoints = helper.printEndpoints;
const transferStatusFromInt = helper.transferStatusFromInt;
const dynStringDescriptorOr = helper.dynStringDescriptorOr;
const printStrDesc = helper.printStrDesc;
const libusb_error_2_set = helper.libusb_error_2_set;

const ArtoStatus = bb.Status;

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
const BB_STA_OK = bb.STA_OK;
const LIBUSB_OK = helper.LIBUSB_OK;
const BB_SEL_SLOT = c.BB_SLOT_0;
const BB_SEL_PORT = 3;
const BB_ERROR_ALREADY_OPENED_SOCKET = 257;
const BB_ERROR_UNSPECIFIED = -259; // unspecified error, only vendor knows
// See `dev_dat_so_write_proc` in `sock_node.c`.
const BB_SOCKET_SEND_OK: i32 = -0x106;
const BB_SOCKET_SEND_NEED_UPDATE_ADDR: i32 = -0x107; // 强制更新写入地址
const BB_SOCKET_SEND_ERROR: i32 = -0x108;
const BB_SOCKET_TX_BUFFER = 2048;
const BB_SOCKET_RX_BUFFER = 3072;
// debug related packet
// See `BB_REQ_DBG`
//
// /**定义debug 通道 msgid*/
// typedef enum {
//     BB_DBG_CLIENT_CHANGE,
//     BB_DBG_DATA,
//     BB_DBG_MAX,
// } bb_debug_id_e;
const BB_REQID_DEBUG_CLIENT_CHANGE = 0x05000000;
const BB_REQID_DEBUG_DATA = 0x05000001;

const GlobalConfig = struct {
    /// whether log the content when `tx`/`rx` involve (raw packet, including the `UsbPack` header)
    const is_log_content: bool = false;
    /// whether log the content when logging the `UsbPack`
    const is_log_packet_content: bool = false;
    /// whether enable the debug callback for AR8030.
    /// The debug message will be printed to `stdout` directly.
    const is_enable_ar8030_debug_callback: bool = false;
    const is_start_test_send_loop = false;
};
const is_windows = builtin.os.tag == .windows;

const DeviceGPA = std.heap.GeneralPurposeAllocator(.{
    .thread_safe = true,
});
const UsbPackQueue = LockedQueue(ManagedUsbPack, 8);

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

    pub const Predicate = Observer.Predicate;
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
        pub const MAX_NAME_LEN = 24;
        pub const Predicate = union(enum) { func: PredicateFnPtr, reqid: u32 };
        /// expected zero-terminated string
        name_buf_z: [MAX_NAME_LEN + 1]u8 = std.mem.zeroes([MAX_NAME_LEN + 1]u8),
        predicate: Observer.Predicate,
        /// the callback function SHOULD NOT block
        on_data: OnDataFnPtr,
        on_error: NullableOnErrorFnPtr,
        userdata: ?*anyopaque,
        dtor: NullableDtorPtr,

        pub fn name(self: *const @This()) [*:0]const u8 {
            return @ptrCast(&self.name_buf_z);
        }

        /// hashing the pointer, don't ask me why it's useful
        pub fn xxhash(self: *const @This()) u32 {
            var h = std.hash.XxHash32.init(XXHASH_SEED);
            switch (self.predicate) {
                .func => |f| {
                    const predicate_addr = @intFromPtr(f);
                    h.update(utils.anytype2Slice(&predicate_addr));
                },
                .reqid => |id| h.update(utils.anytype2Slice(&id)),
            }
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
    /// internal list of observers.
    /// user SHOULD NOT interact with it directly
    _list: std.ArrayList(Observer),
    _lk: RwLock = RwLock{},
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
    ///   - `name`: the name of the observer, only for debug purpose, won't be hashed
    ///   - `predicate`: a function to determine whether the observer should be notified, or a `reqid`
    ///   - `on_data`: the callback function when the observer is notified, could return `anyerror`
    ///   - `on_error`: the callback function when `on_data` returns an error
    ///   - `userdata`: closure
    ///   - `dtor`: destructor for the closure, optional
    ///
    /// Note that if the `name` is longer than `Observer.MAX_NAME_LEN`, it will be truncated silently.
    pub fn subscribe(
        self: *@This(),
        name: []const u8,
        predicate: Predicate,
        on_data: OnDataFnPtr,
        on_error: NullableOnErrorFnPtr,
        userdata: ?*anyopaque,
        dtor: NullableDtorPtr,
    ) !void {
        var obs = Observer{
            .predicate = predicate,
            .on_data = on_data,
            .on_error = on_error,
            .userdata = userdata,
            .dtor = dtor,
        };

        if (name.len > Observer.MAX_NAME_LEN) {
            @memcpy(obs.name_buf_z[0..Observer.MAX_NAME_LEN], name[0..Observer.MAX_NAME_LEN]);
            utils.logWithSrc(logz.warn(), @src())
                .string("what", "observer name is too long, will be truncated")
                .string("name", name)
                .fmt("len", "{}", .{name.len})
                .stringZ("truncated", obs.name())
                .log();
        } else {
            @memcpy(obs.name_buf_z[0..name.len], name);
        }
        const h = obs.xxhash();

        {
            self._lk.lock();
            defer self._lk.unlock();
            for (self._list.items) |*o| {
                if (o.xxhash() == h) {
                    return ObserverError.Existed;
                }
            }
        }

        self._lk.lockShared();
        defer self._lk.unlockShared();
        try self._list.append(obs);
    }

    /// dispatch the packet to the observers
    pub fn update(self: *@This(), pack: *const UsbPack) void {
        // explicit no lock here
        var cnt: usize = 0;
        for (self._list.items) |*o| {
            var ok: bool = undefined;
            switch (o.predicate) {
                .func => |f| {
                    ok = f(pack, o.userdata);
                },
                .reqid => |id| {
                    ok = pack.reqid == id;
                },
            }
            if (ok) {
                o.on_data(self, pack, o) catch |e| {
                    if (o.on_error) |on_err| {
                        on_err(self, pack, o, e);
                    } else {
                        const h = o.xxhash();
                        var lg = pack.withLogger(utils.logWithSrc(logz.err(), @src())
                            .string("what", "unhandled observer error")
                            .stringZ("name", o.name())
                            .fmt("hash", "0x{x:0>8}", .{h}), GlobalConfig.is_log_packet_content)
                            .err(e);
                        switch (o.predicate) {
                            .func => {},
                            .reqid => |id| lg = lg.fmt("reqid", "0x{x:0>8}", .{id}),
                        }
                        lg.log();
                    }
                };
                cnt += 1;
            }
        }

        if (cnt == 0) {
            pack.withLogger(utils.logWithSrc(logz.warn(), @src()), GlobalConfig.is_log_packet_content)
                .string("what", "no observer is notified").log();
        }
    }

    pub inline fn unsubscribe(self: *@This(), obs: *const Observer) ObserverError!void {
        return self.unsubscribeByHash(obs.xxhash());
    }

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

        self._lk.lockShared();
        var el = self._list.swapRemove(@intCast(idx));
        self._lk.unlockShared();
        el.deinit();
    }

    /// unsubscribe all observers
    pub fn unsubscribeAll(self: *@This()) void {
        self.deinit();
        self._list = std.ArrayList(Observer).init(self.allocator);
    }

    pub fn deinit(self: *@This()) void {
        self._lk.lockShared();
        defer self._lk.lockShared();

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

        pub inline fn setLength(self: *@This(), len: u32) AppError!void {
            if (len > TRANSFER_BUF_SIZE) {
                return AppError.Overflow;
            }
            self.self.length = @intCast(len);
        }

        /// ONLY used in RX transfer, use `actual_length`
        /// as the length of slice
        pub inline fn rxBuf(self: *@This()) []const u8 {
            return self.buf[0..@intCast(self.self.actual_length)];
        }

        /// ONLY used in TX transfer, use `length` as
        /// the length of slice
        pub inline fn txBuf(self: *@This()) []const u8 {
            return self.buf[0..@intCast(self.self.length)];
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

        inline fn dev(self: *@This()) *DeviceContext {
            return @fieldParentPtr("xfer", self);
        }

        pub fn initThreads(self: *@This()) void {
            const alloc = self.dev().allocator();
            const config = std.Thread.SpawnConfig{
                .stack_size = DEFAULT_THREAD_STACK_SIZE,
                .allocator = alloc,
            };
            self.rx_thread = std.Thread.spawn(config, DeviceContext.recvLoop, .{self.dev()}) catch unreachable;
            self.rx_observable = PackObserverList.init(alloc);
            if (GlobalConfig.is_start_test_send_loop) {
                self.tx_thread = std.Thread.spawn(config, DeviceContext.testSendLoop, .{self.dev()}) catch unreachable;
            }
        }

        pub fn deinit(self: *@This()) void {
            self.tx_transfer.deinit();
            self.rx_transfer.deinit();
            self.rx_queue.deinit();
            self.rx_observable.deinit();
            self.rx_thread.join();
            if (GlobalConfig.is_start_test_send_loop) {
                self.tx_thread.join();
            }
        }
    };

    const ArtoContext = struct {
        const NEVER_UPDATED = 0;
        _status: ArtoStatus = undefined,
        /// seconds UNIX timestamp when the status is updated
        _last_status_updated: i64 = NEVER_UPDATED,
        _magic_socket: MagicSocket = undefined,

        const UpdateStatusCallback = struct {
            dev: *DeviceContext,
            const Observer = PackObserverList.Observer;

            pub fn create(arg_dev: *DeviceContext) !*@This() {
                var self = try arg_dev.allocator().create(@This());
                self.dev = arg_dev;
                return self;
            }

            pub fn subscribe(self: *@This()) !void {
                const Callback = @This();
                const predicate = Observer.Predicate{ .reqid = c.BB_GET_STATUS };
                var subject = self.dev.rxObservable();
                try subject.subscribe(
                    "status",
                    predicate,
                    &Callback.onData,
                    null,
                    self,
                    @ptrCast(&Callback.deinit),
                );
            }

            pub fn deinit(self: *@This()) void {
                self.dev.allocator().destroy(self);
            }

            pub fn onData(_: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
                const ud = obs.userdata;
                var self = utils.as(@This(), ud);
                const st = try pack.dataAs(c.bb_get_status_out_t);
                bb.logWithStatus(self.dev.withSrcLogger(logz.info(), @src()), &st).log();
                try self.dev.arto.setWithBBStatus(&st);
            }
        };

        inline fn dev(self: *@This()) *DeviceContext {
            return @fieldParentPtr("arto", self);
        }

        pub inline fn initCallback(self: *@This()) !void {
            var cb = try UpdateStatusCallback.create(self.dev());
            try cb.subscribe();
        }

        pub inline fn status(self: *const @This()) ?*const ArtoStatus {
            if (self._last_status_updated == NEVER_UPDATED) {
                return null;
            }
            return &self._status;
        }

        pub inline fn setWithBBStatus(self: *@This(), new_bb_status: *const c.bb_get_status_out_t) !void {
            const new_status = try bb.Status.fromC(new_bb_status);
            self.setStatus(&new_status);
        }

        pub inline fn setStatus(self: *@This(), new_status: *const ArtoStatus) void {
            self._status = new_status.*;
            self._last_status_updated = std.time.timestamp();
        }
    };

    /// `MagicSocket` refers to the Arto's socket
    const MagicSocket = struct {
        // should only be SET BY CALLBACK
        _is_open: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
        _slot: u8,
        _port: u8,
        _position: u64 = 0,
        _dev: *DeviceContext,

        const flag: u8 = @intCast(c.BB_SOCK_FLAG_TX | c.BB_SOCK_FLAG_RX);
        const common_payload = &[_]u8{
            flag, 0x00, 0x00, 0x00, // flags, with alignment
            0x00, 0x08, 0x00, 0x00, // 2048 in `bb.bb_sock_opt_t.tx_buf_size`
            0x00, 0x0c, 0x00, 0x00, // 3072 in `bb.bb_sock_opt_t.rx_buf_size`
        };

        pub inline fn isOpen(self: *const @This()) bool {
            return self._is_open.load(std.builtin.AtomicOrder.unordered);
        }

        pub inline fn setOpen(self: *@This(), open: bool) void {
            self._is_open.store(open, std.builtin.AtomicOrder.unordered);
        }

        pub inline fn position(self: *const @This()) u64 {
            return self._position;
        }

        pub fn withLogger(self: *const @This(), logger: logz.Logger) logz.Logger {
            return logger
                .int("slot", self._slot)
                .int("port", self._port);
        }

        pub inline fn initialize(self: *@This(), arg_dev: *DeviceContext, slot: u8, port: u8) void {
            self._is_open.store(false, std.builtin.AtomicOrder.unordered);
            self._slot = slot;
            self._port = port;
            self._dev = arg_dev;
            self._position = 0;
        }

        pub inline fn requestId(self: *const @This(), opt: bb.SoCmdOpt) u32 {
            return bb.socketRequestId(opt, self._slot, self._port);
        }

        pub inline fn movePosition(self: *@This(), offset: u64) void {
            self._position += offset;
        }

        pub inline fn resetPosition(self: *@This()) void {
            self._position = 0;
        }

        pub fn trySocketOpen(self: *@This()) !void {
            // see `session_socket.c:232`
            const OpenRequestId = self.requestId(.open);
            try self._dev.transmitSliceWithPack(self._dev.allocator(), OpenRequestId, common_payload);
        }

        pub fn trySocketClose(self: *@This()) !void {
            const CloseRequestId = self.requestId(.close);
            try self._dev.transmitSliceWithPack(self._dev.allocator(), CloseRequestId, common_payload);
        }
    };

    /// one should call `create` to initialize the sockets
    const ExternalSockets = struct {
        _has_deinit: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
        _downstream: network.Socket = undefined,
        _upstream: network.Socket = undefined,
        _upstream_thread: std.Thread = undefined,
        const Ext = @This();

        const DownStreamCallback = struct {
            dev: *DeviceContext,
            const Observer = PackObserverList.Observer;
            const Callback = @This();

            pub fn create(arg_dev: *DeviceContext) !*@This() {
                var self = try arg_dev.allocator().create(@This());
                self.dev = arg_dev;
                return self;
            }

            pub fn subscribe(self: *@This()) !void {
                const magic_socket = self.dev.magicSocket();
                const predicate = Observer.Predicate{ .reqid = magic_socket.requestId(.read) };
                var subject = self.dev.rxObservable();
                try subject.subscribe(
                    "downstream",
                    predicate,
                    &Callback.onData,
                    null,
                    self,
                    @ptrCast(&Callback.deinit),
                );
            }

            pub fn deinit(self: *@This()) void {
                self.dev.allocator().destroy(self);
            }

            pub fn onData(_: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
                const ud = obs.userdata;
                const self = utils.as(@This(), ud);
                var down = &self.dev.ext._downstream;
                const buf = try pack.data();
                const sz = try down.send(buf);
                self.dev.withSrcLogger(logz.debug(), @src())
                    .string("what", "downstream")
                    .int("len", sz).log();
                if (sz != buf.len) {
                    return AppError.BadSize;
                }
            }
        };

        inline fn dev(self: *@This()) *DeviceContext {
            return @fieldParentPtr("ext", self);
        }

        pub inline fn initCallback(self: *@This()) !void {
            var cb = try DownStreamCallback.create(self.dev());
            try cb.subscribe();
        }

        pub inline fn downstream(self: *@This()) ?*network.Socket {
            if (self.hasDeinit()) {
                return null;
            }
            return &self._downstream;
        }

        pub inline fn upstream(self: *@This()) ?*network.Socket {
            if (self.hasDeinit()) {
                return null;
            }
            return &self._upstream;
        }

        /// unless fully certain that the sockets are initialized
        /// you should check this field before using the sockets
        pub inline fn hasDeinit(self: *const @This()) bool {
            return self._has_deinit.load(std.builtin.AtomicOrder.unordered);
        }

        fn upstreamIter(self: *@This()) !void {
            var buf: [BB_SOCKET_TX_BUFFER]u8 = undefined;
            const n = try self._upstream.receive(buf[0..]);
            if (n == 0) {
                return AppError.Empty;
            }
            try self.dev().transmitViaSocket(buf[0..n]);
        }

        fn upstreamLoop(self: *@This()) void {
            while (!self.hasDeinit()) {
                self.upstreamIter() catch |e| {
                    switch (e) {
                        error.ConnectionTimedOut => continue,
                        error.WouldBlock => continue,
                        AppError.Empty => continue,
                        ClosedError.Closed => break,
                        else => {
                            self.dev().withSrcLogger(logz.err(), @src())
                                .string("what", "upstream loop exception")
                                .err(e).log();
                            std.debug.panic("upstream loop exception {}", .{e});
                        },
                    }
                };
            }
            self.dev().withSrcLogger(logz.debug(), @src())
                .string("what", "exit upstream loop").log();
        }

        /// spawn a thread to forward the packets from the upstream
        /// and subscribe the observer to the downstream
        fn runForwarding(self: *@This()) !void {
            const config = std.Thread.SpawnConfig{
                .stack_size = DEFAULT_THREAD_STACK_SIZE,
                .allocator = self.dev().allocator(),
            };
            try self._upstream.setReadTimeout(std.time.us_per_ms * 100);
            try self._downstream.setWriteTimeout(std.time.us_per_ms * 10);
            self._upstream_thread = try std.Thread.spawn(config, Ext.upstreamLoop, .{self});
            try self.initCallback();
        }

        pub fn init(
            self: *@This(),
            upstream_listen_port: u16,
            downstream_endpoint: network.EndPoint,
        ) !void {
            if (!self.hasDeinit()) {
                return AppError.HasInit;
            }
            var ds = try network.Socket.create(.ipv4, .udp);
            try ds.connect(downstream_endpoint);
            errdefer ds.close();
            const a = &downstream_endpoint.address.ipv4.value;
            logz.info()
                .string("what", "downstream connected")
                .fmt("address", "{}.{}.{}.{}", .{ a[0], a[1], a[2], a[3] })
                .int("port", downstream_endpoint.port).log();

            var us = try network.Socket.create(.ipv4, .udp);
            try us.bind(network.EndPoint{
                .address = try network.Address.parse("0.0.0.0"),
                .port = upstream_listen_port,
            });
            errdefer us.close();
            // it can provide port 0 to bind() as its connection parameter. That
            // triggers the operating system to automatically search for and
            // return a suitable available port in the TCP/IP dynamic port
            // number range.
            const addr = try us.getLocalEndPoint();
            logz.info()
                .string("what", "upstream bound")
                .int("port", addr.port).log();
            self._downstream = ds;
            self._upstream = us;
            self._has_deinit.store(false, std.builtin.AtomicOrder.unordered);
            try self.runForwarding();
        }

        pub fn deinit(self: *@This()) void {
            if (self.hasDeinit()) {
                return;
            }
            self._has_deinit.store(true, std.builtin.AtomicOrder.unordered);
            self._upstream_thread.join();
            self._downstream.close();
            self._upstream.close();
        }
    };

    const Self = @This();

    // ****** fields ******
    _has_deinit: std.atomic.Value(bool) = std.atomic.Value(bool).init(true),
    gpa: DeviceGPA,
    core: DeviceHandles,
    bus: u8,
    port: u8,
    /// managed by `gpa`
    endpoints: []Endpoint,
    xfer: TransferContext,
    arto: ArtoContext,
    ext: ExternalSockets,

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

    pub inline fn magicSocket(self: *@This()) *MagicSocket {
        return &self.arto._magic_socket;
    }

    pub inline fn mutTxBuffer(self: *@This()) []u8 {
        return self.xfer.tx_transfer.buf[0..];
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
            .ext = ExternalSockets{},
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
        // `rx_queue` is not happy with allocated with allocator in
        // the `DeviceContext`, which would cause a deadlock.
        // Interestingly, the deadlock is from the internal of GPA.
        // For now, using a external allocator to allocate the queue.
        dc.xfer.rx_queue = UsbPackQueue.init(alloc);
        dc.xfer.rx_queue.setElemDtor(&ManagedUsbPack.deinit);
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
        const speed = UsbSpeed.getDeviceSpeed(self.mutDev()) catch unreachable;
        self.withLogger(logz.info()).string("speed", @tagName(speed)).log();
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

    /// transmit with `data` copy to the internal buffer
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
    pub fn transmitSlice(self: *@This(), data: []const u8) !void {
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

    /// Write to the magical socket, requires an open socket
    pub fn transmitViaSocket(self: *@This(), payload: []const u8) !void {
        var socket = self.magicSocket();
        if (self.hasDeinit()) {
            return ClosedError.Closed;
        }
        if (!socket.isOpen()) {
            return ClosedError.Closed;
        }

        const transfer = &self.xfer.tx_transfer;
        const payload_len_required = payload.len + @sizeOf(u64);
        const total_len_required = UsbPack.fixed_pack_base + payload_len_required;
        if (total_len_required > transfer.buf.len) {
            return TransmitError.Overflow;
        }
        const tx_buf = self.mutTxBuffer();
        var pack = UsbPack{
            .reqid = socket.requestId(.write),
            .msgid = 0,
            .sta = 0,
        };

        const ok = transfer.lk.tryLockShared();
        if (!ok) {
            return TransmitError.Busy;
        }
        errdefer transfer.lk.unlockShared();
        var stream = std.io.fixedBufferStream(tx_buf);
        var writer = stream.writer();
        var any_writer = writer.any();
        try pack.writeHeaderOnly(&any_writer, @intCast(payload_len_required));
        try writer.writeInt(u64, socket.position(), .little);
        _ = try writer.write(payload);
        try writer.writeByte(0xbb);
        try transfer.setLength(@intCast(try stream.getPos()));

        const ret = usb.libusb_submit_transfer(transfer.self);
        if (ret != LIBUSB_OK) {
            return libusb_error_2_set(ret);
        }
        socket.movePosition(@intCast(payload.len));
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
        const data = try pack.marshalAlloc(alloc);
        defer alloc.free(data);
        try self.transmitSlice(data);
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
        const data = try pack.marshalAlloc(alloc);
        defer alloc.free(data);
        try self.transmitSlice(data);
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
    /// It's recommended to subscribe the observable, instead of
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
        const cb = TransferCallback.create(
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
        const cb = TransferCallback.create(
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
        // first, we start the loop thread for observable
        self.xfer.initThreads();

        if (GlobalConfig.is_enable_ar8030_debug_callback) {
            var debug_cb = MagicSocketCallback.create(self.allocator(), self) catch unreachable;
            debug_cb.subscribe_debug() catch unreachable;
            self.transmitWithPack(self.allocator(), BB_REQID_DEBUG_CLIENT_CHANGE, null) catch unreachable;
            self.waitForTxComplete();
        }

        // it's quite hard to design a promise chain without lambda/closure.
        //
        // we only needs a little push to start the chain
        // query_status.than(query_info).than(open_socket)
        var action = InitSequenceCallback.create(self.allocator(), self) catch unreachable;
        action.status_query_send() catch unreachable;
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

    /// send message depending on the role, only for testing
    fn testSendLoop(self: *@This()) void {
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

/// Refresh the `ctx_list`. Note that will mutate `ctx_list` in place.
///
/// - `allocator` is for `DeviceContext`, which would persist
/// - `arena` for the temporary memory.
fn refreshDevList(allocator: std.mem.Allocator, arena: *std.heap.ArenaAllocator, ctx: *usb.libusb_context, ctx_list: *std.ArrayList(DeviceContext)) void {
    var c_device_list: [*c]?*usb.libusb_device = undefined;
    // See also
    // Device discovery and reference counting
    // in https://libusb.sourceforge.io/api-1.0/group__libusb__dev.html
    //
    // https://zig.news/kprotty/resource-efficient-thread-pools-with-zig-3291
    //
    // If the unref_devices parameter is set, the reference count of each device
    // in the list is decremented by 1
    const sz = usb.libusb_get_device_list(ctx, &c_device_list);
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

    const Observer = PackObserverList.Observer;

    pub fn create(alloc: std.mem.Allocator, dev: *DeviceContext) !*Self {
        var ret = try alloc.create(Self);
        ret.allocator = alloc;
        ret.dev = dev;
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.destroy(self);
    }

    pub fn subscribe_write(self: *@This()) !void {
        const subject = self.dev.rxObservable();
        const magic_socket = self.dev.magicSocket();
        const predicate = Observer.Predicate{ .reqid = magic_socket.requestId(.write) };
        try subject.subscribe(
            "so_write",
            predicate,
            &Self.write_on_data,
            null,
            self,
            @ptrCast(&Self.deinit),
        );
    }

    /// the device will return two message on write
    ///
    /// First one is the status of the write operation
    /// (BB_SOCKET_SEND_OK/BB_SOCKET_SEND_ERROR/BB_SOCKET_SEND_NEED_UPDATE_ADDR)
    /// whose payload is
    ///
    /// ```c
    /// struct socket_msg_ret {
    ///     uint64_t pos;
    ///     uint32_t len;
    /// };
    /// ```
    ///
    /// with a few bytes of gibberish in the end because of alignment padding.
    ///
    /// Second one is the written length as `sta`, whose payload is the position of
    /// pointer (u64)
    ///
    /// I'm not sure if there's any command to query the position of the pointer (why the position is needed?)
    ///
    /// `position` is the data have been written since the opening of the socket,
    /// it acts like a pointer, which moves forward after each write operation.
    /// The original code uses a ring-buffer to write the data, but I still don't see the necessity of
    /// this field...
    ///
    /// If `BB_SOCKET_SEND_ERROR` is the status, than
    /// `socket_msg_ret.pos` means the position given to device, which made the device not happy,
    /// `socket_msg_ret.len` is the position expected, but it might be a overflowed value since
    /// its width is only 32 bits.
    pub fn write_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = utils.as(@This(), ud);
        _ = sbj;
        var socket = self.dev.magicSocket();
        if (pack.sta >= 0) {
            // sta is the length and payload is the position (u64)
            const len = pack.sta;
            if (pack.data()) |pos| {
                var position: u64 = undefined;
                utils.fillWithBytes(&position, pos) catch unreachable;
                socket.withLogger(self.dev.withSrcLogger(logz.info(), @src()))
                    .string("what", "written")
                    .int("pos", position)
                    .int("len", len)
                    .log();
            } else |_| {}
        } else {
            switch (pack.sta) {
                BB_SOCKET_SEND_OK => {
                    const len = @sizeOf(bb.err_socket_msg_ret_t);
                    if (pack.data()) |data| {
                        std.debug.assert(data.len >= len);
                        var ret: bb.socket_msg_ret_t = undefined;
                        utils.fillWithBytes(&ret, data[0..len]) catch unreachable;
                        socket.withLogger(self.dev.withSrcLogger(logz.debug(), @src()))
                            .string("what", "ok")
                            .int("pos", ret.pos)
                            .int("len", ret.len)
                            .log();
                    } else |_| {}
                },
                BB_SOCKET_SEND_NEED_UPDATE_ADDR => std.debug.panic("fixme: BB_SOCKET_SEND_NEED_UPDATE_ADDR", .{}),
                BB_SOCKET_SEND_ERROR => {
                    var ret: bb.err_socket_msg_ret_t = undefined;
                    if (pack.data()) |data| {
                        const len = @sizeOf(bb.err_socket_msg_ret_t);
                        std.debug.assert(data.len >= len);
                        utils.fillWithBytes(&ret, data[0..len]) catch unreachable;
                        socket.withLogger(self.dev.withSrcLogger(logz.info(), @src()))
                            .string("what", "socket write error")
                            .fmt("got_pos", "0x{x:0>16}", .{ret.got_pos})
                            .fmt("expected_pos", "0x{x:0>8}", .{ret.expected_pos})
                            .log();
                        // we could try to recover the position
                        socket._position = @intCast(ret.expected_pos);
                        // but I still prefer panic
                        std.debug.panic("socket write error, got_pos=0x{x:0>16}, expected_pos=0x{x:0>8}", .{ ret.got_pos, ret.expected_pos });
                    } else |_| {
                        std.debug.panic("socket write error", .{});
                    }
                },
                else => std.debug.panic("unknown status from socket write. sta={d}", .{pack.sta}),
            }
        }
    }

    pub fn subscribe_read(self: *@This()) !void {
        const subject = self.dev.rxObservable();
        const magic_socket = self.dev.magicSocket();
        const predicate = Observer.Predicate{ .reqid = magic_socket.requestId(.read) };
        try subject.subscribe(
            "so_read",
            predicate,
            &Self.read_on_data,
            null,
            self,
            @ptrCast(&Self.deinit),
        );
    }
    pub fn read_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = utils.as(@This(), ud);
        var socket = self.dev.magicSocket();
        _ = sbj;
        // the magic sta, no idea what it means
        // 305419896=0x12345678
        // You're fucking kidding me?
        std.debug.assert(pack.sta == 0x12345678);
        if (pack.data()) |data| {
            socket.withLogger(self.dev.withSrcLogger(logz.info(), @src()))
                .int("sta", pack.sta)
                .string("what", "read")
                .string("data", data)
                .fmt("hex", "{s}", .{std.fmt.fmtSliceHexLower(data)})
                .log();
            // TODO: to downstream
        } else |_| {}
    }

    pub fn subscribe_debug(self: *@This()) !void {
        const subject = self.dev.rxObservable();
        const predicate = Observer.Predicate{ .reqid = BB_REQID_DEBUG_DATA };
        try subject.subscribe(
            "debug",
            predicate,
            &Self.debug_on_data,
            null,
            self,
            @ptrCast(&Self.deinit),
        );
    }
    pub fn debug_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        const self = utils.as(@This(), ud);
        _ = self;
        _ = sbj;
        std.debug.assert(pack.sta == BB_STA_OK);
        if (pack.data()) |data| {
            const stdout = std.io.getStdOut();
            try stdout.writer().print("{s}", .{data});
        } else |_| {}
    }
};

/// only used in `DeviceContext.loopPrepare`.
/// For the initialization sequence of the device.
const InitSequenceCallback = struct {
    arena: std.heap.ArenaAllocator,
    /// reference, not OWNING
    dev: *DeviceContext,

    const Observer = PackObserverList.Observer;
    const Self = @This();

    pub inline fn as(ud: ?*anyopaque) *Self {
        return utils.as(Self, ud);
    }

    pub fn create(alloc: std.mem.Allocator, dev: *DeviceContext) !*Self {
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
                    .stringZ("observer", obs.name())
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
        var socket_cb_write = try MagicSocketCallback.create(self.dev.allocator(), self.dev);
        var socket_cb_read = try MagicSocketCallback.create(self.dev.allocator(), self.dev);
        try socket_cb_write.subscribe_write();
        try socket_cb_read.subscribe_read();
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

    pub fn status_query_send(self: *@This()) !void {
        var in = c.bb_get_status_in_t{
            .user_bmp = SLOT_BIT_MAP_MAX,
        };
        try self.dev.transmitWithPack(self.arena.allocator(), c.BB_GET_STATUS, &in);
        const predicate = Observer.Predicate{ .reqid = c.BB_GET_STATUS };
        var subject = self.dev.rxObservable();
        // `UpdateStatusCallback` is responsible for updating the status
        try self.dev.arto.initCallback();

        // `query_status_on_data` responsible for pushing the next initialization action
        subject.subscribe(
            "status_query",
            predicate,
            &Self.status_on_data,
            &Self.status_on_error,
            self,
            null,
        ) catch unreachable;
    }
    pub const status_on_error = Self.make_generic_error_handler("exception on handle status query response");
    pub fn status_on_data(sbj: *PackObserverList, _: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = Self.as(ud);
        // ***** and_then *****
        try self.sys_info_query_send();

        sbj.unsubscribe(obs) catch unreachable;
    }

    pub fn sys_info_query_send(self: *@This()) !void {
        try self.dev.transmitWithPack(self.arena.allocator(), c.BB_GET_SYS_INFO, null);
        const predicate = PackObserverList.Predicate{ .reqid = c.BB_GET_SYS_INFO };
        var subject = self.dev.rxObservable();
        subject.subscribe(
            "sysinfo",
            predicate,
            &Self.sys_info_on_data,
            &Self.sys_info_on_error,
            self,
            null,
        ) catch unreachable;
    }
    pub const sys_info_on_error = Self.make_generic_error_handler("exception on handle system info query response");
    pub fn sys_info_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        std.debug.assert(pack.sta == BB_STA_OK);
        const ud = obs.userdata;
        var self = Self.as(ud);
        const info = try pack.dataAs(c.bb_get_sys_info_out_t);

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
    pub fn subscribe_event_no_response(self: *@This(), event: bb.Event) !void {
        const req = bb.subscribeRequestId(event);
        try self.dev.transmitWithPack(self.arena.allocator(), req, null);
    }

    const OpenSocketError = error{
        AlreadyOpened,
        Unspecified,
    };

    pub fn reopen_socket_send(self: *@This()) !void {
        const magic_socket = self.dev.magicSocket();
        try magic_socket.trySocketClose();
        var subject = self.dev.rxObservable();
        const predicate = Observer.Predicate{ .reqid = magic_socket.requestId(.close) };
        subject.subscribe(
            "so_reopen",
            predicate,
            &Self.reopen_socket_on_data,
            null,
            self,
            null,
        ) catch unreachable;
    }
    pub fn reopen_socket_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        const ud = obs.userdata;
        var self = Self.as(ud);
        var socket = self.dev.magicSocket();
        socket.setOpen(false);
        std.debug.assert(pack.sta == BB_STA_OK);
        try socket.trySocketOpen();
        sbj.unsubscribe(obs) catch unreachable;
    }

    pub fn open_socket_send(self: *@This()) !void {
        var magic_socket = self.dev.magicSocket();
        magic_socket.initialize(self.dev, BB_SEL_SLOT, BB_SEL_PORT);
        try magic_socket.trySocketOpen();
        var subject = self.dev.rxObservable();
        const predicate = Observer.Predicate{ .reqid = magic_socket.requestId(.open) };
        subject.subscribe(
            "so_open",
            predicate,
            &Self.open_socket_on_data,
            &Self.open_socket_on_error,
            self,
            null,
        ) catch unreachable;
    }
    pub const open_socket_on_error = Self.make_generic_error_handler("exception on handle open socket response");
    pub fn open_socket_on_data(sbj: *PackObserverList, pack: *const UsbPack, obs: *Observer) !void {
        // TODO: use state machine
        const ud = obs.userdata;
        var self = Self.as(ud);
        const skt = self.dev.magicSocket();
        switch (pack.sta) {
            BB_STA_OK => {
                skt.setOpen(true);
                try self.listen_to_socket();
                skt.withLogger(self.dev.withSrcLogger(logz.info(), @src()))
                    .string("what", "socket opened")
                    .log();
                if (self.dev.arto.status()) |status| {
                    var upstream_listen_port: u16 = undefined;
                    var downstream_endpoint: network.EndPoint = undefined;
                    if (status.role == .dev) {
                        upstream_listen_port = 39450;
                        downstream_endpoint = network.EndPoint{
                            .address = try network.Address.parse("127.0.0.1"),
                            .port = 39451,
                        };
                    } else {
                        upstream_listen_port = 38450;
                        downstream_endpoint = network.EndPoint{
                            .address = try network.Address.parse("127.0.0.1"),
                            .port = 38451,
                        };
                    }
                    try self.dev.ext.init(upstream_listen_port, downstream_endpoint);
                } else {
                    std.debug.panic("uninitialized status when socket opened", .{});
                }
            },
            BB_ERROR_ALREADY_OPENED_SOCKET => {
                skt.withLogger(self.dev.withSrcLogger(logz.warn(), @src()))
                    .string("what", "magic socket opened, try to close it than reopen")
                    .log();
                try reopen_socket_send(self);
                return;
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

    pub fn create(alloc: std.mem.Allocator, dev: *DeviceContext, transfer: *DeviceContext.Transfer, endpoint: Endpoint) !*Self {
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
    pub inline fn dtorPtrTypeErased() *const fn (*anyopaque) void {
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

        const tx_buf = self.transfer.txBuf();
        var lg = utils.logWithSrc(self.dev.withLogger(logz.debug()), @src());
        lg = self.endpoint.withLogger(lg);
        lg = lg.string("status", @tagName(status))
            .int("flags", trans.*.flags)
            .string("action", "transmit")
            .int("len", tx_buf.len);
        if (GlobalConfig.is_log_content) {
            lg = lg.fmt("content", "{s}", .{std.fmt.fmtSliceHexLower(tx_buf)});
        }
        lg.log();
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

        const rx_buf = self.transfer.rxBuf();
        self.transfer.lk.unlockShared();
        var lg = utils.logWithSrc(self.dev.withLogger(logz.debug()), @src());
        lg = self.endpoint.withLogger(lg);
        lg = lg.string("status", @tagName(status))
            .int("flags", trans.*.flags)
            .string("action", "receive")
            .int("len", rx_buf.len);
        if (GlobalConfig.is_log_content) {
            lg = lg.fmt("content", "{s}", .{std.fmt.fmtSliceHexLower(rx_buf)});
        }
        lg.log();

        if (rx_buf.len > 0) {
            var e_mpk = ManagedUsbPack.unmarshal(self.alloc, rx_buf);
            if (e_mpk) |*mpk| {
                lg = utils.logWithSrc(self.dev.withLogger(logz.debug()), @src());
                mpk.pack.withLogger(lg, GlobalConfig.is_log_packet_content).log();
                self.dev.xfer.rx_queue.enqueue(mpk.*) catch |e| {
                    utils.logWithSrc(self.dev.withLogger(logz.err()), @src())
                        .err(e).string("what", "failed to enqueue").log();
                    mpk.deinit();
                };
            } else |err| {
                utils.logWithSrc(self.dev.withLogger(logz.err()), @src())
                    .err(err).string("what", "failed to unmarshal")
                    .fmt("data", "{s}", .{std.fmt.fmtSliceHexLower(rx_buf)})
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
    // required for Windows
    // https://github.com/ziglang/zig/issues/8943
    try network.init();
    defer network.deinit();

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
