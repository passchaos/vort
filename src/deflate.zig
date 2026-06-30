const std = @import("std");
const checksum = @import("checksum.zig");
const bitstream = @import("bitstream.zig");
const huffman = @import("huffman.zig");
const lz77 = @import("lz77.zig");
const core = @import("core.zig");

pub const Error = core.Error;
pub const max_stored_block_len: usize = std.math.maxInt(u16);

pub const DecodeResult = struct {
    input_read: usize,
    output_written: usize,
};

pub const ParserMode = enum { hash, greedy, lazy, optimal };

pub const BlockSelection = enum { stored_fixed, stored_fixed_dynamic };

pub const CompressionOptions = struct {
    parser: ParserMode = .greedy,
    lz77_options: lz77.GreedyOptions = .{},
    block_selection: BlockSelection = .stored_fixed_dynamic,
};

pub const CompressionLevel = enum { fastest, fast, default, best };

pub fn optionsForLevel(level: CompressionLevel) CompressionOptions {
    return switch (level) {
        .fastest => .{ .parser = .hash, .lz77_options = .{ .max_chain = 4, .nice_len = 8 }, .block_selection = .stored_fixed },
        .fast => .{ .parser = .hash, .lz77_options = .{ .max_chain = 32, .nice_len = 16 }, .block_selection = .stored_fixed },
        .default => .{ .parser = .lazy, .lz77_options = .{ .max_chain = 128, .nice_len = 64 } },
        .best => .{ .parser = .optimal, .lz77_options = .{ .max_chain = 512, .nice_len = 128 } },
    };
}

pub const OwnedDecodeResult = struct {
    bytes: []u8,
    input_read: usize,

    pub fn deinit(self: OwnedDecodeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

fn planTokensAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) !lz77.GreedyPlan {
    return switch (options.parser) {
        .hash => try lz77.hashGreedyPlanAlloc(allocator, input, options.lz77_options),
        .greedy => try lz77.greedyPlanAlloc(allocator, input, options.lz77_options),
        .lazy => try lz77.lazyGreedyPlanAlloc(allocator, input, options.lz77_options),
        .optimal => try lz77.optimalPlanAlloc(allocator, input, options.lz77_options),
    };
}

pub fn encodeRawBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const stored = try encodeRawStoredAlloc(allocator, input);
    errdefer allocator.free(stored);
    const fixed = try encodeRawFixedWithOptionsAlloc(allocator, input, options);
    errdefer allocator.free(fixed);

    if (options.block_selection == .stored_fixed) {
        if (stored.len <= fixed.len) {
            allocator.free(fixed);
            return stored;
        }
        allocator.free(stored);
        return fixed;
    }

    const dynamic = try encodeRawDynamicWithOptionsAlloc(allocator, input, options);
    errdefer allocator.free(dynamic);
    if (stored.len <= fixed.len and stored.len <= dynamic.len) {
        allocator.free(fixed);
        allocator.free(dynamic);
        return stored;
    }
    allocator.free(stored);
    if (fixed.len <= dynamic.len) {
        allocator.free(dynamic);
        return fixed;
    }
    allocator.free(fixed);
    return dynamic;
}

pub fn encodeRawBestSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    const effective_block_len = @min(block_len, max_stored_block_len);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    if (input.len == 0) {
        const plan = try planTokensAlloc(allocator, "", options);
        defer plan.deinit(allocator);
        try writeBestTokensBlock(allocator, &writer, "", plan.tokens, true, options);
        return writer.toOwnedSlice(allocator);
    }
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(effective_block_len, input.len - offset);
        const chunk = input[offset..][0..n];
        const final = offset + n == input.len;
        const plan = try planTokensAlloc(allocator, chunk, options);
        defer plan.deinit(allocator);
        try writeBestTokensBlock(allocator, &writer, chunk, plan.tokens, final, options);
        offset += n;
    }
    return writer.toOwnedSlice(allocator);
}

pub const AdaptiveSplitOptions = struct {
    min_block_len: usize = 16 * 1024,
    max_block_len: usize = max_stored_block_len,
    sample_len: usize = 4096,
};

pub fn encodeRawBestAdaptiveSplitAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    if (split_options.min_block_len == 0 or split_options.max_block_len == 0 or split_options.min_block_len > split_options.max_block_len) return error.InvalidBlockPlan;
    const max_block_len = @min(split_options.max_block_len, max_stored_block_len);
    const min_block_len = @min(split_options.min_block_len, max_block_len);
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    if (input.len == 0) {
        const plan = try planTokensAlloc(allocator, "", options);
        defer plan.deinit(allocator);
        try writeBestTokensBlock(allocator, &writer, "", plan.tokens, true, options);
        return writer.toOwnedSlice(allocator);
    }
    var offset: usize = 0;
    while (offset < input.len) {
        const remaining = input.len - offset;
        const n = chooseAdaptiveBlockLen(input[offset..], min_block_len, max_block_len, split_options.sample_len);
        const chunk_len = @min(n, remaining);
        const chunk = input[offset..][0..chunk_len];
        const final = offset + chunk_len == input.len;
        const plan = try planTokensAlloc(allocator, chunk, options);
        defer plan.deinit(allocator);
        try writeBestTokensBlock(allocator, &writer, chunk, plan.tokens, final, options);
        offset += chunk_len;
    }
    return writer.toOwnedSlice(allocator);
}

fn chooseAdaptiveBlockLen(input: []const u8, min_block_len: usize, max_block_len: usize, sample_len: usize) usize {
    if (input.len <= min_block_len) return input.len;
    const sample = input[0..@min(input.len, @max(sample_len, 1))];
    const unique = uniqueByteCount(sample);
    if (unique <= 4 and input.len >= min_block_len) return min_block_len;
    if (unique <= 32) return @min(input.len, @max(min_block_len, max_block_len / 2));
    return @min(input.len, max_block_len);
}

fn uniqueByteCount(input: []const u8) usize {
    var seen: [256]bool = @splat(false);
    var count: usize = 0;
    for (input) |byte| {
        if (!seen[byte]) {
            seen[byte] = true;
            count += 1;
        }
    }
    return count;
}

fn writeBestTokensBlock(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, plain: []const u8, tokens: []const lz77.Token, final: bool, options: CompressionOptions) !void {
    const stored_len = storedBlockEncodedSizeFromState(writer.*, plain.len);
    const fixed = try encodeRawFixedTokensFinalAlloc(allocator, tokens, final);
    defer allocator.free(fixed);

    if (options.block_selection == .stored_fixed) {
        if (stored_len <= fixed.len) {
            return writeStoredBlock(allocator, writer, plain, final);
        }
        return writeFixedTokens(allocator, writer, tokens, final);
    }

    const dynamic = try encodeRawDynamicTokensFinalAlloc(allocator, tokens, final);
    defer allocator.free(dynamic);
    if (stored_len <= fixed.len and stored_len <= dynamic.len) {
        return writeStoredBlock(allocator, writer, plain, final);
    }
    if (fixed.len <= dynamic.len) {
        return writeFixedTokens(allocator, writer, tokens, final);
    }
    return writeDynamicTokens(allocator, writer, tokens, final);
}

fn storedBlockEncodedSizeFromState(writer: bitstream.BitWriter, input_len: usize) usize {
    return input_len + 5 + @intFromBool(writer.bit_index != 0);
}

fn writeStoredBlock(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, input: []const u8, final: bool) !void {
    if (input.len > max_stored_block_len) return error.InvalidBlockPlan;
    try writer.alignToByte(allocator);
    var header: [5]u8 = undefined;
    writeStoredHeader(final, @intCast(input.len), &header);
    try writer.bytes.appendSlice(allocator, &header);
    try writer.bytes.appendSlice(allocator, input);
}

pub fn encodeRawFixedSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    var offset: usize = 0;
    if (input.len == 0) {
        const plan = try lz77.hashGreedyPlanAlloc(allocator, "", options.lz77_options);
        defer plan.deinit(allocator);
        try writeFixedTokens(allocator, &writer, plan.tokens, true);
        return writer.toOwnedSlice(allocator);
    }
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const final = offset + n == input.len;
        const plan = try planTokensAlloc(allocator, input[offset..][0..n], options);
        defer plan.deinit(allocator);
        try writeFixedTokens(allocator, &writer, plan.tokens, final);
        offset += n;
    }
    return writer.toOwnedSlice(allocator);
}

pub fn encodeRawDynamicLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var tokens: std.ArrayList(lz77.Token) = .empty;
    defer tokens.deinit(allocator);
    for (input) |byte| try tokens.append(allocator, .{ .literal = byte });
    return encodeRawDynamicTokensAlloc(allocator, tokens.items);
}

pub fn encodeRawDynamicWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeRawDynamicTokensAlloc(allocator, plan.tokens);
}

const CodeLengthOp = struct {
    symbol: u8,
    extra_bits: u6 = 0,
    extra_value: u8 = 0,
};

fn buildCodeLengthOpsAlloc(allocator: std.mem.Allocator, lit_lengths: []const u4, dist_lengths: []const u4) ![]CodeLengthOp {
    var ops: std.ArrayList(CodeLengthOp) = .empty;
    errdefer ops.deinit(allocator);
    try appendCodeLengthOps(allocator, &ops, lit_lengths);
    try appendCodeLengthOps(allocator, &ops, dist_lengths);
    return ops.toOwnedSlice(allocator);
}

fn appendCodeLengthOps(allocator: std.mem.Allocator, ops: *std.ArrayList(CodeLengthOp), lengths: []const u4) !void {
    var i: usize = 0;
    while (i < lengths.len) {
        const value = lengths[i];
        var run: usize = 1;
        while (i + run < lengths.len and lengths[i + run] == value) run += 1;
        if (value == 0) {
            var remaining = run;
            while (remaining >= 11) {
                const count = @min(remaining, 138);
                try ops.append(allocator, .{ .symbol = 18, .extra_bits = 7, .extra_value = @intCast(count - 11) });
                remaining -= count;
            }
            if (remaining >= 3) {
                try ops.append(allocator, .{ .symbol = 17, .extra_bits = 3, .extra_value = @intCast(remaining - 3) });
                remaining = 0;
            }
            while (remaining > 0) : (remaining -= 1) try ops.append(allocator, .{ .symbol = 0 });
        } else {
            try ops.append(allocator, .{ .symbol = value });
            var remaining = run - 1;
            while (remaining >= 3) {
                const count = @min(remaining, 6);
                try ops.append(allocator, .{ .symbol = 16, .extra_bits = 2, .extra_value = @intCast(count - 3) });
                remaining -= count;
            }
            while (remaining > 0) : (remaining -= 1) try ops.append(allocator, .{ .symbol = value });
        }
        i += run;
    }
}

pub fn encodeRawDynamicTokensAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token) ![]u8 {
    return encodeRawDynamicTokensFinalAlloc(allocator, tokens, true);
}

fn encodeRawDynamicTokensFinalAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token, final: bool) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeDynamicTokens(allocator, &writer, tokens, final);
    return writer.toOwnedSlice(allocator);
}

fn writeDynamicTokens(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, tokens: []const lz77.Token, final: bool) !void {
    var lit_freqs: [286]u32 = @splat(0);
    var dist_freqs: [30]u32 = @splat(0);
    for (tokens) |token| switch (token) {
        .literal => |byte| lit_freqs[byte] += 1,
        .match => |m| {
            const len_code = lengthCode(m.length);
            const dist_code = distanceCode(m.distance);
            lit_freqs[len_code.symbol] += 1;
            dist_freqs[dist_code.symbol] += 1;
        },
    };
    lit_freqs[256] = 1;
    completeLiteralFrequencySet(&lit_freqs);
    if (!dynamicDistanceSafe(&dist_freqs)) return writeFixedTokens(allocator, writer, tokens, final);
    completeDistanceFrequencySet(&dist_freqs);

    var lit_lengths_full = huffman.simpleCodeLengths(286, &lit_freqs, 15);
    var dist_lengths_full = huffman.simpleCodeLengths(30, &dist_freqs, 15);
    const hlit: usize = trimCodeLengthCount(286, 257, &lit_lengths_full);
    const hdist: usize = trimCodeLengthCount(30, 1, &dist_lengths_full);

    const code_len_ops = try buildCodeLengthOpsAlloc(allocator, lit_lengths_full[0..hlit], dist_lengths_full[0..hdist]);
    defer allocator.free(code_len_ops);
    var code_len_freqs: [19]u32 = @splat(0);
    for (code_len_ops) |op| code_len_freqs[op.symbol] += 1;
    completeCodeLengthFrequencySet(&code_len_freqs);
    var code_len_lengths = huffman.simpleCodeLengths(19, &code_len_freqs, 7);
    var hclen: usize = 4;
    for (huffman.code_length_order, 0..) |symbol, i| {
        if (code_len_lengths[symbol] != 0) hclen = @max(hclen, i + 1);
    }

    const lit_encoder = try huffman.HuffmanTable(286).Encoder.init(lit_lengths_full[0..hlit]);
    const dist_encoder = try huffman.HuffmanTable(30).Encoder.init(dist_lengths_full[0..hdist]);
    const code_len_encoder = try huffman.CodeLengthTable.Encoder.init(&code_len_lengths);

    try writer.writeBits(allocator, @intFromBool(final), 1);
    try writer.writeBits(allocator, 0b10, 2);
    try writer.writeBits(allocator, @intCast(hlit - 257), 5);
    try writer.writeBits(allocator, @intCast(hdist - 1), 5);
    try writer.writeBits(allocator, @intCast(hclen - 4), 4);
    for (huffman.code_length_order[0..hclen]) |symbol| try writer.writeBits(allocator, code_len_lengths[symbol], 3);
    for (code_len_ops) |op| {
        try code_len_encoder.writeSymbol(writer, allocator, op.symbol);
        if (op.extra_bits != 0) try writer.writeBits(allocator, op.extra_value, op.extra_bits);
    }
    for (tokens) |token| switch (token) {
        .literal => |byte| try lit_encoder.writeSymbol(writer, allocator, byte),
        .match => |m| {
            const len_code = lengthCode(m.length);
            try lit_encoder.writeSymbol(writer, allocator, len_code.symbol);
            if (len_code.extra_bits != 0) try writer.writeBits(allocator, len_code.extra_value, len_code.extra_bits);
            const dist_code = distanceCode(m.distance);
            try dist_encoder.writeSymbol(writer, allocator, dist_code.symbol);
            if (dist_code.extra_bits != 0) try writer.writeBits(allocator, dist_code.extra_value, dist_code.extra_bits);
        },
    };
    try lit_encoder.writeSymbol(writer, allocator, 256);
}

pub fn encodeRawDynamicSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    var offset: usize = 0;
    if (input.len == 0) {
        const plan = try lz77.hashGreedyPlanAlloc(allocator, "", options.lz77_options);
        defer plan.deinit(allocator);
        try writeDynamicTokens(allocator, &writer, plan.tokens, true);
        return writer.toOwnedSlice(allocator);
    }
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const final = offset + n == input.len;
        const plan = try planTokensAlloc(allocator, input[offset..][0..n], options);
        defer plan.deinit(allocator);
        try writeDynamicTokens(allocator, &writer, plan.tokens, final);
        offset += n;
    }
    return writer.toOwnedSlice(allocator);
}

fn trimCodeLengthCount(comptime n: usize, minimum: usize, lengths: *[n]u4) usize {
    var count = n;
    while (count > minimum and lengths[count - 1] == 0) count -= 1;
    return count;
}

fn completeLiteralFrequencySet(freqs: *[286]u32) void {
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq != 0) active += 1;
    }
    var target: usize = 2;
    while (target < active) target <<= 1;
    var symbol: usize = 0;
    while (active < target and symbol < freqs.len) : (symbol += 1) {
        if (freqs[symbol] == 0) {
            freqs[symbol] = 1;
            active += 1;
        }
    }
}

fn completeDistanceFrequencySet(freqs: *[30]u32) void {
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq != 0) active += 1;
    }
    if (active == 0) {
        freqs[0] = 1;
        freqs[1] = 1;
        active = 2;
    }
    var target: usize = 2;
    while (target < active) target <<= 1;
    var symbol: usize = 0;
    while (active < target and symbol < freqs.len) : (symbol += 1) {
        if (freqs[symbol] == 0) {
            freqs[symbol] = 1;
            active += 1;
        }
    }
}

fn dynamicDistanceSafe(freqs: *const [30]u32) bool {
    var active: usize = 0;
    var max_symbol: usize = 0;
    for (freqs, 0..) |freq, i| {
        if (freq != 0) {
            active += 1;
            max_symbol = i;
        }
    }
    return active <= 8 and max_symbol <= 7;
}

fn completeCodeLengthFrequencySet(freqs: *[19]u32) void {
    var active: usize = 0;
    for (freqs.*) |freq| {
        if (freq != 0) active += 1;
    }
    var target: usize = 2;
    while (target < active) target <<= 1;
    var symbol: usize = 0;
    while (active < target and symbol < freqs.len) : (symbol += 1) {
        if (freqs[symbol] == 0) {
            freqs[symbol] = 1;
            active += 1;
        }
    }
}

pub fn encodeRawFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeRawFixedWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeRawFixedWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const plan = try planTokensAlloc(allocator, input, options);
    defer plan.deinit(allocator);
    return encodeRawFixedTokensAlloc(allocator, plan.tokens);
}

fn writeFixedTokens(allocator: std.mem.Allocator, writer: *bitstream.BitWriter, tokens: []const lz77.Token, final: bool) !void {
    const lit_lengths = huffman.fixedLiteralLengths();
    const lit_encoder = try huffman.FixedLiteralTable.Encoder.init(&lit_lengths);
    const dist_lengths = huffman.fixedDistanceLengths();
    const dist_encoder = try huffman.FixedDistanceTable.Encoder.init(&dist_lengths);
    try writer.writeBits(allocator, @intFromBool(final), 1);
    try writer.writeBits(allocator, 0b01, 2);
    for (tokens) |token| {
        switch (token) {
            .literal => |byte| try lit_encoder.writeSymbol(writer, allocator, byte),
            .match => |m| {
                const len_code = lengthCode(m.length);
                try lit_encoder.writeSymbol(writer, allocator, len_code.symbol);
                if (len_code.extra_bits != 0) try writer.writeBits(allocator, len_code.extra_value, len_code.extra_bits);
                const dist_code = distanceCode(m.distance);
                try dist_encoder.writeSymbol(writer, allocator, dist_code.symbol);
                if (dist_code.extra_bits != 0) try writer.writeBits(allocator, dist_code.extra_value, dist_code.extra_bits);
            },
        }
    }
    try lit_encoder.writeSymbol(writer, allocator, 256);
}

pub fn encodeRawFixedTokensAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token) ![]u8 {
    return encodeRawFixedTokensFinalAlloc(allocator, tokens, true);
}

fn encodeRawFixedTokensFinalAlloc(allocator: std.mem.Allocator, tokens: []const lz77.Token, final: bool) ![]u8 {
    var writer = bitstream.BitWriter{};
    errdefer writer.deinit(allocator);
    try writeFixedTokens(allocator, &writer, tokens, final);
    return writer.toOwnedSlice(allocator);
}

const CodeExtra = struct {
    symbol: u16,
    extra_bits: u6,
    extra_value: u16,
};

fn lengthCode(length: u16) CodeExtra {
    for (length_table, 0..) |entry, i| {
        const span: u16 = if (entry.extra_bits == 0) 1 else @as(u16, 1) << @intCast(entry.extra_bits);
        if (length >= entry.base and length < entry.base + span) {
            return .{ .symbol = @intCast(257 + i), .extra_bits = entry.extra_bits, .extra_value = length - entry.base };
        }
    }
    unreachable;
}

fn distanceCode(distance: u16) CodeExtra {
    for (distance_table, 0..) |entry, i| {
        const span: u16 = if (entry.extra_bits == 0) 1 else @as(u16, 1) << @intCast(entry.extra_bits);
        if (distance >= entry.base and distance < entry.base + span) {
            return .{ .symbol = @intCast(i), .extra_bits = entry.extra_bits, .extra_value = distance - entry.base };
        }
    }
    unreachable;
}

pub fn decodeRawFixed(input: []const u8, output: []u8) Error!DecodeResult {
    var reader = bitstream.BitReader.init(input);
    const final = try reader.readBits(u1, 1);
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b01) return error.InvalidDeflateBlockType;

    const lit_table = try huffman.fixedLiteralTable();
    const dist_table = try huffman.fixedDistanceTable();
    var out_offset: usize = 0;
    while (true) {
        const symbol = (try lit_table.decode(&reader)).value;
        if (symbol < 256) {
            if (out_offset == output.len) return error.OutputTooSmall;
            output[out_offset] = @intCast(symbol);
            out_offset += 1;
        } else if (symbol == 256) {
            _ = final;
            return .{ .input_read = reader.byteOffset(), .output_written = out_offset };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_table.decode(&reader)).value;
            const distance = try decodeDistance(distance_symbol, &reader);
            try copyMatch(output[0..out_offset], output[out_offset..], length, distance);
            out_offset += length;
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

pub fn decodeRawFixedAlloc(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.ensureTotalCapacity(allocator, @min(input.len * 4, 1 << 20));

    var reader = bitstream.BitReader.init(input);
    const final = try reader.readBits(u1, 1);
    const block_type = try reader.readBits(u2, 2);
    if (block_type != 0b01) return error.InvalidDeflateBlockType;

    const lit_table = try huffman.fixedLiteralTable();
    const dist_table = try huffman.fixedDistanceTable();
    while (true) {
        const symbol = (try lit_table.decode(&reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            _ = final;
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_table.decode(&reader)).value;
            const distance = try decodeDistance(distance_symbol, &reader);
            try appendMatch(allocator, &out, length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

pub fn decodeRawFixedAllocStrict(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawFixedAlloc(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawDynamicAlloc(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var reader = bitstream.BitReader.init(input);
    const parsed = try huffman.parseDynamicLengths(&reader);
    const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
    const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);

    while (true) {
        const symbol = (try lit_table.decode(&reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, &reader);
            const distance_symbol = (try dist_table.decode(&reader)).value;
            const distance = try decodeDistance(distance_symbol, &reader);
            try appendMatch(allocator, &out, length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

pub fn decodeRawDynamicAllocStrict(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawDynamicAlloc(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn decodeRawAutoAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    if (input.len == 0) return error.TruncatedFrame;
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var reader = bitstream.BitReader.init(input);
    while (true) {
        const final = (try reader.readBits(u1, 1)) != 0;
        const block_type = try reader.readBits(u2, 2);
        switch (block_type) {
            0 => try decodeStoredBlockFromReader(allocator, &reader, &out),
            1 => try decodeFixedBlockFromReader(allocator, &reader, &out),
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(final, &reader);
                const lit_table = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const dist_table = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                try decodeCompressedBlockFromReader(allocator, &reader, &out, &lit_table, &dist_table);
            },
            else => return error.InvalidDeflateBlockType,
        }
        if (final) return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = reader.byteOffset() };
    }
}

pub fn decodeRawAutoAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawAutoAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

pub fn rawStoredEncodedSize(input_len: usize) Error!usize {
    const blocks: usize = if (input_len == 0) 1 else ((input_len - 1) / max_stored_block_len) + 1;
    const header_bytes = std.math.mul(usize, blocks, 5) catch return error.IntegerOverflow;
    return std.math.add(usize, input_len, header_bytes) catch error.IntegerOverflow;
}

pub fn encodeRawStored(input: []const u8, output: []u8) Error!usize {
    const required = try rawStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    var in_offset: usize = 0;
    var out_offset: usize = 0;
    if (input.len == 0) {
        writeStoredHeader(true, 0, output[0..5]);
        return 5;
    }

    while (in_offset < input.len) {
        const chunk_len = @min(max_stored_block_len, input.len - in_offset);
        const final = in_offset + chunk_len == input.len;
        writeStoredHeader(final, @intCast(chunk_len), output[out_offset..][0..5]);
        out_offset += 5;
        @memcpy(output[out_offset..][0..chunk_len], input[in_offset..][0..chunk_len]);
        out_offset += chunk_len;
        in_offset += chunk_len;
    }
    return out_offset;
}

pub fn encodeRawStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try rawStoredEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeRawStored(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn decodeRawStored(input: []const u8, output: []u8) Error!DecodeResult {
    var in_offset: usize = 0;
    var out_offset: usize = 0;

    while (true) {
        if (input.len - in_offset < 5) return error.TruncatedFrame;
        const header = input[in_offset];
        if (((header >> 1) & 0b11) != 0) return error.InvalidDeflateBlockType;
        if ((header & 0b1111_1000) != 0) return error.CorruptFrame;
        const final = (header & 1) != 0;
        in_offset += 1;

        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, input[in_offset + 2 ..][0..2], .little);
        in_offset += 4;
        if (nlen != ~len) return error.StoredLengthMismatch;

        const chunk_len: usize = len;
        if (input.len - in_offset < chunk_len) return error.TruncatedFrame;
        if (output.len - out_offset < chunk_len) return error.OutputTooSmall;
        @memcpy(output[out_offset..][0..chunk_len], input[in_offset..][0..chunk_len]);
        in_offset += chunk_len;
        out_offset += chunk_len;

        if (final) return .{ .input_read = in_offset, .output_written = out_offset };
    }
}

pub fn decodeRawStoredAllocPartial(allocator: std.mem.Allocator, input: []const u8) !OwnedDecodeResult {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var in_offset: usize = 0;
    while (true) {
        if (input.len - in_offset < 5) return error.TruncatedFrame;
        const header = input[in_offset];
        if (((header >> 1) & 0b11) != 0) return error.InvalidDeflateBlockType;
        if ((header & 0b1111_1000) != 0) return error.CorruptFrame;
        const final = (header & 1) != 0;
        in_offset += 1;

        const len = std.mem.readInt(u16, input[in_offset..][0..2], .little);
        const nlen = std.mem.readInt(u16, input[in_offset + 2 ..][0..2], .little);
        in_offset += 4;
        if (nlen != ~len) return error.StoredLengthMismatch;

        const chunk_len: usize = len;
        if (input.len - in_offset < chunk_len) return error.TruncatedFrame;
        try out.appendSlice(allocator, input[in_offset..][0..chunk_len]);
        in_offset += chunk_len;

        if (final) {
            return .{ .bytes = try out.toOwnedSlice(allocator), .input_read = in_offset };
        }
    }
}

pub fn decodeRawStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const result = try decodeRawStoredAllocPartial(allocator, input);
    errdefer result.deinit(allocator);
    if (result.input_read != input.len) return error.TrailingData;
    return result.bytes;
}

fn decodeStoredBlockFromReader(allocator: std.mem.Allocator, reader: *bitstream.BitReader, out: *std.ArrayList(u8)) !void {
    reader.alignToByte();
    const offset = reader.byte_index;
    if (reader.input.len - offset < 4) return error.TruncatedFrame;
    const len = std.mem.readInt(u16, reader.input[offset..][0..2], .little);
    const nlen = std.mem.readInt(u16, reader.input[offset + 2 ..][0..2], .little);
    if (nlen != ~len) return error.StoredLengthMismatch;
    const chunk_len: usize = len;
    if (reader.input.len - offset - 4 < chunk_len) return error.TruncatedFrame;
    try out.appendSlice(allocator, reader.input[offset + 4 ..][0..chunk_len]);
    reader.byte_index = offset + 4 + chunk_len;
    reader.bit_index = 0;
}

fn decodeFixedBlockFromReader(allocator: std.mem.Allocator, reader: *bitstream.BitReader, out: *std.ArrayList(u8)) !void {
    while (true) {
        const symbol = (try huffman.decodeFixedLiteralFast(reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try huffman.decodeFixedDistanceFast(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatch(allocator, out, length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeCompressedBlockFromReader(
    allocator: std.mem.Allocator,
    reader: *bitstream.BitReader,
    out: *std.ArrayList(u8),
    lit_table: anytype,
    dist_table: anytype,
) !void {
    while (true) {
        const symbol = (try lit_table.decode(reader)).value;
        if (symbol < 256) {
            try out.append(allocator, @intCast(symbol));
        } else if (symbol == 256) {
            return;
        } else if (symbol <= 285) {
            const length = try decodeLength(symbol, reader);
            const distance_symbol = (try dist_table.decode(reader)).value;
            const distance = try decodeDistance(distance_symbol, reader);
            try appendMatch(allocator, out, length, distance);
        } else {
            return error.InvalidHuffmanCode;
        }
    }
}

fn decodeLength(symbol: u16, reader: *bitstream.BitReader) Error!usize {
    if (symbol < 257 or symbol > 285) return error.InvalidHuffmanCode;
    const index = symbol - 257;
    const entry = length_table[index];
    const extra = if (entry.extra_bits == 0) 0 else try reader.readBits(u16, entry.extra_bits);
    return entry.base + extra;
}

fn decodeDistance(symbol: u16, reader: *bitstream.BitReader) Error!usize {
    if (symbol >= distance_table.len) return error.InvalidHuffmanCode;
    const entry = distance_table[symbol];
    const extra = if (entry.extra_bits == 0) 0 else try reader.readBits(u16, entry.extra_bits);
    return entry.base + extra;
}

fn copyMatch(history: []const u8, dest: []u8, length: usize, distance: usize) Error!void {
    if (distance == 0 or distance > history.len) return error.InvalidMatch;
    if (dest.len < length) return error.OutputTooSmall;
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const absolute = history.len + i - distance;
        dest[i] = if (absolute < history.len) history[absolute] else dest[absolute - history.len];
    }
}

fn appendMatch(allocator: std.mem.Allocator, out: *std.ArrayList(u8), length: usize, distance: usize) !void {
    if (distance == 0 or distance > out.items.len) return error.InvalidMatch;
    try out.ensureUnusedCapacity(allocator, length);
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const index = out.items.len - distance;
        out.appendAssumeCapacity(out.items[index]);
    }
}

const LengthEntry = struct { base: u16, extra_bits: u6 };
const length_table = [_]LengthEntry{
    .{ .base = 3, .extra_bits = 0 },
    .{ .base = 4, .extra_bits = 0 },
    .{ .base = 5, .extra_bits = 0 },
    .{ .base = 6, .extra_bits = 0 },
    .{ .base = 7, .extra_bits = 0 },
    .{ .base = 8, .extra_bits = 0 },
    .{ .base = 9, .extra_bits = 0 },
    .{ .base = 10, .extra_bits = 0 },
    .{ .base = 11, .extra_bits = 1 },
    .{ .base = 13, .extra_bits = 1 },
    .{ .base = 15, .extra_bits = 1 },
    .{ .base = 17, .extra_bits = 1 },
    .{ .base = 19, .extra_bits = 2 },
    .{ .base = 23, .extra_bits = 2 },
    .{ .base = 27, .extra_bits = 2 },
    .{ .base = 31, .extra_bits = 2 },
    .{ .base = 35, .extra_bits = 3 },
    .{ .base = 43, .extra_bits = 3 },
    .{ .base = 51, .extra_bits = 3 },
    .{ .base = 59, .extra_bits = 3 },
    .{ .base = 67, .extra_bits = 4 },
    .{ .base = 83, .extra_bits = 4 },
    .{ .base = 99, .extra_bits = 4 },
    .{ .base = 115, .extra_bits = 4 },
    .{ .base = 131, .extra_bits = 5 },
    .{ .base = 163, .extra_bits = 5 },
    .{ .base = 195, .extra_bits = 5 },
    .{ .base = 227, .extra_bits = 5 },
    .{ .base = 258, .extra_bits = 0 },
};

const DistanceEntry = struct { base: u16, extra_bits: u6 };
const distance_table = [_]DistanceEntry{
    .{ .base = 1, .extra_bits = 0 },
    .{ .base = 2, .extra_bits = 0 },
    .{ .base = 3, .extra_bits = 0 },
    .{ .base = 4, .extra_bits = 0 },
    .{ .base = 5, .extra_bits = 1 },
    .{ .base = 7, .extra_bits = 1 },
    .{ .base = 9, .extra_bits = 2 },
    .{ .base = 13, .extra_bits = 2 },
    .{ .base = 17, .extra_bits = 3 },
    .{ .base = 25, .extra_bits = 3 },
    .{ .base = 33, .extra_bits = 4 },
    .{ .base = 49, .extra_bits = 4 },
    .{ .base = 65, .extra_bits = 5 },
    .{ .base = 97, .extra_bits = 5 },
    .{ .base = 129, .extra_bits = 6 },
    .{ .base = 193, .extra_bits = 6 },
    .{ .base = 257, .extra_bits = 7 },
    .{ .base = 385, .extra_bits = 7 },
    .{ .base = 513, .extra_bits = 8 },
    .{ .base = 769, .extra_bits = 8 },
    .{ .base = 1025, .extra_bits = 9 },
    .{ .base = 1537, .extra_bits = 9 },
    .{ .base = 2049, .extra_bits = 10 },
    .{ .base = 3073, .extra_bits = 10 },
    .{ .base = 4097, .extra_bits = 11 },
    .{ .base = 6145, .extra_bits = 11 },
    .{ .base = 8193, .extra_bits = 12 },
    .{ .base = 12289, .extra_bits = 12 },
    .{ .base = 16385, .extra_bits = 13 },
    .{ .base = 24577, .extra_bits = 13 },
};

pub fn zlibStoredEncodedSize(input_len: usize) Error!usize {
    const raw_len = try rawStoredEncodedSize(input_len);
    const with_header = std.math.add(usize, 2, raw_len) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 4) catch error.IntegerOverflow;
}

pub fn encodeZlibStored(input: []const u8, output: []u8) Error!usize {
    const required = try zlibStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    output[0] = 0x78; // deflate, 32 KiB window
    output[1] = 0x01; // fastest/no compression, valid FCHECK
    const raw_written = try encodeRawStored(input, output[2 .. required - 4]);
    const footer_offset = 2 + raw_written;
    std.mem.writeInt(u32, output[footer_offset..][0..4], checksum.adler32(input), .big);
    return footer_offset + 4;
}

pub fn encodeZlibStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try zlibStoredEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeZlibStored(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn encodeZlibFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeZlibFixedWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeZlibFixedWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawFixedWithOptionsAlloc(allocator, input, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, 2 + raw.len + 4);
    errdefer allocator.free(out);
    out[0] = 0x78;
    out[1] = 0x01;
    @memcpy(out[2..][0..raw.len], raw);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

pub fn encodeZlibDynamicLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeZlibDynamicWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeZlibDynamicWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawDynamicWithOptionsAlloc(allocator, input, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, 2 + raw.len + 4);
    errdefer allocator.free(out);
    out[0] = 0x78;
    out[1] = 0x01;
    @memcpy(out[2..][0..raw.len], raw);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

pub fn encodeZlibBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawBestAlloc(allocator, input, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, 2 + raw.len + 4);
    errdefer allocator.free(out);
    out[0] = 0x78;
    out[1] = 0x01;
    @memcpy(out[2..][0..raw.len], raw);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

pub fn encodeZlibBestSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawBestSplitAlloc(allocator, input, block_len, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, 2 + raw.len + 4);
    errdefer allocator.free(out);
    out[0] = 0x78;
    out[1] = 0x01;
    @memcpy(out[2..][0..raw.len], raw);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

pub fn encodeZlibBestAdaptiveSplitAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    const raw = try encodeRawBestAdaptiveSplitAlloc(allocator, input, options, split_options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, 2 + raw.len + 4);
    errdefer allocator.free(out);
    out[0] = 0x78;
    out[1] = 0x01;
    @memcpy(out[2..][0..raw.len], raw);
    std.mem.writeInt(u32, out[2 + raw.len ..][0..4], checksum.adler32(input), .big);
    return out;
}

pub fn decodeZlibStored(input: []const u8, output: []u8) Error!usize {
    if (input.len < 2) return error.TruncatedFrame;
    try validateZlibHeader(input[0], input[1]);

    const raw = try decodeRawStored(input[2..], output);
    const footer_offset = 2 + raw.input_read;
    if (input.len - footer_offset < 4) return error.TruncatedFrame;
    const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
    if (checksum.adler32(output[0..raw.output_written]) != expected) return error.ChecksumMismatch;
    if (footer_offset + 4 != input.len) return error.TrailingData;
    return raw.output_written;
}

pub fn decodeZlibStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const scratch = try allocator.alloc(u8, input.len);
    defer allocator.free(scratch);
    const written = try decodeZlibStored(input, scratch);
    const out = try allocator.alloc(u8, written);
    errdefer allocator.free(out);
    @memcpy(out, scratch[0..written]);
    return out;
}

pub fn decodeZlibAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len < 2) return error.TruncatedFrame;
    try validateZlibHeader(input[0], input[1]);

    const raw = try decodeRawAutoAllocPartial(allocator, input[2..]);
    errdefer raw.deinit(allocator);
    const footer_offset = 2 + raw.input_read;
    if (input.len - footer_offset < 4) return error.TruncatedFrame;
    const expected = std.mem.readInt(u32, input[footer_offset..][0..4], .big);
    if (checksum.adler32(raw.bytes) != expected) return error.ChecksumMismatch;
    if (footer_offset + 4 != input.len) return error.TrailingData;
    return raw.bytes;
}

pub fn gzipStoredEncodedSize(input_len: usize) Error!usize {
    const raw_len = try rawStoredEncodedSize(input_len);
    const with_header = std.math.add(usize, 10, raw_len) catch return error.IntegerOverflow;
    return std.math.add(usize, with_header, 8) catch error.IntegerOverflow;
}

pub fn encodeGzipStored(input: []const u8, output: []u8) Error!usize {
    const required = try gzipStoredEncodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;

    @memcpy(output[0..10], &gzip_header);
    const raw_written = try encodeRawStored(input, output[10 .. required - 8]);
    const footer_offset = 10 + raw_written;
    std.mem.writeInt(u32, output[footer_offset..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, output[footer_offset + 4 ..][0..4], @truncate(input.len), .little);
    return footer_offset + 8;
}

pub fn encodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try gzipStoredEncodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeGzipStored(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn encodeGzipFixedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeGzipFixedWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeGzipFixedWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawFixedWithOptionsAlloc(allocator, input, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, gzip_header.len + raw.len + 8);
    errdefer allocator.free(out);
    @memcpy(out[0..gzip_header.len], &gzip_header);
    @memcpy(out[gzip_header.len..][0..raw.len], raw);
    const footer = gzip_header.len + raw.len;
    std.mem.writeInt(u32, out[footer..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, out[footer + 4 ..][0..4], @truncate(input.len), .little);
    return out;
}

pub fn encodeGzipDynamicLiteralAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    return encodeGzipDynamicWithOptionsAlloc(allocator, input, .{});
}

pub fn encodeGzipDynamicWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawDynamicWithOptionsAlloc(allocator, input, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, gzip_header.len + raw.len + 8);
    errdefer allocator.free(out);
    @memcpy(out[0..gzip_header.len], &gzip_header);
    @memcpy(out[gzip_header.len..][0..raw.len], raw);
    const footer = gzip_header.len + raw.len;
    std.mem.writeInt(u32, out[footer..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, out[footer + 4 ..][0..4], @truncate(input.len), .little);
    return out;
}

pub fn encodeGzipBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawBestAlloc(allocator, input, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, gzip_header.len + raw.len + 8);
    errdefer allocator.free(out);
    @memcpy(out[0..gzip_header.len], &gzip_header);
    @memcpy(out[gzip_header.len..][0..raw.len], raw);
    const footer = gzip_header.len + raw.len;
    std.mem.writeInt(u32, out[footer..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, out[footer + 4 ..][0..4], @truncate(input.len), .little);
    return out;
}

pub fn encodeGzipBestSplitAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: CompressionOptions) ![]u8 {
    const raw = try encodeRawBestSplitAlloc(allocator, input, block_len, options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, gzip_header.len + raw.len + 8);
    errdefer allocator.free(out);
    @memcpy(out[0..gzip_header.len], &gzip_header);
    @memcpy(out[gzip_header.len..][0..raw.len], raw);
    const footer = gzip_header.len + raw.len;
    std.mem.writeInt(u32, out[footer..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, out[footer + 4 ..][0..4], @truncate(input.len), .little);
    return out;
}

pub fn encodeGzipBestAdaptiveSplitAlloc(allocator: std.mem.Allocator, input: []const u8, options: CompressionOptions, split_options: AdaptiveSplitOptions) ![]u8 {
    const raw = try encodeRawBestAdaptiveSplitAlloc(allocator, input, options, split_options);
    defer allocator.free(raw);
    const out = try allocator.alloc(u8, gzip_header.len + raw.len + 8);
    errdefer allocator.free(out);
    @memcpy(out[0..gzip_header.len], &gzip_header);
    @memcpy(out[gzip_header.len..][0..raw.len], raw);
    const footer = gzip_header.len + raw.len;
    std.mem.writeInt(u32, out[footer..][0..4], checksum.crc32(input), .little);
    std.mem.writeInt(u32, out[footer + 4 ..][0..4], @truncate(input.len), .little);
    return out;
}

pub fn decodeGzipStored(input: []const u8, output: []u8) Error!usize {
    const data_offset = try parseGzipHeader(input);

    const raw = try decodeRawStored(input[data_offset..], output);
    const footer_offset = data_offset + raw.input_read;
    if (input.len - footer_offset < 8) return error.TruncatedFrame;
    const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
    const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
    const payload = output[0..raw.output_written];
    if (checksum.crc32(payload) != expected_crc) return error.ChecksumMismatch;
    if (@as(u32, @truncate(raw.output_written)) != expected_size) return error.SizeMismatch;
    if (footer_offset + 8 != input.len) return error.TrailingData;
    return raw.output_written;
}

pub fn decodeGzipStoredAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const scratch = try allocator.alloc(u8, input.len);
    defer allocator.free(scratch);
    const written = try decodeGzipStored(input, scratch);
    const out = try allocator.alloc(u8, written);
    errdefer allocator.free(out);
    @memcpy(out, scratch[0..written]);
    return out;
}

pub fn decodeGzipConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const data_offset = try parseGzipHeader(input[offset..]);
        const raw = try decodeRawAutoAllocPartial(allocator, input[offset + data_offset ..]);
        defer raw.deinit(allocator);
        const footer_offset = offset + data_offset + raw.input_read;
        if (input.len - footer_offset < 8) return error.TruncatedFrame;
        const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
        const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
        if (checksum.crc32(raw.bytes) != expected_crc) return error.ChecksumMismatch;
        if (@as(u32, @truncate(raw.bytes.len)) != expected_size) return error.SizeMismatch;
        try out.appendSlice(allocator, raw.bytes);
        offset = footer_offset + 8;
    }
    return out.toOwnedSlice(allocator);
}

pub fn decodeGzipAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const data_offset = try parseGzipHeader(input);

    const raw = try decodeRawAutoAllocPartial(allocator, input[data_offset..]);
    errdefer raw.deinit(allocator);
    const footer_offset = data_offset + raw.input_read;
    if (input.len - footer_offset < 8) return error.TruncatedFrame;
    const expected_crc = std.mem.readInt(u32, input[footer_offset..][0..4], .little);
    const expected_size = std.mem.readInt(u32, input[footer_offset + 4 ..][0..4], .little);
    if (checksum.crc32(raw.bytes) != expected_crc) return error.ChecksumMismatch;
    if (@as(u32, @truncate(raw.bytes.len)) != expected_size) return error.SizeMismatch;
    if (footer_offset + 8 != input.len) return error.TrailingData;
    return raw.bytes;
}

fn validateZlibHeader(cmf: u8, flg: u8) Error!void {
    if ((cmf & 0x0f) != 8) return error.BadZlibHeader;
    if ((cmf >> 4) > 7) return error.BadZlibHeader;
    const combined: u16 = (@as(u16, cmf) << 8) | flg;
    if (combined % 31 != 0) return error.BadZlibHeader;
    if ((flg & 0x20) != 0) return error.BadZlibHeader;
}

const gzip_header = [_]u8{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03 };

fn parseGzipHeader(input: []const u8) Error!usize {
    if (input.len < 10) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..2], &.{ 0x1f, 0x8b })) return error.BadGzipHeader;
    if (input[2] != 8) return error.BadGzipHeader;
    const flags = input[3];
    if ((flags & 0xe0) != 0) return error.BadGzipHeader;

    var offset: usize = 10;
    if ((flags & 0x04) != 0) {
        if (input.len - offset < 2) return error.TruncatedFrame;
        const xlen: usize = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (input.len - offset < xlen) return error.TruncatedFrame;
        offset += xlen;
    }
    if ((flags & 0x08) != 0) offset = try skipGzipZeroTerminated(input, offset);
    if ((flags & 0x10) != 0) offset = try skipGzipZeroTerminated(input, offset);
    if ((flags & 0x02) != 0) {
        if (input.len - offset < 2) return error.TruncatedFrame;
        const expected = std.mem.readInt(u16, input[offset..][0..2], .little);
        const actual: u16 = @truncate(checksum.crc32(input[0..offset]));
        if (actual != expected) return error.BadGzipHeader;
        offset += 2;
    }
    return offset;
}

fn skipGzipZeroTerminated(input: []const u8, offset: usize) Error!usize {
    var index = offset;
    while (index < input.len) : (index += 1) {
        if (input[index] == 0) return index + 1;
    }
    return error.TruncatedFrame;
}

fn writeStoredHeader(final: bool, len: u16, output: []u8) void {
    std.debug.assert(output.len >= 5);
    output[0] = @intFromBool(final);
    std.mem.writeInt(u16, output[1..3], len, .little);
    std.mem.writeInt(u16, output[3..5], ~len, .little);
}

test "raw stored deflate matches zlib level-0 vectors" {
    const empty = try encodeRawStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x00, 0x00, 0xff, 0xff }, empty);

    const one = try encodeRawStoredAlloc(std.testing.allocator, "a");
    defer std.testing.allocator.free(one);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x01, 0x00, 0xfe, 0xff, 'a' }, one);

    const hello = try encodeRawStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o' }, hello);
}

test "raw stored deflate round trips across block boundary" {
    var input: [max_stored_block_len + 3]u8 = undefined;
    for (&input, 0..) |*byte, i| byte.* = @truncate((i * 17 + 91) & 0xff);

    const encoded = try encodeRawStoredAlloc(std.testing.allocator, &input);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawStoredAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

test "raw stored deflate reports malformed blocks" {
    var invalid_type = [_]u8{ 0x03, 0x00, 0x00, 0xff, 0xff };
    var out: [8]u8 = undefined;
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawStored(&invalid_type, &out));

    var bad_nlen = [_]u8{ 0x01, 0x01, 0x00, 0xff, 0xff, 'x' };
    try std.testing.expectError(error.StoredLengthMismatch, decodeRawStored(&bad_nlen, &out));

    const valid = [_]u8{ 0x01, 0x04, 0x00, 0xfb, 0xff, 't', 'e', 's', 't' };
    try std.testing.expectError(error.OutputTooSmall, decodeRawStored(&valid, out[0..2]));
}

test "zlib stored wrapper matches level-0 vectors" {
    const empty = try encodeZlibStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, empty);

    const hello = try encodeZlibStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o', 0x06, 0x2c, 0x02, 0x15 }, hello);
}

test "zlib stored wrapper validates checksum header and trailing data" {
    const encoded = try encodeZlibStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeZlibStoredAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);

    var bad_header = try encodeZlibStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_header);
    bad_header[1] ^= 1;
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(bad_header, &out));

    var bad_checksum = try encodeZlibStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeZlibStored(bad_checksum, &out));

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodeZlibStored(with_trailing[0 .. encoded.len + 1], &out));
}

test "gzip stored wrapper matches level-0 vectors" {
    const empty = try encodeGzipStoredAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 }, empty);

    const hello = try encodeGzipStoredAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x01, 0x05, 0x00, 0xfa, 0xff, 'h', 'e', 'l', 'l', 'o', 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, hello);
}

test "gzip stored wrapper validates crc size header and trailing data" {
    const encoded = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeGzipStoredAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "payload", decoded);

    var bad_header = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_header);
    bad_header[0] = 0;
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadGzipHeader, decodeGzipStored(bad_header, &out));

    var bad_crc = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_crc);
    bad_crc[bad_crc.len - 8] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeGzipStored(bad_crc, &out));

    var bad_size = try encodeGzipStoredAlloc(std.testing.allocator, "payload");
    defer std.testing.allocator.free(bad_size);
    bad_size[bad_size.len - 4] ^= 1;
    try std.testing.expectError(error.SizeMismatch, decodeGzipStored(bad_size, &out));

    var with_trailing: [64]u8 = undefined;
    @memcpy(with_trailing[0..encoded.len], encoded);
    with_trailing[encoded.len] = 0;
    try std.testing.expectError(error.TrailingData, decodeGzipStored(with_trailing[0 .. encoded.len + 1], &out));
}

test "raw fixed Huffman literal/match inflate matches zlib fixed vectors" {
    const cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x03, 0x00 }, .plain = "" },
        .{ .compressed = &.{ 0x4b, 0x04, 0x00 }, .plain = "a" },
        .{ .compressed = &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, .plain = "hello" },
        .{ .compressed = &.{ 0x4b, 0x4c, 0x4a, 0x4e, 0x49, 0x4d, 0x03, 0x00 }, .plain = "abcdef" },
    };
    for (cases) |case| {
        var out: [64]u8 = undefined;
        const decoded = try decodeRawFixed(case.compressed, &out);
        try std.testing.expectEqualSlices(u8, case.plain, out[0..decoded.output_written]);
        const owned = try decodeRawFixedAllocStrict(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(owned);
        try std.testing.expectEqualSlices(u8, case.plain, owned);
    }
}

test "raw fixed Huffman inflate decodes back references and rejects wrong block types" {
    const cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x4b, 0x4c, 0x04, 0x01, 0x00 }, .plain = "aaaaaa" },
        .{ .compressed = &.{ 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00 }, .plain = "abcabcabcabc" },
        .{ .compressed = &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0xc8, 0x40, 0x27, 0x01 }, .plain = "hello hello hello hello" },
        .{ .compressed = &.{ 0x4b, 0x4c, 0x1c, 0x05, 0xc4, 0x86, 0x00, 0x00 }, .plain = "a" ** 300 },
    };
    for (cases) |case| {
        const decoded = try decodeRawFixedAllocStrict(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.plain, decoded);
    }

    var out: [8]u8 = undefined;
    try std.testing.expectError(error.InvalidDeflateBlockType, decodeRawFixed(&.{ 0x01, 0x00, 0x00, 0xff, 0xff }, &out));
    try std.testing.expectError(error.OutputTooSmall, decodeRawFixed(&.{ 0x4b, 0x04, 0x00 }, out[0..0]));
}

test "zlib and gzip fixed Huffman wrappers decode zlib fixed vectors" {
    const zlib_cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x78, 0x01, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15 }, .plain = "hello" },
        .{ .compressed = &.{ 0x78, 0x01, 0x4b, 0x4c, 0x04, 0x01, 0x00, 0x07, 0xfb, 0x02, 0x47 }, .plain = "aaaaaa" },
        .{ .compressed = &.{ 0x78, 0x01, 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00, 0x1d, 0xe0, 0x04, 0x99 }, .plain = "abcabcabcabc" },
    };
    for (zlib_cases) |case| {
        const decoded = try decodeZlibAlloc(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.plain, decoded);
    }

    const gzip_cases = [_]struct { compressed: []const u8, plain: []const u8 }{
        .{ .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, .plain = "hello" },
        .{ .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x4b, 0x4c, 0x04, 0x01, 0x00, 0xf8, 0x19, 0xe4, 0x5a, 0x06, 0x00, 0x00, 0x00 }, .plain = "aaaaaa" },
        .{ .compressed = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0x4b, 0x4c, 0x4a, 0x4e, 0x84, 0x21, 0x00, 0x34, 0x2a, 0x6e, 0x5a, 0x0c, 0x00, 0x00, 0x00 }, .plain = "abcabcabcabc" },
    };
    for (gzip_cases) |case| {
        const decoded = try decodeGzipAlloc(std.testing.allocator, case.compressed);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.plain, decoded);
    }
}

test "auto raw decoder dispatches stored and fixed blocks" {
    const stored = try encodeRawStoredAlloc(std.testing.allocator, "stored");
    defer std.testing.allocator.free(stored);
    const stored_decoded = try decodeRawAutoAlloc(std.testing.allocator, stored);
    defer std.testing.allocator.free(stored_decoded);
    try std.testing.expectEqualSlices(u8, "stored", stored_decoded);

    const fixed = try decodeRawAutoAlloc(std.testing.allocator, &.{ 0x4b, 0x4c, 0x04, 0x01, 0x00 });
    defer std.testing.allocator.free(fixed);
    try std.testing.expectEqualSlices(u8, "aaaaaa", fixed);
}

test "raw dynamic Huffman inflate decodes zlib dynamic vectors" {
    const compressed = &.{
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02,
        0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
        0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
    };
    const plain = "ABCDEABCD ABCDEABCD";
    const decoded = try decodeRawDynamicAllocStrict(std.testing.allocator, compressed);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);
    const auto_decoded = try decodeRawAutoAlloc(std.testing.allocator, compressed);
    defer std.testing.allocator.free(auto_decoded);
    try std.testing.expectEqualSlices(u8, plain, auto_decoded);
}

test "zlib and gzip dynamic Huffman wrappers decode dynamic vectors" {
    const zlib_frame = &.{
        0x78, 0x01,
        0x3d, 0xc6,
        0x39, 0x11,
        0x00, 0x00,
        0x0c, 0x02,
        0x30, 0x2b,
        0xb5, 0x52,
        0x1e, 0xff,
        0x96, 0x38,
        0x16, 0x96,
        0x5c, 0x1e,
        0x94, 0xcb,
        0x6d, 0x01,
        0x30, 0x33,
        0x04, 0xd3,
    };
    const gzip_frame = &.{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b,
        0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e,
        0x94, 0xcb, 0x6d, 0x01, 0x17, 0x1c, 0x39, 0xb4, 0x13, 0x00,
        0x00, 0x00,
    };
    const plain = "ABCDEABCD ABCDEABCD";
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
}

test "raw zlib and gzip decoders handle multi-block streams" {
    const raw = &.{ 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 };
    const plain = "hihello";
    const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, plain, raw_decoded);

    const zlib_frame = &.{ 0x78, 0x01, 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x0b, 0x7c, 0x02, 0xe6 };
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);

    const gzip_frame = &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x00, 0x02, 0x00, 0xfd, 0xff, 'h', 'i', 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0xf5, 0xd2, 0xfc, 0xfa, 0x07, 0x00, 0x00, 0x00 };
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
}

test "gzip decoder accepts optional extra name comment and header crc fields" {
    const with_options = &.{
        0x1f, 0x8b, 0x08, 0x1e, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x04, 0x00, 'a',  'b',  'c',  'd',  'n',  'a',  'm',  'e',
        0x00, 'c',  'o',  'm',  'm',  'e',  'n',  't',  0x00, 0xe2,
        0x48, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6,
        0x10, 0x36, 0x05, 0x00, 0x00, 0x00,
    };
    const decoded = try decodeGzipAlloc(std.testing.allocator, with_options);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);
}

test "gzip decoder rejects truncated optional headers" {
    try std.testing.expectError(error.TruncatedFrame, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x08, 0x04, 0, 0, 0, 0, 0, 3, 4, 0, 'a' }));
    try std.testing.expectError(error.TruncatedFrame, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x08, 0x08, 0, 0, 0, 0, 0, 3, 'n', 'o' }));
}

test "raw fixed Huffman encoder round trips through decoder" {
    const cases = [_][]const u8{
        "",
        "hello",
        "abcabcabcabc",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    };
    for (cases) |case| {
        const encoded = try encodeRawFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case, decoded);
    }
}

test "raw fixed Huffman encoder emits zlib-compatible hello vector" {
    const encoded = try encodeRawFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 }, encoded);
}

test "zlib and gzip fixed encoders round trip through wrappers" {
    const cases = [_][]const u8{ "hello", "abcabcabcabc", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" };
    for (cases) |case| {
        const zlib_frame = try encodeZlibFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(zlib_frame);
        const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
        defer std.testing.allocator.free(zlib_decoded);
        try std.testing.expectEqualSlices(u8, case, zlib_decoded);

        const gzip_frame = try encodeGzipFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(gzip_frame);
        const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
        defer std.testing.allocator.free(gzip_decoded);
        try std.testing.expectEqualSlices(u8, case, gzip_decoded);
    }
}

test "zlib and gzip fixed encoders emit known hello frames" {
    const zlib_frame = try encodeZlibFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(zlib_frame);
    try std.testing.expectEqualSlices(u8, &.{ 0x78, 0x01, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x06, 0x2c, 0x02, 0x15 }, zlib_frame);

    const gzip_frame = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(gzip_frame);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86, 0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00 }, gzip_frame);
}

test "zlib and gzip wrappers decode multi-block stream ending in dynamic block" {
    const plain = "hiABCDEABCD ABCDEABCD";
    const zlib_frame = &.{
        0x78, 0x01,
        0x00, 0x02,
        0x00, 0xfd,
        0xff, 'h',
        'i',  0x3d,
        0xc6, 0x39,
        0x11, 0x00,
        0x00, 0x0c,
        0x02, 0x30,
        0x2b, 0xb5,
        0x52, 0x1e,
        0xff, 0x96,
        0x38, 0x16,
        0x96, 0x5c,
        0x1e, 0x94,
        0xcb, 0x6d,
        0x01, 0x40,
        0xf1, 0x05,
        0xa4,
    };
    const gzip_frame = &.{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
        0x00, 0x02, 0x00, 0xfd, 0xff, 'h',  'i',  0x3d, 0xc6, 0x39,
        0x11, 0x00, 0x00, 0x0c, 0x02, 0x30, 0x2b, 0xb5, 0x52, 0x1e,
        0xff, 0x96, 0x38, 0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d,
        0x01, 0x45, 0x6c, 0x56, 0xbe, 0x15, 0x00, 0x00, 0x00,
    };
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, plain, zlib_decoded);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, plain, gzip_decoded);
}

test "gzip FHCRC is validated when present" {
    const valid = &.{
        0x1f, 0x8b, 0x08, 0x02, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03,
        0xa3, 0xb2, 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00, 0x86,
        0xa6, 0x10, 0x36, 0x05, 0x00, 0x00, 0x00,
    };
    const decoded = try decodeGzipAlloc(std.testing.allocator, valid);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);

    var invalid: [valid.len]u8 = valid.*;
    invalid[10] ^= 1;
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(std.testing.allocator, &invalid));
}

test "zlib header rejects bad method window check and dictionary flag" {
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(&.{ 0x77, 0x85, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, &out));
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(&.{ 0x88, 0x98, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, &out));
    try std.testing.expectError(error.BadZlibHeader, decodeZlibStored(&.{ 0x78, 0x20, 0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x01 }, &out));
}

test "gzip header rejects reserved flags and bad method" {
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x08, 0xe0, 0, 0, 0, 0, 0, 3 }));
    try std.testing.expectError(error.BadGzipHeader, decodeGzipAlloc(std.testing.allocator, &.{ 0x1f, 0x8b, 0x00, 0x00, 0, 0, 0, 0, 0, 3 }));
}

test "fixed encoder supports parser strategy options" {
    const input = "abcabcabcabc xyz xyz xyz";
    inline for (.{ ParserMode.greedy, ParserMode.lazy, ParserMode.optimal }) |mode| {
        const encoded = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, input, .{ .parser = mode });
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "dynamic literal encoder round trips through raw zlib and gzip decoders" {
    const cases = [_][]const u8{ "", "hello", "dynamic literal encoder" };
    for (cases) |case| {
        const raw = try encodeRawDynamicLiteralAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(raw);
        const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
        defer std.testing.allocator.free(raw_decoded);
        try std.testing.expectEqualSlices(u8, case, raw_decoded);

        const zlib_frame = try encodeZlibDynamicLiteralAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(zlib_frame);
        const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
        defer std.testing.allocator.free(zlib_decoded);
        try std.testing.expectEqualSlices(u8, case, zlib_decoded);

        const gzip_frame = try encodeGzipDynamicLiteralAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(gzip_frame);
        const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
        defer std.testing.allocator.free(gzip_decoded);
        try std.testing.expectEqualSlices(u8, case, gzip_decoded);
    }
}

test "dynamic code length RLE emits repeat symbols" {
    const lit_lengths = [_]u4{0} ** 20 ++ [_]u4{5} ** 7;
    const dist_lengths = [_]u4{5} ** 4;
    const ops = try buildCodeLengthOpsAlloc(std.testing.allocator, &lit_lengths, &dist_lengths);
    defer std.testing.allocator.free(ops);
    var saw_zero_repeat = false;
    var saw_prev_repeat = false;
    for (ops) |op| {
        if (op.symbol == 18 or op.symbol == 17) saw_zero_repeat = true;
        if (op.symbol == 16) saw_prev_repeat = true;
    }
    try std.testing.expect(saw_zero_repeat);
    try std.testing.expect(saw_prev_repeat);
}

test "best encoder selects a valid smallest raw block" {
    const cases = [_][]const u8{ "", "hello", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "abcabcabcabc" };
    for (cases) |case| {
        const best = try encodeRawBestAlloc(std.testing.allocator, case, .{});
        defer std.testing.allocator.free(best);
        const stored = try encodeRawStoredAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(stored);
        const fixed = try encodeRawFixedAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(fixed);
        const dynamic = try encodeRawDynamicWithOptionsAlloc(std.testing.allocator, case, .{});
        defer std.testing.allocator.free(dynamic);
        try std.testing.expect(best.len <= stored.len);
        try std.testing.expect(best.len <= fixed.len);
        try std.testing.expect(best.len <= dynamic.len);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, best);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case, decoded);
    }
}

test "compression level presets round trip" {
    const input = "abcabcabcabc abcabcabcabc";
    inline for (.{ CompressionLevel.fastest, CompressionLevel.fast, CompressionLevel.default, CompressionLevel.best }) |level| {
        const encoded = try encodeRawBestAlloc(std.testing.allocator, input, optionsForLevel(level));
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "gzip concatenated members decode in sequence" {
    const a = try encodeGzipFixedAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(a);
    const b = try encodeGzipFixedAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(b);
    var cat: std.ArrayList(u8) = .empty;
    defer cat.deinit(std.testing.allocator);
    try cat.appendSlice(std.testing.allocator, a);
    try cat.appendSlice(std.testing.allocator, b);
    const decoded = try decodeGzipConcatenatedAlloc(std.testing.allocator, cat.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "helloworld", decoded);
}

test "fast level skips dynamic block candidate" {
    const input = "abcabcabcabc";
    const fast = try encodeRawBestAlloc(std.testing.allocator, input, optionsForLevel(.fast));
    defer std.testing.allocator.free(fast);
    const stored = try encodeRawStoredAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(stored);
    const fixed = try encodeRawFixedWithOptionsAlloc(std.testing.allocator, input, optionsForLevel(.fast));
    defer std.testing.allocator.free(fixed);
    try std.testing.expect(fast.len == @min(stored.len, fixed.len));
}

test "split raw fixed encoder emits multi-block deflate stream" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const encoded = try encodeRawFixedSplitAlloc(std.testing.allocator, input, 7, optionsForLevel(.fast));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "split raw dynamic encoder emits multi-block deflate stream" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const encoded = try encodeRawDynamicSplitAlloc(std.testing.allocator, input, 7, optionsForLevel(.fast));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "split raw best encoder selects block modes independently" {
    const input = "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const encoded = try encodeRawBestSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const fixed = try encodeRawFixedSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(fixed);
    const dynamic = try encodeRawDynamicSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(dynamic);
    try std.testing.expect(encoded.len <= fixed.len);
    try std.testing.expect(encoded.len <= dynamic.len);
}

test "zlib and gzip split-best wrappers round trip" {
    const input = "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const zlib_frame = try encodeZlibBestSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(zlib_frame);
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, input, zlib_decoded);

    const gzip_frame = try encodeGzipBestSplitAlloc(std.testing.allocator, input, 26, optionsForLevel(.default));
    defer std.testing.allocator.free(gzip_frame);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, input, gzip_decoded);
}

test "adaptive split best wrappers round trip" {
    const input = ("aaaaaaaaaaaaaaaa" ** 4) ++ "abcdefghijklmnopqrstuvwxyz" ++ ("abcabcabcabc" ** 8);
    const raw = try encodeRawBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8 });
    defer std.testing.allocator.free(raw);
    const raw_decoded = try decodeRawAutoAlloc(std.testing.allocator, raw);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, input, raw_decoded);

    const zlib_frame = try encodeZlibBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8 });
    defer std.testing.allocator.free(zlib_frame);
    const zlib_decoded = try decodeZlibAlloc(std.testing.allocator, zlib_frame);
    defer std.testing.allocator.free(zlib_decoded);
    try std.testing.expectEqualSlices(u8, input, zlib_decoded);

    const gzip_frame = try encodeGzipBestAdaptiveSplitAlloc(std.testing.allocator, input, optionsForLevel(.default), .{ .min_block_len = 16, .max_block_len = 64, .sample_len = 8 });
    defer std.testing.allocator.free(gzip_frame);
    const gzip_decoded = try decodeGzipAlloc(std.testing.allocator, gzip_frame);
    defer std.testing.allocator.free(gzip_decoded);
    try std.testing.expectEqualSlices(u8, input, gzip_decoded);
}
