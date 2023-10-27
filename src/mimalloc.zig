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

fn alloc(
    ctx: *anyopaque,
    len: usize,
    log2_ptr_align: u8,
    ret_addr: usize,
) ?[*]u8 {
    _ = ctx;
    _ = ret_addr;

    const ptr_align = @as(usize, 1) << @as(Allocator.Log2Align, @intCast(log2_ptr_align));
    return @as(?[*]u8, @ptrCast(c.mi_malloc_aligned(len, ptr_align)));
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

    const len = c.mi_usable_size(buf.ptr);

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
    c.mi_free_size_aligned(buf.ptr, buf.len, buf_align);
}

test "mimalloc" {
    try heap.testAllocator(allocator);
    try heap.testAllocatorAligned(allocator);
    try heap.testAllocatorLargeAlignment(allocator);
    try heap.testAllocatorAlignedShrink(allocator);
}
