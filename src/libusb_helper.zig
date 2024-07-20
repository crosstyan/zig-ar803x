const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");
const common = @import("app_common.zig");
pub const c = @cImport({
    @cInclude("libusb.h");
});

const AppError = common.AppError;
const BadEnum = common.BadEnum;
const LengthNotEqual = common.LengthNotEqual;
const ClosedError = common.ClosedError;

pub const LIBUSB_OK = c.LIBUSB_SUCCESS;

pub const LibUsbError = error{
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

pub inline fn usbEndpointNum(ep_addr: u8) u8 {
    return ep_addr & 0x07;
}

pub inline fn usbEndpointTransferType(ep_attr: u8) u8 {
    return ep_attr & @as(u8, c.LIBUSB_TRANSFER_TYPE_MASK);
}

pub const Direction = enum {
    in,
    out,
};

pub const TransferType = enum {
    control,
    isochronous,
    bulk,
    interrupt,
};

pub const Endpoint = struct {
    /// config index
    iConfig: u8,
    /// interface index
    iInterface: u8,
    addr: u8,
    number: u8,
    direction: Direction,
    transferType: TransferType,
    maxPacketSize: u16,

    pub fn fromDesc(iConfig: u8, iInterface: u8, ep: *const c.libusb_endpoint_descriptor) AppError!Endpoint {
        const local_t = struct {
            pub inline fn addr_to_dir(addr: u8) BadEnum!Direction {
                const dir = addr & c.LIBUSB_ENDPOINT_DIR_MASK;
                const r = switch (dir) {
                    c.LIBUSB_ENDPOINT_IN => Direction.in,
                    c.LIBUSB_ENDPOINT_OUT => Direction.out,
                    else => return BadEnum.BadEnum,
                };
                return r;
            }
            pub inline fn attr_to_transfer_type(attr: u8) BadEnum!TransferType {
                const r = switch (usbEndpointTransferType(attr)) {
                    c.LIBUSB_TRANSFER_TYPE_CONTROL => TransferType.control,
                    c.LIBUSB_TRANSFER_TYPE_ISOCHRONOUS => TransferType.isochronous,
                    c.LIBUSB_TRANSFER_TYPE_BULK => TransferType.bulk,
                    c.LIBUSB_TRANSFER_TYPE_INTERRUPT => TransferType.interrupt,
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

pub fn logWithDevice(logger: logz.Logger, device: *c.libusb_device, desc: *const c.libusb_device_descriptor) logz.Logger {
    const vid = desc.idVendor;
    const pid = desc.idProduct;
    const bus = c.libusb_get_bus_number(device);
    const port = c.libusb_get_port_number(device);
    return logger
        .fmt("vid", "0x{x:0>4}", .{vid})
        .fmt("pid", "0x{x:0>4}", .{pid})
        .int("bus", bus)
        .int("port", port);
}

pub fn getEndpoints(alloc: std.mem.Allocator, device: *c.libusb_device, ldesc: *const c.libusb_device_descriptor) []Endpoint {
    var ret: c_int = undefined;
    var list = std.ArrayList(Endpoint).init(alloc);
    defer list.deinit();
    const n_config = ldesc.bNumConfigurations;
    for (0..n_config) |i| {
        var config_: ?*c.libusb_config_descriptor = undefined;
        ret = c.libusb_get_config_descriptor(device, @intCast(i), &config_);
        if (ret != 0) continue;
        if (config_) |config| {
            const ifaces = config.interface[0..@intCast(config.bNumInterfaces)];
            for (ifaces) |iface_alt| {
                const iface_alts = iface_alt.altsetting[0..@intCast(iface_alt.num_altsetting)];
                if (iface_alts.len == 0) continue;

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

pub const Speed = enum {
    unknown,
    low,
    full,
    high,
    super,
    super_plus,

    pub fn fromC(speed: c_int) BadEnum!Speed {
        return switch (speed) {
            c.LIBUSB_SPEED_UNKNOWN => Speed.unknown,
            c.LIBUSB_SPEED_LOW => Speed.low,
            c.LIBUSB_SPEED_FULL => Speed.full,
            c.LIBUSB_SPEED_HIGH => Speed.high,
            c.LIBUSB_SPEED_SUPER => Speed.super,
            c.LIBUSB_SPEED_SUPER_PLUS => Speed.super_plus,
            else => BadEnum.BadEnum,
        };
    }

    pub fn getDeviceSpeed(device: *c.libusb_device) BadEnum!Speed {
        const speed = c.libusb_get_device_speed(device);
        return Speed.fromC(speed);
    }
};

pub const TransferStatus = enum {
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
        c.LIBUSB_TRANSFER_COMPLETED => TransferStatus.completed,
        c.LIBUSB_TRANSFER_ERROR => TransferStatus.err,
        c.LIBUSB_TRANSFER_TIMED_OUT => TransferStatus.timed_out,
        c.LIBUSB_TRANSFER_CANCELLED => TransferStatus.cancelled,
        c.LIBUSB_TRANSFER_STALL => TransferStatus.stall,
        c.LIBUSB_TRANSFER_NO_DEVICE => TransferStatus.no_device,
        c.LIBUSB_TRANSFER_OVERFLOW => TransferStatus.overflow,
        else => return BadEnum.BadEnum,
    };
}

/// Get a string descriptor or return a default value
pub fn dynStringDescriptorOr(alloc: std.mem.Allocator, hdl: *c.libusb_device_handle, idx: u8, default: []const u8) []const u8 {
    const BUF_SIZE = 128;
    var buf: [BUF_SIZE]u8 = undefined;
    const sz: c_int = c.libusb_get_string_descriptor_ascii(hdl, idx, &buf, @intCast(buf.len));
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
pub fn printStrDesc(hdl: *c.libusb_device_handle, desc: *const c.libusb_device_descriptor) void {
    const local_t = struct {
        /// Get string descriptor or return a default value.
        /// Note that the caller must ensure the buffer is large enough.
        /// The return slice will be a slice of the buffer.
        pub fn get_string_descriptor_or(lhdl: *c.libusb_device_handle, idx: u8, buf: []u8, default: []const u8) []const u8 {
            var lsz: c_int = undefined;
            lsz = c.libusb_get_string_descriptor_ascii(lhdl, idx, buf.ptr, @intCast(buf.len));
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

pub fn libusb_error_2_set(err: c_int) LibUsbError {
    return switch (err) {
        c.LIBUSB_ERROR_IO => LibUsbError.IO,
        c.LIBUSB_ERROR_INVALID_PARAM => LibUsbError.InvalidParam,
        c.LIBUSB_ERROR_ACCESS => LibUsbError.Access,
        c.LIBUSB_ERROR_NO_DEVICE => LibUsbError.NoDevice,
        c.LIBUSB_ERROR_NOT_FOUND => LibUsbError.NotFound,
        c.LIBUSB_ERROR_BUSY => LibUsbError.Busy,
        c.LIBUSB_ERROR_TIMEOUT => LibUsbError.Timeout,
        c.LIBUSB_ERROR_OVERFLOW => LibUsbError.Overflow,
        c.LIBUSB_ERROR_PIPE => LibUsbError.Pipe,
        c.LIBUSB_ERROR_INTERRUPTED => LibUsbError.Interrupted,
        c.LIBUSB_ERROR_NO_MEM => LibUsbError.NoMem,
        c.LIBUSB_ERROR_NOT_SUPPORTED => LibUsbError.NotSupported,
        c.LIBUSB_ERROR_OTHER => LibUsbError.Other,
        else => std.debug.panic("unknown libusb error code: {}", .{err}),
    };
}
