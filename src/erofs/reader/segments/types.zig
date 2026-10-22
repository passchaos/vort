const context = @import("../context.zig");
const input = @import("../input.zig");
const format = @import("../../format.zig");

pub const Error = context.Error;
pub const Rotation = struct { block_size: usize, start: usize };
pub const Raw = struct {
    input: input.Input,
    start: u64,
    physical_size: usize,
    skip: usize = 0,
    rotation: ?Rotation = null,
};
pub const Encoded = struct {
    input: input.Input,
    start: u64,
    encoded_size: usize,
    decoded_size: usize,
    algorithm: format.Compression,
    within: usize = 0,
};
pub const Content = union(enum) { zero, raw: Raw, encoded: Encoded };
pub const Whole = struct { start: usize, end: usize, content: Content };
pub const Segment = struct { start: usize, size: usize, content: Content, max_decoded: usize };

pub fn crop(whole: Whole, range_start: usize, range_end: usize, destination: usize, max_decoded: usize) Error!?Segment {
    const start = @max(whole.start, range_start);
    const end = @min(whole.end, range_end);
    if (start >= end) return null;
    var content = whole.content;
    switch (content) {
        .zero => {},
        .raw => |*raw| {
            _ = try raw.input.endAt(raw.start, raw.physical_size);
            raw.skip = start - whole.start;
            if (raw.rotation) |rotation| {
                if (whole.end - whole.start > rotation.block_size or raw.physical_size < rotation.block_size) return error.InvalidErofs;
            } else if (try context.add(raw.skip, end - start) > raw.physical_size) return error.InvalidErofs;
        },
        .encoded => |*encoded| encoded.within = start - whole.start,
    }
    return .{ .start = try context.add(destination, start - range_start), .size = end - start, .content = content, .max_decoded = max_decoded };
}
