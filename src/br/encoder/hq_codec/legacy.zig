//! A compatibility candidate is eligible only when every physical meta-block
//! honors the HQ distance shape and block ceiling. Decode authority supplies
//! its published command/copy statistics.
const std = @import("std");
const options_mod = @import("../hq_options.zig");
const initial_recent = @import("../hq_types.zig").initial_recent;

pub fn inspect(comptime Codec: type, allocator: std.mem.Allocator, encoded: []const u8, options: Codec.Options, resolved: options_mod.Resolved, expected_len: usize) Codec.Error!?options_mod.HqProfile.Emitted {
    var reader = Codec.Reader.init(encoded);
    const window = try Codec.readWindow(&reader, options);
    if (window.large != (resolved.format == .large_window) or window.bits != options.window_bits) return null;
    var shared = try Codec.dictionary(options);
    const dictionary = if (shared) |*value| value else null;
    const history_len = @min(expected_len, (@as(usize, 1) << window.bits) - 16);
    const external = if (history_len > Codec.history_capacity) try allocator.alloc(u8, history_len) else null;
    defer if (external) |storage| allocator.free(storage);
    var history: Codec.History = .{ .external = external };
    var recent = initial_recent;
    var decoded_len: usize = 0;
    var emitted: options_mod.HqProfile.Emitted = .{};
    while (true) {
        switch (try Codec.readMetaBlock(&reader)) {
            .end => {
                try Codec.checkEnd(reader);
                if (decoded_len != expected_len) return error.SizeMismatch;
                return emitted;
            },
            .metadata => try Codec.skipMetadata(&reader),
            .uncompressed => |length| {
                if (length > resolved.block_len) return null;
                try Codec.consumePadding(&reader);
                if (reader.byte_index > encoded.len or length > encoded.len - reader.byte_index) return error.TruncatedFrame;
                Codec.pushHistory(&history, encoded[reader.byte_index..][0..length]);
                reader.byte_index += length;
                decoded_len = std.math.add(usize, decoded_len, length) catch return error.IntegerOverflow;
                emitted.emitted_metablocks +|= 1;
            },
            .compressed => |meta| {
                if (meta.decoded_len > resolved.block_len) return null;
                var stats: Codec.Stats = .{};
                try Codec.skipCompressed(&reader, decoded_len, meta.decoded_len, &recent, &history, &stats, window, dictionary);
                if (stats.max_distance_postfix_bits != resolved.distance_parameters.npostfix or stats.max_direct_distance_codes != resolved.distance_parameters.ndirect()) return null;
                decoded_len = std.math.add(usize, decoded_len, meta.decoded_len) catch return error.IntegerOverflow;
                emitted.emitted_metablocks +|= 1;
                emitted.emitted_commands +|= @intCast(stats.command_count);
                emitted.emitted_copy_bytes +|= @intCast(stats.lz77_copy_bytes);
                emitted.emitted_copy_bytes +|= @intCast(stats.static_dictionary_bytes);
                emitted.emitted_copy_bytes +|= @intCast(stats.shared_dictionary_bytes);
                emitted.emitted_static_commands +|= @intCast(stats.static_dictionary_copy_count);
                emitted.emitted_compound_commands +|= @intCast(stats.shared_dictionary_copy_count);
                emitted.emitted_max_distance = @max(emitted.emitted_max_distance, stats.max_wire_distance);
                if (meta.final) {
                    try Codec.checkEnd(reader);
                    if (decoded_len != expected_len) return error.SizeMismatch;
                    return emitted;
                }
            },
        }
    }
}
