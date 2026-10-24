const std = @import("std");
const core = @import("../../core.zig");
const tables = @import("tables.zig");
const model = @import("model.zig");
const item_encoder = @import("item_encoder.zig");
const finder = @import("match_finder.zig");
const literal_encoder = @import("literal_encoder.zig");
const options_mod = @import("encode_options.zig");
const working = @import("../../io/working_allocator.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{ InvalidQuantumStream, UnsupportedCabinetFeature, WorkingMemoryLimitExceeded };
pub const Options = options_mod.Options;
pub const Strategy = options_mod.Strategy;
pub const Summary = item_encoder.Summary;
pub const Encoded = struct {
    bytes: []u8,
    summary: Summary,
    peak_working_bytes: usize = 0,
    pub fn deinit(self: *Encoded, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Encoder = struct {
    options: Options,
    models: model.State,
    input_read: usize = 0,

    pub fn init(options: Options) Error!Encoder {
        try options.validate();
        return .{ .options = options, .models = model.initialState(options.window_bits) };
    }

    pub fn encodeFrameAlloc(self: *Encoder, allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize) Error![]u8 {
        return (try self.encodeFrameWithSummaryAlloc(allocator, input, start, end)).bytes;
    }

    pub fn encodeFrameWithHistoryAlloc(self: *Encoder, allocator: std.mem.Allocator, history: []const u8, input: []const u8) Error![]u8 {
        return (try self.encodeFrameWithHistoryAndSummaryAlloc(allocator, history, input)).bytes;
    }

    /// Accept one frame and caller-retained preceding bytes without requiring
    /// a complete stream prefix. Scratch is bounded by the selected history
    /// suffix plus one frame; adaptive state and global input progress persist.
    pub fn encodeFrameWithHistoryAndSummaryAlloc(self: *Encoder, allocator: std.mem.Allocator, history: []const u8, input: []const u8) Error!Encoded {
        try self.options.validate();
        if (input.len == 0 or input.len > tables.frame_size or self.input_read % tables.frame_size != 0 or history.len > self.input_read)
            return error.InvalidBlockPlan;
        var budget = working.WorkingAllocator.init(allocator, self.options.max_working_memory);
        var result = self.encodeHistoryInternal(budget.allocator(), history, input) catch |err| {
            std.debug.assert(budget.live == 0);
            if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
            return err;
        };
        result.peak_working_bytes = budget.peak;
        std.debug.assert(budget.live == result.bytes.len);
        return result;
    }

    fn encodeHistoryInternal(self: *Encoder, allocator: std.mem.Allocator, history: []const u8, input: []const u8) Error!Encoded {
        const retained = if (self.options.strategy == .literals) 0 else @min(history.len, self.options.historyLimit());
        if (retained == 0) return self.encodeInternal(allocator, input, 0, input.len);
        const context = try allocator.alloc(u8, retained + input.len);
        defer allocator.free(context);
        @memcpy(context[0..retained], history[history.len - retained ..]);
        @memcpy(context[retained..], input);
        return self.encodeInternal(allocator, context, retained, context.len);
    }

    pub fn encodeFrameWithSummaryAlloc(self: *Encoder, allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize) Error!Encoded {
        try self.options.validate();
        if (start != self.input_read or start % tables.frame_size != 0 or start >= end or end > input.len or end - start > tables.frame_size)
            return error.InvalidBlockPlan;
        var budget = working.WorkingAllocator.init(allocator, self.options.max_working_memory);
        var result = self.encodeInternal(budget.allocator(), input, start, end) catch |err| {
            std.debug.assert(budget.live == 0);
            if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
            return err;
        };
        result.peak_working_bytes = budget.peak;
        std.debug.assert(budget.live == result.bytes.len);
        return result;
    }

    fn encodeInternal(self: *Encoder, allocator: std.mem.Allocator, input: []const u8, start: usize, end: usize) Error!Encoded {
        const next_input = std.math.add(usize, self.input_read, end - start) catch return error.IntegerOverflow;
        var reference = literal_encoder.LiteralEncoder{ .literal_models = .{ self.models[0], self.models[1], self.models[2], self.models[3] }, .selector_model = self.models[model.selector_index] };
        var selected = Encoded{ .bytes = try reference.encodeFrameAlloc(allocator, input[start..end]), .summary = .{ .literals = end - start, .literal_reference_frames = 1 } };
        errdefer allocator.free(selected.bytes);
        var next_models = self.models;
        for (0..4) |index| next_models[index] = reference.literal_models[index];
        next_models[model.selector_index] = reference.selector_model;
        if (self.options.strategy == .greedy and end - start >= 3) {
            var plan = try finder.planAlloc(allocator, input, start, end, self.options);
            defer plan.deinit(allocator);
            const candidate = try item_encoder.encode(allocator, plan.items.items, self.input_read, self.options.window_bits, self.models);
            if (candidate.bytes.len < selected.bytes.len) {
                allocator.free(selected.bytes);
                selected = .{ .bytes = candidate.bytes, .summary = candidate.summary };
                next_models = candidate.models;
            } else allocator.free(candidate.bytes);
        }
        if (selected.bytes.len > self.options.max_output_len) return error.OutputLimitExceeded;
        self.models = next_models;
        self.input_read = next_input;
        return selected;
    }
};

/// Standalone Quantum streams include CAB's synthetic 0xff sentinel after
/// every complete 32 KiB frame. CAB's per-CFDATA writer uses Encoder directly.
pub fn encodeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error!Encoded {
    try options.validate();
    var budget = working.WorkingAllocator.init(allocator, options.max_working_memory);
    var result = encodeStreamInternal(budget.allocator(), input, options) catch |err| {
        std.debug.assert(budget.live == 0);
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
    result.peak_working_bytes = budget.peak;
    std.debug.assert(budget.live == result.bytes.len);
    return result;
}

fn encodeStreamInternal(allocator: std.mem.Allocator, input: []const u8, options: Options) Error!Encoded {
    var frame_options = options;
    frame_options.max_working_memory = std.math.maxInt(usize);
    var state = try Encoder.init(frame_options);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var summary = Summary{};
    var start: usize = 0;
    while (start < input.len) {
        const end = start + @min(input.len - start, tables.frame_size);
        var frame = try state.encodeFrameWithSummaryAlloc(allocator, input, start, end);
        defer frame.deinit(allocator);
        const sentinel_len: usize = @intFromBool(end - start == tables.frame_size);
        const remaining = options.max_output_len - @min(options.max_output_len, output.items.len);
        if (frame.bytes.len > remaining or sentinel_len > remaining - frame.bytes.len) return error.OutputLimitExceeded;
        try output.appendSlice(allocator, frame.bytes);
        if (sentinel_len != 0) try output.append(allocator, 0xff);
        try summary.add(frame.summary);
        start = end;
    }
    return .{ .bytes = try output.toOwnedSlice(allocator), .summary = summary };
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error![]u8 {
    return (try encodeWithSummaryAlloc(allocator, input, options)).bytes;
}

pub fn encodeInto(allocator: std.mem.Allocator, input: []const u8, output: []u8, options: Options) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeAppend(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, options: Options) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try output.appendSlice(allocator, encoded);
    return encoded.len;
}

test {
    _ = @import("encoder_tests.zig");
}
