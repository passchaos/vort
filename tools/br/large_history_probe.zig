//! Public Brotli history QA. Payload/wire/config files; JSON diagnostics only.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("br");

const Api = enum { chunks, reusable, incremental, one_shot };
const Event = enum { none, flush, metadata };
const Config = struct {
    api: Api = .incremental,
    level: br.PlannedCompressionLevel = .fast,
    quality: ?u4 = null,
    window_bits: u5 = 16,
    large_window: bool = false,
    block_len: usize = 0,
    input_chunk: usize = 4096,
    prefix_len: usize = 0,
    event: Event = .none,
    exercise_new_stream: bool = true,
    max_total_working_memory: ?usize = null,
};
const Progress = struct {
    steps: usize = 0,
    input_read: usize = 0,
    output_written: usize = 0,
    zero_input_offers: usize = 0,
    zero_output_offers: usize = 0,
    need_input: usize = 0,
    need_output: usize = 0,
    event_acknowledged: bool = false,
    caller_guards_verified: bool = true,
};
const Checkpoint = struct {
    stage: []const u8,
    accepted_input: usize,
    buffered_input: usize,
    committed_input: usize,
    history_len: usize,
    history_capacity: usize,
    history_source_start: usize,
    history_matches_committed_tail: bool,
    history_sha256: []const u8,
    retained_capacity: usize,
    stream_input: usize,
    stream_output: usize,
};
const Report = struct {
    @"error": ?[]const u8 = null,
    encoded_bound: ?usize = null,
    summary: ?br.StreamSummary = null,
    progress: Progress = .{},
    reset_progress: Progress = .{},
    checkpoints: std.ArrayList(Checkpoint) = .empty,
    maximum_observed_history_len: usize = 0,
    maximum_observed_history_capacity: usize = 0,
    maximum_observed_retained_capacity: usize = 0,
    new_stream_matches_fresh_wire: ?bool = null,
    reset_wire_bytes: ?usize = null,
    reset_wire_sha256: ?[64]u8 = null,
    reset_input_sha256: ?[64]u8 = null,
    reset_summary: ?br.StreamSummary = null,
    memory_profile: br.EncodeMemoryProfile = .{},
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const wire_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const config_json = try read(init, config_path);
    defer init.gpa.free(config_json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, config_json, .{});
    defer parsed.deinit();
    const c = parsed.value;
    if (c.prefix_len > input.len or c.input_chunk == 0 or c.input_chunk > 65536 or (c.event != .none and c.api != .incremental)) return error.InvalidConfig;
    var report: Report = .{};
    defer {
        for (report.checkpoints.items) |point| init.gpa.free(point.history_sha256);
        report.checkpoints.deinit(init.gpa);
    }
    const input_sha = digest(input);
    const wire: ?[]u8 = encode(init, input, wire_path, c, &report) catch |err| blk: {
        report.@"error" = @errorName(err);
        break :blk null;
    };
    defer if (wire) |bytes| init.gpa.free(bytes);
    const wire_sha: ?[64]u8 = if (wire) |bytes| digest(bytes) else null;
    const after_sha = digest(input);
    if (!std.mem.eql(u8, &input_sha, &after_sha)) return error.BorrowedInputChanged;
    if (wire) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = wire_path, .data = bytes });
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.br.large-history-probe.v1",
        .config = c,
        .@"error" = report.@"error",
        .input_bytes = input.len,
        .input_sha256 = input_sha[0..],
        .wire_bytes = if (wire) |bytes| bytes.len else 0,
        .wire_sha256 = if (wire_sha) |*hash| hash[0..] else null,
        .encoded_bound = report.encoded_bound,
        .self_decode_verified = wire != null,
        .borrowed_input_verified = true,
        .summary = report.summary,
        .far_copy_count_lower_bound = if (report.summary) |summary| @intFromBool(summary.max_lz77_distance >= 65536) else 0,
        .far_copy_count_exact = @as(?usize, null),
        .progress = report.progress,
        .reset_progress = report.reset_progress,
        .checkpoints = report.checkpoints.items,
        .maximum_observed_history_len = report.maximum_observed_history_len,
        .maximum_observed_history_capacity = report.maximum_observed_history_capacity,
        .maximum_observed_retained_capacity = report.maximum_observed_retained_capacity,
        .new_stream_matches_fresh_wire = report.new_stream_matches_fresh_wire,
        .reset_wire_bytes = report.reset_wire_bytes,
        .reset_wire_sha256 = if (report.reset_wire_sha256) |*hash| hash[0..] else null,
        .reset_input_sha256 = if (report.reset_input_sha256) |*hash| hash[0..] else null,
        .reset_summary = report.reset_summary,
        .memory_profile = report.memory_profile,
        .diagnostic_scope = "codec history len/cap/tail are internal QA diagnostics; public progress/summaries and independent decoder prove behavior",
        .target = @tagName(builtin.cpu.arch),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
    }, .{});
    defer init.gpa.free(json);
    try std.Io.File.stdout().writeStreamingAll(init.io, json);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

fn options(c: Config, profile: ?*br.EncodeMemoryProfile) br.PlannedStreamChunksOptions {
    return .{ .level = c.level, .quality = c.quality, .window_bits = c.window_bits, .large_window = c.large_window, .block_len = c.block_len, .adaptive_blocks = false, .memory_profile = profile, .max_total_working_memory = c.max_total_working_memory };
}
fn oneShotOptions(c: Config, profile: ?*br.EncodeMemoryProfile) br.PlannedEncodeOptions {
    return .{ .level = c.level, .quality = c.quality, .window_bits = c.window_bits, .large_window = c.large_window, .memory_profile = profile, .max_total_working_memory = c.max_total_working_memory };
}
fn split(allocator: std.mem.Allocator, input: []const u8, size: usize) !std.ArrayList([]const u8) {
    var chunks: std.ArrayList([]const u8) = .empty;
    errdefer chunks.deinit(allocator);
    try chunks.append(allocator, "");
    var offset: usize = 0;
    while (offset < input.len) {
        const end = offset + @min(input.len - offset, size);
        try chunks.append(allocator, input[offset..end]);
        offset = end;
    }
    try chunks.append(allocator, "");
    return chunks;
}
fn inspect(allocator: std.mem.Allocator, wire: []const u8, input: []const u8, c: Config) !br.StreamSummary {
    const decode: br.DecodeOptions = .{ .allow_large_window = c.large_window };
    const decoded = try br.decodeStreamAllocLimitedWithOptions(allocator, wire, input.len, decode);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, decoded, input)) return error.RoundTripMismatch;
    return br.summarizeStreamAllocLimitedWithOptions(allocator, wire, input.len, decode);
}
fn encode(init: std.process.Init, input: []const u8, wire_path: []const u8, c: Config, r: *Report) ![]u8 {
    if (c.api == .one_shot) {
        if (c.exercise_new_stream or c.block_len != 0) return error.InvalidOneShotConfig;
        r.encoded_bound = try br.encodedPlannedStreamBoundWithOptions(input.len, oneShotOptions(c, null));
        const wire = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, oneShotOptions(c, &r.memory_profile));
        errdefer init.gpa.free(wire);
        r.summary = try inspect(init.gpa, wire, input, c);
        if (wire.len > r.encoded_bound.?) return error.EncodedBoundExceeded;
        return wire;
    }
    var chunks = try split(init.gpa, input, c.input_chunk);
    defer chunks.deinit(init.gpa);
    r.encoded_bound = try std.math.add(usize, try br.encodedPlannedStreamChunksBoundWithOptions(chunks.items, options(c, null)), 128);
    const suffix = input[input.len - @min(input.len, 258) ..];
    var reset_chunks = try split(init.gpa, suffix, c.input_chunk);
    defer reset_chunks.deinit(init.gpa);
    var reset_config = c;
    reset_config.event = .none;
    reset_config.prefix_len = 0;
    const wire = if (c.api == .chunks)
        try br.encodePlannedStreamChunksWithOptionsAlloc(init.gpa, chunks.items, options(c, &r.memory_profile))
    else if (c.api == .reusable) blk: {
        var encoder = br.PlannedStreamEncoder.init(init.gpa);
        defer encoder.deinit();
        const first = try encoder.encodeChunksWithOptionsAlloc(init.gpa, chunks.items, options(c, &r.memory_profile));
        errdefer init.gpa.free(first);
        try checkpoint(init.gpa, r, "reusable_first_complete", &encoder.stream_state, input, input.len, 0, first.len, encoder.retainedCapacity());
        if (c.exercise_new_stream) {
            const second = try encoder.encodeChunksWithOptionsAlloc(init.gpa, reset_chunks.items, options(reset_config, &r.memory_profile));
            defer init.gpa.free(second);
            try checkpoint(init.gpa, r, "reusable_independent_frame_complete", &encoder.stream_state, suffix, suffix.len, 0, second.len, encoder.retainedCapacity());
            try verifyReset(init, wire_path, suffix, second, reset_chunks.items, reset_config, r);
        }
        break :blk first;
    } else blk: {
        var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .stream = options(c, &r.memory_profile), .block_len = c.block_len, .max_input_len = input.len + suffix.len });
        defer encoder.deinit();
        const first = try pump(init.gpa, input, c, &encoder, &r.progress, r, "first");
        errdefer init.gpa.free(first);
        if (c.exercise_new_stream) {
            try encoder.nextStream(.{ .stream = options(reset_config, &r.memory_profile), .block_len = c.block_len, .max_input_len = input.len + suffix.len });
            const snapshot = encoder.snapshot();
            try checkpoint(init.gpa, r, "next_stream_initial", &encoder.codec_state, suffix, @intCast(snapshot.stream_input), snapshot.buffered_input, @intCast(snapshot.stream_output), encoder.retainedCapacity());
            if (encoder.codec_state.history.items.len != 0) return error.NewStreamKeptOldHistory;
            const second = try pump(init.gpa, suffix, reset_config, &encoder, &r.reset_progress, r, "reset");
            defer init.gpa.free(second);
            try verifyReset(init, wire_path, suffix, second, reset_chunks.items, reset_config, r);
        }
        break :blk first;
    };
    errdefer init.gpa.free(wire);
    r.summary = try inspect(init.gpa, wire, input, c);
    if (wire.len > r.encoded_bound.?) return error.EncodedBoundExceeded;
    return wire;
}
fn verifyReset(init: std.process.Init, path: []const u8, suffix: []const u8, second: []const u8, chunks: []const []const u8, c: Config, r: *Report) !void {
    const fresh = try br.encodePlannedStreamChunksWithOptionsAlloc(init.gpa, chunks, options(c, null));
    defer init.gpa.free(fresh);
    if (!std.mem.eql(u8, fresh, second)) return error.NewStreamWireDiffersFromFresh;
    r.new_stream_matches_fresh_wire = true;
    r.reset_wire_bytes = second.len;
    r.reset_wire_sha256 = digest(second);
    r.reset_input_sha256 = digest(suffix);
    r.reset_summary = try inspect(init.gpa, second, suffix, c);
    const reset_path = try std.fmt.allocPrint(init.gpa, "{s}.reset.br", .{path});
    defer init.gpa.free(reset_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = reset_path, .data = second });
}
fn checkpoint(allocator: std.mem.Allocator, r: *Report, stage: []const u8, state: anytype, input: []const u8, accepted: usize, buffered: usize, written: usize, retained: usize) !void {
    const committed = accepted - buffered;
    const history = state.history.items;
    const valid = history.len <= committed and std.mem.eql(u8, history, input[committed - @min(committed, history.len) .. committed]);
    const hash = digest(history);
    const hash_text = try allocator.dupe(u8, &hash);
    errdefer allocator.free(hash_text);
    try r.checkpoints.append(allocator, .{ .stage = stage, .accepted_input = accepted, .buffered_input = buffered, .committed_input = committed, .history_len = history.len, .history_capacity = state.history.capacity, .history_source_start = committed - @min(committed, history.len), .history_matches_committed_tail = valid, .history_sha256 = hash_text, .retained_capacity = retained, .stream_input = accepted, .stream_output = written });
    r.maximum_observed_history_len = @max(r.maximum_observed_history_len, history.len);
    r.maximum_observed_history_capacity = @max(r.maximum_observed_history_capacity, state.history.capacity);
    r.maximum_observed_retained_capacity = @max(r.maximum_observed_retained_capacity, retained);
    if (!valid) return error.DiagnosticHistoryTailMismatch;
}
fn pump(allocator: std.mem.Allocator, input: []const u8, c: Config, encoder: anytype, p: *Progress, r: *Report, stage: []const u8) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    var offset: usize = 0;
    var prefix_recorded = c.prefix_len == 0;
    var event_done = c.event == .none;
    var event_pending = false;
    var finishing = false;
    var buffer: [65552]u8 = undefined;
    const output_sizes = [_]usize{ 0, 1, 0, 31, 4096, 65536 };
    while (p.steps < input.len * 16 + 8192) : (p.steps += 1) {
        if (!event_done and !event_pending and offset == c.prefix_len) {
            if (c.event == .metadata) try encoder.writeMetadata("LargeWindow history metadata") else encoder.flush();
            event_pending = true;
        }
        if (offset == input.len and !finishing and !event_pending) {
            try encoder.finish();
            finishing = true;
        }
        var end = offset + @min(input.len - offset, if (p.steps % 3 == 0) @as(usize, 0) else c.input_chunk);
        if (!prefix_recorded or !event_done) end = @min(end, c.prefix_len);
        const offered = if (event_pending or finishing) input[offset..offset] else input[offset..end];
        const capacity = output_sizes[p.steps % output_sizes.len];
        @memset(&buffer, 0xa5);
        if (offered.len == 0) p.zero_input_offers += 1;
        if (capacity == 0) p.zero_output_offers += 1;
        const result = try encoder.step(offered, buffer[8..][0..capacity]);
        const read_count = result.progress.input_read;
        const write_count = result.progress.output_written;
        if (read_count > offered.len or write_count > capacity) return error.InvalidProgress;
        for (buffer[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
        for (buffer[8 + write_count ..]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
        offset += read_count;
        p.input_read += read_count;
        p.output_written += write_count;
        try output.appendSlice(allocator, buffer[8..][0..write_count]);
        r.maximum_observed_history_len = @max(r.maximum_observed_history_len, encoder.codec_state.history.items.len);
        r.maximum_observed_history_capacity = @max(r.maximum_observed_history_capacity, encoder.codec_state.history.capacity);
        r.maximum_observed_retained_capacity = @max(r.maximum_observed_retained_capacity, encoder.retainedCapacity());
        const snapshot = encoder.snapshot();
        if (!prefix_recorded and offset == c.prefix_len) {
            try checkpoint(allocator, r, "prefix_admitted", &encoder.codec_state, input, offset, snapshot.buffered_input, output.items.len, encoder.retainedCapacity());
            prefix_recorded = true;
        }
        switch (result.status) {
            .need_output => p.need_output += 1,
            .need_input => {
                p.need_input += 1;
                if (event_pending) {
                    try checkpoint(allocator, r, "event_acknowledged", &encoder.codec_state, input, offset, snapshot.buffered_input, output.items.len, encoder.retainedCapacity());
                    event_pending = false;
                    event_done = true;
                    p.event_acknowledged = true;
                }
            },
            .done => {
                if (offset != input.len or snapshot.stream_input != input.len or snapshot.stream_output != output.items.len or snapshot.metadata_pending) return error.FinalProgressMismatch;
                try checkpoint(allocator, r, stage, &encoder.codec_state, input, offset, snapshot.buffered_input, output.items.len, encoder.retainedCapacity());
                p.steps += 1;
                return output.toOwnedSlice(allocator);
            },
        }
    }
    return error.IncrementalDidNotFinish;
}
fn digest(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1024 * 1024));
}
