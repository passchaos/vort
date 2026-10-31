//! Internal workspace policy. Full mode preserves its original descriptor.
const Source = @import("../controlled_source.zig").Source;
const HqOptions = @import("../../encode/hq_options.zig").HqOptions;
const resources = @import("resources.zig");
const view = @import("view.zig");

pub fn Metadata(comptime sized: bool) type {
    return if (!sized) view.Metadata else struct {
        prefix: usize,
        total: usize,
        short_mask: usize = 0,
        long_mask: usize = 0,
    };
}

pub fn metadata(needed: resources.Requirements, comptime sized: bool) Metadata(sized) {
    return if (!sized) needed.metadata else .{
        .prefix = needed.metadata.prefix,
        .total = needed.metadata.total,
        .short_mask = if (needed.short_heads == 0) 0 else needed.short_heads - 1,
        .long_mask = if (needed.long_heads == 0) 0 else needed.long_heads - 1,
    };
}

pub fn headCount(total: usize, window: usize, comptime sized: bool) usize {
    if (!sized) return 65536;
    const available = @min(@as(usize, 65536), @min(total, window + 1));
    var count: usize = 256;
    while (count < available) count *= 2;
    return count;
}

pub fn requirements(source: Source, options: HqOptions, comptime sized: bool) !resources.Requirements {
    var needed = try resources.requirements(source, options);
    const heads = headCount(needed.metadata.total, source.window_len, sized);
    needed.short_heads = if (needed.metadata.total >= 3) heads else 0;
    needed.long_heads = if (needed.metadata.total >= 4) heads else 0;
    return needed;
}
