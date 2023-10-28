const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = struct {
    left: ?*Node,
    right: ?*Node,
};

fn bottomUpTree(allocator: Allocator, depth: i32) ?*Node {
    if (depth < 0) {
        return null;
    }
    var node = allocator.create(Node) catch unreachable;
    node.* = .{
        .left = bottomUpTree(allocator, depth - 1),
        .right = bottomUpTree(allocator, depth - 1),
    };
    return node;
}

fn deinit(allocator: Allocator, node: *Node) void {
    if (node.left) |left| {
        deinit(allocator, left);
    }
    if (node.right) |right| {
        deinit(allocator, right);
    }
    allocator.destroy(node);
}

fn itemCheck(node: *Node) i32 {
    var result: i32 = 1;
    if (node.left) |left| {
        result += itemCheck(left);
    }
    if (node.right) |right| {
        result += itemCheck(right);
    }
    return result;
}

pub fn main() !void {
    const n = blk: {
        if (std.os.argv.len < 2) {
            break :blk 10;
        }
        break :blk std.fmt.parseInt(i32, std.os.argv[1][0..std.mem.len(std.os.argv[1])], 10) catch 10;
    };
    const min_depth = 4;
    const max_depth = if (min_depth + 2 > n) min_depth + 2 else n;
    const stretch_depth = max_depth + 1;

    const allocator = std.heap.c_allocator;

    {
        var tree = bottomUpTree(allocator, stretch_depth).?;
        std.debug.print("stretch tree of depth {}\t check: {}\n", .{ stretch_depth, itemCheck(tree) });
        deinit(allocator, tree);
    }

    var long_lived_tree = bottomUpTree(allocator, max_depth).?;
    defer deinit(allocator, long_lived_tree);

    var depth: i32 = min_depth;
    while (depth <= max_depth) : (depth += 2) {
        const iterations = @as(usize, 1) << @as(u6, @intCast((max_depth - depth + min_depth)));
        var check: i32 = 0;

        for (0..iterations) |_| {
            var tree = bottomUpTree(allocator, depth).?;
            check += itemCheck(tree);
            deinit(allocator, tree);
        }
        std.debug.print("{}\t trees of depth {}\t check: {}\n", .{ iterations, depth, check });
    }

    std.debug.print("long lived tree of depth {}\t check: {}\n", .{ max_depth, itemCheck(long_lived_tree) });
}
