const std = @import("std");
const codec = @import("codec");
const br = codec.br;
const Config = struct {
    api: enum { alloc, reuse_alloc, into, reuse, chunks_alloc, chunks_append, chunks_into, reuse_chunks, incremental },
    payload_path: []const u8,
    wire_path: []const u8,
    disable: bool = false,
    quality: ?u4 = null,
    level: br.PlannedCompressionLevel = .fast,
    large: bool = false,
    hq: bool = false,
    nested_only: bool = false,
    defaults: bool = false,
    input_chunk: usize = 97,
    output_chunk: usize = 17,
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
    const c = parsed.value;
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, c.payload_path, init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(payload);
    const options: br.PlannedEncodeOptions = .{
        .level = c.level,
        .quality = c.quality,
        .window_bits = if (c.defaults) null else if (c.large) 20 else 16,
        .large_window = c.large,
        .disable_literal_context_modeling = c.disable and !c.nested_only,
        .hq = if (c.hq) .{ .search_depth = 8, .nice_len = 32, .beam_width = 4, .iterations = 1, .block_len = 4096, .disable_literal_context_modeling = c.disable and c.nested_only } else null,
    };
    const stream_options: br.PlannedStreamChunksOptions = .{
        .level = options.level,
        .quality = options.quality,
        .window_bits = options.window_bits orelse br.default_window_bits,
        .large_window = options.large_window,
        .hq = options.hq,
        .disable_literal_context_modeling = options.disable_literal_context_modeling,
        .block_len = if (c.hq) 4096 else 3072,
    };
    const chunks = [_][]const u8{ payload[0..@min(payload.len, 128)], &.{}, payload[@min(payload.len, 128)..] };
    var wire: ?[]u8 = null;
    defer if (wire) |bytes| init.gpa.free(bytes);
    var reuse = br.PlannedStreamEncoder.init(init.gpa);
    defer reuse.deinit();
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(init.gpa);
    var into: ?[]u8 = null;
    defer if (into) |bytes| init.gpa.free(bytes);
    var calls: u64 = 0;
    const encoded: []const u8 = switch (c.api) {
        .alloc => blk: {
            wire = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, payload, options);
            break :blk wire.?;
        },
        .reuse_alloc => blk: {
            wire = try reuse.encodeWithOptionsAlloc(init.gpa, payload, options);
            break :blk wire.?;
        },
        .into => blk: {
            const bound = try br.encodedPlannedStreamBoundWithOptions(payload.len, options);
            into = try init.gpa.alloc(u8, bound + 19);
            @memset(into.?, 0xa5);
            const n = try br.encodePlannedStreamWithOptionsInto(payload, into.?[0..bound], options);
            for (into.?[n..]) |byte| try require(byte == 0xa5);
            break :blk into.?[0..n];
        },
        .reuse => try reuse.encodeScratchWithOptions(payload, options),
        .chunks_alloc => blk: {
            wire = try br.encodePlannedStreamChunksWithOptionsAlloc(init.gpa, &chunks, stream_options);
            break :blk wire.?;
        },
        .chunks_append => blk: {
            try output.appendSlice(init.gpa, "prefix");
            try br.encodePlannedStreamChunksWithOptionsAppend(init.gpa, &output, &chunks, stream_options);
            try require(std.mem.eql(u8, output.items[0..6], "prefix"));
            break :blk output.items[6..];
        },
        .chunks_into => blk: {
            const bound = try br.encodedPlannedStreamChunksBoundWithOptions(&chunks, stream_options);
            into = try init.gpa.alloc(u8, bound + 19);
            @memset(into.?, 0xa5);
            const n = try br.encodePlannedStreamChunksWithOptionsInto(&chunks, into.?[0..bound], stream_options);
            for (into.?[n..]) |byte| try require(byte == 0xa5);
            break :blk into.?[0..n];
        },
        .reuse_chunks => try reuse.encodeChunksScratchWithOptions(&chunks, stream_options),
        .incremental => blk: {
            var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .stream = stream_options, .block_len = stream_options.block_len });
            defer encoder.deinit();
            var scratch: [65536]u8 = undefined;
            var offset: usize = 0;
            var finished = false;
            while (true) {
                if (offset == payload.len and !finished) {
                    try encoder.finish();
                    finished = true;
                }
                const end = @min(payload.len, offset + c.input_chunk);
                const before = encoder.snapshot();
                const step = try encoder.step(payload[offset..end], scratch[0..c.output_chunk]);
                offset += step.progress.input_read;
                calls += 1;
                try output.appendSlice(init.gpa, scratch[0..step.progress.output_written]);
                const after = encoder.snapshot();
                try require(after.input_read == before.input_read + step.progress.input_read and after.output_written == before.output_written + step.progress.output_written);
                if (step.status == .done) {
                    try require(offset == payload.len);
                    break;
                }
                try require(step.progress.input_read != 0 or step.progress.output_written != 0);
            }
            break :blk output.items;
        },
    };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = c.wire_path, .data = encoded });
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{ .schema = "vort.br.literal-context-control.v1", .api = c.api, .quality = c.quality, .level = c.level, .large_window = c.large, .hq = c.hq, .disable = c.disable, .nested_only = c.nested_only, .payload_bytes = payload.len, .wire_bytes = encoded.len, .calls = calls, .pointer_bits = @bitSizeOf(usize), .build_mode = @tagName(@import("builtin").mode), .completed = true }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn require(value: bool) !void {
    if (!value) return error.LiteralContextProbeMismatch;
}
