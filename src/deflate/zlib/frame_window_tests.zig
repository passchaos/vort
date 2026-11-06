const std = @import("std");
const oracle = @import("frame_window_oracle.zig");
const a = std.testing.allocator;
const prefix = "caller-owned prefix";
const guard: u8 = 0xa5;

pub fn contracts(comptime D: type) !void {
    try oracle.controls();
    try allWindowsAndForms(D);
    try defaultBytes(D);
    try literalPolicy(D);
    try exactDistances(D);
    try dictionarySuffixes(D);
    try splitHistory(D);
    try bestCandidatePolicies(D);
    try storedChunks(D);
    try invalidWindows(D);
    try optionTransitions(D);
    try levels(D);
}

pub fn candidateContracts(comptime D: type, comptime A: type) !void {
    try @import("frame_window_candidate_tests.zig").contracts(D, A);
}

fn windowLen(bits: u8) usize {
    return @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(bits));
}

fn config(comptime D: type) D.CompressionOptions {
    var result = D.optionsForLevel(.fast);
    result.lz77_options.max_chain = 128;
    result.lz77_options.max_candidates = 16;
    result.lz77_options.nice_len = 258;
    result.lz77_options.max_match = 258;
    result.lz77_options.min_match = 3;
    result.lz77_options.min_savings_bits = 0;
    return result;
}

fn splitConfig(comptime D: type) D.AdaptiveSplitOptions {
    return .{ .min_block_len = 256, .max_block_len = 1024, .sample_len = 128, .search_step = 256 };
}

fn matrixInput() [3072]u8 {
    var result: [3072]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x73f7c809c41a);
    random.random().bytes(result[0..513]);
    for (513..2048) |i| result[i] = result[i % 513];
    for (2048..result.len) |i| result[i] = if (i % 127 < 96) 0 else @intCast(i % 7);
    return result;
}

/// The global and owned APIs must all produce exactly the independently
/// audited member while respecting the caller's existing output and guards.
fn forms(comptime D: type, input: []const u8, options: D.ZlibEncodeOptions, target: usize) !oracle.Stats {
    const encoded = try D.encodeZlibFrameAlloc(a, input, options);
    defer a.free(encoded);
    const stats = try oracle.frame(encoded, input, options.dictionary, options.window_bits, target);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, prefix);
    try std.testing.expectEqual(encoded.len, try D.encodeZlibFrameAppend(a, &out, input, options));
    try std.testing.expectEqualSlices(u8, prefix, out.items[0..prefix.len]);
    try std.testing.expectEqualSlices(u8, encoded, out.items[prefix.len..]);

    const buffer = try a.alloc(u8, encoded.len + 32);
    defer a.free(buffer);
    @memset(buffer, guard);
    try std.testing.expectEqual(encoded.len, try D.encodeZlibFrameInto(a, input, buffer[16 .. buffer.len - 16], options));
    try std.testing.expectEqualSlices(u8, encoded, buffer[16 .. buffer.len - 16]);
    try expectGuard(buffer[0..16]);
    try expectGuard(buffer[buffer.len - 16 ..]);

    var encoder = try D.ZlibFrameEncoder.init(a, options);
    defer encoder.deinit();
    const owned = try encoder.encodeAlloc(input);
    defer a.free(owned);
    try std.testing.expectEqualSlices(u8, encoded, owned);
    out.items.len = prefix.len;
    try std.testing.expectEqual(encoded.len, try encoder.encodeAppend(&out, input));
    try std.testing.expectEqualSlices(u8, prefix, out.items[0..prefix.len]);
    try std.testing.expectEqualSlices(u8, encoded, out.items[prefix.len..]);
    @memset(buffer, guard);
    try std.testing.expectEqual(encoded.len, try encoder.encodeInto(input, buffer[16 .. buffer.len - 16]));
    try std.testing.expectEqualSlices(u8, encoded, buffer[16 .. buffer.len - 16]);
    try expectGuard(buffer[0..16]);
    try expectGuard(buffer[buffer.len - 16 ..]);
    try std.testing.expectEqualSlices(u8, encoded, try encoder.encodeScratch(input));
    return stats;
}

fn expectGuard(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(guard, byte);
}

fn allWindowsAndForms(comptime D: type) !void {
    const input = matrixInput();
    for (9..16) |wide| {
        const bits: u8 = @intCast(wide);
        for (std.meta.tags(D.ZlibEncodeMode)) |mode| {
            var compression = config(D);
            // Deliberately exceed every RFC 1950 cap. Framing must clamp the
            // parser rather than merely changing CINFO in the header.
            compression.lz77_options.window_len = 65535;
            const options: D.ZlibEncodeOptions = .{
                .window_bits = bits,
                .mode = mode,
                .compression = compression,
                .split_options = splitConfig(D),
            };
            const stats = try forms(D, &input, options, 513);
            try std.testing.expect(stats.max_distance <= windowLen(bits));
            if (mode == .stored or mode == .dynamic_literal)
                try std.testing.expectEqual(@as(usize, 0), stats.matches);
            if (mode == .png_ultrafast)
                try std.testing.expect(stats.max_distance <= 1);
            // Empty members still advertise the selected window and every
            // output form must retain its ownership/progress contract.
            _ = try forms(D, "", options, 0);
        }
    }
}

fn legacy(comptime D: type, input: []const u8, options: D.ZlibEncodeOptions) ![]u8 {
    const compression = options.compression;
    if (options.dictionary) |dictionary| return switch (options.mode) {
        .stored => try D.encodeZlibStoredWithDictionaryAlloc(a, input, dictionary),
        .fixed => if (options.block_len) |n|
            try D.encodeZlibFixedSplitWithDictionaryAlloc(a, input, dictionary, n, compression)
        else
            try D.encodeZlibFixedWithDictionaryAlloc(a, input, dictionary, compression),
        .dynamic => if (options.block_len) |n|
            try D.encodeZlibDynamicSplitWithDictionaryAlloc(a, input, dictionary, n, compression)
        else
            try D.encodeZlibDynamicWithDictionaryAlloc(a, input, dictionary, compression),
        .dynamic_literal => blk: {
            var literal = compression;
            literal.strategy = .huffman_only;
            break :blk if (options.block_len) |n|
                try D.encodeZlibDynamicSplitWithDictionaryAlloc(a, input, dictionary, n, literal)
            else
                try D.encodeZlibDynamicWithDictionaryAlloc(a, input, dictionary, literal);
        },
        .best => if (options.block_len) |n|
            try D.encodeZlibBestSplitWithDictionaryAlloc(a, input, dictionary, n, compression)
        else
            try D.encodeZlibBestWithDictionaryAlloc(a, input, dictionary, compression),
        .adaptive => try D.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(a, input, dictionary, compression, options.split_options),
        .png_ultrafast => blk: {
            // PNG previously had no dictionary frontend. Its frozen body and
            // footer combine with the old dictionary-header byte contract.
            const frozen = try D.encodeZlibPngUltraFastAlloc(a, input);
            defer a.free(frozen);
            const header = try D.encodeZlibStoredWithDictionaryAlloc(a, "", dictionary);
            defer a.free(header);
            const combined = try a.alloc(u8, frozen.len + 4);
            @memcpy(combined[0..6], header[0..6]);
            @memcpy(combined[6..], frozen[2..]);
            break :blk combined;
        },
    };
    return switch (options.mode) {
        .stored => try D.encodeZlibStoredAlloc(a, input),
        .fixed => if (options.block_len) |n|
            try D.encodeZlibFixedSplitAlloc(a, input, n, compression)
        else
            try D.encodeZlibFixedWithOptionsAlloc(a, input, compression),
        .dynamic => if (options.block_len) |n|
            try D.encodeZlibDynamicSplitAlloc(a, input, n, compression)
        else
            try D.encodeZlibDynamicWithOptionsAlloc(a, input, compression),
        .dynamic_literal => blk: {
            if (options.block_len) |n| {
                var literal = compression;
                literal.strategy = .huffman_only;
                break :blk try D.encodeZlibDynamicSplitAlloc(a, input, n, literal);
            }
            break :blk try D.encodeZlibDynamicLiteralAlloc(a, input);
        },
        .best => if (options.block_len) |n|
            try D.encodeZlibBestSplitAlloc(a, input, n, compression)
        else
            try D.encodeZlibBestAlloc(a, input, compression),
        .adaptive => try D.encodeZlibBestAdaptiveSplitAlloc(a, input, compression, options.split_options),
        .png_ultrafast => try D.encodeZlibPngUltraFastAlloc(a, input),
    };
}

fn defaultBytes(comptime D: type) !void {
    const input = matrixInput();
    for (std.meta.tags(D.ZlibEncodeMode)) |mode| {
        for ([_]?[]const u8{ null, "", "legacy dictionary\x00with trailing bytes" }) |dictionary| {
            for ([_][]const u8{ "", "x", &input }) |payload| {
                const options: D.ZlibEncodeOptions = .{ .mode = mode, .dictionary = dictionary, .split_options = splitConfig(D) };
                const old = try legacy(D, payload, options);
                defer a.free(old);
                const current = try D.encodeZlibFrameAlloc(a, payload, options);
                defer a.free(current);
                try std.testing.expectEqualSlices(u8, old, current);
                _ = try oracle.frame(current, payload, dictionary, 15, 0);
                try std.testing.expectEqual(dictionary != null, current[1] & 0x20 != 0);
                if (dictionary) |dict|
                    try std.testing.expectEqual(oracle.adler32(dict), std.mem.readInt(u32, current[2..6], .big));
            }
            if (mode == .stored or mode == .adaptive or mode == .png_ultrafast) continue;
            const options: D.ZlibEncodeOptions = .{
                .mode = mode,
                .dictionary = dictionary,
                .block_len = 257,
                .compression = config(D),
            };
            const old = try legacy(D, &input, options);
            defer a.free(old);
            const current = try D.encodeZlibFrameAlloc(a, &input, options);
            defer a.free(current);
            try std.testing.expectEqualSlices(u8, old, current);
            const stats = try oracle.frame(current, &input, dictionary, 15, 0);
            try std.testing.expect(stats.blockCount() > 1);
        }
    }
}

fn exactDistances(comptime D: type) !void {
    for (9..16) |wide| {
        const bits: u8 = @intCast(wide);
        const cap = windowLen(bits);
        for ([_]usize{ cap - 1, cap, cap + 1 }) |distance| {
            const input = try a.alloc(u8, distance + 384);
            defer a.free(input);
            var random = std.Random.DefaultPrng.init(0x18c4f707 + distance);
            random.random().bytes(input[0..distance]);
            // Keep the prefix random but below the stored-fast-path entropy
            // threshold so best actually evaluates the boundary match.
            for (input[0..distance]) |*byte| byte.* &= 0x7f;
            @memcpy(input[distance..], input[0..384]);
            for ([_]D.ZlibEncodeMode{ .fixed, .dynamic, .best }) |mode| {
                var compression = config(D);
                compression.lz77_options.window_len = 65535;
                const options: D.ZlibEncodeOptions = .{ .mode = mode, .window_bits = bits, .compression = compression };
                const encoded = try D.encodeZlibFrameAlloc(a, input, options);
                defer a.free(encoded);
                const stats = try oracle.frame(encoded, input, null, bits, distance);
                if (distance <= cap)
                    try std.testing.expect(stats.target_matches != 0)
                else
                    try std.testing.expectEqual(@as(usize, 0), stats.target_matches);
            }
        }
    }
    // The identical distance-513 payload becomes legal at 10 bits. A smaller
    // window must change actual match availability, not just framing bytes.
    var input: [897]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x68999f);
    random.random().bytes(input[0..513]);
    @memcpy(input[513..], input[0..384]);
    for ([_]u8{ 9, 10 }) |bits| {
        const stats = try forms(D, &input, .{ .mode = .fixed, .window_bits = bits, .compression = config(D) }, 513);
        try std.testing.expectEqual(bits == 10, stats.target_matches != 0);
    }
}

fn literalPolicy(comptime D: type) !void {
    const input = "aaaaaaaaabbbbbbbbbccccccccc" ** 24;
    for ([_]u8{ 9, 15 }) |bits| {
        inline for (.{ .default, .filtered, .rle }) |strategy| {
            var compression = D.optionsForLevel(.best);
            compression.strategy = strategy;
            compression.lz77_options.window_len = 65535;
            const stats = try forms(D, input, .{
                .window_bits = bits,
                .mode = .dynamic_literal,
                .dictionary = "aaaaaaaaabbbbbbbbbccccccccc",
                .compression = compression,
                .block_len = 31,
            }, 1);
            try std.testing.expectEqual(@as(usize, 0), stats.matches);
            try std.testing.expectEqual((input.len + 30) / 31, stats.blocks[2]);
        }
    }
}

fn dictionarySuffixes(comptime D: type) !void {
    for (9..16) |wide| {
        const bits: u8 = @intCast(wide);
        const cap = windowLen(bits);
        const dictionary = try a.alloc(u8, cap + 777);
        defer a.free(dictionary);
        var random = std.Random.DefaultPrng.init(0x6873ac90 + cap);
        random.random().bytes(dictionary);
        const suffix = dictionary[dictionary.len - cap ..];
        const input = suffix[0..384];
        try std.testing.expect(oracle.adler32(dictionary) != oracle.adler32(suffix));
        for ([_]D.ZlibEncodeMode{ .fixed, .dynamic, .best }) |mode| {
            var compression = config(D);
            compression.lz77_options.window_len = 65535;
            const options: D.ZlibEncodeOptions = .{ .window_bits = bits, .mode = mode, .dictionary = dictionary, .compression = compression };
            const stats = try forms(D, input, options, cap);
            try std.testing.expect(stats.dictionary_matches != 0);
            try std.testing.expect(stats.target_matches != 0);
            const full = try D.encodeZlibFrameAlloc(a, input, options);
            defer a.free(full);
            var suffix_options = options;
            suffix_options.dictionary = suffix;
            const tail = try D.encodeZlibFrameAlloc(a, input, suffix_options);
            defer a.free(tail);
            try std.testing.expectEqualSlices(u8, full[6..], tail[6..]);
            try std.testing.expectEqual(oracle.adler32(dictionary), std.mem.readInt(u32, full[2..6], .big));
            try std.testing.expectEqual(oracle.adler32(suffix), std.mem.readInt(u32, tail[2..6], .big));
        }
        for ([_]?[]const u8{ null, "" }) |dictionary_option| {
            for (std.meta.tags(D.ZlibEncodeMode)) |mode| {
                _ = try forms(D, "empty dictionary semantics " ** 4, .{
                    .window_bits = bits,
                    .mode = mode,
                    .dictionary = dictionary_option,
                    .compression = config(D),
                    .split_options = splitConfig(D),
                }, 0);
            }
        }
    }
}

fn splitHistory(comptime D: type) !void {
    var input: [4096]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x926a114);
    random.random().bytes(input[0..512]);
    for (512..input.len) |i| input[i] = input[i % 512];
    for (9..16) |wide| {
        const bits: u8 = @intCast(wide);
        for ([_]D.ZlibEncodeMode{ .stored, .fixed, .dynamic, .dynamic_literal, .best }) |mode| {
            const stats = try forms(D, &input, .{
                .window_bits = bits,
                .mode = mode,
                .block_len = 256,
                .compression = config(D),
            }, 512);
            try std.testing.expectEqual(@as(usize, 16), stats.blockCount());
            if (mode != .stored and mode != .dynamic_literal) {
                try std.testing.expect(stats.cross_block_matches != 0);
                try std.testing.expect(stats.target_matches != 0);
            }
        }
        _ = try forms(D, &input, .{
            .window_bits = bits,
            .mode = .adaptive,
            .compression = config(D),
            .split_options = splitConfig(D),
        }, 512);
    }

    var dictionary: [40_000]u8 = undefined;
    var residual: [512]u8 = undefined;
    random.random().bytes(&dictionary);
    for (&dictionary) |*byte| byte.* &= 0x7f;
    random.random().bytes(residual[0..256]);
    for (residual[0..256]) |*byte| byte.* |= 0x80;
    @memcpy(residual[256..], dictionary[dictionary.len - 256 ..]);
    for ([_]D.ZlibEncodeMode{ .fixed, .dynamic, .best, .adaptive }) |mode| {
        const stats = try forms(D, &residual, .{
            .window_bits = 9,
            .mode = mode,
            .dictionary = &dictionary,
            .block_len = if (mode == .adaptive) null else 256,
            .compression = config(D),
            .split_options = .{ .min_block_len = 256, .max_block_len = 256, .sample_len = 64, .search_step = 256 },
        }, 512);
        try std.testing.expect(stats.dictionary_matches != 0);
        try std.testing.expect(stats.target_matches != 0);
    }
}

fn bestCandidatePolicies(comptime D: type) !void {
    // The long-distance period makes an accidentally widened recursive
    // default-parser fallback attractive. A few short runs ensure the capped
    // candidates also contain real match tokens that the oracle can audit.
    const input = try a.alloc(u8, 66_048);
    defer a.free(input);
    var random = std.Random.DefaultPrng.init(0xdaa94b15);
    random.random().bytes(input[0..1024]);
    @memset(input[128..256], 'q');
    for (1024..input.len) |i| input[i] = input[i % 1024];
    for ([_]usize{ 512, 127 }) |parser_window| {
        for ([_]usize{ 8192, input.len }) |len| {
            var compression = D.optionsForLevel(.best);
            compression.lz77_options.window_len = parser_window;
            compression.lz77_options.max_chain = 16;
            compression.lz77_options.max_candidates = 4;
            for ([_]bool{ false, true }) |refinement| {
                compression.dynamic_cost_refinement = refinement;
                const options: D.ZlibEncodeOptions = .{ .window_bits = 9, .mode = .best, .compression = compression };
                const encoded = try D.encodeZlibFrameAlloc(a, input[0..len], options);
                defer a.free(encoded);
                const stats = try oracle.frame(encoded, input[0..len], null, 9, 1024);
                try std.testing.expect(stats.matches != 0);
                _ = try oracle.raw(encoded[2 .. encoded.len - 4], input[0..len], "", parser_window, 1024);
                // Null and nonnull-empty dictionaries select separate legacy
                // paths. Full dictionary IDs remain distinct from raw history.
                for ([_][]const u8{ "", input[0..2048] }) |dictionary| {
                    var with_dictionary = options;
                    with_dictionary.dictionary = dictionary;
                    const dict_frame = try D.encodeZlibFrameAlloc(a, input[0..len], with_dictionary);
                    defer a.free(dict_frame);
                    _ = try oracle.frame(dict_frame, input[0..len], dictionary, 9, 1024);
                    _ = try oracle.raw(dict_frame[6 .. dict_frame.len - 4], input[0..len], dictionary, parser_window, 1024);
                }
            }
        }
    }
    // Direct public candidate policies complement the best winner audit; each
    // seed/fallback policy is independently encoded at the same advertised cap.
    inline for (.{ .hash, .greedy, .lazy, .optimal }) |parser| {
        inline for (.{ .default, .filtered, .huffman_only, .rle }) |strategy| {
            var compression = config(D);
            compression.parser = parser;
            compression.strategy = strategy;
            compression.lz77_options.window_len = 512;
            const options: D.ZlibEncodeOptions = .{ .window_bits = 9, .mode = .best, .compression = compression };
            const encoded = try D.encodeZlibFrameAlloc(a, input[0..8192], options);
            defer a.free(encoded);
            _ = try oracle.frame(encoded, input[0..8192], null, 9, 1024);
        }
    }
}

fn storedChunks(comptime D: type) !void {
    const input = matrixInput();
    const chunks = [_][]const u8{ "", input[0..1], "", input[1..512], input[512..2049], "", input[2049..], "" };
    for (9..16) |wide| {
        const bits: u8 = @intCast(wide);
        for ([_]?[]const u8{ null, "", "stored chunks dictionary" }) |dictionary| {
            for ([_]?usize{ null, 257 }) |block_len| {
                const options: D.ZlibEncodeOptions = .{ .window_bits = bits, .mode = .stored, .dictionary = dictionary, .block_len = block_len };
                var encoder = try D.ZlibFrameEncoder.init(a, options);
                defer encoder.deinit();
                const encoded = try encoder.encodeStoredChunksAlloc(&chunks);
                defer a.free(encoded);
                const stats = try oracle.frame(encoded, &input, dictionary, bits, 0);
                try std.testing.expectEqual(if (block_len) |n| (input.len + n - 1) / n else @as(usize, 1), stats.blockCount());
                var out: std.ArrayList(u8) = .empty;
                defer out.deinit(a);
                try out.appendSlice(a, prefix);
                try std.testing.expectEqual(encoded.len, try encoder.encodeStoredChunksAppend(&out, &chunks));
                try std.testing.expectEqualSlices(u8, prefix, out.items[0..prefix.len]);
                try std.testing.expectEqualSlices(u8, encoded, out.items[prefix.len..]);
                const buffer = try a.alloc(u8, encoded.len + 32);
                defer a.free(buffer);
                @memset(buffer, guard);
                try std.testing.expectEqual(encoded.len, try encoder.encodeStoredChunksInto(&chunks, buffer[16 .. buffer.len - 16]));
                try std.testing.expectEqualSlices(u8, encoded, buffer[16 .. buffer.len - 16]);
                try expectGuard(buffer[0..16]);
                try expectGuard(buffer[buffer.len - 16 ..]);
                try std.testing.expectEqualSlices(u8, encoded, try encoder.encodeStoredChunksScratch(&chunks));
                const empty_chunks = [_][]const u8{ "", "" };
                _ = try oracle.frame(try encoder.encodeStoredChunksScratch(&empty_chunks), "", dictionary, bits, 0);
                if (bits == 15 and block_len == null) {
                    const old = if (dictionary) |dict|
                        try D.encodeZlibStoredWithDictionaryChunksAlloc(a, &chunks, dict)
                    else
                        try D.encodeZlibStoredChunksAlloc(a, &chunks);
                    defer a.free(old);
                    try std.testing.expectEqualSlices(u8, old, encoded);
                }
            }
        }
    }
}

fn invalidWindows(comptime D: type) !void {
    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0, .resize_fail_index = 0 });
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, prefix);
    const saved_ptr = out.items.ptr;
    const saved_capacity = out.capacity;
    var output: [64]u8 = @splat(guard);
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        for (std.meta.tags(D.ZlibEncodeMode)) |mode| {
            for ([_]?[]const u8{ null, "", "dictionary" }) |dictionary| {
                const options: D.ZlibEncodeOptions = .{ .window_bits = bits, .mode = mode, .dictionary = dictionary };
                for ([_][]const u8{ "", "payload payload" }) |input| {
                    try std.testing.expectError(error.InvalidZlibWindow, D.encodeZlibFrameAlloc(denied.allocator(), input, options));
                    try std.testing.expectError(error.InvalidZlibWindow, D.encodeZlibFrameAppend(denied.allocator(), &out, input, options));
                    try std.testing.expectEqualSlices(u8, prefix, out.items);
                    try std.testing.expect(out.items.ptr == saved_ptr);
                    try std.testing.expectEqual(saved_capacity, out.capacity);
                    try std.testing.expectError(error.InvalidZlibWindow, D.encodeZlibFrameInto(denied.allocator(), input, output[16..48], options));
                    try expectGuard(&output);
                    try std.testing.expectError(error.InvalidZlibWindow, D.encodeZlibFrameInto(denied.allocator(), input, output[16..16], options));
                    try expectGuard(&output);
                }
                try std.testing.expectError(error.InvalidZlibWindow, D.ZlibFrameEncoder.init(denied.allocator(), options));
            }
        }
    }
    for ([_]u8{ 9, 15 }) |bits| {
        const options: D.ZlibEncodeOptions = .{ .window_bits = bits, .mode = .png_ultrafast, .block_len = 1 };
        try std.testing.expectError(error.InvalidBlockPlan, D.encodeZlibFrameAlloc(denied.allocator(), "payload", options));
        try std.testing.expectError(error.InvalidBlockPlan, D.encodeZlibFrameAppend(denied.allocator(), &out, "payload", options));
        try std.testing.expectError(error.InvalidBlockPlan, D.encodeZlibFrameInto(denied.allocator(), "payload", output[16..48], options));
        try std.testing.expectError(error.InvalidBlockPlan, D.ZlibFrameEncoder.init(denied.allocator(), options));
        try std.testing.expectEqualSlices(u8, prefix, out.items);
        try expectGuard(&output);
    }
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expectEqual(@as(usize, 0), denied.resize_index);
}

fn optionTransitions(comptime D: type) !void {
    const input = matrixInput();
    var heap = std.testing.FailingAllocator.init(a, .{});
    const original: D.ZlibEncodeOptions = .{ .mode = .fixed, .window_bits = 10, .dictionary = "", .compression = config(D) };
    var encoder = try D.ZlibFrameEncoder.init(heap.allocator(), original);
    defer encoder.deinit();
    const retained = try encoder.encodeScratch(&input);
    const copy = try a.dupe(u8, retained);
    defer a.free(copy);
    const allocations = heap.alloc_index;
    const resizes = heap.resize_index;
    heap.fail_index = allocations;
    heap.resize_fail_index = resizes;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(a);
    try out.appendSlice(a, prefix);
    var output: [64]u8 = @splat(guard);
    const chunks = [_][]const u8{ "", input[0..513], input[513..] };
    for ([_]u8{ 0, 8, 16, 255 }) |bits| {
        var invalid = original;
        invalid.window_bits = bits;
        invalid.mode = .dynamic;
        invalid.dictionary = "new dictionary";
        try std.testing.expectError(error.InvalidZlibWindow, encoder.setOptions(invalid));
        try std.testing.expectEqualDeep(original, encoder.options);
        try std.testing.expectEqualSlices(u8, copy, retained);
        // Options are caller-visible state. Every encode frontend must still
        // validate a rejected direct mutation before touching any output.
        encoder.options = invalid;
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeAlloc(&input));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeAppend(&out, &input));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeInto(&input, output[16..48]));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeScratch(&input));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeStoredChunksAlloc(&chunks));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeStoredChunksAppend(&out, &chunks));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeStoredChunksInto(&chunks, output[16..48]));
        try std.testing.expectError(error.InvalidZlibWindow, encoder.encodeStoredChunksScratch(&chunks));
        try std.testing.expectEqualSlices(u8, copy, retained);
        try std.testing.expectEqualSlices(u8, prefix, out.items);
        try expectGuard(&output);
        encoder.options = original;
        try std.testing.expectEqual(allocations, heap.alloc_index);
        try std.testing.expectEqual(resizes, heap.resize_index);
    }
    heap.fail_index = std.math.maxInt(usize);
    heap.resize_fail_index = std.math.maxInt(usize);
    const after = try encoder.encodeAlloc(&input);
    defer heap.allocator().free(after);
    try std.testing.expectEqualSlices(u8, copy, after);
    _ = try oracle.frame(after, &input, "", 10, 513);
    const replacement: D.ZlibEncodeOptions = .{ .mode = .dynamic, .window_bits = 9, .compression = config(D) };
    try encoder.setOptions(replacement);
    const changed = try encoder.encodeScratch(&input);
    const stats = try oracle.frame(changed, &input, null, 9, 513);
    try std.testing.expectEqual(@as(usize, 0), stats.target_matches);
}

fn levels(comptime D: type) !void {
    const input = "numeric compression level and RFC 1950 window " ** 12;
    for (9..16) |wide| {
        const bits: u8 = @intCast(wide);
        for (0..10) |n| {
            const level: u4 = @intCast(n);
            const options = try D.zlibEncodeOptionsForLevel(level, bits);
            try std.testing.expectEqual(bits, options.window_bits);
            const encoded = try D.encodeZlibFrameAlloc(a, input, options);
            defer a.free(encoded);
            _ = try oracle.frame(encoded, input, null, bits, 0);
            if (bits == 15) {
                const old = try D.encodeZlibLevelAlloc(a, input, level);
                defer a.free(old);
                try std.testing.expectEqualSlices(u8, old, encoded);
            }
        }
    }
    for ([_]u8{ 0, 8, 16, 255 }) |bits|
        try std.testing.expectError(error.InvalidZlibWindow, D.zlibEncodeOptionsForLevel(0, bits));
    try std.testing.expectError(error.InvalidBlockPlan, D.zlibEncodeOptionsForLevel(10, 15));
}
