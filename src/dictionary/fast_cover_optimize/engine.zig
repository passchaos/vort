const std = @import("std");
const builtin = @import("builtin");
const fast = @import("../fast_cover.zig");
const types = @import("types.zig");
const grid_mod = @import("grid.zig");
const memory = @import("memory.zig");
const default_thread_stack_bytes = 2 * 1024 * 1024;
// Zig 0.16's WASI multi-threaded runtime is not yet usable with this public
// synchronous interface; preserve the complete deterministic serial search.
const thread_capable = !builtin.single_threaded and (builtin.os.tag == .linux or builtin.os.tag == .windows or std.Thread.use_pthreads);
const allocator_owned_stacks = builtin.os.tag == .wasi;

const Variant = struct { size: usize, score: types.Score };
fn Job(comptime Failure: type) type {
    return struct {
        bytes: ?[]u8 = null,
        variants: [types.maximum_variants]Variant = undefined,
        variant_count: usize = 0,
        failure: ?Failure = null,
        training: fast.Profile = .{},
        scoring_calls: usize = 0,
        shrink_evaluations: usize = 0,
    };
}

fn functionErrors(comptime Function: type) type {
    const Return = @typeInfo(Function).@"fn".return_type.?;
    return switch (@typeInfo(Return)) {
        .error_union => |value| value.error_set,
        else => error{},
    };
}

pub fn train(
    allocator: std.mem.Allocator,
    training_samples: []const []const u8,
    validation_samples: []const []const u8,
    options: types.OptimizeOptions,
    init_context: anytype,
    comptime Scorer: type,
) !types.OwnedResult {
    const thread_stack_bytes: usize = if (@hasDecl(Scorer, "worker_stack_size")) Scorer.worker_stack_size else default_thread_stack_bytes;
    if (thread_stack_bytes < 64 * 1024) return error.InvalidDictionaryTraining;
    const Failure = error{ InvalidDictionaryTraining, WorkingMemoryLimitExceeded, OutOfMemory } || functionErrors(@TypeOf(Scorer.init)) || functionErrors(@TypeOf(Scorer.score));
    const CandidateJob = Job(Failure);
    const candidates = try grid_mod.build(options);
    const corpus_bytes = try grid_mod.validateCorpus(training_samples, validation_samples, options);
    var budget = memory.Budget.init(allocator, options.max_working_memory);
    var coordinator = memory.Slot{ .budget = &budget };
    const operation_allocator = coordinator.allocator();
    var profile = types.Profile{ .available = true, .training_samples = training_samples.len, .validation_samples = validation_samples.len, .corpus_bytes = corpus_bytes };
    profile.add("candidate_grid_points", candidates.len);
    defer {
        profile.peak_working_memory = budget.state.peak;
        profile.peak_allocator_owned_bytes = budget.heap_peak;
        profile.thread_stack_reservation_peak = budget.stack_peak;
        if (options.profile) |caller| caller.merge(profile);
    }
    var jobs: [types.maximum_candidates]CandidateJob = @splat(.{});
    defer for (jobs[0..candidates.len]) |job| if (job.bytes) |bytes| operation_allocator.free(bytes);

    const Worker = struct {
        slot: memory.Slot,
        scorer: Scorer = undefined,
        scorer_ready: bool = false,
        owned_prepared: fast.Prepared = .{},
        prepared: *fast.Prepared = undefined,
        candidates: []const grid_mod.Candidate = &.{},
        jobs: []CandidateJob = &.{},
        validation: []const []const u8 = &.{},
        options: types.OptimizeOptions,
        index: usize = 0,
        count: usize = 1,

        fn run(self: *@This()) void {
            var index = self.index;
            while (index < self.candidates.len) : (index += self.count) {
                self.evaluate(index) catch |err| {
                    self.jobs[index].failure = self.slot.mapError(err);
                    if (@hasDecl(Scorer, "resetAfterError")) self.scorer.resetAfterError();
                };
            }
        }
        fn evaluate(self: *@This(), index: usize) !void {
            const job = &self.jobs[index];
            var candidate = self.candidates[index].options;
            candidate.profile = &job.training;
            const content = try self.prepared.trainAlloc(self.slot.allocator(), candidate);
            job.bytes = content;
            candidate.profile = null;
            if (@hasDecl(Scorer, "accepts")) if (!self.scorer.accepts(content)) return;
            job.scoring_calls += 1;
            job.variants[0] = .{ .size = content.len, .score = normalizeScore(try self.scorer.score(content, self.validation, self.options.min_match_len, candidate)) };
            job.variant_count = 1;
            var sizes: [types.maximum_variants]usize = undefined;
            const size_count = grid_mod.shrinkSizes(content.len, self.options, &sizes);
            for (sizes[0..size_count]) |size| {
                const suffix = content[content.len - size ..];
                if (@hasDecl(Scorer, "accepts")) if (!self.scorer.accepts(suffix)) continue;
                job.scoring_calls += 1;
                job.shrink_evaluations += 1;
                const score = normalizeScore(try self.scorer.score(suffix, self.validation, self.options.min_match_len, candidate));
                job.variants[job.variant_count] = .{ .size = size, .score = score };
                job.variant_count += 1;
            }
        }
    };

    var maximum_group: usize = 1;
    var start: usize = 0;
    while (start < candidates.len) {
        var end = start + 1;
        while (end < candidates.len and grid_mod.sameGroup(candidates.candidates[start], candidates.candidates[end])) : (end += 1) {}
        maximum_group = @max(maximum_group, end - start);
        start = end;
    }
    const worker_count = if (thread_capable) @min(options.threads, maximum_group) else 1;
    var workers: [types.maximum_threads]Worker = undefined;
    for (workers[0..worker_count]) |*worker| worker.* = .{ .slot = .{ .budget = &budget }, .options = options };
    defer for (workers[0..worker_count]) |*worker| {
        worker.owned_prepared.deinit(operation_allocator);
        if (worker.scorer_ready) {
            if (@hasDecl(Scorer, "mergeProfile")) worker.scorer.mergeProfile(init_context);
            worker.scorer.deinit();
        }
    };
    var scorer_options = options;
    scorer_options.profile = null;
    for (workers[0..worker_count]) |*worker| {
        worker.scorer = Scorer.init(worker.slot.allocator(), init_context, training_samples, validation_samples, scorer_options) catch |err| return worker.slot.mapError(err);
        worker.scorer_ready = true;
    }

    start = 0;
    while (start < candidates.len) {
        var end = start + 1;
        while (end < candidates.len and grid_mod.sameGroup(candidates.candidates[start], candidates.candidates[end])) : (end += 1) {}
        var prepared_profile = fast.Profile{};
        var prepare_options = candidates.candidates[start].options;
        prepare_options.profile = &prepared_profile;
        var prepared = fast.Prepared.init(operation_allocator, training_samples, prepare_options) catch |err| return coordinator.mapError(err);
        defer prepared.deinit(operation_allocator);
        profile.training.merge(prepared_profile);
        profile.add("prepared_groups", 1);
        const count = @min(worker_count, end - start);
        for (workers[0..count], 0..) |*worker, index| {
            worker.owned_prepared.deinit(operation_allocator);
            if (count == 1) {
                worker.prepared = &prepared;
            } else {
                worker.owned_prepared = prepared.fork(worker.slot.allocator(), options.max_working_memory) catch |err| return worker.slot.mapError(err);
                worker.prepared = &worker.owned_prepared;
                profile.training.merge(worker.owned_prepared.profile);
            }
            worker.candidates = candidates.candidates[start..end];
            worker.jobs = jobs[start..end];
            worker.validation = validation_samples;
            worker.index = index;
            worker.count = count;
        }
        var threads: if (thread_capable) [types.maximum_threads - 1]?std.Thread else [0]u8 = if (thread_capable) @splat(null) else .{};
        var spawned: usize = 0;
        if (thread_capable) for (1..count) |index| {
            if (!allocator_owned_stacks and !coordinator.reserveStack(thread_stack_bytes)) {
                profile.add("thread_spawn_fallbacks", 1);
                workers[index].run();
                continue;
            }
            threads[index - 1] = std.Thread.spawn(.{ .stack_size = thread_stack_bytes, .allocator = if (allocator_owned_stacks) operation_allocator else null }, Worker.run, .{&workers[index]}) catch {
                if (!allocator_owned_stacks) coordinator.releaseStack(thread_stack_bytes);
                profile.add("thread_spawn_fallbacks", 1);
                workers[index].run();
                continue;
            };
            spawned += 1;
        };
        workers[0].run();
        if (thread_capable) for (threads[0 .. count - 1]) |thread| if (thread) |value| {
            value.join();
            if (!allocator_owned_stacks) coordinator.releaseStack(thread_stack_bytes);
        };
        profile.threads_used = @max(profile.threads_used, spawned + 1);
        var failure: ?Failure = null;
        for (jobs[start..end]) |job| {
            profile.training.merge(job.training);
            profile.add("scoring_calls", job.scoring_calls);
            profile.add("shrink_evaluations", job.shrink_evaluations);
            if (job.failure) |err| {
                if (failure == null) failure = err;
            } else profile.add("candidates_evaluated", 1);
        }
        if (failure) |err| return err;
        for (workers[0..count]) |*worker| worker.owned_prepared.deinit(operation_allocator);
        start = end;
    }

    var best_full_optional: ?usize = null;
    for (jobs[0..candidates.len], 0..) |job, index| {
        if (job.variant_count == 0) continue;
        if (best_full_optional == null or better(job.variants[0], jobs[best_full_optional.?].variants[0], index, best_full_optional.?)) best_full_optional = index;
    }
    const best_full = best_full_optional orelse return error.InvalidDictionaryTraining;
    var selected_job = best_full;
    var selected_variant: usize = 0;
    if (options.shrink_dictionary) {
        const baseline = jobs[best_full].variants[0].score.estimated_bits;
        for (jobs[0..candidates.len], 0..) |job, index| {
            for (job.variants[0..job.variant_count], 0..) |variant, vi| {
                if (@as(u128, variant.score.estimated_bits) * 10000 > @as(u128, baseline) * (10000 + @as(u128, options.regression_tolerance_bps))) continue;
                const current = jobs[selected_job].variants[selected_variant];
                const charge = charged(variant);
                const current_charge = charged(current);
                if (charge < current_charge or (charge == current_charge and better(variant, current, index, selected_job))) {
                    selected_job = index;
                    selected_variant = vi;
                }
            }
        }
    }
    const chosen = jobs[selected_job].variants[selected_variant];
    const original_size = jobs[selected_job].bytes.?.len;
    const output = if (chosen.size == original_size) blk: {
        const transferred = jobs[selected_job].bytes.?;
        jobs[selected_job].bytes = null;
        break :blk transferred;
    } else operation_allocator.dupe(u8, jobs[selected_job].bytes.?[original_size - chosen.size ..]) catch |err| return coordinator.mapError(err);
    profile.result_bytes = output.len;
    profile.charged_dictionary_bytes = charged(chosen);
    if (chosen.size < original_size) profile.add("shrink_selected", 1);
    profile.peak_working_memory = budget.state.peak;
    profile.peak_allocator_owned_bytes = budget.heap_peak;
    profile.thread_stack_reservation_peak = budget.stack_peak;
    var selected_options = candidates.candidates[selected_job].options;
    selected_options.profile = null;
    return .{ .bytes = output, .selected_options = selected_options, .validation_score = chosen.score, .candidates_evaluated = candidates.len, .profile = profile, .original_dictionary_size = original_size };
}

fn normalizeScore(value: anytype) types.Score {
    return .{ .estimated_bits = value.estimated_bits, .covered_bytes = value.covered_bytes, .matches = value.matches, .distance_bits = value.distance_bits, .dictionary_bytes = if (@hasField(@TypeOf(value), "dictionary_bytes")) value.dictionary_bytes else null };
}
fn charged(value: Variant) usize {
    return value.score.dictionary_bytes orelse value.size;
}
fn better(candidate: Variant, current: Variant, serial: usize, current_serial: usize) bool {
    const a = candidate.score;
    const b = current.score;
    if (a.estimated_bits != b.estimated_bits) return a.estimated_bits < b.estimated_bits;
    if (a.covered_bytes != b.covered_bytes) return a.covered_bytes > b.covered_bytes;
    if (a.matches != b.matches) return a.matches < b.matches;
    if (a.distance_bits != b.distance_bits) return a.distance_bits < b.distance_bits;
    if (charged(candidate) != charged(current)) return charged(candidate) < charged(current);
    if (candidate.size != current.size) return candidate.size < current.size;
    return serial < current_serial;
}
