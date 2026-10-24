const context = @import("../context.zig");
const input = @import("../input.zig");
const format = @import("../../format.zig");

pub const Error = context.Error;
pub const Rotation = struct { block_size: usize, start: usize };
pub const Raw = struct {
    /// Null selects the device address space; metadata inputs stay borrowed.
    input: ?input.Input = null,
    start: u64,
    physical_size: usize,
    skip: usize = 0,
    rotation: ?Rotation = null,
};
pub const Encoded = struct {
    input: ?input.Input = null,
    start: u64,
    encoded_size: usize,
    decoded_size: usize,
    algorithm: format.Compression,
    within: usize = 0,
    partial: bool = false,
};
pub const Content = union(enum) { zero, raw: Raw, encoded: Encoded, fragment: u64 };
pub const Whole = struct { start: usize, end: usize, content: Content };
pub const Segment = struct { start: usize, size: usize, content: Content, max_decoded: usize };

pub fn crop(reader_context: context.Context, whole: Whole, range_start: usize, range_end: usize, destination: usize, max_decoded: usize) Error!?Segment {
    const start = @max(whole.start, range_start);
    const end = @min(whole.end, range_end);
    if (start >= end) return null;
    var content = whole.content;
    switch (content) {
        .zero => {},
        .raw => |*raw| {
            if (raw.input == null) {
                const region = try reader_context.devices.resolveAt(0, raw.start, raw.physical_size);
                raw.input = region.input;
                raw.start = region.start;
            }
            _ = try raw.input.?.endAt(raw.start, raw.physical_size);
            raw.skip = start - whole.start;
            if (raw.rotation) |rotation| {
                if (whole.end - whole.start > rotation.block_size or raw.physical_size < rotation.block_size) return error.InvalidErofs;
            } else if (try context.add(raw.skip, end - start) > raw.physical_size) return error.InvalidErofs;
        },
        .encoded => |*encoded| {
            if (encoded.input == null) {
                const region = try reader_context.devices.resolveAt(0, encoded.start, encoded.encoded_size);
                encoded.input = region.input;
                encoded.start = region.start;
            }
            encoded.within = start - whole.start;
            if (encoded.partial) encoded.decoded_size = @min(encoded.decoded_size, end - whole.start);
        },
        .fragment => |*offset| offset.* = try context.offset(offset.*, start - whole.start),
    }
    return .{ .start = try context.add(destination, start - range_start), .size = end - start, .content = content, .max_decoded = max_decoded };
}
