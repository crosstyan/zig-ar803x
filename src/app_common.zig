const std = @import("std");
const builtin = @import("builtin");
const logz = @import("logz");

pub const AppError = error{
    BadDescriptor,
    BadPortNumbers,
    BadEnum,
    Unknown,
};
pub const BadEnum = error{BadEnum};
pub const LengthNotEqual = error{LengthNotEqual};
pub const ClosedError = error{Closed};
