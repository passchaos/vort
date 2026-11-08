//! Source-backed Zstandard frame and block wire layout.
//!
//! These parsers retain only scalar metadata and checked absolute ranges. They
//! do not materialize block or skippable payloads, decode entropy streams, or
//! apply dictionary policy.
const std = @import("std");
const core = @import("../../core.zig");
const frame_block = @import("../frame/block.zig");
const frame_format = @import("../frame/format.zig");
const frame_header = @import("../frame/header.zig");
const frame_skippable = @import("../frame/skippable.zig");
const source_input = @import("input.zig");

pub const Error = core.Error || source_input.Error;
pub const FrameFormat = frame_format.FrameFormat;

pub const DataFrameLayout = struct {
    format: FrameFormat,
    /// Caller-provided bytes beginning at this frame. The range may include a
    /// concatenated suffix; block parsing remains bounded by it.
    available: source_input.Range,
    header: frame_header.WireHeader,
    prefix_range: source_input.Range,
    wire_header_range: source_input.Range,
    header_range: source_input.Range,
    blocks: source_input.Range,
    first_block_offset: u64,
};

pub const SkippableFrameLayout = struct {
    magic: u32,
    skippable_id: u4,
    frame_range: source_input.Range,
    header_range: source_input.Range,
    payload: source_input.Range,
    next_element_offset: u64,
};

pub const StreamElement = union(enum) {
    data: DataFrameLayout,
    skippable: SkippableFrameLayout,
};

pub const BlockLayout = struct {
    header: frame_block.Header,
    header_range: source_input.Range,
    payload: source_input.Range,
    next_header_offset: u64,
};

const Prefix = struct {
    kind: frame_format.Prefix,
    range: source_input.Range,
};

fn parsePrefix(available: source_input.Range, format: FrameFormat) Error!Prefix {
    if (format == .magicless) return .{
        .kind = .data,
        .range = try available.subrange(0, 0),
    };

    var bytes: [4]u8 = undefined;
    try available.readExact(0, &bytes);
    return .{
        .kind = try frame_format.classifyMagic(std.mem.readInt(u32, &bytes, .little)),
        .range = try available.subrange(0, bytes.len),
    };
}

fn parseDataAfterPrefix(
    available: source_input.Range,
    format: FrameFormat,
    prefix_range: source_input.Range,
) Error!DataFrameLayout {
    const descriptor_offset = prefix_range.len;
    const descriptor = try available.byte(descriptor_offset);
    const encoded_len = try frame_header.encodedLen(descriptor);
    const encoded_len_u64: u64 = @intCast(encoded_len);
    const wire_header_range = try available.subrange(descriptor_offset, encoded_len_u64);

    var bytes: [frame_header.max_encoded_len]u8 = undefined;
    bytes[0] = descriptor;
    if (encoded_len > 1)
        try wire_header_range.readExact(1, bytes[1..encoded_len]);
    const header = try frame_header.parse(bytes[0..encoded_len]);

    const header_len = std.math.add(u64, descriptor_offset, encoded_len_u64) catch
        return error.IntegerOverflow;
    const header_range = try available.subrange(0, header_len);
    const blocks = try available.subrange(header_len, available.len - header_len);
    return .{
        .format = format,
        .available = available,
        .header = header,
        .prefix_range = prefix_range,
        .wire_header_range = wire_header_range,
        .header_range = header_range,
        .blocks = blocks,
        .first_block_offset = try header_range.end(),
    };
}

/// Parse one data-frame header. Standard skippable prefixes are deliberately
/// rejected as `InvalidMagic`, matching the existing slice frame inspector.
pub fn parseDataFrameHeader(
    available: source_input.Range,
    format: FrameFormat,
) Error!DataFrameLayout {
    const prefix = try parsePrefix(available, format);
    if (prefix.kind != .data) return error.InvalidMagic;
    return parseDataAfterPrefix(available, format, prefix.range);
}

fn parseSkippableAfterPrefix(
    available: source_input.Range,
    magic: u32,
) Error!SkippableFrameLayout {
    var length_bytes: [4]u8 = undefined;
    try available.readExact(4, &length_bytes);
    var bytes: [frame_skippable.encoded_len]u8 = undefined;
    std.mem.writeInt(u32, bytes[0..4], magic, .little);
    @memcpy(bytes[4..], &length_bytes);
    const header = try frame_skippable.parse(&bytes);
    const payload_len: u64 = header.payload_len;
    const header_range = try available.subrange(0, frame_skippable.encoded_len);
    const payload = try available.subrange(8, payload_len);
    const frame_len = std.math.add(u64, 8, payload_len) catch
        return error.IntegerOverflow;
    const frame_range = try available.subrange(0, frame_len);
    return .{
        .magic = magic,
        .skippable_id = header.id,
        .frame_range = frame_range,
        .header_range = header_range,
        .payload = payload,
        .next_element_offset = try frame_range.end(),
    };
}

/// Parse the next standard data/skippable header, or one magicless data
/// header. Skippable payloads are range-checked without being read.
pub fn parseStreamElementHeader(
    available: source_input.Range,
    format: FrameFormat,
) Error!StreamElement {
    const prefix = try parsePrefix(available, format);
    return switch (prefix.kind) {
        .data => .{ .data = try parseDataAfterPrefix(available, format, prefix.range) },
        .skippable => |magic| .{ .skippable = try parseSkippableAfterPrefix(available, magic) },
    };
}

/// Parse a block header at an absolute source offset and derive its wire
/// payload range. The payload itself is never read. RLE blocks therefore carry
/// a declared regenerated length but exactly one source byte in `payload`.
pub fn parseBlock(
    frame: DataFrameLayout,
    header_offset: u64,
) Error!BlockLayout {
    if (header_offset < frame.first_block_offset) return error.CorruptFrame;
    const available_end = try frame.available.end();
    if (header_offset > available_end) return error.TruncatedFrame;
    const relative_offset = header_offset - frame.available.offset;

    var bytes: [3]u8 = undefined;
    try frame.available.readExact(relative_offset, &bytes);
    const header = try frame_block.parse(&bytes);
    try frame_block.validateSize(header, frame.header.block_size_max);

    const payload_offset = std.math.add(u64, relative_offset, bytes.len) catch
        return error.IntegerOverflow;
    const wire_len = std.math.cast(u64, header.wire_len) orelse
        return error.IntegerOverflow;
    const header_range = try frame.available.subrange(relative_offset, bytes.len);
    const payload = try frame.available.subrange(payload_offset, wire_len);
    return .{
        .header = header,
        .header_range = header_range,
        .payload = payload,
        .next_header_offset = try payload.end(),
    };
}

pub fn parseFirstBlock(frame: DataFrameLayout) Error!BlockLayout {
    return parseBlock(frame, frame.first_block_offset);
}
