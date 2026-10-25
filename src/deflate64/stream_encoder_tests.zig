//! Independent fixed/stored token inspection and resumable encoder contracts.
//! The public decoder is imported directly, without the Deflate64 facade.
const std = @import("std");
const decoder = @import("decoder.zig");
const stored_encoder = @import("encoder.zig");
const core = @import("../core.zig");

const Cursor = struct {
    bytes: []const u8,
    position: usize = 0,
    fn read(self: *Cursor, width: u6) !u32 {
        if (@as(u128, self.position) + width > @as(u128, self.bytes.len) * 8) return error.TruncatedFrame;
        var result: u32 = 0;
        for (0..width) |bit| {
            const absolute = self.position + bit;
            const one: u32 = (self.bytes[absolute / 8] >> @as(u3, @intCast(absolute % 8))) & 1;
            result |= one << @as(u5, @intCast(bit));
        }
        self.position += width;
        return result;
    }
    fn fixedSymbol(self: *Cursor) !u16 {
        var code: u16 = 0;
        for (1..10) |width| {
            code = (code << 1) | @as(u16, @intCast(try self.read(1)));
            if (width == 7 and code <= 23) return 256 + code;
            if (width == 8) {
                if (code >= 48 and code <= 191) return code - 48;
                if (code >= 192 and code <= 199) return 280 + code - 192;
            }
            if (width == 9 and code >= 400 and code <= 511) return 144 + code - 400;
        }
        return error.InvalidHuffmanCode;
    }
    fn distanceSymbol(self: *Cursor) !u16 {
        var code: u16 = 0;
        for (0..5) |_| code = (code << 1) | @as(u16, @intCast(try self.read(1)));
        return code;
    }
};

const Match = struct {
    block: usize,
    output_offset: usize,
    length_symbol: u16,
    length: usize,
    distance_symbol: u16,
    distance: usize,
};
const Inspection = struct {
    output: []u8,
    matches: std.ArrayList(Match) = .empty,
    fixed_blocks: usize = 0,
    stored_blocks: usize = 0,
    literals: usize = 0,
    fn deinit(self: *Inspection) void {
        self.matches.deinit(std.testing.allocator);
        std.testing.allocator.free(self.output);
    }
};

fn inspect(wire: []const u8, output_len: usize) !Inspection {
    var result: Inspection = .{ .output = try std.testing.allocator.alloc(u8, output_len) };
    errdefer result.deinit();
    var reader: Cursor = .{ .bytes = wire };
    var written: usize = 0;
    var block: usize = 0;
    while (true) : (block += 1) {
        const final = try reader.read(1) != 0;
        const kind = try reader.read(2);
        if (kind == 0) {
            result.stored_blocks += 1;
            reader.position = reader.position / 8 * 8 + @as(usize, @intFromBool(reader.position % 8 != 0)) * 8;
            const length: u16 = @intCast(try reader.read(16));
            const complement: u16 = @intCast(try reader.read(16));
            try std.testing.expectEqual(@as(u16, ~length), complement);
            if (length > result.output.len - written) return error.OutputTooSmall;
            for (result.output[written..][0..length]) |*byte| byte.* = @intCast(try reader.read(8));
            written += length;
        } else if (kind == 1) {
            result.fixed_blocks += 1;
            while (true) {
                const symbol = try reader.fixedSymbol();
                if (symbol < 256) {
                    if (written == result.output.len) return error.OutputTooSmall;
                    result.output[written] = @intCast(symbol);
                    written += 1;
                    result.literals += 1;
                } else if (symbol == 256) {
                    break;
                } else {
                    if (symbol > 285) return error.InvalidHuffmanCode;
                    var length: usize = undefined;
                    if (symbol <= 264) {
                        length = symbol - 254;
                    } else if (symbol == 285) {
                        length = 3 + try reader.read(16);
                    } else {
                        const group: usize = (symbol - 265) / 4;
                        const width: u6 = @intCast(group + 1);
                        const slot: usize = (symbol - 265) % 4;
                        const base = (@as(usize, 1) << @intCast(width + 2)) + 3 + slot * (@as(usize, 1) << @intCast(width));
                        length = base + try reader.read(width);
                    }
                    const distance_symbol = try reader.distanceSymbol();
                    const distance: usize = if (distance_symbol < 4)
                        distance_symbol + 1
                    else blk: {
                        const width: u6 = @intCast(distance_symbol / 2 - 1);
                        const base = ((2 + @as(usize, distance_symbol & 1)) << @intCast(width)) + 1;
                        break :blk base + try reader.read(width);
                    };
                    if (distance > written or distance > 65536) return error.InvalidMatch;
                    if (length > result.output.len - written) return error.OutputTooSmall;
                    try result.matches.append(std.testing.allocator, .{ .block = block, .output_offset = written, .length_symbol = symbol, .length = length, .distance_symbol = distance_symbol, .distance = distance });
                    for (0..length) |_| {
                        result.output[written] = result.output[written - distance];
                        written += 1;
                    }
                }
            }
        } else return error.InvalidDeflateBlockType;
        if (final) break;
    }
    try std.testing.expectEqual(output_len, written);
    try std.testing.expectEqual(wire.len, reader.position / 8 + @intFromBool(reader.position % 8 != 0));
    return result;
}

fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn checkedStep(encoder: anytype, input: []const u8, output: []u8) !core.StepResult {
    const before = encoder.snapshot();
    const result = encoder.step(input, output) catch |err| {
        const after = encoder.snapshot();
        const failure = encoder.failedProgress() orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(failure.input_read, after.input_read - before.input_read);
        try std.testing.expectEqual(failure.output_written, after.output_written - before.output_written);
        try std.testing.expect(failure.input_read <= input.len and failure.output_written <= output.len);
        try untouched(output[failure.output_written..]);
        return err;
    };
    const after = encoder.snapshot();
    try std.testing.expectEqual(result.progress.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(result.progress.output_written, after.output_written - before.output_written);
    try std.testing.expect(result.progress.input_read <= input.len);
    try std.testing.expect(result.progress.output_written <= output.len);
    try untouched(output[result.progress.output_written..]);
    return result;
}

fn feed(encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize, wire: *std.ArrayList(u8)) !void {
    var offset: usize = 0;
    var output: [521]u8 = undefined;
    for (0..input.len * 4 + 4096) |call| {
        const end = @min(input.len, offset + input_quota);
        @memset(&output, 0xa5);
        const result = try checkedStep(encoder, input[offset..end], output[0..if (call % 11 == 0) 0 else output_quota]);
        offset += result.progress.input_read;
        try wire.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (offset == input.len and result.status == .need_input) return;
    }
    return error.TestUnexpectedResult;
}

fn complete(encoder: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    try feed(encoder, input, input_quota, output_quota, &wire);
    encoder.finish();
    var output: [521]u8 = undefined;
    for (0..input.len * 4 + 4096) |call| {
        @memset(&output, 0xa5);
        const result = try checkedStep(encoder, "", output[0..if (call % 11 == 0) 0 else output_quota]);
        try wire.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (result.status == .done) return wire.toOwnedSlice(std.testing.allocator);
    }
    return error.TestUnexpectedResult;
}

fn decodedEqual(wire: []const u8, input: []const u8) !void {
    var parsed = try inspect(wire, input.len);
    defer parsed.deinit();
    try std.testing.expectEqualSlices(u8, input, parsed.output);
    const actual = try decoder.decodeAlloc(std.testing.allocator, wire);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(u8, input, actual);
}

fn fill(bytes: []u8, seed: u32) void {
    var random = seed;
    for (bytes) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
}

fn roundTrips(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const repetitive = "Deflate64 stream exact caller progress abcdefghabcdefgh\n" ** 79;
    var random: [4097]u8 = undefined;
    fill(&random, 0x243f6a88);
    inline for (.{ .adaptive, .fixed, .stored }) |compression| {
        for ([_][]const u8{ "", "x", "abc", "tiny", repetitive, &random }) |input| {
            var baseline = Encoder.initWithOptions(std.testing.allocator, .{ .block_len = 1024, .compression = compression });
            defer baseline.deinit();
            const expected = try complete(&baseline, input, input.len + 1, 521);
            defer std.testing.allocator.free(expected);
            try decodedEqual(expected, input);
            for ([_][2]usize{ .{ 1, 1 }, .{ 17, 5 }, .{ 511, 257 } }) |quotas| {
                var encoder = Encoder.initExactSize(std.testing.allocator, .{ .block_len = 1024, .compression = compression }, input.len);
                defer encoder.deinit();
                const actual = try complete(&encoder, input, quotas[0], quotas[1]);
                defer std.testing.allocator.free(actual);
                try std.testing.expectEqualSlices(u8, expected, actual);
                try std.testing.expectEqual(input.len, encoder.snapshot().input_read);
                try std.testing.expectEqual(actual.len, encoder.snapshot().output_written);
                try std.testing.expect(encoder.snapshot().done);
            }
        }
    }
    // Explicit stored mode at the historical 65535-byte block size preserves
    // the old no-compression wire, separately from adaptive-format behavior.
    const input = try std.testing.allocator.alloc(u8, 65536);
    defer std.testing.allocator.free(input);
    fill(input, 17);
    var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .block_len = 65535, .compression = .stored });
    defer encoder.deinit();
    const actual = try complete(&encoder, input, 4096, 521);
    defer std.testing.allocator.free(actual);
    const expected = try std.testing.allocator.alloc(u8, try stored_encoder.encodedBound(input.len));
    defer std.testing.allocator.free(expected);
    _ = try stored_encoder.encodeStoredInto(input, expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn extendedTokens(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const input = try std.testing.allocator.alloc(u8, 131072);
    defer std.testing.allocator.free(input);
    fill(input[0..65536], 0x243f6a88);
    @memcpy(input[65536..], input[0..65536]);
    var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .fixed, .max_chain = 128, .nice_length = 65538 });
    defer encoder.deinit();
    const wire = try complete(&encoder, input, 4096, 521);
    defer std.testing.allocator.free(wire);
    var parsed = try inspect(wire, input.len);
    defer parsed.deinit();
    try std.testing.expectEqualSlices(u8, input, parsed.output);
    var distance_65536 = false;
    for (parsed.matches.items) |match| if (match.distance == 65536) {
        distance_65536 = true;
        try std.testing.expectEqual(@as(u16, 31), match.distance_symbol);
        try std.testing.expect(match.length >= 32768);
    };
    try std.testing.expect(distance_65536);

    @memset(input[0..65539], 'R');
    var long = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .fixed });
    defer long.deinit();
    const long_wire = try complete(&long, input[0..65539], 4096, 521);
    defer std.testing.allocator.free(long_wire);
    var long_tokens = try inspect(long_wire, 65539);
    defer long_tokens.deinit();
    try std.testing.expectEqual(@as(usize, 1), long_tokens.literals);
    try std.testing.expectEqual(@as(usize, 1), long_tokens.matches.items.len);
    try std.testing.expectEqual(@as(u16, 285), long_tokens.matches.items[0].length_symbol);
    try std.testing.expectEqual(@as(usize, 65538), long_tokens.matches.items[0].length);
    try std.testing.expectEqual(@as(usize, 1), long_tokens.matches.items[0].distance);
    var length258 = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .fixed });
    defer length258.deinit();
    const short_wire = try complete(&length258, input[0..259], 17, 5);
    defer std.testing.allocator.free(short_wire);
    var short_tokens = try inspect(short_wire, 259);
    defer short_tokens.deinit();
    try std.testing.expectEqual(@as(usize, 1), short_tokens.matches.items.len);
    try std.testing.expectEqual(@as(u16, 284), short_tokens.matches.items[0].length_symbol);
    try std.testing.expectEqual(@as(usize, 258), short_tokens.matches.items[0].length);
}

fn drainFlush(encoder: anytype, wire: *std.ArrayList(u8)) !void {
    var output: [521]u8 = undefined;
    for (0..8192) |_| {
        @memset(&output, 0xa5);
        const result = try checkedStep(encoder, "", output[0..5]);
        try wire.appendSlice(std.testing.allocator, output[0..result.progress.output_written]);
        if (result.status == .need_input and !encoder.snapshot().flushing) return;
    }
    return error.TestUnexpectedResult;
}

fn flushHistory(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    var input: [2048]u8 = undefined;
    fill(input[0..1024], 0x6a09e667);
    @memcpy(input[1024..], input[0..1024]);
    const Flush = enum { block, partial, sync, full };
    for (std.enums.values(Flush)) |mode| {
        var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .fixed, .block_len = 1024 });
        defer encoder.deinit();
        var wire: std.ArrayList(u8) = .empty;
        defer wire.deinit(std.testing.allocator);
        try feed(&encoder, input[0..1024], 17, 5, &wire);
        switch (mode) {
            .block => encoder.blockFlush(),
            .partial => encoder.partialFlush(),
            .sync => encoder.flush(),
            .full => encoder.fullFlush(),
        }
        try drainFlush(&encoder, &wire);
        const boundary_len = wire.items.len;
        switch (mode) {
            .block => encoder.blockFlush(),
            .partial => encoder.partialFlush(),
            .sync => encoder.flush(),
            .full => encoder.fullFlush(),
        }
        try drainFlush(&encoder, &wire);
        try std.testing.expectEqual(boundary_len, wire.items.len);
        if (mode == .full) try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().history_len) else try std.testing.expect(encoder.snapshot().history_len != 0);
        const rest = try complete(&encoder, input[1024..], 17, 5);
        defer std.testing.allocator.free(rest);
        try wire.appendSlice(std.testing.allocator, rest);
        try decodedEqual(wire.items, &input);
        var parsed = try inspect(wire.items, input.len);
        defer parsed.deinit();
        var cross_history = false;
        for (parsed.matches.items) |match| {
            if (match.output_offset == 1024 and match.distance == 1024 and match.length == 1024) cross_history = true;
        }
        try std.testing.expectEqual(mode != .full, cross_history);
        if (mode == .partial) try std.testing.expect(parsed.fixed_blocks >= 3);
        if (mode == .sync or mode == .full) try std.testing.expect(parsed.stored_blocks != 0);
    }
    var automatic = Encoder.initWithOptions(std.testing.allocator, .{ .compression = .fixed, .block_len = 1024 });
    defer automatic.deinit();
    const wire = try complete(&automatic, &input, input.len, 521);
    defer std.testing.allocator.free(wire);
    var parsed = try inspect(wire, input.len);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 2), parsed.fixed_blocks);
    var shared = false;
    for (parsed.matches.items) |match| if (match.output_offset == 1024 and match.distance == 1024) {
        shared = true;
    };
    try std.testing.expect(shared);
}

fn checkSticky(encoder: anytype, expected_error: anyerror, input: []const u8, output: []u8) !void {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(expected_error, encoder.step(input, output));
    const after = encoder.snapshot();
    const failure = encoder.failedProgress() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(failure.input_read, after.input_read - before.input_read);
    try std.testing.expectEqual(failure.output_written, after.output_written - before.output_written);
    try std.testing.expectEqualDeep(failure, after.last_step_progress);
    try untouched(output[failure.output_written..]);
    const preserved = encoder.snapshot();
    @memset(output, 0xa5);
    try std.testing.expectError(expected_error, encoder.step("unaccepted", output));
    try std.testing.expectEqualDeep(preserved, encoder.snapshot());
    try std.testing.expectEqualDeep(@as(?core.Progress, failure), encoder.failedProgress());
    try untouched(output);
}

fn limitsAndReset(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const a = std.testing.allocator;
    var output: [128]u8 = @splat(0xa5);
    for ([_]Encoder.Options{ .{ .block_len = 0 }, .{ .block_len = 131073 }, .{ .nice_length = 2 }, .{ .nice_length = 65539 } }) |options| {
        try std.testing.expectError(error.InvalidBlockPlan, Encoder.validateOptions(options));
        var backing = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
        var invalid = Encoder.initWithOptions(backing.allocator(), options);
        defer invalid.deinit();
        try checkSticky(&invalid, error.InvalidBlockPlan, "valid input", &output);
        try std.testing.expectEqual(@as(usize, 0), backing.alloc_index);
    }
    var limited = Encoder.initWithOptions(a, .{ .max_input_len = 3 });
    defer limited.deinit();
    try checkSticky(&limited, error.OutputLimitExceeded, "four", &output);
    try std.testing.expectEqual(@as(usize, 0), limited.snapshot().input_read);
    limited.resetWithOptions(.{ .compression = .fixed, .max_chain = 0 });
    try std.testing.expect(limited.failedProgress() == null);
    const recovered = try complete(&limited, "recovered", 1, 5);
    defer a.free(recovered);
    try decodedEqual(recovered, "recovered");

    var over_pledge = Encoder.initExactSize(a, .{}, 3);
    defer over_pledge.deinit();
    try checkSticky(&over_pledge, error.SizeMismatch, "four", &output);
    try std.testing.expectEqual(@as(usize, 0), over_pledge.snapshot().input_read);
    over_pledge.resetWithOptions(.{});
    over_pledge.resetExactSize(4);
    const corrected = try complete(&over_pledge, "four", 1, 1);
    defer a.free(corrected);
    try decodedEqual(corrected, "four");
    var short = Encoder.initExactSize(a, .{}, 4);
    defer short.deinit();
    @memset(&output, 0xa5);
    _ = try checkedStep(&short, "abc", &output);
    short.finish();
    try checkSticky(&short, error.SizeMismatch, "", &output);
    var pending = Encoder.initWithOptions(a, .{ .max_pending_output_len = 0 });
    defer pending.deinit();
    @memset(&output, 0xa5);
    _ = try checkedStep(&pending, "abc", &output);
    pending.finish();
    try checkSticky(&pending, error.OutputLimitExceeded, "", &output);
    pending.reset();
    try std.testing.expect(pending.failedProgress() == null);

    var stored: [128]u8 = undefined;
    fill(&stored, 17);
    var exact_pending = Encoder.initWithOptions(a, .{ .compression = .stored, .block_len = stored.len, .max_pending_output_len = stored.len + 5 });
    defer exact_pending.deinit();
    const stored_wire = try complete(&exact_pending, &stored, 17, 5);
    defer a.free(stored_wire);
    try std.testing.expectEqual(@as(usize, stored.len + 5), stored_wire.len);
    try decodedEqual(stored_wire, &stored);
    var below_pending = Encoder.initWithOptions(a, .{ .compression = .stored, .block_len = stored.len, .max_pending_output_len = stored.len + 4 });
    defer below_pending.deinit();
    var collected: std.ArrayList(u8) = .empty;
    defer collected.deinit(a);
    try feed(&below_pending, &stored, 17, 5, &collected);
    below_pending.finish();
    try checkSticky(&below_pending, error.OutputLimitExceeded, "", &output);

    var literals_only = Encoder.initWithOptions(a, .{ .compression = .fixed, .max_chain = 0 });
    defer literals_only.deinit();
    const plain = "R" ** 513;
    const literal_wire = try complete(&literals_only, plain, 17, 5);
    defer a.free(literal_wire);
    var literal_tokens = try inspect(literal_wire, plain.len);
    defer literal_tokens.deinit();
    try std.testing.expectEqual(plain.len, literal_tokens.literals);
    try std.testing.expectEqual(@as(usize, 0), literal_tokens.matches.items.len);
}

fn allocationFailures(comptime Codec: type) !void {
    const Encoder = Codec.Encoder;
    const input = "Deflate64 reusable allocation and progress fixture abcdefgh\n" ** 24;
    var baseline = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var encoder = Encoder.initWithOptions(baseline.allocator(), .{ .compression = .fixed, .block_len = 1024 });
    const wire = try complete(&encoder, input, 17, 5);
    std.testing.allocator.free(wire);
    const count = baseline.alloc_index;
    encoder.deinit();
    try std.testing.expect(count > 1);
    try std.testing.expectEqual(baseline.allocated_bytes, baseline.freed_bytes);
    for ([_]usize{ 0, 1, count - 1 }) |failure| {
        var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = failure });
        var failing = Encoder.initWithOptions(backing.allocator(), .{ .compression = .fixed, .block_len = 1024 });
        var wire_bytes: std.ArrayList(u8) = .empty;
        defer wire_bytes.deinit(std.testing.allocator);
        const accepted = feed(&failing, input, 17, 5, &wire_bytes);
        if (accepted) |_| {
            failing.finish();
            var output: [128]u8 = @splat(0xa5);
            // A later real allocation can occur only while draining or
            // materializing the last block; do not invent the failure call.
            var failed = false;
            for (0..4096) |_| {
                @memset(&output, 0xa5);
                const step = failing.step("", output[0..5]);
                if (step) |result| {
                    if (result.status == .done) break;
                } else |err| {
                    try std.testing.expectEqual(error.OutOfMemory, err);
                    failed = true;
                    break;
                }
            }
            try std.testing.expect(failed);
        } else |err| try std.testing.expectEqual(error.OutOfMemory, err);
        try std.testing.expect(backing.has_induced_failure);
        const progress = failing.failedProgress() orelse return error.TestUnexpectedResult;
        const before = failing.snapshot();
        var output: [128]u8 = @splat(0xa5);
        try std.testing.expectError(error.OutOfMemory, failing.step("ignored", &output));
        try std.testing.expectEqualDeep(before, failing.snapshot());
        try std.testing.expectEqualDeep(@as(?core.Progress, progress), failing.failedProgress());
        try untouched(&output);
        backing.fail_index = std.math.maxInt(usize);
        failing.resetWithOptions(.{ .compression = .fixed, .block_len = 1024 });
        failing.resetExactSize(9);
        const recovered = try complete(&failing, "recovered", 1, 5);
        defer std.testing.allocator.free(recovered);
        try decodedEqual(recovered, "recovered");
        failing.deinit();
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
}

fn boundedOwnership(comptime Codec: type) !void {
    const block_len: usize = 4096;
    const blocks: usize = 1024;
    const pending_bound: usize = block_len + 14;
    var input: [block_len]u8 = undefined;
    fill(&input, 0x243f6a88);
    var backing = std.testing.FailingAllocator.init(std.testing.allocator, .{});
    var encoder = Codec.Encoder.initWithOptions(backing.allocator(), .{ .block_len = block_len, .compression = .adaptive });
    errdefer encoder.deinit();
    var delivered: usize = 0;
    var warmed_allocations: usize = 0;
    var warmed_live: usize = 0;
    var output: [128]u8 = undefined;
    for (0..blocks) |block| {
        var offset: usize = 0;
        var consumed = false;
        for (0..128) |_| {
            @memset(&output, 0xa5);
            const result = try checkedStep(&encoder, input[offset..], &output);
            offset += result.progress.input_read;
            delivered += result.progress.output_written;
            const snapshot = encoder.snapshot();
            try std.testing.expect(snapshot.history_len <= 65536);
            try std.testing.expect(snapshot.buffered_input <= block_len);
            try std.testing.expect(snapshot.pending_output <= pending_bound);
            try std.testing.expect(snapshot.retained_input_capacity <= block_len);
            try std.testing.expect(snapshot.retained_pending_capacity <= pending_bound);
            if (offset == input.len and result.status == .need_input) {
                consumed = true;
                break;
            }
        }
        try std.testing.expect(consumed);
        if (block == 31) {
            warmed_allocations = backing.alloc_index;
            warmed_live = backing.allocated_bytes - backing.freed_bytes;
            try std.testing.expect(warmed_allocations > 0);
        } else if (block > 31) {
            try std.testing.expectEqual(warmed_allocations, backing.alloc_index);
            try std.testing.expectEqual(warmed_live, backing.allocated_bytes - backing.freed_bytes);
        }
    }
    encoder.finish();
    var finished = false;
    for (0..128) |_| {
        @memset(&output, 0xa5);
        const result = try checkedStep(&encoder, "", &output);
        delivered += result.progress.output_written;
        const snapshot = encoder.snapshot();
        try std.testing.expect(snapshot.history_len <= 65536);
        try std.testing.expect(snapshot.buffered_input <= block_len);
        try std.testing.expect(snapshot.pending_output <= pending_bound);
        try std.testing.expect(snapshot.retained_input_capacity <= block_len);
        try std.testing.expect(snapshot.retained_pending_capacity <= pending_bound);
        if (result.status == .done) {
            finished = true;
            break;
        }
    }
    try std.testing.expect(finished);
    try std.testing.expectEqual(@as(usize, 4 * 1024 * 1024), encoder.snapshot().input_read);
    try std.testing.expectEqual(delivered, encoder.snapshot().output_written);
    try std.testing.expect(delivered != 0);
    try std.testing.expect(encoder.snapshot().block_count >= blocks);
    try std.testing.expectEqual(warmed_allocations, backing.alloc_index);
    // This case discards already-delivered bytes to isolate encoder ownership.
    // Earlier tests independently inspect/round-trip the same codec paths.
    // There is no whole-input or wire collection allocation in this ledger.
    encoder.deinit();
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

pub fn contracts(comptime Codec: type) !void {
    try roundTrips(Codec);
    try extendedTokens(Codec);
    try flushHistory(Codec);
    try limitsAndReset(Codec);
    try allocationFailures(Codec);
    try boundedOwnership(Codec);
}
