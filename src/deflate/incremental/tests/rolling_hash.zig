const std = @import("std");
const deflate = @import("../../../deflate.zig");

test "raw deflate incremental hash encoder persists index across blocks and reset" {
    const phrase = "persistent-hash-chain-across-incremental-blocks-0123456789";
    const payload = (phrase ** 10) ++ ("separator" ** 5) ++ (phrase ** 10);
    var compression = deflate.optionsForLevel(.fastest);
    compression.block_selection = .stored_fixed_dynamic;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = phrase.len * 4,
        .compression = compression,
    });
    defer encoder.deinit();

    const encoded = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const used = encoder.matchFinderSnapshot();
    const encoder_used = encoder.snapshot();
    try std.testing.expect(used.initialized);
    try std.testing.expectEqual(payload.len, used.absolute_position);
    try std.testing.expect(used.indexed_positions > 0);
    try std.testing.expectEqual(@as(usize, 3 * 32 * 1024), used.table_entries);
    try std.testing.expect(encoder_used.retained_token_capacity > 0);

    encoder.reset();
    const reset = encoder.matchFinderSnapshot();
    const encoder_reset = encoder.snapshot();
    try std.testing.expect(!reset.initialized);
    try std.testing.expectEqual(@as(usize, 0), reset.absolute_position);
    try std.testing.expectEqual(@as(usize, 0), reset.indexed_positions);
    // Reset advances an epoch and retains caller-paid table capacity rather
    // than clearing/reallocating the persistent index.
    try std.testing.expectEqual(used.table_entries, reset.table_entries);
    try std.testing.expectEqual(encoder_used.retained_token_capacity, encoder_reset.retained_token_capacity);

    const encoded_again = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded_again);
    try std.testing.expectEqualSlices(u8, encoded, encoded_again);
}

test "raw deflate incremental hash encoder retains preset dictionary index" {
    const dictionary = "dictionary-prefix: persistent rolling hash phrase and shared suffix";
    const payload = "persistent rolling hash phrase and shared suffix plus payload";
    var compression = deflate.optionsForLevel(.fast);
    compression.block_selection = .stored_fixed_dynamic;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithDictionary(std.testing.allocator, .{
        .block_len = 13,
        .compression = compression,
    }, dictionary);
    defer encoder.deinit();

    const encoded = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, encoded, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(payload.len + dictionary.len, encoder.matchFinderSnapshot().absolute_position);
}

test "raw deflate incremental hash beats rebuilding split reference index" {
    const dictionary = "reference-dictionary-prefix-abcdefghijklmnopqrstuvwxyz";
    const payload = ("abcdefghijklmnopqrstuvwxyz-reference-payload-" ** 9) ++ "tail";
    const options = deflate.optionsForLevel(.fastest);
    const block_len: usize = 47;

    var encoder = deflate.RawDeflateIncrementalFixedEncoder.initWithDictionary(std.testing.allocator, .{
        .block_len = block_len,
        .compression = options,
    }, dictionary);
    defer encoder.deinit();
    const incremental = try encodeFixedStream(&encoder, payload);
    defer std.testing.allocator.free(incremental);
    const reference = try deflate.encodeRawFixedSplitWithDictionaryAlloc(
        std.testing.allocator,
        payload,
        dictionary,
        block_len,
        options,
    );
    defer std.testing.allocator.free(reference);
    // The one-shot split reference rebuilds its dictionary hash table for each
    // block. Persistent heads can retain more useful recent candidates and
    // therefore intentionally produce a different, no-larger stream.
    try std.testing.expect(incremental.len <= reference.len);
    const decoded = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, incremental, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "raw deflate incremental lazy encoder persists dense chains" {
    const phrase = "lazy-cross-block-phrase:abcdefghijklmnopqrstuvwxyz0123456789";
    const payload = (phrase ** 12) ++ "interstitial" ++ (phrase ** 12);
    var compression = deflate.optionsForLevel(.default);
    compression.block_selection = .stored_fixed_dynamic;
    const block_len = phrase.len * 3 + 7;

    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = block_len,
        .compression = compression,
    });
    defer encoder.deinit();
    const incremental = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(incremental);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, incremental);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const snapshot = encoder.matchFinderSnapshot();
    try std.testing.expect(snapshot.initialized);
    try std.testing.expectEqual(payload.len, snapshot.absolute_position);
    try std.testing.expect(snapshot.indexed_positions > 0);

    const reference = try deflate.encodeRawBestSplitAlloc(
        std.testing.allocator,
        payload,
        block_len,
        compression,
    );
    defer std.testing.allocator.free(reference);
    try std.testing.expect(incremental.len <= reference.len);

    encoder.reset();
    const again = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(again);
    try std.testing.expectEqualSlices(u8, incremental, again);
}

test "raw deflate incremental lazy encoder seeds preset dictionary" {
    const dictionary = "default lazy preset dictionary phrase shared across stream blocks";
    const payload = "preset dictionary phrase shared across stream blocks and repeated blocks " ** 4;
    const compression = deflate.optionsForLevel(.default);
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithDictionary(std.testing.allocator, .{
        .block_len = 29,
        .compression = compression,
    }, dictionary);
    defer encoder.deinit();

    const encoded = try encodeStream(&encoder, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAllocWithDictionary(std.testing.allocator, encoded, dictionary);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectEqual(dictionary.len + payload.len, encoder.matchFinderSnapshot().absolute_position);
}

test "raw deflate incremental matcher safely changes parser modes" {
    const first = "hash-mode-prefix-abcdefghijklmnopqrstuvwxyz0123456789" ** 3;
    const second = "lazy-mode-suffix-abcdefghijklmnopqrstuvwxyz0123456789" ** 3;
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = first.len,
        .compression = deflate.optionsForLevel(.fastest),
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [17]u8 = undefined;

    // The extra byte forces publication of the first hash-parsed block and is
    // then retained as the next block's first byte. Changing options must reset
    // and reseed the index from history rather than mixing hash policies.
    var first_with_prefix = first ++ second[0..1].*;
    var offset: usize = 0;
    while (offset < first_with_prefix.len) {
        const result = try encoder.step(first_with_prefix[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.options.compression = deflate.optionsForLevel(.default);
    offset = 1;
    while (offset < second.len) {
        const result = try encoder.step(second[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }

    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
    try std.testing.expect(encoder.matchFinderSnapshot().initialized);
}

test "raw deflate incremental matcher preserves offsets across unindexed mode" {
    const block_len: usize = 96;
    const hash_block = ("hash-prefix-abcdefghijklmnopqrstuvwxyz" ** 4)[0..block_len];
    const literal_block = ("literal-middle-0123456789" ** 4)[0..block_len];
    const lazy_block = ("lazy-suffix-ABCDEFGHIJKLMNOPQRSTUVWXYZ" ** 4)[0..block_len];
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = block_len,
        .compression = deflate.optionsForLevel(.fastest),
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [19]u8 = undefined;

    try feedAndForceBlock(&encoder, &encoded, hash_block, literal_block[0]);
    encoder.options.compression.strategy = .huffman_only;
    try feedAndForceBlock(&encoder, &encoded, literal_block[1..], lazy_block[0]);
    encoder.options.compression = deflate.optionsForLevel(.default);
    var offset: usize = 1;
    while (offset < lazy_block.len) {
        const result = try encoder.step(lazy_block[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }

    const expected = hash_block ++ literal_block ++ lazy_block;
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
    try std.testing.expectEqual(expected.len, encoder.matchFinderSnapshot().absolute_position);
}

test "raw deflate incremental stored probe preserves repeated binary history" {
    var first: [32 * 1024]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x6a09_e667_f3bc_c909);
    random.random().bytes(&first);
    var payload: [2 * first.len]u8 = undefined;
    @memcpy(payload[0..first.len], &first);
    @memcpy(payload[first.len..], &first);
    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = first.len,
        .compression = deflate.optionsForLevel(.default),
    });
    defer encoder.deinit();

    const encoded = try encodeStream(&encoder, &payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
    try std.testing.expectEqual(deflate.RawDeflateBlockType.stored, (try deflate.parseRawDeflateHeaderInfo(encoded)).block_type);

    const stored = try deflate.encodeRawStoredAlloc(std.testing.allocator, &payload);
    defer std.testing.allocator.free(stored);
    // The first block takes the stored fast path, but sparse history probes
    // route the repeated second block through the matcher instead of storing it.
    try std.testing.expect(encoded.len < stored.len - first.len / 2);
}

test "raw deflate incremental low entropy blocks amortize dynamic headers" {
    const payload = "a" ** (256 * 1024);
    var coalesced = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 32 * 1024,
        .low_entropy_block_len = payload.len,
        .compression = deflate.optionsForLevel(.default),
    });
    defer coalesced.deinit();
    const encoded = try encodeStream(&coalesced, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var fixed = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 32 * 1024,
        .compression = deflate.optionsForLevel(.default),
    });
    defer fixed.deinit();
    const fixed_encoded = try encodeStream(&fixed, payload);
    defer std.testing.allocator.free(fixed_encoded);
    try std.testing.expect(encoded.len + 64 < fixed_encoded.len);

    const one_shot = try deflate.encodeRawBestAlloc(std.testing.allocator, payload, deflate.optionsForLevel(.default));
    defer std.testing.allocator.free(one_shot);
    try std.testing.expectEqual(one_shot.len, encoded.len);
}

test "raw deflate incremental low entropy decision resets after block" {
    const low_len = 2048;
    const high_len = 1025;
    var payload: [low_len + high_len]u8 = undefined;
    @memset(payload[0..low_len], 'a');
    for (payload[low_len..], 0..) |*byte, i|
        byte.* = @intCast((i * 37 + i / 11) % 251);

    var encoder = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 1024,
        .low_entropy_block_len = low_len,
        .compression = deflate.optionsForLevel(.default),
    });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    var scratch: [4096]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 127);
        const result = try encoder.step(payload[offset..end], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    // The low-entropy block consumed 2 KiB, then the high-entropy block
    // returned to the normal 1 KiB target instead of inheriting expansion.
    try std.testing.expectEqual(@as(usize, 1), encoder.snapshot().buffered_input);

    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    const decoded = try deflate.decodeRawAutoAlloc(std.testing.allocator, encoded.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &payload, decoded);
}

test "raw deflate incremental low entropy block limit validates bounds" {
    var invalid = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(std.testing.allocator, .{
        .block_len = 1024,
        .low_entropy_block_len = 512,
    });
    defer invalid.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, invalid.step("x", &.{}));
}

fn feedAndForceBlock(encoder: *deflate.RawDeflateIncrementalBestEncoder, encoded: *std.ArrayList(u8), block: []const u8, next: u8) !void {
    var joined = try std.testing.allocator.alloc(u8, block.len + 1);
    defer std.testing.allocator.free(joined);
    @memcpy(joined[0..block.len], block);
    joined[block.len] = next;
    var scratch: [19]u8 = undefined;
    var offset: usize = 0;
    while (offset < joined.len) {
        const result = try encoder.step(joined[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
}

fn encodeStream(encoder: *deflate.RawDeflateIncrementalBestEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [11]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + 7);
        const result = try encoder.step(payload[offset..end], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(std.testing.allocator);
}

fn encodeFixedStream(encoder: *deflate.RawDeflateIncrementalFixedEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(std.testing.allocator);
    var scratch: [13]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(std.testing.allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(std.testing.allocator);
}
