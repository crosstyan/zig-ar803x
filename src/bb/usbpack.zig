const std = @import("std");
const logz = @import("logz");
const utils = @import("../utils.zig");
const LengthNotEqual = utils.LengthNotEqual;

pub fn xorCheck(buf: []const u8) u8 {
    var xor: u8 = 0xff;
    for (buf) |byte| {
        xor ^= byte;
    }
    return xor;
}

pub const UnmarshalError = error{
    InvalidStartMagic,
    InvalidEndMagic,
    LengthTooShort,
};
const NoContent = error{NoContent};
const HasContent = error{HasContent};

// Note that this struct is NOT owning `data`
pub const UsbPack = packed struct {
    reqid: u32,
    msgid: u32,
    sta: i32 = 0,
    ptr: ?[*]const u8 = null,
    len: u32 = 0,

    const Self = @This();
    // usbpack 的固定长度
    pub const fixedPackBase = 1 + 4 + 4 + 4 + 4 + 1 + 1;

    /// data combines the `ptr` and `len` fields into a valid byte slice
    ///
    /// note that the actual ownership of the data is NOT transferred
    pub fn data(self: *const Self) NoContent![]const u8 {
        if (self.ptr == null or self.len == 0) {
            return NoContent.NoContent;
        }
        return self.ptr.?[0..self.len];
    }

    pub fn hasData(self: *const Self) bool {
        return self.ptr != null and self.len > 0;
    }

    /// data returns an instance of struct `T` filled with the data field
    pub fn dataAs(self: *const Self, comptime T: type) !T {
        const d = try self.data();
        switch (@typeInfo(T)) {
            .Struct => {
                var ret: T = undefined;
                try utils.fillWithBytes(&ret, d);
                return ret;
            },
            else => @compileError("expected a struct type, found `" ++ @typeName(T) ++ "`"),
        }
    }

    /// `fillWithAlloc` will allocate a new buffer with `alloc` and fill it with
    /// the content of `data_ref`, which should be a pointer to its underlying data.
    ///
    /// Note that the ownership of the buffer is belongs to the `alloc` allocator,
    /// so caller might want to free it after use.
    ///
    /// Will return `error.HasContent` if the `ptr` field is not null and `len` is greater than 0,
    /// which means the buffer is already filled.
    ///
    /// Call might needs to call `deinitWith` to free the buffer.
    pub fn fillWithAlloc(self: *Self, alloc: std.mem.Allocator, data_ref: anytype) !void {
        if (self.data()) |_| {
            return HasContent.HasContent;
        } else |_| {
            // I'm expecting no content here
            const P = @TypeOf(data_ref);
            switch (@typeInfo(P)) {
                .Pointer => {
                    const T = @typeInfo(P).Pointer.child;
                    const size = @sizeOf(T);
                    const buf = try alloc.alloc(u8, size);
                    try utils.fillBytesWith(buf, data_ref);
                    self.ptr = buf.ptr;
                    self.len = size;
                },
                else => @compileError("`data_ref` must be a pointer type, found `" ++ @typeName(P) ++ "`"),
            }
        }
    }

    /// use `data_ref` directly to fill the `data` field
    ///
    /// Note that the caller SHOULD NOT call `deinitWith` with this instance,
    /// since there's no allocation happens here, only reinterpreting the data.
    pub fn fillWith(self: *Self, data_ref: anytype) !void {
        if (self.data()) |_| {
            return HasContent.HasContent;
        } else |_| {
            // I'm expecting no content here
            const P = @TypeOf(data_ref);
            switch (@typeInfo(P)) {
                .Pointer => {
                    const T = @typeInfo(P).Pointer.child;
                    switch (@typeInfo(T)) {
                        .Pointer => @compileError("nested pointer type is not allowed, found `" ++ @typeName(P) ++ "`"),
                        else => {},
                    }
                    const size = @sizeOf(T);
                    const buf = utils.anytype2Slice(data_ref);
                    self.ptr = buf.ptr;
                    self.len = size;
                },
                else => @compileError("`data_ref` must be a pointer type, found `" ++ @typeName(P) ++ "`"),
            }
        }
    }

    /// marshal packs the struct into a byte slice
    ///
    /// Please note that the returned slice is owned by the `alloc` allocator
    pub fn marshal(self: *const Self, alloc: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(alloc);
        defer list.deinit();
        if (self.ptr != null and self.len > 0) {
            try list.ensureTotalCapacity(self.len + Self.fixedPackBase);
        } else {
            try list.ensureTotalCapacity(Self.fixedPackBase);
        }
        var writer = list.writer();
        try writer.writeByte(0xaa);
        if (self.ptr != null and self.len > 0) {
            try writer.writeInt(u32, self.len, std.builtin.Endian.little);
        } else {
            try writer.writeInt(u32, 0, std.builtin.Endian.little);
        }
        try writer.writeInt(u32, self.reqid, std.builtin.Endian.big);
        try writer.writeInt(u32, self.msgid, std.builtin.Endian.big);
        try writer.writeInt(i32, self.sta, std.builtin.Endian.big);
        const xor = xorCheck(list.items);
        try writer.writeByte(xor);
        if (self.data()) |s| {
            _ = try writer.write(s);
        } else |_| {}
        try writer.writeByte(0xbb);
        return list.toOwnedSlice();
    }

    /// unmarshal unpacks the byte slice into a struct.
    ///
    /// note that the `data` field is owned by the `alloc` allocator
    pub fn unmarshal(alloc: std.mem.Allocator, buf: []const u8) !Self {
        if (buf.len < Self.fixedPackBase) {
            return UnmarshalError.LengthTooShort;
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
        var ret: UsbPack = undefined;
        ret.reqid = reqid;
        ret.msgid = msgid;
        ret.sta = sta;
        if (dataLen > 0) {
            const out = try alloc.alloc(u8, dataLen);
            const sz = try reader.read(out);
            ret.ptr = out.ptr;
            ret.len = @intCast(sz);
        } else {
            ret.ptr = null;
            ret.len = 0;
        }
        const end = try reader.readByte();
        if (end != 0xbb) {
            return UnmarshalError.InvalidEndMagic;
        }
        return ret;
    }

    /// free the `data`. Note that the `alloc` should be the same allocator
    /// that was used to allocate the `data`
    pub fn deinitWith(self: *Self, alloc: std.mem.Allocator) void {
        if (self.data()) |s| {
            alloc.free(s);
        } else |_| {}
    }

    pub fn withLogger(pack: *const Self, logger: logz.Logger) logz.Logger {
        var lg = logger
            .int("reqid", pack.reqid)
            .int("msgid", pack.msgid)
            .int("sta", pack.sta);
        if (pack.data()) |d| {
            lg = lg.int("len", d.len)
                .fmt("content", "{s}", .{std.fmt.fmtSliceHexLower(d)});
        } else |_| {}
        return lg;
    }
};

/// See `UsbPack`
pub const ManagedUsbPack = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pack: UsbPack,

    pub inline fn unmarshal(alloc: std.mem.Allocator, buf: []const u8) !ManagedUsbPack {
        const pack = try UsbPack.unmarshal(alloc, buf);
        return ManagedUsbPack{
            .allocator = alloc,
            .pack = pack,
        };
    }

    /// data returns an instance of struct `T` filled with the data field
    pub inline fn dataAs(self: *const Self, comptime T: type) !T {
        return self.pack.dataAs(T);
    }

    pub fn deinit(self: *@This()) void {
        self.pack.deinitWith(self.allocator);
    }
};
