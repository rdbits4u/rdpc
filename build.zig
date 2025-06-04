const std = @import("std");

pub fn build(b: *std.Build) void
{
    // build options
    const do_strip = b.option(
        bool,
        "strip",
        "Strip the executabes"
    ) orelse false;
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    // librdpc
    const librdpc = b.addSharedLibrary(.{
        .name = "rdpc",
        .root_source_file = b.path("src/librdpc.zig"),
        .target = target,
        .optimize = optimize,
        .strip = do_strip,
    });
    librdpc.linkLibC();
    librdpc.addIncludePath(b.path("../common"));
    librdpc.addIncludePath(b.path("include"));
    librdpc.root_module.addImport("parse", b.createModule(.{
        .root_source_file = b.path("../common/parse.zig"),
    }));
    librdpc.root_module.addImport("hexdump", b.createModule(.{
        .root_source_file = b.path("../common/hexdump.zig"),
    }));
    librdpc.root_module.addImport("strings", b.createModule(.{
        .root_source_file = b.path("../common/strings.zig"),
    }));
    b.installArtifact(librdpc);
}
