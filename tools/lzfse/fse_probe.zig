const std = @import("std");
const lzfse = @import("lzfse");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.MissingMode;
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(64 * 1024 * 1024));
    defer init.gpa.free(input);
    if (std.mem.eql(u8, mode, "decode")) {
        const expected = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLength, 10);
        if (args.next() != null) return error.TooManyArguments;
        const plain = try lzfse.decodeAllocLimited(init.gpa, input, expected);
        defer init.gpa.free(plain);
        if (plain.len != expected) return error.SizeMismatch;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = plain });
        std.debug.print("{{\"input\":{d},\"decoded\":{d}}}\n", .{ input.len, plain.len });
        return;
    }
    if (std.mem.eql(u8, mode, "plan")) {
        const version = try parseVersion(args.next() orelse "v2");
        if (args.next() != null) return error.TooManyArguments;
        return encodePlan(init, input, output_path, version);
    }
    const strategy_name = args.next() orelse "default";
    const version = try parseVersion(args.next() orelse "v2");
    const block_size = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 65536;
    const hash_log = if (args.next()) |value| try std.fmt.parseInt(u8, value, 10) else 15;
    const distance = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 262139;
    if (args.next() != null) return error.TooManyArguments;
    var options: lzfse.Options = .{ .block_size = block_size, .fse_version = version, .hash_log = hash_log, .max_match_distance = distance };
    if (std.mem.eql(u8, strategy_name, "legacy-stored")) {
        options.use_lzvn = false;
    } else if (std.mem.eql(u8, strategy_name, "override-fse")) {
        options.use_lzvn = false;
        options.strategy = .fse;
    } else if (!std.mem.eql(u8, strategy_name, "default")) {
        options.strategy = if (std.mem.eql(u8, strategy_name, "auto")) .auto else if (std.mem.eql(u8, strategy_name, "fse")) .fse else if (std.mem.eql(u8, strategy_name, "lzvn")) .lzvn else if (std.mem.eql(u8, strategy_name, "stored")) .stored else return error.InvalidStrategy;
    }
    var encoded = try lzfse.encodeWithSummaryAlloc(init.gpa, input, options);
    defer encoded.deinit(init.gpa);
    const plain = try lzfse.decodeAllocLimited(init.gpa, encoded.bytes, input.len);
    defer init.gpa.free(plain);
    if (!std.mem.eql(u8, input, plain)) return error.SizeMismatch;
    var allocation_failures: usize = 0;
    if (std.mem.eql(u8, mode, "limits")) {
        try checkLimits(init.gpa, input, options, encoded.bytes, encoded.peak_working_bytes);
    } else if (std.mem.eql(u8, mode, "oom")) {
        allocation_failures = try checkAllocationFailures(init.gpa, input, options, encoded.bytes);
    } else if (!std.mem.eql(u8, mode, "encode")) return error.InvalidMode;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded.bytes });
    printSummary(input.len, encoded.bytes.len, encoded.summary, encoded.peak_working_bytes, allocation_failures);
}

fn parseVersion(value: []const u8) !lzfse.FseVersion {
    return if (std.mem.eql(u8, value, "v1")) .v1 else if (std.mem.eql(u8, value, "v2")) .v2 else error.InvalidVersion;
}

fn printSummary(input_len: usize, encoded_len: usize, summary: lzfse.Summary, peak: usize, allocation_failures: usize) void {
    std.debug.print(
        "{{\"input\":{d},\"encoded\":{d},\"peak_working_bytes\":{d},\"allocation_failure_cases\":{d}," ++
            "\"stored_blocks\":{d},\"lzvn_blocks\":{d},\"fse_v1_blocks\":{d},\"fse_v2_blocks\":{d}," ++
            "\"fse_literal_bytes\":{d},\"fse_matched_bytes\":{d},\"fse_records\":{d}," ++
            "\"max_fse_distance\":{d},\"max_fse_match_length\":{d}," ++
            "\"fse_literal_payload_bytes\":{d},\"fse_lmd_payload_bytes\":{d}}}\n",
        .{ input_len, encoded_len, peak, allocation_failures, summary.stored_blocks, summary.lzvn_blocks, summary.fse_v1_blocks, summary.fse_v2_blocks, summary.fse_literal_bytes, summary.fse_matched_bytes, summary.fse_records, summary.max_fse_distance, summary.max_fse_match_length, summary.fse_literal_payload_bytes, summary.fse_lmd_payload_bytes },
    );
}

// The Python corpus writes LFSP, three little-endian u32 lengths, prefix,
// unpadded literals, then (u16 L, u16 M, u32 D) records. This transport belongs
// only to the harness; Plan validation and block serialization use public APIs.
fn encodePlan(init: std.process.Init, data: []const u8, output_path: []const u8, version: lzfse.FseVersion) !void {
    if (data.len < 16 or !std.mem.eql(u8, data[0..4], "LFSP")) return error.InvalidPlanInput;
    const prefix_len: usize = std.mem.readInt(u32, data[4..8], .little);
    const literal_len: usize = std.mem.readInt(u32, data[8..12], .little);
    const record_count: usize = std.mem.readInt(u32, data[12..16], .little);
    if (prefix_len > data.len - 16 or literal_len > data.len - 16 - prefix_len or
        record_count > (data.len - 16 - prefix_len - literal_len) / 8 or
        data.len - 16 - prefix_len - literal_len != record_count * 8) return error.InvalidPlanInput;
    const prefix = data[16 .. 16 + prefix_len];
    const literals = data[16 + prefix_len ..][0..literal_len];
    var plan = lzfse.EncodePlan.init(prefix.len);
    defer plan.deinit(init.gpa);
    try plan.literals.appendSlice(init.gpa, literals);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(init.gpa);
    try expected.appendSlice(init.gpa, prefix);
    var literal_position: usize = 0;
    var max_distance: usize = 0;
    var max_match: usize = 0;
    for (0..record_count) |index| {
        const record = data[16 + prefix_len + literal_len + index * 8 ..][0..8];
        const l = std.mem.readInt(u16, record[0..2], .little);
        const m = std.mem.readInt(u16, record[2..4], .little);
        const d = std.mem.readInt(u32, record[4..8], .little);
        if (l > literals.len - literal_position or (m != 0 and (d == 0 or d > expected.items.len + l))) return error.InvalidPlanInput;
        try plan.records.append(init.gpa, .{ .literal_len = l, .match_len = m, .distance = d });
        plan.raw_size = try std.math.add(usize, plan.raw_size, @as(usize, l) + m);
        try expected.appendSlice(init.gpa, literals[literal_position..][0..l]);
        literal_position += l;
        for (0..m) |_| {
            const byte = expected.items[expected.items.len - d];
            try expected.append(init.gpa, byte);
        }
        if (m != 0) {
            max_distance = @max(max_distance, d);
            max_match = @max(max_match, m);
        }
    }
    if (literal_position != literals.len) return error.InvalidPlanInput;
    try plan.validate();
    var block = try lzfse.encodeFsePlanAlloc(init.gpa, &plan, version);
    defer block.deinit(init.gpa);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(init.gpa);
    if (prefix.len != 0) {
        try stream.appendSlice(init.gpa, "bvx-");
        var length: [4]u8 = undefined;
        std.mem.writeInt(u32, &length, @intCast(prefix.len), .little);
        try stream.appendSlice(init.gpa, &length);
        try stream.appendSlice(init.gpa, prefix);
    }
    try stream.appendSlice(init.gpa, block.bytes);
    try stream.appendSlice(init.gpa, "bvx$");
    const plain = try lzfse.decodeAllocLimited(init.gpa, stream.items, expected.items.len);
    defer init.gpa.free(plain);
    if (!std.mem.eql(u8, expected.items, plain)) return error.SizeMismatch;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = stream.items });
    const summary: lzfse.Summary = .{
        .stored_blocks = @intFromBool(prefix.len != 0),
        .fse_v1_blocks = @intFromBool(version == .v1),
        .fse_v2_blocks = @intFromBool(version == .v2),
        .fse_literal_bytes = literals.len,
        .fse_matched_bytes = plan.raw_size - literals.len,
        .fse_records = plan.records.items.len,
        .max_fse_distance = max_distance,
        .max_fse_match_length = max_match,
        .fse_literal_payload_bytes = block.literal_payload_size,
        .fse_lmd_payload_bytes = block.lmd_payload_size,
    };
    printSummary(expected.items.len, stream.items.len, summary, 0, 0);
}

fn checkLimits(allocator: std.mem.Allocator, input: []const u8, options: lzfse.Options, expected: []const u8, peak: usize) !void {
    if (input.len == 0 or peak == 0) return error.MissingLimitInput;
    var limited = options;
    limited.max_output_len = expected.len - 1;
    try expectEncodeError(allocator, input, limited, error.OutputLimitExceeded);
    limited.max_output_len = expected.len;
    const exact = try lzfse.encodeAlloc(allocator, input, limited);
    defer allocator.free(exact);
    if (!std.mem.eql(u8, expected, exact)) return error.ExactOutputLimitMismatch;
    limited = options;
    limited.max_working_memory = peak - 1;
    try expectEncodeError(allocator, input, limited, error.WorkingMemoryLimitExceeded);
    limited.max_working_memory = peak;
    const budgeted = try lzfse.encodeAlloc(allocator, input, limited);
    defer allocator.free(budgeted);
    if (!std.mem.eql(u8, expected, budgeted)) return error.ExactWorkingLimitMismatch;
    limited = options;
    limited.block_size = 0;
    try expectEncodeError(allocator, input, limited, error.InvalidLzfseStream);
    limited = options;
    limited.hash_log = 7;
    try expectEncodeError(allocator, input, limited, error.InvalidLzfseStream);
    limited.hash_log = 21;
    try expectEncodeError(allocator, input, limited, error.InvalidLzfseStream);
    limited = options;
    limited.max_match_distance = 0;
    try expectEncodeError(allocator, input, limited, error.InvalidLzfseStream);
    const guard = try allocator.alloc(u8, expected.len + 16);
    defer allocator.free(guard);
    @memset(guard, 0xa5);
    if (lzfse.encodeInto(allocator, input, options, guard[8 .. 8 + expected.len - 1])) |_| {
        return error.UnexpectedShortOutputSuccess;
    } else |err| if (err != error.OutputTooSmall) return err;
    for (guard) |byte| if (byte != 0xa5) return error.CallerOutputModified;
    if (try lzfse.encodeInto(allocator, input, options, guard[8 .. 8 + expected.len]) != expected.len or
        !std.mem.eql(u8, expected, guard[8 .. 8 + expected.len])) return error.CallerOutputMismatch;
    for (guard[0..8]) |byte| if (byte != 0xa5) return error.CallerPrefixModified;
    for (guard[8 + expected.len ..]) |byte| if (byte != 0xa5) return error.CallerSuffixModified;
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "prefix:");
    limited = options;
    limited.max_output_len = expected.len - 1;
    if (lzfse.encodeAppend(allocator, &output, input, limited)) |_| {
        return error.UnexpectedAppendSuccess;
    } else |err| if (err != error.OutputLimitExceeded) return err;
    if (!std.mem.eql(u8, output.items, "prefix:")) return error.CallerAppendModified;
    if (try lzfse.encodeAppend(allocator, &output, input, options) != expected.len or
        !std.mem.eql(u8, output.items["prefix:".len..], expected)) return error.CallerAppendMismatch;
}

fn expectEncodeError(allocator: std.mem.Allocator, input: []const u8, options: lzfse.Options, expected_error: anyerror) !void {
    if (lzfse.encodeAlloc(allocator, input, options)) |bytes| {
        allocator.free(bytes);
        return error.UnexpectedLimitSuccess;
    } else |err| if (err != expected_error) return err;
}

fn checkAllocationFailures(backing: std.mem.Allocator, input: []const u8, options: lzfse.Options, expected: []const u8) !usize {
    const guard = try backing.alloc(u8, expected.len + 16);
    defer backing.free(guard);
    for (0..1024) |failure_index| {
        var failing = std.testing.FailingAllocator.init(backing, .{ .fail_index = failure_index });
        @memset(guard, 0xa5);
        if (lzfse.encodeInto(failing.allocator(), input, options, guard[8 .. 8 + expected.len])) |written| {
            if (written != expected.len or !std.mem.eql(u8, expected, guard[8 .. 8 + expected.len])) return error.OomOutputMismatch;
        } else |err| {
            if (err != error.OutOfMemory) return err;
            for (guard) |byte| if (byte != 0xa5) return error.OomCallerOutputModified;
        }
        if (failing.allocated_bytes != failing.freed_bytes) return error.OomAllocationLeak;
        if (!failing.has_induced_failure) return failure_index;
    }
    return error.AllocationFailureWalkLimit;
}
