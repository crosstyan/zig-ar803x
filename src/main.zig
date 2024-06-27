const std = @import("std");
const usb = @cImport({
    @cInclude("libusb-1.0/libusb.h");
});
const log = std.log;

pub fn main() !void {
    const ret = usb.libusb_init(null);
    log.info("libusb_init returned: {}", .{ret});
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
