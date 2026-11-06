const std = @import("std");
const h = @import("helpers.zig");
pub const raw = @import("raw.zig");
pub const wrappers = @import("wrappers.zig");
pub const transactions = @import("transactions.zig");
pub const png = @import("png.zig");

/// The same public contracts run on native, x86 and WASI. Large states model
/// lawful repetitive prefixes proved with real small replays. Every suffix and
/// the complete large PNG run wire are physically encoded and checked here;
/// physical replay of >4 GiB of source belongs to the external oracle.
pub fn contracts(comptime D: type) !void {
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, h.Count);
    try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "input_read"));
    try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "output_written"));
    try raw.contracts(D);
    try wrappers.contracts(D);
    try transactions.contracts(D);
    try png.contracts(D);
}
