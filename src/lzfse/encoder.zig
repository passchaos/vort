const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const lzvn = @import("lzvn.zig");
const options_mod = @import("encode_options.zig");
const matcher = @import("encoder/match_finder.zig");
const blocks = @import("encoder/block_encoder.zig");
const plans = @import("encoder/block_plan.zig");
const working = @import("../io/working_allocator.zig");

pub const Error = core.Error || format.Error || lzvn.Error || std.mem.Allocator.Error || error{ InvalidLzfseStream, WorkingMemoryLimitExceeded, BlockPlanLimitExceeded };
pub const Options = options_mod.Options;
pub const Strategy = options_mod.Strategy;
pub const FseVersion = options_mod.FseVersion;
pub const Plan = plans.Plan;
pub const Record = plans.Record;
pub const encodeFsePlanAlloc = blocks.encodePlanAlloc;

pub const Summary = struct {
    stored_blocks: usize = 0,
    lzvn_blocks: usize = 0,
    fse_v1_blocks: usize = 0,
    fse_v2_blocks: usize = 0,
    fse_literal_bytes: usize = 0,
    fse_matched_bytes: usize = 0,
    fse_records: usize = 0,
    max_fse_distance: usize = 0,
    max_fse_match_length: usize = 0,
    fse_literal_payload_bytes: usize = 0,
    fse_lmd_payload_bytes: usize = 0,
};
pub const Encoded = struct {
    bytes: []u8,
    summary: Summary,
    peak_working_bytes: usize,
    pub fn deinit(self: *Encoded, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub fn encodeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error!Encoded {
    try options.validate();
    var budget = working.WorkingAllocator.init(allocator, options.max_working_memory);
    var result = encodeInternal(budget.allocator(), input, options) catch |err| {
        std.debug.assert(budget.live == 0);
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
    result.peak_working_bytes = budget.peak;
    std.debug.assert(budget.live == result.bytes.len);
    return result;
}

fn encodeInternal(allocator: std.mem.Allocator, input: []const u8, options: Options) Error!Encoded {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var summary = Summary{};
    const strategy = options.effectiveStrategy();
    if (input.len == 0) {
        try emitLegacy(allocator, &output, input, null, options.max_output_len, &summary);
    }
    var start: usize = 0;
    while (start < input.len) {
        const end = start + @min(input.len - start, options.block_size);
        if (strategy == .stored or strategy == .lzvn) {
            const block = input[start..end];
            const payload = if (strategy == .lzvn) try lzvn.encodeAlloc(allocator, block) else null;
            defer if (payload) |bytes| allocator.free(bytes);
            try emitLegacy(allocator, &output, block, payload, options.max_output_len, &summary);
            start = end;
            continue;
        }
        var plan = try matcher.planAlloc(allocator, input, start, end, options);
        defer plan.deinit(allocator);
        if (plan.raw_size == 0 or plan.raw_size > end - start) return error.InvalidLzfseStream;
        const candidate_end = start + plan.raw_size;
        const block = input[start..candidate_end];
        var fse_block = try blocks.encodePlanAlloc(allocator, &plan, options.fse_version);
        defer fse_block.deinit(allocator);
        var payload: ?[]u8 = if (strategy == .auto) try lzvn.encodeAlloc(allocator, block) else null;
        defer if (payload) |bytes| allocator.free(bytes);
        const raw_size = try add(block.len, 8);
        const legacy_size = if (payload) |bytes| @min(raw_size, try add(bytes.len, 12)) else raw_size;
        if (fse_block.bytes.len < legacy_size) {
            try appendLimited(allocator, &output, fse_block.bytes, options.max_output_len);
            try recordFse(&summary, &plan, &fse_block, options.fse_version);
            start = candidate_end;
        } else {
            // A count-limited plan that does not win need not fragment raw or
            // LZVN output. Compare/emit the original requested legacy block.
            if (candidate_end != end and strategy == .auto) {
                if (payload) |bytes| allocator.free(bytes);
                payload = null;
                payload = try lzvn.encodeAlloc(allocator, input[start..end]);
            }
            try emitLegacy(allocator, &output, input[start..end], payload, options.max_output_len, &summary);
            start = end;
        }
    }
    var end_magic: [4]u8 = undefined;
    std.mem.writeInt(u32, &end_magic, format.end_of_stream_magic, .little);
    try appendLimited(allocator, &output, &end_magic, options.max_output_len);
    return .{ .bytes = try output.toOwnedSlice(allocator), .summary = summary, .peak_working_bytes = 0 };
}

fn recordFse(summary: *Summary, plan: *const Plan, block: anytype, version: FseVersion) Error!void {
    var next = summary.*;
    const field = if (version == .v1) &next.fse_v1_blocks else &next.fse_v2_blocks;
    field.* = try add(field.*, 1);
    next.fse_literal_bytes = try add(next.fse_literal_bytes, plan.literals.items.len);
    next.fse_records = try add(next.fse_records, plan.records.items.len);
    next.fse_literal_payload_bytes = try add(next.fse_literal_payload_bytes, block.literal_payload_size);
    next.fse_lmd_payload_bytes = try add(next.fse_lmd_payload_bytes, block.lmd_payload_size);
    for (plan.records.items) |record| {
        next.fse_matched_bytes = try add(next.fse_matched_bytes, record.match_len);
        if (record.match_len != 0) next.max_fse_distance = @max(next.max_fse_distance, record.distance);
        next.max_fse_match_length = @max(next.max_fse_match_length, record.match_len);
    }
    summary.* = next;
}

fn emitLegacy(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, payload: ?[]const u8, limit: usize, summary: *Summary) Error!void {
    const raw_size = try add(input.len, 8);
    const use_lzvn = if (payload) |bytes| try add(bytes.len, 12) < raw_size else false;
    const size = if (use_lzvn) try add(payload.?.len, 12) else raw_size;
    try requireRoom(output.items.len, size, limit);
    var header: [12]u8 = @splat(0);
    std.mem.writeInt(u32, header[0..4], if (use_lzvn) format.compressed_lzvn_magic else format.uncompressed_magic, .little);
    std.mem.writeInt(u32, header[4..8], std.math.cast(u32, input.len) orelse return error.IntegerOverflow, .little);
    if (use_lzvn) {
        std.mem.writeInt(u32, header[8..12], std.math.cast(u32, payload.?.len) orelse return error.IntegerOverflow, .little);
        try output.appendSlice(allocator, &header);
        try output.appendSlice(allocator, payload.?);
        summary.lzvn_blocks = try add(summary.lzvn_blocks, 1);
    } else {
        try output.appendSlice(allocator, header[0..8]);
        try output.appendSlice(allocator, input);
        summary.stored_blocks = try add(summary.stored_blocks, 1);
    }
}

fn requireRoom(current: usize, size: usize, limit: usize) Error!void {
    if (try add(current, size) > limit) return error.OutputLimitExceeded;
}
fn appendLimited(allocator: std.mem.Allocator, output: *std.ArrayList(u8), bytes: []const u8, limit: usize) Error!void {
    try requireRoom(output.items.len, bytes.len, limit);
    try output.appendSlice(allocator, bytes);
}
fn add(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error![]u8 {
    return (try encodeWithSummaryAlloc(allocator, input, options)).bytes;
}
pub fn encodeAppend(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, options: Options) Error!usize {
    const bytes = try encodeAlloc(allocator, input, options);
    defer allocator.free(bytes);
    try output.appendSlice(allocator, bytes);
    return bytes.len;
}
pub fn encodeInto(allocator: std.mem.Allocator, input: []const u8, options: Options, output: []u8) Error!usize {
    const bytes = try encodeAlloc(allocator, input, options);
    defer allocator.free(bytes);
    if (bytes.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..bytes.len], bytes);
    return bytes.len;
}
