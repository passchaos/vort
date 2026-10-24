//! Allocator for legacy Brotli entrypoints without an allocator parameter.
//! Single-threaded targets use the standard target-aware portable singleton;
//! normal native builds keep the established SMP allocator and ownership.
const std = @import("std");
const builtin = @import("builtin");

pub const singleton = if (builtin.single_threaded)
    std.heap.page_allocator
else
    std.heap.smp_allocator;
