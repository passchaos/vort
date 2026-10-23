const std = @import("std");
const limits = @import("../encode_options.zig");

pub const max_records: usize = 10000;
pub const max_literals: usize = 40000;
pub const Error = std.mem.Allocator.Error || error{ InvalidLzfseStream, BlockPlanLimitExceeded };
pub const Record = struct {
    literal_len: u16,
    match_len: u16,
    /// Real positive distance; the wire serializer owns repeat-distance D=0.
    /// Literal-only records use the canonical dummy distance 1.
    distance: u32,
};

pub const Plan = struct {
    records: std.ArrayList(Record) = .empty,
    /// Unpadded literal bytes in record order. The serializer pads to four.
    literals: std.ArrayList(u8) = .empty,
    raw_size: usize = 0,
    history_len: usize,

    pub fn init(history_len: usize) Plan {
        return .{ .history_len = history_len };
    }

    pub fn deinit(self: *Plan, allocator: std.mem.Allocator) void {
        self.records.deinit(allocator);
        self.literals.deinit(allocator);
        self.* = undefined;
    }

    pub fn validate(self: Plan) Error!void {
        if (self.records.items.len > max_records or self.literals.items.len > max_literals or
            self.raw_size > limits.max_plan_raw_size) return error.BlockPlanLimitExceeded;
        if (self.records.items.len == 0 or self.raw_size == 0) return error.InvalidLzfseStream;
        var raw_size: usize = 0;
        var literal_count: usize = 0;
        for (self.records.items) |record| {
            if (record.literal_len > limits.max_literal_length or record.match_len > limits.max_match_length or
                (record.literal_len == 0 and record.match_len == 0) or record.distance == 0 or
                record.distance > limits.max_distance or (record.match_len == 0 and record.distance != 1))
                return error.InvalidLzfseStream;
            raw_size += record.literal_len;
            literal_count += record.literal_len;
            if (record.match_len != 0 and record.distance > raw_size and
                record.distance - raw_size > self.history_len) return error.InvalidLzfseStream;
            raw_size += record.match_len;
        }
        if (raw_size != self.raw_size or literal_count != self.literals.items.len)
            return error.InvalidLzfseStream;
    }

    /// Append literals followed by a match, splitting both into legal L/M
    /// records. Failures preserve logical records, literals and raw progress.
    pub fn append(self: *Plan, allocator: std.mem.Allocator, literals: []const u8, match_len: usize, distance: u32) Error!void {
        if ((literals.len == 0 and match_len == 0) or distance == 0 or distance > limits.max_distance or
            (match_len == 0 and distance != 1) or self.records.items.len > max_records or
            self.literals.items.len > max_literals or self.raw_size > limits.max_plan_raw_size)
            return error.InvalidLzfseStream;
        if (literals.len > max_literals - self.literals.items.len or
            match_len > limits.max_plan_raw_size - self.raw_size or
            literals.len > limits.max_plan_raw_size - self.raw_size - match_len)
            return error.BlockPlanLimitExceeded;
        const match_records = match_len / limits.max_match_length + @intFromBool(match_len % limits.max_match_length != 0);
        const literal_records = if (match_len == 0)
            literals.len / limits.max_literal_length + @intFromBool(literals.len % limits.max_literal_length != 0)
        else if (literals.len == 0) 0 else (literals.len - 1) / limits.max_literal_length;
        if (match_records > max_records - self.records.items.len or
            literal_records > max_records - self.records.items.len - match_records)
            return error.BlockPlanLimitExceeded;
        const before_match = self.raw_size + literals.len;
        if (match_len != 0 and distance > before_match and distance - before_match > self.history_len)
            return error.InvalidLzfseStream;

        try self.records.ensureUnusedCapacity(allocator, match_records + literal_records);
        try self.literals.ensureUnusedCapacity(allocator, literals.len);
        self.literals.appendSliceAssumeCapacity(literals);
        var literal_remaining = literals.len;
        while (literal_remaining > limits.max_literal_length) {
            self.records.appendAssumeCapacity(.{ .literal_len = limits.max_literal_length, .match_len = 0, .distance = 1 });
            literal_remaining -= limits.max_literal_length;
        }
        var match_remaining = match_len;
        if (literal_remaining != 0 or match_remaining != 0) {
            const length = @min(match_remaining, limits.max_match_length);
            self.records.appendAssumeCapacity(.{
                .literal_len = @intCast(literal_remaining),
                .match_len = @intCast(length),
                .distance = if (length == 0) 1 else distance,
            });
            match_remaining -= length;
        }
        while (match_remaining != 0) {
            const length = @min(match_remaining, limits.max_match_length);
            self.records.appendAssumeCapacity(.{ .literal_len = 0, .match_len = @intCast(length), .distance = distance });
            match_remaining -= length;
        }
        self.raw_size += literals.len + match_len;
    }

    pub fn appendLiterals(self: *Plan, allocator: std.mem.Allocator, literals: []const u8) Error!void {
        return self.append(allocator, literals, 0, 1);
    }
};

test {
    _ = @import("block_plan_tests.zig");
}
