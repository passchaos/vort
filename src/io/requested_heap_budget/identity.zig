const std = @import("std");
const builtin = @import("builtin");

pub fn equal(left: std.mem.Allocator, right: std.mem.Allocator) bool {
    if (left.vtable != right.vtable) return false;
    if (!builtin.cpu.arch.isWasm()) {
        if (left.vtable == &std.heap.PageAllocator.vtable) return true;
    }
    if (!builtin.single_threaded) {
        if (left.vtable == &std.heap.SmpAllocator.vtable) return true;
    }
    if (builtin.single_threaded and (builtin.cpu.arch.isWasm() or builtin.os.tag == .linux)) {
        if (left.vtable == std.heap.brk_allocator.vtable) return true;
    }
    if (builtin.link_libc and left.vtable == std.heap.c_allocator.vtable) return true;
    // Stateful allocators have initialized contexts. A custom stateless
    // allocator needs a defined sentinel context for ownership comparisons.
    return left.ptr == right.ptr;
}
