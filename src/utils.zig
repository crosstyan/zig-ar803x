const std = @import("std");
const logz = @import("logz");
const common = @import("app_common.zig");
const Mutex = std.Thread.Mutex;
const RwLock = std.Thread.RwLock;

pub const BadEnum = common.BadEnum;
pub const LengthNotEqual = common.LengthNotEqual;
pub const ClosedError = common.ClosedError;

/// generate a unique number for a type `T`
///
/// See also
///
///   - https://zig.news/xq/cool-zig-patterns-type-identifier-3mfd
///   - https://github.com/ziglang/zig/issues/19858
///   - https://github.com/ziglang/zig/issues/5459
pub fn typeId(comptime T: type) usize {
    // https://ziglang.org/documentation/0.13.0/#Static-Local-Variables
    // https://www.reddit.com/r/Zig/comments/ard50a/static_local_variables_in_zig/
    // basically we create a anonymous struct for each type T,
    // and get the address of a field in the struct.
    // so that we can get a unique number for each type.
    const H = struct {
        const byte: u8 = undefined;
        const _ = T;
    };
    return @intFromPtr(&H.byte);
}

pub fn PointeeType(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => |info| return info.child,
        .Optional => |info| return info.child,
        else => @compileError("T is expected to be a pointer, found `" ++ @typeName(T) ++ "`"),
    }
}

/// get the type of the `param_idx`-th parameter of a function-like type (function, optional/pointer to a function)
pub fn FnParamType(comptime function_like: type, comptime param_idx: comptime_int) type {
    switch (@typeInfo(function_like)) {
        .Fn => |info| {
            if (param_idx < 0) {
                @compileError("param_idx must be non-negative, found `" ++ param_idx ++ "`");
            }
            if (param_idx > info.params.len) {
                @compileError("param_idx is out of range, function `" ++ @typeName(function_like) ++ "` has " ++
                    info.params.len ++ " parameters, but got `" ++ param_idx ++ "` as index");
            }
            const param = info.params[param_idx];
            return param.type.?;
        },
        .Optional => |info| {
            return FnParamType(info.child);
        },
        .Pointer => |info| {
            return FnParamType(info.child);
        },
        else => @compileError("cbParamType: expected a function like (pointer/optional to a function, or a function), found `" ++
            @typeName(function_like) ++ "` in the end of reference chain"),
    }
}

/// cast a reference of type `T` to a slice of bytes (`u8`)
///
///   - `src`: a reference of type `T`
///
/// returns a slice of bytes, whose length is equal to the size of `T`
pub fn anytype2Slice(src: anytype) []const u8 {
    const P = @TypeOf(src);
    switch (@typeInfo(P)) {
        .Pointer => {
            const T = @typeInfo(P).Pointer.child;
            switch (@typeInfo(T)) {
                // prevent nested pointer type, usually it's not meaningful and error-prone
                .Pointer => @compileError("nested pointer type is not allowed, found `" ++ @typeName(P) ++ "`"),
                else => {},
            }
            const size = @sizeOf(T);
            const ptr: [*]const u8 = @ptrCast(src);
            return ptr[0..size];
        },
        else => @compileError("`src` must be a pointer type, found `" ++ @typeName(P) ++ "`"),
    }
}

/// fill a reference of type `T` as `dst` with with content of `src`
///
/// Note that the length of `src` slice must be equal to the size of `T`,
/// otherwise, it will return `LengthNotEqual`
///
///   - `dst`: a *mutable* reference of type `T`
///   - `src`: a slice of bytes, whose length must be equal to the size of `T`
pub fn fillWithBytes(dst: anytype, src: []const u8) LengthNotEqual!void {
    const P = @TypeOf(dst);
    switch (@typeInfo(P)) {
        .Pointer => |info| {
            if (info.is_const) {
                @compileError("`dst` must be a mutable pointer type, found `" ++ @typeName(P) ++ "`");
            }
            const s_dst: []u8 = @constCast(anytype2Slice(dst));
            if (s_dst.len != src.len) {
                return LengthNotEqual.LengthNotEqual;
            }
            @memcpy(s_dst, src);
        },
        else => @compileError("`dst` must be a pointer type, found `" ++ @typeName(P) ++ "`"),
    }
}

/// fill a slice of bytes (`u8`) with a reference of type `T` as `src`
///
/// Note that the length of `dst` must be equal to the size of `T`,
/// otherwise, it will return `LengthNotEqual`
///
///   - `dst`: a slice of bytes, whose length must be equal to the size of `T`
///   - `src`: a reference of type `T`
pub fn fillBytesWith(dst: []u8, src: anytype) LengthNotEqual!void {
    const P = @TypeOf(src);
    switch (@typeInfo(P)) {
        .Pointer => {
            const s = anytype2Slice(src);
            if (dst.len != s.len) {
                return LengthNotEqual.LengthNotEqual;
            }
            @memcpy(dst, s);
        },
        else => @compileError("`src` must be a pointer type, get `" ++ @typeName(P) ++ "`"),
    }
}

// https://github.com/ziglang/zig/blob/b3afba8a70af984423fc24e5b834df966693b50a/lib/std/builtin.zig#L243-L250
pub inline fn logWithSrc(logger: logz.Logger, src: std.builtin.SourceLocation) logz.Logger {
    return logger
        .fmt("src", "{s}:{d} @{s}", .{ src.file, src.line, src.fn_name });
}

pub fn LockedQueue(comptime T: type, comptime max_size: usize) type {
    // TODO: https://zig.news/kprotty/simple-scalable-unbounded-queue-34c2
    // https://www.reddit.com/r/Zig/comments/oekuxh/question_does_zig_has_workstealingsharing
    // https://github.com/ziglang/zig/issues/8224
    // https://github.com/magurotuna/zig-deque
    // I don't feel like going down the rabbit hole of data structures
    const LockedQueueImpl = struct {
        const MAX_SIZE = max_size;
        const Self = @This();

        /// should be false until `deinit` is called
        _has_deinit: std.atomic.Value(bool),
        /// WARNING: don't use it directly
        _list: std.ArrayList(T),
        /// used when modifying the `_list`
        lock: RwLock = RwLock{},

        /// used with `cv` to signal the `dequeue`, different from `lock`
        mutex: Mutex = Mutex{},
        cv: std.Thread.Condition = std.Thread.Condition{},
        /// function to call when removing an element.
        /// Only useful when the queue is full, and needs to discard old
        /// elements.
        elem_dtor: ?*const fn (*T) void = null,

        pub fn init(alloc: std.mem.Allocator) Self {
            var l = std.ArrayList(T).init(alloc);
            l.ensureTotalCapacity(max_size) catch @panic("OOM");
            return Self{
                ._list = l,
                ._has_deinit = std.atomic.Value(bool).init(false),
            };
        }

        pub fn hasDeinit(self: *const @This()) bool {
            return self._has_deinit.load(std.builtin.AtomicOrder.unordered);
        }

        pub fn deinit(self: *@This()) void {
            self._has_deinit.store(true, std.builtin.AtomicOrder.unordered);
            self.cv.broadcast();
            self._list.deinit();
        }

        pub fn enqueue(self: *@This(), pkt: T) ClosedError!void {
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            {
                self.lock.lockShared();
                defer self.lock.unlockShared();
                while (self.lenNoCheck() >= MAX_SIZE) {
                    logWithSrc(logz.warn(), @src())
                        .string("what", "full queue, discarding old element").log();
                    var elem = self._list.orderedRemove(0);
                    if (self.elem_dtor) |dtor| {
                        dtor(&elem);
                    }
                }
                self._list.append(pkt) catch @panic("OOM");
            }
            self.cv.signal();
        }

        inline fn lenNoCheck(self: *const @This()) usize {
            return self._list.items.len;
        }

        inline fn isEmptyNoCheck(self: *const @This()) bool {
            return self.lenNoCheck() == 0;
        }

        /// return the length of the queue
        pub inline fn len(self: *@This()) ClosedError!usize {
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            self.lock.lock();
            defer self.lock.unlock();
            return self.lenNoCheck();
        }

        /// return whether the queue is empty
        pub inline fn isEmpty(self: *@This()) ClosedError!bool {
            return try self.len() == 0;
        }

        pub fn peek(self: *@This()) ClosedError!?T {
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            self.lock.lock();
            defer self.lock.unlock();
            if (self._list.len == 0) {
                return null;
            } else {
                const ret = self._list.items[0];
                return ret;
            }
        }

        /// note that this function will block indefinitely
        /// until the queue is not empty
        pub fn dequeue(self: *@This()) ClosedError!T {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            while (self.isEmptyNoCheck()) {
                if (self.hasDeinit()) {
                    return ClosedError.Closed;
                }
                self.cv.wait(&self.mutex);
            }
            if (self.hasDeinit()) {
                return ClosedError.Closed;
            }
            self.lock.lockShared();
            defer self.lock.unlockShared();
            const ret = self._list.items[0];
            _ = self._list.orderedRemove(0);
            return ret;
        }
    };
    return LockedQueueImpl;
}

pub fn u8ToArray(u: u8, comptime msb_first: bool) [8]bool {
    var ret: [8]bool = undefined;
    if (msb_first) {
        ret[0] = (u & 0x80) != 0x00;
        ret[1] = (u & 0x40) != 0x00;
        ret[2] = (u & 0x20) != 0x00;
        ret[3] = (u & 0x10) != 0x00;
        ret[4] = (u & 0x08) != 0x00;
        ret[5] = (u & 0x04) != 0x00;
        ret[6] = (u & 0x02) != 0x00;
        ret[7] = (u & 0x01) != 0x00;
    } else {
        ret[0] = (u & 0x01) != 0x00;
        ret[1] = (u & 0x02) != 0x00;
        ret[2] = (u & 0x04) != 0x00;
        ret[3] = (u & 0x08) != 0x00;
        ret[4] = (u & 0x10) != 0x00;
        ret[5] = (u & 0x20) != 0x00;
        ret[6] = (u & 0x40) != 0x00;
        ret[7] = (u & 0x80) != 0x00;
    }
    return ret;
}

const expect = std.testing.expect;
test "typeId" {
    const T = struct {
        const a: u8 = 42;
        const b: u16 = 42;
    };
    try expect(typeId(T) == typeId(T));
    try expect(typeId(T) != typeId(*T));
    try expect(typeId(*T) == typeId(*T));
    try expect(typeId(u32) == typeId(u32));
    try expect(typeId(u32) != typeId(u31));
    try expect(typeId(std.ArrayList(u32)) == typeId(std.ArrayList(u32)));
    try expect(typeId(std.ArrayList(u31)) != typeId(std.ArrayList(u32)));
}
