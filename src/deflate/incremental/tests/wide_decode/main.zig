const std = @import("std");
const h = @import("helpers.zig");
pub const raw = @import("raw.zig");
pub const wrappers = @import("wrappers.zig");
pub const transactions = @import("transactions.zig");

/// Public decoder contracts run unchanged on native, 32-bit x86, and WASI.
/// The large fixtures summarize a verified lawful prefix, then physically
/// decode every byte of the suffix; whole >4 GiB replay belongs to the oracle.
pub fn contracts(comptime D: type) !void {
    try std.testing.expectEqual(if (@bitSizeOf(usize) < 64) u64 else usize, h.Count);
    try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "input_read"));
    try std.testing.expectEqual(usize, @FieldType(h.core.Progress, "output_written"));
    try std.testing.expectEqual(?h.Count, @FieldType(h.core.StreamingDiagnostics, "frame_input_read"));
    try std.testing.expectEqual(?h.Count, @FieldType(h.core.StreamingDiagnostics, "expected_output_len"));
    try raw.contracts(D);
    try wrappers.contracts(D);
    try transactions.contracts(D);
}
