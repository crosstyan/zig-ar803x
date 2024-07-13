const std = @import("std");
const logz = @import("logz");

pub const BadEnum = error{BadEnum};
pub const LengthNotEqual = error{LengthNotEqual};

/// generate a unique number for a type `T`
///
/// See https://zig.news/xq/cool-zig-patterns-type-identifier-3mfd
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
