const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");

pub const AppError = error{
    BadDescriptor,
    BadPortNumbers,
    BadEnum,
    BadSize,
    Overflow,
    HasInit,
    Empty,
    Unknown,
};
pub const BadEnum = error{BadEnum};
pub const LengthNotEqual = error{LengthNotEqual};
pub const ClosedError = error{Closed};
pub const ContentError = error{
    NoContent,
    HasContent,
};
