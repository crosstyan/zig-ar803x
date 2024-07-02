const std = @import("std");

pub const BadEnum = error{BadEnum};
pub const LengthNotEqual = error{LengthNotEqual};

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
        .Pointer => {
            const is_const = @typeInfo(P).Pointer.is_const;
            if (is_const) {
                @compileError("`dst` must be a mutable pointer type, found `" ++ @typeName(P) ++ "`");
            }
            const sdst: []u8 = @constCast(anytype2Slice(dst));
            if (sdst.len != src.len) {
                return LengthNotEqual.LengthNotEqual;
            }
            @memcpy(sdst, src);
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
