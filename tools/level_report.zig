const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    input: []const u8,
    owned: bool = false,
};

const LevelCase = struct {
    name: []const u8,
    level: vort.CompressionLevel,
};

const StrategyCase = struct {
    name: []const u8,
    strategy: vort.CompressionStrategy,
};

const builtins = [_]Case{
    .{ .name = "text", .input = "the quick brown fox jumps over the lazy dog\n" ** 64 },
    .{ .name = "structured", .input = "abcabcabcabc xyz xyz xyz lorem ipsum lorem ipsum\n" ** 64 },
    .{ .name = "repeated", .input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 64 },
};

const ReportRow = struct {
    case_name: []const u8,
    input_bytes: usize,
    level_name: []const u8,
    strategy_name: []const u8,
    parser_name: []const u8,
    block_selection_name: []const u8,
    window_len: usize,
    max_chain: usize,
    nice_len: usize,
    max_candidates: usize,
    lazy_min_gain: usize,
    min_match: usize,
    max_match: usize,
    min_savings_bits: usize,
    split_min: usize,
    split_max: usize,
    split_step: usize,
    stored_fast_path: bool,
    tokens: usize,
    literal_tokens: usize,
    match_tokens: usize,
    matched_bytes: usize,
    match_coverage_x10000: usize,
    avg_match_len_x100: usize,
    fixed_bits: usize,
    fixed_bits_per_byte_x100: usize,
    raw_best_bytes: usize,
    raw_best_ratio_x10000: usize,
    adaptive_bytes: usize,
    adaptive_ratio_x10000: usize,
    roundtrip_crc32: u32,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    var file_cases: std.ArrayList(Case) = .empty;
    defer {
        for (file_cases.items) |case| if (case.owned) init.gpa.free(case.input);
        file_cases.deinit(init.gpa);
    }
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        const input = try std.Io.Dir.cwd().readFileAlloc(init.io, arg, init.gpa, .limited(64 * 1024 * 1024));
        errdefer init.gpa.free(input);
        try file_cases.append(init.gpa, .{ .name = arg, .input = input, .owned = true });
    }

    const cases = if (file_cases.items.len == 0) builtins[0..] else file_cases.items;
    const levels = [_]LevelCase{
        .{ .name = "fastest", .level = .fastest },
        .{ .name = "fast", .level = .fast },
        .{ .name = "default", .level = .default },
        .{ .name = "best", .level = .best },
    };
    const strategies = [_]StrategyCase{
        .{ .name = "default", .strategy = .default },
        .{ .name = "filtered", .strategy = .filtered },
        .{ .name = "huffman_only", .strategy = .huffman_only },
        .{ .name = "rle", .strategy = .rle },
    };

    var output = std.Io.Writer.Allocating.init(init.gpa);
    defer output.deinit();
    const writer = &output.writer;
    try writeCsvHeader(writer);

    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);

    for (cases) |case| {
        for (levels) |level_case| {
            for (strategies) |strategy_case| {
                var options = vort.optionsForCompressionLevel(level_case.level);
                options.strategy = strategy_case.strategy;
                options = vort.normalizeCompressionOptionsForStrategy(options);
                const plan = switch (options.strategy) {
                    .default => switch (options.parser) {
                        .hash => try vort.hashGreedyLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                        .greedy => try vort.greedyLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                        .lazy => try vort.lazyGreedyLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                        .optimal => try vort.optimalLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                    },
                    .filtered => try vort.filteredLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                    .huffman_only => try vort.literalLz77PlanAlloc(init.gpa, case.input),
                    .rle => try vort.runLengthLz77PlanAlloc(init.gpa, case.input, options.lz77_options),
                };
                defer plan.deinit(init.gpa);

                const encoded = try vort.encodeRawBestAlloc(init.gpa, case.input, options);
                defer init.gpa.free(encoded);
                const decoded = try vort.decodeRawDeflateAlloc(init.gpa, encoded);
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, case.input, decoded)) return error.RoundTripMismatch;

                const adaptive = try vort.encodeRawBestAdaptiveSplitAlloc(init.gpa, case.input, options, options.split_options);
                defer init.gpa.free(adaptive);
                const adaptive_decoded = try vort.decodeRawDeflateAlloc(init.gpa, adaptive);
                defer init.gpa.free(adaptive_decoded);
                if (!std.mem.eql(u8, case.input, adaptive_decoded)) return error.RoundTripMismatch;

                const fixed_bits = vort.fixedLz77BitCost(plan.tokens);
                const avg_match_len_x100 = if (plan.stats.matches == 0) 0 else (plan.stats.matched_bytes * 100) / plan.stats.matches;
                const match_coverage_x10000 = scaledRatio(plan.stats.matched_bytes, case.input.len, 10_000);
                const fixed_bits_per_byte_x100 = scaledRatio(fixed_bits, case.input.len, 100);
                const raw_best_ratio_x10000 = scaledRatio(encoded.len, case.input.len, 10_000);
                const adaptive_ratio_x10000 = scaledRatio(adaptive.len, case.input.len, 10_000);

                const row: ReportRow = .{
                    .case_name = case.name,
                    .input_bytes = case.input.len,
                    .level_name = level_case.name,
                    .strategy_name = strategy_case.name,
                    .parser_name = @tagName(options.parser),
                    .block_selection_name = @tagName(options.block_selection),
                    .window_len = options.lz77_options.window_len,
                    .max_chain = options.lz77_options.max_chain,
                    .nice_len = options.lz77_options.nice_len,
                    .max_candidates = options.lz77_options.max_candidates,
                    .lazy_min_gain = options.lz77_options.lazy_min_gain,
                    .min_match = options.lz77_options.min_match,
                    .max_match = options.lz77_options.max_match,
                    .min_savings_bits = options.lz77_options.min_savings_bits,
                    .split_min = options.split_options.min_block_len,
                    .split_max = options.split_options.max_block_len,
                    .split_step = options.split_options.search_step,
                    .stored_fast_path = vort.usesStoredFastPath(case.input, options),
                    .tokens = plan.stats.tokenCount(),
                    .literal_tokens = plan.stats.literals,
                    .match_tokens = plan.stats.matches,
                    .matched_bytes = plan.stats.matched_bytes,
                    .match_coverage_x10000 = match_coverage_x10000,
                    .avg_match_len_x100 = avg_match_len_x100,
                    .fixed_bits = fixed_bits,
                    .fixed_bits_per_byte_x100 = fixed_bits_per_byte_x100,
                    .raw_best_bytes = encoded.len,
                    .raw_best_ratio_x10000 = raw_best_ratio_x10000,
                    .adaptive_bytes = adaptive.len,
                    .adaptive_ratio_x10000 = adaptive_ratio_x10000,
                    .roundtrip_crc32 = vort.crc32(decoded),
                };
                try rows.append(init.gpa, row);
                try writeCsvRow(writer, row);
            }
        }
    }
    const bytes = output.written();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(bytes);
    try stdout.flush();

    if (csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = bytes });
    }
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items);
}

fn writeCsvHeader(writer: *std.Io.Writer) !void {
    try writer.print("case,input_bytes,level,strategy,parser,block_selection,window_len,max_chain,nice_len,max_candidates,lazy_min_gain,min_match,max_match,min_savings_bits,split_min,split_max,split_step,stored_fast_path,tokens,literal_tokens,match_tokens,matched_bytes,match_coverage_x10000,avg_match_len_x100,fixed_bits,fixed_bits_per_byte_x100,raw_best_bytes,raw_best_ratio_x10000,adaptive_bytes,adaptive_ratio_x10000,roundtrip_crc32\n", .{});
}

fn writeCsvRow(writer: *std.Io.Writer, row: ReportRow) !void {
    try writer.print("{s},{d},{s},{s},{s},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        row.case_name,
        row.input_bytes,
        row.level_name,
        row.strategy_name,
        row.parser_name,
        row.block_selection_name,
        row.window_len,
        row.max_chain,
        row.nice_len,
        row.max_candidates,
        row.lazy_min_gain,
        row.min_match,
        row.max_match,
        row.min_savings_bits,
        row.split_min,
        row.split_max,
        row.split_step,
        row.stored_fast_path,
        row.tokens,
        row.literal_tokens,
        row.match_tokens,
        row.matched_bytes,
        row.match_coverage_x10000,
        row.avg_match_len_x100,
        row.fixed_bits,
        row.fixed_bits_per_byte_x100,
        row.raw_best_bytes,
        row.raw_best_ratio_x10000,
        row.adaptive_bytes,
        row.adaptive_ratio_x10000,
        row.roundtrip_crc32,
    });
}

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var out = std.Io.Writer.Allocating.init(init.gpa);
    defer out.deinit();
    const writer = &out.writer;

    try writer.print("# Vort compression level report\n\nRows: {d}\n\n", .{rows.len});
    try writer.print("| case | level | strategy | parser | raw bytes | raw ratio | adaptive bytes | adaptive ratio | match coverage | avg match len | fixed bits/byte | tokens | stored fast path |\n", .{});
    try writer.print("|---|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|\n", .{});
    for (rows) |row| {
        try writer.writeByte('|');
        try writeMarkdownCell(writer, row.case_name);
        try writer.print(" | {s} | {s} | {s} | {d} | ", .{ row.level_name, row.strategy_name, row.parser_name, row.raw_best_bytes });
        try writePercent(writer, row.raw_best_ratio_x10000);
        try writer.print(" | {d} | ", .{row.adaptive_bytes});
        try writePercent(writer, row.adaptive_ratio_x10000);
        try writer.print(" | ", .{});
        try writePercent(writer, row.match_coverage_x10000);
        try writer.print(" | ", .{});
        try writeFixed2(writer, row.avg_match_len_x100);
        try writer.print(" | ", .{});
        try writeFixed2(writer, row.fixed_bits_per_byte_x100);
        try writer.print(" | {d} | {} |\n", .{ row.tokens, row.stored_fast_path });
    }

    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = out.written() });
}

fn writeMarkdownCell(writer: *std.Io.Writer, value: []const u8) !void {
    for (value) |byte| switch (byte) {
        '|' => try writer.writeAll("\\|"),
        '\n', '\r' => try writer.writeByte(' '),
        else => try writer.writeByte(byte),
    };
}

fn writePercent(writer: *std.Io.Writer, scaled_x10000: usize) !void {
    try writeFixed2Value(writer, scaled_x10000 / 100, scaled_x10000 % 100);
    try writer.writeByte('%');
}

fn writeFixed2(writer: *std.Io.Writer, scaled_x100: usize) !void {
    try writeFixed2Value(writer, scaled_x100 / 100, scaled_x100 % 100);
}

fn writeFixed2Value(writer: *std.Io.Writer, whole: usize, frac: usize) !void {
    try writer.print("{d}.", .{whole});
    if (frac < 10) try writer.writeByte('0');
    try writer.print("{d}", .{frac});
}

fn scaledRatio(numerator: usize, denominator: usize, scale: usize) usize {
    if (denominator == 0) return 0;
    return (numerator * scale) / denominator;
}
