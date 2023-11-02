const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

pub const raw = @cImport(@cInclude("mimalloc.h"));

pub const default_allocator = Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};

fn alloc(
    ctx: *anyopaque,
    len: usize,
    log2_ptr_align: u8,
    ret_addr: usize,
) ?[*]u8 {
    _ = ctx;
    _ = ret_addr;

    const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
    return @as(?[*]u8, @ptrCast(raw.mi_malloc_aligned(len, ptr_align)));
}

fn resize(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    new_len: usize,
    ret_addr: usize,
) bool {
    _ = ctx;
    _ = log2_buf_align;
    _ = ret_addr;

    const len = raw.mi_usable_size(buf.ptr);

    // Reallocation still fits, is aligned and not more than 50% waste.
    return new_len <= len and new_len >= (len - (len / 2));
}

fn free(
    ctx: *anyopaque,
    buf: []u8,
    log2_buf_align: u8,
    ret_addr: usize,
) void {
    _ = ctx;
    _ = ret_addr;

    const buf_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_buf_align));
    raw.mi_free_size_aligned(buf.ptr, buf.len, buf_align);
}

pub const Heap = struct {
    const Self = @This();

    inner: *raw.mi_heap_t,

    pub fn new() !Self {
        return .{
            .inner = raw.mi_heap_new() orelse return error.OutOfMemory,
        };
    }

    pub fn default() !Self {
        return .{
            .inner = raw.mi_heap_get_default() orelse return error.OutOfMemory,
        };
    }

    pub fn setDefault(self: *Self) ?Heap {
        const prev = raw.mi_heap_set_default(self.inner) orelse return null;
        return .{
            .inner = prev,
        };
    }

    pub fn backing() !Heap {
        return .{
            .inner = raw.mi_heap_get_backing() orelse return error.OutOfMemory,
        };
    }

    pub fn delete(self: *Self) void {
        raw.mi_heap_delete(self.inner);
        self.* = undefined;
    }

    pub fn destroy(self: *Self) void {
        raw.mi_heap_destroy(self.inner);
        self.* = undefined;
    }

    pub fn collect(self: *Self, force: bool) void {
        raw.mi_heap_collect(self.inner, force);
    }

    pub fn checkOwned(self: *Self, p: ?*anyopaque) bool {
        return raw.mi_heap_check_owned(self.inner, p);
    }

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = heapAlloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn heapAlloc(
        ctx: *anyopaque,
        len: usize,
        log2_ptr_align: u8,
        ret_addr: usize,
    ) ?[*]u8 {
        _ = ret_addr;

        const self: *Self = @ptrCast(@alignCast(ctx));

        const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
        return @as(?[*]u8, @ptrCast(raw.mi_heap_malloc_aligned(self.inner, len, ptr_align)));
    }
};

test "default_allocator" {
    try std.heap.testAllocator(default_allocator);
    try std.heap.testAllocatorAligned(default_allocator);
    try std.heap.testAllocatorLargeAlignment(default_allocator);
    try std.heap.testAllocatorAlignedShrink(default_allocator);
}

test "heap allocator" {
    var heap = try Heap.new();
    defer heap.destroy();
    const allocator = heap.allocator();

    try std.heap.testAllocator(allocator);
    try std.heap.testAllocatorAligned(allocator);
    try std.heap.testAllocatorLargeAlignment(allocator);
    try std.heap.testAllocatorAlignedShrink(allocator);
}

test "delete" {
    var heap = try Heap.new();
    var backing = try Heap.backing();

    var slice = try heap.allocator().alloc(u8, 1);

    try testing.expect(heap.checkOwned(slice.ptr));
    try testing.expect(!backing.checkOwned(slice.ptr));

    heap.delete();
    try testing.expect(backing.checkOwned(slice.ptr));
    backing.allocator().free(slice);
}

test "default" {
    var default = try Heap.default();
    var backing = try Heap.backing();
    try testing.expectEqual(@intFromPtr(backing.inner), @intFromPtr(default.inner));

    var heap = try Heap.new();
    defer heap.destroy();
    var prev = heap.setDefault().?;
    try testing.expectEqual(@intFromPtr(backing.inner), @intFromPtr(prev.inner));
    var default2 = try Heap.default();
    try testing.expectEqual(@intFromPtr(heap.inner), @intFromPtr(default2.inner));
    try testing.expect(@intFromPtr(backing.inner) != @intFromPtr(default2.inner));

    var heap2 = try Heap.new();
    defer heap2.destroy();
    var prev2 = heap2.setDefault().?;
    try testing.expectEqual(@intFromPtr(heap.inner), @intFromPtr(prev2.inner));
}
