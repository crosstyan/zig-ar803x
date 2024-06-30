const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");
const log = std.log;
const usb = @cImport({
    @cInclude("libusb.h");
});
const bb = @import("bb/c.zig");
const UsbPack = @import("bb/usbpack.zig").UsbPack;

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;
const XXHASH_SEED: u32 = 0x0;

/// the essential part of the USB device.
/// you could retrieve everything elese from this
/// with libusb API
const DeviceHandles = struct {
    dev: *usb.libusb_device,
    hdl: *usb.libusb_device_handle,
    desc: usb.libusb_device_descriptor,

    const Self = @This();
    pub fn dtor(self: Self) void {
        usb.libusb_close(self.hdl);
    }
};

/// cast any type to a slice of u8
pub fn anytype2Slice(any: anytype) []const u8 {
    const size = @sizeOf(@TypeOf(any));
    const ptr: *const u8 = @ptrCast(&any);
    return ptr[0..size];
}

const DeviceContext = struct {
    alloc: std.heap.ArenaAllocator,
    core: DeviceHandles,
    bus: u8,
    port: u8,
    /// managed by `alloc`
    ports: []const u8,
    /// managed by `alloc`
    endpoints: []Endpoint,

    const Self = @This();

    pub fn dev(self: Self) *usb.libusb_device {
        return self.core.dev;
    }

    pub fn hdl(self: Self) *usb.libusb_device_handle {
        return self.core.hdl;
    }

    pub fn desc(self: Self) *const usb.libusb_device_descriptor {
        return &self.core.desc;
    }

    pub fn dtor(self: Self) void {
        self.core.dtor();
        self.alloc.deinit();
    }

    /// attach the device information to the logger
    pub fn withLogger(self: Self, logger: logz.Logger) logz.Logger {
        return logger
            .fmt("vid", "0x{x:0>4}", .{self.core.desc.idVendor})
            .fmt("pid", "0x{x:0>4}", .{self.core.desc.idProduct})
            .int("bus", self.bus)
            .int("port", self.port);
    }

    /// hash the device by bus, port, and ports
    pub fn xxhash(self: Self) u32 {
        var h = std.hash.XxHash32.init(XXHASH_SEED);
        h.update(anytype2Slice(self.bus));
        h.update(anytype2Slice(self.port));
        h.update(self.ports);
        return h.final();
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

const AppError = error{
    BadDescriptor,
    BadPortNumbers,
    BadEnum,
};
const BadEnum = error{BadEnum};

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

        pub fn withLogger(self: @This(), logger: logz.Logger) logz.Logger {
            return logger
                .fmt("vid", "0x{x:0>4}", .{self.vid})
                .fmt("pid", "0x{x:0>4}", .{self.pid})
                .int("bus", self.bus)
                .int("port", self.port);
        }

        /// hash the device by bus, port, and ports
        pub fn xxhash(self: @This()) u32 {
            var h = std.hash.XxHash32.init(XXHASH_SEED);
            h.update(anytype2Slice(self.bus));
            h.update(anytype2Slice(self.port));
            h.update(self.ports);
            return h.final();
        }
    };

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
        ///   - right: devices that should be added to the context list (`DeviceLike` that could be used to initialite a device)
        pub fn call(
            self: @This(),
            alloc: std.mem.Allocator,
            poll_list: []const ?*usb.libusb_device,
        ) struct { std.ArrayList(*const DeviceContext), std.ArrayList(DeviceLike) } {
            var ret: c_int = undefined;
            var filtered = std.ArrayList(DeviceLike).init(alloc);
            defer filtered.deinit();
            for (poll_list) |device| {
                if (device == null) {
                    continue;
                }
                var ldesc: usb.libusb_device_descriptor = undefined;
                ret = usb.libusb_get_device_descriptor(device, &ldesc);
                if (ret != 0) {
                    continue;
                }
                if (ldesc.idVendor == ARTO_RTOS_VID and ldesc.idProduct == ARTO_RTOS_PID) {
                    const dev_like = DeviceLike.from_device(device.?) catch {
                        continue;
                    };
                    filtered.append(dev_like) catch @panic("OOM");
                }
            }

            const DEFAULT_CAP = 4;
            var left = std.ArrayList(*const DeviceContext).init(alloc);
            left.ensureTotalCapacity(DEFAULT_CAP) catch @panic("OOM");
            var right = std.ArrayList(DeviceLike).init(alloc);
            right.ensureTotalCapacity(DEFAULT_CAP) catch @panic("OOM");
            var intersec = std.ArrayList(DeviceLike).init(alloc);
            intersec.ensureTotalCapacity(DEFAULT_CAP) catch @panic("OOM");
            defer intersec.deinit();

            // TODO: improve the performance by using a hash set or a hash map
            for (self.ctx_list) |*dc| {
                var found = false;
                const lhash = dc.xxhash();
                inner: for (filtered.items) |dl| {
                    const rhash = dl.xxhash();
                    if (lhash == rhash) {
                        found = true;
                        intersec.append(dl) catch @panic("OOM");
                        break :inner;
                    }
                }

                if (!found) {
                    left.append(dc) catch @panic("OOM");
                }
            }

            for (filtered.items) |fdl| {
                var found = false;
                const rhash = fdl.xxhash();
                inner: for (intersec.items) |idl| {
                    const lhash = idl.xxhash();
                    if (lhash == rhash) {
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

    for (r.items) |d| {
        var ret: c_int = undefined;
        var hdl: ?*usb.libusb_device_handle = null;
        ret = usb.libusb_open(d.dev, &hdl);
        if (ret != 0 or hdl == null) {
            const tmp = logz.err().string("err", "failed to open device");
            d.withLogger(tmp).log();
            continue;
        }
        var desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(d.dev, &desc);
        if (ret != 0) {
            const tmp = logz.err().string("err", "failed to get device descriptor");
            d.withLogger(tmp).log();
            continue;
        }

        var gpa = std.heap.GeneralPurposeAllocator(.{
            .thread_safe = true,
        }){};
        const alloc = gpa.allocator();
        var arena = std.heap.ArenaAllocator.init(alloc);
        const heap_ports = arena.allocator().alloc(u8, d.ports.len) catch @panic("OOM");
        const eps = getEndpoints(arena.allocator(), d.dev, &desc);
        @memcpy(heap_ports, d.ports);
        const dc = DeviceContext{
            .alloc = arena,
            .core = DeviceHandles{
                .dev = d.dev,
                .hdl = hdl.?,
                .desc = desc,
            },
            .bus = d.bus,
            .port = d.port,
            .ports = heap_ports,
            .endpoints = eps,
        };
        ctx_list.append(dc) catch @panic("OOM");
        const tmp = logz.info().string("action", "added");
        dc.withLogger(tmp).log();
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
                    else => return AppError.BadEnum,
                };
                return r;
            }
            pub inline fn attr_to_transfer_type(attr: u8) BadEnum!TransferType {
                const r = switch (usbEndpointTransferType(attr)) {
                    usb.LIBUSB_TRANSFER_TYPE_CONTROL => TransferType.control,
                    usb.LIBUSB_TRANSFER_TYPE_ISOCHRONOUS => TransferType.isochronous,
                    usb.LIBUSB_TRANSFER_TYPE_BULK => TransferType.bulk,
                    usb.LIBUSB_TRANSFER_TYPE_INTERRUPT => TransferType.interrupt,
                    else => return AppError.BadEnum,
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
};

pub fn getEndpoints(alloc: std.mem.Allocator, device: *usb.libusb_device, ldesc: *const usb.libusb_device_descriptor) []Endpoint {
    var ret: c_int = undefined;
    var list = std.ArrayList(Endpoint).init(alloc);
    defer list.deinit();
    const n_config = ldesc.bNumConfigurations;
    for (0..n_config) |i| {
        var config_: ?*usb.libusb_config_descriptor = undefined;
        ret = usb.libusb_get_config_descriptor(device, @intCast(i), &config_);
        if (ret != 0 or config_ == null) {
            continue;
        }
        const config = config_.?;
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

// enum libusb_transfer_status {
//     LIBUSB_TRANSFER_COMPLETED,
//     LIBUSB_TRANSFER_ERROR,
//     LIBUSB_TRANSFER_TIMED_OUT,
//     LIBUSB_TRANSFER_CANCELLED,
//     LIBUSB_TRANSFER_STALL,
//     LIBUSB_TRANSFER_NO_DEVICE,
//     LIBUSB_TRANSFER_OVERFLOW,
// };
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
        else => return AppError.BadEnum,
    };
}

pub fn main() !void {
    // https://libusb.sourceforge.io/api-1.0/libusb_contexts.html
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
    try logz.setup(alloc, .{
        .level = .Debug,
        .pool_size = 96,
        .buffer_size = 4096,
        .large_buffer_count = 8,
        .large_buffer_size = 16384,
        .output = .stdout,
        .encoding = .logfmt,
    });
    defer logz.deinit();

    var ctx_: ?*usb.libusb_context = null;
    var ret: c_int = undefined;
    ret = usb.libusb_init_context(&ctx_, null, 0);
    if (ret != 0) {
        return std.debug.panic("libusb_init_context failed: {}", .{ret});
    }
    const ctx = ctx_.?;
    defer usb.libusb_exit(ctx);
    const pc_version = usb.libusb_get_version();
    const p_version: ?*const usb.libusb_version = @ptrCast(pc_version);
    logz.info().fmt("libusb version", "{}.{}.{}.{}", .{ p_version.?.major, p_version.?.minor, p_version.?.micro, p_version.?.nano }).log();
    var device_list = std.ArrayList(DeviceContext).init(alloc);
    defer device_list.deinit();
    refreshDevList(ctx, &device_list);

    const tx_transfer = usb.libusb_alloc_transfer(0);
    if (tx_transfer == null) {
        return std.debug.panic("failed to allocate rx transfer", .{});
    }
    defer usb.libusb_free_transfer(tx_transfer);

    const rx_transfer = usb.libusb_alloc_transfer(0);
    if (rx_transfer == null) {
        return std.debug.panic("failed to allocate rx transfer", .{});
    }
    defer usb.libusb_free_transfer(rx_transfer);

    for (device_list.items) |dev| {
        const speed = usb.libusb_get_device_speed(dev.dev());
        printStrDesc(dev.hdl(), dev.desc());
        printEndpoints(dev.desc().idVendor, dev.desc().idProduct, dev.endpoints);
        dev.withLogger(logz.info()).string("speed", usbSpeedToString(speed)).log();
        if (builtin.os.tag != .windows) {
            ret = usb.libusb_set_auto_detach_kernel_driver(dev.hdl(), 1);
            if (ret != 0) {
                dev.withLogger(logz.err())
                    .string("err", "failed to set auto detach kernel driver")
                    .log();
            }
        }
        ret = usb.libusb_claim_interface(dev.hdl(), 0);
        if (ret != 0) {
            dev.withLogger(logz.err())
                .string("err", "failed to claim interface")
                .log();
        }
        for (dev.endpoints) |*ep| {
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
            const bulk_transfer_callback = struct {
                alloc: std.mem.Allocator,
                dev: DeviceContext,
                buffer: []u8,
                pub fn tx(trans: [*c]usb.libusb_transfer) callconv(.C) void {
                    if (trans == null) {
                        return;
                    }
                    const self: *@This() = @alignCast(@ptrCast(trans.*.user_data.?));
                    defer self.alloc.destroy(self);
                    defer self.alloc.free(self.buffer);
                    const status = transferStatusFromInt(trans.*.status) catch unreachable;
                    self.dev.withLogger(logz.info())
                        .string("status", @tagName(status))
                        .int("flags", trans.*.flags)
                        .string("action", "transfer completed")
                        .log();
                }
                pub fn rx(trans: [*c]usb.libusb_transfer) callconv(.C) void {
                    if (trans == null) {
                        return;
                    }
                    const self: *@This() = @alignCast(@ptrCast(trans.*.user_data.?));
                    const status = transferStatusFromInt(trans.*.status) catch unreachable;
                    const len: usize = @intCast(trans.*.actual_length);
                    const rx_buf: []const u8 = self.buffer[0..len];
                    self.dev.withLogger(logz.info())
                        .int("len", len)
                        .int("flags", trans.*.flags)
                        .string("status", @tagName(status))
                        .string("action", "receive")
                        .fmt("data", "{any}", .{rx_buf})
                        .log();
                    const ok = usb.libusb_submit_transfer(trans);
                    if (ok != 0) {
                        self.dev.withLogger(logz.err())
                            .int("code", ok)
                            .string("err", "failed to submit transfer")
                            .log();
                    }
                }
            };
            if (ep.direction == Direction.out and ep.transferType == TransferType.bulk) {
                const l_alloc = alloc;
                var cb = l_alloc.create(bulk_transfer_callback) catch @panic("OOM");
                cb.alloc = l_alloc;
                cb.dev = dev;
                const header = UsbPack{
                    .msgid = 0x0,
                    .reqid = bb.BB_GET_STATUS,
                    .sta = 0x0,
                    .data = null,
                };
                const tx_buffer = header.marshal(l_alloc) catch @panic("OOM");
                cb.buffer = tx_buffer;
                usb.libusb_fill_bulk_transfer(
                    tx_transfer,
                    dev.hdl(),
                    ep.addr,
                    tx_buffer.ptr,
                    @intCast(tx_buffer.len),
                    bulk_transfer_callback.tx,
                    cb,
                    1000,
                );
                dev.withLogger(logz.info())
                    .int("interface", ep.iInterface)
                    .fmt("address", "0x{x:0>2}", .{ep.addr})
                    .string("direction", @tagName(ep.direction))
                    .string("action", "submitting transfer")
                    .log();
                ret = usb.libusb_submit_transfer(tx_transfer);
                if (ret != 0) {
                    dev.withLogger(logz.err())
                        .int("interface", ep.iInterface)
                        .fmt("address", "0x{x:0>2}", .{ep.addr})
                        .string("direction", @tagName(ep.direction))
                        .int("code", ret)
                        .string("err", "failed to submit transfer")
                        .log();
                }
            } else if (ep.direction == Direction.in and ep.transferType == TransferType.bulk) {
                const l_alloc = alloc;
                var cb = l_alloc.create(bulk_transfer_callback) catch @panic("OOM");
                cb.alloc = l_alloc;
                cb.dev = dev;
                const rx_buffer = l_alloc.alloc(u8, ep.maxPacketSize) catch @panic("OOM");
                cb.buffer = rx_buffer;
                usb.libusb_fill_bulk_transfer(
                    rx_transfer,
                    dev.hdl(),
                    ep.addr,
                    rx_buffer.ptr,
                    @intCast(rx_buffer.len),
                    bulk_transfer_callback.rx,
                    cb,
                    1000,
                );
                dev.withLogger(logz.info())
                    .int("interface", ep.iInterface)
                    .fmt("address", "0x{x:0>2}", .{ep.addr})
                    .string("direction", @tagName(ep.direction))
                    .string("action", "submitting transfer")
                    .log();
                ret = usb.libusb_submit_transfer(rx_transfer);
                if (ret != 0) {
                    dev.withLogger(logz.err())
                        .int("interface", ep.iInterface)
                        .fmt("address", "0x{x:0>2}", .{ep.addr})
                        .string("direction", @tagName(ep.direction))
                        .int("code", ret)
                        .string("err", "failed to submit transfer")
                        .log();
                }
            }
        }
    }
    // https://libusb.sourceforge.io/api-1.0/libusb_mtasync.html
    // https://stackoverflow.com/questions/45672717/how-to-force-a-libusb-event-so-that-libusb-handle-events-returns
    // https://libusb.sourceforge.io/api-1.0/group__libusb__poll.html
    // https://www.reddit.com/r/Zig/comments/11mr0r8/defer_errdefer_and_sigint_ctrlc/
    // https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/signal
    // TODO: handle Ctrl+C (Unix is SIGINT, Windows is a different story)
    while (true) {
        ret = usb.libusb_handle_events(ctx);
        if (ret != 0) {
            logz.err().string("err", "failed to handle events").log();
            break;
        }
    }
}
