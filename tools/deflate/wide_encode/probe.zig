//! Real bounded encoder streams. Binary wire goes to stdout; receipts go to
//! a separate JSON file after final-byte publication and encoder destruction.
const std = @import("std");
const codec = @import("codec");
const common = @import("common.zig");
const Crc = @FieldType(codec.GzipIncrementalDecoder, "crc");
const Adler = @FieldType(codec.ZlibIncrementalDecoder, "adler");
const Family = enum { raw_stored, raw_fixed, raw_best, zlib_fixed, zlib_best, gzip_fixed, gzip_best, png };
const Config = struct { family: Family, count: u64, pattern: common.Pattern = .repeat, report_path: []const u8 };
const Matcher = struct { initialized: bool, absolute_position: u64, indexed_positions: u64, counter_bits: usize, retained_history_bytes: usize };
const Receipt = struct {
    input_read: u64 = 0,
    output_written: u64 = 0,
    calls: u64 = 0,
    completed: bool = false,
    counter_bits: usize = 0,
    step_progress_bits: usize = 0,
    pledged_input_len: u64 = 0,
    input_crc32: u32 = 0,
    input_adler32: u32 = 0,
    peak_zero_run: u64 = 0,
    zero_run_counter_bits: ?usize = null,
    matcher: ?Matcher = null,
    heap_peak: usize = 0,
    heap_live_after_deinit: usize = 0,
    heap_allocations: u64 = 0,
    premature_pledge_refusals: usize = 0,
    excess_pledge_refusals: usize = 0,
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
    if (config.count < 2 or (config.family != .png and config.pattern != .repeat)) return error.InvalidConfig;
    const compression: codec.CompressionOptions = .{ .parser = .hash, .lz77_options = .{ .max_chain = 8, .max_candidates = 2, .nice_len = 128 } };
    const receipt = switch (config.family) {
        .raw_stored => try run(codec.RawDeflateIncrementalStoredEncoder, init, config, .{ .max_input_len = config.count, .block_len = 65535 }),
        .raw_fixed => try run(codec.RawDeflateIncrementalFixedEncoder, init, config, .{ .max_input_len = config.count, .block_len = 32768, .compression = compression }),
        .raw_best => try run(codec.RawDeflateIncrementalBestEncoder, init, config, .{ .max_input_len = config.count, .block_len = 32768, .compression = compression }),
        .zlib_fixed => try run(codec.ZlibIncrementalFixedEncoder, init, config, .{ .raw = .{ .max_input_len = config.count, .block_len = 32768, .compression = compression } }),
        .zlib_best => try run(codec.ZlibIncrementalBestEncoder, init, config, .{ .raw = .{ .max_input_len = config.count, .block_len = 32768, .compression = compression } }),
        .gzip_fixed => try run(codec.GzipIncrementalFixedEncoder, init, config, .{ .raw = .{ .max_input_len = config.count, .block_len = 32768, .compression = compression } }),
        .gzip_best => try run(codec.GzipIncrementalBestEncoder, init, config, .{ .raw = .{ .max_input_len = config.count, .block_len = 32768, .compression = compression } }),
        .png => try run(codec.ZlibIncrementalPngUltraFastEncoder, init, config, .{ .max_input_len = config.count }),
    };
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.deflate.wide-encode.v1",
        .family = config.family,
        .pattern = config.pattern,
        .count = config.count,
        .receipt = receipt,
        .input_chunk_bytes = common.chunk_len,
        .output_chunk_bytes = common.chunk_len,
        .pointer_bits = @bitSizeOf(usize),
        .build_mode = @tagName(@import("builtin").mode),
        .parser = if (config.family == .raw_stored or config.family == .png) "none" else "hash",
        .wire_transport = "stdout pipe",
    }, .{});
    defer init.gpa.free(report);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = config.report_path, .data = report });
}

fn pledge(encoder: anytype) ?u64 {
    return if (@hasField(@TypeOf(encoder.*), "raw")) encoder.raw.expected_input_len else encoder.expected_input_len;
}
fn rawEncoder(encoder: anytype) if (@hasField(@TypeOf(encoder.*), "raw")) @TypeOf(&encoder.raw) else @TypeOf(encoder) {
    return if (@hasField(@TypeOf(encoder.*), "raw")) &encoder.raw else encoder;
}

fn run(comptime Encoder: type, init: std.process.Init, config: Config, options: Encoder.Options) !Receipt {
    try checkPledges(Encoder, init.gpa, options);
    var ledger: common.Ledger = .{ .backing = init.gpa };
    var encoder = Encoder.initExactSize(ledger.allocator(), options, config.count);
    var live = true;
    defer if (live) encoder.deinit();
    if (pledge(&encoder) != config.count) return error.WrongPledge;
    var receipt: Receipt = .{ .pledged_input_len = config.count, .premature_pledge_refusals = 1, .excess_pledge_refusals = 1 };
    var input: [common.chunk_len]u8 = undefined;
    var output: [common.chunk_len]u8 = undefined;
    var stdout_buffer: [common.chunk_len]u8 = undefined;
    var sink = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    var crc = Crc.init();
    var adler = Adler.init();
    var finishing = false;
    var previous_match_position: u64 = 0;
    while (!receipt.completed) {
        if (receipt.input_read == config.count and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const len: usize = @intCast(@min(config.count - receipt.input_read, input.len));
        common.fill(input[0..len], receipt.input_read, config.count, config.pattern);
        const before = encoder.snapshot();
        const result = try encoder.step(input[0..len], &output);
        if (result.progress.input_read > len or result.progress.output_written > output.len) return error.InvalidProgress;
        crc.update(input[0..result.progress.input_read]);
        adler.update(input[0..result.progress.input_read]);
        receipt.input_read = try std.math.add(u64, receipt.input_read, @intCast(result.progress.input_read));
        receipt.output_written = try std.math.add(u64, receipt.output_written, @intCast(result.progress.output_written));
        receipt.calls += 1;
        receipt.completed = result.status == .done;
        const after = encoder.snapshot();
        receipt.counter_bits = @bitSizeOf(@TypeOf(after.input_read));
        receipt.step_progress_bits = @bitSizeOf(@TypeOf(result.progress.input_read));
        if (receipt.counter_bits != 64) return error.MissingWideEncoderCount;
        if (after.input_read != before.input_read + result.progress.input_read or after.output_written != before.output_written + result.progress.output_written) return error.SnapshotProgressMismatch;
        if (after.input_read != receipt.input_read or after.output_written != receipt.output_written or pledge(&encoder) != config.count) return error.SnapshotProgressMismatch;
        if (@hasField(@TypeOf(after), "zero_run")) {
            receipt.peak_zero_run = @max(receipt.peak_zero_run, after.zero_run);
            receipt.zero_run_counter_bits = @bitSizeOf(@TypeOf(after.zero_run));
            if (receipt.zero_run_counter_bits != 64) return error.MissingWidePngRun;
        }
        const raw = rawEncoder(&encoder);
        if (@hasDecl(@TypeOf(raw.*), "matchFinderSnapshot")) {
            const matcher = raw.matchFinderSnapshot();
            if (matcher.absolute_position < previous_match_position or matcher.absolute_position > receipt.input_read) return error.MatcherProgressMismatch;
            previous_match_position = matcher.absolute_position;
        }
        try sink.interface.writeAll(output[0..result.progress.output_written]);
        if (!receipt.completed and result.progress.input_read == 0 and result.progress.output_written == 0) return error.NoProgress;
    }
    try sink.interface.flush();
    if (receipt.input_read != config.count or !encoder.snapshot().done) return error.WrongReceipt;
    const raw = rawEncoder(&encoder);
    if (@hasDecl(@TypeOf(raw.*), "matchFinderSnapshot")) {
        const matcher = raw.matchFinderSnapshot();
        receipt.matcher = .{ .initialized = matcher.initialized, .absolute_position = matcher.absolute_position, .indexed_positions = matcher.indexed_positions, .counter_bits = @bitSizeOf(@TypeOf(matcher.absolute_position)), .retained_history_bytes = raw.history.items.len };
        if (!matcher.initialized or matcher.absolute_position != config.count or matcher.indexed_positions == 0 or receipt.matcher.?.counter_bits != 64) return error.MatcherProgressMismatch;
    }
    receipt.input_crc32 = crc.digest();
    receipt.input_adler32 = adler.digest();
    if (@hasField(Encoder, "adler")) if (encoder.adler.digest() != receipt.input_adler32) return error.EncoderAdlerMismatch;
    if (@hasField(Encoder, "crc")) if (encoder.crc.digest() != receipt.input_crc32) return error.EncoderCrcMismatch;
    encoder.deinit();
    live = false;
    receipt.heap_peak = ledger.peak;
    receipt.heap_live_after_deinit = ledger.live;
    receipt.heap_allocations = ledger.allocations;
    if (ledger.live != 0) return error.EncoderHeapLeak;
    return receipt;
}

fn checkPledges(comptime Encoder: type, a: std.mem.Allocator, options: Encoder.Options) !void {
    var output: [common.chunk_len]u8 = undefined;
    var short = Encoder.initExactSize(a, options, 2);
    defer short.deinit();
    const accepted = try short.step("R", &output);
    if (accepted.progress.input_read != 1) return error.PledgeInputMismatch;
    short.finish();
    if (short.step(&.{}, &output)) |_| return error.ExpectedPrematurePledgeRefusal else |err| if (err != error.SizeMismatch) return err;
    var excess = Encoder.initExactSize(a, options, 1);
    defer excess.deinit();
    if (excess.step("RR", &output)) |_| return error.ExpectedExcessPledgeRefusal else |err| if (err != error.SizeMismatch) return err;
    if (excess.snapshot().input_read != 0 or short.snapshot().input_read != 1) return error.PledgeInputMismatch;
}
