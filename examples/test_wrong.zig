const std = @import("std");
const mimalloc = @import("mimalloc");
const allocator = mimalloc.default_allocator;

pub fn main() !void {
    var p = try allocator.alloc(i32, 3);
    _ = p;

    var r = try allocator.alignedAlloc(u8, 16, 8);
    allocator.free(r);

    // undefined access
    var q = try allocator.create(i32);
    std.debug.print("undefined: {}\n", .{q.*});

    q.* = 42;

    allocator.destroy(q);

    // double free
    allocator.destroy(q);

    // use after free
    std.debug.print("use-after-free: {}\n", .{q.*});

    // leak p
    // allocator.free(p);
}
