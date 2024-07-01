const std = @import("std");

pub fn xorCheck(buf: []const u8) u8 {
    var xor: u8 = 0xff;
    for (buf) |byte| {
        xor ^= byte;
    }
    return xor;
}

pub const AllocError = std.mem.Allocator.Error;
pub const UnmarshalError = error{
    InvalidStartMagic,
    InvalidEndMagic,
    OutOfRange,
};

// Note that this struct is NOT owning `data`
pub const UsbPack = packed struct {
    reqid: u32,
    msgid: u32,
    sta: i32,
    data: ?*[]const u8,

    const Self = @This();
    // usbpack 的固定长度
    const fixedPackBase = 1 + 4 + 4 + 4 + 4 + 1 + 1;

    /// marshal packs the struct into a byte slice
    ///
    /// Please note that the returned slice is owned by the `alloc` allocator
    pub fn marshal(self: Self, alloc: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(alloc);
        defer list.deinit();
        if (self.data != null) {
            try list.ensureTotalCapacity(self.data.?.len + Self.fixedPackBase);
        } else {
            try list.ensureTotalCapacity(Self.fixedPackBase);
        }
        var writer = list.writer();
        // buf[offset] = 0xaa;
        // offset += 1;
        try writer.writeByte(0xaa);
        if (self.data != null) {
            const l: u32 = @intCast(self.data.?.len);
            try writer.writeInt(u32, l, std.builtin.Endian.little);
        } else {
            try writer.writeInt(u32, 0, std.builtin.Endian.little);
        }
        try writer.writeInt(u32, self.reqid, std.builtin.Endian.big);
        try writer.writeInt(u32, self.msgid, std.builtin.Endian.big);
        try writer.writeInt(i32, self.sta, std.builtin.Endian.big);
        const xor = xorCheck(list.items);
        try writer.writeByte(xor);
        if (self.data != null) {
            _ = try writer.write(self.data.?.*);
        }
        try writer.writeByte(0xbb);
        return list.toOwnedSlice();
    }

    /// unmarshal unpacks the byte slice into a struct.
    ///
    /// note that the `data` field is owned by the `alloc` allocator
    pub fn unmarshal(alloc: std.mem.Allocator, buf: []const u8) !Self {
        if (buf.len < Self.fixedPackBase) {
            return UnmarshalError.OutOfRange;
        }
        var stream = std.io.fixedBufferStream(buf);
        var reader = stream.reader();
        const h = try reader.readByte();
        if (h != 0xaa) {
            return UnmarshalError.InvalidStartMagic;
        }
        const dataLen = try reader.readInt(u32, std.builtin.Endian.little);

        const reqid = try reader.readInt(u32, std.builtin.Endian.big);
        const msgid = try reader.readInt(u32, std.builtin.Endian.big);
        const sta = try reader.readInt(i32, std.builtin.Endian.big);
        // skip xor
        const xor = try reader.readByte();
        _ = xor;
        var p_data: ?*[]u8 = null;
        if (dataLen > 0) {
            var ptr = try alloc.create([]u8);
            const out = try alloc.alloc(u8, dataLen);
            const sz = try reader.read(out);
            ptr.* = out;
            ptr.len = sz;
            p_data = ptr;
        }
        const end = try reader.readByte();
        if (end != 0xbb) {
            return UnmarshalError.InvalidEndMagic;
        }
        return Self{ .reqid = reqid, .msgid = msgid, .sta = sta, .data = p_data };
    }

    pub fn dtor(self: Self, alloc: std.mem.Allocator) void {
        if (self.data) |data| {
            alloc.free(data.*);
            alloc.destroy(data);
        }
    }
};
