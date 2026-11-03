//! Full old physical writer is the wire oracle; no candidate-cost formula is
//! repeated here. Borrowed model snapshots detect accidental baseline changes.
const std = @import("std");
const fixtures = @import("fixtures.zig");
const distance = @import("../distance.zig");

pub fn Guarded(comptime T: type) type {
    return struct {
        before: [17]u8 = @splat(0x91),
        value: T,
        after: [19]u8 = @splat(0x2b),

        pub fn check(self: *const @This()) !void {
            try std.testing.expectEqualSlices(u8, &@as([17]u8, @splat(0x91)), &self.before);
            try std.testing.expectEqualSlices(u8, &@as([19]u8, @splat(0x2b)), &self.after);
        }
    };
}

pub fn physical(comptime C: type, allocator: std.mem.Allocator, data: fixtures.Fixture, stats: *C.Stats, options: C.Options) ![]u8 {
    var cold = options;
    cold.prepared_common = null;
    cold.prepared_literal = null;
    return C.encode(allocator, data.input, data.commands, stats, cold);
}

/// The old physical baseline, original 64-shape chooser, physical alternative,
/// and strict local comparison are independent of the new counted controller.
pub fn LocalWinner(comptime C: type) type {
    return struct {
        baseline: []u8,
        alternate: ?[]u8,
        parameters: ?distance.Parameters,
        baseline_stats: C.Stats,
        alternate_stats: C.Stats,
        selected_alternate: bool,

        pub fn init(allocator: std.mem.Allocator, data: fixtures.Fixture, options: C.Options) !@This() {
            var base_stats = fixtures.stats(C.Stats, data);
            const base = try physical(C, allocator, data, &base_stats, options);
            errdefer allocator.free(base);
            const choice = try C.choose(allocator, data.commands, options);
            var alternate: ?[]u8 = null;
            var alternate_stats = fixtures.stats(C.Stats, data);
            if (choice) |parameters| {
                var alt_options = options;
                alt_options.distance_parameters = parameters;
                alt_options.optimize_same_last_distance = false;
                alternate = try physical(C, allocator, data, &alternate_stats, alt_options);
            }
            return .{
                .baseline = base,
                .alternate = alternate,
                .parameters = choice,
                .baseline_stats = base_stats,
                .alternate_stats = alternate_stats,
                .selected_alternate = if (alternate) |candidate| candidate.len < base.len else false,
            };
        }

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            allocator.free(self.baseline);
            if (self.alternate) |candidate| allocator.free(candidate);
        }
        pub fn wire(self: *const @This()) []const u8 {
            return if (self.selected_alternate) self.alternate.? else self.baseline;
        }
        pub fn stats(self: *const @This()) C.Stats {
            return if (self.selected_alternate) self.alternate_stats else self.baseline_stats;
        }
    };
}

pub fn Session(comptime C: type) type {
    return struct {
        const Self = @This();
        common: Guarded(C.Common),
        literal: Guarded(C.Literal),
        baseline_stats: C.Stats,
        baseline: []u8,
        physical_baseline: []u8,
        options: C.Options,
        input_before: []u8,
        commands_before: []fixtures.Command,

        pub fn init(self: *Self, allocator: std.mem.Allocator, data: fixtures.Fixture, requested: C.Options) !void {
            self.options = requested;
            self.options.distance_parameters = distance.Parameters.init(0, 0);
            self.options.use_recent_distances = true;
            self.options.optimize_same_last_distance = true;
            self.options.prepared_common = null;
            self.options.prepared_literal = null;
            self.input_before = try allocator.dupe(u8, data.input);
            errdefer allocator.free(self.input_before);
            self.commands_before = try allocator.dupe(fixtures.Command, data.commands);
            errdefer allocator.free(self.commands_before);
            var expected_stats = fixtures.stats(C.Stats, data);
            self.physical_baseline = try physical(C, allocator, data, &expected_stats, self.options);
            errdefer allocator.free(self.physical_baseline);
            self.common = .{ .value = C.Common.init(self.options, data.commands) };
            self.literal = .{ .value = .{} };
            var measured = fixtures.stats(C.Stats, data);
            const predicted = try C.prepareBase(allocator, data.input, data.commands, &measured, self.options, &self.common.value, &self.literal.value);
            try std.testing.expectEqual(self.physical_baseline.len, predicted);
            try std.testing.expectEqual(predicted, self.literal.value.wire_len);
            self.baseline = try C.emitBase(allocator, data.input, data.commands, &measured, self.options, &self.common.value, &self.literal.value);
            errdefer allocator.free(self.baseline);
            try std.testing.expectEqualSlices(u8, self.physical_baseline, self.baseline);
            try std.testing.expectEqualDeep(expected_stats, measured);
            self.baseline_stats = measured;
            try std.testing.expect(self.common.value.ready and self.literal.value.ready);
            try self.unchanged(data);
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.baseline);
            allocator.free(self.physical_baseline);
            allocator.free(self.input_before);
            allocator.free(self.commands_before);
        }

        pub fn altOptions(self: *const Self, parameters: distance.Parameters) C.Options {
            var options = self.options;
            options.distance_parameters = parameters;
            options.optimize_same_last_distance = false;
            return options;
        }

        pub fn candidate(self: *Self, allocator: std.mem.Allocator, data: fixtures.Fixture, parameters: distance.Parameters) !void {
            errdefer std.debug.print("parameter_pair bytes={d} commands={d} postfix={d} direct={d}\n", .{ data.input.len, data.commands.len, parameters.npostfix, parameters.ndirect_high });
            const options = self.altOptions(parameters);
            var expected_stats = fixtures.stats(C.Stats, data);
            const expected = try physical(C, allocator, data, &expected_stats, options);
            defer allocator.free(expected);
            const common_key = self.common.value.key;
            const common_extra = self.common.value.payload_extra_bits;
            const command_frequencies = self.common.value.command_frequencies;
            const command_lengths = self.common.value.command_lengths;
            const distance_frequencies = self.common.value.distance_frequencies;
            const distance_lengths = self.common.value.distance_lengths;
            const literal_key = self.literal.value.key;
            const literal_payload = self.literal.value.payload_bits;
            const literal_header = self.literal.value.header_bits;
            const literal_wire = self.literal.value.wire_len;
            var state: Guarded(C.State) = .{ .value = .{} };
            const initial = fixtures.stats(C.Stats, data);
            var measured = initial;
            const predicted = try C.prepareAlt(allocator, data.input, data.commands, &measured, options, &self.common.value, &self.literal.value, &state.value);
            try std.testing.expectEqual(expected.len, predicted);
            try std.testing.expectEqual(predicted, state.value.wire_len);
            try std.testing.expect(state.value.matches(data.input, data.commands, options));
            try std.testing.expect(state.value.commandPlan() == &self.common.value);
            try std.testing.expect(state.value.literalModels() == &self.literal.value);
            try std.testing.expect(state.value.distancePlan() == &state.value);
            try std.testing.expect(self.literal.value.matches(data.input, options));
            if (parameters.npostfix == 3 and parameters.ndirect_high == 15) {
                const has_deep = for (data.commands) |item| {
                    if (item.has_copy and item.distance >= 120) break true;
                } else false;
                if (has_deep) {
                    const crosses_79 = for (state.value.distance_alphabet.symbols[0..state.value.distance_alphabet.len]) |symbol| {
                        if (symbol >= 79) break true;
                    } else false;
                    try std.testing.expect(crosses_79);
                }
            }
            inline for (@typeInfo(C.Stats).@"struct".fields) |field| {
                const symbol_count = comptime std.mem.eql(u8, field.name, "literal_symbol_count") or std.mem.eql(u8, field.name, "command_symbol_count") or std.mem.eql(u8, field.name, "distance_symbol_count");
                try std.testing.expectEqual(@field(if (symbol_count) expected_stats else initial, field.name), @field(measured, field.name));
            }
            const actual = try C.emitAlt(allocator, data.input, data.commands, &measured, options, &self.common.value, &self.literal.value, &state.value);
            defer allocator.free(actual);
            try std.testing.expectEqualSlices(u8, expected, actual);
            try std.testing.expectEqualDeep(expected_stats, measured);
            if (parameters.npostfix == 0 and parameters.ndirect_high == 0) {
                try std.testing.expectEqualSlices(u8, self.baseline, actual);
                try std.testing.expectEqualDeep(self.baseline_stats, measured);
            }
            try std.testing.expectEqualDeep(common_key, self.common.value.key);
            try std.testing.expectEqual(common_extra, self.common.value.payload_extra_bits);
            try std.testing.expectEqualSlices(u32, &command_frequencies, &self.common.value.command_frequencies);
            try std.testing.expectEqualSlices(u4, &command_lengths, &self.common.value.command_lengths);
            try std.testing.expectEqualSlices(u32, &distance_frequencies, &self.common.value.distance_frequencies);
            try std.testing.expectEqualSlices(u4, &distance_lengths, &self.common.value.distance_lengths);
            try std.testing.expectEqualDeep(literal_key, self.literal.value.key);
            try std.testing.expectEqual(literal_payload, self.literal.value.payload_bits);
            try std.testing.expectEqual(literal_header, self.literal.value.header_bits);
            try std.testing.expectEqual(literal_wire, self.literal.value.wire_len);
            try state.check();
            try self.unchanged(data);
        }

        pub fn unchanged(self: *const Self, data: fixtures.Fixture) !void {
            try self.common.check();
            try self.literal.check();
            try data.checkGuards();
            try std.testing.expectEqualSlices(u8, self.input_before, data.input);
            for (self.commands_before, data.commands) |before, after| try std.testing.expectEqualDeep(before, after);
        }
    };
}
