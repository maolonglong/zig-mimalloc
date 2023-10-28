const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mimalloc_mod = b.addModule("mimalloc", .{
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

    inline for ([_]struct {
        name: []const u8,
        src: []const u8,
    }{
        .{ .name = "binary_trees_arena", .src = "benchs/binary_trees_arena.zig" },
        .{ .name = "binary_trees_c", .src = "benchs/binary_trees_c.zig" },
        .{ .name = "binary_trees_gpa", .src = "benchs/binary_trees_gpa.zig" },
        .{ .name = "binary_trees_mimalloc", .src = "benchs/binary_trees_mimalloc.zig" },
    }) |config| {
        const step_name = std.fmt.allocPrint(b.allocator, "run-{s}", .{config.name}) catch unreachable;
        const step_desc = std.fmt.allocPrint(b.allocator, "Run the {s} bench", .{config.name}) catch unreachable;

        const bench = b.addExecutable(.{
            .name = config.name,
            .root_source_file = .{ .path = config.src },
            .target = target,
            .optimize = optimize,
        });

        bench.linkLibrary(lib);
        bench.addModule("mimalloc", mimalloc_mod);

        const run_cmd = b.addRunArtifact(bench);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(step_name, step_desc);
        run_step.dependOn(&run_cmd.step);
    }
}
