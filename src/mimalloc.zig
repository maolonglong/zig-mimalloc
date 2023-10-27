const std = @import("std");
const testing = std.testing;
const heap = std.heap;
const c = @cImport(@cInclude("mimalloc.h"));
const Allocator = std.mem.Allocator;

pub const allocator = Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = alloc,
        .resize = resize,
        .free = free,
    },
};

fn alloc(ctx: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
    _ = ctx;
    _ = ret_addr;

    return @as(?[*]u8, @ptrCast(c.mi_malloc_aligned(len, @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align)))));
}

fn resize(ctx: *anyopaque, buf: []u8, log2_old_align: u8, new_len: usize, ret_addr: usize) bool {
    _ = ctx;
    _ = log2_old_align;
    _ = ret_addr;

    return new_len <= c.mi_usable_size(buf.ptr);
}

fn free(ctx: *anyopaque, buf: []u8, log2_old_align: u8, ret_addr: usize) void {
    _ = ctx;
    _ = ret_addr;

    c.mi_free_size_aligned(buf.ptr, buf.len, @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_old_align)));
}

test "mimalloc" {
    try heap.testAllocator(allocator);
    try heap.testAllocatorAligned(allocator);
    try heap.testAllocatorLargeAlignment(allocator);
    try heap.testAllocatorAlignedShrink(allocator);
}
