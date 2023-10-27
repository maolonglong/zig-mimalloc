const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("mimalloc", .{
        .source_file = .{ .path = "src/mimalloc.zig" },
    });

    const lib = b.addStaticLibrary(.{
        .name = "mimalloc",
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    lib.addIncludePath(.{ .path = "c_src/mimalloc/include" });
    lib.addCSourceFile(.{ .file = .{ .path = "c_src/mimalloc/src/static.c" }, .flags = &.{} });
    lib.installHeader("c_src/mimalloc/include/mimalloc.h", "mimalloc.h");
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/mimalloc.zig" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.linkLibrary(lib);
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const kcov = b.addSystemCommand(&.{ "kcov", "--clean", "--include-pattern=src/", "--exclude-pattern=c_src/", "kcov-output" });
    kcov.addArtifactArg(main_tests);
    const kcov_step = b.step("kcov", "Generate code coverage report");
    kcov_step.dependOn(&kcov.step);
}
