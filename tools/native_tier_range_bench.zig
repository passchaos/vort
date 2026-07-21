const std = @import("std");
const vort = @import("vort");

const Tier = vort.SeekabilityTier;

const Fixture = struct {
    name: []const u8,
    data: []const u8,
};

const Row = struct {
    fixture: []const u8,
    tier: Tier,
    block_len: usize,
    input_bytes: usize,
    stream_bytes: usize,
    index_entries: usize,
    range_offset: usize,
    range_len: usize,
    iterations: usize,
    repeat: usize,
    elapsed_ns: u64,
    range_mib_s: f64,
    full_input_mib_s: f64,
    checksum: u64,
};

const RunResult = struct {
    elapsed_ns: u64,
    checksum: u64,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var iterations: usize = 400;
    var repeat: usize = 3;
    var range_len: usize = 4096;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try parsePositiveUsize(args.next());
            continue;
        }
        if (std.mem.eql(u8, arg, "--repeat")) {
            repeat = try parsePositiveUsize(args.next());
            continue;
        }
        if (std.mem.eql(u8, arg, "--range-len")) {
            range_len = try parsePositiveUsize(args.next());
            continue;
        }
        return error.UnknownArgument;
    }

    const text = "Seekable native tier range benchmark text payload. " ** 2048;
    const structured = "{\"service\":\"vort\",\"tier\":\"seekability\",\"value\":12345}\n" ** 1600;
    const repetitive = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 512;
    const fixtures = [_]Fixture{
        .{ .name = "text", .data = text },
        .{ .name = "structured", .data = structured },
        .{ .name = "repetitive", .data = repetitive },
    };
    const tiers = [_]Tier{ .seek_fast, .balanced, .ratio };

    var rows = try std.ArrayList(Row).initCapacity(init.gpa, fixtures.len * tiers.len);
    defer rows.deinit(init.gpa);

    for (fixtures) |fixture| {
        const effective_range_len = @min(range_len, fixture.data.len);
        const range_offset = if (fixture.data.len <= effective_range_len) 0 else (fixture.data.len - effective_range_len) / 2;
        const expected = fixture.data[range_offset..][0..effective_range_len];
        for (tiers) |tier| {
            const options = vort.SeekableNativeOptions.withSeekabilityTier(tier);
            const stream = try vort.storeEncodeSeekableNativeStreamAlloc(init.gpa, fixture.data, options);
            defer init.gpa.free(stream);
            const view = try vort.storeViewEmbeddedIndex(stream);
            const index = try init.gpa.alloc(vort.StoreFrameIndexEntry, view.entry_count);
            defer init.gpa.free(index);
            const decoded_index = try vort.storeDecodeEmbeddedIndex(stream, index);
            const entries = index[0..decoded_index.entries_written];
            const output = try init.gpa.alloc(u8, effective_range_len);
            defer init.gpa.free(output);

            const verify = try vort.storeDecodeIndexedRangeIntoWithIndexBuffer(init.gpa, stream, range_offset, effective_range_len, output, entries);
            if (verify.output_written != effective_range_len) return error.SizeMismatch;
            if (!std.mem.eql(u8, output, expected)) return error.SizeMismatch;

            var samples = try std.ArrayList(RunResult).initCapacity(init.gpa, repeat);
            defer samples.deinit(init.gpa);
            for (0..repeat) |_| {
                try samples.append(init.gpa, try runRangeDecodeBench(init.gpa, stream, entries, range_offset, output, iterations, init.io));
            }
            const best = bestRun(samples.items);
            const seconds = @as(f64, @floatFromInt(best.elapsed_ns)) / 1_000_000_000.0;
            const range_bytes = effective_range_len * iterations;
            const full_bytes = fixture.data.len * iterations;
            try rows.append(init.gpa, .{
                .fixture = fixture.name,
                .tier = tier,
                .block_len = options.block_len,
                .input_bytes = fixture.data.len,
                .stream_bytes = stream.len,
                .index_entries = entries.len,
                .range_offset = range_offset,
                .range_len = effective_range_len,
                .iterations = iterations,
                .repeat = repeat,
                .elapsed_ns = best.elapsed_ns,
                .range_mib_s = mibPerSecond(range_bytes, seconds),
                .full_input_mib_s = mibPerSecond(full_bytes, seconds),
                .checksum = best.checksum,
            });
        }
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var stdout_buffer: [1024]u8 = undefined;
        var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
        try stdout_writer.interface.writeAll(csv.written());
        try stdout_writer.interface.flush();
    }
}

fn parsePositiveUsize(text: ?[]const u8) !usize {
    const value = text orelse return error.MissingReportPath;
    const parsed = try std.fmt.parseInt(usize, value, 10);
    if (parsed == 0) return error.InvalidBlockPlan;
    return parsed;
}

fn runRangeDecodeBench(allocator: std.mem.Allocator, stream: []const u8, index: []vort.StoreFrameIndexEntry, offset: usize, output: []u8, iterations: usize, io: std.Io) !RunResult {
    const start = std.Io.Clock.awake.now(io);
    var checksum: u64 = 0;
    for (0..iterations) |_| {
        const result = try vort.storeDecodeIndexedRangeIntoWithIndexBuffer(allocator, stream, offset, output.len, output, index);
        if (result.output_written != output.len) return error.SizeMismatch;
        checksum +%= result.crc32;
    }
    const elapsed_ns_signed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    if (elapsed_ns_signed < 0) return error.InvalidTimestamp;
    return .{ .elapsed_ns = @intCast(elapsed_ns_signed), .checksum = checksum };
}

fn bestRun(samples: []const RunResult) RunResult {
    var best = samples[0];
    for (samples[1..]) |sample| {
        if (sample.elapsed_ns < best.elapsed_ns) best = sample;
    }
    return best;
}

fn mibPerSecond(bytes: usize, seconds: f64) f64 {
    if (seconds <= 0.0) return 0.0;
    return (@as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0)) / seconds;
}

fn tierLabel(tier: Tier) []const u8 {
    return switch (tier) {
        .seek_fast => "seek_fast",
        .balanced => "balanced",
        .ratio => "ratio",
    };
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll("fixture,tier,block_len,input_bytes,stream_bytes,index_entries,range_offset,range_len,iterations,repeat,elapsed_ns,range_mib_s,full_input_mib_s,checksum\n");
    for (rows) |row| {
        try writer.print("{s},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d:.6},{d:.6},{d}\n", .{
            row.fixture,
            tierLabel(row.tier),
            row.block_len,
            row.input_bytes,
            row.stream_bytes,
            row.index_entries,
            row.range_offset,
            row.range_len,
            row.iterations,
            row.repeat,
            row.elapsed_ns,
            row.range_mib_s,
            row.full_input_mib_s,
            row.checksum,
        });
    }
}
