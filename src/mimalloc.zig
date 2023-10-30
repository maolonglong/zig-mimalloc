const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const log = std.log.scoped(.mimalloc);
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

/// Emits log messages for leaks and then returns whether there were any leaks.
pub fn detectLeaks(heap: ?*const raw.mi_heap_t) bool {
    const Closure = struct {
        leaks: bool = false,

        fn visitor(
            _: ?*const raw.mi_heap_t,
            _: [*c]const raw.mi_heap_area_t,
            block: ?*anyopaque,
            _: usize,
            ctx: ?*anyopaque,
        ) callconv(.C) bool {
            const self: *@This() = @ptrCast(@alignCast(ctx.?));
            if (block) |ptr| {
                if (!builtin.is_test) {
                    // TODO: stack trace
                    log.err("memory address 0x{x} leaked", .{@intFromPtr(ptr)});
                }
                self.leaks = true;
            }
            return true;
        }
    };

    var closure = Closure{};
    _ = raw.mi_heap_visit_blocks(heap, true, Closure.visitor, &closure);
    return closure.leaks;
}

test "mimalloc" {
    try std.heap.testAllocator(default_allocator);
    try std.heap.testAllocatorAligned(default_allocator);
    try std.heap.testAllocatorLargeAlignment(default_allocator);
    try std.heap.testAllocatorAlignedShrink(default_allocator);
}

test "detectLeaks" {
    const memory = try default_allocator.alloc(u8, 1);
    try testing.expect(detectLeaks(raw.mi_heap_get_default()));
    default_allocator.free(memory);
    try testing.expect(!detectLeaks(raw.mi_heap_get_default()));
}
