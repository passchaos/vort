const std = @import("std");
const vort = @import("vort");

const Row = struct {
    name: []const u8,
    input_bytes: usize,
    output_bytes: usize,
    iterations: usize,
    elapsed_ns: i96,
    mix: u64,

    fn throughput(self: Row) f64 {
        const mib = @as(f64, @floatFromInt(self.input_bytes * self.iterations)) / (1024.0 * 1024.0);
        return mib / (@as(f64, @floatFromInt(self.elapsed_ns)) / @as(f64, std.time.ns_per_s));
    }
};

pub fn main(init: std.process.Init) !void {
    const payload = try buildPayload(init.gpa);
    defer init.gpa.free(payload);
    const iterations: usize = 80;
    const block_len: usize = 8 * 1024;
    const options = vort.optionsForCompressionLevel(.default);

    var persistent = vort.RawDeflateIncrementalBestEncoder.initWithOptions(init.gpa, .{
        .block_len = block_len,
        .compression = options,
    });
    defer persistent.deinit();

    const persistent_row = try measurePersistent(init, &persistent, payload, iterations);
    const rebuild_row = try measureRebuild(init, payload, block_len, options, iterations);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll("mode,input_bytes,output_bytes,iterations,elapsed_s,throughput_mib_s,mix\n");
    for ([_]Row{ persistent_row, rebuild_row }) |row| {
        try stdout.print("{s},{d},{d},{d},{d:.6},{d:.2},{d}\n", .{
            row.name,
            row.input_bytes,
            row.output_bytes,
            row.iterations,
            @as(f64, @floatFromInt(row.elapsed_ns)) / @as(f64, std.time.ns_per_s),
            row.throughput(),
            row.mix,
        });
    }
    try stdout.print("persistent_over_rebuild={d:.3} size_ratio={d:.3}\n", .{
        persistent_row.throughput() / rebuild_row.throughput(),
        @as(f64, @floatFromInt(persistent_row.output_bytes)) / @as(f64, @floatFromInt(rebuild_row.output_bytes)),
    });
    try stdout.flush();
}

fn measurePersistent(init: std.process.Init, encoder: *vort.RawDeflateIncrementalBestEncoder, payload: []const u8, iterations: usize) !Row {
    var mix: u64 = 0;
    var output_bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        encoder.reset();
        const encoded = try encodeIncremental(init.gpa, encoder, payload);
        defer init.gpa.free(encoded);
        output_bytes = encoded.len;
        mix +%= vort.crc32(encoded);
    }
    return .{
        .name = "persistent-lazy",
        .input_bytes = payload.len,
        .output_bytes = output_bytes,
        .iterations = iterations,
        .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(),
        .mix = mix,
    };
}

fn measureRebuild(init: std.process.Init, payload: []const u8, block_len: usize, options: vort.CompressionOptions, iterations: usize) !Row {
    var mix: u64 = 0;
    var output_bytes: usize = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const encoded = try vort.encodeRawBestSplitAlloc(init.gpa, payload, block_len, options);
        defer init.gpa.free(encoded);
        output_bytes = encoded.len;
        mix +%= vort.crc32(encoded);
    }
    return .{
        .name = "rebuild-lazy",
        .input_bytes = payload.len,
        .output_bytes = output_bytes,
        .iterations = iterations,
        .elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds(),
        .mix = mix,
    };
}

fn encodeIncremental(allocator: std.mem.Allocator, encoder: *vort.RawDeflateIncrementalBestEncoder, payload: []const u8) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var scratch: [4096]u8 = undefined;
    var offset: usize = 0;
    while (offset < payload.len) {
        const result = try encoder.step(payload[offset..], &scratch);
        offset += result.progress.input_read;
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &scratch);
        try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
    return encoded.toOwnedSlice(allocator);
}

fn buildPayload(allocator: std.mem.Allocator) ![]u8 {
    var payload: std.ArrayList(u8) = .empty;
    errdefer payload.deinit(allocator);
    const line = "{\"time\":123456,\"level\":\"info\",\"message\":\"incremental lazy hash chain benchmark\",\"request\":\"abcdef0123456789\"}\n";
    while (payload.items.len < 256 * 1024) try payload.appendSlice(allocator, line);
    payload.items.len = 256 * 1024;
    return payload.toOwnedSlice(allocator);
}
