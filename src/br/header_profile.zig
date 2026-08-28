const std = @import("std");

/// Timing and shape counters for Brotli's compressed-header parser. This is a
/// diagnostic surface for repository benchmark tooling; normal decode does not
/// collect these counters or read the clock.
pub const Profile = struct {
    compressed_meta_block_count: usize = 0,
    input_bits: usize = 0,
    block_switch_ns: u64 = 0,
    context_map_ns: u64 = 0,
    literal_tree_ns: u64 = 0,
    command_tree_ns: u64 = 0,
    distance_tree_ns: u64 = 0,
    code_length_header_ns: u64 = 0,
    code_length_rle_ns: u64 = 0,
    canonical_build_ns: u64 = 0,
    simple_tree_ns: u64 = 0,
    literal_block_types: usize = 0,
    command_block_types: usize = 0,
    distance_block_types: usize = 0,
    literal_context_trees: usize = 0,
    command_trees: usize = 0,
    distance_context_trees: usize = 0,
    tree_symbols: usize = 0,
    tree_entries: usize = 0,
    complex_trees: usize = 0,
    simple_trees: usize = 0,
    code_length_symbols: usize = 0,
    repeat_symbols: usize = 0,
    repeated_lengths: usize = 0,
    families: [family_count]FamilyProfile = @splat(.{}),

    pub fn elapsedNs(self: Profile) u64 {
        return self.block_switch_ns + self.context_map_ns + self.literal_tree_ns + self.command_tree_ns + self.distance_tree_ns;
    }

    pub fn checksum(self: Profile) usize {
        return self.input_bits +% self.literal_block_types +% self.command_block_types +% self.distance_block_types +%
            self.literal_context_trees +% self.command_trees +% self.distance_context_trees +% self.tree_symbols +% self.tree_entries;
    }
};

pub const Family = enum { literal, command, distance };
pub const family_count = @typeInfo(Family).@"enum".fields.len;

pub const FamilyProfile = struct {
    code_length_header_ns: u64 = 0,
    code_length_rle_ns: u64 = 0,
    canonical_build_ns: u64 = 0,
    simple_tree_ns: u64 = 0,
    complex_trees: usize = 0,
    simple_trees: usize = 0,
    active_entries: usize = 0,
    code_length_symbols: usize = 0,
    repeat_symbols: usize = 0,
    repeated_lengths: usize = 0,
};

pub const PrefixCodeProfile = struct {
    code_length_header_ns: u64 = 0,
    code_length_rle_ns: u64 = 0,
    canonical_build_ns: u64 = 0,
    simple_tree_ns: u64 = 0,
    complex_trees: usize = 0,
    simple_trees: usize = 0,
    code_length_symbols: usize = 0,
    repeat_symbols: usize = 0,
    repeated_lengths: usize = 0,
    active_entries: usize = 0,

    pub fn addTo(self: PrefixCodeProfile, profile: *Profile, family: Family) void {
        profile.code_length_header_ns +%= self.code_length_header_ns;
        profile.code_length_rle_ns +%= self.code_length_rle_ns;
        profile.canonical_build_ns +%= self.canonical_build_ns;
        profile.simple_tree_ns +%= self.simple_tree_ns;
        profile.complex_trees +%= self.complex_trees;
        profile.simple_trees +%= self.simple_trees;
        profile.code_length_symbols +%= self.code_length_symbols;
        profile.repeat_symbols +%= self.repeat_symbols;
        profile.repeated_lengths +%= self.repeated_lengths;
        const target = &profile.families[@intFromEnum(family)];
        target.code_length_header_ns +%= self.code_length_header_ns;
        target.code_length_rle_ns +%= self.code_length_rle_ns;
        target.canonical_build_ns +%= self.canonical_build_ns;
        target.simple_tree_ns +%= self.simple_tree_ns;
        target.complex_trees +%= self.complex_trees;
        target.simple_trees +%= self.simple_trees;
        target.active_entries +%= self.active_entries;
        target.code_length_symbols +%= self.code_length_symbols;
        target.repeat_symbols +%= self.repeat_symbols;
        target.repeated_lengths +%= self.repeated_lengths;
    }
};

test "Brotli header profile totals stages and prefix counters" {
    var profile: Profile = .{
        .block_switch_ns = 1,
        .context_map_ns = 2,
        .literal_tree_ns = 3,
        .command_tree_ns = 4,
        .distance_tree_ns = 5,
    };
    const prefix: PrefixCodeProfile = .{ .code_length_symbols = 7, .repeat_symbols = 2 };
    prefix.addTo(&profile, .literal);
    try std.testing.expectEqual(@as(u64, 15), profile.elapsedNs());
    try std.testing.expectEqual(@as(usize, 7), profile.code_length_symbols);
    try std.testing.expectEqual(@as(usize, 2), profile.repeat_symbols);
    try std.testing.expectEqual(@as(usize, 7), profile.families[@intFromEnum(Family.literal)].code_length_symbols);
}
