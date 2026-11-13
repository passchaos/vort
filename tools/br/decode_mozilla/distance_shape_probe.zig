//! One-off diagnostic: capture the header-only distance coding plane of every
//! compressed Brotli meta-block (context map shape, inline/packed tree tiers,
//! single-symbol and nine-bit-tail eligibility). It drives the public
//! meta-block diagnostic API, so production decode paths stay untouched, and
//! validates complete output against the plain bytes before reporting.
const std = @import("std");
const builtin = @import("builtin");
const br = @import("br");

const max_file_bytes = 256 * 1024 * 1024;
const usage =
    "distance-shape --input WIRE --plain PLAIN --output JSON\n" ++
    "Reports per-meta-block Brotli distance tree/context-map shape without timing.\n" ++
    "Files are limited to 256 MiB each.\n";

const Options = struct {
    input: []const u8,
    plain: []const u8,
    output: []const u8,
};

pub fn main(init: std.process.Init) void {
    run(init) catch |err| {
        var buffer: [1024]u8 = undefined;
        var stderr = std.Io.File.stderr().writerStreaming(init.io, &buffer);
        stderr.interface.print("distance-shape: {s}\n{s}", .{ @errorName(err), usage }) catch {};
        stderr.interface.flush() catch {};
        std.process.exit(2);
    };
}

fn run(init: std.process.Init) !void {
    if (comptime builtin.os.tag != .linux) return error.LinuxOnly;
    const a = init.gpa;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, a);
    defer args.deinit();
    _ = args.next();
    var arguments: [6][]const u8 = undefined;
    var count: usize = 0;
    while (args.next()) |argument| {
        if (count == arguments.len) return error.ExtraArguments;
        arguments[count] = argument;
        count += 1;
    }
    if (count == 1 and std.mem.eql(u8, arguments[0], "--help")) {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(usage);
        try stdout.interface.flush();
        return;
    }
    const options = try parseOptions(arguments[0..count]);

    const wire = try std.Io.Dir.cwd().readFileAlloc(init.io, options.input, a, .limited(max_file_bytes));
    defer a.free(wire);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, options.plain, a, .limited(max_file_bytes));
    defer a.free(plain);

    var report = try br.diagnoseMetaBlocksAlloc(init.io, a, wire, .{ .capture_distance_shape = true });
    defer report.deinit(a);
    if (!std.mem.eql(u8, report.output, plain)) return error.OutputMismatch;

    var block_reports = std.ArrayList(BlockReport).empty;
    defer block_reports.deinit(a);

    var shape_index: usize = 0;
    for (report.records) |record| {
        if (record.kind != .compressed) continue;
        const shape = report.distance_shapes[shape_index];
        shape_index += 1;
        try block_reports.append(a, .{
            .meta_block_index = shape.meta_block_index,
            .route = if (record.route) |route| @tagName(route) else "unknown",
            .block_type_count = shape.block_type_count,
            .tree_count = shape.tree_count,
            .npostfix = shape.npostfix,
            .ndirect = shape.ndirect,
            .distinct_tree_histogram = shape.distinct_tree_histogram,
            .referenced_tree_count = shape.referenced_tree_count,
            .referenced_inline_count = shape.referenced_inline_count,
            .referenced_packed_count = shape.referenced_packed_count,
            .referenced_single_symbol_count = shape.referenced_single_symbol_count,
            .referenced_tail9_ineligible_count = shape.referenced_tail9_ineligible_count,
            .packed_context_slots = shape.packed_context_slots,
            .packed_context3_rows = shape.packed_context3_rows,
            .tree_max_bits_histogram = shape.tree_max_bits_histogram,
            .distance_context_histogram = .{
                record.stats.distance_context_histogram[0],
                record.stats.distance_context_histogram[1],
                record.stats.distance_context_histogram[2],
                record.stats.distance_context_histogram[3],
            },
        });
    }
    if (shape_index != report.distance_shapes.len) return error.ShapeRecordMismatch;

    const aggregate = aggregateShapes(report.distance_shapes, block_reports.items);
    const out_report = .{
        .schema = "vort.brotli.distance-shape.v2",
        .diagnostic = true,
        .input_path = options.input,
        .plain_path = options.plain,
        .wire_bytes = wire.len,
        .plain_bytes = plain.len,
        .compressed_meta_blocks = report.distance_shapes.len,
        .output_validated_against_plain = true,
        .blocks = block_reports.items,
        .aggregate = aggregate,
        .build = .{
            .mode = @tagName(builtin.mode),
            .target_arch = @tagName(builtin.cpu.arch),
            .target_cpu_model = builtin.cpu.model.name,
            .pointer_bits = @bitSizeOf(usize),
        },
        .interpretation = .{
            .timing_included = false,
            .production_decode_changed = false,
            .scope = "Header-only distance plane shape; replay counters and payload routes come from the existing meta-block diagnostic",
        },
    };
    const json = try std.json.Stringify.valueAlloc(a, out_report, .{ .whitespace = .indent_2 });
    defer a.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = options.output, .data = json });
}

const Aggregate = struct {
    distance_block_types: u64 = 0,
    context_slots: u64 = 0,
    packed_context_slots: u64 = 0,
    packed_context3_rows: u64 = 0,
    distinct_tree_histogram: [5]u64 = @splat(0),
    referenced_trees: u64 = 0,
    referenced_inline_trees: u64 = 0,
    referenced_packed_trees: u64 = 0,
    referenced_single_symbol_trees: u64 = 0,
    referenced_tail9_ineligible_trees: u64 = 0,
    tree_max_bits_histogram: [16]u64 = @splat(0),
    distance_context_histogram: [4]u64 = @splat(0),
};

const BlockReport = struct {
    meta_block_index: usize,
    route: []const u8,
    block_type_count: u16,
    tree_count: u16,
    npostfix: u2,
    ndirect: u16,
    distinct_tree_histogram: [5]u32,
    referenced_tree_count: u16,
    referenced_inline_count: u16,
    referenced_packed_count: u16,
    referenced_single_symbol_count: u16,
    referenced_tail9_ineligible_count: u16,
    packed_context_slots: u32,
    packed_context3_rows: u32,
    tree_max_bits_histogram: [16]u32,
    distance_context_histogram: [4]u64,
};

fn aggregateShapes(shapes: []const br.DecodeDistanceBlockShape, blocks: []const BlockReport) Aggregate {
    var total: Aggregate = .{};
    for (shapes) |shape| {
        total.distance_block_types += shape.block_type_count;
        total.context_slots += @as(u64, shape.block_type_count) * 4;
        total.packed_context_slots += shape.packed_context_slots;
        total.packed_context3_rows += shape.packed_context3_rows;
        for (shape.distinct_tree_histogram, 0..) |value, index| {
            total.distinct_tree_histogram[index] += value;
        }
        total.referenced_trees += shape.referenced_tree_count;
        total.referenced_inline_trees += shape.referenced_inline_count;
        total.referenced_packed_trees += shape.referenced_packed_count;
        total.referenced_single_symbol_trees += shape.referenced_single_symbol_count;
        total.referenced_tail9_ineligible_trees += shape.referenced_tail9_ineligible_count;
        for (shape.tree_max_bits_histogram, 0..) |value, bits| {
            total.tree_max_bits_histogram[bits] += value;
        }
    }
    for (blocks) |block| {
        for (block.distance_context_histogram, 0..) |value, context| {
            total.distance_context_histogram[context] += value;
        }
    }
    return total;
}

fn parseOptions(arguments: []const []const u8) !Options {
    const Field = enum { input, plain, output };
    var seen = std.EnumSet(Field).initEmpty();
    var input: ?[]const u8 = null;
    var plain: ?[]const u8 = null;
    var output: ?[]const u8 = null;
    var i: usize = 0;
    while (i < arguments.len) : (i += 2) {
        const flag = arguments[i];
        if (!std.mem.startsWith(u8, flag, "--")) return error.UnknownOption;
        const field = std.meta.stringToEnum(Field, flag[2..]) orelse return error.UnknownOption;
        if (seen.contains(field)) return error.DuplicateOption;
        seen.insert(field);
        if (i + 1 == arguments.len) return error.MissingOptionValue;
        const value = arguments[i + 1];
        if (value.len == 0 or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidOptionValue;
        if (std.mem.startsWith(u8, value, "--")) return error.MissingOptionValue;
        switch (field) {
            .input => input = value,
            .plain => plain = value,
            .output => output = value,
        }
    }
    return .{
        .input = input orelse return error.MissingInput,
        .plain = plain orelse return error.MissingPlain,
        .output = output orelse return error.MissingOutput,
    };
}

test "distance shape probe accepts explicit options in any order" {
    const options = try parseOptions(&.{ "--output", "report.json", "--plain", "plain", "--input", "wire" });
    try std.testing.expectEqualStrings("wire", options.input);
    try std.testing.expectEqualStrings("plain", options.plain);
    try std.testing.expectEqualStrings("report.json", options.output);
}

test "distance shape probe rejects malformed and missing options" {
    try std.testing.expectError(error.UnknownOption, parseOptions(&.{ "--unknown", "x" }));
    try std.testing.expectError(error.MissingOptionValue, parseOptions(&.{"--input"}));
    try std.testing.expectError(error.InvalidOptionValue, parseOptions(&.{ "--input", "" }));
    try std.testing.expectError(error.DuplicateOption, parseOptions(&.{ "--input", "a", "--input", "b", "--plain", "p", "--output", "o" }));
    try std.testing.expectError(error.MissingPlain, parseOptions(&.{ "--input", "wire", "--output", "out" }));
}
