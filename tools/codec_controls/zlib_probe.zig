const std = @import("std");
const h = @import("common.zig");
const D = h.codec.deflate;
const Stream = struct { suffix: []const u8 = "", input_read: u64 = 0, wire_bytes: usize = 0, params_changes: u64 = 0, unsupported_params_refusals: usize = 0, advertised_window: usize = 0 };
pub const Receipt = struct { wire_bytes: usize = 0, default_bytes_checked: bool = false, invalid_options_refusals: usize = 0, streams: [3]Stream = @splat(.{}), stream_count: usize = 0 };

pub fn run(init: std.process.Init, config: h.Config) !Receipt {
    const payload = try h.read(init, config.payload_path);
    defer init.gpa.free(payload);
    const dictionary = if (config.dictionary_path) |path| try h.read(init, path) else null;
    defer if (dictionary) |bytes| init.gpa.free(bytes);
    if (std.mem.startsWith(u8, config.api, "incremental_")) {
        if (std.mem.eql(u8, config.api, "incremental_fixed")) return incremental(D.ZlibIncrementalFixedEncoder, init, config, payload, dictionary);
        if (std.mem.eql(u8, config.api, "incremental_best")) return incremental(D.ZlibIncrementalBestEncoder, init, config, payload, dictionary);
        return error.UnknownApi;
    }
    const options: D.ZlibEncodeOptions = .{
        .window_bits = config.window_bits,
        .mode = std.meta.stringToEnum(D.ZlibEncodeMode, config.zlib_mode) orelse return error.UnknownMode,
        .compression = .{ .parser = .hash, .lz77_options = .{ .max_chain = 16, .max_candidates = 3, .nice_len = 128 } },
        .dictionary = dictionary,
        .block_len = config.block_len,
        .split_options = .{ .min_block_len = 128, .max_block_len = 1024, .sample_len = 256, .search_step = 128 },
    };
    var encoder = try D.ZlibFrameEncoder.init(init.gpa, options);
    defer encoder.deinit();
    const chunks = try makeChunks(init.gpa, payload, config.input_chunk);
    defer init.gpa.free(chunks);
    const stored_chunks = std.mem.startsWith(u8, config.api, "stored_chunks_");
    var owned: ?[]u8 = null;
    defer if (owned) |bytes| init.gpa.free(bytes);
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(init.gpa);
    var into: ?[]u8 = null;
    defer if (into) |bytes| init.gpa.free(bytes);
    const wire: []const u8 = if (std.mem.endsWith(u8, config.api, "alloc")) blk: {
        owned = if (stored_chunks) try encoder.encodeStoredChunksAlloc(chunks) else try encoder.encodeAlloc(payload);
        break :blk owned.?;
    } else if (std.mem.endsWith(u8, config.api, "append")) blk: {
        try appended.appendSlice(init.gpa, "prefix");
        const count = if (stored_chunks) try encoder.encodeStoredChunksAppend(&appended, chunks) else try encoder.encodeAppend(&appended, payload);
        try h.require(std.mem.eql(u8, appended.items[0..6], "prefix") and appended.items.len == count + 6);
        break :blk appended.items[6..];
    } else if (std.mem.endsWith(u8, config.api, "into")) blk: {
        into = try init.gpa.alloc(u8, payload.len * 4 + 4096);
        @memset(into.?, 0xa5);
        const count = if (stored_chunks) try encoder.encodeStoredChunksInto(chunks, into.?) else try encoder.encodeInto(payload, into.?);
        for (into.?[count..]) |byte| try h.require(byte == 0xa5);
        break :blk into.?[0..count];
    } else if (std.mem.endsWith(u8, config.api, "scratch")) blk: {
        break :blk if (stored_chunks) try encoder.encodeStoredChunksScratch(chunks) else try encoder.encodeScratch(payload);
    } else return error.UnknownApi;
    var receipt: Receipt = .{ .wire_bytes = wire.len };
    if (config.window_bits == 15 and !stored_chunks) {
        const original = try legacy(init.gpa, payload, options);
        defer init.gpa.free(original);
        try h.require(std.mem.eql(u8, original, wire));
        receipt.default_bytes_checked = true;
    }
    for ([_]u8{ 8, 16 }) |bits| {
        var invalid = options;
        invalid.window_bits = bits;
        if (encoder.setOptions(invalid)) |_| return error.ExpectedWindowRefusal else |err| try h.require(err == error.InvalidZlibWindow);
        try h.require(encoder.options.window_bits == options.window_bits);
        receipt.invalid_options_refusals += 1;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = config.output_path orelse return error.MissingOutput, .data = wire });
    return receipt;
}

fn makeChunks(a: std.mem.Allocator, payload: []const u8, quota: usize) ![][]const u8 {
    try h.require(quota > 0);
    const chunks = try a.alloc([]const u8, payload.len / quota + @intFromBool(payload.len % quota != 0));
    var offset: usize = 0;
    for (chunks) |*chunk| {
        const end = @min(payload.len, offset + quota);
        chunk.* = payload[offset..end];
        offset = end;
    }
    return chunks;
}

fn legacy(a: std.mem.Allocator, payload: []const u8, options: D.ZlibEncodeOptions) ![]u8 {
    const dictionary = options.dictionary;
    return switch (options.mode) {
        .stored => if (dictionary) |dict| D.encodeZlibStoredWithDictionaryAlloc(a, payload, dict) else D.encodeZlibStoredAlloc(a, payload),
        .fixed => if (options.block_len) |len|
            if (dictionary) |dict| D.encodeZlibFixedSplitWithDictionaryAlloc(a, payload, dict, len, options.compression) else D.encodeZlibFixedSplitAlloc(a, payload, len, options.compression)
        else if (dictionary) |dict| D.encodeZlibFixedWithDictionaryAlloc(a, payload, dict, options.compression) else D.encodeZlibFixedWithOptionsAlloc(a, payload, options.compression),
        .dynamic => if (options.block_len) |len|
            if (dictionary) |dict| D.encodeZlibDynamicSplitWithDictionaryAlloc(a, payload, dict, len, options.compression) else D.encodeZlibDynamicSplitAlloc(a, payload, len, options.compression)
        else if (dictionary) |dict| D.encodeZlibDynamicWithDictionaryAlloc(a, payload, dict, options.compression) else D.encodeZlibDynamicWithOptionsAlloc(a, payload, options.compression),
        .dynamic_literal => D.encodeZlibDynamicLiteralAlloc(a, payload),
        .best => if (options.block_len) |len|
            if (dictionary) |dict| D.encodeZlibBestSplitWithDictionaryAlloc(a, payload, dict, len, options.compression) else D.encodeZlibBestSplitAlloc(a, payload, len, options.compression)
        else if (dictionary) |dict| D.encodeZlibBestWithDictionaryAlloc(a, payload, dict, options.compression) else D.encodeZlibBestAlloc(a, payload, options.compression),
        .adaptive => if (dictionary) |dict| D.encodeZlibBestAdaptiveSplitWithDictionaryAlloc(a, payload, dict, options.compression, options.split_options) else D.encodeZlibBestAdaptiveSplitAlloc(a, payload, options.compression, options.split_options),
        .png_ultrafast => D.encodeZlibPngUltraFastAlloc(a, payload),
    };
}

fn incremental(comptime Encoder: type, init: std.process.Init, config: h.Config, payload: []const u8, dictionary: ?[]const u8) !Receipt {
    const settings: Encoder.Options = .{ .window_bits = config.window_bits, .raw = .{ .block_len = 257, .compression = .{ .parser = .hash } } };
    var encoder = if (dictionary) |bytes| Encoder.initExactSizeWithDictionary(init.gpa, settings, payload.len, bytes) else Encoder.initExactSize(init.gpa, settings, payload.len);
    defer encoder.deinit();
    var receipt: Receipt = .{};
    const main = try encodeStream(init, &encoder, config, payload, config.runtime_schedule);
    defer init.gpa.free(main.wire);
    receipt.streams[0] = main.receipt;
    receipt.wire_bytes = main.wire.len;
    receipt.stream_count = 3;
    if (config.window_bits == 15) {
        var default = if (dictionary) |bytes| Encoder.initExactSizeWithDictionary(init.gpa, .{ .raw = settings.raw }, payload.len, bytes) else Encoder.initExactSize(init.gpa, .{ .raw = settings.raw }, payload.len);
        defer default.deinit();
        const original = try encodeStream(init, &default, config, payload, config.runtime_schedule);
        defer init.gpa.free(original.wire);
        try h.require(std.mem.eql(u8, original.wire, main.wire));
        receipt.default_bytes_checked = true;
    }
    const path = config.output_path orelse return error.MissingOutput;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = main.wire });
    encoder.reset();
    const reset = try encodeStream(init, &encoder, config, payload, false);
    defer init.gpa.free(reset.wire);
    receipt.streams[1] = reset.receipt;
    receipt.streams[1].suffix = ".reset";
    const reset_path = try std.fmt.allocPrint(init.gpa, "{s}.reset", .{path});
    defer init.gpa.free(reset_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = reset_path, .data = reset.wire });
    try encoder.nextStreamExactSize(settings, dictionary orelse &.{}, payload.len);
    const next = try encodeStream(init, &encoder, config, payload, false);
    defer init.gpa.free(next.wire);
    receipt.streams[2] = next.receipt;
    receipt.streams[2].suffix = ".next";
    const next_path = try std.fmt.allocPrint(init.gpa, "{s}.next", .{path});
    defer init.gpa.free(next_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = next_path, .data = next.wire });
    return receipt;
}

fn encodeStream(init: std.process.Init, encoder: anytype, config: h.Config, payload: []const u8, scheduled: bool) !struct { wire: []u8, receipt: Stream } {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(init.gpa);
    var output: [65536]u8 = undefined;
    const start = encoder.snapshot();
    var offset: usize = 0;
    var stage: usize = 0;
    var unsupported_params: usize = 0;
    var finishing = false;
    const window = @as(usize, 1) << @as(std.math.Log2Int(usize), @intCast(config.window_bits));
    while (true) {
        if (scheduled and stage < 2 and offset == payload.len * (stage + 1) / 3) {
            const params: D.DeflateParams = .{ .level = if (stage == 0) 0 else 6, .strategy = .default };
            if (@TypeOf(encoder.*).supports_runtime_params) {
                try encoder.requestParams(params);
            } else {
                const unchanged = encoder.snapshot();
                if (encoder.requestParams(params)) |_| return error.ExpectedUnsupportedParams else |err| try h.require(err == error.UnsupportedOperation);
                try h.require(std.meta.eql(unchanged, encoder.snapshot()));
                unsupported_params += 1;
            }
            if (stage == 0) encoder.flush() else encoder.fullFlush();
            stage += 1;
        }
        if (offset == payload.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const before = encoder.snapshot();
        const target = if (scheduled and stage < 2) payload.len * (stage + 1) / 3 else payload.len;
        const end = if (before.flushing) offset else @min(target, offset + config.input_chunk);
        const result = try encoder.step(payload[offset..end], output[0..config.output_chunk]);
        offset += result.progress.input_read;
        try wire.appendSlice(init.gpa, output[0..result.progress.output_written]);
        const after = encoder.snapshot();
        try h.require(after.input_read == before.input_read + result.progress.input_read and after.output_written == before.output_written + result.progress.output_written);
        try h.require(encoder.options.window_bits == config.window_bits);
        if (result.status == .done) {
            try h.require(offset == payload.len and after.input_read - start.input_read == payload.len and after.output_written - start.output_written == wire.items.len);
            if (scheduled and @TypeOf(encoder.*).supports_runtime_params) try h.require(after.params_change_count >= 2);
            const wire_len = wire.items.len;
            return .{ .wire = try wire.toOwnedSlice(init.gpa), .receipt = .{ .input_read = payload.len, .wire_bytes = wire_len, .params_changes = after.params_change_count, .unsupported_params_refusals = unsupported_params, .advertised_window = window } };
        }
        try h.require(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
}
