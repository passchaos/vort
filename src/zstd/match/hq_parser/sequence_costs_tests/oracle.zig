const std = @import("std");
pub const Old = @import("../prices_known_ml_reference.zig");

/// Freeze every field, including non-price distributions and provenance.
pub fn freeze(comptime Prices: type, model: Prices.EntropyModel) Old.EntropyModel {
    var result: Old.EntropyModel = .{};
    inline for (comptime std.meta.fieldNames(Prices.EntropyModel)) |field| {
        if (comptime std.mem.eql(u8, field, "origin")) {
            result.origin = @enumFromInt(@intFromEnum(model.origin));
        } else @field(result, field) = @field(model, field);
    }
    return result;
}

pub fn verifyMapping(comptime Prices: type, model: Prices.EntropyModel) !void {
    const old = freeze(Prices, model);
    inline for (comptime std.meta.fieldNames(Prices.EntropyModel)) |field| {
        if (comptime std.mem.eql(u8, field, "origin")) {
            try std.testing.expectEqual(@intFromEnum(model.origin), @intFromEnum(old.origin));
        } else try std.testing.expectEqualDeep(@field(model, field), @field(old, field));
    }
}
