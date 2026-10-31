//! Test bindings keep private encoder operations out of the public API.
const std = @import("std");
const distance = @import("../distance.zig");
const projection = @import("../symbol_projection.zig");

pub fn Support(comptime S: type) type {
    return struct {
        pub const decodeStreamAllocExactSize = S.decode;
        pub const decodeStreamAllocExactSizeWithOptions = S.decodeOptions;
        pub const summarizeStreamAlloc = S.summarize;
        pub const SymbolProjectionTestSupport = struct {
            pub const Command = S.Command;
            pub const Context = S.Context;
            pub const Split = S.Split;
            pub const Splits = S.Splits;
            pub fn project(command: Command, use_recent: bool, context: Context, repeats: [4]usize) S.Error!projection.Step {
                return projection.project(S.ProjectionStrategy, command, use_recent, context, repeats);
            }
            pub fn choose(a: std.mem.Allocator, commands: []const Command, context: Context) S.Error!Splits {
                return S.choose(a, commands, true, true, true, true, true, context);
            }
            pub const deinit = S.deinitSplits;
            fn options(context: Context, commands: ?*const Split, distances: ?*const Split) S.Options {
                return .{
                    .use_recent_distances = true,
                    .optimize_same_last_distance = false,
                    .adaptive_command_split = commands,
                    .adaptive_distance_split = distances,
                    .distance_parameters = distance.Parameters.init(0, 15),
                    .large_window = context.large_window,
                    .window_bits = context.window_bits,
                    .compound_dictionary_size = context.compound_dictionary_size,
                    .initial_output_pos = context.initial_output_pos,
                    .starting_last_distances = context.starting_last_distances,
                };
            }
            pub fn write(a: std.mem.Allocator, input: []const u8, commands: []const Command, context: Context, command_split: ?*const Split, distance_split: ?*const Split) S.Error![]u8 {
                var stats: S.Stats = .{};
                return S.write(a, input, commands, null, &stats, options(context, command_split, distance_split));
            }
            pub fn writeInto(a: std.mem.Allocator, output: []u8, input: []const u8, commands: []const Command, context: Context, command_split: ?*const Split, distance_split: ?*const Split) S.Error!usize {
                var stats: S.Stats = .{};
                return S.writeInto(a, output, input, commands, &stats, options(context, command_split, distance_split));
            }
        };
        pub const ExactPreparedTestSupport = struct {
            pub const Options = S.Options;
            pub const Common = S.Common;
            pub const Literal = S.Literal;
            pub const Stats = S.Stats;
            pub const Command = S.Command;
            pub const wireDistance = S.wireDistance;
            pub const resolve = S.resolve;
            pub const write = S.write;
            pub const writeInto = S.writeInto;
            pub fn capture(a: std.mem.Allocator, input: []const u8, commands: []const Command, options: Options, state: *Literal) S.Error!void {
                var stats: Stats = .{};
                _ = try S.prepare(false, .{}, a, input, commands, null, &stats, options, state);
            }
            pub fn emit(a: std.mem.Allocator, input: []const u8, commands: []const Command, options: Options, state: *const Literal) S.Error![]u8 {
                var stats: Stats = .{};
                return S.emit(false, .{}, a, input, commands, null, &stats, options, state, .{ .bytes = state.wire_len });
            }
        };
    };
}
