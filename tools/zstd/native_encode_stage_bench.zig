const std = @import("std");
const vort = @import("vort");

const Case = struct { name: []const u8, payload: []const u8 };
const Options = struct {
    iterations: usize = 1,
    rounds: usize = 7,
    warmup: usize = 1,
    level: c_int = 9,
    only_case: ?[]const u8 = null,
    only_candidate: ?[]const u8 = null,
    only_stage: ?[]const u8 = null,
    csv_path: ?[]const u8 = null,
};
const Candidate = struct { name: []const u8, block_size: usize };
const Sample = struct { ns: u64, mix: usize };
const Aggregate = struct { available_blocks: usize, encoded_len: usize, sequence_count: usize, literals_bytes: usize, sequence_bytes: usize };

const stages = [_]vort.zstd.NativeMatchStage{
    .mixed,
    .double_fast,
    .greedy,
    .lazy,
    .optimal,
    .rep_beam,
    .repeated,
    .multi_duplicate,
    .single_duplicate,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);

    var numbered_json: std.ArrayList(u8) = .empty;
    defer numbered_json.deinit(init.gpa);
    while (numbered_json.items.len < 32 * 1024) {
        var line: [128]u8 = undefined;
        const index = numbered_json.items.len / 64;
        const formatted = try std.fmt.bufPrint(&line, "{{\"id\":{d},\"service\":\"vort\",\"message\":\"structured zstd encode corpus\"}}\n", .{index});
        try numbered_json.appendSlice(init.gpa, formatted);
    }
    const binary = try init.gpa.alloc(u8, 32 * 1024);
    defer init.gpa.free(binary);
    var state: u32 = 0xfeed_beef;
    for (binary, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    const cases = [_]Case{
        .{ .name = "text", .payload = "Zstandard encode benchmark text with repeated structure and punctuation.\n" ** 512 },
        .{ .name = "json", .payload = numbered_json.items },
        .{ .name = "binary", .payload = binary },
    };

    const policy = try vort.zstd.nativeEncodeLevelDiagnostics(options.level, .{});
    const candidates = [_]Candidate{
        .{ .name = "primary", .block_size = policy.primary_options.block_size_max },
        .{ .name = "adaptive_0", .block_size = policy.adaptive_block_sizes[0] },
        .{ .name = "adaptive_1", .block_size = policy.adaptive_block_sizes[1] },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,level,candidate,block_size,block_count,search_budget,stage,available_blocks,sequences,encoded_bytes,literals_bytes,sequence_bytes,iterations,rounds,warmup,median_ns,ns_per_block,checksum\n");
    var selected_rows: usize = 0;
    for (cases) |case| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        for (candidates) |candidate| {
            if (options.only_candidate) |wanted| if (!std.mem.eql(u8, wanted, candidate.name)) continue;
            if (candidate.block_size >= case.payload.len and !std.mem.eql(u8, candidate.name, "primary")) continue;
            const search_budget = if (std.mem.eql(u8, candidate.name, "primary"))
                policy.primary_options.match_search_budget
            else
                policy.adaptive_match_search_budget;
            selected_rows += try benchmarkCandidate(init.io, init.gpa, &csv.writer, case, candidate, search_budget, options);
        }
    }
    if (selected_rows == 0) return error.InvalidBlockPlan;

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn benchmarkCandidate(
    io: std.Io,
    allocator: std.mem.Allocator,
    csv: *std.Io.Writer,
    case: Case,
    candidate: Candidate,
    search_budget: usize,
    options: Options,
) !usize {
    var scratch: vort.zstd.NativeMatchStageScratch = .{};
    defer scratch.deinit(allocator);
    var selected_rows: usize = 0;

    if (stageSelected(options.only_stage, "duplicate_index")) {
        const indexed_block_count = try prepareAllBlocks(allocator, case.payload, candidate.block_size, &scratch);
        vort.zstd.benchmarkInvalidateNativeMatchStageScratch(&scratch);
        try writeMeasuredRow(io, allocator, csv, case, candidate, search_budget, options, .index, indexed_block_count, 0, 0, 0, 0, &scratch);
        selected_rows += 1;
    }
    for (stages) |stage| {
        if (!stageSelected(options.only_stage, @tagName(stage))) continue;
        const probe = try evaluateAllBlocks(allocator, case.payload, candidate.block_size, search_budget, stage, &scratch);
        try writeMeasuredRow(io, allocator, csv, case, candidate, search_budget, options, .{ .candidate = stage }, probe.available_blocks, probe.sequence_count, probe.encoded_len, probe.literals_bytes, probe.sequence_bytes, &scratch);
        selected_rows += 1;
    }
    return selected_rows;
}

fn stageSelected(only_stage: ?[]const u8, name: []const u8) bool {
    const wanted = only_stage orelse return true;
    return std.mem.eql(u8, wanted, name);
}

const MeasuredStage = union(enum) {
    index,
    candidate: vort.zstd.NativeMatchStage,

    fn name(self: MeasuredStage) []const u8 {
        return switch (self) {
            .index => "duplicate_index",
            .candidate => |stage| @tagName(stage),
        };
    }
};

fn writeMeasuredRow(
    io: std.Io,
    allocator: std.mem.Allocator,
    csv: *std.Io.Writer,
    case: Case,
    candidate: Candidate,
    search_budget: usize,
    options: Options,
    stage: MeasuredStage,
    available_blocks: usize,
    sequence_count: usize,
    encoded_len: usize,
    literals_bytes: usize,
    sequence_bytes: usize,
    scratch: *vort.zstd.NativeMatchStageScratch,
) !void {
    var warmup_mix: usize = 0;
    for (0..options.warmup) |_| warmup_mix +%= (try measureStagePass(io, allocator, case.payload, candidate.block_size, search_budget, stage, scratch)).mix;

    const samples = try allocator.alloc(Sample, options.rounds);
    defer allocator.free(samples);
    for (samples) |*sample| {
        sample.* = .{ .ns = 0, .mix = 0 };
        for (0..options.iterations) |_| {
            const pass = try measureStagePass(io, allocator, case.payload, candidate.block_size, search_budget, stage, scratch);
            sample.ns +%= pass.ns;
            sample.mix +%= pass.mix;
        }
    }
    std.mem.sort(Sample, samples, {}, struct {
        fn lessThan(_: void, lhs: Sample, rhs: Sample) bool {
            return lhs.ns < rhs.ns;
        }
    }.lessThan);
    const median = samples[samples.len / 2];
    const blocks_per_sample = blockCount(case.payload.len, candidate.block_size) * options.iterations;
    const ns_per_block = if (blocks_per_sample == 0) 0 else median.ns / blocks_per_sample;
    try csv.print("{s},{d},{s},{d},{d},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        case.name,
        options.level,
        candidate.name,
        candidate.block_size,
        blockCount(case.payload.len, candidate.block_size),
        search_budget,
        stage.name(),
        available_blocks,
        sequence_count,
        encoded_len,
        literals_bytes,
        sequence_bytes,
        options.iterations,
        options.rounds,
        options.warmup,
        median.ns,
        ns_per_block,
        median.mix +% warmup_mix,
    });
}

fn measureStagePass(
    io: std.Io,
    allocator: std.mem.Allocator,
    payload: []const u8,
    block_size: usize,
    search_budget: usize,
    stage: MeasuredStage,
    scratch: *vort.zstd.NativeMatchStageScratch,
) !Sample {
    var sample: Sample = .{ .ns = 0, .mix = 0 };
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + block_size);
        const block = payload[offset..end];
        switch (stage) {
            .index => {
                const start = std.Io.Clock.awake.now(io);
                const available = try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, block, scratch);
                sample.ns +%= elapsed(start, io);
                sample.mix +%= @intFromBool(available);
                vort.zstd.benchmarkInvalidateNativeMatchStageScratch(scratch);
            },
            .candidate => |candidate_stage| {
                // Production shares this setup across mixed/multi/single. Keep
                // it outside each family timer and report it as its own row.
                if (block.len > 4096 and block.len <= std.math.maxInt(u16))
                    _ = try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, block, scratch);
                const start = std.Io.Clock.awake.now(io);
                const result = try vort.zstd.benchmarkNativeMatchStage(allocator, block, end == payload.len, search_budget, candidate_stage, scratch);
                sample.ns +%= elapsed(start, io);
                sample.mix +%= result.encoded_len +% result.sequence_count;
            },
        }
        offset = end;
    }
    return sample;
}

fn prepareAllBlocks(allocator: std.mem.Allocator, payload: []const u8, block_size: usize, scratch: *vort.zstd.NativeMatchStageScratch) !usize {
    var mix: usize = 0;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + block_size);
        mix +%= @intFromBool(try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, payload[offset..end], scratch));
        offset = end;
    }
    return mix;
}

fn evaluateAllBlocks(
    allocator: std.mem.Allocator,
    payload: []const u8,
    block_size: usize,
    search_budget: usize,
    stage: vort.zstd.NativeMatchStage,
    scratch: *vort.zstd.NativeMatchStageScratch,
) !Aggregate {
    var available_blocks: usize = 0;
    var encoded_len: usize = 0;
    var sequence_count: usize = 0;
    var literals_bytes: usize = 0;
    var sequence_bytes: usize = 0;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + block_size);
        const block = payload[offset..end];
        if (block.len > 4096 and block.len <= std.math.maxInt(u16))
            _ = try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, block, scratch);
        const result = try vort.zstd.benchmarkNativeMatchStage(allocator, block, end == payload.len, search_budget, stage, scratch);
        available_blocks += @intFromBool(result.available);
        encoded_len +%= result.encoded_len;
        sequence_count +%= result.sequence_count;
        literals_bytes +%= result.literals_bytes;
        sequence_bytes +%= result.sequence_bytes;
        offset = end;
    }
    return .{ .available_blocks = available_blocks, .encoded_len = encoded_len, .sequence_count = sequence_count, .literals_bytes = literals_bytes, .sequence_bytes = sequence_bytes };
}

fn blockCount(input_len: usize, block_size: usize) usize {
    if (input_len == 0) return 1;
    return (input_len + block_size - 1) / block_size;
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--rounds"))
            options.rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--warmup"))
            options.warmup = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--level"))
            options.level = try std.fmt.parseInt(c_int, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--case"))
            options.only_case = args.next() orelse return error.MissingCorpusPath
        else if (std.mem.eql(u8, arg, "--candidate"))
            options.only_candidate = args.next() orelse return error.MissingLimit
        else if (std.mem.eql(u8, arg, "--stage"))
            options.only_stage = args.next() orelse return error.MissingLimit
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingCorpusPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0) return error.InvalidBlockPlan;
    return options;
}
