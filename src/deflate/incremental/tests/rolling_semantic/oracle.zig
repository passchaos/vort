const std = @import("std");
const core = @import("../../../../core.zig");
const decoder = @import("../../decoder/fixed_literals.zig");
const capacity: usize = 65536;
const window: usize = 32768;
pub const Linear = decoder.DecoderWithMode(.{}, .linear, false);
pub const Rolling = decoder.DecoderWithMode(.{}, .rolling, false);
const ObservedLinear = decoder.DecoderWithMode(.{}, .linear, true);
const ObservedRolling = decoder.DecoderWithMode(.{}, .rolling, true);
pub const Options = Linear.Options;
pub const Outcome = union(enum) { step: core.StepResult, failure: core.Error };

const Guarded = struct {
    before: [17]u8 = @splat(0x3d),
    bytes: [capacity]u8 = @splat(0xc7),
    after: [19]u8 = @splat(0xa9),

    fn check(self: *const Guarded) !void {
        try std.testing.expectEqualSlices(u8, &@as([17]u8, @splat(0x3d)), &self.before);
        try std.testing.expectEqualSlices(u8, &@as([19]u8, @splat(0xa9)), &self.after);
    }
};

const members = .{
    .{ "linear", "linear_history", "linear_workspace" },
    .{ "rolling", "rolling_history", "rolling_workspace" },
    .{ "observed_linear", "observed_linear_history", "observed_linear_workspace" },
    .{ "observed_rolling", "observed_rolling_history", "observed_rolling_workspace" },
};

pub const Rig = struct {
    linear: Linear,
    rolling: Rolling,
    observed_linear: ObservedLinear,
    observed_rolling: ObservedRolling,
    linear_history: Guarded,
    rolling_history: Guarded,
    observed_linear_history: Guarded,
    observed_rolling_history: Guarded,
    linear_workspace: Linear.SemanticWorkspace,
    rolling_workspace: Rolling.SemanticWorkspace,
    observed_linear_workspace: ObservedLinear.SemanticWorkspace,
    observed_rolling_workspace: ObservedRolling.SemanticWorkspace,

    pub fn init(self: *Rig, options: Options, dictionary: []const u8) !void {
        inline for (members) |member| {
            @field(self, member[1]) = .{};
            const T = @TypeOf(@field(self, member[0]));
            @field(self, member[0]) = try T.initWithDictionary(.{
                .max_output_len = options.max_output_len,
                .expected_output_len = options.expected_output_len,
                .allow_trailing_data = options.allow_trailing_data,
                .stop_at_output_limit = options.stop_at_output_limit,
                .max_distance = options.max_distance,
            }, &@field(self, member[1]).bytes, dictionary);
            try @field(self, member[0]).attachSemanticWorkspace(&@field(self, member[2]));
        }
    }

    pub fn reset(self: *Rig, dictionary: []const u8) !void {
        inline for (members) |member| {
            const current = &@field(self, member[0]);
            current.reset();
            try std.testing.expect(current.semantic_decoder == &@field(self, member[2]));
            current.seedDictionary(dictionary);
            try std.testing.expectEqual(@as(usize, 0), current.semanticBlocksStarted());
            try std.testing.expectEqualDeep(decoder.SemanticWork{}, current.semanticWork());
        }
    }

    pub fn invoke(self: *Rig, input: []const u8, output_capacity: usize, dictionary: []const u8, payload: []const u8) !Outcome {
        std.debug.assert(output_capacity <= 4096);
        var outputs: [4][4098]u8 = @splat(@splat(0x72));
        var outcomes: [4]Outcome = undefined;
        const before_output = self.linear.total_output;
        inline for (members, 0..) |member, index| {
            outcomes[index] = capture(&@field(self, member[0]), input, outputs[index][1 .. 1 + output_capacity]);
            if (index != 0) try std.testing.expectEqualDeep(outcomes[0], outcomes[index]);
        }
        const written = self.linear.total_output - before_output;
        try std.testing.expect(written <= output_capacity);
        try std.testing.expect(before_output + written <= payload.len);
        inline for (members, 0..) |member, index| {
            try std.testing.expectEqualSlices(u8, payload[before_output..][0..written], outputs[index][1 .. 1 + written]);
            try std.testing.expectEqual(@as(u8, 0x72), outputs[index][0]);
            for (outputs[index][1 + written ..]) |byte| try std.testing.expectEqual(@as(u8, 0x72), byte);
            try @field(self, member[1]).check();
            if (index != 0) try compareState(&self.linear, &@field(self, member[0]));
        }
        try self.checkLogical(dictionary, payload);
        const linear_work = self.observed_linear.semanticWork();
        const rolling_work = self.observed_rolling.semanticWork();
        inline for (.{ "generated_bytes", "delivered_bytes", "discarded_bytes" }) |name| {
            try std.testing.expectEqual(@field(linear_work, name), @field(rolling_work, name));
        }
        try std.testing.expectEqualDeep(decoder.SemanticWork{}, self.linear.semanticWork());
        try std.testing.expectEqualDeep(decoder.SemanticWork{}, self.rolling.semanticWork());
        return outcomes[0];
    }

    pub fn finish(self: *Rig, dictionary: []const u8, payload: []const u8) !?core.Error {
        var errors: [4]?core.Error = @splat(null);
        inline for (members, 0..) |member, index| {
            @field(self, member[0]).finish() catch |err| {
                errors[index] = err;
            };
            if (index != 0) {
                try std.testing.expectEqual(errors[0], errors[index]);
                try compareState(&self.linear, &@field(self, member[0]));
            }
            try @field(self, member[1]).check();
        }
        try self.checkLogical(dictionary, payload);
        return errors[0];
    }

    fn checkLogical(self: *const Rig, dictionary: []const u8, payload: []const u8) !void {
        const current = &self.linear;
        if (current.phase == .fast_dynamic_block) {
            const initialized = current.semantic_generated_end;
            inline for (members, 0..) |member, index| {
                if (index != 0) try expectLogical(&@field(self, member[0]), 0, current.semantic_scratch[0..initialized]);
            }
            const published = current.semantic_delivered - current.semantic_prefix_len;
            const generation_start = current.total_output - published;
            var prefix: [window]u8 = undefined;
            historyBytes(prefix[0..current.semantic_prefix_len], dictionary, payload, generation_start);
            inline for (members) |member| {
                const candidate = &@field(self, member[0]);
                try expectLogical(candidate, 0, prefix[0..current.semantic_prefix_len]);
                const generated = current.semantic_generated_end - current.semantic_prefix_len;
                try std.testing.expect(generation_start + generated <= payload.len);
                try expectLogical(candidate, current.semantic_prefix_len, payload[generation_start..][0..generated]);
            }
        }
        const retained = if (current.phase == .fast_dynamic_block)
            @min(window, current.semantic_delivered)
        else
            current.history_len;
        var latest: [window]u8 = undefined;
        historyBytes(latest[0..retained], dictionary, payload, current.total_output);
        inline for (members) |member| {
            const candidate = &@field(self, member[0]);
            if (candidate.phase == .fast_dynamic_block) {
                try expectLogical(candidate, candidate.semantic_delivered - retained, latest[0..retained]);
            } else {
                try std.testing.expectEqual(retained, candidate.history_len);
                const source = if (retained == window) candidate.history_pos else 0;
                const first = @min(retained, window - source);
                try std.testing.expectEqualSlices(u8, latest[0..first], candidate.history[source..][0..first]);
                try std.testing.expectEqualSlices(u8, latest[first..retained], candidate.history[0 .. retained - first]);
            }
        }
    }
};

fn capture(current: anytype, input: []const u8, output: []u8) Outcome {
    return if (current.step(input, output)) |result| .{ .step = result } else |err| .{ .failure = err };
}

fn compareState(expected: anytype, actual: anytype) !void {
    try std.testing.expectEqualStrings(@tagName(expected.phase), @tagName(actual.phase));
    try std.testing.expectEqualStrings(@tagName(expected.last_error_phase), @tagName(actual.last_error_phase));
    try std.testing.expectEqualDeep(expected.diagnostics(), actual.diagnostics());
    inline for (.{
        "bit_buffer",             "bit_count",               "code",
        "code_bits",              "final_block",             "length_base",
        "length_extra_bits",      "distance_code",           "distance_code_bits",
        "match_len",              "match_remaining",         "match_distance",
        "stored_length_received", "stored_remaining",        "dynamic_hlit",
        "dynamic_hdist",          "dynamic_hclen",           "dynamic_code_length_index",
        "dynamic_length_pos",     "dynamic_previous_length", "dynamic_repeat_symbol",
        "dynamic_code",           "dynamic_code_bits",       "dynamic_block",
        "input_finished",         "total_input",             "total_output",
        "semantic_prefix_len",    "semantic_generated_end",  "semantic_delivered",
        "semantic_end_of_block",  "semantic_blocks_started", "semantic_blocks_completed",
    }) |name| try std.testing.expectEqual(@field(expected, name), @field(actual, name));
    try std.testing.expectEqualSlices(u8, expected.stored_lengths[0..expected.stored_length_received], actual.stored_lengths[0..actual.stored_length_received]);
    try std.testing.expectEqualSlices(u4, &expected.dynamic_code_lengths, &actual.dynamic_code_lengths);
    try std.testing.expectEqualSlices(u4, &expected.dynamic_literal_lengths, &actual.dynamic_literal_lengths);
    try std.testing.expectEqualSlices(u4, &expected.dynamic_distance_lengths, &actual.dynamic_distance_lengths);
}

fn expectLogical(current: anytype, start: usize, expected: []const u8) !void {
    if (expected.len == 0) return;
    const source = (current.semantic_prefix_start + start) % capacity;
    const first = @min(expected.len, capacity - source);
    try std.testing.expectEqualSlices(u8, expected[0..first], current.semantic_scratch[source..][0..first]);
    try std.testing.expectEqualSlices(u8, expected[first..], current.semantic_scratch[0 .. expected.len - first]);
}

fn historyBytes(output: []u8, dictionary: []const u8, payload: []const u8, published: usize) void {
    const start = dictionary.len + published - output.len;
    for (output, 0..) |*byte, offset| {
        const position = start + offset;
        byte.* = if (position < dictionary.len) dictionary[position] else payload[position - dictionary.len];
    }
}
