const std = @import("std");
const observer = @import("observer.zig");

pub fn contracts(comptime D: type) !void {
    var stats: observer.Stats = .{};
    try @import("api.zig").contracts(D, &stats);
    try @import("dictionaries.zig").contracts(D, &stats);
    try @import("resources.zig").contracts(D, &stats);
    try std.testing.expect(stats.disabled_compressed_blocks != 0);
    try std.testing.expect(stats.disabled_lz77_copies != 0);
    try std.testing.expect(stats.disabled_max_literal_types > 1 or stats.max_distance_trees > 1 or stats.distance_parameter_frames != 0);
    std.debug.print("Brotli literal context contract audit: frames={d} disabled_frames={d} compressed_frames={d} compressed_blocks={d} disabled_compressed_blocks={d} literal_types={d} max_literal_types={d} disabled_max_literal_types={d} nonconstant_default_types={d} max_distance_types={d} max_distance_trees={d} distance_parameter_headers={d} lz77_copies={d} disabled_lz77_copies={d} dictionary_copies={d} decoded_bytes={d}\n", .{
        stats.frames,                     stats.disabled_frames,      stats.compressed_frames,  stats.compressed_blocks,
        stats.disabled_compressed_blocks, stats.literal_types,        stats.max_literal_types,  stats.disabled_max_literal_types,
        stats.nonconstant_literal_types,  stats.max_distance_types,   stats.max_distance_trees, stats.distance_parameter_frames,
        stats.lz77_copies,                stats.disabled_lz77_copies, stats.dictionary_copies,  stats.bytes,
    });
}
