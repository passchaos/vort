const std = @import("std");
const vort = @import("vort");
const quantum = vort.quantum;
const cab = vort.cab;

// The differential driver owns corpus generation and reference decoding. Every
// codec operation here goes through the same public API available to callers.
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.MissingMode;
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const window_bits = if (args.next()) |value| try std.fmt.parseInt(u5, value, 10) else 18;
    const strategy_name = args.next() orelse "greedy";
    const strategy: quantum.Strategy = if (std.mem.eql(u8, strategy_name, "greedy"))
        .greedy
    else if (std.mem.eql(u8, strategy_name, "literals"))
        .literals
    else
        return error.InvalidStrategy;
    const max_distance = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else std.math.maxInt(usize);
    const hash_log = if (args.next()) |value| try std.fmt.parseInt(u8, value, 10) else 15;
    if (args.next() != null) return error.TooManyArguments;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(input);
    const options: quantum.Options = .{
        .window_bits = window_bits,
        .strategy = strategy,
        .hash_log = hash_log,
        .max_match_distance = max_distance,
    };
    var result = try quantum.encodeWithSummaryAlloc(init.gpa, input, options);
    defer result.deinit(init.gpa);
    const restored = try quantum.decodeAlloc(init.gpa, result.bytes, input.len, window_bits);
    defer init.gpa.free(restored);
    if (!std.mem.eql(u8, input, restored)) return error.SizeMismatch;

    var parts: usize = 0;
    var encoded_len: usize = result.bytes.len;
    if (std.mem.eql(u8, mode, "raw")) {
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = result.bytes });
    } else if (std.mem.eql(u8, mode, "cab")) {
        const encoded = try cab.encodeAlloc(init.gpa, &.{.{ .name = "payload.bin", .data = input }}, .{
            .compression = .quantum,
            .quantum_window_bits = window_bits,
            .quantum_strategy = strategy,
            .quantum_hash_log = hash_log,
            .quantum_max_match_distance = max_distance,
        });
        defer init.gpa.free(encoded);
        const unpacked = try cab.extractByNameAlloc(init.gpa, try cab.parse(encoded), "payload.bin");
        defer init.gpa.free(unpacked);
        if (!std.mem.eql(u8, input, unpacked)) return error.SizeMismatch;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
        encoded_len = encoded.len;
    } else if (std.mem.eql(u8, mode, "cab-set")) {
        var set = try cab.encodeSetAlloc(init.gpa, &.{.{ .name = "payload.bin", .data = input }}, .{
            .cabinet = .{
                .compression = .quantum,
                .quantum_window_bits = window_bits,
                .quantum_strategy = strategy,
                .quantum_hash_log = hash_log,
                .quantum_max_match_distance = max_distance,
            },
            .max_cabinet_size = 2048,
        });
        defer set.deinit(init.gpa);
        const archives = try init.gpa.alloc(cab.Archive, set.parts.len);
        defer init.gpa.free(archives);
        for (archives, set.parts) |*archive, part| archive.* = try cab.parse(part.bytes);
        const parsed_set = try cab.initSet(archives);
        const unpacked = try parsed_set.extractByNameAlloc(init.gpa, "payload.bin");
        defer init.gpa.free(unpacked);
        if (!std.mem.eql(u8, input, unpacked)) return error.SizeMismatch;
        try std.Io.Dir.cwd().createDirPath(init.io, output_path);
        encoded_len = 0;
        for (set.parts) |part| {
            const path = try std.fs.path.join(init.gpa, &.{ output_path, part.name });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = part.bytes });
            encoded_len += part.bytes.len;
        }
        parts = set.parts.len;
    } else if (std.mem.eql(u8, mode, "limits")) {
        try checkLimits(init.gpa, input, options, result.bytes, result.peak_working_bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = result.bytes });
    } else return error.InvalidMode;

    const summary = result.summary;
    std.debug.print(
        "{{\"input\":{d},\"encoded\":{d},\"raw_encoded\":{d},\"parts\":{d},\"peak_working_bytes\":{d}," ++
            "\"literals\":{d},\"fixed3_matches\":{d},\"fixed4_matches\":{d},\"variable_matches\":{d}," ++
            "\"matched_bytes\":{d},\"max_offset\":{d},\"extra_bits\":{d},\"literal_reference_frames\":{d}}}\n",
        .{ input.len, encoded_len, result.bytes.len, parts, result.peak_working_bytes, summary.literals, summary.fixed3_matches, summary.fixed4_matches, summary.variable_matches, summary.matched_bytes, summary.max_offset, summary.extra_bits, summary.literal_reference_frames },
    );
}

fn checkLimits(allocator: std.mem.Allocator, input: []const u8, options: quantum.Options, expected: []const u8, peak_working_bytes: usize) !void {
    if (input.len == 0 or expected.len == 0) return error.MissingLimitInput;
    var constrained = options;
    constrained.max_output_len = expected.len - 1;
    try expectEncodeFailure(allocator, input, constrained, error.OutputLimitExceeded);
    constrained.max_output_len = expected.len;
    const exact = try quantum.encodeAlloc(allocator, input, constrained);
    defer allocator.free(exact);
    if (!std.mem.eql(u8, expected, exact)) return error.ExactOutputLimitMismatch;
    constrained = options;
    constrained.max_working_memory = 0;
    try expectEncodeFailure(allocator, input, constrained, error.WorkingMemoryLimitExceeded);
    if (peak_working_bytes == 0) return error.MissingWorkingMemoryAccounting;
    constrained.max_working_memory = peak_working_bytes - 1;
    try expectEncodeFailure(allocator, input, constrained, error.WorkingMemoryLimitExceeded);
    constrained.max_working_memory = peak_working_bytes;
    const budgeted = try quantum.encodeAlloc(allocator, input, constrained);
    defer allocator.free(budgeted);
    if (!std.mem.eql(u8, expected, budgeted)) return error.ExactWorkingLimitMismatch;
    constrained = options;
    constrained.window_bits = 9;
    try expectEncodeFailure(allocator, input, constrained, error.InvalidBlockPlan);
    constrained.window_bits = 22;
    try expectEncodeFailure(allocator, input, constrained, error.InvalidBlockPlan);
    constrained = options;
    constrained.hash_log = 7;
    try expectEncodeFailure(allocator, input, constrained, error.InvalidBlockPlan);
    constrained.hash_log = 21;
    try expectEncodeFailure(allocator, input, constrained, error.InvalidBlockPlan);
    constrained = options;
    constrained.max_match_distance = 0;
    try expectEncodeFailure(allocator, input, constrained, error.InvalidBlockPlan);
    const guard = try allocator.alloc(u8, expected.len + 16);
    defer allocator.free(guard);
    @memset(guard, 0xa5);
    const short = guard[8 .. 8 + expected.len - 1];
    if (quantum.encodeInto(allocator, input, short, options)) |_| {
        return error.UnexpectedShortOutputSuccess;
    } else |err| if (err != error.OutputTooSmall) return err;
    for (guard) |byte| if (byte != 0xa5) return error.CallerOutputModified;
    const written = try quantum.encodeInto(allocator, input, guard[8 .. 8 + expected.len], options);
    if (written != expected.len or !std.mem.eql(u8, expected, guard[8 .. 8 + expected.len])) return error.CallerOutputMismatch;
    for (guard[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
    for (guard[8 + expected.len ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    constrained = options;
    constrained.max_output_len = expected.len - 1;
    if (quantum.encodeAppend(allocator, &appended, input, constrained)) |_| {
        return error.UnexpectedAppendSuccess;
    } else |err| if (err != error.OutputLimitExceeded) return err;
    if (!std.mem.eql(u8, appended.items, "prefix:")) return error.CallerAppendModified;
    if (try quantum.encodeAppend(allocator, &appended, input, options) != expected.len or
        !std.mem.eql(u8, appended.items["prefix:".len..], expected)) return error.CallerAppendMismatch;
}

fn expectEncodeFailure(allocator: std.mem.Allocator, input: []const u8, options: quantum.Options, expected_error: anyerror) !void {
    if (quantum.encodeAlloc(allocator, input, options)) |encoded| {
        allocator.free(encoded);
        return error.UnexpectedLimitSuccess;
    } else |err| if (err != expected_error) return err;
}
