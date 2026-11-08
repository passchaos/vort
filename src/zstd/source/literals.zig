//! Source-backed Literals_Section wire layout.
//!
//! The parser returns only owned scalars and checked absolute source ranges. It
//! never borrows callback destinations and never reads Huffman or sequence
//! reverse payload bytes.
const std = @import("std");
const core = @import("../../core.zig");
const header = @import("../literals/header.zig");
const stream_layout = @import("../literals/streams.zig");
const tree_description = @import("../literals/tree_description.zig");
const sequence_count = @import("../sequence/count.zig");
const source_input = @import("input.zig");

pub const Error = core.Error || source_input.Error;

pub const Streams = union(enum) {
    none,
    one: source_input.Range,
    four: [4]source_input.Range,
};

/// Tree-independent literals metadata. Source decoders prepare a compressed
/// tree from this view before reading four-stream jumps or sequence counts,
/// matching the established slice parser's semantic error priority.
pub const PrefixLayout = struct {
    block: source_input.Range,
    kind: header.Kind,
    size_format: u2,
    regenerated_size: usize,
    compressed_size: usize,
    header_range: source_input.Range,
    literal_payload: source_input.Range,
    tree_description: ?source_input.Range,
    stream_data: ?source_input.Range,
    sequence_offset: u64,
};

pub const Layout = struct {
    kind: header.Kind,
    size_format: u2,
    regenerated_size: usize,
    compressed_size: usize,
    header_range: source_input.Range,
    literal_payload: source_input.Range,
    tree_description: ?source_input.Range,
    streams: Streams,
    sequence_count: usize,
    sequence_count_range: source_input.Range,
    sequence_payload: source_input.Range,
};

pub fn parsePrefix(block: source_input.Range, previous_tree_available: bool) Error!PrefixLayout {
    const first = try block.byte(0);
    const header_len = header.encodedLen(first);
    var header_bytes: [header.max_encoded_len]u8 = undefined;
    try block.readExact(0, header_bytes[0..header_len]);
    const decoded = try header.parse(header_bytes[0..header_len]);
    const header_range = try block.subrange(0, @intCast(header_len));
    const literal_len: usize = switch (decoded.kind) {
        .raw => decoded.regenerated_size,
        .rle => 1,
        .compressed, .treeless => decoded.compressed_size,
    };
    const literal_offset: u64 = @intCast(header_len);
    const literal_payload = try block.subrange(literal_offset, @intCast(literal_len));
    if (decoded.kind == .treeless and !previous_tree_available)
        return error.CorruptFrame;

    var description_range: ?source_input.Range = null;
    var stream_data: ?source_input.Range = null;
    if (decoded.kind == .compressed or decoded.kind == .treeless) {
        const description_len: usize = if (decoded.kind == .compressed) blk: {
            const tree_first = try literal_payload.byte(0);
            const len = tree_description.encodedLenFromFirst(tree_first);
            if (@as(u64, @intCast(len)) > literal_payload.len) return error.TruncatedFrame;
            description_range = try literal_payload.subrange(0, @intCast(len));
            break :blk len;
        } else 0;
        const description_len_u64: u64 = @intCast(description_len);
        stream_data = try literal_payload.subrange(
            description_len_u64,
            literal_payload.len - description_len_u64,
        );
    }

    const sequence_offset = std.math.add(u64, literal_offset, @as(u64, @intCast(literal_len))) catch
        return error.IntegerOverflow;

    return .{
        .block = block,
        .kind = decoded.kind,
        .size_format = decoded.size_format,
        .regenerated_size = decoded.regenerated_size,
        .compressed_size = decoded.compressed_size,
        .header_range = header_range,
        .literal_payload = literal_payload,
        .tree_description = description_range,
        .stream_data = stream_data,
        .sequence_offset = sequence_offset,
    };
}

pub fn finishLayout(prefix: PrefixLayout) Error!Layout {
    var huffman_streams: Streams = .none;
    if (prefix.stream_data) |stream_data| {
        var jump: [6]u8 = undefined;
        const numeric = if (prefix.size_format == 0)
            try stream_layout.parse(prefix.size_format, @intCast(stream_data.len), null)
        else blk: {
            if (stream_data.len < jump.len) return error.CorruptFrame;
            try stream_data.readExact(0, &jump);
            break :blk try stream_layout.parse(prefix.size_format, @intCast(stream_data.len), &jump);
        };
        huffman_streams = switch (numeric) {
            .one => |span| .{ .one = try stream_data.subrange(@intCast(span.offset), @intCast(span.len)) },
            .four => |spans| four: {
                var ranges: [4]source_input.Range = undefined;
                for (spans, 0..) |span, index|
                    ranges[index] = try stream_data.subrange(@intCast(span.offset), @intCast(span.len));
                break :four .{ .four = ranges };
            },
        };
    }

    const sequence_first = try prefix.block.byte(prefix.sequence_offset);
    const count_len = sequence_count.encodedLen(sequence_first);
    var count_bytes: [sequence_count.max_encoded_len]u8 = undefined;
    try prefix.block.readExact(prefix.sequence_offset, count_bytes[0..count_len]);
    const count = try sequence_count.parse(count_bytes[0..count_len]);
    const count_range = try prefix.block.subrange(prefix.sequence_offset, @intCast(count_len));
    const sequence_payload_offset = std.math.add(u64, prefix.sequence_offset, @as(u64, @intCast(count_len))) catch
        return error.IntegerOverflow;
    const sequence_payload = try prefix.block.subrange(
        sequence_payload_offset,
        prefix.block.len - sequence_payload_offset,
    );

    return .{
        .kind = prefix.kind,
        .size_format = prefix.size_format,
        .regenerated_size = prefix.regenerated_size,
        .compressed_size = prefix.compressed_size,
        .header_range = prefix.header_range,
        .literal_payload = prefix.literal_payload,
        .tree_description = prefix.tree_description,
        .streams = huffman_streams,
        .sequence_count = count,
        .sequence_count_range = count_range,
        .sequence_payload = sequence_payload,
    };
}

pub fn parseLayout(block: source_input.Range, previous_tree_available: bool) Error!Layout {
    return finishLayout(try parsePrefix(block, previous_tree_available));
}

test "Zstd source literals raw layout skips payload bytes" {
    const byte_source = @import("../../io/source.zig");
    const bytes = [_]u8{ 0x10, 'a', 'b', 0 };
    var slice = byte_source.SliceSource{ .bytes = &bytes };
    const block = try source_input.Range.init(slice.source(), 0, bytes.len);
    const layout = try parseLayout(block, false);
    try std.testing.expectEqual(header.Kind.raw, layout.kind);
    try std.testing.expectEqual(@as(usize, 2), layout.regenerated_size);
    try std.testing.expectEqual(@as(u64, 1), layout.literal_payload.offset);
    try std.testing.expectEqual(@as(u64, 2), layout.literal_payload.len);
    try std.testing.expectEqual(@as(usize, 0), layout.sequence_count);
}
