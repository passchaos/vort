const std = @import("std");
const vort = @import("vort");
const benchmark_provenance = @import("benchmark_provenance");

const Case = struct {
    name: []const u8,
    payload: []const u8,
    primary_double_fast_only: bool = false,
    owned: bool = false,

    fn deinit(case: Case, allocator: std.mem.Allocator) void {
        if (case.owned) {
            allocator.free(case.name);
            allocator.free(case.payload);
        }
    }
};
const Options = struct {
    iterations: usize = 1,
    rounds: usize = 7,
    warmup: usize = 1,
    level: c_int = 9,
    only_case: ?[]const u8 = null,
    only_candidate: ?[]const u8 = null,
    only_stage: ?[]const u8 = null,
    csv_path: ?[]const u8 = null,
    path_limit: usize = std.compress.zstd.block_size_max,
    paths: std.ArrayList([]const u8) = .empty,

    fn deinit(options: *Options, allocator: std.mem.Allocator) void {
        for (options.paths.items) |path| allocator.free(path);
        options.paths.deinit(allocator);
    }
};
const Candidate = struct { name: []const u8, block_size: usize };
const Sample = struct { ns: u64, mix: usize };
const Aggregate = struct {
    available_blocks: usize,
    encoded_len: usize,
    sequence_count: usize,
    literals_bytes: usize,
    sequence_bytes: usize,
    single_beam_profile: vort.zstd.NativeSingleBeamProfile = .{},
};

const stages = [_]vort.zstd.NativeMatchStage{
    .mixed,
    .double_fast,
    .greedy,
    .lazy,
    .optimal,
    .rep_beam,
    .rep_beam_single,
    .repeated,
    .multi_duplicate,
    .single_duplicate,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var options = try parseOptions(init.gpa, &args);
    defer options.deinit(init.gpa);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);

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
    const wide_sequences = try init.gpa.alloc(u8, std.compress.zstd.block_size_max);
    defer init.gpa.free(wide_sequences);
    state = 0xfeed_beef;
    for (wide_sequences, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(state >> 16);
    }
    var cases: std.ArrayList(Case) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    if (options.paths.items.len == 0) {
        try cases.append(init.gpa, .{ .name = "text", .payload = "Zstandard encode benchmark text with repeated structure and punctuation.\n" ** 512 });
        try cases.append(init.gpa, .{ .name = "json", .payload = numbered_json.items });
        try cases.append(init.gpa, .{ .name = "binary", .payload = binary });
        try cases.append(init.gpa, .{ .name = "wide_sequences", .payload = wide_sequences, .primary_double_fast_only = true });
    } else {
        for (options.paths.items, 0..) |path, index| {
            const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
            defer file.close(init.io);
            const stat = try file.stat(init.io);
            const read_len: usize = @intCast(@min(stat.size, options.path_limit));
            if (read_len == 0) continue;
            const payload = try init.gpa.alloc(u8, read_len);
            errdefer init.gpa.free(payload);
            var reader_buffer: [4096]u8 = undefined;
            var reader = file.reader(init.io, &reader_buffer);
            if (try reader.interface.readSliceShort(payload) != read_len) return error.InputTooSmall;
            const name = try caseNameForPath(init.gpa, path, index);
            errdefer init.gpa.free(name);
            try cases.append(init.gpa, .{ .name = name, .payload = payload, .owned = true });
        }
    }

    const policy = try vort.zstd.nativeEncodeLevelDiagnostics(options.level, .{});
    const candidates = [_]Candidate{
        .{ .name = "primary", .block_size = policy.primary_options.block_size_max },
        .{ .name = "adaptive_0", .block_size = policy.adaptive_block_sizes[0] },
        .{ .name = "adaptive_1", .block_size = policy.adaptive_block_sizes[1] },
    };

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.print("case,level,input_bytes,input_sha256,candidate,block_size,block_count,search_budget,stage,available_blocks,sequences,encoded_bytes,literals_bytes,sequence_bytes,single_positions,single_literal_empty_inserts,single_literal_replacements,single_literal_rejections,single_indexed_empty_inserts,single_indexed_replacements,single_indexed_rejections,single_indexed_min_cost_rejections,single_indexed_short_min_cost_rejections,single_rep0_empty_inserts,single_rep0_replacements,single_rep0_rejections,single_rep0_min_cost_rejections,single_indexed_searches,single_chain_nodes,single_prefix_rejections,single_matches,single_window_stops,single_chain_limit_stops,single_indexed_length_histogram,single_rep0_probes,single_rep0_prefix_rejections,single_rep0_prefix_mismatch_histogram,single_rep0_matches,single_rep0_length_histogram,iterations,rounds,warmup,median_ns,ns_per_block,checksum,{s}\n", .{benchmark_provenance.csv_columns});
    var selected_rows: usize = 0;
    for (cases.items) |case| {
        if (options.only_case) |wanted| if (!std.mem.eql(u8, wanted, case.name)) continue;
        for (candidates) |candidate| {
            if (options.only_candidate) |wanted| if (!std.mem.eql(u8, wanted, candidate.name)) continue;
            if (case.primary_double_fast_only and !std.mem.eql(u8, candidate.name, "primary")) continue;
            if (candidate.block_size >= case.payload.len and !std.mem.eql(u8, candidate.name, "primary")) continue;
            const search_budget = if (std.mem.eql(u8, candidate.name, "primary"))
                policy.primary_options.match_search_budget
            else
                policy.adaptive_match_search_budget;
            selected_rows += try benchmarkCandidate(init.io, init.gpa, &csv.writer, case, candidate, search_budget, options, provenance);
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
    provenance: benchmark_provenance.Info,
) !usize {
    var scratch: vort.zstd.NativeMatchStageScratch = .{};
    defer scratch.deinit(allocator);
    var selected_rows: usize = 0;

    if (!case.primary_double_fast_only and stageSelected(options.only_stage, "duplicate_index")) {
        const indexed_block_count = try prepareAllBlocks(allocator, case.payload, candidate.block_size, search_budget, &scratch);
        vort.zstd.benchmarkInvalidateNativeMatchStageScratch(&scratch);
        try writeMeasuredRow(io, allocator, csv, case, candidate, search_budget, options, provenance, .index, .{ .available_blocks = indexed_block_count, .encoded_len = 0, .sequence_count = 0, .literals_bytes = 0, .sequence_bytes = 0 }, &scratch);
        selected_rows += 1;
    }
    for (stages) |stage| {
        if (!stageSelected(options.only_stage, @tagName(stage))) continue;
        if (case.primary_double_fast_only and stage != .double_fast) continue;
        const probe = try evaluateAllBlocks(allocator, case.payload, candidate.block_size, search_budget, stage, &scratch);
        try writeMeasuredRow(io, allocator, csv, case, candidate, search_budget, options, provenance, .{ .candidate = stage }, probe, &scratch);
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
    provenance: benchmark_provenance.Info,
    stage: MeasuredStage,
    aggregate: Aggregate,
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
    const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
    try csv.print("{s},{d},{d},{s},{s},{d},{d},{d},{s},{d},{d},{d},{d},{d}", .{
        case.name,
        options.level,
        case.payload.len,
        &input_sha256,
        candidate.name,
        candidate.block_size,
        blockCount(case.payload.len, candidate.block_size),
        search_budget,
        stage.name(),
        aggregate.available_blocks,
        aggregate.sequence_count,
        aggregate.encoded_len,
        aggregate.literals_bytes,
        aggregate.sequence_bytes,
    });
    try csv.print(",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}", .{
        aggregate.single_beam_profile.positions,
        aggregate.single_beam_profile.literal_empty_inserts,
        aggregate.single_beam_profile.literal_replacements,
        aggregate.single_beam_profile.literal_rejections,
        aggregate.single_beam_profile.indexed_empty_inserts,
        aggregate.single_beam_profile.indexed_replacements,
        aggregate.single_beam_profile.indexed_rejections,
        aggregate.single_beam_profile.indexed_min_cost_rejections,
        aggregate.single_beam_profile.indexed_short_min_cost_rejections,
        aggregate.single_beam_profile.rep0_empty_inserts,
        aggregate.single_beam_profile.rep0_replacements,
        aggregate.single_beam_profile.rep0_rejections,
        aggregate.single_beam_profile.rep0_min_cost_rejections,
        aggregate.single_beam_profile.indexed_searches,
        aggregate.single_beam_profile.indexed_chain_nodes,
        aggregate.single_beam_profile.indexed_prefix_rejections,
        aggregate.single_beam_profile.indexed_matches,
        aggregate.single_beam_profile.indexed_window_stops,
        aggregate.single_beam_profile.indexed_chain_limit_stops,
    });
    try csv.writeByte(',');
    try writeHistogram(csv, &aggregate.single_beam_profile.indexed_length_histogram);
    try csv.print(",{d},{d},", .{
        aggregate.single_beam_profile.rep0_probes,
        aggregate.single_beam_profile.rep0_prefix_rejections,
    });
    try writeHistogram(csv, &aggregate.single_beam_profile.rep0_prefix_mismatch_histogram);
    try csv.print(",{d},", .{aggregate.single_beam_profile.rep0_matches});
    try writeHistogram(csv, &aggregate.single_beam_profile.rep0_length_histogram);
    try csv.print(",{d},{d},{d},{d},{d},{d}", .{
        options.iterations,
        options.rounds,
        options.warmup,
        median.ns,
        ns_per_block,
        median.mix +% warmup_mix,
    });
    try provenance.writeCsvFields(csv);
    try csv.writeByte('\n');
}

fn writeHistogram(writer: *std.Io.Writer, histogram: []const usize) !void {
    for (histogram, 0..) |count, index| {
        if (index != 0) try writer.writeByte(';');
        try writer.print("{d}", .{count});
    }
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
                const available = try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, block, search_budget, scratch);
                sample.ns +%= elapsed(start, io);
                sample.mix +%= @intFromBool(available);
                vort.zstd.benchmarkInvalidateNativeMatchStageScratch(scratch);
            },
            .candidate => |candidate_stage| {
                // Production shares this setup across mixed/multi/single. Keep
                // it outside each family timer and report it as its own row.
                _ = try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, block, search_budget, scratch);
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

fn prepareAllBlocks(allocator: std.mem.Allocator, payload: []const u8, block_size: usize, search_budget: usize, scratch: *vort.zstd.NativeMatchStageScratch) !usize {
    var mix: usize = 0;
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + block_size);
        mix +%= @intFromBool(try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, payload[offset..end], search_budget, scratch));
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
    var single_beam_profile: vort.zstd.NativeSingleBeamProfile = .{};
    var offset: usize = 0;
    while (offset < payload.len) {
        const end = @min(payload.len, offset + block_size);
        const block = payload[offset..end];
        _ = try vort.zstd.benchmarkPrepareNativeMatchStageScratch(allocator, block, search_budget, scratch);
        const result = try vort.zstd.benchmarkNativeMatchStage(allocator, block, end == payload.len, search_budget, stage, scratch);
        available_blocks += @intFromBool(result.available);
        encoded_len +%= result.encoded_len;
        sequence_count +%= result.sequence_count;
        literals_bytes +%= result.literals_bytes;
        sequence_bytes +%= result.sequence_bytes;
        if (stage == .rep_beam_single) {
            var block_profile: vort.zstd.NativeSingleBeamProfile = .{};
            const stats = try vort.zstd.benchmarkNativeSingleBeamProfile(allocator, block, scratch, &block_profile);
            if (stats.matches != result.sequence_count) return error.ProfileShapeMismatch;
            single_beam_profile.add(block_profile);
        }
        offset = end;
    }
    return .{ .available_blocks = available_blocks, .encoded_len = encoded_len, .sequence_count = sequence_count, .literals_bytes = literals_bytes, .sequence_bytes = sequence_bytes, .single_beam_profile = single_beam_profile };
}

fn blockCount(input_len: usize, block_size: usize) usize {
    if (input_len == 0) return 1;
    return (input_len + block_size - 1) / block_size;
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn caseNameForPath(allocator: std.mem.Allocator, path: []const u8, index: usize) ![]u8 {
    var out: std.Io.Writer.Allocating = .init(allocator);
    errdefer out.deinit();
    try out.writer.print("file{d}_", .{index});
    for (std.fs.path.basename(path)) |byte|
        try out.writer.writeByte(if (std.ascii.isAlphanumeric(byte)) byte else '_');
    return try out.toOwnedSlice();
}

fn parseOptions(allocator: std.mem.Allocator, args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    errdefer options.deinit(allocator);
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
        else if (std.mem.eql(u8, arg, "--limit"))
            options.path_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--path"))
            try options.paths.append(allocator, try allocator.dupe(u8, args.next() orelse return error.MissingCorpusPath))
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0 or options.rounds == 0 or options.path_limit == 0) return error.InvalidBlockPlan;
    return options;
}
