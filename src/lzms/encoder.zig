const std = @import("std");
const core = @import("../core.zig");
const adaptive = @import("adaptive_huffman.zig");
const probability = @import("probability.zig");
const tables = @import("tables.zig");
const x86 = @import("x86.zig");
const streams = @import("stream_encoder.zig");
const item_encoder = @import("item_encoder.zig");
const match_finder = @import("match_finder.zig");
const options_module = @import("encode_options.zig");
const working = @import("../io/working_allocator.zig");
const RangeEncoder = streams.RangeEncoder;
const BackwardBitWriter = streams.BackwardBitWriter;
const appendU16AssumeCapacity = streams.appendU16AssumeCapacity;

pub const Error = core.Error || adaptive.Error || std.mem.Allocator.Error || error{
    InvalidLzms,
    WorkingMemoryLimitExceeded,
};

pub const Options = options_module.Options;
pub const Strategy = options_module.Strategy;
pub const Summary = item_encoder.Summary;
pub const Encoded = struct {
    bytes: []u8,
    summary: Summary,
    used_literal_reference: bool,
    peak_working_bytes: usize = 0,

    pub fn deinit(self: *Encoded, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

/// Greedy LZ/delta encoding, with complete literal-wire arbitration.
pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return encodeWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error![]u8 {
    return (try encodeWithSummaryAlloc(allocator, input, options)).bytes;
}

pub fn encodeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, options: Options) Error!Encoded {
    try options.validate();
    if (input.len > tables.max_buffer_size) return error.OutputLimitExceeded;
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
    if (input.len == 0) return .{ .bytes = try allocator.alloc(u8, 0), .summary = .{}, .used_literal_reference = true };
    const transformed = try transformAlloc(allocator, input);
    defer allocator.free(transformed);
    const reference = try encodeLiteralTransformed(allocator, transformed);
    var result = Encoded{ .bytes = reference, .summary = .{ .literals = input.len }, .used_literal_reference = true };
    errdefer allocator.free(result.bytes);
    if (options.strategy == .greedy and input.len >= 2) {
        var encoder = try item_encoder.Encoder.init(allocator, input.len);
        defer encoder.deinit();
        var finder = try match_finder.Finder.init(allocator, transformed, options);
        defer finder.deinit();
        while (encoder.position < transformed.len) {
            const start = encoder.position;
            const item = (try finder.find(&encoder)) orelse item_encoder.Item{ .literal = transformed[start] };
            try encoder.push(item);
            finder.advance(start, encoder.position - start);
        }
        const candidate = try encoder.finishAlloc();
        if (candidate.len < reference.len) {
            allocator.free(reference);
            result = .{ .bytes = candidate, .summary = encoder.summary, .used_literal_reference = false };
        } else allocator.free(candidate);
    }
    if (result.bytes.len > options.max_output_len) return error.OutputLimitExceeded;
    return result;
}

pub fn encodeLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    if (input.len > tables.max_buffer_size) return error.OutputLimitExceeded;
    if (input.len == 0) return allocator.alloc(u8, 0);
    const transformed = try transformAlloc(allocator, input);
    defer allocator.free(transformed);
    return encodeLiteralTransformed(allocator, transformed);
}

fn transformAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    const transformed = try allocator.dupe(u8, input);
    errdefer allocator.free(transformed);
    if (transformed.len > 17) {
        const scratch = try allocator.create([65_536]i32);
        defer allocator.destroy(scratch);
        x86.apply(transformed, scratch);
    }
    return transformed;
}

fn encodeLiteralTransformed(allocator: std.mem.Allocator, transformed: []const u8) Error![]u8 {
    var range = RangeEncoder{};
    defer range.bytes.deinit(allocator);
    var bits = BackwardBitWriter{ .allocator = allocator };
    defer bits.words.deinit(allocator);
    var literals = try adaptive.AdaptiveEncoder(256).init(256, 1024);
    var main_probabilities: [16]probability.Entry = @splat(.{});
    var main_state: u32 = 0;
    for (transformed) |literal| {
        try encodeDecisionBit(
            allocator,
            &range,
            &main_state,
            &main_probabilities,
            0,
        );
        try literals.encode(&bits, literal);
    }
    try bits.finish();
    try range.finish(allocator);

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const bit_bytes = std.math.mul(usize, bits.words.items.len, 2) catch
        return error.IntegerOverflow;
    const total = std.math.add(usize, range.bytes.items.len, bit_bytes) catch
        return error.IntegerOverflow;
    try output.ensureTotalCapacity(allocator, total);
    output.appendSliceAssumeCapacity(range.bytes.items);
    var word_index = bits.words.items.len;
    while (word_index != 0) {
        word_index -= 1;
        appendU16AssumeCapacity(&output, bits.words.items[word_index]);
    }
    std.debug.assert(output.items.len == total and total & 1 == 0);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
) Error!usize {
    return encodeWithOptionsAppend(allocator, output, input, .{});
}

pub fn encodeWithOptionsAppend(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, options: Options) Error!usize {
    const encoded = try encodeWithOptionsAlloc(allocator, input, options);
    defer allocator.free(encoded);
    try output.ensureUnusedCapacity(allocator, encoded.len);
    output.appendSliceAssumeCapacity(encoded);
    return encoded.len;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
) Error!usize {
    return encodeWithOptionsInto(allocator, input, output, .{});
}

pub fn encodeWithOptionsInto(allocator: std.mem.Allocator, input: []const u8, output: []u8, options: Options) Error!usize {
    const encoded = try encodeWithOptionsAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (encoded.len > output.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn encodeDecisionBit(
    allocator: std.mem.Allocator,
    range: *RangeEncoder,
    state: *u32,
    entries: []probability.Entry,
    bit: u1,
) !void {
    const entry = &entries[state.*];
    state.* = ((state.* << 1) | bit) & @as(u32, @intCast(entries.len - 1));
    const predicted = entry.probability();
    entry.update(bit);
    try range.encodeBit(allocator, bit, predicted);
}
