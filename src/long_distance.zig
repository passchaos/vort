const std = @import("std");
const lz77 = @import("lz77.zig");

pub const Candidate = struct {
    position: usize,
    distance: usize,
    length: usize,
};

pub const Options = struct {
    min_distance: usize = lz77.default_window_len + 1,
    min_length: usize = 8,
    max_length: usize = 1024,
    max_candidates: usize = 64,
};

pub fn findCandidatesAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) ![]Candidate {
    var out: std.ArrayList(Candidate) = .empty;
    errdefer out.deinit(allocator);
    var pos: usize = options.min_distance;
    while (pos + options.min_length <= input.len and out.items.len < options.max_candidates) : (pos += 1) {
        var prev: usize = 0;
        while (prev + options.min_length <= pos) : (prev += 1) {
            const distance = pos - prev;
            if (distance < options.min_distance) continue;
            var len: usize = 0;
            const max_len = @min(options.max_length, input.len - pos);
            while (len < max_len and input[prev + len] == input[pos + len]) len += 1;
            if (len >= options.min_length) {
                try out.append(allocator, .{ .position = pos, .distance = distance, .length = len });
                break;
            }
        }
    }
    return out.toOwnedSlice(allocator);
}

pub const Summary = struct {
    candidates: usize = 0,
    longest: usize = 0,
    max_distance: usize = 0,
};

pub fn summarizeAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) !Summary {
    const candidates = try findCandidatesAlloc(allocator, input, options);
    defer allocator.free(candidates);
    var summary = Summary{ .candidates = candidates.len };
    for (candidates) |candidate| {
        summary.longest = @max(summary.longest, candidate.length);
        summary.max_distance = @max(summary.max_distance, candidate.distance);
    }
    return summary;
}

test "long-distance scanner finds beyond-window repetitions" {
    const prefix = "abcd" ** 9000;
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const candidates = try findCandidatesAlloc(std.testing.allocator, input, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(candidates);
    try std.testing.expect(candidates.len > 0);
    try std.testing.expect(candidates[0].distance >= 32769);
    try std.testing.expect(candidates[0].length >= 16);
}

test "long-distance summary reports aggregate candidates" {
    const prefix = "abcd" ** 9000;
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const summary = try summarizeAlloc(std.testing.allocator, input, .{ .min_distance = 32769, .min_length = 16 });
    try std.testing.expect(summary.candidates > 0);
    try std.testing.expect(summary.longest >= 16);
    try std.testing.expect(summary.max_distance >= 32769);
}
