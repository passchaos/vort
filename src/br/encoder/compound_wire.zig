const std = @import("std");
const command_plan = @import("command_plan.zig");

pub const Source = command_plan.Source;

pub const Error = error{
    InvalidBlockPlan,
    IntegerOverflow,
};

/// Convert an encoder command's logical distance or dictionary address into
/// the distance represented on a Brotli wire.
///
/// `logical_value` is an LZ77 backward distance for `.lz77` and a zero-based
/// dictionary address for `.compound` and `.static`. `max_history` is the
/// active history limit, which remains capped at the Brotli window after the
/// produced output has filled that window.
pub fn wireDistance(
    source: Source,
    logical_value: usize,
    max_history: usize,
    compound_size: usize,
) Error!usize {
    return switch (source) {
        .lz77 => if (logical_value == 0)
            error.InvalidBlockPlan
        else
            logical_value,
        .compound => compoundDistance(logical_value, max_history, compound_size),
        .static => staticDistance(logical_value, max_history, compound_size),
    };
}

fn compoundDistance(
    address: usize,
    max_history: usize,
    compound_size: usize,
) Error!usize {
    if (address >= compound_size) return error.InvalidBlockPlan;

    // Subtract first so valid boundary inputs do not spuriously overflow the
    // equivalent `max_history + compound_size - address` expression.
    const suffix_distance = std.math.sub(usize, compound_size, address) catch
        return error.IntegerOverflow;
    return std.math.add(usize, max_history, suffix_distance) catch
        return error.IntegerOverflow;
}

fn staticDistance(
    address: usize,
    max_history: usize,
    compound_size: usize,
) Error!usize {
    const after_history = std.math.add(usize, max_history, compound_size) catch
        return error.IntegerOverflow;
    const first_static = std.math.add(usize, after_history, 1) catch
        return error.IntegerOverflow;
    return std.math.add(usize, first_static, address) catch
        return error.IntegerOverflow;
}

/// Static-dictionary distances never participate in Brotli's recent-distance
/// ring. Both ordinary history and compound-dictionary distances do.
pub inline fn canUseRecentDistance(source: Source) bool {
    return source != .static;
}

/// Whether committing this command must move its actual wire distance to the
/// front of the recent-distance ring. An implicit rep0 reuses the newest entry
/// in place; all other eligible encodings, including explicit compound
/// distances, update the ring.
pub inline fn updatesRecentDistance(source: Source, implicit_rep0: bool) bool {
    return canUseRecentDistance(source) and !implicit_rep0;
}

test "compound wire distances map every command source" {
    try std.testing.expectEqual(
        @as(usize, 7),
        try wireDistance(.lz77, 7, 10, 5),
    );

    // The closest compound distance addresses the final dictionary byte.
    try std.testing.expectEqual(
        @as(usize, 15),
        try wireDistance(.compound, 0, 10, 5),
    );
    try std.testing.expectEqual(
        @as(usize, 11),
        try wireDistance(.compound, 4, 10, 5),
    );
    try std.testing.expectEqual(
        @as(usize, 1),
        try wireDistance(.compound, 0, 0, 1),
    );

    // Static address zero follows the whole compound distance region.
    try std.testing.expectEqual(
        @as(usize, 16),
        try wireDistance(.static, 0, 10, 5),
    );
    try std.testing.expectEqual(
        @as(usize, 23),
        try wireDistance(.static, 7, 10, 5),
    );
    try std.testing.expectEqual(
        @as(usize, 1),
        try wireDistance(.static, 0, 0, 0),
    );
}

test "compound wire distances reject zero and out-of-range logical values" {
    try std.testing.expectError(
        error.InvalidBlockPlan,
        wireDistance(.lz77, 0, 0, 0),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        wireDistance(.compound, 0, 10, 0),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        wireDistance(.compound, 5, 10, 5),
    );
    try std.testing.expectError(
        error.InvalidBlockPlan,
        wireDistance(.compound, 6, 10, 5),
    );
}

test "compound wire arithmetic preserves usize boundaries and reports overflow" {
    const maximum = std.math.maxInt(usize);

    // Although max_history + compound_size would overflow, subtracting the
    // address first proves this valid distance is exactly representable.
    try std.testing.expectEqual(
        maximum,
        try wireDistance(.compound, maximum - 1, maximum - 1, maximum),
    );
    try std.testing.expectError(
        error.IntegerOverflow,
        wireDistance(.compound, 0, maximum, 1),
    );

    try std.testing.expectEqual(
        maximum,
        try wireDistance(.static, 0, maximum - 1, 0),
    );
    try std.testing.expectError(
        error.IntegerOverflow,
        wireDistance(.static, 0, maximum, 0),
    );
    try std.testing.expectError(
        error.IntegerOverflow,
        wireDistance(.static, 0, 0, maximum),
    );
    try std.testing.expectError(
        error.IntegerOverflow,
        wireDistance(.static, maximum, 0, 0),
    );
}

test "dictionary wire distances retain the saturated active window base" {
    const window_limit = (@as(usize, 1) << 16) - 16;
    const produced = window_limit + 4096;
    const max_history = @min(produced, window_limit);
    const compound_size: usize = 4;

    try std.testing.expectEqual(
        window_limit + 1,
        try wireDistance(.compound, compound_size - 1, max_history, compound_size),
    );
    try std.testing.expectEqual(
        window_limit + compound_size + 1 + 3,
        try wireDistance(.static, 3, max_history, compound_size),
    );
}

test "recent ring eligibility distinguishes compound static and rep0" {
    try std.testing.expect(canUseRecentDistance(.lz77));
    try std.testing.expect(canUseRecentDistance(.compound));
    try std.testing.expect(!canUseRecentDistance(.static));

    try std.testing.expect(updatesRecentDistance(.lz77, false));
    try std.testing.expect(updatesRecentDistance(.compound, false));
    try std.testing.expect(!updatesRecentDistance(.static, false));

    try std.testing.expect(!updatesRecentDistance(.lz77, true));
    try std.testing.expect(!updatesRecentDistance(.compound, true));
    try std.testing.expect(!updatesRecentDistance(.static, true));
}
