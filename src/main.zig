const std = @import("std");
const logz = @import("logz");
const log = std.log;
const usb = @cImport({
    @cInclude("libusb.h");
});
const bb = @import("bb/c.zig");

const ARTO_RTOS_VID: u16 = 0x1d6b;
const ARTO_RTOS_PID: u16 = 0x8030;

/// Print the manufacturer, product, serial number of a device.
/// If a string descriptor is not available, 'N/A' will be display.
fn print_dev_info(hdl: *usb.libusb_device_handle, desc: *usb.libusb_device_descriptor) void {
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
    logz.info().int("number of device", sz).log();

    // https://www.reddit.com/r/Zig/comments/18p7w7v/making_a_struct_inside_a_function_makes_it_static/
    // https://www.reddit.com/r/Zig/comments/ard50a/static_local_variables_in_zig/
    const handle_device = struct {
        pub fn call(device: *usb.libusb_device) void {
            var lret: c_int = undefined;
            var ldesc: usb.libusb_device_descriptor = undefined;
            lret = usb.libusb_get_device_descriptor(device, &ldesc);
            if (lret != 0) {
                return;
            }
            var hdl: ?*usb.libusb_device_handle = null;
            // zig use a unique syntax for string formatting
            // https://github.com/ziglang/zig/blob/master/lib/std/fmt.zig
            lret = usb.libusb_open(device, &hdl);
            if (lret != 0) {
                logz.warn()
                    .fmt("vid", "0x{x:0>4}", .{ldesc.idVendor})
                    .fmt("pid", "0x{x:0>4}", .{ldesc.idProduct})
                    .int("code", lret)
                    .string("what", "can't open device")
                    .log();
                return;
            }
            defer usb.libusb_close(hdl);
            logz.warn()
                .fmt("vid", "0x{x:0>4}", .{ldesc.idVendor})
                .fmt("pid", "0x{x:0>4}", .{ldesc.idProduct})
                .string("speed", usb_speed_to_string(usb.libusb_get_device_speed(device))).log();

            print_dev_info(hdl.?, &ldesc);
            const n_config = ldesc.bNumConfigurations;
            for (0..n_config) |i| {
                var p_config_: ?*usb.libusb_config_descriptor = undefined;
                lret = usb.libusb_get_config_descriptor(device, @intCast(i), &p_config_);
                if (lret != 0 or p_config_ == null) {
                    return;
                }
                const p_config = p_config_.?;
                logz.info()
                    .fmt("vid", "0x{x:0>4}", .{ldesc.idVendor})
                    .fmt("pid", "0x{x:0>4}", .{ldesc.idProduct})
                    .int("configIndex", i)
                    .int("bNumInterfaces", p_config.bNumInterfaces)
                    .int("bConfigurationValue", p_config.bConfigurationValue)
                    .int("iConfiguration", p_config.iConfiguration).log();
            }
        }
    };
    for (device_list) |device| {
        handle_device.call(device.?);
    }
}

test "simple test" {}
