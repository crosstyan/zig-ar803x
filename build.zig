const std = @import("std");
const builtin = @import("builtin");
const log = std.log;
const bd = std.Build;
const fs = std.fs;

// only useful in Windows
const VCPKG_ROOT_FALLBACK = "C:/vcpkg/";

fn getVcpkgRoot(allocator: std.mem.Allocator) []const u8 {
    var env_map = std.process.getEnvMap(allocator) catch {
        log.warn("Failed to get environment variables, fallback to '{s}'", .{VCPKG_ROOT_FALLBACK});
        return VCPKG_ROOT_FALLBACK;
    };
    defer env_map.deinit();
    const root_ = env_map.get("VCPKG_ROOT");
    if (root_) |r| {
        const ret = allocator.alloc(u8, r.len) catch @panic("OOM");
        @memcpy(ret, r);
        log.info("use environment variable VCPKG_ROOT={s}", .{r});
        return ret;
    }
    log.warn("VCPKG_ROOT not found in environment variables, fallback to '{s}'", .{VCPKG_ROOT_FALLBACK});
    return VCPKG_ROOT_FALLBACK;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const logz_module = b.dependency("logz", .{}).module("logz");
    const exe = b.addExecutable(.{
        .name = "ar8030",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("logz", logz_module);
    if (builtin.os.tag == .windows) {
        // See also
        //
        // C:\tools\vcpkg\packages\libusb_x64-windows\lib\pkgconfig
        //
        // I still don't want to deal with Zig package system bullshit
        // That's ugly but it works, except you MUST reconfigure
        // it for different host (that's the configure stage for, zig just skips it)
        const VCPKG_ROOT = getVcpkgRoot(b.allocator);
        const vcpkg_packages_path = b.pathJoin(&.{ VCPKG_ROOT, "packages/" });
        const libusb_prefix = b.pathJoin(&.{ vcpkg_packages_path, "libusb_x64-windows/" });
        const usb_lib_dir = b.pathJoin(&.{ libusb_prefix, "lib/" });
        // where the `.dll` file is located
        const usb_bin_dir = b.pathJoin(&.{ libusb_prefix, "bin/" });
        const usb_include_dir = b.pathJoin(&.{ libusb_prefix, "include/libusb-1.0" });
        // const usb_pkgconfig_dir = usb_lib_prefix ++ "pkgconfig/";
        exe.addLibraryPath(bd.LazyPath{ .cwd_relative = usb_lib_dir });
        exe.addIncludePath(bd.LazyPath{ .cwd_relative = usb_include_dir });
        exe.linkSystemLibrary("c");
        exe.linkSystemLibrary("libusb-1.0");
        // and you should copy the DLL to the same directory as the executable
        const usb_lib_file_path = b.pathJoin(&.{ usb_bin_dir, "libusb-1.0.dll" });
        const usb_lib_file_lazy_path = bd.LazyPath{ .cwd_relative = usb_lib_file_path };
        // see b.installFile
        b.getInstallStep().dependOn(&b.addInstallFileWithDir(usb_lib_file_lazy_path, .prefix, "bin/libusb-1.0.dll").step);
    } else {
        exe.linkSystemLibrary("c");
        exe.linkSystemLibrary("libusb-1.0");
    }

    // include ar8030 base band driver
    exe.addIncludePath(bd.LazyPath{ .cwd_relative = "inc" });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    _ = b.step("test", "Run unit tests");
}
