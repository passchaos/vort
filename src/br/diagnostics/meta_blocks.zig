const std = @import("std");
const bit_count = @import("../../io/bit_count.zig");
const summary = @import("../summary/types.zig");
const dispatch = @import("../decoder/prepared_dispatch.zig");

pub const Options = struct {
    max_output_len: usize = 256 * 1024 * 1024,
    max_meta_blocks: usize = 4096,
};

pub const Record = struct {
    kind: enum { compressed, stored, metadata },
    route: ?dispatch.Route = null,
    meta_block_index: usize,
    header_start: bit_count.BitCount,
    compressed_header_start: ?bit_count.BitCount = null,
    payload_start: bit_count.BitCount,
    payload_end: bit_count.BitCount,
    decoded_start: usize,
    decoded_end: usize,
    literal_trees: u16 = 0,
    command_trees: u16 = 0,
    distance_trees: u16 = 0,
    npostfix: u2 = 0,
    ndirect: u16 = 0,
    header_ns: u64 = 0,
    payload_ns: u64 = 0,
    /// Small ordinary streams invoke their existing dictionary-aware decoder,
    /// which reconstructs its header. This diagnostic does not subtract it.
    small_payload_includes_header: bool = false,
    stats: summary.MetaBlockStats = .{},
};

pub const Report = struct {
    window_bits: u5,
    records: []Record,
    output: []u8,
    replay_history_bytes: usize,

    pub fn deinit(self: *Report, allocator: std.mem.Allocator) void {
        allocator.free(self.records);
        allocator.free(self.output);
        self.* = undefined;
    }
};

/// Diagnostic discovery owns decoded output, two parsed headers and a full
/// bounded replay window. Clocks describe instrumented per-block work, not
/// competitor timing or the production decoder's allocation requirements.
pub fn inspect(comptime Codec: type, io: std.Io, allocator: std.mem.Allocator, stream: []const u8, options: Options) Codec.Error!Report {
    if (options.max_meta_blocks == 0) return error.InvalidBlockPlan;
    var reader = Codec.Reader.init(stream);
    const window_bits = try Codec.readWindow(&reader);
    const window_len = (@as(usize, 1) << window_bits) - 16;
    const history_bytes = @min(options.max_output_len, window_len);
    const history_storage = try allocator.alloc(u8, history_bytes);
    defer allocator.free(history_storage);
    const history = try allocator.create(Codec.History);
    defer allocator.destroy(history);
    history.* = .{ .external = history_storage };
    const header = try allocator.create(Codec.Header);
    defer allocator.destroy(header);
    const replay_header = try allocator.create(Codec.Header);
    defer allocator.destroy(replay_header);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var records: std.ArrayList(Record) = .empty;
    errdefer records.deinit(allocator);
    var written: usize = 0;
    var last_distances = Codec.initial_distances;
    var replay_distances = last_distances;
    while (true) {
        const header_start = reader.bitPosition();
        const meta = try Codec.readMeta(&reader);
        switch (meta) {
            .end => {
                try Codec.finish(reader);
                return own(allocator, window_bits, history_bytes, &output, &records);
            },
            else => {},
        }
        if (records.items.len >= options.max_meta_blocks) return error.WorkingMemoryLimitExceeded;
        try records.ensureUnusedCapacity(allocator, 1);
        const decoded_start = written;
        var record: Record = .{
            .kind = .compressed,
            .meta_block_index = records.items.len,
            .header_start = header_start,
            .payload_start = reader.bitPosition(),
            .payload_end = reader.bitPosition(),
            .decoded_start = written,
            .decoded_end = written,
        };
        switch (meta) {
            .end => unreachable,
            .metadata => {
                record.kind = .metadata;
                try Codec.skipMetadata(&reader);
            },
            .uncompressed => |len| {
                record.kind = .stored;
                const end = try limitedEnd(Codec.Error, written, len, options.max_output_len);
                try output.resize(allocator, end);
                try Codec.consumePadding(&reader);
                record.payload_start = reader.bitPosition();
                try reader.readAlignedBytes(output.items[written..end]);
                Codec.pushHistory(history, output.items[written..end]);
                written = end;
            },
            .compressed => |compressed| {
                const end = try limitedEnd(Codec.Error, written, compressed.decoded_len, options.max_output_len);
                try output.resize(allocator, end);
                const compressed_start = reader;
                record.compressed_header_start = reader.bitPosition();
                const header_start_time = std.Io.Clock.awake.now(io);
                try Codec.readHeader(&reader, header);
                record.header_ns = elapsedNs(header_start_time, io);
                record.payload_start = reader.bitPosition();
                const payload_start = reader;
                replay_header.* = header.*;
                record.literal_trees = header.literal_tree_count;
                record.command_trees = header.command_block.block_type_count;
                record.distance_trees = header.distance_tree_count;
                record.npostfix = header.npostfix;
                record.ndirect = header.ndirect;
                seedShape(&record.stats, header);
                var route: dispatch.Route = undefined;
                record.small_payload_includes_header = Codec.smallGeneric(stream.len, compressed.decoded_len);
                const payload_start_time = std.Io.Clock.awake.now(io);
                try Codec.execute(&reader, compressed_start, output.items, &written, compressed.decoded_len, end, &last_distances, window_bits, header, &route, record.small_payload_includes_header);
                record.payload_ns = elapsedNs(payload_start_time, io);
                if (written != end) return error.SizeMismatch;
                record.route = route;
                var replay_reader = payload_start;
                // Replay counters and compare semantic state outside every
                // reported production-stage clock. Use the pre-execution header.
                try Codec.replay(&replay_reader, decoded_start, end, &replay_distances, history, &record.stats, window_bits, replay_header);
                if (replay_reader.bitPosition() != reader.bitPosition() or
                    !std.mem.eql(usize, &last_distances, &replay_distances) or
                    !Codec.historyMatches(history, output.items)) return error.InvalidBlockPlan;
                record.payload_end = reader.bitPosition();
                record.decoded_end = written;
                records.appendAssumeCapacity(record);
                if (compressed.final) {
                    try Codec.finish(reader);
                    return own(allocator, window_bits, history_bytes, &output, &records);
                }
                continue;
            },
        }
        record.payload_end = reader.bitPosition();
        record.decoded_end = written;
        records.appendAssumeCapacity(record);
    }
}

fn limitedEnd(comptime Error: type, start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.WorkingMemoryLimitExceeded;
    return end;
}

fn own(allocator: std.mem.Allocator, window_bits: u5, history_bytes: usize, output: *std.ArrayList(u8), records: *std.ArrayList(Record)) std.mem.Allocator.Error!Report {
    const bytes = try output.toOwnedSlice(allocator);
    errdefer allocator.free(bytes);
    return .{ .window_bits = window_bits, .records = try records.toOwnedSlice(allocator), .output = bytes, .replay_history_bytes = history_bytes };
}

fn seedShape(stats: *summary.MetaBlockStats, header: anytype) void {
    stats.max_literal_block_types = header.literal_block.block_type_count;
    stats.max_literal_context_trees = header.literal_tree_count;
    stats.max_command_block_types = header.command_block.block_type_count;
    stats.max_distance_block_types = header.distance_block.block_type_count;
    stats.max_distance_context_trees = header.distance_tree_count;
    stats.max_distance_postfix_bits = header.npostfix;
    stats.max_direct_distance_codes = header.ndirect;
}

fn elapsedNs(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}
