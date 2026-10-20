const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |value|
        try std.fmt.parseInt(usize, value, 10)
    else
        3;
    const quality = if (args.next()) |value|
        try std.fmt.parseInt(u4, value, 10)
    else
        10;
    const path = args.next() orelse "src/br.zig";
    const limit = if (args.next()) |value|
        try std.fmt.parseInt(usize, value, 10)
    else
        32 * 1024;
    if (iterations == 0 or quality < 10 or quality > 11 or limit == 0 or
        args.next() != null)
    {
        return error.InvalidBlockPlan;
    }

    var generated: [4096]u8 = undefined;
    const generated_fixture = std.mem.eql(u8, path, "@command-state");
    const input = if (generated_fixture) blk: {
        fillCommandStateFixture(&generated);
        break :blk generated[0..@min(generated.len, limit)];
    } else try readFilePrefixAlloc(init.io, init.gpa, path, limit);
    defer if (!generated_fixture) init.gpa.free(input);
    const baseline = try vort.brEncodePlannedStreamWithOptionsAlloc(
        init.gpa,
        input,
        .{
            .quality = quality,
            .command_state_max_input_kib = 0,
        },
    );
    defer init.gpa.free(baseline);
    var aggregate: vort.BrotliQualityCommandStateProfile = .{};
    var encoded_bytes: ?usize = null;
    var checksum: u64 = 0;
    for (0..iterations) |_| {
        var profile: vort.BrotliQualityCommandStateProfile = .{};
        const encoded = try vort.brProfileQualityCommandStateCandidateAlloc(
            init.gpa,
            input,
            quality,
            .generic,
            init.io,
            &profile,
        );
        if (encoded_bytes) |expected| {
            if (encoded.len != expected) {
                init.gpa.free(encoded);
                return error.SizeMismatch;
            }
        } else encoded_bytes = encoded.len;
        checksum +%= std.hash.Wyhash.hash(0, encoded);
        addProfile(&aggregate, profile);
        init.gpa.free(encoded);
    }

    var buffer: [2048]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll(
        "input_bytes,quality,iterations,baseline_bytes,encoded_bytes,compact_wire_bytes,seed_tokens,seed_commands,state_tokens,state_commands,state_positions,state_states_visited,state_match_candidates,state_match_transitions,state_general_match_transitions,state_recent_match_transitions,state_cost_bound_rejections,state_beam_replacements,seed_plan_ns,seed_command_ns,model_ns,state_index_ns,state_setup_ns,state_search_ns,state_reconstruct_ns,state_plan_ns,state_command_ns,compact_wire_ns,wire_ns,total_ns,accounted_ns,checksum\n",
    );
    try stdout.interface.print(
        "{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n",
        .{
            input.len,
            quality,
            iterations,
            baseline.len,
            encoded_bytes.?,
            aggregate.compact_wire_bytes / iterations,
            aggregate.seed_tokens / iterations,
            aggregate.seed_commands / iterations,
            aggregate.state_tokens / iterations,
            aggregate.state_commands / iterations,
            aggregate.state_positions / iterations,
            aggregate.state_states_visited / iterations,
            aggregate.state_match_candidates / iterations,
            aggregate.state_match_transitions / iterations,
            aggregate.state_general_match_transitions / iterations,
            aggregate.state_recent_match_transitions / iterations,
            aggregate.state_cost_bound_rejections / iterations,
            aggregate.state_beam_replacements / iterations,
            aggregate.seed_plan_ns / iterations,
            aggregate.seed_command_ns / iterations,
            aggregate.model_ns / iterations,
            aggregate.state_index_ns / iterations,
            aggregate.state_setup_ns / iterations,
            aggregate.state_search_ns / iterations,
            aggregate.state_reconstruct_ns / iterations,
            aggregate.state_plan_ns / iterations,
            aggregate.state_command_ns / iterations,
            aggregate.compact_wire_ns / iterations,
            aggregate.wire_ns / iterations,
            aggregate.total_ns / iterations,
            aggregate.accountedNs() / iterations,
            checksum,
        },
    );
    try stdout.interface.flush();
}

fn fillCommandStateFixture(output: *[4096]u8) void {
    var state: u32 = 0x9e37_79b9;
    var position: usize = 0;
    while (position < output.len) {
        state = state *% 1_664_525 +% 1_013_904_223;
        const distances = [_]usize{ 4, 7, 11, 16, 31, 64, 127, 257 };
        const selected_distance = distances[(state >> 16) % distances.len];
        if (position >= selected_distance and state & 3 != 0) {
            const copy_len = @min(output.len - position, 4 + ((state >> 8) % 61));
            for (0..copy_len) |i|
                output[position + i] = output[position + i - selected_distance];
            position += copy_len;
        } else {
            output[position] = @truncate((state >> 24) & 31);
            position += 1;
        }
    }
}

fn addProfile(
    total: *vort.BrotliQualityCommandStateProfile,
    sample: vort.BrotliQualityCommandStateProfile,
) void {
    total.input_bytes = sample.input_bytes;
    total.quality = sample.quality;
    inline for (.{
        "seed_tokens",
        "seed_commands",
        "state_tokens",
        "state_commands",
        "state_positions",
        "state_states_visited",
        "state_match_candidates",
        "state_match_transitions",
        "state_general_match_transitions",
        "state_recent_match_transitions",
        "state_cost_bound_rejections",
        "state_beam_replacements",
        "encoded_bytes",
        "compact_wire_bytes",
        "seed_plan_ns",
        "seed_command_ns",
        "model_ns",
        "state_index_ns",
        "state_setup_ns",
        "state_search_ns",
        "state_reconstruct_ns",
        "state_plan_ns",
        "state_command_ns",
        "compact_wire_ns",
        "wire_ns",
        "total_ns",
    }) |field| @field(total, field) += @field(sample, field);
}

fn readFilePrefixAlloc(
    io: std.Io,
    allocator: std.mem.Allocator,
    path: []const u8,
    limit: usize,
) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    const read_len: usize = @intCast(@min(stat.size, limit));
    if (read_len == 0) return error.InputTooSmall;
    const input = try allocator.alloc(u8, read_len);
    errdefer allocator.free(input);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    if (try reader.interface.readSliceShort(input) != read_len)
        return error.InputTooSmall;
    return input;
}
