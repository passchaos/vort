const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const progress_input_chunks = [_]usize{ 1, 2, 3, 7, 16, 31, 64, 255 };
const progress_output_chunks = [_]usize{ 1, 2, 3, 7, 16, 63, 256 };

const Case = struct {
    name: []const u8,
    chunks: []const []const u8,
    expected: []const u8,
    qualities: []const u32,
    modes: []const u32 = &.{0},
    windows: []const u32 = &.{16},
    lgblock: u32 = 16,
    disable_literal_context_modeling: bool = false,
    npostfix: ?u32 = null,
    ndirect: ?u32 = null,
    min_compressed_blocks: ?usize = null,
    min_stored_blocks: usize = 0,
    retry_summary_with_caller_history: bool = false,
    min_literal_context_trees: usize = 0,
    min_distance_block_types: usize = 0,
    min_distance_context_trees: usize = 0,
    sweep_progress_chunks: bool = false,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var real_files: std.ArrayList([]const u8) = .empty;
    defer real_files.deinit(init.gpa);
    var real_limit: usize = 2 * 1024 * 1024;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--real-file")) {
            try real_files.append(init.gpa, args.next() orelse return error.MissingCorpusPath);
        } else if (std.mem.eql(u8, arg, "--real-limit")) {
            real_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
            if (real_limit == 0) return error.InvalidBlockPlan;
        } else return error.UnknownArgument;
    }

    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();

    const text = "The quick brown fox jumps over the lazy dog. " ** 64;
    const json = "{\"service\":\"vort\",\"status\":\"ok\",\"value\":12345}\n" ** 48;
    const first_pattern = "abcdefghijklmnopqrstuvwxyz012345" ** 64;
    const second_pattern = "zyxwvutsrqponmlkjihgfedcba543210" ** 64;
    const third_pattern = "012345abcdefghijklmnopqrstuvwxyz" ** 64;
    var binary: [4096]u8 = undefined;
    for (&binary, 0..) |*byte, index| byte.* = @intCast((index * 29) % 251);
    var random: [4096]u8 = undefined;
    var random_state: u32 = 0x9e37_79b9;
    for (&random) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 16);
    }
    const text_chunks = [_][]const u8{ text, text };
    const json_chunks = [_][]const u8{ json, json };
    const pattern_chunks = [_][]const u8{ first_pattern, second_pattern, third_pattern };
    const binary_chunks = [_][]const u8{ binary[0..2048], binary[2048..] };
    const random_chunks = [_][]const u8{ random[0..2048], random[2048..] };
    const unicode = "压缩算法需要在多语言文本、标点和上下文之间保持稳定。Καλημέρα κόσμε. مرحبا بالعالم. 🚀\n" ** 48;
    const unicode_chunks = [_][]const u8{ unicode[0 .. unicode.len / 3], unicode[unicode.len / 3 .. 2 * unicode.len / 3], unicode[2 * unicode.len / 3 ..] };
    const transition_chunks = [_][]const u8{ text, random[0..2048], text };
    const far_history = try init.gpa.alloc(u8, 96 * 1024);
    defer init.gpa.free(far_history);
    var far_state: u32 = 0x243f_6a88;
    for (far_history) |*byte| {
        far_state = far_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(far_state >> 16);
    }
    const far_history_chunks = [_][]const u8{ far_history[0 .. 48 * 1024], far_history[48 * 1024 ..], far_history[0 .. 32 * 1024] };
    const far_history_expected = try std.mem.concat(init.gpa, u8, &.{ far_history, far_history[0 .. 32 * 1024] });
    defer init.gpa.free(far_history_expected);
    const long_text = text ** 32;
    const long_text_chunks = [_][]const u8{ long_text[0 .. long_text.len / 3], long_text[long_text.len / 3 .. 2 * long_text.len / 3], long_text[2 * long_text.len / 3 ..] };
    const large_source = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/br.zig", init.gpa, .limited(2 * 1024 * 1024));
    defer init.gpa.free(large_source);
    const large_source_chunks = [_][]const u8{ large_source[0 .. large_source.len / 4], large_source[large_source.len / 4 .. large_source.len / 2], large_source[large_source.len / 2 .. 3 * large_source.len / 4], large_source[3 * large_source.len / 4 ..] };
    // Build a deterministic heterogeneous source from repository-owned files.
    // Unlike the specialized clustering fixtures below, this mixes unrelated
    // codec code, public API declarations, build graph, and prose in one input.
    // libbrotli quality 8 uses more than the old 64-entry distance type/tree
    // tier here, pinning that compatibility boundary without relying on an
    // optional neighboring checkout.
    const diverse_paths = [_][]const u8{
        "src/br.zig",
        "src/zstd.zig",
        "src/deflate.zig",
        "src/root.zig",
        "build.zig",
        "docs/roadmap.md",
        "README.md",
        "src/lz77.zig",
    };
    var diverse_source_builder: std.ArrayList(u8) = .empty;
    defer diverse_source_builder.deinit(init.gpa);
    var diverse_parts: [diverse_paths.len][]u8 = undefined;
    var diverse_part_count: usize = 0;
    defer for (diverse_parts[0..diverse_part_count]) |part| init.gpa.free(part);
    for (diverse_paths) |path| {
        diverse_parts[diverse_part_count] = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024));
        diverse_part_count += 1;
    }
    // Repeat differently ordered passes until the corpus reaches a stable
    // minimum size. This keeps the distance-clustering boundary from drifting
    // when comments or tests shrink, while avoiding needless growth as the
    // repository expands.
    const diverse_min_len = 15 * 1024 * 1024;
    var pass: usize = 0;
    while (diverse_source_builder.items.len < diverse_min_len) : (pass += 1) {
        for (0..diverse_part_count) |i| {
            const index = switch (pass % 3) {
                0 => i,
                1 => diverse_part_count - 1 - i,
                else => (i * 3) % diverse_part_count,
            };
            try diverse_source_builder.appendSlice(init.gpa, diverse_parts[index]);
            try diverse_source_builder.appendSlice(init.gpa, "\n/* VORT BROTLI CORPUS BOUNDARY */\n");
        }
    }
    const diverse_source = diverse_source_builder.items;
    // A single large source meta-block makes libbrotli's higher-quality
    // clustering exercise more than 32 literal trees. Keep this separate from
    // the flushed case above: flush boundaries intentionally simplify each
    // header.
    const dictionary_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/br/dictionary.bin", init.gpa, .limited(128 * 1024));
    defer init.gpa.free(dictionary_bytes);
    const clustered_source = try init.gpa.alloc(u8, 1024 * 1024);
    defer init.gpa.free(clustered_source);
    for (clustered_source, 0..) |*byte, i| {
        const segment = i / 1024;
        const base = (segment * 3571) % dictionary_bytes.len;
        byte.* = dictionary_bytes[(base + i % 1024) % dictionary_bytes.len];
    }
    const clustered_source_chunks = [_][]const u8{clustered_source};
    const mixed_clustered_source = try init.gpa.alloc(u8, 1024 * 1024);
    defer init.gpa.free(mixed_clustered_source);
    const clustered_tokens = [_][]const u8{
        "const function allocator return error while if else switch struct union enum defer try catch payload input output\n",
        "{\"service\":\"vort\",\"codec\":\"brotli\",\"status\":\"ok\",\"value\":123456}\n",
        "The quick brown fox jumps over the lazy dog. Compression context model and distance tree.\n",
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-=+[]{}();:,.<>/\\\n",
    };
    for (mixed_clustered_source, 0..) |*byte, i| {
        const segment = i / 8192;
        const token = clustered_tokens[segment % clustered_tokens.len];
        byte.* = if (i % 256 < 192)
            token[(i + segment) % token.len]
        else
            dictionary_bytes[(i * 17 + segment) % dictionary_bytes.len];
    }
    const mixed_clustered_source_chunks = [_][]const u8{mixed_clustered_source};
    const distance_clustered_source = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/deflate.zig", init.gpa, .limited(2 * 1024 * 1024));
    defer init.gpa.free(distance_clustered_source);
    const distance_clustered_chunks = [_][]const u8{distance_clustered_source};
    // Local upstream/competitor checkouts are optional. When the neighboring
    // Godot checkout is present, its large ufbx source provides a stable real-
    // world header with 247 literal trees and 43 distance types/trees.
    const external_cluster_source_path = "../../Work/godot/thirdparty/ufbx/ufbx.c";
    const external_cluster_source = std.Io.Dir.cwd().readFileAlloc(init.io, external_cluster_source_path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    defer if (external_cluster_source) |source| init.gpa.free(source);
    // This real Graphviz DOT fixture makes libbrotli quality 11 exceed the old
    // 32-entry literal block-type tier (37 types in the first 1.5 MiB). Keep
    // it optional like the neighboring Godot corpus so ordinary checkouts do
    // not depend on unrelated repositories.
    const external_literal_types_path = "../../Work/graphviz/tests/2475_1.dot";
    const external_literal_types_file = std.Io.Dir.cwd().readFileAlloc(init.io, external_literal_types_path, init.gpa, .limited(16 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    defer if (external_literal_types_file) |source| init.gpa.free(source);
    const tiny_prefix = "alpha alpha alpha alpha" ++
        "{\"kind\":\"tiny\",\"value\":1}\n" ++
        "beta beta beta beta";
    const tiny_suffix = "gamma gamma gamma gamma" ++
        "delta delta delta delta";
    const tiny_expected = try std.mem.concat(init.gpa, u8, &.{ tiny_prefix, random[0..73], tiny_suffix });
    defer init.gpa.free(tiny_expected);
    const tiny_chunks = [_][]const u8{
        tiny_prefix[0..23],
        tiny_prefix[23..],
        random[0..73],
        tiny_suffix[0..23],
        tiny_suffix[23..],
    };
    const all_qualities = [_]u32{ 0, 1, 3, 4, 5, 6, 9, 11 };
    const context_qualities = [_]u32{ 4, 5, 9, 11 };
    const compact_qualities = [_]u32{ 5, 9 };
    const quality_eleven = [_]u32{11};
    const clustered_qualities = [_]u32{ 5, 8 };
    const mixed_clustered_qualities = [_]u32{5};
    const distance_clustered_qualities = [_]u32{8};
    const all_modes = [_]u32{ 0, 1, 2 };
    const window_sweep = [_]u32{ 10, 16, 18, 20, 22, 24 };
    const cases = [_]Case{
        .{ .name = "repeated-text", .chunks = &text_chunks, .expected = text ++ text, .qualities = &all_qualities },
        .{ .name = "structured-json", .chunks = &json_chunks, .expected = json ++ json, .qualities = &all_qualities },
        .{ .name = "changed-pattern-three-block", .chunks = &pattern_chunks, .expected = first_pattern ++ second_pattern ++ third_pattern, .qualities = &all_qualities },
        .{ .name = "binary-cycle", .chunks = &binary_chunks, .expected = &binary, .qualities = &all_qualities },
        .{ .name = "random-stored", .chunks = &random_chunks, .expected = &random, .qualities = &all_qualities, .min_compressed_blocks = 0, .min_stored_blocks = 2 },
        .{ .name = "unicode-context", .chunks = &unicode_chunks, .expected = unicode, .qualities = &context_qualities, .modes = &all_modes },
        .{ .name = "json-no-context", .chunks = &json_chunks, .expected = json ++ json, .qualities = &context_qualities, .disable_literal_context_modeling = true },
        .{ .name = "window-sweep", .chunks = &pattern_chunks, .expected = first_pattern ++ second_pattern ++ third_pattern, .qualities = &compact_qualities, .windows = &window_sweep },
        .{ .name = "history-wrap", .chunks = &long_text_chunks, .expected = long_text, .qualities = &compact_qualities },
        .{ .name = "large-source", .chunks = &large_source_chunks, .expected = large_source, .qualities = &compact_qualities, .windows = &.{20}, .lgblock = 18 },
        .{ .name = "large-source-clustered", .chunks = &clustered_source_chunks, .expected = clustered_source, .qualities = &clustered_qualities, .windows = &.{20}, .lgblock = 16, .min_compressed_blocks = 1, .retry_summary_with_caller_history = true, .min_literal_context_trees = 39 },
        .{ .name = "large-source-mixed-clustered", .chunks = &mixed_clustered_source_chunks, .expected = mixed_clustered_source, .qualities = &mixed_clustered_qualities, .windows = &.{20}, .lgblock = 16, .min_compressed_blocks = 1, .retry_summary_with_caller_history = true, .min_literal_context_trees = 128 },
        .{ .name = "large-source-distance-clustered", .chunks = &distance_clustered_chunks, .expected = distance_clustered_source, .qualities = &distance_clustered_qualities, .windows = &.{20}, .lgblock = 16, .min_compressed_blocks = 1, .retry_summary_with_caller_history = true, .min_distance_block_types = 33, .min_distance_context_trees = 33 },
        .{ .name = "large-source-quality-eleven", .chunks = &large_source_chunks, .expected = large_source, .qualities = &quality_eleven, .windows = &.{ 18, 20, 22, 24 }, .lgblock = 18, .retry_summary_with_caller_history = true },
        .{ .name = "far-history", .chunks = &far_history_chunks, .expected = far_history_expected, .qualities = &compact_qualities, .windows = &.{17}, .min_compressed_blocks = 1, .min_stored_blocks = 2 },
        .{ .name = "compressed-stored-compressed", .chunks = &transition_chunks, .expected = text ++ random[0..2048] ++ text, .qualities = &context_qualities, .min_compressed_blocks = 2, .min_stored_blocks = 1 },
        .{ .name = "tiny-flushes", .chunks = &tiny_chunks, .expected = tiny_expected, .qualities = &context_qualities, .lgblock = 14, .min_compressed_blocks = 0, .sweep_progress_chunks = true },
        .{ .name = "postfix-distances", .chunks = &pattern_chunks, .expected = first_pattern ++ second_pattern ++ third_pattern, .qualities = &context_qualities, .npostfix = 1, .ndirect = 2 },
    };

    var cases_run: usize = 0;
    var one_shot_cases: usize = 0;
    var large_window_decode_cases: usize = 0;
    var caller_history_summaries: usize = 0;
    var progress_matrix_runs: usize = 0;
    var progress_matrix_streams: usize = 0;
    var wide_literal_type_cases: usize = 0;
    var maximum_literal_type_cases: usize = 0;
    var maximum_command_type_cases: usize = 0;
    var extended_header_cases: usize = 0;
    var operation_schedule_cases: usize = 0;
    var allocating_summary_history_cases: usize = 0;
    var high_tree_truncation_cases: usize = 0;
    for (cases) |case| {
        for (case.qualities) |quality| {
            for (case.modes) |mode| {
                for (case.windows) |lgwin| {
                    const encoded = try reference.encodeFlushedChunksWithOptionsAlloc(
                        init.gpa,
                        case.chunks,
                        .{
                            .quality = quality,
                            .lgwin = lgwin,
                            .lgblock = case.lgblock,
                            .mode = mode,
                            .disable_literal_context_modeling = case.disable_literal_context_modeling,
                            .npostfix = case.npostfix,
                            .ndirect = case.ndirect,
                        },
                    );
                    defer init.gpa.free(encoded);
                    decodeByteProgressive(init.gpa, encoded, case.expected, lgwin) catch |err| {
                        std.debug.print("{s} quality={d} mode={d} lgwin={d}: decode {s} encoded={d} expected={d}\n", .{ case.name, quality, mode, lgwin, @errorName(err), encoded.len, case.expected.len });
                        return err;
                    };
                    if (case.sweep_progress_chunks) {
                        try decodeProgressChunkMatrix(init.gpa, encoded, case.expected, lgwin);
                        progress_matrix_runs += progressChunkMatrixCaseCount();
                        progress_matrix_streams += 1;
                    }
                    var used_caller_history = false;
                    const summary = vort.brSummarizeStream(encoded) catch |err| blk: {
                        if (case.retry_summary_with_caller_history and err == error.UnsupportedBrotliFeature) {
                            const history_len = @min(case.expected.len, (@as(usize, 1) << @intCast(lgwin)) - 16);
                            const history = try init.gpa.alloc(u8, history_len);
                            defer init.gpa.free(history);
                            used_caller_history = true;
                            caller_history_summaries += 1;
                            break :blk vort.brSummarizeStreamWithHistory(encoded, history) catch |history_err| {
                                std.debug.print("{s} quality={d} mode={d} lgwin={d}: caller-history summary {s}\n", .{ case.name, quality, mode, lgwin, @errorName(history_err) });
                                return history_err;
                            };
                        }
                        std.debug.print("{s} quality={d} mode={d} lgwin={d}: summary {s} encoded={d} expected={d}\n", .{ case.name, quality, mode, lgwin, @errorName(err), encoded.len, case.expected.len });
                        return err;
                    };
                    if (summary.decoded_bytes != case.expected.len) return error.SizeMismatch;
                    if (std.mem.eql(u8, case.name, "large-source-clustered") and quality == 8) {
                        var counting = std.testing.FailingAllocator.init(init.gpa, .{});
                        const allocated_summary = try vort.brSummarizeStreamAlloc(counting.allocator(), encoded);
                        if (allocated_summary.decoded_bytes != case.expected.len or counting.allocations != 1 or counting.deallocations != 1)
                            return error.ReferenceDecodeFailed;
                        var failing = std.testing.FailingAllocator.init(init.gpa, .{ .fail_index = 0 });
                        if (vort.brSummarizeStreamAlloc(failing.allocator(), encoded)) |_|
                            return error.ReferenceDecodeFailed
                        else |err| if (err != error.OutOfMemory) return err;
                        allocating_summary_history_cases += 1;
                        const truncated_output = try init.gpa.alloc(u8, case.expected.len);
                        defer init.gpa.free(truncated_output);
                        const truncation_count = @min(encoded.len, 64);
                        for (1..truncation_count + 1) |drop| {
                            if (vort.brDecodeStreamInto(encoded[0 .. encoded.len - drop], truncated_output)) |_|
                                return error.ReferenceDecodeFailed
                            else |_| {}
                            high_tree_truncation_cases += 1;
                        }
                    }
                    if (used_caller_history) {
                        const decoded = try vort.brDecodeStreamAlloc(init.gpa, encoded);
                        defer init.gpa.free(decoded);
                        if (!std.mem.eql(u8, decoded, case.expected)) return error.SizeMismatch;
                        const exact_output = try init.gpa.alloc(u8, case.expected.len);
                        defer init.gpa.free(exact_output);
                        const written = try vort.brDecodeStreamIntoExactSize(encoded, exact_output, case.expected.len);
                        if (written != case.expected.len or !std.mem.eql(u8, exact_output, case.expected)) return error.SizeMismatch;
                    }
                    const payload_blocks = summary.compressed_meta_block_count + summary.uncompressed_meta_block_count;
                    try validateClusterCoverage(case, summary);
                    const min_compressed = case.min_compressed_blocks orelse case.chunks.len;
                    if (payload_blocks < case.chunks.len or
                        summary.compressed_meta_block_count < min_compressed or
                        summary.uncompressed_meta_block_count < case.min_stored_blocks)
                    {
                        std.debug.print(
                            "{s} quality={d} mode={d} lgwin={d}: expected payload>={d} compressed>={d} stored>={d}, got compressed={d} stored={d} empty={d}\n",
                            .{ case.name, quality, mode, lgwin, case.chunks.len, min_compressed, case.min_stored_blocks, summary.compressed_meta_block_count, summary.uncompressed_meta_block_count, summary.empty_meta_block_count },
                        );
                        return error.ReferenceEncodeFailed;
                    }
                    cases_run += 1;
                }
            }
        }
    }
    const one_shot_cases_spec = [_]struct {
        payload: []const u8,
        quality: c_int,
        mode: c_int,
        lgwin: c_int,
    }{
        .{ .payload = text, .quality = 0, .mode = 0, .lgwin = 10 },
        .{ .payload = json, .quality = 1, .mode = 1, .lgwin = 16 },
        .{ .payload = unicode, .quality = 4, .mode = 1, .lgwin = 18 },
        .{ .payload = first_pattern ++ second_pattern, .quality = 5, .mode = 0, .lgwin = 20 },
        .{ .payload = &binary, .quality = 6, .mode = 2, .lgwin = 22 },
        .{ .payload = long_text, .quality = 9, .mode = 1, .lgwin = 24 },
        // Quality 11 is already exercised across several windows by the main
        // one-shot/reference benchmark. Keep this boundary matrix focused on
        // representative wire families so it remains suitable for CI.
        .{ .payload = mixed_clustered_source[0 .. 64 * 1024], .quality = 11, .mode = 0, .lgwin = 20 },
    };
    for (one_shot_cases_spec) |case| {
        const encoded = try reference.encodeWithOptionsAlloc(init.gpa, case.payload, .{
            .quality = case.quality,
            .mode = case.mode,
            .lgwin = case.lgwin,
        });
        defer init.gpa.free(encoded);
        const window_bits: u32 = @intCast((try vort.brSummarizeStreamAlloc(init.gpa, encoded)).window_bits);
        try decodeProgressChunkMatrix(init.gpa, encoded, case.payload, window_bits);
        progress_matrix_runs += progressChunkMatrixCaseCount();
        progress_matrix_streams += 1;
        one_shot_cases += 1;
    }

    // Large Window Brotli occupies an RFC-reserved stream-header code and is
    // intentionally rejected by Vort's default APIs. Exercise every window
    // supported by libbrotli's 32-bit implementation through the explicit
    // opt-in, including both buffered and true byte-progressive decoders.
    const large_window_payload = "large window brotli compatibility payload 0123456789\n" ** 64;
    const large_window_options = vort.BrotliDecodeOptions{ .allow_large_window = true };
    for (25..31) |lgwin_usize| {
        const lgwin: c_int = @intCast(lgwin_usize);
        const encoded = try reference.encodeWithOptionsAlloc(init.gpa, large_window_payload, .{
            .quality = 5,
            .mode = 0,
            .lgwin = lgwin,
        });
        defer init.gpa.free(encoded);

        if (vort.brSummarizeStream(encoded)) |_| return error.ReferenceDecodeFailed else |err| if (err != error.CorruptFrame) return err;
        if (vort.brDecodeStreamAlloc(init.gpa, encoded)) |decoded| {
            init.gpa.free(decoded);
            return error.ReferenceDecodeFailed;
        } else |err| if (err != error.CorruptFrame) return err;
        var strict_buffered = vort.BrotliIncrementalStreamDecoder.initExactCompressedSize(init.gpa, .{
            .expected_output_len = large_window_payload.len,
        }, encoded.len);
        defer strict_buffered.deinit();
        if (strict_buffered.step(encoded, &.{})) |_| return error.ReferenceDecodeFailed else |err| if (err != error.CorruptFrame) return err;
        const strict_history = try init.gpa.alloc(u8, large_window_payload.len);
        defer init.gpa.free(strict_history);
        var strict_progressive = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(strict_history, .{
            .expected_output_len = large_window_payload.len,
        });
        if (strict_progressive.step(encoded, &.{})) |_| return error.ReferenceDecodeFailed else |err| if (err != error.CorruptFrame) return err;

        const summary = try vort.brSummarizeStreamAllocWithOptions(init.gpa, encoded, large_window_options);
        if (summary.window_bits != lgwin_usize or !summary.large_window or summary.decoded_bytes != large_window_payload.len)
            return error.SizeMismatch;
        const decoded = try vort.brDecodeStreamAllocWithOptions(init.gpa, encoded, large_window_options);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, decoded, large_window_payload)) return error.SizeMismatch;

        const split_a = @min(encoded.len, 1);
        const split_b = @min(encoded.len, 17);
        const chunks = [_][]const u8{ encoded[0..split_a], encoded[split_a..split_b], encoded[split_b..] };
        const joined = try init.gpa.alloc(u8, encoded.len);
        defer init.gpa.free(joined);
        const chunked = try vort.brDecodeStreamChunksAllocExactSizeWithOptions(
            init.gpa,
            &chunks,
            joined,
            large_window_payload.len,
            large_window_options,
        );
        defer init.gpa.free(chunked);
        if (!std.mem.eql(u8, chunked, large_window_payload)) return error.SizeMismatch;

        try decodeLargeWindowBuffered(init.gpa, encoded, large_window_payload);
        try decodeLargeWindowProgressive(init.gpa, encoded, large_window_payload, @intCast(lgwin_usize));
        try reference.decodeLargeWindow(encoded, decoded);
        large_window_decode_cases += 1;
    }

    // Prove that support is not merely a header rewrite: this valid stream
    // copies bytes from 16 MiB back, crossing the RFC 7932 window ceiling while
    // using a regular distance code with 23 extra bits.
    const far_prefix_len = @as(usize, 1) << 24;
    const far_copy_len = 64;
    const far_prefix = try init.gpa.alloc(u8, far_prefix_len);
    defer init.gpa.free(far_prefix);
    for (far_prefix, 0..) |*byte, index| byte.* = @intCast(index & 3);
    const far_encoded = vort.br.IncrementalTestSupport.encodeLargeWindowFarCopy(init.gpa, far_prefix, far_copy_len, 25) catch |err| {
        std.debug.print("large-window far fixture encode: {s}\n", .{@errorName(err)});
        return err;
    };
    defer init.gpa.free(far_encoded);
    if (vort.brDecodeStreamAlloc(init.gpa, far_encoded)) |decoded| {
        init.gpa.free(decoded);
        return error.ReferenceDecodeFailed;
    } else |err| if (err != error.CorruptFrame) return err;
    const far_expected = try init.gpa.alloc(u8, far_prefix_len + far_copy_len);
    defer init.gpa.free(far_expected);
    @memcpy(far_expected[0..far_prefix_len], far_prefix);
    @memcpy(far_expected[far_prefix_len..], far_prefix[0..far_copy_len]);
    const far_summary = vort.brSummarizeStreamAllocWithOptions(init.gpa, far_encoded, large_window_options) catch |err| {
        std.debug.print("large-window far fixture summary: {s} encoded={d}\n", .{ @errorName(err), far_encoded.len });
        return err;
    };
    if (!far_summary.large_window or
        far_summary.window_bits != 25 or
        far_summary.decoded_bytes != far_expected.len or
        far_summary.max_lz77_distance != far_prefix_len) return error.ReferenceDecodeFailed;
    const far_decoded = vort.brDecodeStreamAllocWithOptions(init.gpa, far_encoded, large_window_options) catch |err| {
        std.debug.print("large-window far fixture Vort decode: {s} encoded={d}\n", .{ @errorName(err), far_encoded.len });
        return err;
    };
    defer init.gpa.free(far_decoded);
    if (!std.mem.eql(u8, far_decoded, far_expected)) return error.SizeMismatch;
    reference.decodeLargeWindow(far_encoded, far_expected) catch |err| {
        std.debug.print("large-window far fixture libbrotli decode: {s} encoded={d}\n", .{ @errorName(err), far_encoded.len });
        return err;
    };
    large_window_decode_cases += 1;
    const diverse_encoded = try reference.encodeWithOptionsAlloc(init.gpa, diverse_source, .{
        .quality = 8,
        .mode = 0,
        .lgwin = 22,
    });
    defer init.gpa.free(diverse_encoded);
    const diverse_summary = try vort.brSummarizeStreamAlloc(init.gpa, diverse_encoded);
    if (diverse_summary.max_distance_block_types <= 64 or
        diverse_summary.max_distance_context_trees <= 64)
    {
        return error.ReferenceEncodeFailed;
    }
    try decodeProgressChunks(init.gpa, diverse_encoded, diverse_source, 22, 17, 31);
    one_shot_cases += 1;
    if (caller_history_summaries != 8) return error.ReferenceEncodeFailed;

    if (external_cluster_source) |source| {
        const chunks = [_][]const u8{source};
        const external_case: Case = .{
            .name = "external-large-source-clustered",
            .chunks = &chunks,
            .expected = source,
            .qualities = &.{8},
            .windows = &.{20},
            .lgblock = 16,
            .min_compressed_blocks = 1,
            .min_literal_context_trees = 247,
            .min_distance_block_types = 43,
            .min_distance_context_trees = 43,
        };
        const encoded = try reference.encodeFlushedChunksWithOptionsAlloc(init.gpa, external_case.chunks, .{
            .quality = 8,
            .lgwin = 20,
            .lgblock = 16,
        });
        defer init.gpa.free(encoded);
        try decodeByteProgressive(init.gpa, encoded, source, 20);
        const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
        try validateClusterCoverage(external_case, summary);
        if (summary.compressed_meta_block_count < 1) return error.ReferenceEncodeFailed;
        cases_run += 1;
    }

    if (external_literal_types_file) |complete_source| {
        if (complete_source.len < 1536 * 1024) return error.ReferenceEncodeFailed;
        const source = complete_source[0 .. 1536 * 1024];
        const encoded = try reference.encodeWithOptionsAlloc(init.gpa, source, .{
            .quality = 11,
            .mode = 0,
            .lgwin = 22,
        });
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
        if (summary.max_literal_block_types <= 32 or summary.max_command_block_types > 32)
            return error.ReferenceEncodeFailed;
        try decodeProgressChunks(init.gpa, encoded, source, 22, 17, 31);
        wide_literal_type_cases += 1;
        cases_run += 1;
    }

    const maximum_literal_types = try vort.br.IncrementalTestSupport.encodeMaximumLiteralBlockTypes(init.gpa);
    defer init.gpa.free(maximum_literal_types);
    const maximum_literal_expected = ("a" ** 255) ++ "q";
    var reference_output: [maximum_literal_expected.len]u8 = undefined;
    try reference.decode(maximum_literal_types, &reference_output);
    if (!std.mem.eql(u8, maximum_literal_expected, &reference_output)) return error.ReferenceDecodeFailed;
    const maximum_literal_summary = try vort.brSummarizeStream(maximum_literal_types);
    if (maximum_literal_summary.max_literal_block_types != 256 or
        maximum_literal_summary.max_literal_context_trees != 2)
        return error.ReferenceDecodeFailed;
    try decodeProgressChunkMatrix(init.gpa, maximum_literal_types, maximum_literal_expected, 16);
    progress_matrix_runs += progressChunkMatrixCaseCount();
    progress_matrix_streams += 1;
    maximum_literal_type_cases += 1;

    const maximum_command_types = try vort.br.IncrementalTestSupport.encodeMaximumCommandBlockTypes(init.gpa);
    defer init.gpa.free(maximum_command_types);
    const maximum_command_expected = ("aaa" ** 255) ++ "bb";
    const maximum_command_reference_output = try init.gpa.alloc(u8, maximum_command_expected.len);
    defer init.gpa.free(maximum_command_reference_output);
    try reference.decode(maximum_command_types, maximum_command_reference_output);
    if (!std.mem.eql(u8, maximum_command_expected, maximum_command_reference_output)) return error.ReferenceDecodeFailed;
    const maximum_command_summary = try vort.brSummarizeStream(maximum_command_types);
    if (maximum_command_summary.max_command_block_types != 256) return error.ReferenceDecodeFailed;
    try decodeProgressChunkMatrix(init.gpa, maximum_command_types, maximum_command_expected, 16);
    progress_matrix_runs += progressChunkMatrixCaseCount();
    progress_matrix_streams += 1;
    maximum_command_type_cases += 1;

    const large_header = try vort.br.IncrementalTestSupport.encodeLargeCompressedHeader(init.gpa);
    defer init.gpa.free(large_header);
    if (large_header.len <= vort.brotliDefaultIncrementalCompressedHeaderBytes) return error.ReferenceEncodeFailed;
    var large_header_reference_output: [1]u8 = undefined;
    try reference.decode(large_header, &large_header_reference_output);
    if (!std.mem.eql(u8, "x", &large_header_reference_output)) return error.ReferenceDecodeFailed;
    const large_header_scratch = try init.gpa.alloc(u8, large_header.len);
    defer init.gpa.free(large_header_scratch);
    try decodeProgressChunksWithHeaderScratch(init.gpa, large_header, "x", 16, 257, 1, large_header_scratch);
    progress_matrix_runs += 1;
    progress_matrix_streams += 1;
    extended_header_cases += 1;

    const metadata = "vort/libbrotli metadata boundary";
    const metadata_operations = [_]libbrotli.Runtime.StreamingOperation{
        .{ .flush = text },
        .{ .metadata = metadata },
        .{ .flush = json },
    };
    for (context_qualities) |quality| {
        const encoded = try reference.encodeOperationsAlloc(init.gpa, &metadata_operations, .{
            .quality = quality,
            .lgwin = 16,
            .lgblock = 16,
            .mode = 1,
        });
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStream(encoded);
        if (summary.compressed_meta_block_count < 2 or summary.metadata_meta_block_count < 1)
            return error.ReferenceEncodeFailed;
        try decodeByteProgressiveWithMetadata(init.gpa, encoded, text ++ json, metadata, 16);
        try decodeMetadataProgressChunkMatrix(init.gpa, encoded, text ++ json, metadata, 16);
        progress_matrix_runs += progressChunkMatrixCaseCount();
        progress_matrix_streams += 1;
        cases_run += 1;
    }

    const process_finish_operations = [_]libbrotli.Runtime.StreamingOperation{
        .{ .process = text[0 .. text.len / 2] },
        .{ .process = &.{} },
        .{ .process = text[text.len / 2 ..] },
        .{ .finish = json },
    };
    const empty_flush_operations = [_]libbrotli.Runtime.StreamingOperation{
        .{ .process = tiny_prefix },
        .{ .flush = &.{} },
        .{ .flush = &.{} },
        .{ .process = random[0..73] },
        .{ .flush = &.{} },
        .{ .finish = tiny_suffix },
    };
    const OperationScheduleCase = struct {
        name: []const u8,
        operations: []const libbrotli.Runtime.StreamingOperation,
        expected: []const u8,
    };
    const operation_schedules = [_]OperationScheduleCase{
        .{ .name = "process-finish-input", .operations = &process_finish_operations, .expected = text ++ json },
        .{ .name = "empty-flush-process-finish", .operations = &empty_flush_operations, .expected = tiny_expected },
    };
    for (operation_schedules) |schedule| {
        for ([_]u32{ 0, 5, 11 }) |quality| {
            const encoded = try reference.encodeOperationsAlloc(init.gpa, schedule.operations, .{
                .quality = quality,
                .lgwin = 16,
                .lgblock = 16,
            });
            defer init.gpa.free(encoded);
            const schedule_reference_output = try init.gpa.alloc(u8, schedule.expected.len);
            defer init.gpa.free(schedule_reference_output);
            try reference.decode(encoded, schedule_reference_output);
            if (!std.mem.eql(u8, schedule.expected, schedule_reference_output)) return error.ReferenceDecodeFailed;
            decodeProgressChunkMatrix(init.gpa, encoded, schedule.expected, 16) catch |err| {
                std.debug.print("{s} quality={d}: operation schedule decode {s} encoded={d} expected={d}\n", .{ schedule.name, quality, @errorName(err), encoded.len, schedule.expected.len });
                return err;
            };
            progress_matrix_runs += progressChunkMatrixCaseCount();
            progress_matrix_streams += 1;
            operation_schedule_cases += 1;
        }
    }

    const process_metadata_finish_operations = [_]libbrotli.Runtime.StreamingOperation{
        .{ .process = text },
        .{ .metadata = metadata },
        .{ .process = json },
        .{ .finish = tiny_suffix },
    };
    const process_metadata_expected = text ++ json ++ tiny_suffix;
    for ([_]u32{ 5, 11 }) |quality| {
        const encoded = try reference.encodeOperationsAlloc(init.gpa, &process_metadata_finish_operations, .{
            .quality = quality,
            .lgwin = 16,
            .lgblock = 16,
            .mode = 1,
        });
        defer init.gpa.free(encoded);
        try decodeMetadataProgressChunkMatrix(init.gpa, encoded, process_metadata_expected, metadata, 16);
        progress_matrix_runs += progressChunkMatrixCaseCount();
        progress_matrix_streams += 1;
        operation_schedule_cases += 1;
    }

    const process_after_finish = [_]libbrotli.Runtime.StreamingOperation{
        .{ .finish = text },
        .{ .process = json },
    };
    const duplicate_finish = [_]libbrotli.Runtime.StreamingOperation{
        .{ .finish = text },
        .{ .finish = &.{} },
    };
    for ([_][]const libbrotli.Runtime.StreamingOperation{ &process_after_finish, &duplicate_finish }) |invalid_operations| {
        try std.testing.expectError(
            error.ReferenceEncodeFailed,
            reference.encodeOperationsAlloc(init.gpa, invalid_operations, .{
                .quality = 5,
                .lgwin = 16,
                .lgblock = 16,
            }),
        );
    }
    // Sweep one-shot libbrotli output across the complete quality/mode range,
    // representative windows, payload sizes, and entropy shapes. The existing
    // cases above target deep structural boundaries; this broader matrix makes
    // sure ordinary encoder decisions between them remain accepted too.
    var broad_generated_cases: usize = 0;
    var broad_progressive_cases: usize = 0;
    const broad_sizes = [_]usize{ 1, 7, 31, 257, 4096, 16 * 1024, 64 * 1024 };
    const broad_windows = [_]c_int{ 10, 12, 16, 18, 20, 22, 24 };
    for (0..4) |shape| {
        for (broad_sizes) |size| {
            const payload = try init.gpa.alloc(u8, size);
            defer init.gpa.free(payload);
            var broad_state: u32 = @truncate(0x9e37_79b9 +% shape *% 0x0100_0193 +% size);
            for (payload, 0..) |*byte, index| {
                broad_state = broad_state *% 1_664_525 +% 1_013_904_223;
                byte.* = switch (shape) {
                    0 => @truncate(broad_state >> 16),
                    1 => @truncate((index / 7 + shape) & 31),
                    2 => "Brotli structured compatibility sweep 0123456789.\n"[(index + size) % 47],
                    else => if (index % 64 < 48) @truncate(index * 29) else @truncate(broad_state >> 24),
                };
            }
            for (0..12) |quality| {
                for (0..3) |mode| {
                    for (broad_windows) |lgwin| {
                        const encoded = try reference.encodeWithOptionsAlloc(init.gpa, payload, .{
                            .quality = @intCast(quality),
                            .mode = @intCast(mode),
                            .lgwin = lgwin,
                        });
                        defer init.gpa.free(encoded);
                        const decoded = vort.brDecodeStreamAlloc(init.gpa, encoded) catch |err| {
                            std.debug.print("broad shape={d} size={d} quality={d} mode={d} lgwin={d} encoded={d}: {s}\n", .{ shape, size, quality, mode, lgwin, encoded.len, @errorName(err) });
                            return err;
                        };
                        defer init.gpa.free(decoded);
                        if (!std.mem.eql(u8, payload, decoded)) {
                            std.debug.print("broad mismatch shape={d} size={d} quality={d} mode={d} lgwin={d} encoded={d}\n", .{ shape, size, quality, mode, lgwin, encoded.len });
                            return error.SizeMismatch;
                        }
                        decodeProgressChunks(init.gpa, encoded, payload, @intCast(lgwin), 17, 31) catch |err| {
                            std.debug.print("broad progressive shape={d} size={d} quality={d} mode={d} lgwin={d} encoded={d}: {s}\n", .{ shape, size, quality, mode, lgwin, encoded.len, @errorName(err) });
                            return err;
                        };
                        broad_generated_cases += 1;
                        broad_progressive_cases += 1;
                    }
                }
            }
        }
    }
    // Optional real-corpus coverage deliberately stays outside the default CI
    // contract: callers can point this dependency-free decoder at source,
    // markup, model metadata, or font files from neighboring checkouts without
    // making those repositories build dependencies. Each source is truncated
    // to a deterministic prefix and crosses representative libbrotli quality,
    // mode, and window families through allocating and byte-progressive APIs.
    var real_file_cases: usize = 0;
    var real_progressive_cases: usize = 0;
    const RealCaseOptions = struct { quality: c_int, mode: c_int, lgwin: c_int };
    const real_options = [_]RealCaseOptions{
        .{ .quality = 0, .mode = 0, .lgwin = 10 },
        .{ .quality = 4, .mode = 1, .lgwin = 16 },
        .{ .quality = 8, .mode = 2, .lgwin = 20 },
        .{ .quality = 11, .mode = 0, .lgwin = 24 },
    };
    var real_quality_mask: u16 = 0;
    var real_mode_mask: u8 = 0;
    var real_window_mask: u32 = 0;
    for (real_options) |options| {
        real_quality_mask |= @as(u16, 1) << @intCast(options.quality);
        real_mode_mask |= @as(u8, 1) << @intCast(options.mode);
        real_window_mask |= @as(u32, 1) << @intCast(options.lgwin);
    }
    for (real_files.items) |path| {
        const payload = try readFilePrefixAlloc(init, path, real_limit);
        defer init.gpa.free(payload);
        if (payload.len == 0) return error.EmptyInput;
        for (real_options) |options| {
            const encoded = try reference.encodeWithOptionsAlloc(init.gpa, payload, .{
                .quality = options.quality,
                .mode = options.mode,
                .lgwin = options.lgwin,
            });
            defer init.gpa.free(encoded);
            const decoded = vort.brDecodeStreamAlloc(init.gpa, encoded) catch |err| {
                std.debug.print("real file={s} bytes={d} quality={d} mode={d} lgwin={d} encoded={d}: {s}\n", .{ path, payload.len, options.quality, options.mode, options.lgwin, encoded.len, @errorName(err) });
                return err;
            };
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
            decodeProgressChunks(init.gpa, encoded, payload, @intCast(options.lgwin), 17, 31) catch |err| {
                std.debug.print("real progressive file={s} bytes={d} quality={d} mode={d} lgwin={d} encoded={d}: {s}\n", .{ path, payload.len, options.quality, options.mode, options.lgwin, encoded.len, @errorName(err) });
                return err;
            };
            real_file_cases += 1;
            real_progressive_cases += 1;
        }
    }
    // Vort-to-libbrotli coverage for every newly exposed planned window. The
    // producer must advertise the requested window and the independent decoder
    // must reproduce the payload for all stable compression levels.
    var planned_window_cases: usize = 0;
    const planned_window_payload = "windowed planned Brotli interoperability payload 0123456789.\n" ** 32;
    for ([_]vort.BrotliPlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
        for (10..17) |window_bits_usize| {
            const window_bits: u5 = @intCast(window_bits_usize);
            const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, planned_window_payload, .{
                .level = level,
                .window_bits = window_bits,
            });
            defer init.gpa.free(encoded);
            const summary = try vort.brSummarizeStream(encoded);
            if (summary.window_bits != window_bits) return error.SizeMismatch;
            const decoded = try init.gpa.alloc(u8, planned_window_payload.len);
            defer init.gpa.free(decoded);
            reference.decode(encoded, decoded) catch |err| {
                std.debug.print("planned window level={s} lgwin={d} encoded={d}: {s}\n", .{ @tagName(level), window_bits, encoded.len, @errorName(err) });
                return err;
            };
            if (!std.mem.eql(u8, planned_window_payload, decoded)) return error.ReferenceDecodeFailed;
            planned_window_cases += 1;
        }
    }
    var planned_literal_split_cases: usize = 0;
    const planned_literal_split_payload = try init.gpa.alloc(u8, 96 * 1024);
    defer init.gpa.free(planned_literal_split_payload);
    var planned_literal_split_state: u32 = 0x1234_5678;
    for (planned_literal_split_payload, 0..) |*byte, i| {
        planned_literal_split_state = planned_literal_split_state *% 1_664_525 +% 1_013_904_223;
        const nibble: u8 = @truncate(planned_literal_split_state >> 28);
        byte.* = if (i < planned_literal_split_payload.len / 6) nibble else 240 + nibble;
    }
    const planned_literal_split = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, planned_literal_split_payload, .{ .level = .ratio });
    defer init.gpa.free(planned_literal_split);
    const planned_literal_split_summary = try vort.brSummarizeStream(planned_literal_split);
    if (planned_literal_split_summary.max_literal_block_types != 2 or
        planned_literal_split_summary.max_literal_context_trees != 2) return error.ReferenceEncodeFailed;
    const planned_literal_split_decoded = try init.gpa.alloc(u8, planned_literal_split_payload.len);
    defer init.gpa.free(planned_literal_split_decoded);
    try reference.decode(planned_literal_split, planned_literal_split_decoded);
    if (!std.mem.eql(u8, planned_literal_split_payload, planned_literal_split_decoded)) return error.ReferenceDecodeFailed;
    try decodeProgressChunks(init.gpa, planned_literal_split, planned_literal_split_payload, 16, 17, 31);
    planned_literal_split_cases += 1;
    var planned_command_split_cases: usize = 0;
    const planned_command_split = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, dictionary_bytes, .{ .level = .ratio });
    defer init.gpa.free(planned_command_split);
    const planned_command_split_summary = try vort.brSummarizeStreamAlloc(init.gpa, planned_command_split);
    if (planned_command_split_summary.max_command_block_types != 2) return error.ReferenceEncodeFailed;
    const planned_command_split_decoded = try init.gpa.alloc(u8, dictionary_bytes.len);
    defer init.gpa.free(planned_command_split_decoded);
    try reference.decode(planned_command_split, planned_command_split_decoded);
    if (!std.mem.eql(u8, dictionary_bytes, planned_command_split_decoded)) return error.ReferenceDecodeFailed;
    try decodeProgressChunks(init.gpa, planned_command_split, dictionary_bytes, 16, 17, 31);
    planned_command_split_cases += 1;
    const long_window_gap = 80 * 1024;
    const long_window_repeat = 12 * 1024;
    const long_window_payload = try init.gpa.alloc(u8, long_window_gap + long_window_repeat);
    defer init.gpa.free(long_window_payload);
    var long_window_state: u32 = 0x1234_5678;
    for (long_window_payload[0..long_window_gap]) |*byte| {
        long_window_state = long_window_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(long_window_state >> 24);
    }
    @memcpy(long_window_payload[long_window_gap..], long_window_payload[0..long_window_repeat]);
    const long_window_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, long_window_payload, .{ .level = .ratio, .window_bits = 17 });
    defer init.gpa.free(long_window_encoded);
    const long_window_decoded = try init.gpa.alloc(u8, long_window_payload.len);
    defer init.gpa.free(long_window_decoded);
    try reference.decode(long_window_encoded, long_window_decoded);
    if (!std.mem.eql(u8, long_window_payload, long_window_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const wider_window_gap = 160 * 1024;
    const wider_window_repeat = 12 * 1024;
    const wider_window_payload = try init.gpa.alloc(u8, wider_window_gap + wider_window_repeat);
    defer init.gpa.free(wider_window_payload);
    var wider_window_state: u32 = 0x8bad_f00d;
    for (wider_window_payload[0..wider_window_gap]) |*byte| {
        wider_window_state = wider_window_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(wider_window_state >> 24);
    }
    @memcpy(wider_window_payload[wider_window_gap..], wider_window_payload[0..wider_window_repeat]);
    const wider_window_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, wider_window_payload, .{ .level = .ratio, .window_bits = 18 });
    defer init.gpa.free(wider_window_encoded);
    const wider_window_decoded = try init.gpa.alloc(u8, wider_window_payload.len);
    defer init.gpa.free(wider_window_decoded);
    try reference.decode(wider_window_encoded, wider_window_decoded);
    if (!std.mem.eql(u8, wider_window_payload, wider_window_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const window_19_gap = 320 * 1024;
    const window_19_repeat = 12 * 1024;
    const window_19_payload = try init.gpa.alloc(u8, window_19_gap + window_19_repeat);
    defer init.gpa.free(window_19_payload);
    var window_19_state: u32 = 0x1976_0421;
    for (window_19_payload[0..window_19_gap]) |*byte| {
        window_19_state = window_19_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(window_19_state >> 24);
    }
    @memcpy(window_19_payload[window_19_gap..], window_19_payload[0..window_19_repeat]);
    const window_19_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, window_19_payload, .{ .level = .ratio, .window_bits = 19 });
    defer init.gpa.free(window_19_encoded);
    const window_19_decoded = try init.gpa.alloc(u8, window_19_payload.len);
    defer init.gpa.free(window_19_decoded);
    try reference.decode(window_19_encoded, window_19_decoded);
    if (!std.mem.eql(u8, window_19_payload, window_19_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const window_20_gap = 640 * 1024;
    const window_20_repeat = 12 * 1024;
    const window_20_payload = try init.gpa.alloc(u8, window_20_gap + window_20_repeat);
    defer init.gpa.free(window_20_payload);
    var window_20_state: u32 = 0x20c0_ffee;
    for (window_20_payload[0..window_20_gap]) |*byte| {
        window_20_state = window_20_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(window_20_state >> 24);
    }
    @memcpy(window_20_payload[window_20_gap..], window_20_payload[0..window_20_repeat]);
    const window_20_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, window_20_payload, .{ .level = .ratio, .window_bits = 20 });
    defer init.gpa.free(window_20_encoded);
    const window_20_decoded = try init.gpa.alloc(u8, window_20_payload.len);
    defer init.gpa.free(window_20_decoded);
    try reference.decode(window_20_encoded, window_20_decoded);
    if (!std.mem.eql(u8, window_20_payload, window_20_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const window_21_gap = 1280 * 1024;
    const window_21_repeat = 12 * 1024;
    const window_21_payload = try init.gpa.alloc(u8, window_21_gap + window_21_repeat);
    defer init.gpa.free(window_21_payload);
    var window_21_state: u32 = 0x21c0_ffee;
    for (window_21_payload[0..window_21_gap]) |*byte| {
        window_21_state = window_21_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(window_21_state >> 24);
    }
    @memcpy(window_21_payload[window_21_gap..], window_21_payload[0..window_21_repeat]);
    const window_21_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, window_21_payload, .{ .level = .ratio, .window_bits = 21 });
    defer init.gpa.free(window_21_encoded);
    const window_21_decoded = try init.gpa.alloc(u8, window_21_payload.len);
    defer init.gpa.free(window_21_decoded);
    try reference.decode(window_21_encoded, window_21_decoded);
    if (!std.mem.eql(u8, window_21_payload, window_21_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const window_22_gap = 2560 * 1024;
    const window_22_repeat = 12 * 1024;
    const window_22_payload = try init.gpa.alloc(u8, window_22_gap + window_22_repeat);
    defer init.gpa.free(window_22_payload);
    var window_22_state: u32 = 0x5221_1eaf;
    for (window_22_payload[0..window_22_gap]) |*byte| {
        window_22_state = window_22_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(window_22_state >> 24);
    }
    @memcpy(window_22_payload[window_22_gap..], window_22_payload[0..window_22_repeat]);
    const window_22_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, window_22_payload, .{ .level = .ratio, .window_bits = 22 });
    defer init.gpa.free(window_22_encoded);
    const window_22_decoded = try init.gpa.alloc(u8, window_22_payload.len);
    defer init.gpa.free(window_22_decoded);
    try reference.decode(window_22_encoded, window_22_decoded);
    if (!std.mem.eql(u8, window_22_payload, window_22_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const window_23_gap = 5 * 1024 * 1024;
    const window_23_repeat = 12 * 1024;
    const window_23_payload = try init.gpa.alloc(u8, window_23_gap + window_23_repeat);
    defer init.gpa.free(window_23_payload);
    var window_23_state: u32 = 0x5238_1eaf;
    for (window_23_payload[0..window_23_gap]) |*byte| {
        window_23_state = window_23_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(window_23_state >> 24);
    }
    @memcpy(window_23_payload[window_23_gap..], window_23_payload[0..window_23_repeat]);
    const window_23_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, window_23_payload, .{ .level = .ratio, .window_bits = 23 });
    defer init.gpa.free(window_23_encoded);
    const window_23_decoded = try init.gpa.alloc(u8, window_23_payload.len);
    defer init.gpa.free(window_23_decoded);
    try reference.decode(window_23_encoded, window_23_decoded);
    if (!std.mem.eql(u8, window_23_payload, window_23_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    const window_24_gap = 10 * 1024 * 1024;
    const window_24_repeat = 256 * 1024;
    const window_24_payload = try init.gpa.alloc(u8, window_24_gap + window_24_repeat);
    defer init.gpa.free(window_24_payload);
    var window_24_state: u32 = 0x524f_1eaf;
    for (window_24_payload[0..window_24_gap]) |*byte| {
        window_24_state = window_24_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(window_24_state >> 24);
    }
    @memcpy(window_24_payload[window_24_gap..], window_24_payload[0..window_24_repeat]);
    const window_24_encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, window_24_payload, .{ .level = .ratio, .window_bits = 24 });
    defer init.gpa.free(window_24_encoded);
    const window_24_decoded = try init.gpa.alloc(u8, window_24_payload.len);
    defer init.gpa.free(window_24_decoded);
    try reference.decode(window_24_encoded, window_24_decoded);
    if (!std.mem.eql(u8, window_24_payload, window_24_decoded)) return error.ReferenceDecodeFailed;
    planned_window_cases += 1;
    var planned_chunked_window_cases: usize = 0;
    const planned_chunks = [_][]const u8{
        planned_window_payload[0 .. planned_window_payload.len / 2],
        planned_window_payload[planned_window_payload.len / 2 ..],
    };
    const planned_chunked_metadata = "vort planned chunked options";
    for ([_]u5{ 10, 16, 20, 24 }) |window_bits| {
        const encoded = try vort.brEncodePlannedStreamChunksWithOptionsAlloc(init.gpa, &planned_chunks, .{
            .window_bits = window_bits,
            .metadata = planned_chunked_metadata,
        });
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStream(encoded);
        if (summary.window_bits != window_bits or
            summary.metadata_meta_block_count != 1 or
            summary.metadata_bytes != planned_chunked_metadata.len) return error.SizeMismatch;
        const decoded = try init.gpa.alloc(u8, planned_window_payload.len);
        defer init.gpa.free(decoded);
        try reference.decode(encoded, decoded);
        if (!std.mem.eql(u8, planned_window_payload, decoded)) return error.ReferenceDecodeFailed;
        planned_chunked_window_cases += 1;
    }
    var planned_large_window_cases: usize = 0;
    const planned_large_len = vort.brotliMaxUncompressedMetaBlockLen + 17;
    const planned_large_payload = try init.gpa.alloc(u8, planned_large_len);
    defer init.gpa.free(planned_large_payload);
    for (planned_large_payload, 0..) |*byte, i| byte.* = "abcd0123"[i & 7];
    for ([_]u5{ 10, 24 }) |window_bits| {
        const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, planned_large_payload, .{
            .level = .ratio,
            .window_bits = window_bits,
        });
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
        if (summary.window_bits != window_bits or summary.compressed_meta_block_count < 2 or encoded.len >= planned_large_payload.len / 100)
            return error.ReferenceEncodeFailed;
        const decoded = try init.gpa.alloc(u8, planned_large_payload.len);
        defer init.gpa.free(decoded);
        try reference.decode(encoded, decoded);
        if (!std.mem.eql(u8, planned_large_payload, decoded)) return error.ReferenceDecodeFailed;
        planned_large_window_cases += 1;
    }
    var planned_metadata_cases: usize = 0;
    const planned_metadata = "vort one-shot planned metadata";
    for ([_]vort.BrotliPlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
        const window_bits: u5 = if (level == .ratio) 24 else 10;
        const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, planned_window_payload, .{
            .level = level,
            .window_bits = window_bits,
            .metadata = planned_metadata,
        });
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStream(encoded);
        if (summary.window_bits != window_bits or
            summary.metadata_meta_block_count != 1 or
            summary.metadata_bytes != planned_metadata.len or
            summary.compressed_meta_block_count < 1) return error.ReferenceEncodeFailed;
        const decoded = try init.gpa.alloc(u8, planned_window_payload.len);
        defer init.gpa.free(decoded);
        try reference.decode(encoded, decoded);
        if (!std.mem.eql(u8, planned_window_payload, decoded)) return error.ReferenceDecodeFailed;
        planned_metadata_cases += 1;
    }
    const planned_metadata_dictionary_payload = "information";
    const planned_metadata_dictionary = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, planned_metadata_dictionary_payload, .{
        .level = .ratio,
        .window_bits = 24,
        .metadata = planned_metadata,
    });
    defer init.gpa.free(planned_metadata_dictionary);
    const planned_metadata_dictionary_summary = try vort.brSummarizeStream(planned_metadata_dictionary);
    if (planned_metadata_dictionary_summary.metadata_meta_block_count != 1 or
        planned_metadata_dictionary_summary.static_dictionary_copy_count == 0) return error.ReferenceEncodeFailed;
    var planned_metadata_dictionary_decoded: [planned_metadata_dictionary_payload.len]u8 = undefined;
    try reference.decode(planned_metadata_dictionary, &planned_metadata_dictionary_decoded);
    if (!std.mem.eql(u8, planned_metadata_dictionary_payload, &planned_metadata_dictionary_decoded)) return error.ReferenceDecodeFailed;
    planned_metadata_cases += 1;
    const planned_metadata_long = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, long_window_payload, .{
        .level = .ratio,
        .metadata = planned_metadata,
    });
    defer init.gpa.free(planned_metadata_long);
    const planned_metadata_long_summary = try vort.brSummarizeStreamAlloc(init.gpa, planned_metadata_long);
    if (planned_metadata_long_summary.window_bits != 17 or
        planned_metadata_long_summary.metadata_meta_block_count != 1 or
        planned_metadata_long_summary.metadata_bytes != planned_metadata.len) return error.ReferenceEncodeFailed;
    const planned_metadata_long_decoded = try init.gpa.alloc(u8, long_window_payload.len);
    defer init.gpa.free(planned_metadata_long_decoded);
    try reference.decode(planned_metadata_long, planned_metadata_long_decoded);
    if (!std.mem.eql(u8, long_window_payload, planned_metadata_long_decoded)) return error.ReferenceDecodeFailed;
    planned_metadata_cases += 1;
    var planned_extended_dictionary_cases: usize = 0;
    const planned_extended_dictionary_payload = "Information about compression performance and dictionary support." ** 5;
    const planned_extended_dictionary = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, planned_extended_dictionary_payload, .{
        .level = .ratio,
        .extended_dictionary_probes = 64,
    });
    defer init.gpa.free(planned_extended_dictionary);
    if ((try vort.brSummarizeStream(planned_extended_dictionary)).static_dictionary_copy_count == 0)
        return error.ReferenceEncodeFailed;
    var planned_extended_dictionary_decoded: [planned_extended_dictionary_payload.len]u8 = undefined;
    try reference.decode(planned_extended_dictionary, &planned_extended_dictionary_decoded);
    if (!std.mem.eql(u8, planned_extended_dictionary_payload, &planned_extended_dictionary_decoded))
        return error.ReferenceDecodeFailed;
    planned_extended_dictionary_cases += 1;
    const boundary_prefix_len = (@as(usize, 1) << 10) - 15;
    var boundary_payload: [boundary_prefix_len + 256]u8 = undefined;
    var boundary_state: u32 = 0x2c1b_3a49;
    for (boundary_payload[0..boundary_prefix_len]) |*byte| {
        boundary_state = boundary_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(boundary_state >> 24);
    }
    @memcpy(boundary_payload[boundary_prefix_len..], boundary_payload[0..256]);
    for ([_]vort.BrotliPlannedCompressionLevel{ .fast, .balanced, .ratio }) |level| {
        for ([_]u5{ 10, 11 }) |window_bits| {
            const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, &boundary_payload, .{
                .level = level,
                .window_bits = window_bits,
            });
            defer init.gpa.free(encoded);
            const decoded = try init.gpa.alloc(u8, boundary_payload.len);
            defer init.gpa.free(decoded);
            reference.decode(encoded, decoded) catch |err| {
                std.debug.print("planned boundary level={s} lgwin={d} encoded={d}: {s}\n", .{ @tagName(level), window_bits, encoded.len, @errorName(err) });
                return err;
            };
            if (!std.mem.eql(u8, &boundary_payload, decoded)) return error.ReferenceDecodeFailed;
            planned_window_cases += 1;
        }
    }

    var stdout_buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.print(
        "br_upstream_multiblock_diff=ok cases={d} one_shot_cases={d} large_window_decode_cases={d} broad_generated_cases={d} broad_progressive_cases={d} real_file_cases={d} real_progressive_cases={d} real_options_per_file={d} real_quality_mask=0x{x} real_mode_mask=0x{x} real_window_mask=0x{x} planned_window_cases={d} planned_literal_split_cases={d} planned_command_split_cases={d} planned_chunked_window_cases={d} planned_large_window_cases={d} planned_metadata_cases={d} planned_extended_dictionary_cases={d} progress_matrix_streams={d} progress_matrix_runs={d} summaries_unsupported=0 caller_history_summaries={d} allocating_summary_history_cases={d} high_tree_truncation_cases={d} wide_literal_type_cases={d} maximum_literal_type_cases={d} maximum_command_type_cases={d} extended_header_cases={d} operation_schedule_cases={d} invalid_operation_schedule_cases=2 reference_version={x}\n",
        .{ cases_run, one_shot_cases, large_window_decode_cases, broad_generated_cases, broad_progressive_cases, real_file_cases, real_progressive_cases, real_options.len, real_quality_mask, real_mode_mask, real_window_mask, planned_window_cases, planned_literal_split_cases, planned_command_split_cases, planned_chunked_window_cases, planned_large_window_cases, planned_metadata_cases, planned_extended_dictionary_cases, progress_matrix_streams, progress_matrix_runs, caller_history_summaries, allocating_summary_history_cases, high_tree_truncation_cases, wide_literal_type_cases, maximum_literal_type_cases, maximum_command_type_cases, extended_header_cases, operation_schedule_cases, reference.version() },
    );
    try stdout.interface.flush();
}

fn readFilePrefixAlloc(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    const stat = try std.Io.Dir.cwd().statFile(init.io, path, .{});
    const file_len = std.math.cast(usize, stat.size) orelse limit;
    const prefix_len = @min(file_len, limit);
    const payload = try init.gpa.alloc(u8, prefix_len);
    errdefer init.gpa.free(payload);
    var file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const read_len = try file.readPositionalAll(init.io, payload, 0);
    return init.gpa.realloc(payload, read_len);
}

fn validateClusterCoverage(case: Case, summary: vort.BrotliStreamSummary) !void {
    if (summary.max_literal_context_trees < case.min_literal_context_trees or
        summary.max_distance_block_types < case.min_distance_block_types or
        summary.max_distance_context_trees < case.min_distance_context_trees)
    {
        std.debug.print(
            "{s}: expected trees/types >= {d}/{d}/{d}, got {d}/{d}/{d}\n",
            .{ case.name, case.min_literal_context_trees, case.min_distance_block_types, case.min_distance_context_trees, summary.max_literal_context_trees, summary.max_distance_block_types, summary.max_distance_context_trees },
        );
        return error.ReferenceEncodeFailed;
    }
}

fn decodeByteProgressiveWithMetadata(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, expected_metadata: []const u8, lgwin: u32) !void {
    return decodeMetadataProgressChunks(allocator, encoded, expected, expected_metadata, lgwin, 1, 7);
}

fn decodeMetadataProgressChunkMatrix(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, expected_metadata: []const u8, lgwin: u32) !void {
    for (progress_input_chunks) |input_chunk_len| {
        for (progress_output_chunks) |output_chunk_len|
            try decodeMetadataProgressChunks(allocator, encoded, expected, expected_metadata, lgwin, input_chunk_len, output_chunk_len);
    }
}

fn decodeMetadataProgressChunks(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, expected_metadata: []const u8, lgwin: u32, input_chunk_len: usize, output_chunk_len: usize) !void {
    const history = try allocator.alloc(u8, @min(expected.len, (@as(usize, 1) << @intCast(lgwin)) - 16));
    defer allocator.free(history);
    const metadata = try allocator.alloc(u8, expected_metadata.len);
    defer allocator.free(metadata);
    var metadata_lengths: [8]usize = undefined;
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(history, .{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
        .metadata_output = metadata,
        .metadata_block_lengths = &metadata_lengths,
    });
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const output_end = @min(output.len, output_offset + output_chunk_len);
        const step = decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]) catch |err| {
            std.debug.print("decode failure input={d}/{d} output={d}/{d} snapshot={any}\n", .{ input_offset, encoded.len, output_offset, expected.len, decoder.snapshot() });
            return err;
        };
        if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.ReferenceDecodeFailed;
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    const snapshot = decoder.snapshot();
    if (input_offset != encoded.len or output_offset != expected.len or
        !std.mem.eql(u8, output, expected) or
        snapshot.metadata_block_count == 0 or
        snapshot.metadata_block_count > metadata_lengths.len or
        snapshot.metadata_total != expected_metadata.len or
        !std.mem.eql(u8, metadata, expected_metadata))
    {
        std.debug.print(
            "metadata mismatch input={d}/{d} output={d}/{d} blocks={d} bytes={d}/{d} captured={d} equal={any}\n",
            .{ input_offset, encoded.len, output_offset, expected.len, snapshot.metadata_block_count, snapshot.metadata_total, expected_metadata.len, snapshot.metadata_written, std.mem.eql(u8, metadata, expected_metadata) },
        );
        return error.SizeMismatch;
    }
    var metadata_len_sum: usize = 0;
    for (metadata_lengths[0..snapshot.metadata_block_count]) |len| metadata_len_sum += len;
    if (metadata_len_sum != expected_metadata.len) return error.SizeMismatch;
}

fn decodeByteProgressive(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, lgwin: u32) !void {
    return decodeProgressChunks(allocator, encoded, expected, lgwin, 1, 7);
}

fn decodeProgressChunkMatrix(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, lgwin: u32) !void {
    for (progress_input_chunks) |input_chunk_len| {
        for (progress_output_chunks) |output_chunk_len|
            try decodeProgressChunks(allocator, encoded, expected, lgwin, input_chunk_len, output_chunk_len);
    }
}

fn progressChunkMatrixCaseCount() usize {
    return progress_input_chunks.len * progress_output_chunks.len;
}

fn decodeProgressChunks(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, lgwin: u32, input_chunk_len: usize, output_chunk_len: usize) !void {
    return decodeProgressChunksWithHeaderScratch(allocator, encoded, expected, lgwin, input_chunk_len, output_chunk_len, &.{});
}

fn decodeLargeWindowBuffered(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8) !void {
    var decoder = vort.BrotliIncrementalStreamDecoder.initExactCompressedSize(allocator, .{
        .expected_output_len = expected.len,
        .decode = .{ .allow_large_window = true },
    }, encoded.len);
    defer decoder.deinit();
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.ReferenceDecodeFailed;
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    if (input_offset != encoded.len or output_offset != expected.len or !std.mem.eql(u8, output, expected))
        return error.SizeMismatch;
}

fn decodeLargeWindowProgressive(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, lgwin: u5) !void {
    const history = try allocator.alloc(u8, @min(expected.len, (@as(usize, 1) << lgwin) - 16));
    defer allocator.free(history);
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(history, .{
        .expected_output_len = expected.len,
        .decode = .{ .allow_large_window = true },
    });
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
        const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]);
        if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.ReferenceDecodeFailed;
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    if (input_offset != encoded.len or output_offset != expected.len or !std.mem.eql(u8, output, expected))
        return error.SizeMismatch;
}

fn decodeProgressChunksWithHeaderScratch(allocator: std.mem.Allocator, encoded: []const u8, expected: []const u8, lgwin: u32, input_chunk_len: usize, output_chunk_len: usize, header_scratch: []u8) !void {
    // Keep exactly the useful portion of the advertised window so larger-window
    // cases exercise caller-owned history without overallocating short streams.
    const history = try allocator.alloc(u8, @min(expected.len, (@as(usize, 1) << @intCast(lgwin)) - 16));
    defer allocator.free(history);
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(history, .{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
        .compressed_header_scratch = header_scratch,
    });
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + input_chunk_len);
        const output_end = @min(output.len, output_offset + output_chunk_len);
        const step = decoder.step(encoded[input_offset..input_end], output[output_offset..output_end]) catch |err| {
            std.debug.print("decode failure input={d}/{d} output={d}/{d} snapshot={any}\n", .{ input_offset, encoded.len, output_offset, expected.len, decoder.snapshot() });
            return err;
        };
        if (step.progress.input_read == 0 and step.progress.output_written == 0)
            return error.ReferenceDecodeFailed;
        input_offset += step.progress.input_read;
        output_offset += step.progress.output_written;
    }
    try decoder.finish();
    if (input_offset != encoded.len or output_offset != expected.len or !std.mem.eql(u8, output, expected))
        return error.SizeMismatch;

    const one_shot_written = try vort.brDecodeStreamInto(encoded, output);
    if (one_shot_written != expected.len or !std.mem.eql(u8, output, expected))
        return error.SizeMismatch;
}
