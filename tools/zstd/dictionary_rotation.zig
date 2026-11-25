//! Upstream multiblock frames exercise dictionary changes independently of
//! Vort's encoder. Never infer a member boundary from .done alone.
const std = @import("std");
const vort = @import("vort");
const Runtime = @import("libzstd_runtime.zig").Runtime;
const Z = vort.zstd;
const Decoder = Z.NativeIncrementalFrameDecoder;
const Dictionary = Z.NativeDictionary;
const Set = Z.NativeDictionarySet;

const rotation = [_]usize{ 0, 1, 1, 0 };
const markers = [_][]const u8{ "leading marker", "between dictionaries" };
const window = 128 * 1024;
const canary: u8 = 0xa5;

pub const Receipt = struct { frames: usize, blocks: usize, requests: usize, plaintext: usize };
const Member = struct { start: usize, header_end: usize, end: usize, output_end: usize };
const Progress = struct { read: usize = 0, written: usize = 0 };
const Mode = enum { catalog, stopped_recovery, rolling_recovery };

fn require(ok: bool) !void {
    if (!ok) return error.DictionaryRotationMismatch;
}

pub fn verify(a: std.mem.Allocator, ref: Runtime, serialized: [2][]const u8) !Receipt {
    const dictionaries = [2]Dictionary{
        (try Dictionary.initFromStandardDictionary(serialized[0])).dictionary,
        (try Dictionary.initFromStandardDictionary(serialized[1])).dictionary,
    };
    const set = try Set.initChecked(&dictionaries);
    const partial = try Set.initChecked(dictionaries[0..1]);
    try require(dictionaries[0].id != dictionaries[1].id and
        !std.mem.eql(u8, dictionaries[0].content, dictionaries[1].content));

    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var plain: std.ArrayList(u8) = .empty;
    defer plain.deinit(a);
    var members: [rotation.len]Member = undefined;
    var blocks: usize = 0;
    for (rotation, 0..) |which, i| {
        if (i < markers.len) try Z.encodeSkippableFrameAppend(a, &wire, @intCast(3 + i), markers[i]);
        const dict = dictionaries[which];
        const seed = dict.content[dict.content.len - @min(dict.content.len, 2048) ..];
        try require(seed.len != 0);
        const data = try plain.addManyAsSlice(a, window + 8193 + i * 701);
        for (data, 0..) |*byte, j| byte.* = seed[j % seed.len];
        data[data.len - 1] = @intCast(i);
        const frame = try ref.encodeAdvancedWithDictAlloc(a, data, .{
            .window_log = 17,
            .content_size = i % 2 == 0,
            .checksum = true,
        }, serialized[which]);
        defer a.free(frame);
        const header = try Z.inspectNativeFrameHeader(frame);
        try require(header.dictionary_id == dict.id and header.has_checksum and
            header.window_size <= window and (header.content_size != null) == (i % 2 == 0));
        const first = try Z.inspectNativeFrameFirstBlock(frame);
        try require(!first.last and first.block_type == .compressed);
        var block = first;
        blocks += 1;
        while (!block.last) {
            block = try Z.inspectNativeFrameBlockAt(frame, block.next_header_offset);
            blocks += 1;
        }
        try require(block.next_header_offset + 4 == frame.len);

        const output = try a.alloc(u8, data.len);
        defer a.free(output);
        try ref.decodeUsingDict(frame, output, serialized[which]);
        try require(std.mem.eql(u8, data, output));
        // Rewrite only the other valid dictionary's ID to rule out a refusal
        // caused solely by the frame header's ID check.
        const other = try a.dupe(u8, serialized[1 - which]);
        defer a.free(other);
        std.mem.writeInt(u32, other[4..8], dict.id, .little);
        if (ref.decodeUsingDict(frame, output, other)) |_| {
            try require(!std.mem.eql(u8, data, output));
        } else |err| if (err != error.ReferenceDecodeFailed and err != error.SizeMismatch) return err;

        members[i] = .{
            .start = wire.items.len,
            .header_end = wire.items.len + header.payload_offset,
            .end = wire.items.len + frame.len,
            .output_end = plain.items.len,
        };
        try wire.appendSlice(a, frame);
    }

    var requests: usize = 0;
    for ([_]vort.CompressedInputPolicy{ .block_stream, .prevalidated_frame }) |policy| {
        requests += try incremental(a, wire.items, plain.items, &members, dictionaries, set, policy, .catalog);
        requests += try incremental(a, wire.items, plain.items, &members, dictionaries, partial, policy, .stopped_recovery);
        requests += try incremental(a, wire.items, plain.items, &members, dictionaries, partial, policy, .rolling_recovery);
    }
    try source(a, wire.items, plain.items, &members, dictionaries, set, partial);
    return .{ .frames = members.len, .blocks = blocks, .requests = requests, .plaintext = plain.items.len };
}

fn compareStep(progress: *Progress, step: vort.Progress, input: []const u8, offered: usize, scratch: []const u8, plain: []const u8) !void {
    try require(step.input_read <= input.len and step.output_written <= offered and
        step.output_written <= plain.len - progress.written);
    try require(std.mem.allEqual(u8, scratch[step.output_written..], canary) and
        std.mem.eql(u8, scratch[0..step.output_written], plain[progress.written..][0..step.output_written]));
    progress.read += step.input_read;
    progress.written += step.output_written;
}

fn incremental(a: std.mem.Allocator, wire: []const u8, plain: []const u8, members: []const Member, dictionaries: [2]Dictionary, set: Set, policy: vort.CompressedInputPolicy, mode: Mode) !usize {
    const stopped = mode == .stopped_recovery;
    const read_ahead = mode == .rolling_recovery and policy == .prevalidated_frame;
    const fragment: usize = if (read_ahead) wire.len else if (policy == .block_stream) 1 else 23;
    var events: [markers.len]Decoder.SkippableEvent = undefined;
    var capture: [(markers[0].len + markers[1].len)]u8 = @splat(canary);
    var decoder = Decoder.initWithDictionarySetAndOptions(a, set, .{
        .input_policy = policy,
        .stop_after_first_frame = stopped,
        .expected_output_len = plain.len,
        .max_frames = rotation.len + markers.len,
        .skippable_events = &events,
        .skippable_output = &capture,
    });
    defer decoder.deinit();
    var progress: Progress = .{};
    var requests: usize = 0;
    var member: usize = 0;
    while (true) {
        const boundary = if (stopped) members[member].end else wire.len;
        const input = wire[progress.read..][0..@min(fragment, boundary - progress.read)];
        const offered: usize = 113;
        var scratch: [offered + 16]u8 = @splat(canary);
        const step = decoder.step(input, scratch[0..offered]) catch |err| {
            if (err != error.NeedDictionary or mode == .catalog) return err;
            const snap = decoder.snapshot();
            const pending: usize = @intCast(snap.data_frame_count);
            try require(pending != 0 and pending < members.len and rotation[pending] == 1 and (!stopped or pending == member));
            try compareStep(&progress, snap.last_step_progress, input, offered, &scratch, plain);
            const header_end = members[pending].header_end;
            try require((if (read_ahead) progress.read > header_end else progress.read == header_end) and
                progress.written == members[pending - 1].output_end and decoder.requiredDictionaryId() == dictionaries[1].id);
            if (decoder.provideDictionary(dictionaries[0])) |_| return error.DictionaryRotationMismatch else |wrong| {
                if (wrong != error.DictionaryMismatch) return wrong;
            }
            try require(decoder.requiredDictionaryId() == dictionaries[1].id and decoder.snapshot().input_received == progress.read and
                decoder.snapshot().output_written == progress.written);
            try decoder.provideDictionary(dictionaries[1]);
            requests += 1;
            continue;
        };
        try compareStep(&progress, step.progress, input, offered, &scratch, plain);
        if (step.status == .done and stopped) {
            try require(progress.read == boundary and progress.written == members[member].output_end and
                decoder.snapshot().data_frame_count == member + 1);
            member += 1;
            if (member == members.len) break;
            try decoder.nextStream();
            continue;
        }
        if (!stopped and progress.read == wire.len and step.status != .need_output) break;
        try require(step.progress.input_read != 0 or step.progress.output_written != 0);
    }
    try decoder.finish();
    const snap = decoder.snapshot();
    try require(progress.read == wire.len and progress.written == plain.len and snap.input_received == wire.len and
        snap.output_written == plain.len and snap.data_frame_count == members.len and snap.skippable_event_count == markers.len and
        snap.skippable_total == capture.len and requests == @as(usize, if (mode == .catalog) 0 else 2));
    try require(std.mem.eql(u8, &capture, markers[0] ++ markers[1]));
    for (events, markers, 0..) |event, marker, i| try require(event.id == 3 + i and event.payload_len == marker.len);
    return requests;
}

fn source(a: std.mem.Allocator, wire: []const u8, plain: []const u8, members: []const Member, dictionaries: [2]Dictionary, set: Set, partial: Set) !void {
    const history = try a.alloc(u8, window + @max(dictionaries[0].content.len, dictionaries[1].content.len));
    defer a.free(history);
    const staging = try a.alloc(u8, window);
    defer a.free(staging);
    var literal: [17]u8 = undefined;
    var sequence: [31]u8 = undefined;
    const workspace: Z.SourceFrameWorkspace = .{ .history = history, .staging = staging, .literal_page = &literal, .sequence_page = &sequence };
    const output = try a.alloc(u8, plain.len + 1);
    defer a.free(output);
    @memset(output, canary);
    var reader = vort.SliceByteSource{ .bytes = wire };
    const view = reader.source();
    const options: Z.SourceStreamDecodeOptions = .{
        .dictionary_set = set,
        .max_frames = rotation.len + markers.len,
        .max_window_size = window,
    };
    const inspected = try Z.inspectSourceStream(view, options);
    try require(inspected.stream_end_offset == wire.len and inspected.total_decoded == null and
        inspected.data_frames == members.len and inspected.skippable_frames == markers.len);
    const result = try Z.decodeSourceStreamInto(view, output, workspace, options);
    try require(result.stream_end_offset == wire.len and result.decoded_len == plain.len and
        result.data_frames == members.len and result.skippable_frames == markers.len and
        std.mem.eql(u8, output[0..plain.len], plain) and output[plain.len] == canary);

    var cursor = try Z.SourceStreamCursor.initWithFrameLimit(view, .standard, options.max_frames);
    var member: usize = 0;
    var skipped: usize = 0;
    var written: usize = 0;
    @memset(output, canary);
    while (try cursor.next()) |element| switch (element) {
        .skippable => |skip| {
            try require(skipped < markers.len and skip.skippable_id == 3 + skipped and
                skip.payload_len == markers[skipped].len and skip.next_offset == members[skipped].start);
            skipped += 1;
        },
        .data => |data| {
            try require(member < members.len and data.offset == members[member].start and data.dictionary_id == dictionaries[rotation[member]].id);
            if (rotation[member] == 1) {
                const missing = cursor.decodeInto(output[written..], workspace, .{ .dictionary_set = partial });
                if (missing) |_| return error.DictionaryRotationMismatch else |err| if (err != error.NeedDictionary) return err;
                try require(cursor.pending() and cursor.offset() == data.offset and cursor.totalDecoded() == written and
                    std.mem.allEqual(u8, output[written..], canary));
            }
            const decoded = try cursor.decodeInto(output[written..], workspace, options);
            written += @intCast(decoded.decoded_len);
            try require(decoded.frame_end_offset == members[member].end and written == members[member].output_end);
            member += 1;
        },
    };
    try require(member == members.len and skipped == markers.len and cursor.offset() == wire.len and
        written == plain.len and std.mem.eql(u8, output[0..written], plain) and output[written] == canary);
}
