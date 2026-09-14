const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");
const benchmark_provenance = @import("benchmark_provenance");
const q8_records_fixture = @import("q8_records_fixture.zig");

const Case = struct { name: []const u8, payload: []const u8 };
const Options = struct { iterations: usize = 3, csv_path: ?[]const u8 = null };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);
    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();
    const source = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/br.zig", init.gpa, .limited(2 * 1024 * 1024));
    defer init.gpa.free(source);
    if (source.len < 32 * 1024) return error.InputTooSmall;
    var records_q8: [q8_records_fixture.input_len]u8 = undefined;
    q8_records_fixture.fill(&records_q8);
    const cases = [_]Case{
        .{ .name = "source4k", .payload = source[0 .. 4 * 1024] },
        .{ .name = "source16k", .payload = source[0 .. 16 * 1024] },
        .{ .name = "source32k", .payload = source[0 .. 32 * 1024] },
        .{ .name = "records_q8", .payload = &records_q8 },
    };

    var csv: std.Io.Writer.Allocating = .init(init.gpa);
    defer csv.deinit();
    try csv.writer.print(
        "case,reference_version,input_bytes,input_sha256,encoded_sha256,iterations,selected_bytes,lazy_bytes,optimal_bytes,stored_bytes,optimal_attempted,optimal_selected,lazy_tokens,lazy_literals,lazy_matches,lazy_matched_bytes,lazy_fixed_bits,lazy_commands,lazy_recent_distances,lazy_last_distances,optimal_tokens,optimal_literals,optimal_matches,optimal_matched_bytes,optimal_fixed_bits,optimal_commands,optimal_recent_distances,optimal_last_distances,optimal_index_bytes,optimal_positions,optimal_chain_nodes,optimal_prefix_rejections,optimal_bound_rejections,optimal_prefix_mismatch_histogram,optimal_bound_length_histogram,optimal_bound_distance_cost_histogram,optimal_bound_slack_histogram,optimal_length_extension_histogram,optimal_match_length_calls,optimal_valid_match_candidates,optimal_length_choices_built,optimal_candidate_budget_stops,lazy_plan_ns,lazy_command_ns,lazy_wire_ns,optimal_plan_ns,optimal_index_ns,optimal_search_ns,optimal_reconstruct_ns,optimal_command_ns,optimal_wire_ns,selection_ns,total_ns,stage_ns,unaccounted_ns,{s}\n",
        .{benchmark_provenance.csv_columns},
    );
    for (cases) |case| try writeCase(init, reference, &csv.writer, case, options.iterations, provenance);

    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
    } else {
        var buffer: [4096]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn writeCase(init: std.process.Init, reference: libbrotli.Runtime, writer: *std.Io.Writer, case: Case, iterations: usize, provenance: benchmark_provenance.Info) !void {
    const expected = try vort.brEncodePlannedStreamRatioAlloc(init.gpa, case.payload);
    defer init.gpa.free(expected);
    const decoded = try vort.brDecodeStreamAllocExactSize(init.gpa, expected, case.payload.len);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, decoded, case.payload)) return error.SizeMismatch;
    try reference.decode(expected, decoded);
    if (!std.mem.eql(u8, decoded, case.payload)) return error.SizeMismatch;

    var aggregate: vort.BrotliRatioEncodeProfile = .{};
    var shape: ?vort.BrotliRatioEncodeProfile = null;
    for (0..iterations) |_| {
        var current: vort.BrotliRatioEncodeProfile = .{};
        const encoded = try vort.brProfilePlannedRatioBlockAlloc(init.gpa, case.payload, init.io, &current);
        defer init.gpa.free(encoded);
        if (!std.mem.eql(u8, expected, encoded)) return error.SizeMismatch;
        if (shape) |prior| try expectSameShape(prior, current) else shape = current;
        addTimings(&aggregate, current);
    }
    const fixed = shape.?;
    const stage_ns = aggregate.stageNs();
    if (stage_ns > aggregate.total_ns) return error.InvalidBlockPlan;
    const input_sha256 = benchmark_provenance.sha256Hex(case.payload);
    const encoded_sha256 = benchmark_provenance.sha256Hex(expected);
    try writer.print(
        "{s},{x},{d},{s},{s},{d},{d},{d},{d},{d},{d},{d}",
        .{
            case.name,           reference.version(), fixed.input_bytes,                     &input_sha256,
            &encoded_sha256,     iterations,          fixed.selected_bytes,                  fixed.lazy_bytes,
            fixed.optimal_bytes, fixed.stored_bytes,  @intFromBool(fixed.optimal_attempted), @intFromBool(fixed.optimal_selected),
        },
    );
    try writer.print(",{d},{d},{d},{d},{d},{d},{d},{d}", .{
        fixed.lazy_token_count, fixed.lazy_literal_count, fixed.lazy_match_count,           fixed.lazy_matched_bytes,
        fixed.lazy_fixed_bits,  fixed.lazy_command_count, fixed.lazy_recent_distance_count, fixed.lazy_last_distance_count,
    });
    try writer.print(",{d},{d},{d},{d},{d},{d},{d},{d}", .{
        fixed.optimal_token_count, fixed.optimal_literal_count, fixed.optimal_match_count,           fixed.optimal_matched_bytes,
        fixed.optimal_fixed_bits,  fixed.optimal_command_count, fixed.optimal_recent_distance_count, fixed.optimal_last_distance_count,
    });
    try writer.print(",{d},{d},{d},{d},{d}", .{
        fixed.optimal_index_bytes,       fixed.optimal_positions,        fixed.optimal_chain_nodes,
        fixed.optimal_prefix_rejections, fixed.optimal_bound_rejections,
    });
    try writer.writeByte(',');
    try writeHistogram(writer, &fixed.optimal_prefix_mismatch_histogram);
    try writer.writeByte(',');
    try writeHistogram(writer, &fixed.optimal_bound_length_histogram);
    try writer.writeByte(',');
    try writeHistogram(writer, &fixed.optimal_bound_distance_cost_histogram);
    try writer.writeByte(',');
    try writeHistogram(writer, &fixed.optimal_bound_slack_histogram);
    try writer.writeByte(',');
    try writeHistogram(writer, &fixed.optimal_length_extension_histogram);
    try writer.print(
        ",{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}",
        .{
            fixed.optimal_match_length_calls, fixed.optimal_valid_match_candidates, fixed.optimal_length_choices_built, fixed.optimal_candidate_budget_stops,
            aggregate.lazy_plan_ns,           aggregate.lazy_command_ns,            aggregate.lazy_wire_ns,             aggregate.optimal_plan_ns,
            aggregate.optimal_index_ns,       aggregate.optimal_search_ns,          aggregate.optimal_reconstruct_ns,   aggregate.optimal_command_ns,
            aggregate.optimal_wire_ns,        aggregate.selection_ns,               aggregate.total_ns,                 stage_ns,
            aggregate.total_ns - stage_ns,
        },
    );
    try provenance.writeCsvFields(writer);
    try writer.writeByte('\n');
}

fn expectSameShape(expected: vort.BrotliRatioEncodeProfile, actual: vort.BrotliRatioEncodeProfile) !void {
    inline for (.{
        "input_bytes",                  "lazy_token_count",               "lazy_literal_count",         "lazy_match_count",              "lazy_matched_bytes",
        "lazy_fixed_bits",              "lazy_command_count",             "lazy_recent_distance_count", "lazy_last_distance_count",      "lazy_bytes",
        "optimal_attempted",            "optimal_token_count",            "optimal_match_count",        "optimal_command_count",         "optimal_bytes",
        "optimal_literal_count",        "optimal_matched_bytes",          "optimal_fixed_bits",         "optimal_recent_distance_count", "optimal_last_distance_count",
        "optimal_selected",             "stored_bytes",                   "selected_bytes",             "optimal_index_bytes",           "optimal_positions",
        "optimal_chain_nodes",          "optimal_prefix_rejections",      "optimal_bound_rejections",   "optimal_match_length_calls",    "optimal_valid_match_candidates",
        "optimal_length_choices_built", "optimal_candidate_budget_stops",
    }) |field| if (@field(expected, field) != @field(actual, field)) return error.ProfileShapeMismatch;
    if (!std.mem.eql(usize, &expected.optimal_prefix_mismatch_histogram, &actual.optimal_prefix_mismatch_histogram) or
        !std.mem.eql(usize, &expected.optimal_bound_length_histogram, &actual.optimal_bound_length_histogram) or
        !std.mem.eql(usize, &expected.optimal_bound_distance_cost_histogram, &actual.optimal_bound_distance_cost_histogram) or
        !std.mem.eql(usize, &expected.optimal_bound_slack_histogram, &actual.optimal_bound_slack_histogram) or
        !std.mem.eql(usize, &expected.optimal_length_extension_histogram, &actual.optimal_length_extension_histogram)) return error.ProfileShapeMismatch;
}

fn writeHistogram(writer: *std.Io.Writer, histogram: []const usize) !void {
    for (histogram, 0..) |count, index| {
        if (index != 0) try writer.writeByte(';');
        try writer.print("{d}", .{count});
    }
}

fn addTimings(total: *vort.BrotliRatioEncodeProfile, sample: vort.BrotliRatioEncodeProfile) void {
    inline for (.{
        "lazy_plan_ns",      "lazy_command_ns",        "lazy_wire_ns",       "optimal_plan_ns", "optimal_index_ns",
        "optimal_search_ns", "optimal_reconstruct_ns", "optimal_command_ns", "optimal_wire_ns", "selection_ns",
        "total_ns",
    }) |field| @field(total, field) +%= @field(sample, field);
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
