const std = @import("std");
const codec = @import("codec");
const common = @import("common.zig");

pub fn run(init: std.process.Init, config: common.Config, prefix: []const u8, tail_a: []const u8, tail_b: []const u8, dictionary: []const u8) !common.Receipt {
    return switch (config.family) {
        .raw_stored => try fork(codec.RawDeflateIncrementalStoredEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        .raw_fixed => try fork(codec.RawDeflateIncrementalFixedEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        .raw_best => try fork(codec.RawDeflateIncrementalBestEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        .zlib_fixed => try fork(codec.ZlibIncrementalFixedEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        .zlib_best => try fork(codec.ZlibIncrementalBestEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        .gzip_fixed => try fork(codec.GzipIncrementalFixedEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        .gzip_best => try fork(codec.GzipIncrementalBestEncoder, init, config, prefix, tail_a, tail_b, dictionary),
        else => error.InvalidConfig,
    };
}

fn options(comptime Encoder: type, config: common.Config) Encoder.Options {
    var result: Encoder.Options = .{};
    const raw = if (@hasField(Encoder.Options, "raw")) &result.raw else &result;
    raw.block_len = 257;
    if (@hasField(@TypeOf(raw.*), "compression")) {
        raw.compression = codec.optionsForCompressionLevel(.fast);
        raw.compression.lz77_options.window_len = @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(config.window_bits));
    }
    if (@hasField(Encoder.Options, "window_bits")) result.window_bits = config.window_bits;
    if (@hasField(Encoder.Options, "header")) {
        result.header = .{ .filename = "immutable-clone-fixture", .comment = "borrowed until both branches finish" };
    }
    return result;
}

fn fork(comptime Encoder: type, init: std.process.Init, config: common.Config, prefix: []const u8, tail_a: []const u8, tail_b: []const u8, dictionary: []const u8) !common.Receipt {
    var ledger: common.Ledger = .{ .backing = init.gpa };
    const allocator = ledger.allocator();
    const source = try allocator.create(Encoder);
    var source_live = true;
    defer if (source_live) {
        source.deinit();
        allocator.destroy(source);
    };
    const opts = options(Encoder, config);
    if (@hasDecl(Encoder, "initWithDictionary")) {
        source.* = Encoder.initWithDictionary(allocator, opts, dictionary);
    } else {
        source.* = Encoder.initWithOptions(allocator, opts);
        if (dictionary.len != 0) return error.InvalidConfig;
    }
    if (config.logical_counter_base != 0) {
        if (comptime Encoder == codec.RawDeflateIncrementalBestEncoder) {
            source.total_input = config.logical_counter_base;
            source.total_output = config.logical_counter_base;
            source.match_finder.absolute_position = config.logical_counter_base;
        } else return error.InvalidConfig;
    }
    var shared_wire: std.ArrayList(u8) = .empty;
    defer shared_wire.deinit(init.gpa);
    var accepted: usize = 0;
    var calls: usize = 0;
    if (config.stage == .header) {
        accepted += try step(source, prefix, 1, init.gpa, &shared_wire, &calls);
    } else {
        while (accepted < prefix.len) accepted += try step(source, prefix[accepted..], 113, init.gpa, &shared_wire, &calls);
        if (config.stage == .params) {
            if (@hasDecl(Encoder, "supports_runtime_params")) {
                if (!Encoder.supports_runtime_params) return error.InvalidConfig;
                try source.requestParams(.{ .level = 9, .strategy = .fixed });
            } else return error.InvalidConfig;
        } else if (config.stage == .trailer) {
            if (@hasField(Encoder, "footer_written")) {
                if (tail_a.len != 0 or tail_b.len != 0) return error.InvalidConfig;
                source.finish();
                while (!source.footer_written) _ = try step(source, &.{}, 1, init.gpa, &shared_wire, &calls);
            } else return error.InvalidConfig;
        } else {
            flush(source, config.flush);
            _ = try step(source, &.{}, 1, init.gpa, &shared_wire, &calls);
            if (config.stage == .bits) {
                while (source.snapshot().flushing or source.snapshot().pending_output != 0)
                    _ = try step(source, &.{}, 113, init.gpa, &shared_wire, &calls);
            }
        }
    }
    const state = source.snapshot();
    if (state.input_read != config.logical_counter_base + accepted or state.output_written != config.logical_counter_base + shared_wire.items.len)
        return error.InexactSourceProgress;
    const fork_receipt: common.Fork = .{
        .input_read = state.input_read,
        .output_written = state.output_written,
        .pending_output = state.pending_output,
        .pending_bits = state.pending_bits,
        .params_queued = if (@hasField(@TypeOf(state), "params_boundary_pending")) state.params_boundary_pending else false,
        .flushing = state.flushing,
        .footer_written = if (@hasField(Encoder, "footer_written")) source.footer_written else false,
    };
    var a = try source.clone(allocator);
    var a_live = true;
    defer if (a_live) a.deinit();
    var b = try source.clone(allocator);
    var b_live = true;
    defer if (b_live) b.deinit();
    if (!std.meta.eql(state, a.snapshot()) or !std.meta.eql(state, b.snapshot())) return error.CloneSnapshotMismatch;
    source.deinit();
    @memset(std.mem.asBytes(source), 0xd7);
    allocator.destroy(source);
    source_live = false;
    const a_receipt = try branch(&a, init, prefix, tail_a, accepted, shared_wire.items, config.wire_a_path, calls, config.logical_counter_base);
    a.reset();
    _ = try branch(&a, init, common.reset_plain, &.{}, 0, &.{}, config.reset_path, 0, 0);
    a.deinit();
    a_live = false;
    const b_receipt = try branch(&b, init, prefix, tail_b, accepted, shared_wire.items, config.wire_b_path, calls, config.logical_counter_base);
    b.deinit();
    b_live = false;
    if (ledger.live != 0) return error.CloneAllocationLeak;
    return .{ .fork = fork_receipt, .branches = .{ a_receipt, b_receipt }, .heap_live_after_free = ledger.live, .heap_peak = ledger.peak, .logical_counter_base = config.logical_counter_base, .dictionary_ownership = if (dictionary.len == 0) "none; gzip filename/comment are immutable static borrows" else "immutable caller dictionary borrow retained until both encoders and resets finish" };
}

fn flush(encoder: anytype, mode: common.Flush) void {
    switch (mode) {
        .none => {},
        .block => encoder.blockFlush(),
        .partial => encoder.partialFlush(),
        .sync => encoder.flush(),
        .full => encoder.fullFlush(),
    }
}

fn step(encoder: anytype, input: []const u8, capacity: usize, allocator: std.mem.Allocator, wire: *std.ArrayList(u8), calls: *usize) !usize {
    var guard: [121]u8 = @splat(0xa5);
    const before = encoder.snapshot();
    const result = try encoder.step(input, guard[4..][0..capacity]);
    calls.* += 1;
    if (calls.* > 100000 or result.progress.input_read > input.len or result.progress.output_written > capacity) return error.InvalidProgress;
    for (guard[0..4]) |byte| if (byte != 0xa5) return error.OutputGuard;
    for (guard[4 + capacity ..]) |byte| if (byte != 0xa5) return error.OutputGuard;
    const after = encoder.snapshot();
    if (after.input_read != before.input_read + result.progress.input_read or after.output_written != before.output_written + result.progress.output_written) return error.InexactProgress;
    try common.append(allocator, wire, guard[4..][0..result.progress.output_written]);
    return result.progress.input_read;
}

fn branch(encoder: anytype, init: std.process.Init, prefix: []const u8, tail: []const u8, accepted: usize, shared_wire: []const u8, path: []const u8, prior_calls: usize, counter_base: u64) !common.Branch {
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(init.gpa);
    try common.append(init.gpa, &wire, shared_wire);
    var calls = prior_calls;
    while (encoder.snapshot().flushing) _ = try step(encoder, &.{}, 113, init.gpa, &wire, &calls);
    var offset = accepted;
    while (offset < prefix.len) offset += try step(encoder, prefix[offset..], 113, init.gpa, &wire, &calls);
    offset = 0;
    while (offset < tail.len) offset += try step(encoder, tail[offset..], 113, init.gpa, &wire, &calls);
    encoder.finish();
    while (!encoder.snapshot().done) _ = try step(encoder, &.{}, 113, init.gpa, &wire, &calls);
    const state = encoder.snapshot();
    if (state.input_read != counter_base + prefix.len + tail.len or state.output_written != counter_base + wire.items.len) return error.InexactBranchProgress;
    try common.save(init, path, wire.items);
    var crc = std.hash.Crc32.init();
    crc.update(prefix);
    crc.update(tail);
    return .{ .input_read = state.input_read, .output_written = state.output_written, .actual_input = prefix.len + tail.len, .actual_output = wire.items.len, .crc32 = crc.final(), .calls = calls, .eof = state.done };
}
