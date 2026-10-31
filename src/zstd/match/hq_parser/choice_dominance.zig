//! Materialize one exact offset encoding per adjacent successor-history group.
const std = @import("std");
const rep = @import("rep.zig");
const prices = @import("prices.zig");

/// The caller supplies the ascending offset order returned by rep.choices and
/// an immutable validated entropy model. Equal terms keep the first offset,
/// which is also the original state/spill tie winner. Different repeat triples
/// remain independent; even a repeated distance may have a different future.
pub inline fn materializeMask(choices: *const rep.Choices, model: *const prices.EntropyModel) u8 {
    var result: u8 = 0;
    var start: usize = 0;
    const items = choices.slice();
    while (start < items.len) {
        var end = start + 1;
        while (end < items.len and sameRepeats(items[start].repeats, items[end].repeats)) : (end += 1) {}
        var best = start;
        if (end > start + 1) {
            var best_price = offsetPrice(model, items[start].offset_value);
            for (start + 1..end) |slot| {
                const price = offsetPrice(model, items[slot].offset_value);
                if (price < best_price) {
                    best = slot;
                    best_price = price;
                }
            }
        }
        result |= @as(u8, 1) << @intCast(best);
        start = end;
    }
    return result;
}

inline fn sameRepeats(left: rep.Repeats, right: rep.Repeats) bool {
    return left[0] == right[0] and left[1] == right[1] and left[2] == right[2];
}

inline fn offsetPrice(model: *const prices.EntropyModel, offset: u32) u32 {
    std.debug.assert(offset != 0);
    const code = std.math.log2_int(u32, offset);
    const penalty = if (model.penalize_long_offsets and code >= 20) (code - 19) * 2 * prices.scale else 0;
    return model.of_prices[code] + code * prices.scale + penalty;
}

/// Compact caller-owned choices before enumeration, retaining original order.
/// Writes never reach an unread slot; each winner is copied before publication.
pub inline fn compact(choices: *rep.Choices, model: *const prices.EntropyModel) void {
    const mask = materializeMask(choices, model);
    const all = (@as(u8, 1) << @intCast(choices.len)) - 1;
    if (mask == all) return;
    var kept: usize = 0;
    for (0..choices.len) |slot| {
        if (mask & (@as(u8, 1) << @intCast(slot)) == 0) continue;
        choices.items[kept] = choices.items[slot];
        kept += 1;
    }
    choices.len = kept;
}
