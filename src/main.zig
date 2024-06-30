const std = @import("std");
const logz = @import("logz");
const log = std.log;
const usb = @cImport({
    @cInclude("libusb.h");
});
const bb = @import("bb/c.zig");

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;
const XXHASH_SEED: u32 = 0x9E3779B1;

/// the essential part of the USB device.
/// you could retrieve everything elese from this
/// with libusb API
const DevCore = struct {
    self: *usb.libusb_device,
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
    core: DevCore,
    bus: u8,
    port: u8,
    /// managed by `alloc`
    ports: []const u8,
    /// managed by `alloc`
    endpoints: []Endpoint,

    pub fn dtor(self: DeviceContext) void {
        self.core.dtor();
        self.alloc.deinit();
    }

    /// attach the device information to the logger
    pub fn withLogger(self: DeviceContext, logger: logz.Logger) logz.Logger {
        return logger
            .fmt("vid", "0x{x:0>4}", .{self.core.desc.idVendor})
            .fmt("pid", "0x{x:0>4}", .{self.core.desc.idProduct})
            .int("bus", self.bus)
            .int("port", self.port);
    }

    /// hash the device by bus, port, and ports
    pub fn xxhash(self: DeviceContext) u32 {
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
        self: *usb.libusb_device,
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
                .self = dev,
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
            var lret: c_int = undefined;
            var filtered = std.ArrayList(DeviceLike).init(alloc);
            defer filtered.deinit();
            for (poll_list) |device| {
                if (device == null) {
                    continue;
                }
                var ldesc: usb.libusb_device_descriptor = undefined;
                lret = usb.libusb_get_device_descriptor(device, &ldesc);
                if (lret != 0) {
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
        ret = usb.libusb_open(d.self, &hdl);
        if (ret != 0 or hdl == null) {
            const tmp = logz.err().string("err", "failed to open device");
            d.withLogger(tmp).log();
            // lg.attach(tmp).log();
            continue;
        }
        var desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(d.self, &desc);
        if (ret != 0) {
            const tmp = logz.err().string("err", "failed to get device descriptor");
            d.withLogger(tmp).log();
            continue;
        }

        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const alloc = gpa.allocator();
        var arena = std.heap.ArenaAllocator.init(alloc);
        const heap_ports = arena.allocator().alloc(u8, d.ports.len) catch @panic("OOM");
        const eps = getEndpoints(arena.allocator(), d.self, &desc);
        @memcpy(heap_ports, d.ports);
        const dc = DeviceContext{
            .alloc = arena,
            .core = DevCore{
                .self = d.self,
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
            pub inline fn addr_to_dir(addr: u8) AppError!Direction {
                const dir = addr & usb.LIBUSB_ENDPOINT_DIR_MASK;
                const r = switch (dir) {
                    usb.LIBUSB_ENDPOINT_IN => Direction.in,
                    usb.LIBUSB_ENDPOINT_OUT => Direction.out,
                    else => return AppError.BadEnum,
                };
                return r;
            }
            pub inline fn attr_to_transfer_type(attr: u8) AppError!TransferType {
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
    var lret: c_int = undefined;
    var list = std.ArrayList(Endpoint).init(alloc);
    defer list.deinit();
    const n_config = ldesc.bNumConfigurations;
    for (0..n_config) |i| {
        var config_: ?*usb.libusb_config_descriptor = undefined;
        lret = usb.libusb_get_config_descriptor(device, @intCast(i), &config_);
        if (lret != 0 or config_ == null) {
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
    logz.info().fmt("vid", "0x{x:0>4}", .{vid}).fmt("pid", "0x{x:0>4}", .{pid}).log();
    for (endpoints) |ep| {
        logz.info()
            .int("config", ep.iConfig)
            .int("interface", ep.iInterface)
            .int("number", ep.number)
            .fmt("direction", "{s}", .{@tagName(ep.direction)})
            .fmt("transfer type", "{s}", .{@tagName(ep.transferType)})
            .int("max packet size", ep.maxPacketSize).log();
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

pub fn main() !void {
    // https://libusb.sourceforge.io/api-1.0/libusb_contexts.html
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
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
    for (device_list.items) |dev| {
        const core = &dev.core;
        const speed = usb.libusb_get_device_speed(core.self);
        printStrDesc(core.hdl, &core.desc);
        printEndpoints(core.desc.idVendor, core.desc.idProduct, dev.endpoints);
        dev.withLogger(logz.info()).string("speed", usbSpeedToString(speed)).log();
    }
}

test "simple test" {}
