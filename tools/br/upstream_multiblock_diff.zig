const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

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
    allow_summary_unsupported: bool = false,
    min_literal_context_trees: usize = 0,
    min_distance_block_types: usize = 0,
    min_distance_context_trees: usize = 0,
};

pub fn main(init: std.process.Init) !void {
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
        .{ .name = "large-source-clustered", .chunks = &clustered_source_chunks, .expected = clustered_source, .qualities = &clustered_qualities, .windows = &.{20}, .lgblock = 16, .min_compressed_blocks = 1, .allow_summary_unsupported = true, .min_literal_context_trees = 39 },
        .{ .name = "large-source-mixed-clustered", .chunks = &mixed_clustered_source_chunks, .expected = mixed_clustered_source, .qualities = &mixed_clustered_qualities, .windows = &.{20}, .lgblock = 16, .min_compressed_blocks = 1, .allow_summary_unsupported = true, .min_literal_context_trees = 128 },
        .{ .name = "large-source-distance-clustered", .chunks = &distance_clustered_chunks, .expected = distance_clustered_source, .qualities = &distance_clustered_qualities, .windows = &.{20}, .lgblock = 16, .min_compressed_blocks = 1, .allow_summary_unsupported = true, .min_distance_block_types = 33, .min_distance_context_trees = 33 },
        .{ .name = "large-source-quality-eleven", .chunks = &large_source_chunks, .expected = large_source, .qualities = &quality_eleven, .windows = &.{ 18, 20, 22, 24 }, .lgblock = 18, .allow_summary_unsupported = true },
        .{ .name = "far-history", .chunks = &far_history_chunks, .expected = far_history_expected, .qualities = &compact_qualities, .windows = &.{17}, .min_compressed_blocks = 1, .min_stored_blocks = 2 },
        .{ .name = "compressed-stored-compressed", .chunks = &transition_chunks, .expected = text ++ random[0..2048] ++ text, .qualities = &context_qualities, .min_compressed_blocks = 2, .min_stored_blocks = 1 },
        .{ .name = "tiny-flushes", .chunks = &tiny_chunks, .expected = tiny_expected, .qualities = &context_qualities, .lgblock = 14, .min_compressed_blocks = 0 },
        .{ .name = "postfix-distances", .chunks = &pattern_chunks, .expected = first_pattern ++ second_pattern ++ third_pattern, .qualities = &context_qualities, .npostfix = 1, .ndirect = 2 },
    };

    var cases_run: usize = 0;
    var summaries_unsupported: usize = 0;
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
                    const summary = vort.brSummarizeStream(encoded) catch |err| {
                        if (case.allow_summary_unsupported and err == error.UnsupportedBrotliFeature) {
                            const allocated_summary = vort.brSummarizeStreamAlloc(init.gpa, encoded) catch |allocated_err| {
                                std.debug.print("{s} quality={d} mode={d} lgwin={d}: allocated summary {s}\n", .{ case.name, quality, mode, lgwin, @errorName(allocated_err) });
                                return allocated_err;
                            };
                            if (allocated_summary.decoded_bytes != case.expected.len) return error.SizeMismatch;
                            try validateClusterCoverage(case, allocated_summary);
                            const decoded = try vort.brDecodeStreamAlloc(init.gpa, encoded);
                            defer init.gpa.free(decoded);
                            if (!std.mem.eql(u8, decoded, case.expected)) return error.SizeMismatch;
                            const exact_output = try init.gpa.alloc(u8, case.expected.len);
                            defer init.gpa.free(exact_output);
                            const written = try vort.brDecodeStreamIntoExactSize(encoded, exact_output, case.expected.len);
                            if (written != case.expected.len or !std.mem.eql(u8, exact_output, case.expected)) return error.SizeMismatch;
                            summaries_unsupported += 1;
                            cases_run += 1;
                            continue;
                        }
                        std.debug.print("{s} quality={d} mode={d} lgwin={d}: summary {s} encoded={d} expected={d}\n", .{ case.name, quality, mode, lgwin, @errorName(err), encoded.len, case.expected.len });
                        return err;
                    };
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
        cases_run += 1;
    }

    var stdout_buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.print(
        "br_upstream_multiblock_diff=ok cases={d} summaries_unsupported={d} reference_version={x}\n",
        .{ cases_run, summaries_unsupported, reference.version() },
    );
    try stdout.interface.flush();
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
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
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
    // Keep exactly the useful portion of the advertised window so larger-window
    // cases exercise caller-owned history without overallocating short streams.
    const history = try allocator.alloc(u8, @min(expected.len, (@as(usize, 1) << @intCast(lgwin)) - 16));
    defer allocator.free(history);
    var decoder = vort.BrotliIncrementalCopyStreamDecoder.initWithOptions(history, .{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
    });
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const input_end = @min(encoded.len, input_offset + 1);
        const output_end = @min(output.len, output_offset + 7);
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
