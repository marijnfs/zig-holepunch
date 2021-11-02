const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const server = b.addExecutable("zig-holepunch-server", "src/server.zig");
    server.setTarget(target);
    server.setBuildMode(mode);
    server.install();

    const exe_client = b.addExecutable("zig-holepunch", "src/client.zig");
    exe_client.setTarget(target);
    exe_client.setBuildMode(mode);
    exe_client.install();

    const exe_tests = b.addTest("src/server.zig");
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
