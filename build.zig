const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_secure_mode = b.option(bool, "secure", "Use full security mitigations (like guard pages, allocation randomization, double-free mitigation, and free-list corruption detection)") orelse false;
    const enable_valgrind = b.option(bool, "valgrind", "Compile with Valgrind support (adds a small overhead)") orelse false;

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
    if (enable_secure_mode) {
        lib.defineCMacro("MI_SECURE", "4");
    }
    if (enable_valgrind) {
        lib.defineCMacro("MI_TRACK_VALGRIND", "1");
    }
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
        .{ .name = "binary_trees_arena", .src = "examples/binary_trees_arena.zig" },
        .{ .name = "binary_trees_c", .src = "examples/binary_trees_c.zig" },
        .{ .name = "binary_trees_gpa", .src = "examples/binary_trees_gpa.zig" },
        .{ .name = "binary_trees_mimalloc", .src = "examples/binary_trees_mimalloc.zig" },
        .{ .name = "test_wrong", .src = "examples/test_wrong.zig" },
    }) |config| {
        const step_name = std.fmt.allocPrint(b.allocator, "run-{s}", .{config.name}) catch unreachable;
        const step_desc = std.fmt.allocPrint(b.allocator, "Run the {s} example", .{config.name}) catch unreachable;

        const example = b.addExecutable(.{
            .name = config.name,
            .root_source_file = .{ .path = config.src },
            .target = target,
            .optimize = optimize,
        });

        example.linkLibrary(lib);
        example.addModule("mimalloc", mimalloc_mod);

        const run_cmd = b.addRunArtifact(example);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(step_name, step_desc);
        run_step.dependOn(&run_cmd.step);

        b.allocator.free(step_name);
        b.allocator.free(step_desc);
    }
}
