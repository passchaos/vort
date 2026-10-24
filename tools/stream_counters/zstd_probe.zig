const std = @import("std");
const vort = @import("vort");
const common = @import("common.zig");
const zstd = vort.zstd;
const Config = struct {
    operation: enum { decode_rle, decode_skip, encode },
    count: u64,
    fixture_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
    max_working_memory: usize = 8 * 1024 * 1024,
};
const Receipt = struct { policy: vort.core.CompressedInputPolicy, progress: common.Progress, snapshot: zstd.NativeIncrementalFrameDecoder.Snapshot, allocation_peak: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const config_path = args.next() orelse return error.MissingConfig;
    const json = try std.Io.Dir.cwd().readFileAlloc(init.io, config_path, init.gpa, .limited(65536));
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var ledger: common.Ledger = .{ .backing = init.gpa };
    var policies: [2]Receipt = undefined;
    var encoded: ?[]u8 = null;
    defer if (encoded) |wire| init.gpa.free(wire);
    if (config.operation == .encode) {
        const result = try encode(init, config, &ledger);
        encoded = result.wire;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = config.output_path orelse return error.MissingOutput, .data = result.wire });
        try common.print(init, .{ .operation = config.operation, .count = config.count, .progress = result.progress, .snapshot = result.snapshot, .total_memory_profile = result.memory, .content_xxh64 = result.content_xxh64, .allocation_peak = ledger.peak, .allocation_live_after_deinit = ledger.live, .wire_bytes = result.wire.len, .build_mode = @tagName(@import("builtin").mode), .pointer_bits = @bitSizeOf(usize) });
        return;
    }
    const fixture = if (config.fixture_path) |path| try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1024 * 1024)) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(fixture);
    for ([_]vort.core.CompressedInputPolicy{ .block_stream, .prevalidated_frame }, 0..) |policy, index| {
        policies[index] = try decode(init, config, policy, fixture, &ledger);
    }
    try common.print(init, .{ .operation = config.operation, .count = config.count, .policies = policies, .allocation_live_after_deinit = ledger.live, .build_mode = @tagName(@import("builtin").mode), .pointer_bits = @bitSizeOf(usize) });
}

fn decode(init: std.process.Init, config: Config, policy: vort.core.CompressedInputPolicy, fixture: []const u8, ledger: *common.Ledger) !Receipt {
    _ = init;
    var decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(ledger.allocator(), .{
        .input_policy = policy,
        .max_output_len = if (config.operation == .decode_rle) config.count else 0,
        .max_decoded_buffer_len = config.count,
        .expected_output_len = if (config.operation == .decode_rle) config.count else 0,
        .max_compressed_buffer_len = 1024 * 1024,
        .max_working_memory = config.max_working_memory,
    });
    defer decoder.deinit();
    var output: [common.chunk_len]u8 = undefined;
    var progress: common.Progress = .{};
    if (config.operation == .decode_rle) {
        var offset: usize = 0;
        while (!progress.completed) {
            const end = offset + @min(fixture.len - offset, common.chunk_len);
            offset += try common.consumeDecoder(&decoder, fixture[offset..end], &output, &progress, true);
            if (offset == fixture.len and !progress.completed and progress.output_written == config.count) {
                try decoder.finish();
                break;
            }
        }
        if (offset != fixture.len or progress.output_written != config.count) return error.WrongProgress;
    } else {
        // Exactly two frames at the long boundary: u32max plus two bytes.
        var source = try common.Source.init(.zstd_skip, config.count, std.math.maxInt(u32));
        while (true) {
            const offered = try source.next();
            if (source.ended) break;
            const consumed = try common.consumeDecoder(&decoder, offered, &output, &progress, false);
            source.consume(consumed);
            if (progress.output_written != 0) return error.SkippableEmittedOutput;
        }
        if (progress.input_read != config.count + source.blocks * 8) return error.WrongProgress;
    }
    try decoder.finish();
    const snapshot = decoder.snapshot();
    if (snapshot.input_received != progress.input_read or snapshot.output_written != progress.output_written or snapshot.phase != .done) return error.WrongProgress;
    if (config.operation == .decode_skip and snapshot.skippable_total != config.count) return error.WrongProgress;
    return .{ .policy = policy, .progress = progress, .snapshot = snapshot, .allocation_peak = ledger.peak };
}

const tail = "vort-4GiB-tail!!!";
fn encode(init: std.process.Init, config: Config, ledger: *common.Ledger) !struct { wire: []u8, progress: common.Progress, snapshot: zstd.NativeIncrementalFrameEncoder.Snapshot, memory: zstd.EncodeMemoryProfile, content_xxh64: u64 } {
    if (config.count < 17) return error.InvalidFixture;
    var memory: zstd.EncodeMemoryProfile = .{};
    var encoder = try zstd.NativeIncrementalFrameEncoder.initExactSize(ledger.allocator(), .{ .selection = .raw_or_rle, .include_content_size = true, .content_checksum = true, .window_log = 20, .block_size_max = 128 * 1024, .max_total_working_memory = config.max_working_memory, .memory_profile = &memory }, config.count);
    var active = true;
    defer if (active) encoder.deinit();
    var buffer: [common.chunk_len]u8 = @splat(0);
    var output: [common.chunk_len]u8 = undefined;
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(init.gpa);
    var progress: common.Progress = .{};
    const prefix = config.count - 17;
    var finishing = false;
    while (!progress.completed) {
        if (progress.input_read == config.count and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const offered: []const u8 = if (progress.input_read < prefix)
            buffer[0..@intCast(@min(prefix - progress.input_read, buffer.len))]
        else if (progress.input_read < config.count)
            tail[@intCast(progress.input_read - prefix)..]
        else
            &.{};
        const result = try encoder.step(offered, &output);
        progress.input_read += result.progress.input_read;
        progress.output_written += result.progress.output_written;
        progress.steps += 1;
        progress.completed = result.status == .done;
        if (wire.items.len + result.progress.output_written > 1024 * 1024) return error.WireCollectorLimit;
        try wire.appendSlice(init.gpa, output[0..result.progress.output_written]);
    }
    const snapshot = encoder.snapshot();
    const checksum = encoder.hasher.final();
    encoder.deinit();
    active = false;
    if (progress.input_read != config.count or ledger.live != 0 or memory.live_requested_bytes != 0) return error.WrongProgress;
    return .{ .wire = try wire.toOwnedSlice(init.gpa), .progress = progress, .snapshot = snapshot, .memory = memory, .content_xxh64 = checksum };
}
