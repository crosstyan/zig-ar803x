const std = @import("std");
const logz = @import("logz");
const log = std.log;
const usb = @cImport({
    @cInclude("libusb.h");
});
const bb = @import("bb/c.zig");

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;

// the essential part of the USB device
const DeviceCore = struct {
    self: *usb.libusb_device,
    hdl: *usb.libusb_device_handle,
    desc: usb.libusb_device_descriptor,

    const Self = @This();
    pub fn dtor(self: Self) void {
        if (self.hdl != null) {
            usb.libusb_close(self.hdl);
        }
    }
};

const Device = struct {
    core: DeviceCore,
    endpoints: []Endpoint,
};

fn refresh_atro_device(ctx: *usb.libusb_context, list: *std.ArrayList(Device)) void {
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
    var device_list = c_device_list[0..@intCast(sz)];
    device_list.len = @intCast(sz);

    // https://www.reddit.com/r/Zig/comments/18p7w7v/making_a_struct_inside_a_function_makes_it_static/
    // https://www.reddit.com/r/Zig/comments/ard50a/static_local_variables_in_zig/
    const is_existed = struct {
        list: *std.ArrayList(Device),
        const Self = @This();

        pub fn call(self: Self, dev: *usb.libusb_device, desc: *usb.libusb_device_descriptor) bool {
            // Unless the OS does something funky, or you are hot-plugging USB
            // extension cards, the port number returned by this call is usually
            // guaranteed to be uniquely tied to a physical port, meaning that
            // different devices plugged on the same physical port should return
            // the same port number.
            const bus = usb.libusb_get_bus_number(dev);
            const port = usb.libusb_get_port_number(dev);
            for (self.list.items) |d| {
                const core = &d.core;
                const target_bus = usb.libusb_get_bus_number(core.self);
                const target_port = usb.libusb_get_port_number(core.self);
                if (bus == target_bus and
                    port == target_port and
                    desc.idVendor == core.desc.idVendor and
                    desc.idProduct == core.desc.idProduct)
                {
                    return true;
                }
            }
            return false;
        }
    };

    const handle_device = struct {
        list: *std.ArrayList(Device),
        const Self = @This();

        pub fn call(self: Self, device: *usb.libusb_device, out: *Device) bool {
            var lret: c_int = undefined;
            var ldesc: usb.libusb_device_descriptor = undefined;
            lret = usb.libusb_get_device_descriptor(device, &ldesc);
            if (lret != 0) {
                return false;
            }
            if (ldesc.idVendor == ARTO_RTOS_VID and ldesc.idProduct == ARTO_RTOS_PID) {
                if ((is_existed{ .list = self.list }).call(device, &ldesc)) {
                    return false;
                }
                var hdl: ?*usb.libusb_device_handle = null;
                lret = usb.libusb_open(device, &hdl);
                if (lret != 0) {
                    logz.err()
                        .fmt("vid", "0x{x:0>4}", .{ldesc.idVendor})
                        .fmt("pid", "0x{x:0>4}", .{ldesc.idProduct})
                        .int("code", lret)
                        .string("what", "can't open device")
                        .log();
                    return false;
                }
                const alloc = self.list.allocator;
                var ep_list = std.ArrayList(Endpoint).init(alloc);
                defer ep_list.deinit();
                get_endpoints(device, &ldesc, &ep_list);
                out.core.self = device;
                out.core.hdl = hdl.?;
                out.core.desc = ldesc;
                out.endpoints = ep_list.toOwnedSlice() catch @panic("OOM");
                return true;
            }
            return false;
        }
    };

    logz.debug().int("number of device", sz).log();
    for (device_list) |device| {
        if (device == null) {
            continue;
        }
        var dev: Device = undefined;
        if ((handle_device{ .list = list }).call(device.?, &dev)) {
            list.append(dev) catch @panic("OOM");
        }
    }
}

pub fn usb_endpoint_number(ep_addr: u8) u8 {
    return ep_addr & 0x07;
}

pub fn usb_endpoint_transfer_type(ep_attr: u8) u8 {
    return ep_attr & @as(u8, usb.LIBUSB_TRANSFER_TYPE_MASK);
}

pub fn unwarp_ifaces_desc(iface: *const usb.libusb_interface) []const usb.libusb_interface_descriptor {
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

    pub fn from_desc(iConfig: u8, iInterface: u8, ep: *const usb.libusb_endpoint_descriptor) Endpoint {
        const local = struct {
            pub fn addr_to_dir(addr: u8) Direction {
                const dir = addr & usb.LIBUSB_ENDPOINT_DIR_MASK;
                const r = switch (dir) {
                    usb.LIBUSB_ENDPOINT_IN => Direction.in,
                    usb.LIBUSB_ENDPOINT_OUT => Direction.out,
                    else => @panic("invalid direction"),
                };
                return r;
            }
            pub fn attr_to_transfer_type(attr: u8) TransferType {
                const r = switch (usb_endpoint_transfer_type(attr)) {
                    usb.LIBUSB_TRANSFER_TYPE_CONTROL => TransferType.control,
                    usb.LIBUSB_TRANSFER_TYPE_ISOCHRONOUS => TransferType.isochronous,
                    usb.LIBUSB_TRANSFER_TYPE_BULK => TransferType.bulk,
                    usb.LIBUSB_TRANSFER_TYPE_INTERRUPT => TransferType.interrupt,
                    else => @panic("invalid transfer type"),
                };
                return r;
            }
        };
        return Endpoint{
            .iConfig = iConfig,
            .iInterface = iInterface,
            .addr = ep.bEndpointAddress,
            .number = usb_endpoint_number(ep.bEndpointAddress),
            .direction = local.addr_to_dir(ep.bEndpointAddress),
            .transferType = local.attr_to_transfer_type(ep.bmAttributes),
            .maxPacketSize = ep.wMaxPacketSize,
        };
    }
};

pub fn get_endpoints(device: *usb.libusb_device, ldesc: *const usb.libusb_device_descriptor, list: *std.ArrayList(Endpoint)) void {
    var lret: c_int = undefined;
    const n_config = ldesc.bNumConfigurations;
    for (0..n_config) |i| {
        var p_config_: ?*usb.libusb_config_descriptor = undefined;
        lret = usb.libusb_get_config_descriptor(device, @intCast(i), &p_config_);
        if (lret != 0 or p_config_ == null) {
            return;
        }
        const p_config = p_config_.?;
        const ifaces = p_config.interface[0..@intCast(p_config.bNumInterfaces)];
        for (ifaces) |iface_| {
            // I don't really care alternate setting
            const iface = unwarp_ifaces_desc(&iface_)[0];
            const endpoints = iface.endpoint[0..@intCast(iface.bNumEndpoints)];
            for (endpoints) |ep| {
                list.append(Endpoint.from_desc(@intCast(i), iface.bInterfaceNumber, &ep)) catch @panic("OOM");
            }
        }
    }
}

pub fn print_endpoints(vid: u16, pid: u16, endpoints: []const Endpoint) void {
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
fn print_str_desc(hdl: *usb.libusb_device_handle, desc: *const usb.libusb_device_descriptor) void {
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

pub fn usb_speed_to_string(speed: c_int) []const u8 {
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
        _ = gpa.deinit();
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
    var device_list = std.ArrayList(Device).init(alloc);
    defer device_list.deinit();
    refresh_atro_device(ctx, &device_list);
    for (device_list.items) |dev| {
        const core = &dev.core;
        const speed = usb.libusb_get_device_speed(core.self);
        const bus = usb.libusb_get_bus_number(core.self);
        const port = usb.libusb_get_port_number(core.self);
        logz.info()
            .fmt("vid", "0x{x:0>4}", .{core.desc.idVendor})
            .fmt("pid", "0x{x:0>4}", .{core.desc.idProduct})
            .int("bus", bus)
            .int("port", port)
            .string("speed", usb_speed_to_string(speed)).log();
        print_str_desc(core.hdl, &core.desc);
    }
}

test "simple test" {}
