//! Explicit large-history campaign. This source is intentionally kept out of
//! default codec test roots; the dedicated runner must use ReleaseFast.
const std = @import("std");
const vort = @import("vort");
const br = vort.br;
const Encoder = br.IncrementalPlannedStreamEncoder;
const mib: usize = 1024 * 1024;
const far_prefix_len = 17 * mib + 57;
const repeated_len: usize = 2048;
const template_len: usize = 64 * mib / 1024;
const workspace_limit: usize = 8 * 1024 * mib;
const total_limit: usize = 10 * 1024 * mib;
const window_bits: u5 = 30;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const prefix_len = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else far_prefix_len;
    const output_directory = args.next() orelse "/tmp/vort-br-large-window-far-stage";
    if (args.next() != null) return error.UnexpectedArgument;
    try campaign(init.gpa, init.io, prefix_len, output_directory);
}

test "Brotli large window far public history emits a copy beyond the standard window" {
    try campaign(std.testing.allocator, std.testing.io, far_prefix_len, "/tmp/vort-br-large-window-far-stage");
}

fn campaign(a: std.mem.Allocator, io: std.Io, prefix_len: usize, output_directory: []const u8) !void {
    if (prefix_len < 2 * repeated_len or prefix_len > far_prefix_len) return error.InvalidFixtureLength;
    const input = try a.alloc(u8, prefix_len + repeated_len);
    defer a.free(input);
    const generation_begin = std.Io.Clock.awake.now(io);
    const rejected = generate(input[0..prefix_len]);
    @memcpy(input[prefix_len..], input[0..repeated_len]);
    const generation_ns = elapsed(io, generation_begin);
    const block_len: usize = @min(prefix_len, 16 * mib);
    const Command = @typeInfo(@TypeOf(@as(Encoder, undefined).codec_state.commands.items)).pointer.child;
    const command_bytes = @sizeOf(Command);
    const plan_commands_estimate = try std.math.mul(usize, block_len + 1, command_bytes);
    const literal_prices_estimate = try std.math.mul(usize, block_len + 1, @sizeOf(u64));
    var profile: br.HqProfile = .{};
    var memory: br.EncodeMemoryProfile = .{};
    var encoder = Encoder.initWithOptions(a, .{ .stream = .{
        .quality = 10,
        .window_bits = window_bits,
        .large_window = true,
        .hq = .{
            .search_depth = 1,
            .nice_len = 128,
            .beam_width = 1,
            .iterations = 1,
            .block_len = block_len,
            .max_working_memory = workspace_limit,
            .profile = &profile,
        },
        .max_total_working_memory = total_limit,
        .memory_profile = &memory,
    } });
    var encoder_alive = true;
    defer if (encoder_alive) encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var output: [64 * 1024]u8 = undefined;
    std.debug.print("far-start prefix={d} repeat={d} window={d} command_size={d} plan_capacity_bytes={d} literal_prices_bytes={d}\n", .{ prefix_len, repeated_len, window_bits, command_bytes, plan_commands_estimate, literal_prices_estimate });
    const encode_begin = std.Io.Clock.awake.now(io);
    try feed(a, &encoder, &wire, input[0..prefix_len], &output);
    encoder.flush();
    try drain(a, &encoder, &wire, &output, .need_input);
    const prefix_encode_ns = elapsed(io, encode_begin);
    const checkpoint = encoder.snapshot();
    const prefix_emitted = profile.emitted();
    const prefix_wire_len = wire.items.len;
    const prefix_frame_offset = encoder.codec_state.hq_state.frame_offset;
    const prefix_history_len = encoder.codec_state.history.items.len;
    const prefix_seed_positions = profile.history_seed_positions;
    const prefix_stitch_positions = profile.stitch_positions;
    try require(checkpoint.input_read == prefix_len and checkpoint.output_written == prefix_wire_len);
    try require(checkpoint.buffered_input == 0 and checkpoint.pending_output == 0);
    try require(prefix_frame_offset == prefix_len and prefix_history_len == prefix_len);
    try require(prefix_emitted.emitted_metablocks == (prefix_len + block_len - 1) / block_len);
    try require(!encoder.codec_state.hq_state.matcher.?.bound);
    std.debug.print("far-prefix-committed ns={d} wire={d} meta={d} history={d} offset={d} indexed={d} seed={d} stitch={d} totalpeak={d}\n", .{ prefix_encode_ns, prefix_wire_len, prefix_emitted.emitted_metablocks, prefix_history_len, prefix_frame_offset, profile.indexed_positions, prefix_seed_positions, prefix_stitch_positions, memory.peak_requested_bytes });
    const suffix_begin = std.Io.Clock.awake.now(io);
    try feed(a, &encoder, &wire, input[prefix_len..], &output);
    try encoder.finish();
    try drain(a, &encoder, &wire, &output, .done);
    const suffix_encode_ns = elapsed(io, suffix_begin);
    const window_len = (@as(usize, 1) << window_bits) - 16;
    try require(profile.emitted_max_distance == prefix_len);
    try require(profile.emitted_copy_bytes >= repeated_len);
    if (prefix_len == far_prefix_len) try require(profile.emitted_max_distance > (1 << 24) - 16);
    try require(encoder.codec_state.hq_state.frame_offset == input.len);
    try require(encoder.codec_state.history.items.len == input.len and encoder.codec_state.history.items.len <= window_len);
    try require(profile.history_seed_positions == prefix_seed_positions);
    try require(profile.stitch_positions > prefix_stitch_positions);
    try require(profile.effective.?.format == .large_window);
    try require(profile.peak_working_memory <= workspace_limit and memory.peak_requested_bytes <= total_limit);
    try require(wire.items.len >= 2 and wire.items[0] == 0x11 and (wire.items[1] & 63) == window_bits);
    const final_profile = profile;
    const final_history_len = encoder.codec_state.history.items.len;
    const final_frame_offset = encoder.codec_state.hq_state.frame_offset;
    const live_before_deinit = memory.live_requested_bytes;
    encoder.deinit();
    encoder_alive = false;
    try require(memory.live_requested_bytes == 0);

    const decode_begin = std.Io.Clock.awake.now(io);
    const decoded = try br.decodeStreamAllocExactSizeWithOptions(a, wire.items, input.len, .{ .allow_large_window = true });
    defer a.free(decoded);
    try require(std.mem.eql(u8, input, decoded));
    const decode_ns = elapsed(io, decode_begin);
    const summary = try br.summarizeStreamAllocLimitedWithOptions(a, wire.items, input.len, .{ .allow_large_window = true });
    try require(summary.large_window and summary.window_bits == window_bits);
    try require(summary.max_lz77_distance == prefix_len and summary.decoded_bytes == input.len);
    try require(summary.compressed_meta_block_count >= 1);
    const input_path = try std.fmt.allocPrint(a, "{s}/input.bin", .{output_directory});
    defer a.free(input_path);
    const wire_path = try std.fmt.allocPrint(a, "{s}/wire.br", .{output_directory});
    defer a.free(wire_path);
    const report_path = try std.fmt.allocPrint(a, "{s}/artifact.json", .{output_directory});
    defer a.free(report_path);
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = input_path, .data = input });
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = wire_path, .data = wire.items });
    const input_hash = hash(input);
    const wire_hash = hash(wire.items);
    const report = try std.json.Stringify.valueAlloc(a, .{
        .status = "passed",
        .api = "IncrementalPlannedStreamEncoder",
        .build_mode = @tagName(@import("builtin").mode),
        .quality = 10,
        .window_bits = window_bits,
        .large_window = true,
        .raw_dictionary = false,
        .prefix_bytes = prefix_len,
        .repeat_bytes = repeated_len,
        .input_bytes = input.len,
        .wire_bytes = wire.items.len,
        .input_path = input_path,
        .wire_path = wire_path,
        .input_sha256 = &input_hash,
        .wire_sha256 = &wire_hash,
        .emitted_max_distance = profile.emitted_max_distance,
        .summary_max_distance = summary.max_lz77_distance,
        .standard_max_distance = (1 << 24) - 16,
        .is_actual_far_case = prefix_len == far_prefix_len,
        .generator = "unique-anchor-xorshift64-template-repeat-reject-main-hash-bucket",
        .template_bytes = template_len,
        .generator_seed = @as(u64, 0x8e7c_9a51_38d4_620b),
        .anchor_bucket_rejections = rejected,
        .search_depth = 1,
        .beam_width = 1,
        .iterations = 1,
        .block_len = block_len,
        .command_struct_bytes = command_bytes,
        .plan_commands_bytes_estimate = plan_commands_estimate,
        .literal_prices_bytes_estimate = literal_prices_estimate,
        .prefix_wire_bytes_already_delivered = prefix_wire_len,
        .prefix_emitted = prefix_emitted,
        .prefix_frame_offset = prefix_frame_offset,
        .prefix_history_len = prefix_history_len,
        .final_frame_offset = final_frame_offset,
        .final_history_len = final_history_len,
        .profile = final_profile,
        .memory_profile = memory,
        .total_live_before_encoder_deinit = live_before_deinit,
        .total_live_after_encoder_deinit = memory.live_requested_bytes,
        .summary = summary,
        .generation_ns = generation_ns,
        .prefix_encode_ns = prefix_encode_ns,
        .suffix_encode_ns = suffix_encode_ns,
        .decode_ns = decode_ns,
    }, .{ .whitespace = .indent_2 });
    defer a.free(report);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = report_path, .data = report });
    std.debug.print("far-passed artifact={s} distance={d} prefix_ns={d} suffix_ns={d} decode_ns={d} totalpeak={d}\n", .{ report_path, profile.emitted_max_distance, prefix_encode_ns, suffix_encode_ns, decode_ns, memory.peak_requested_bytes });
}

/// The first 2048 bytes are unique. The following 64 KiB high-entropy template
/// repeats so ordinary copies can skip expensive per-byte parsing. Rejecting
/// one main hash bucket, including period boundaries, keeps the genuine first
/// anchor discoverable at depth one. The producer still accepts every byte.
fn generate(bytes: []u8) usize {
    @memcpy(bytes[0..4], &[_]u8{ 1, 2, 3, 4 });
    const anchor = bucket(bytes[0..4]);
    var random: u64 = 0x8e7c_9a51_38d4_620b;
    var rejected: usize = 0;
    const seed_end = @min(bytes.len, repeated_len + template_len);
    for (4..seed_end) |position| {
        while (true) {
            random ^= random << 13;
            random ^= random >> 7;
            random ^= random << 17;
            bytes[position] = @truncate(random >> 24);
            if (bucket(bytes[position - 3 ..][0..4]) != anchor) break;
            rejected += 1;
        }
    }
    if (bytes.len > seed_end) {
        // The wrap has three new four-byte windows. Adjust only the template's
        // last byte, rechecking all windows affected by that byte.
        const last = seed_end - 1;
        while (true) {
            var valid = bucket(bytes[last - 3 ..][0..4]) != anchor;
            var boundary: [7]u8 = undefined;
            @memcpy(boundary[0..4], bytes[last - 3 .. last + 1]);
            @memcpy(boundary[4..], bytes[repeated_len..][0..3]);
            for (1..4) |start| valid = valid and bucket(boundary[start..][0..4]) != anchor;
            if (valid) break;
            random ^= random << 13;
            random ^= random >> 7;
            random ^= random << 17;
            bytes[last] = @truncate(random >> 24);
            rejected += 1;
        }
        for (seed_end..bytes.len) |position|
            bytes[position] = bytes[repeated_len + (position - repeated_len) % template_len];
    }
    return rejected;
}

fn bucket(bytes: []const u8) u16 {
    const word = std.mem.readInt(u32, bytes[0..4], .little);
    return @truncate((word *% @as(u32, 2654435761)) >> 16);
}

fn feed(a: std.mem.Allocator, encoder: *Encoder, wire: *std.ArrayList(u8), input: []const u8, output: []u8) !void {
    var offset: usize = 0;
    while (offset != input.len) {
        const result = try encoder.step(input[offset..], output);
        offset += result.progress.input_read;
        try wire.appendSlice(a, output[0..result.progress.output_written]);
        try require(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
}

fn drain(a: std.mem.Allocator, encoder: *Encoder, wire: *std.ArrayList(u8), output: []u8, status: vort.core.StepResult.Status) !void {
    while (true) {
        const result = try encoder.step("", output);
        try wire.appendSlice(a, output[0..result.progress.output_written]);
        if (result.status == status) return;
        try require(result.status == .need_output and result.progress.output_written != 0);
    }
}

fn require(condition: bool) !void {
    if (!condition) return error.FarHistoryContractFailed;
}

fn elapsed(io: std.Io, begin: std.Io.Timestamp) u64 {
    const ns = begin.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn hash(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}
