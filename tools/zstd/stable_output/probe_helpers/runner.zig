//! Actual public stable/owned pumps with decoder-only requested allocation tracking.
const std = @import("std");
const h = @import("common.zig");
const Z = h.Z;

pub const State = struct {
    events: std.ArrayList(h.Observation) = .empty,
    failure: ?[]const u8 = null,
    stable_binding_succeeded: bool = false,
    stable_capacities_zero: bool = true,
    caller_guard_verified: bool = true,
    dictionary_retry_count: usize = 0,
    footer_zero_quantum_input: usize = 0,
    final_snapshot: ?Z.NativeIncrementalFrameDecoder.Snapshot = null,
    retained_requested_before_deinit: usize = 0,
    requested_peak: usize = 0,
    allocations: usize = 0,
    frees: usize = 0,
    growing_resize_refusals: usize = 0,
    growing_remap_refusals: usize = 0,
    denied_requests: usize = 0,
    requested_after_deinit: usize = 0,
    warm_history_capacity: usize = 0,
    warm_scratch_capacity: usize = 0,
    after_bind_history_capacity: usize = 0,
    after_bind_scratch_capacity: usize = 0,
    warm_requested_live: usize = 0,
    warm_requested_peak: usize = 0,
    after_bind_requested_live: usize = 0,
    before_bind_requested_live: usize = 0,
    before_bind_history_capacity: usize = 0,
    before_bind_scratch_capacity: usize = 0,
    completed_members: usize = 0,
    excess_input_unconsumed: bool = false,
    next_destination_distinct: bool = false,
    old_destination_preserved: bool = false,
    prefix_setter_refusal: ?[]const u8 = null,
    prefix_snapshot_before_refusal: ?Z.PrefixSnapshot = null,
    prefix_snapshot_after_refusal: ?Z.PrefixSnapshot = null,
    seeded_repeat_count: ?u64 = null,
    seeded_input: ?u64 = null,
    seeded_output: ?u64 = null,
    seed_scope: ?[]const u8 = null,

    pub fn deinit(self: *State, a: std.mem.Allocator) void {
        self.events.deinit(a);
    }
};

pub fn run(init: std.process.Init, input: []const u8, payload: []const u8, config: h.Config, dict: ?Z.NativeDictionary, state: *State) ![]u8 {
    var tracker = h.Tracker.init(init.gpa);
    tracker.hard_limit = config.hard_heap_limit;
    const options: Z.NativeIncrementalFrameDecoder.Options = .{
        .format = config.format,
        .ignore_content_checksum = config.ignore_checksum,
        .input_policy = config.input_policy,
        .max_working_memory = config.max_working_memory orelse std.math.maxInt(usize),
        .stop_after_first_frame = config.stop_after_first_frame or config.scenario == .next_stream or config.scenario == .crossing_32,
        .expected_output_len = config.expected_output_len,
        .max_output_len = config.max_output_len orelse std.math.maxInt(u64),
    };
    var decoder = if (dict != null and !config.recover_dictionary) Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(tracker.allocator(), dict.?, options) else Z.NativeIncrementalFrameDecoder.initWithOptions(tracker.allocator(), options);
    var caller_storage: ?[]u8 = null;
    var second_storage: ?[]u8 = null;
    defer {
        state.final_snapshot = decoder.snapshot();
        state.retained_requested_before_deinit = tracker.live;
        state.requested_peak = tracker.peak;
        state.allocations = tracker.allocation_calls;
        state.frees = tracker.free_calls;
        state.growing_resize_refusals = tracker.growing_resize_refusals;
        state.growing_remap_refusals = tracker.growing_remap_refusals;
        state.denied_requests = tracker.denied_requests;
        decoder.deinit();
        state.requested_after_deinit = tracker.live;
        if (second_storage) |bytes| init.gpa.free(bytes);
        if (caller_storage) |bytes| init.gpa.free(bytes);
    }
    const destination_size = config.destination_size orelse payload.len;
    const caller = try init.gpa.alloc(u8, destination_size + 19);
    caller_storage = caller;
    @memset(caller, 0xa5);
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(init.gpa);
    if (config.scenario == .warm_owned) {
        var warm = config;
        warm.api = .owned;
        warm.scenario = .normal;
        warm.recover_dictionary = false;
        _ = try pump(init, input, payload, warm, dict, &decoder, &tracker, state, caller[0..destination_size]);
        state.warm_history_capacity = decoder.direct_history.capacity;
        state.warm_scratch_capacity = decoder.decoded_scratch.capacity;
        state.warm_requested_live = tracker.live;
        state.warm_requested_peak = tracker.peak;
        decoder.reset();
        @memset(caller, 0xa5);
        tracker.begin();
    }
    if (config.scenario == .overlap) try decoder.setPrefix(caller[0..@min(destination_size, 32)]);
    if (config.api != .owned) {
        state.before_bind_requested_live = tracker.live;
        state.before_bind_history_capacity = decoder.direct_history.capacity;
        state.before_bind_scratch_capacity = decoder.decoded_scratch.capacity;
        decoder.bindStableOutput(caller[0..destination_size]) catch |err| {
            state.failure = @errorName(err);
            try untouched(caller);
            return result.toOwnedSlice(init.gpa);
        };
        state.stable_binding_succeeded = true;
        state.after_bind_history_capacity = decoder.direct_history.capacity;
        state.after_bind_scratch_capacity = decoder.decoded_scratch.capacity;
        state.after_bind_requested_live = tracker.live;
    }
    if (config.scenario == .overlap_setter) {
        const before = decoder.prefixSnapshot();
        state.prefix_snapshot_before_refusal = before;
        if (decoder.setPrefix(caller[0..@min(destination_size, 32)])) |_| {
            return error.ExpectedPrefixOverlapRefusal;
        } else |err| {
            state.prefix_setter_refusal = @errorName(err);
        }
        const after = decoder.prefixSnapshot();
        state.prefix_snapshot_after_refusal = after;
        try h.require(std.meta.eql(before, after));
        try h.require(decoder.stableOutput().len == 0);
        try untouched(caller);
    }
    const first = pump(init, input, payload, config, dict, &decoder, &tracker, state, caller[0..destination_size]) catch |err| blk: {
        state.failure = @errorName(err);
        break :blk @as(usize, @intCast(decoder.snapshot().output_written));
    };
    try result.appendSlice(init.gpa, caller[0..@min(first, destination_size)]);
    if (state.failure == null and (config.scenario == .next_stream or config.scenario == .crossing_32)) {
        if (config.scenario == .crossing_32) {
            const repeats = @as(u64, std.math.maxInt(u32)) + 2;
            decoder.input_received = @as(u64, @intCast(input.len)) * repeats;
            decoder.output_written = @as(u64, @intCast(payload.len)) * repeats;
            decoder.data_frame_count = repeats;
            state.seeded_repeat_count = repeats;
            state.seeded_input = decoder.input_received;
            state.seeded_output = decoder.output_written;
            state.seed_scope = "Derived repeated completed small-frame totals; only three cumulative counters seeded; no physical 4 GiB transfer";
        }
        const second_caller = try init.gpa.alloc(u8, destination_size + 19);
        second_storage = second_caller;
        @memset(second_caller, 0xa5);
        try h.require(second_caller.ptr != caller.ptr);
        state.next_destination_distinct = true;
        try decoder.nextStreamWithStableOutput(second_caller[0..destination_size]);
        const before_second = decoder.snapshot().output_written;
        const second = pump(init, input, payload, config, dict, &decoder, &tracker, state, second_caller[0..destination_size]) catch |err| blk: {
            state.failure = @errorName(err);
            break :blk @as(usize, @intCast(decoder.snapshot().output_written - before_second));
        };
        try h.require(std.mem.eql(u8, caller[0..first], result.items[0..first]));
        state.old_destination_preserved = true;
        try untouched(second_caller[destination_size..]);
        try result.appendSlice(init.gpa, second_caller[0..second]);
    }
    if (state.failure == null and config.scenario == .excess) {
        const before = decoder.snapshot();
        const extra = try decoder.stepStableLimited(input, 0);
        const after = decoder.snapshot();
        try h.require(extra.status == .done and extra.progress.input_read == 0 and extra.progress.output_written == 0 and before.input_received == after.input_received and before.output_written == after.output_written);
        try h.require(std.mem.eql(u8, decoder.stableOutput(), caller[0..first]));
        state.excess_input_unconsumed = true;
        try state.events.append(init.gpa, .{ .call = state.events.items.len, .api = "limited", .input_before = before.input_received, .input_after = after.input_received, .output_before = before.output_written, .output_after = after.output_written, .input_read = 0, .output_written = 0, .input_offered = input.len, .output_quantum = 0, .status = "done", .requested_live = tracker.live, .requested_peak = tracker.peak, .direct_history_capacity = decoder.direct_history.capacity, .decoded_scratch_capacity = decoder.decoded_scratch.capacity, .compressed_capacity = decoder.compressedBufferCapacity() });
    }
    try untouched(caller[destination_size..]);
    state.caller_guard_verified = true;
    return result.toOwnedSlice(init.gpa);
}

fn pump(init: std.process.Init, wire: []const u8, payload: []const u8, c: h.Config, dict: ?Z.NativeDictionary, decoder: *Z.NativeIncrementalFrameDecoder, tracker: *h.Tracker, state: *State, caller: []u8) !usize {
    const start = decoder.snapshot();
    var input_offset: usize = 0;
    var written: usize = 0;
    var dictionary_supplied = false;
    for (0..wire.len * 8 + payload.len * 4 + 65536) |local_call| {
        const visible_end = if (c.scenario == .footer and written < payload.len) wire.len - 4 else wire.len;
        const offered = @min(visible_end - input_offset, c.input_chunks[local_call % c.input_chunks.len]);
        var quantum = c.output_quanta[local_call % c.output_quanta.len];
        if (c.api == .stable) quantum = caller.len - written;
        if (c.scenario == .footer and written == payload.len) quantum = 0;
        const before = decoder.snapshot();
        const step = if (c.api == .owned)
            decoder.step(wire[input_offset..][0..offered], caller[written..][0..@min(quantum, caller.len - written)])
        else if (c.api == .stable)
            decoder.stepStable(wire[input_offset..][0..offered])
        else
            decoder.stepStableLimited(wire[input_offset..][0..offered], quantum);
        var failure: ?anyerror = null;
        var status: ?[]const u8 = null;
        const progress = if (step) |value| blk: {
            status = @tagName(value.status);
            break :blk value.progress;
        } else |err| blk: {
            failure = err;
            break :blk decoder.snapshot().last_step_progress;
        };
        const after = decoder.snapshot();
        try h.require(after.input_received == before.input_received + progress.input_read and after.output_written == before.output_written + progress.output_written);
        try h.require(progress.input_read <= offered and progress.output_written <= caller.len - written);
        if (c.api != .stable) try h.require(progress.output_written <= quantum);
        input_offset += progress.input_read;
        try h.require(written + progress.output_written <= payload.len);
        try h.require(std.mem.eql(u8, caller[written..][0..progress.output_written], payload[written..][0..progress.output_written]));
        written += progress.output_written;
        if (c.api != .owned) {
            try h.require(std.mem.eql(u8, decoder.stableOutput(), caller[0..written]));
            state.stable_capacities_zero = state.stable_capacities_zero and decoder.direct_history.capacity == 0 and decoder.decoded_scratch.capacity == 0;
        }
        if (quantum == 0 and written == payload.len) state.footer_zero_quantum_input += progress.input_read;
        try state.events.append(init.gpa, .{ .call = state.events.items.len, .api = @tagName(c.api), .input_before = before.input_received, .input_after = after.input_received, .output_before = before.output_written, .output_after = after.output_written, .input_read = progress.input_read, .output_written = progress.output_written, .input_offered = offered, .output_quantum = quantum, .status = status, .failure = if (failure) |err| @errorName(err) else null, .requested_live = tracker.live, .requested_peak = tracker.peak, .direct_history_capacity = decoder.direct_history.capacity, .decoded_scratch_capacity = decoder.decoded_scratch.capacity, .compressed_capacity = decoder.compressedBufferCapacity() });
        if (failure) |err| {
            if (err == error.NeedDictionary and c.recover_dictionary and !dictionary_supplied) {
                try decoder.provideDictionary(dict orelse return error.MissingProbeDictionary);
                dictionary_supplied = true;
                state.dictionary_retry_count += 1;
                continue;
            }
            return err;
        }
        if (status != null and std.mem.eql(u8, status.?, "done")) {
            const stopped = c.stop_after_first_frame or c.scenario == .next_stream or c.scenario == .crossing_32;
            // A member can finish exactly at the currently offered input
            // boundary. Fresh input automatically resumes the same decoder.
            if (!stopped and input_offset < wire.len) continue;
            try decoder.finish();
            state.completed_members += 1;
            if (!c.stop_after_first_frame and c.scenario != .next_stream and c.scenario != .crossing_32) try h.require(input_offset == wire.len);
            try h.require(written == payload.len);
            return written;
        }
        if (input_offset == wire.len and status != null and std.mem.eql(u8, status.?, "need_input")) {
            try decoder.finish();
            try h.require(written == payload.len);
            state.completed_members += 1;
            try h.require(decoder.snapshot().input_received - start.input_received == input_offset);
            return written;
        }
    }
    return error.StableOutputProbeDidNotConverge;
}

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try h.require(byte == 0xa5);
}
