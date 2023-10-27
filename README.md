# zig-mimalloc

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/maolonglong/zig-mimalloc/zig.yml?label=ci)](https://github.com/maolonglong/zig-mimalloc/actions/workflows/zig.yml)
[![Codecov](https://img.shields.io/codecov/c/github/maolonglong/zig-mimalloc/main?logo=codecov)](https://codecov.io/gh/maolonglong/zig-mimalloc)

Zig bindings for mimalloc.

## Installing

Add zig-mimalloc to `build.zig.zon`:

```zig
.{
    .name = "hello",
    .version = "0.1.0",
    .dependencies = .{
        .mimalloc = .{
            .url = "https://github.com/maolonglong/zig-mimalloc/archive/refs/tags/v2.1.2.tar.gz",
            .hash = "1220f0ad7831489d010b950003d1f5fd78d5588969a9e7478ce95f0be70cc02b5aa6",
        },
    },
}
```

Then, edit `build.zig`:

```zig
    const mimalloc = b.dependency("mimalloc", .{
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(mimalloc.artifact("mimalloc"));
    exe.addModule("mimalloc", mimalloc.module("mimalloc"));
```

## Usage

```zig
const std = @import("std");
const mimalloc = @import("mimalloc");

pub fn main() !void {
    var a = std.ArrayList(usize).init(mimalloc.allocator);
    defer a.deinit();

    for (0..100) |i| {
        try a.append(i);
    }

    std.debug.print("len: {}\n", .{a.items.len});
}
```
