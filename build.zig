const std = @import("std");

pub fn build(b: *std.Build) void
{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // librdpc
    const librdpc = b.addSharedLibrary(.{
        .name = "rdpc",
        .root_source_file = b.path("src/librdpc.zig"),
        .target = target,
        .optimize = optimize,
        .strip = true,
    });
    librdpc.linkLibC();
    librdpc.addIncludePath(b.path("../common"));
    librdpc.addIncludePath(b.path("include"));
    librdpc.root_module.addImport("parse", b.createModule(.{
        .root_source_file = b.path("../common/parse.zig"),
    }));
    b.installArtifact(librdpc);
}
