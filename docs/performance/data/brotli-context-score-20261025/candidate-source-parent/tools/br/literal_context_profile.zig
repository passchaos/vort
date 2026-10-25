const std = @import("std");
const vort = @import("vort");
const benchmark_provenance = @import("benchmark_provenance");

const Case = struct { name: []const u8, payload: []const u8 };
const Options = struct { iterations: usize = 5, csv_path: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);
    const source_file = try std.Io.Dir.cwd().openFile(init.io, "src/br.zig", .{});
    defer source_file.close(init.io);
    const source = try init.gpa.alloc(u8, 32 * 1024);
    defer init.gpa.free(source);
    var source_reader = source_file.reader(init.io, &.{});
    if (try source_reader.interface.readSliceShort(source) != source.len) return error.InputTooSmall;
    const cases = [_]Case{
        .{ .name = "source4k", .payload = source[0 .. 4 * 1024] },
        .{ .name = "source16k", .payload = source[0 .. 16 * 1024] },
        .{ .name = "source32k", .payload = source[0 .. 32 * 1024] },
    };

    var csv: std.Io.Writer.Allocating = .init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,input_bytes,input_sha256,iterations,literal_count,active_symbols," ++
            "suffix_tree_count,suffix_mode,suffix_savings_bits," ++
            "up_to_16_tree_count,up_to_16_mode,up_to_16_savings_bits," ++
            "full_tree_count,full_mode,full_savings_bits," ++
            "suffix_payload_scores,suffix_payload_reuses,cluster_trials,cluster_rounds," ++
            "assignment_contexts,assignment_comparisons,score_cache_hits,score_cache_misses," ++
            "tree_score_cache_hits,tree_score_cache_misses," ++
            "tree_score_cache_cold_misses,tree_score_cache_conflict_misses," ++
            "tree_score_calls,tree_simple_scores,tree_complex_scores,tree_active_entries,tree_active_buckets," ++
            "small_huffman_calls,small_huffman_failures,package_merge_calls," ++
            "complex_prefix_calls,complex_prefix_rle_tokens,complex_prefix_code_length_active," ++
            "complex_prefix_input_lengths,complex_prefix_zero_runs,complex_prefix_nonzero_runs," ++
            "complex_prefix_zero_lengths,complex_prefix_nonzero_lengths,complex_prefix_literal_tokens," ++
            "complex_prefix_repeat16_tokens,complex_prefix_repeat17_tokens,complex_prefix_repeat_chain_buckets," ++
            "analysis_ns,baseline_ns,suffix_ns,sparse_ns,cluster_ns,cluster_init_ns," ++
            "cluster_prepare_ns,cluster_assignment_ns,cluster_finalize_ns,cluster_score_ns," ++
            "tree_alphabet_ns,tree_lengths_ns,tree_weighted_ns,tree_prefix_ns,tree_score_stage_ns," ++
            "small_huffman_leaf_order_ns,small_huffman_merge_ns,small_huffman_depth_ns," ++
            "small_huffman_output_ns,small_huffman_stage_ns," ++
            "complex_prefix_rle_ns,complex_prefix_code_length_tree_ns,complex_prefix_header_ns," ++
            "complex_prefix_encoder_ns,complex_prefix_payload_ns,complex_prefix_stage_ns," ++
            "complex_prefix_shape_ns," ++
            "stage_ns,cluster_stage_ns,total_ns,unattributed_ns,cluster_unattributed_ns,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    for (cases) |case| {
        const profile = try vort.brProfileLiteralContextSearch(
            init.gpa,
            case.payload,
            init.io,
            options.iterations,
        );
        const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
        const stage_ns = profile.stageNs();
        const cluster_stage_ns = profile.clusterStageNs();
        const tree_score_stage_ns = profile.treeScoreStageNs();
        // Shared tree scores include misses from all three disjoint parents.
        const tree_score_parent_ns = profile.baseline_ns + profile.suffix_ns + profile.cluster_score_ns;
        const small_huffman_stage_ns = profile.smallHuffmanStageNs();
        const complex_prefix_stage_ns = profile.complexPrefixStageNs();
        if (stage_ns > profile.total_ns or cluster_stage_ns > profile.cluster_ns or
            tree_score_stage_ns > tree_score_parent_ns or
            small_huffman_stage_ns > profile.tree_lengths_ns or
            complex_prefix_stage_ns > profile.tree_prefix_ns)
            return error.InvalidBlockPlan;
        try csv.writer.print(
            "{s},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}," ++
                "{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                case.name,
                profile.input_bytes,
                &input_sha256,
                profile.iterations,
                profile.literal_count,
                profile.active_symbols,
                profile.suffix_tree_count,
                profile.suffix_mode,
                profile.suffix_savings_bits,
                profile.up_to_16_tree_count,
                profile.up_to_16_mode,
                profile.up_to_16_savings_bits,
                profile.full_tree_count,
                profile.full_mode,
                profile.full_savings_bits,
                profile.suffix_payload_scores,
                profile.suffix_payload_reuses,
                profile.cluster_trials,
                profile.cluster_rounds,
                profile.assignment_contexts,
                profile.assignment_comparisons,
                profile.score_cache_hits,
                profile.score_cache_misses,
                profile.tree_score_cache_hits,
                profile.tree_score_cache_misses,
                profile.tree_score_cache_cold_misses,
                profile.tree_score_cache_conflict_misses,
                profile.tree_score_calls,
                profile.tree_simple_scores,
                profile.tree_complex_scores,
                profile.tree_active_entries,
            },
        );
        try csv.writer.writeByte(',');
        try writeHistogram(&csv.writer, &profile.tree_active_buckets);
        try csv.writer.print(
            ",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                profile.small_huffman_calls,
                profile.small_huffman_failures,
                profile.package_merge_calls,
                profile.complex_prefix_calls,
                profile.complex_prefix_rle_tokens,
                profile.complex_prefix_code_length_active,
                profile.complex_prefix_input_lengths,
                profile.complex_prefix_zero_runs,
                profile.complex_prefix_nonzero_runs,
                profile.complex_prefix_zero_lengths,
                profile.complex_prefix_nonzero_lengths,
                profile.complex_prefix_literal_tokens,
                profile.complex_prefix_repeat16_tokens,
                profile.complex_prefix_repeat17_tokens,
            },
        );
        try csv.writer.writeByte(',');
        try writeHistogram(&csv.writer, &profile.complex_prefix_repeat_chain_buckets);
        try csv.writer.print(
            ",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
            .{
                profile.analysis_ns,
                profile.baseline_ns,
                profile.suffix_ns,
                profile.sparse_ns,
                profile.cluster_ns,
                profile.cluster_init_ns,
                profile.cluster_prepare_ns,
                profile.cluster_assignment_ns,
                profile.cluster_finalize_ns,
                profile.cluster_score_ns,
                profile.tree_alphabet_ns,
                profile.tree_lengths_ns,
                profile.tree_weighted_ns,
                profile.tree_prefix_ns,
                tree_score_stage_ns,
                profile.small_huffman_leaf_order_ns,
                profile.small_huffman_merge_ns,
                profile.small_huffman_depth_ns,
                profile.small_huffman_output_ns,
                small_huffman_stage_ns,
                profile.complex_prefix_rle_ns,
                profile.complex_prefix_code_length_tree_ns,
                profile.complex_prefix_header_ns,
                profile.complex_prefix_encoder_ns,
                profile.complex_prefix_payload_ns,
                complex_prefix_stage_ns,
                profile.complex_prefix_shape_ns,
                stage_ns,
                cluster_stage_ns,
                profile.total_ns,
                profile.total_ns - stage_ns,
                profile.cluster_ns - cluster_stage_ns,
            },
        );
        try provenance.writeCsvFields(&csv.writer);
        try csv.writer.writeByte('\n');
    }

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn writeHistogram(writer: *std.Io.Writer, values: []const usize) !void {
    for (values, 0..) |value, index| {
        if (index != 0) try writer.writeByte(';');
        try writer.print("{d}", .{value});
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations"))
            options.iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10)
        else if (std.mem.eql(u8, arg, "--csv"))
            options.csv_path = args.next() orelse return error.MissingPath
        else
            return error.UnknownArgument;
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    return options;
}
