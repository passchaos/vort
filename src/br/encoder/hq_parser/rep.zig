const std = @import("std");
const types = @import("../hq_types.zig");
const distance = @import("../distance.zig");

pub const Cache = [4]usize;
pub const initial_cache = types.initial_recent;
pub const Choice = struct {
    distance: usize,
    /// Semantic short code 0..15, or an ordinary distance plus fifteen.
    code: usize,
    encoding: distance.Encoding,
    cache: Cache,
};
pub const Choices = struct {
    items: [17]Choice = undefined,
    len: usize = 0,
    pub fn slice(self: *const Choices) []const Choice {
        return self.items[0..self.len];
    }
};

pub fn resolve(code: usize, cache: Cache) types.Error!usize {
    return types.resolveDistanceCode(code, &cache);
}
pub fn after(cache: Cache, physical_distance: usize, code: usize, is_static: bool) Cache {
    var result = cache;
    if (!is_static and code != 0) {
        result[0] = cache[1];
        result[1] = cache[2];
        result[2] = cache[3];
        result[3] = physical_distance;
    }
    return result;
}

/// Aliases remain separate: equal physical distances can have different
/// prices and future cache effects. Code zero never pushes, even when encoded
/// explicitly through the distance tree; static references never push either.
pub fn choices(cache: Cache, physical_distance: usize, parameters: distance.Parameters, is_static: bool) types.Error!Choices {
    return choicesWithFormat(cache, physical_distance, parameters, .standard, is_static);
}
pub fn usableDistance(physical_distance: usize, format: distance.Format) bool {
    return physical_distance != 0 and (format == .standard or physical_distance <= distance.safe_max_distance);
}
pub fn choicesWithFormat(cache: Cache, physical_distance: usize, parameters: distance.Parameters, format: distance.Format, is_static: bool) types.Error!Choices {
    if (physical_distance == 0) return error.InvalidBlockPlan;
    var result: Choices = .{};
    // LargeWindow's safe physical-reference bound also applies to cached
    // selectors. Preserve legitimate short codes above this parameter shape's
    // regular-code maximum, but never clamp an oversized dictionary address.
    if (!usableDistance(physical_distance, format)) return result;
    for (0..16) |code| {
        const decoded = resolve(code, cache) catch continue;
        if (decoded != physical_distance) continue;
        result.items[result.len] = .{
            .distance = physical_distance,
            .code = code,
            .encoding = .{ .symbol = @intCast(code) },
            .cache = after(cache, physical_distance, code, is_static),
        };
        result.len += 1;
    }
    if (distance.encodeWithFormat(physical_distance, parameters, format)) |encoding| {
        const code = std.math.add(usize, physical_distance, 15) catch return error.IntegerOverflow;
        result.items[result.len] = .{ .distance = physical_distance, .code = code, .encoding = encoding, .cache = after(cache, physical_distance, code, is_static) };
        result.len += 1;
    }
    return result;
}
