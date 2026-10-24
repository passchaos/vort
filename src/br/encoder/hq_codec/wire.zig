const std = @import("std");
const options = @import("../hq_options.zig");
const distance = @import("../distance.zig");
const Model = @import("../hq_parser/prices.zig").Model;

pub const Context = struct {
    start_byte: u8 = 0,
    start_bit_index: u3 = 0,
    window_bits: u5,
    literal_mode: u2,
    previous: [2]u8 = .{ 0, 0 },
    distance_parameters: distance.Parameters,
    compound_dictionary_size: usize = 0,
    write_stream_prefix: bool = false,
    final_meta_block: bool = false,
    metadata: []const u8 = "",
};

pub const Artifact = struct {
    bytes: std.ArrayList(u8) = .empty,
    bit_index: u3 = 0,
    bit_count: usize = 0,
    last_distances: [4]usize,
    frame_offset: u64,
    model: ?*Model = null,
    emitted: options.HqProfile.Emitted = .{},
    stored: bool = false,

    pub fn deinit(self: *Artifact, allocator: std.mem.Allocator) void {
        if (self.model) |model| allocator.destroy(model);
        self.bytes.deinit(allocator);
        self.* = undefined;
    }
};
