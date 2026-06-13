const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.option(std.builtin.OptimizeMode, "mode", "") orelse .Debug;

    const exe_mod = b.createModule(.{ .root_source_file = b.path("src/main.zig"), .target = target, .optimize = mode });

    if (mode != .Debug) {
        exe_mod.stack_protector = true;
    }
    exe_mod.stack_check = true;

    const vaxis_dep = b.dependency("vaxis", .{ .target = target, .optimize = mode });
    exe_mod.addImport("vaxis", vaxis_dep.module("vaxis"));

    const exe = b.addExecutable(.{
        .name = "zigtop",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);
}
