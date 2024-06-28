const std = @import("std");
const usb = @cImport({
    @cInclude("libusb.h");
});
const log = std.log;

pub fn main() !void {
    // https://libusb.sourceforge.io/api-1.0/libusb_contexts.html
    var p_context: ?*usb.libusb_context = null;
    var ret: c_int = undefined;
    ret = usb.libusb_init_context(&p_context, null, 0);
    if (ret != 0) {
        return std.debug.panic("libusb_init_context failed: {}", .{ret});
    }
    defer usb.libusb_exit(p_context);
    const pc_version = usb.libusb_get_version();
    const p_version: ?*const usb.libusb_version = @ptrCast(pc_version);
    log.info("libusb version: {}.{}.{}.{}", .{ p_version.?.major, p_version.?.minor, p_version.?.micro, p_version.?.nano });
    var c_device_list: [*c]?*usb.libusb_device = undefined;
    const sz = usb.libusb_get_device_list(p_context, &c_device_list);
    var device_list = c_device_list[0..@intCast(sz)];
    device_list.len = @intCast(sz);
    log.info("device list size: {}", .{sz});
    for (device_list) |device| {
        var desc: usb.libusb_device_descriptor = undefined;
        ret = usb.libusb_get_device_descriptor(device, &desc);
        if (ret != 0) {
            continue;
        }
        var hdl: ?*usb.libusb_device_handle = null;
        ret = usb.libusb_open(device, &hdl);
        if (ret != 0) {
            log.warn("skipping, failed to open device: code={d} vid=0x{x:0>4}, pid=0x{x:0>4}", .{ ret, desc.idVendor, desc.idProduct });
            continue;
        }
        // https://github.com/ziglang/zig/blob/master/lib/std/fmt.zig
        // zig use a unique syntax for formatting
        log.info("device: vid=0x{x:0>4}, pid=0x{x:0>4}", .{ desc.idVendor, desc.idProduct });

        // print manufacturer, product, serial number
        var lsz: c_int = undefined;
        const BUF_SIZE = 256;
        var manufacturer_buf: [BUF_SIZE]u8 = undefined;
        lsz = usb.libusb_get_string_descriptor_ascii(hdl, desc.iManufacturer, &manufacturer_buf, BUF_SIZE);
        var manufacturer: []u8 = undefined;
        if (lsz > 0) {
            manufacturer = manufacturer_buf[0..@intCast(lsz)];
        } else {
            manufacturer = @constCast("N/A");
        }

        var product_buf: [BUF_SIZE]u8 = undefined;
        lsz = usb.libusb_get_string_descriptor_ascii(hdl, desc.iProduct, &product_buf, BUF_SIZE);
        var product: []u8 = undefined;
        if (lsz > 0) {
            product = product_buf[0..@intCast(lsz)];
        } else {
            product = @constCast("N/A");
        }

        var serial_buf: [BUF_SIZE]u8 = undefined;
        lsz = usb.libusb_get_string_descriptor_ascii(hdl, desc.iSerialNumber, &serial_buf, BUF_SIZE);
        var serial: []u8 = undefined;
        if (lsz > 0) {
            serial = serial_buf[0..@intCast(lsz)];
        } else {
            serial = @constCast("N/A");
        }
        log.info("manufacturer: {s}, product: {s}, serial: {s}", .{ manufacturer, product, serial });

        const n_config = desc.bNumConfigurations;
        for (0..n_config) |i| {
            var p_config_: ?*usb.libusb_config_descriptor = undefined;
            ret = usb.libusb_get_config_descriptor(device, @intCast(i), &p_config_);
            if (ret != 0 or p_config_ == null) {
                continue;
            }
            const p_config = p_config_.?;
            log.info("config: bNumInterfaces={}, bConfigurationValue={}, iConfiguration={}", .{ p_config.bNumInterfaces, p_config.bConfigurationValue, p_config.iConfiguration });
        }
    }
}

test "simple test" {}
