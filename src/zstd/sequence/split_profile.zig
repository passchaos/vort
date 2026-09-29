const std = @import("std");

pub const Path = enum(u3) {
    all_fse,
    generic,
    non_huffman_literals,
    below_policy,
    one_stream,
    incomplete_lookup,
};

pub const path_count = 6;
pub const path_order = "all_fse;generic;non_huffman_literals;below_policy;one_stream;incomplete_lookup";

comptime {
    std.debug.assert(@typeInfo(Path).@"enum".fields.len == path_count);
}

pub const Classification = struct {
    huffman_literals: bool,
    prefer_generic: bool,
    four_streams: bool,
    complete_lookup: bool,
    all_fse: bool,
    prefer_all_fse: bool,
};

/// Mirror the production split-decoder routing as mutually exclusive profile
/// buckets. The classifier deliberately accepts only already-computed facts so
/// profiling policy stays separate from format parsing and hot decode code.
pub fn classify(input: Classification) Path {
    if (!input.huffman_literals) return .non_huffman_literals;
    if (!input.prefer_generic) return .below_policy;
    if (!input.four_streams) return .one_stream;
    if (!input.complete_lookup) return .incomplete_lookup;
    if (input.all_fse and input.prefer_all_fse) return .all_fse;
    return .generic;
}

pub const Profile = struct {
    blocks: [path_count]usize = @splat(0),
    sequences: [path_count]usize = @splat(0),
    literal_bytes: [path_count]usize = @splat(0),
    match_bytes: [path_count]usize = @splat(0),

    pub fn recordBlock(self: *Profile, path: Path, literals: usize) void {
        const index = @intFromEnum(path);
        self.blocks[index] += 1;
        self.literal_bytes[index] += literals;
    }

    pub fn recordSequence(self: *Profile, path: Path, match_bytes: usize) void {
        const index = @intFromEnum(path);
        self.sequences[index] += 1;
        self.match_bytes[index] += match_bytes;
    }
};

test "split profile classifies production routing priority" {
    const all_fse: Classification = .{
        .huffman_literals = true,
        .prefer_generic = true,
        .four_streams = true,
        .complete_lookup = true,
        .all_fse = true,
        .prefer_all_fse = true,
    };
    try std.testing.expectEqual(Path.all_fse, classify(all_fse));

    var input = all_fse;
    input.prefer_all_fse = false;
    try std.testing.expectEqual(Path.generic, classify(input));
    input.prefer_all_fse = true;
    input.all_fse = false;
    try std.testing.expectEqual(Path.generic, classify(input));

    input = all_fse;
    input.complete_lookup = false;
    try std.testing.expectEqual(Path.incomplete_lookup, classify(input));
    input.four_streams = false;
    try std.testing.expectEqual(Path.one_stream, classify(input));
    input.prefer_generic = false;
    try std.testing.expectEqual(Path.below_policy, classify(input));
    input.huffman_literals = false;
    try std.testing.expectEqual(Path.non_huffman_literals, classify(input));
}

test "split profile accumulates path-weighted work" {
    var profile: Profile = .{};
    profile.recordBlock(.all_fse, 11);
    profile.recordSequence(.all_fse, 23);
    profile.recordSequence(.all_fse, 29);
    profile.recordBlock(.incomplete_lookup, 7);
    profile.recordSequence(.incomplete_lookup, 31);

    try std.testing.expectEqual(@as(usize, 1), profile.blocks[@intFromEnum(Path.all_fse)]);
    try std.testing.expectEqual(@as(usize, 2), profile.sequences[@intFromEnum(Path.all_fse)]);
    try std.testing.expectEqual(@as(usize, 11), profile.literal_bytes[@intFromEnum(Path.all_fse)]);
    try std.testing.expectEqual(@as(usize, 52), profile.match_bytes[@intFromEnum(Path.all_fse)]);
    try std.testing.expectEqual(@as(usize, 1), profile.blocks[@intFromEnum(Path.incomplete_lookup)]);
    try std.testing.expectEqual(@as(usize, 31), profile.match_bytes[@intFromEnum(Path.incomplete_lookup)]);
}
