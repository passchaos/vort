const std = @import("std");
const Index = @import("byte_index.zig").Index;

pub fn find(
    comptime Candidate: type,
    index: *const Index,
    input: []const u8,
    pos: usize,
    options: anytype,
    minimum: usize,
    maximum: usize,
    comptime extend: anytype,
) Candidate {
    std.debug.assert(index.position == pos and pos <= input.len and minimum >= 3);
    if (input.len - pos < minimum) return .{};
    const max_len = @min(maximum, input.len - pos);
    const prefix = std.mem.readInt(u16, input[pos + 1 ..][0..2], .little);
    var candidates = index.candidates(input[pos], options.window_len);
    var checked: usize = 0;
    var best = Candidate{};
    while (checked < options.max_chain) {
        const candidate = candidates.next() orelse break;
        // Spend the same first-byte budget as the scalar scanner, even when
        // the remaining minimum prefix rejects this anchor.
        checked += 1;
        if (std.mem.readInt(u16, input[candidate + 1 ..][0..2], .little) != prefix) continue;
        const length = extend(input, candidate, pos, max_len);
        if (length >= minimum and length > best.length) {
            best = .{ .length = length, .distance = pos - candidate };
            if (length >= options.nice_len) break;
        }
    }
    return best;
}
