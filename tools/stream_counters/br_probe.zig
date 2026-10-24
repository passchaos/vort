const std = @import("std");
const vort = @import("vort");
const br = vort.br;
const common = @import("common.zig");
const Config = struct {
    operation: enum { metadata, stored, stored_copy, encode },
    count: u64,
    block_len: usize = 1 << 24,
    result_path: ?[]const u8 = null,
    tail_wire_path: ?[]const u8 = null,
    tail_plain_path: ?[]const u8 = null,
    tail_proof_path: ?[]const u8 = null,
    wire_stdout: bool = false,
    max_working_memory: usize = 8 * 1024 * 1024,
};
const Receipt = struct {
    consumer: []const u8,
    progress: common.Progress,
    metadata_total: u64,
    metadata_blocks: u64,
    metadata_captured: usize,
    metadata_truncated: bool,
    captured_lengths: [2]usize,
    compressed_header_capacity: usize,
    history_bytes: usize,
    last_copy_distance: ?usize,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingConfig;
    const json = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536));
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var ledger: common.Ledger = .{ .backing = init.gpa };
    if (config.operation == .encode) {
        const report = try encode(init, config, &ledger);
        try publish(init, config, .{ .operation = config.operation, .count = config.count, .progress = report, .allocation_peak = ledger.peak, .allocation_live_after_deinit = ledger.live, .build_mode = @tagName(@import("builtin").mode), .pointer_bits = @bitSizeOf(usize) });
        return;
    }
    var tail_plain: [2048]u8 = undefined;
    var tail_wire: []u8 = &.{};
    if (config.operation == .stored_copy) {
        if (config.count < tail_plain.len) return error.InvalidFixture;
        common.fill(&tail_plain, config.count - tail_plain.len);
        tail_wire = try makeCopyTail(init, &tail_plain, config.tail_proof_path);
        if (config.tail_wire_path) |file| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = file, .data = tail_wire });
        if (config.tail_plain_path) |file| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = file, .data = &tail_plain });
    }
    defer if (tail_wire.len != 0) init.gpa.free(tail_wire);
    var receipts: [3]Receipt = undefined;
    const policies: usize = if (config.operation == .stored_copy) 2 else 3;
    for (0..policies) |index| receipts[index] = try decode(init, config, index, &ledger, tail_wire, &tail_plain);
    if (ledger.live != 0) return error.LiveAllocationAfterDeinit;
    try publish(init, config, .{ .operation = config.operation, .count = config.count, .consumers = receipts[0..policies], .tail_wire_bytes = tail_wire.len, .tail_normal_distance = if (tail_wire.len != 0) @as(?usize, 2048) else null, .allocation_peak = ledger.peak, .allocation_live_after_deinit = ledger.live, .caller_history_bytes = 65535, .source_buffer_bytes = common.chunk_len, .output_buffer_bytes = common.chunk_len, .build_mode = @tagName(@import("builtin").mode), .pointer_bits = @bitSizeOf(usize) });
}

fn makeCopyTail(init: std.process.Init, prefix: []const u8, proof_path: ?[]const u8) ![]u8 {
    const dictionaries = [_][]const u8{prefix};
    const options: br.PlannedEncodeOptions = .{ .quality = 5, .window_bits = 16, .shared_dictionary = .{ .raw_prefixes = &dictionaries } };
    const frame = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, prefix, options);
    defer init.gpa.free(frame);
    if (frame.len < 2 or frame[0] & 1 != 0) return error.UnexpectedCopyTailHeader;
    const summary = try br.summarizeStreamAllocWithOptions(init.gpa, frame, .{ .shared_dictionary = options.shared_dictionary });
    if (summary.shared_dictionary_copy_count == 0 or summary.decoded_bytes != prefix.len) return error.CopyTailDidNotReferencePrefix;
    // Strip exactly the independently read one-bit RFC window16 prefix. No
    // meta-block fields are invented; normal history supplies the same bytes.
    const stripped = try init.gpa.alloc(u8, frame.len);
    errdefer init.gpa.free(stripped);
    for (stripped, 0..) |*byte, index| byte.* = (frame[index] >> 1) | (if (index + 1 < frame.len) frame[index + 1] << 7 else @as(u8, 0));
    var proof: std.ArrayList(u8) = .empty;
    defer proof.deinit(init.gpa);
    var source = try common.Source.init(.br_stored, prefix.len, prefix.len);
    try proof.appendSlice(init.gpa, try source.next());
    try proof.appendSlice(init.gpa, prefix);
    try proof.appendSlice(init.gpa, stripped);
    const normal = try br.summarizeStreamAlloc(init.gpa, proof.items);
    if (normal.max_lz77_distance != 2048 or normal.lz77_copy_bytes != 2048 or normal.uses_shared_dictionary or normal.decoded_bytes != prefix.len * 2)
        return error.CopyTailDidNotUseNormalHistory2048;
    const restored = try br.decodeStreamAlloc(init.gpa, proof.items);
    defer init.gpa.free(restored);
    if (!std.mem.eql(u8, restored[0..prefix.len], prefix) or !std.mem.eql(u8, restored[prefix.len..], prefix)) return error.CopyTailProofContent;
    if (proof_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = proof.items });
    return stripped;
}
fn decode(init: std.process.Init, config: Config, policy: usize, ledger: *common.Ledger, suffix: []const u8, tail_plain: []const u8) !Receipt {
    var captured: [19]u8 = @splat(0);
    var lengths: [2]usize = @splat(0);
    if (policy == 0) {
        const history = try init.gpa.alloc(u8, 65535);
        defer init.gpa.free(history);
        var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(history, .{ .max_output_len = config.count + if (suffix.len != 0) @as(u64, 2048) else 0, .max_total_output_len = config.count + if (suffix.len != 0) @as(u64, 2048) else 0, .metadata_output = &captured, .metadata_block_lengths = &lengths });
        const progress = try drive(config, &decoder, suffix, tail_plain);
        const snapshot = decoder.snapshot();
        if (config.operation == .stored_copy and snapshot.copy_distance != 2048) return error.UnexpectedTailDistance;
        try checkMetadata(config, snapshot.metadata_total, snapshot.metadata_block_count, snapshot.metadata_written, snapshot.metadata_truncated, lengths, captured);
        return .{ .consumer = "copy_caller_history", .progress = progress, .metadata_total = snapshot.metadata_total, .metadata_blocks = snapshot.metadata_block_count, .metadata_captured = snapshot.metadata_written, .metadata_truncated = snapshot.metadata_truncated, .captured_lengths = lengths, .compressed_header_capacity = snapshot.compressed_header_capacity, .history_bytes = history.len, .last_copy_distance = snapshot.copy_distance };
    }
    if (policy == 1) {
        var decoder = br.IncrementalStreamDecoder.initWithOptions(ledger.allocator(), .{ .max_output_len = config.count + if (suffix.len != 0) @as(u64, 2048) else 0, .max_total_output_len = config.count + if (suffix.len != 0) @as(u64, 2048) else 0, .max_working_memory = config.max_working_memory, .max_history_len = 65535, .metadata_output = &captured, .metadata_block_lengths = &lengths });
        defer decoder.deinit();
        const progress = try drive(config, &decoder, suffix, tail_plain);
        const snapshot = decoder.snapshot();
        const metadata = decoder.progressive.?.snapshot();
        if (config.operation == .stored_copy and metadata.copy_distance != 2048) return error.UnexpectedTailDistance;
        try checkMetadata(config, metadata.metadata_total, metadata.metadata_block_count, metadata.metadata_written, metadata.metadata_truncated, lengths, captured);
        return .{ .consumer = "owned_general", .progress = progress, .metadata_total = metadata.metadata_total, .metadata_blocks = metadata.metadata_block_count, .metadata_captured = metadata.metadata_written, .metadata_truncated = metadata.metadata_truncated, .captured_lengths = lengths, .compressed_header_capacity = snapshot.compressed_header_capacity, .history_bytes = snapshot.history_bytes, .last_copy_distance = metadata.copy_distance };
    }
    var decoder = br.IncrementalStoredStreamDecoder.initWithOptions(.{ .max_output_len = config.count, .metadata_output = &captured, .metadata_block_lengths = &lengths });
    const progress = try drive(config, &decoder, suffix, tail_plain);
    const snapshot = decoder.snapshot();
    try checkMetadata(config, snapshot.metadata_total, snapshot.metadata_block_count, snapshot.metadata_written, snapshot.metadata_truncated, lengths, captured);
    return .{ .consumer = "stored_subset", .progress = progress, .metadata_total = snapshot.metadata_total, .metadata_blocks = snapshot.metadata_block_count, .metadata_captured = snapshot.metadata_written, .metadata_truncated = snapshot.metadata_truncated, .captured_lengths = lengths, .compressed_header_capacity = 0, .history_bytes = 0, .last_copy_distance = null };
}
fn checkMetadata(config: Config, total: u64, blocks: u64, captured: usize, truncated: bool, lengths: [2]usize, bytes: [19]u8) !void {
    if (config.operation != .metadata) return;
    const expected_blocks = config.count / config.block_len + @intFromBool(config.count % config.block_len != 0);
    if (total != config.count or blocks != expected_blocks or captured != @min(config.count, bytes.len) or truncated != (config.count > bytes.len)) return error.MetadataAccountingMismatch;
    if (expected_blocks >= 2 and (lengths[0] != config.block_len or lengths[1] != config.block_len)) return error.MetadataLengthsMismatch;
    try common.verify(bytes[0..captured], 0, false);
}
fn drive(config: Config, decoder: anytype, suffix: []const u8, tail_plain: []const u8) !common.Progress {
    var source = try common.Source.init(if (config.operation == .metadata) .br_metadata else .br_stored, config.count, config.block_len);
    if (suffix.len != 0) source.suffix = suffix;
    var buffer: [common.chunk_len]u8 = undefined;
    var progress: common.Progress = .{};
    while (true) {
        const input = try source.next();
        if (source.ended and progress.completed) break;
        const result = try decoder.step(input, &buffer);
        const written = result.progress.output_written;
        if (progress.output_written < config.count or suffix.len == 0) {
            const body = @min(@as(u64, written), config.count - progress.output_written);
            try common.verify(buffer[0..@intCast(body)], progress.output_written, false);
            if (body < written and !std.mem.eql(u8, buffer[@intCast(body)..written], tail_plain[0 .. written - @as(usize, @intCast(body))])) return error.CopyTailContentMismatch;
        } else {
            const at: usize = @intCast(progress.output_written - config.count);
            if (!std.mem.eql(u8, buffer[0..written], tail_plain[at .. at + written])) return error.CopyTailContentMismatch;
        }
        source.consume(result.progress.input_read);
        progress.input_read += result.progress.input_read;
        progress.output_written += written;
        progress.steps += 1;
        progress.completed = result.status == .done;
        if (input.len != 0 and result.progress.input_read == 0 and written == 0 and !progress.completed) return error.NoProgress;
        if (source.ended and !progress.completed and written == 0) return error.TruncatedGeneratedStream;
    }
    try decoder.finish();
    const expected = if (config.operation == .metadata) 0 else config.count + if (suffix.len != 0) @as(u64, 2048) else 0;
    if (progress.output_written != expected or progress.input_read != source.emitted_input) return error.WrongProgress;
    return progress;
}
fn encode(init: std.process.Init, config: Config, ledger: *common.Ledger) !common.Progress {
    var encoder = br.IncrementalStoredStreamEncoder.initWithOptions(ledger.allocator(), .{ .stream = .{ .window_bits = 16 }, .block_len = 65536, .max_input_len = config.count });
    var active = true;
    defer if (active) encoder.deinit();
    var decoder = br.IncrementalStoredStreamDecoder.initWithOptions(.{ .max_output_len = config.count });
    var input: [common.chunk_len]u8 = undefined;
    var output: [common.chunk_len]u8 = undefined;
    var decoded: [common.chunk_len]u8 = undefined;
    var progress: common.Progress = .{};
    var decoder_progress: common.Progress = .{};
    var finished = false;
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    while (!progress.completed) {
        if (progress.input_read == config.count and !finished) {
            try encoder.finish();
            finished = true;
        }
        const take: usize = @intCast(@min(config.count - progress.input_read, input.len));
        common.fill(input[0..take], progress.input_read);
        const result = try encoder.step(input[0..take], &output);
        progress.input_read += result.progress.input_read;
        progress.output_written += result.progress.output_written;
        progress.steps += 1;
        progress.completed = result.status == .done;
        const bytes = output[0..result.progress.output_written];
        var offset: usize = 0;
        while (offset < bytes.len) offset += try common.consumeDecoder(&decoder, bytes[offset..], &decoded, &decoder_progress, false);
        if (config.wire_stdout) try stdout.interface.writeAll(bytes);
    }
    if (config.wire_stdout) try stdout.interface.flush();
    try decoder.finish();
    encoder.deinit();
    active = false;
    if (ledger.peak > config.max_working_memory or ledger.live != 0 or progress.input_read != config.count or decoder_progress.output_written != config.count or !decoder_progress.completed) return error.WrongProgress;
    return progress;
}
fn publish(init: std.process.Init, config: Config, value: anytype) !void {
    if (config.result_path) |path| {
        const json = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
        defer init.gpa.free(json);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = json });
    }
    if (!config.wire_stdout) try common.print(init, value);
}
