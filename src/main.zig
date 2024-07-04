const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");
const usb = @cImport({
    @cInclude("libusb.h");
});
const bb = @import("bb/c.zig");
const UsbPack = @import("bb/usbpack.zig").UsbPack;
const utils = @import("utils.zig");
const BadEnum = utils.BadEnum;
const RwLock = std.Thread.RwLock;
const PriorityQueue = std.PriorityQueue;

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;
const XXHASH_SEED: u32 = 0x0;

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
        else => LibUsbError.Unknown,
    };
}

const DeviceLike = struct {
    const MAX_PORTS = 8;
    dev: *usb.libusb_device,
    vid: u16,
    pid: u16,
    bus: u8,
    port: u8,
    _ports_buf: [MAX_PORTS]u8,
    ports: []const u8,

    pub fn from_device(dev: *usb.libusb_device) AppError!@This() {
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
            .ports = undefined,
        };
        const lsz = usb.libusb_get_port_numbers(dev, &ret._ports_buf, MAX_PORTS);
        if (lsz < 0) {
            return AppError.BadPortNumbers;
        }
        ret.ports = ret._ports_buf[0..@intCast(lsz)];
        return ret;
    }

    pub fn withLogger(self: *const @This(), logger: logz.Logger) logz.Logger {
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
        h.update(self.ports);
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
    pub fn dtor(self: *Self) void {
        usb.libusb_close(self.hdl);
    }
};

/// Select every possible slot (14 slot?).
/// Anyway it's magic a number.
///
/// `0b0011_1111_1111_1111`
const SLOT_BIT_MAP_MAX = 0x3fff;
const is_windows = builtin.os.tag == .windows;

const DeviceGPA = std.heap.GeneralPurposeAllocator(.{
    .thread_safe = true,
});

/// Transfer is a wrapper of `libusb_transfer`
/// but with a closure and a closure destructor
const Transfer = struct {
    self: *usb.libusb_transfer,
    closure: ?*anyopaque = null,
    closure_dtor: ?*const fn (*anyopaque) void = null,
    /// lock when `libusb_submit_transfer` is called.
    /// callback SHOULD be responsible for unlocking it.
    ///
    /// This mutex is mainly used in TX transfer.
    /// For RX transfer, the event loop is always polling and
    /// the transfer will be restarted after the callback is called.
    lk: RwLock,

    pub fn dtor(self: *@This()) void {
        if (self.closure_dtor) |free| {
            if (self.closure) |ptr| {
                free(ptr);
            }
        }
        usb.libusb_free_transfer(self.self);
    }
};

// arto specific context
// like network, transfer, etc.
const ArtoContext = struct {
    tx_transfer: Transfer,
    rx_transfer: Transfer,

    pub fn dtor(self: *@This()) void {
        self.tx_transfer.dtor();
        self.rx_transfer.dtor();
    }
};

const DeviceContext = struct {
    gpa: DeviceGPA,
    core: DeviceHandles,
    bus: u8,
    port: u8,
    /// managed by `alloc`
    ports: []const u8,
    /// managed by `alloc`
    endpoints: []Endpoint,
    /// managed by `alloc`
    serial: []const u8,
    arto: ArtoContext,

    const Self = @This();

    pub fn allocator(self: *Self) std.mem.Allocator {
        return self.gpa.allocator();
    }

    pub fn dev(self: *const Self) *const usb.libusb_device {
        return self.core.dev;
    }

    pub fn mutDev(self: *Self) *usb.libusb_device {
        return self.core.dev;
    }

    pub fn hdl(self: *const Self) *const usb.libusb_device_handle {
        return self.core.hdl;
    }

    pub fn mutHdl(self: *Self) *usb.libusb_device_handle {
        return self.core.hdl;
    }

    pub fn desc(self: *const Self) *const usb.libusb_device_descriptor {
        return &self.core.desc;
    }

    pub fn from_device_like(d: DeviceLike) LibUsbError!@This() {
        var ret: c_int = undefined;
        var l_hdl: ?*usb.libusb_device_handle = null;
        // Internally, this function adds a reference to the device and makes it
        // available to you through `libusb_get_device()`. This reference is
        // removed during `libusb_close()`.
        ret = usb.libusb_open(d.dev, &l_hdl);
        if (ret != 0 or l_hdl == null) {
            d.withLogger(logz.err().string("err", "failed to open device")).log();
            return libusb_error_2_set(ret);
        }
        var l_desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(d.dev, &l_desc);
        if (ret != 0) {
            d.withLogger(logz.err()).string("err", "failed to get device descriptor").log();
            return libusb_error_2_set(ret);
        }

        var gpa = DeviceGPA{};
        const dyn_ports = gpa.allocator().alloc(u8, d.ports.len) catch @panic("OOM");
        const eps = getEndpoints(gpa.allocator(), d.dev, &l_desc);
        const serial = dynStringDescriptorOr(gpa.allocator(), l_hdl.?, l_desc.iSerialNumber, "");
        @memcpy(dyn_ports, d.ports);
        var dc = DeviceContext{
            .gpa = gpa,
            .core = DeviceHandles{
                .dev = d.dev,
                .hdl = l_hdl.?,
                .desc = l_desc,
            },
            .bus = d.bus,
            .port = d.port,
            .ports = dyn_ports,
            .serial = serial,
            .endpoints = eps,
            .arto = undefined,
        };
        const tx_transfer = usb.libusb_alloc_transfer(0);
        const rx_transfer = usb.libusb_alloc_transfer(0);
        if (tx_transfer == null or rx_transfer == null) {
            dc.withLogger(logz.err()).string("err", "failed to allocate transfer").log();
            @panic("failed to allocate transfer, might be OOM");
        }
        dc.arto.tx_transfer = Transfer{
            .self = tx_transfer,
            .lk = RwLock{},
        };
        dc.arto.rx_transfer = Transfer{
            .self = rx_transfer,
            .lk = RwLock{},
        };
        return dc;
    }

    pub fn dtor(self: *Self) void {
        self.core.dtor();
        self.allocator().free(self.ports);
        self.allocator().free(self.endpoints);
        self.allocator().free(self.serial);
        self.arto.dtor();
        const chk = self.gpa.deinit();
        if (chk != .ok) {
            std.debug.print("GPA thinks there are memory leaks when destroying device bus {} port {}\n", .{ self.bus, self.port });
        }
    }

    /// attach the device information to the logger
    pub fn withLogger(self: *const Self, logger: logz.Logger) logz.Logger {
        return logger
            .string("serial_number", self.serial)
            .int("bus", self.bus)
            .int("port", self.port);
    }

    /// hash the device by bus, port, and ports
    pub fn xxhash(self: *const Self) u32 {
        var h = std.hash.XxHash32.init(XXHASH_SEED);
        h.update(utils.anytype2Slice(&self.bus));
        h.update(utils.anytype2Slice(&self.port));
        h.update(self.ports);
        return h.final();
    }

    fn init_transfer_tx(self: *@This(), ep: *Endpoint) void {
        var ret: c_int = undefined;
        const alloc = self.allocator();
        var cb = alloc.create(transfer_callback) catch @panic("OOM");
        var transfer: *Transfer = &self.arto.tx_transfer;
        cb.alloc = alloc;
        cb.dev = self;
        cb.transfer = transfer;
        cb.endpoint = ep.*;
        const payload = bb.bb_get_status_in_t{
            .user_bmp = SLOT_BIT_MAP_MAX,
        };
        const data_buf = alloc.alloc(u8, @sizeOf(@TypeOf(payload))) catch @panic("OOM");
        defer alloc.free(data_buf);
        utils.fillBytesWith(data_buf, &payload) catch unreachable;
        const header = UsbPack{
            .msgid = 0x0,
            .reqid = bb.BB_GET_STATUS,
            .sta = 0x0,
            .ptr = data_buf.ptr,
            .len = @intCast(data_buf.len),
        };
        const tx_buffer = header.marshal(alloc) catch @panic("OOM");
        cb.buffer = tx_buffer;
        usb.libusb_fill_bulk_transfer(
            transfer.self,
            self.mutHdl(),
            ep.addr,
            tx_buffer.ptr,
            @intCast(tx_buffer.len),
            transfer_callback.tx,
            cb,
            1_000,
        );
        var lg = self.withLogger(logz.info());
        lg = ep.withLogger(lg).string("action", "submitting transfer");
        lg.log();
        transfer.closure = cb;
        transfer.closure_dtor = transfer_callback.void_dtor();
        ret = usb.libusb_submit_transfer(transfer.self);
        switch (ret) {
            0 => transfer.lk.lockShared(),
            else => {
                lg = self.withLogger(logz.err());
                lg = ep.withLogger(lg);
                lg.int("code", ret).string("what", "failed to submit transfer").log();
                @panic("failed to submit transfer");
            },
        }
    }

    fn init_transfer_rx(self: *DeviceContext, ep: *Endpoint) void {
        var ret: c_int = undefined;
        const l_alloc = self.allocator();
        var cb = l_alloc.create(transfer_callback) catch @panic("OOM");
        var transfer: *Transfer = &self.arto.rx_transfer;
        cb.alloc = l_alloc;
        cb.dev = self;
        cb.transfer = transfer;
        cb.endpoint = ep.*;
        const rx_buffer = l_alloc.alloc(u8, ep.maxPacketSize) catch @panic("OOM");
        cb.buffer = rx_buffer;
        // timeout 0
        // callback won't be called because of timeout
        usb.libusb_fill_bulk_transfer(
            transfer.self,
            self.mutHdl(),
            ep.addr,
            rx_buffer.ptr,
            @intCast(rx_buffer.len),
            transfer_callback.rx,
            cb,
            0,
        );
        var lg = self.withLogger(logz.info());
        lg = ep.withLogger(lg).string("action", "submitting transfer");
        lg.log();
        transfer.closure = cb;
        transfer.closure_dtor = transfer_callback.void_dtor();

        ret = usb.libusb_submit_transfer(transfer.self);
        switch (ret) {
            0 => transfer.lk.lockShared(),
            else => {
                lg = self.withLogger(logz.err());
                lg = ep.withLogger(lg);
                lg.int("code", ret).string("what", "failed to submit transfer").log();
                @panic("failed to submit transfer");
            },
        }
    }

    fn init_endpoints(self: *@This()) void {
        for (self.endpoints) |*ep| {
            if (ep.direction == Direction.out and ep.transferType == TransferType.bulk) {
                self.init_transfer_tx(ep);
            } else if (ep.direction == Direction.in and ep.transferType == TransferType.bulk) {
                self.init_transfer_rx(ep);
            }
        }
    }

    pub fn init(self: *@This()) LibUsbError!void {
        const speed = usb.libusb_get_device_speed(self.mutDev());
        var ret: c_int = undefined;
        printStrDesc(self.mutHdl(), self.desc());
        printEndpoints(self.desc().idVendor, self.desc().idProduct, self.endpoints);
        self.withLogger(logz.info()).string("speed", usbSpeedToString(speed)).log();
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
        self.init_endpoints();
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

fn refreshDevList(ctx: *usb.libusb_context, ctx_list: *std.ArrayList(DeviceContext)) void {
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

    // https://www.reddit.com/r/Zig/comments/18p7w7v/making_a_struct_inside_a_function_makes_it_static/
    // https://www.reddit.com/r/Zig/comments/ard50a/static_local_variables_in_zig/

    // TODO: if we're polling this we'd better avoid allocating memory repeatedly
    // move shit into a context and preallocate them
    const find_diff = struct {
        ctx_list: []const DeviceContext,

        /// Find the difference between `DeviceContext` the new polled device list from `libusb`.
        ///
        /// Note that the return array will be allocated with `alloc`
        /// and the caller is responsible for freeing the memory.
        ///
        ///   - left: devices that should be removed from the context list (`*const DeviceContext`)
        ///   - right: devices that should be added to the context list (`DeviceLike` that could be used to init a device)
        pub fn call(
            self: *const @This(),
            alloc: std.mem.Allocator,
            poll_list: []const ?*usb.libusb_device,
        ) struct { std.ArrayList(*const DeviceContext), std.ArrayList(DeviceLike) } {
            var ret: c_int = undefined;
            var filtered = std.ArrayList(DeviceLike).init(alloc);
            defer filtered.deinit();
            for (poll_list) |device| {
                if (device) |val| {
                    var l_desc: usb.libusb_device_descriptor = undefined;
                    ret = usb.libusb_get_device_descriptor(val, &l_desc);
                    if (ret != 0) {
                        continue;
                    }
                    if (l_desc.idVendor == ARTO_RTOS_VID and l_desc.idProduct == ARTO_RTOS_PID) {
                        const dev_like = DeviceLike.from_device(val) catch {
                            continue;
                        };
                        filtered.append(dev_like) catch @panic("OOM");
                    }
                }
            }

            const DEFAULT_CAP = 4;
            var left = std.ArrayList(*const DeviceContext).init(alloc);
            left.ensureTotalCapacity(DEFAULT_CAP) catch @panic("OOM");
            var right = std.ArrayList(DeviceLike).init(alloc);
            right.ensureTotalCapacity(DEFAULT_CAP) catch @panic("OOM");
            var inter = std.ArrayList(DeviceLike).init(alloc);
            inter.ensureTotalCapacity(DEFAULT_CAP) catch @panic("OOM");
            defer inter.deinit();

            // TODO: improve the performance by using a hash set or a hash map
            for (self.ctx_list) |*dc| {
                var found = false;
                const l_hash = dc.xxhash();
                inner: for (filtered.items) |dl| {
                    const r_hash = dl.xxhash();
                    if (l_hash == r_hash) {
                        found = true;
                        inter.append(dl) catch @panic("OOM");
                        break :inner;
                    }
                }

                if (!found) {
                    left.append(dc) catch @panic("OOM");
                }
            }

            for (filtered.items) |fdl| {
                var found = false;
                const r_hash = fdl.xxhash();
                inner: for (inter.items) |idl| {
                    const l_hash = idl.xxhash();
                    if (l_hash == r_hash) {
                        found = true;
                        break :inner;
                    }
                }

                if (!found) {
                    right.append(fdl) catch @panic("OOM");
                }
            }

            return .{ left, right };
        }
    };

    const l, const r = (find_diff{ .ctx_list = ctx_list.items }).call(ctx_list.allocator, device_list);
    defer l.deinit();
    defer r.deinit();
    // destroy detached devices
    for (l.items) |ldc| {
        inner: for (ctx_list.items, 0..) |*rdc, index| {
            if (ldc == rdc) {
                rdc.withLogger(logz.warn().string("action", "removed")).log();
                rdc.dtor();
                _ = ctx_list.orderedRemove(index);
                break :inner;
            }
        }
    }

    // open new devices
    for (r.items) |d| {
        var dc = DeviceContext.from_device_like(d) catch |e| {
            d.withLogger(logz.err()).err(e).log();
            continue;
        };
        ctx_list.append(dc) catch @panic("OOM");
        dc.withLogger(logz.info()).string("action", "added").log();
    }
}

pub inline fn usbEndpointNum(ep_addr: u8) u8 {
    return ep_addr & 0x07;
}

pub inline fn usbEndpointTransferType(ep_attr: u8) u8 {
    return ep_attr & @as(u8, usb.LIBUSB_TRANSFER_TYPE_MASK);
}

pub inline fn unwarp_ifaces_desc(iface: *const usb.libusb_interface) []const usb.libusb_interface_descriptor {
    return iface.altsetting[0..@intCast(iface.num_altsetting)];
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

    pub fn from_desc(iConfig: u8, iInterface: u8, ep: *const usb.libusb_endpoint_descriptor) AppError!Endpoint {
        const local = struct {
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
            .direction = try local.addr_to_dir(ep.bEndpointAddress),
            .transferType = try local.attr_to_transfer_type(ep.bmAttributes),
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
            for (ifaces) |iface_| {
                // I don't really care alternate setting
                const iface = unwarp_ifaces_desc(&iface_)[0];
                const endpoints = iface.endpoint[0..@intCast(iface.bNumEndpoints)];
                for (endpoints) |ep| {
                    const app_ep = Endpoint.from_desc(@intCast(i), iface.bInterfaceNumber, &ep) catch |e| {
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
const transfer_callback = struct {
    alloc: std.mem.Allocator,
    /// reference, not OWNED
    dev: *const DeviceContext,
    /// reference, not OWNED
    transfer: *Transfer,
    /// owned by `alloc`
    buffer: []u8,
    endpoint: Endpoint,

    pub fn dtor(self: *@This()) void {
        self.alloc.free(self.buffer);
        self.alloc.destroy(self);
    }

    /// return a function pointer to the destructor
    pub fn void_dtor() *const fn (*anyopaque) void {
        return @ptrCast(&@This().dtor);
    }

    pub fn tx(trans: [*c]usb.libusb_transfer) callconv(.C) void {
        if (trans == null) {
            @panic("null transfer");
        }
        const self: *@This() = @alignCast(@ptrCast(trans.*.user_data.?));
        self.transfer.lk.unlockShared();
        const status = transferStatusFromInt(trans.*.status) catch unreachable;
        var lg = self.dev.withLogger(logz.info());
        lg = self.endpoint.withLogger(lg);
        lg.string("status", @tagName(status))
            .int("flags", trans.*.flags)
            .string("action", "transmit")
            .log();
    }

    pub fn rx(trans: [*c]usb.libusb_transfer) callconv(.C) void {
        if (trans == null) {
            @panic("null transfer");
        }
        const self: *@This() = @alignCast(@ptrCast(trans.*.user_data.?));
        const status = transferStatusFromInt(trans.*.status) catch unreachable;
        const len: usize = @intCast(trans.*.actual_length);
        const rx_buf: []const u8 = self.buffer[0..len];
        self.transfer.lk.unlockShared();
        var lg = self.dev.withLogger(logz.info());
        lg = self.endpoint.withLogger(lg);
        lg.string("status", @tagName(status))
            .int("flags", trans.*.flags)
            .string("action", "receive")
            .log();
        if (rx_buf.len > 0) {
            var pkt_ = UsbPack.unmarshal(self.alloc, rx_buf);
            if (pkt_) |*pkt| {
                defer pkt.dtor(self.alloc);
                lg = self.dev.withLogger(logz.info());
                lg = self.endpoint.withLogger(lg);
                lg = pkt.withLogger(lg);
                lg.log();
                if (pkt.data()) |data| {
                    lg = pkt.withLogger(logz.info());
                    lg = lg.int("len", data.len);
                    // unmarshal it as `bb_get_status_out_t`
                    if (pkt.reqid == bb.BB_GET_STATUS) {
                        var st: bb.bb_get_status_out_t = undefined;
                        if (utils.fillWithBytes(&st, data)) |_| {
                            lg.fmt("status", "{any}", .{st}).log();
                        } else |e| {
                            lg = self.dev.withLogger(logz.err());
                            lg = self.endpoint.withLogger(lg);
                            lg.string("what", "failed to fill struct")
                                .err(e)
                                .log();
                        }
                    }
                } else |_| {}
            } else |err| {
                // failed to unmarshal
                lg = self.dev.withLogger(logz.err());
                lg = self.endpoint.withLogger(lg);
                lg.string("what", "failed to unmarshal")
                    .fmt("data", "{any}", .{rx_buf})
                    .err(err)
                    .log();
            }
        }
        // keeps receiving
        const err = usb.libusb_submit_transfer(trans);
        lg = self.dev.withLogger(logz.err());
        lg = self.endpoint.withLogger(lg);
        switch (err) {
            0 => self.transfer.lk.unlockShared(),
            usb.LIBUSB_ERROR_NO_DEVICE => {
                // upstream should monitor the device list
                // and handle the device removal
                lg.string("err", "no device").log();
            },
            usb.LIBUSB_ERROR_BUSY => {
                // should not happen, unless the transfer is be reused,
                // which should NOT happen with lock
                lg.string("err", "transfer is busy").log();
                @panic("transfer is busy");
            },
            else => {
                lg.int("code", err).string("err", "failed to submit transfer").log();
                @panic("failed to submit transfer");
            },
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
    const local = struct {
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
    const manufacturer = local.get_string_descriptor_or(hdl, desc.iManufacturer, &manufacturer_buf, "N/A");

    var product_buf: [BUF_SIZE]u8 = undefined;
    const product = local.get_string_descriptor_or(hdl, desc.iProduct, &product_buf, "N/A");

    var serial_buf: [BUF_SIZE]u8 = undefined;
    const serial = local.get_string_descriptor_or(hdl, desc.iSerialNumber, &serial_buf, "N/A");
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
    var logz_gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = false,
        .safety = false,
    }){};
    defer {
        _ = logz_gpa.deinit();
    }
    try logz.setup(logz_gpa.allocator(), .{
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
            dev.dtor();
        }
        device_list.deinit();
    }

    refreshDevList(ctx, &device_list);

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
