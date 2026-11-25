//! Reference-produced, checksummed frames exercise frame-atomic publication
//! and catalog recovery across a standard Zstd dictionary rotation.
const std = @import("std");
const vort = @import("vort");
const Runtime = @import("../zstd/libzstd_runtime.zig").Runtime;
const Dictionary = vort.ZstdNativeDictionary;
const DictionarySet = vort.ZstdNativeDictionarySet;

const block_max = 128 * 1024;
const history_prefix_len = 8 * 1024;
const sentinel: u8 = 0xa5;

pub const Receipt = struct {
    frames: [2]FrameReceipt,
    source_bytes: usize,
    missing_dictionary: FailureReceipt,
    retry: vort.ZstdSourceStreamProgress,
    retry_min_read_offset: u64,
    wrong_dictionary: FailureReceipt,
};

const FrameReceipt = struct {
    dictionary_id: u32,
    dictionary_bytes: usize,
    history_bytes: usize,
    wire_offset: u64,
    wire_bytes: usize,
    decoded_bytes: usize,
    blocks: usize,
    upstream_wrong_history_error: []const u8,
};

const FailureReceipt = struct {
    error_name: []const u8,
    frame_offset: u64,
    dictionary_id: u32,
    progress: vort.ZstdSourceStreamProgress,
};

const Member = struct {
    serialized: []u8,
    mutated: []u8,
    dictionary: Dictionary,
    wrong_dictionary: Dictionary,
    plain: []u8,
    wire: []u8,
    blocks: usize,
    upstream_wrong_history_error: []const u8,

    fn deinit(self: Member, a: std.mem.Allocator) void {
        a.free(self.wire);
        a.free(self.plain);
        a.free(self.mutated);
        a.free(self.serialized);
    }

    fn receipt(self: Member, offset: u64) FrameReceipt {
        return .{
            .dictionary_id = self.dictionary.id,
            .dictionary_bytes = self.serialized.len,
            .history_bytes = self.dictionary.content.len,
            .wire_offset = offset,
            .wire_bytes = self.wire.len,
            .decoded_bytes = self.plain.len,
            .blocks = self.blocks,
            .upstream_wrong_history_error = self.upstream_wrong_history_error,
        };
    }
};

fn require(ok: bool) !void {
    if (!ok) return error.ZstdDictionaryRotationMismatch;
}

pub fn verify(a: std.mem.Allocator) !Receipt {
    var upstream = try Runtime.open();
    defer upstream.deinit();
    const first = try makeMember(a, upstream, 0x1357_9bdf, 160 * 1024 + 193);
    defer first.deinit(a);
    const second = try makeMember(a, upstream, 0x4c91_e713, 160 * 1024 + 894);
    defer second.deinit(a);
    try require(first.dictionary.id != second.dictionary.id);

    const wire = try std.mem.concat(a, u8, &.{ first.wire, second.wire });
    defer a.free(wire);
    const second_offset: u64 = first.wire.len;
    const total_decoded = first.plain.len + second.plain.len;
    const max_decoded = @max(first.plain.len, second.plain.len);
    var reader: GuardedSource = .{ .bytes = wire };
    const source = reader.source();

    const history = try a.alloc(u8, block_max + @max(first.dictionary.content.len, second.dictionary.content.len));
    defer a.free(history);
    const staging = try a.alloc(u8, block_max);
    defer a.free(staging);
    var literal_page: [1024]u8 = undefined;
    var sequence_page: [1024]u8 = undefined;
    const workspace: vort.ZstdSourceFrameWorkspace = .{
        .history = history,
        .staging = staging,
        .literal_page = &literal_page,
        .sequence_page = &sequence_page,
    };
    const frame_scratch = try a.alloc(u8, max_decoded);
    defer a.free(frame_scratch);
    const output = try a.alloc(u8, total_decoded + 16);
    defer a.free(output);
    @memset(output, sentinel);

    const partial = [_]Dictionary{first.dictionary};
    var options: vort.ZstdSourceStreamDecodeOptions = .{
        .dictionary_set = try DictionarySet.initChecked(&partial),
        .frame_decoded_max = max_decoded,
        .total_decoded_max = total_decoded,
        .max_window_size = block_max,
        .max_frames = 2,
    };
    const checkpoint: vort.ZstdSourceStreamCheckpoint = .{
        .compressed_offset = second_offset,
        .decoded_len = first.plain.len,
        .data_frames = 1,
    };
    const missing = try verifyFailure(
        vort.zstdDecodeVerifiedSourceStreamIntoWithProgress(source, output, workspace, frame_scratch, options, null),
        checkpoint,
        second,
        output,
        first.plain,
        .missing,
    );

    // Keep the source and destination prefix; a resumed read of A is refused.
    const reversed = [_]Dictionary{ second.dictionary, first.dictionary };
    options.dictionary_set = try DictionarySet.initChecked(&reversed);
    reader.read_floor = missing.progress.checkpoint.compressed_offset;
    reader.min_read_offset = null;
    const retry = switch (vort.zstdDecodeVerifiedSourceStreamIntoWithProgress(
        source,
        output[missing.progress.complete_output_written..],
        workspace,
        frame_scratch,
        options,
        missing.progress.checkpoint,
    )) {
        .complete => |progress| progress,
        .failed => |failure| return failure.err,
    };
    const retry_min_read_offset = reader.min_read_offset orelse return error.ZstdDictionaryRotationMismatch;
    try require(!reader.read_before_floor and retry_min_read_offset == second_offset);
    try require(std.meta.eql(retry, vort.ZstdSourceStreamProgress{
        .checkpoint = .{ .compressed_offset = wire.len, .decoded_len = total_decoded, .data_frames = 2 },
        .output_written = second.plain.len,
        .complete_output_written = second.plain.len,
    }));
    try require(std.mem.eql(u8, output[0..first.plain.len], first.plain));
    try require(std.mem.eql(u8, output[first.plain.len..total_decoded], second.plain));
    try require(std.mem.allEqual(u8, output[total_decoded..], sentinel));

    const wrong = [_]Dictionary{ first.dictionary, second.wrong_dictionary };
    options.dictionary_set = try DictionarySet.initChecked(&wrong);
    reader.read_floor = 0;
    @memset(output, sentinel);
    const rejected = try verifyFailure(
        vort.zstdDecodeVerifiedSourceStreamIntoWithProgress(source, output, workspace, frame_scratch, options, null),
        checkpoint,
        second,
        output,
        first.plain,
        .wrong_history,
    );
    return .{
        .frames = .{ first.receipt(0), second.receipt(second_offset) },
        .source_bytes = wire.len,
        .missing_dictionary = missing,
        .retry = retry,
        .retry_min_read_offset = retry_min_read_offset,
        .wrong_dictionary = rejected,
    };
}

const FailureKind = enum { missing, wrong_history };

fn verifyFailure(
    outcome: vort.ZstdSourceStreamOutcome,
    checkpoint: vort.ZstdSourceStreamCheckpoint,
    pending: Member,
    output: []const u8,
    prefix: []const u8,
    kind: FailureKind,
) !FailureReceipt {
    const failure = switch (outcome) {
        .complete => return error.ZstdDictionaryRotationUnexpectedSuccess,
        .failed => |failure| failure,
    };
    switch (kind) {
        .missing => if (failure.err != error.NeedDictionary) return failure.err,
        .wrong_history => switch (failure.err) {
            error.ChecksumMismatch, error.CorruptFrame, error.InvalidMatch => {},
            else => return failure.err,
        },
    }
    const frame = failure.frame orelse return error.ZstdDictionaryRotationMismatch;
    try require(frame.offset == checkpoint.compressed_offset and frame.dictionary_id == pending.dictionary.id and
        frame.content_size == pending.plain.len and frame.has_checksum);
    try require(std.meta.eql(failure.progress, vort.ZstdSourceStreamProgress{
        .checkpoint = checkpoint,
        .output_written = prefix.len,
        .complete_output_written = prefix.len,
    }));
    try require(std.mem.eql(u8, output[0..prefix.len], prefix));
    try require(std.mem.allEqual(u8, output[prefix.len..], sentinel));
    return .{
        .error_name = @errorName(failure.err),
        .frame_offset = frame.offset,
        .dictionary_id = frame.dictionary_id,
        .progress = failure.progress,
    };
}

fn makeMember(a: std.mem.Allocator, upstream: Runtime, seed: u32, len: usize) !Member {
    const serialized = try train(a, upstream, seed);
    errdefer a.free(serialized);
    const parsed = try Dictionary.initFromStandardDictionary(serialized);
    const dictionary = parsed.dictionary;
    try require(dictionary.id != 0 and upstream.dictionaryId(serialized) == dictionary.id and dictionary.content.len != 0);

    // Change only history bytes: magic, ID, entropy descriptions and repcodes
    // must still parse and select the same dictionary slot.
    const mutated = try a.dupe(u8, serialized);
    errdefer a.free(mutated);
    for (mutated[parsed.view.content_offset..]) |*byte| byte.* ^= 1;
    const wrong = (try Dictionary.initFromStandardDictionary(mutated)).dictionary;
    try require(wrong.id == dictionary.id and upstream.dictionaryId(mutated) == dictionary.id);

    const plain = try a.alloc(u8, len);
    errdefer a.free(plain);
    // A dictionary match is profitable immediately; unrelated filler keeps
    // both the plaintext and the wire above the maximum Zstd block size.
    for (plain[0..history_prefix_len], 0..) |*byte, i| byte.* = dictionary.content[i % dictionary.content.len];
    var state = seed ^ 0xace0_267f;
    fillBytes(plain[history_prefix_len..], &state);
    const wire = try upstream.encodeAdvancedWithDictAlloc(a, plain, .{
        .window_log = 17,
        .checksum = true,
    }, serialized);
    errdefer a.free(wire);
    const header = try vort.zstdInspectNativeFrameHeader(wire);
    try require(header.has_checksum and header.dictionary_id == dictionary.id and header.content_size == len and
        header.window_size <= block_max and wire.len > block_max and len > block_max);
    var block = try vort.zstdInspectNativeFrameBlockAt(wire, header.payload_offset);
    try require(block.block_type == .compressed);
    var blocks: usize = 1;
    while (!block.last) : (blocks += 1) {
        block = try vort.zstdInspectNativeFrameBlockAt(wire, block.next_header_offset);
    }
    try require(blocks >= 2 and block.next_header_offset + 4 == wire.len);

    const output = try a.alloc(u8, len);
    defer a.free(output);
    try upstream.decodeUsingDict(wire, output, serialized);
    try require(std.mem.eql(u8, output, plain));
    // Rejection with unchanged ID and entropy proves the wire actually uses
    // the dictionary history, not just its ID or entropy tables.
    const rejected = if (upstream.decodeUsingDict(wire, output, mutated)) |_| {
        return error.ZstdDictionaryRotationUnexpectedSuccess;
    } else |err| err;
    if (rejected != error.ReferenceDecodeFailed) return rejected;
    return .{
        .serialized = serialized,
        .mutated = mutated,
        .dictionary = dictionary,
        .wrong_dictionary = wrong,
        .plain = plain,
        .wire = wire,
        .blocks = blocks,
        .upstream_wrong_history_error = @errorName(rejected),
    };
}

fn train(a: std.mem.Allocator, upstream: Runtime, seed: u32) ![]u8 {
    var state = seed;
    var motifs: [8][192]u8 = undefined;
    for (&motifs) |*motif| fillBytes(motif, &state);
    var storage: [64][512]u8 = undefined;
    var samples: [storage.len][]const u8 = undefined;
    for (&storage, &samples, 0..) |*bytes, *sample, i| {
        @memcpy(bytes[0..192], &motifs[i % motifs.len]);
        fillBytes(bytes[192..256], &state);
        @memcpy(bytes[256..448], &motifs[(i / motifs.len + i) % motifs.len]);
        fillBytes(bytes[448..512], &state);
        sample.* = bytes;
    }
    return upstream.trainDictionaryAlloc(a, &samples, 2048);
}

fn fillBytes(bytes: []u8, state: *u32) void {
    for (bytes) |*byte| {
        state.* = state.* *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state.* >> 24);
    }
}

const GuardedSource = struct {
    bytes: []const u8,
    read_floor: u64 = 0,
    min_read_offset: ?u64 = null,
    read_before_floor: bool = false,

    fn source(self: *GuardedSource) vort.ByteSource {
        return .{ .context = self, .len = self.bytes.len, .read_at = readAt };
    }

    fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *GuardedSource = @ptrCast(@alignCast(context));
        if (offset < self.read_floor) {
            self.read_before_floor = true;
            return error.SourceReadFailed;
        }
        self.min_read_offset = @min(self.min_read_offset orelse offset, offset);
        const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
        if (start >= self.bytes.len) return 0;
        const size = @min(output.len, self.bytes.len - start);
        @memcpy(output[0..size], self.bytes[start..][0..size]);
        return size;
    }
};
