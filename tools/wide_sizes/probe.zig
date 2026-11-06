const std = @import("std");
const codec = @import("codec");
const br = codec.br;
const zstd = codec.zstd;
const common = @import("common.zig");
const checks = @import("size_checks.zig");
const Mode = enum { brotli_size, zstd_size, dictionary_alloc, dictionary_append };
const Config = struct { mode: Mode, count: u64, wire_path: ?[]const u8 = null, report_path: ?[]const u8 = null };

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
    try common.require(config.count > 0);
    if (config.mode == .dictionary_alloc or config.mode == .dictionary_append) {
        try dictionary(init, config);
        return;
    }
    const wire = try std.Io.Dir.cwd().readFileAlloc(init.io, config.wire_path orelse return error.MissingWire, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(wire);
    var ledger: common.Ledger = .{ .backing = init.gpa };
    const receipt = if (config.mode == .brotli_size)
        try checks.brotli(ledger.allocator(), wire, config.count)
    else
        try checks.zstandard(ledger.allocator(), wire, config.count);
    try common.require(ledger.live == 0);
    try publish(init, config, .{
        .schema = "vort.wide-sizes.v1",
        .mode = config.mode,
        .count = config.count,
        .wire_bytes = @as(u64, @intCast(wire.len)),
        .receipt = receipt,
        .heap_peak = ledger.peak,
        .heap_live_after = ledger.live,
        .pointer_bits = @bitSizeOf(usize),
        .stream_count_bits = @bitSizeOf(codec.StreamCount),
        .build_mode = @tagName(@import("builtin").mode),
    });
}

fn dictionary(init: std.process.Init, config: Config) !void {
    const tile = try init.gpa.alloc(u8, common.tile_len);
    defer init.gpa.free(tile);
    for (tile, 0..) |*byte, index| byte.* = common.word[index % common.word.len];
    const chunk_count_u64 = config.count / tile.len + @intFromBool(config.count % tile.len != 0);
    const chunk_count = std.math.cast(usize, chunk_count_u64) orelse return error.IntegerOverflow;
    const chunks = try init.gpa.alloc([]const u8, chunk_count);
    defer init.gpa.free(chunks);
    var remaining = config.count;
    for (chunks) |*chunk| {
        const len: usize = @intCast(@min(remaining, tile.len));
        chunk.* = tile[0..len];
        remaining -= len;
    }
    try common.require(remaining == 0);
    var ledger: common.Ledger = .{ .backing = init.gpa };
    const heap = ledger.allocator();
    const options: br.StaticDictionaryStreamOptions = .{ .max_input_len = config.count, .block_len = 65536, .stream = .{ .window_bits = 16, .metadata = common.metadata } };
    var refused = options;
    refused.max_input_len = config.count - 1;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(heap);
    if (config.mode == .dictionary_append) try out.appendSlice(heap, common.prefix);
    const old_ptr = out.items.ptr;
    const old_capacity = out.capacity;
    if (br.encodePlannedStreamStaticDictionaryChunksWithOptionsAppend(heap, &out, chunks, refused)) |_| return error.ExpectedDictionaryInputLimit else |err| try common.require(err == error.OutputLimitExceeded);
    try common.require(out.items.ptr == old_ptr and out.capacity == old_capacity);
    if (config.mode == .dictionary_append) try common.require(std.mem.eql(u8, common.prefix, out.items));
    var owned: ?[]u8 = null;
    defer if (owned) |bytes| heap.free(bytes);
    if (config.mode == .dictionary_alloc) owned = try br.encodePlannedStreamStaticDictionaryChunksWithOptionsAlloc(heap, chunks, options) else try br.encodePlannedStreamStaticDictionaryChunksWithOptionsAppend(heap, &out, chunks, options);
    const wire: []const u8 = if (owned) |bytes| bytes else out.items[common.prefix.len..];
    const summary = try br.summarizeStreamAlloc(heap, wire);
    try common.require(summary.decoded_bytes == config.count and summary.uses_static_dictionary and summary.static_dictionary_copy_count > 0);
    try common.require(summary.metadata_bytes == common.metadata.len and summary.input_bytes == wire.len);
    var stdout_buffer: [65536]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.writeAll(wire);
    try stdout.interface.flush();
    const physical_wire: u64 = @intCast(wire.len);
    if (owned) |bytes| heap.free(bytes);
    owned = null;
    out.deinit(heap);
    out = .empty;
    try common.require(ledger.live == 0);
    try publish(init, config, .{
        .schema = "vort.wide-static-dictionary.v1",
        .mode = config.mode,
        .count = config.count,
        .wire_bytes = physical_wire,
        .summary = summary,
        .tile_bytes = tile.len,
        .chunk_views = chunk_count_u64,
        .tail_view_bytes = config.count % tile.len,
        .borrowed_word = common.word,
        .heap_peak = ledger.peak,
        .heap_live_after = ledger.live,
        .input_limit_refusals = 1,
        .pointer_bits = @bitSizeOf(usize),
        .stream_count_bits = @bitSizeOf(codec.StreamCount),
        .build_mode = @tagName(@import("builtin").mode),
    });
}

fn publish(init: std.process.Init, config: Config, value: anytype) !void {
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(bytes);
    if (config.report_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(bytes);
        try stdout.interface.writeByte('\n');
        try stdout.interface.flush();
    }
}
