//! Library contract observer, using the public progressive decoder and summary.
//! These checks are not an independent upstream/reference Brotli parser.
const std = @import("std");
const a = std.testing.allocator;

pub const Stats = struct {
    frames: usize = 0,
    disabled_frames: usize = 0,
    compressed_frames: usize = 0,
    compressed_blocks: usize = 0,
    disabled_compressed_blocks: usize = 0,
    literal_types: usize = 0,
    max_literal_types: usize = 0,
    disabled_max_literal_types: usize = 0,
    nonconstant_literal_types: usize = 0,
    max_distance_types: usize = 0,
    max_distance_trees: usize = 0,
    distance_parameter_frames: usize = 0,
    lz77_copies: usize = 0,
    disabled_lz77_copies: usize = 0,
    dictionary_copies: usize = 0,
    bytes: usize = 0,

    pub fn add(self: *Stats, other: Stats) void {
        inline for (.{ "frames", "disabled_frames", "compressed_frames", "compressed_blocks", "disabled_compressed_blocks", "literal_types", "nonconstant_literal_types", "distance_parameter_frames", "lz77_copies", "disabled_lz77_copies", "dictionary_copies", "bytes" }) |name|
            @field(self, name) += @field(other, name);
        inline for (.{ "max_literal_types", "disabled_max_literal_types", "max_distance_types", "max_distance_trees" }) |name|
            @field(self, name) = @max(@field(self, name), @field(other, name));
    }
};

fn inspect(decoder: anytype, disabled: bool, last_end: *?u64, stats: *Stats) !void {
    const phase = decoder.phase;
    switch (phase) {
        .command, .literals, .distance, .copy, .dictionary => {},
        .trailer, .padding, .done => if (decoder.header_trees == 0) return,
        else => return,
    }
    const end: u64 = @intCast(decoder.header.decoded_len);
    if (last_end.* != null and last_end.*.? == end) return;
    last_end.* = end;
    const header = &decoder.header.compressed;
    const types: usize = header.literal_block.block_type_count;
    try std.testing.expect(types != 0);
    stats.compressed_blocks += 1;
    stats.literal_types += types;
    stats.max_literal_types = @max(stats.max_literal_types, types);
    if (disabled) {
        stats.disabled_compressed_blocks += 1;
        stats.disabled_max_literal_types = @max(stats.disabled_max_literal_types, types);
    }
    for (0..types) |index| {
        const map = header.literal_context_map[index * 64 ..][0..64];
        var constant = true;
        for (map) |tree| {
            try std.testing.expect(tree < header.literal_tree_count);
            constant = constant and tree == map[0];
        }
        if (disabled) try std.testing.expect(constant);
        if (!constant) stats.nonconstant_literal_types += 1;
    }
    stats.max_distance_types = @max(stats.max_distance_types, header.distance_block.block_type_count);
    stats.max_distance_trees = @max(stats.max_distance_trees, header.distance_tree_count);
    for (header.distance_context_map[0 .. @as(usize, header.distance_block.block_type_count) * 4]) |tree|
        try std.testing.expect(tree < header.distance_tree_count);
    if (header.npostfix != 0 or header.ndirect != 0) stats.distance_parameter_frames += 1;
}

pub fn check(comptime D: type, wire: []const u8, expected: []const u8, disabled: bool, options: D.DecodeOptions) !Stats {
    // Retain every plaintext byte that can be referenced by this bounded
    // fixture. A large advertised window does not allocate unneeded GiB.
    const history = try a.alloc(u8, @max(@as(usize, 1), expected.len));
    defer a.free(history);
    const output = try a.alloc(u8, expected.len);
    defer a.free(output);
    const decoder = try a.create(D.IncrementalCopyStreamDecoder);
    defer a.destroy(decoder);
    decoder.* = D.IncrementalCopyStreamDecoder.initWithOptions(history, .{
        .decode = options,
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    var stats: Stats = .{};
    var last_end: ?u64 = null;
    var read: usize = 0;
    var written: usize = 0;
    var calls: usize = 0;
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    while (decoder.phase != .done) : (calls += 1) {
        try std.testing.expect(calls < (wire.len + expected.len) * 16 + 128);
        try inspect(decoder, disabled, &last_end, &stats);
        const advanced = try decoder.step(wire[read..@min(wire.len, read + 1)], output[written..@min(output.len, written + 1)]);
        read += advanced.progress.input_read;
        crc.update(output[written..][0..advanced.progress.output_written]);
        written += advanced.progress.output_written;
        try inspect(decoder, disabled, &last_end, &stats);
        if (advanced.status == .need_input) try std.testing.expect(read < wire.len);
        if (advanced.status == .need_output) try std.testing.expect(written < output.len);
    }
    try decoder.finish();
    try std.testing.expectEqual(wire.len, read);
    try std.testing.expectEqual(expected.len, written);
    try std.testing.expectEqualSlices(u8, expected, output);
    try std.testing.expectEqual(std.hash.crc.Crc32IsoHdlc.hash(expected), crc.final());
    try std.testing.expectEqual(@as(D.IncrementalCopyStreamDecoder.Counter, @intCast(wire.len)), decoder.snapshot().total_compressed);
    try std.testing.expectEqual(@as(D.IncrementalCopyStreamDecoder.Counter, @intCast(expected.len)), decoder.snapshot().total_output);
    const summary = try D.summarizeStreamAllocLimitedWithOptions(a, wire, expected.len, options);
    try std.testing.expectEqual(@as(u64, @intCast(stats.compressed_blocks)), @as(u64, @intCast(summary.compressed_meta_block_count)));
    stats.frames = 1;
    stats.disabled_frames = @intFromBool(disabled);
    stats.compressed_frames = @intFromBool(stats.compressed_blocks != 0);
    stats.lz77_copies = @intCast(summary.lz77_copy_count);
    stats.disabled_lz77_copies = if (disabled) stats.lz77_copies else 0;
    stats.dictionary_copies = @intCast(summary.static_dictionary_copy_count + summary.shared_dictionary_copy_count);
    stats.bytes = expected.len;
    return stats;
}
