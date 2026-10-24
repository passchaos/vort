const std = @import("std");
const types = @import("fast_cover_optimize/types.zig");
const engine = @import("fast_cover_optimize/engine.zig");
const grid = @import("fast_cover_optimize/grid.zig");

pub const OptimizeOptions = types.OptimizeOptions;
pub const Score = types.Score;
pub const Profile = types.Profile;
pub const OwnedResult = types.OwnedResult;
pub const SplitPoint = types.SplitPoint;
pub const Partitions = types.Partitions;
pub const splitSamples = grid.splitSamples;
pub const validateParameters = grid.validateParameters;

/// Managed scorer lifetime covers the complete operation. Scorer must expose:
/// init(operation_allocator, init_context, training, validation, options),
/// score(self, content, validation, min_match_len, candidate TrainOptions), and
/// deinit(self). Each worker gets independent mutable state. Optional
/// mergeProfile(self, init_context) runs on the coordinator after all joins.
/// Optional accepts(self, content) rejects unusable content before scoring.
/// Optional worker_stack_size declares the scorer's required native stack;
/// its full requested size is reserved against the operation working budget.
/// All scorer scratch must use operation_allocator; returned content is freed
/// by the original caller allocator. No allocator/context pointer escapes.
pub fn trainAllocWithScorerFactory(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: OptimizeOptions,
    init_context: anytype,
    comptime Scorer: type,
) !OwnedResult {
    return engine.train(allocator, training_samples, validation_samples, options, init_context, Scorer);
}

/// Borrowed, allocation-free callback convenience. For reusable codec scratch
/// and complete working-memory accounting use trainAllocWithScorerFactory.
/// scoreFn(context, content, validation, min_match_len, candidate_options).
pub fn trainAllocWithScorerContext(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: OptimizeOptions,
    context: anytype,
    comptime scoreFn: anytype,
) !OwnedResult {
    if (options.threads != 1) return error.InvalidDictionaryTraining;
    const Adapter = struct {
        value: @TypeOf(context),
        pub fn init(_: std.mem.Allocator, value: @TypeOf(context), _: []const []const u8, _: []const []const u8, _: OptimizeOptions) !@This() {
            return .{ .value = value };
        }
        pub fn score(self: *@This(), content: []const u8, validation: []const []const u8, minimum: usize, candidate: @import("fast_cover.zig").TrainOptions) !Score {
            return normalizeScore(try scoreFn(self.value, content, validation, minimum, candidate));
        }
        pub fn deinit(_: *@This()) void {}
    };
    return trainAllocWithScorerFactory(allocator, training_samples, validation_samples, options, context, Adapter);
}

pub fn trainAllocWithScorer(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: OptimizeOptions,
    comptime scoreFn: anytype,
) !OwnedResult {
    const Adapter = struct {
        fn score(_: void, content: []const u8, validation: []const []const u8, minimum: usize, _: @import("fast_cover.zig").TrainOptions) !Score {
            return normalizeScore(try scoreFn(content, validation, minimum));
        }
    };
    return trainAllocWithScorerContext(allocator, training_samples, validation_samples, options, {}, Adapter.score);
}

pub fn trainSplitAllocWithScorerFactory(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    split: SplitPoint,
    options: OptimizeOptions,
    init_context: anytype,
    comptime Scorer: type,
) !OwnedResult {
    const partitions = try splitSamples(samples, split);
    return trainAllocWithScorerFactory(allocator, partitions.training, partitions.validation, options, init_context, Scorer);
}

fn normalizeScore(value: anytype) Score {
    return .{
        .estimated_bits = value.estimated_bits,
        .covered_bytes = value.covered_bytes,
        .matches = value.matches,
        .distance_bits = value.distance_bits,
        .dictionary_bytes = if (@hasField(@TypeOf(value), "dictionary_bytes")) value.dictionary_bytes else null,
    };
}
