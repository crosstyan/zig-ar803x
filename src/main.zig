const std = @import("std");
const logz = @import("logz");
const log = std.log;
const usb = @cImport({
    @cInclude("libusb.h");
});
const bb = @import("bb/c.zig");

/// Print the manufacturer, product, serial number of a device.
/// If a string descriptor is not available, 'N/A' will be display.
fn print_infos(hdl: *usb.libusb_device_handle, desc: *usb.libusb_device_descriptor) void {
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

    var ctx: ?*usb.libusb_context = null;
    var ret: c_int = undefined;
    ret = usb.libusb_init_context(&ctx, null, 0);
    if (ret != 0) {
        return std.debug.panic("libusb_init_context failed: {}", .{ret});
    }
    defer usb.libusb_exit(ctx);
    const pc_version = usb.libusb_get_version();
    const p_version: ?*const usb.libusb_version = @ptrCast(pc_version);
    logz.info().fmt("libusb version", "{}.{}.{}.{}", .{ p_version.?.major, p_version.?.minor, p_version.?.micro, p_version.?.nano }).log();
    var c_device_list: [*c]?*usb.libusb_device = undefined;
    const sz = usb.libusb_get_device_list(ctx, &c_device_list);
    var device_list = c_device_list[0..@intCast(sz)];
    device_list.len = @intCast(sz);
    logz.info().int("number of device", sz).log();
    for (device_list) |device| {
        var desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(device, &desc);
        if (ret != 0) {
            continue;
        }
        var hdl: ?*usb.libusb_device_handle = null;
        // zig use a unique syntax for string formatting
        // https://github.com/ziglang/zig/blob/master/lib/std/fmt.zig
        ret = usb.libusb_open(device, &hdl);
        if (ret != 0) {
            logz.warn()
                .fmt("vid", "0x{x:0>4}", .{desc.idVendor})
                .fmt("pid", "0x{x:0>4}", .{desc.idProduct})
                .int("code", ret)
                .string("what", "can't open device")
                .log();
            continue;
        }
        logz.warn()
            .fmt("vid", "0x{x:0>4}", .{desc.idVendor})
            .fmt("pid", "0x{x:0>4}", .{desc.idProduct})
            .string("speed", usb_speed_to_string(usb.libusb_get_device_speed(device))).log();
        defer usb.libusb_close(hdl);

        print_infos(hdl.?, &desc);
        const n_config = desc.bNumConfigurations;
        for (0..n_config) |i| {
            var p_config_: ?*usb.libusb_config_descriptor = undefined;
            ret = usb.libusb_get_config_descriptor(device, @intCast(i), &p_config_);
            if (ret != 0 or p_config_ == null) {
                continue;
            }
            const p_config = p_config_.?;
            logz.info()
                .fmt("vid", "0x{x:0>4}", .{desc.idVendor})
                .fmt("pid", "0x{x:0>4}", .{desc.idProduct})
                .int("configIndex", i)
                .int("bNumInterfaces", p_config.bNumInterfaces)
                .int("bConfigurationValue", p_config.bConfigurationValue)
                .int("iConfiguration", p_config.iConfiguration).log();
        }
    }
}

test "simple test" {}
