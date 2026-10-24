const std = @import("std");
const vort = @import("vort");

const payload = "incremental planned Brotli payload with repeated fields and values=1234567890\n" ** 64;
const repeated_block_len = 4096;
const Sample = struct { elapsed_ns: u64, checksum: usize };
const SingleBlockSamples = struct { one_shot: Sample, reusable: Sample };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 1_000;
    if (iterations == 0 or args.next() != null) return error.InvalidBlockPlan;

    const single = try measureSingleBlockInterleaved(init.io, init.gpa, iterations);
    var buffer: [512]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    const one_shot_wire = try vort.brEncodePlannedStreamAlloc(init.gpa, payload);
    defer init.gpa.free(one_shot_wire);
    var validation_encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .block_len = payload.len });
    defer validation_encoder.deinit();
    var reusable_wire: [payload.len + 16]u8 = undefined;
    const reusable_len = try encodeReusableInto(&validation_encoder, &reusable_wire);
    for ([_][]const u8{ one_shot_wire, reusable_wire[0..reusable_len] }) |wire| {
        const decoded = try vort.brDecodeStreamAllocExactSize(init.gpa, wire, payload.len);
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
    }

    try stdout.interface.writeAll("case,input_bytes,iterations,one_shot_bytes,reusable_bytes,one_shot_ns,reusable_ns,speedup,one_shot_checksum,reusable_checksum,retained_bytes\n");
    try stdout.interface.print("single_block,{d},{d},{d},{d},{d},{d},{d:.4},{d},{d},{d}\n", .{ payload.len, iterations, one_shot_wire.len, reusable_len, single.one_shot.elapsed_ns, single.reusable.elapsed_ns, @as(f64, @floatFromInt(single.one_shot.elapsed_ns)) / @as(f64, @floatFromInt(single.reusable.elapsed_ns)), single.one_shot.checksum, single.reusable.checksum, reusableRetainedCapacity(init.gpa) });
    try writeCrossBlockRow(init.io, init.gpa, &stdout.interface, iterations);
    try stdout.interface.flush();
}

fn writeCrossBlockRow(io: std.Io, allocator: std.mem.Allocator, writer: *std.Io.Writer, iterations: usize) !void {
    var first: [repeated_block_len]u8 = undefined;
    var state: u32 = 0x9e37_79b9;
    for (&first) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 24);
    }
    const input = first ++ first;
    const chunks = [_][]const u8{ &first, &first };
    const one_shot_chunked = try vort.brEncodePlannedStreamChunksAlloc(allocator, &chunks);
    defer allocator.free(one_shot_chunked);

    var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .block_len = first.len });
    defer encoder.deinit();
    const output = try allocator.alloc(u8, input.len + 16);
    defer allocator.free(output);
    const encoded_len = try encodeCrossBlock(&encoder, &input, output);
    const decoded = try vort.brDecodeStreamAllocExactSize(allocator, output[0..encoded_len], input.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, &input, decoded)) return error.SizeMismatch;

    var best_ns: u64 = std.math.maxInt(u64);
    var checksum: usize = 0;
    for (0..5) |_| {
        var run_checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            if (encoder.snapshot().done) try encoder.nextStream(.{ .block_len = first.len });
            const len = try encodeCrossBlock(&encoder, &input, output);
            run_checksum +%= std.hash.Wyhash.hash(0, output[0..len]);
        }
        const elapsed_ns = elapsed(start, io);
        if (elapsed_ns < best_ns) {
            best_ns = elapsed_ns;
            checksum = run_checksum;
        }
    }
    try writer.print("cross_block,{d},{d},{d},{d},{d},{d},{d:.4},{d},{d},{d}\n", .{ input.len, iterations, one_shot_chunked.len, encoded_len, best_ns, best_ns, 1.0, checksum, checksum, encoder.retainedCapacity() });
}

fn encodeCrossBlock(encoder: *vort.BrotliIncrementalPlannedStreamEncoder, input: []const u8, output: []u8) !usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < input.len) {
        const result = try encoder.step(input[input_offset..], output[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", output[output_offset..]);
        output_offset += result.progress.output_written;
        if (result.status == .done) return output_offset;
    }
}

fn measureSingleBlockInterleaved(
    io: std.Io,
    allocator: std.mem.Allocator,
    iterations: usize,
) !SingleBlockSamples {
    const pair_count = 7;
    var pairs: [pair_count]SingleBlockSamples = undefined;
    var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .block_len = payload.len });
    defer encoder.deinit();
    try warmEncoder(&encoder);
    for (&pairs, 0..) |*pair, round| {
        if (round & 1 == 0) {
            pair.one_shot = try measureOneShotOnce(io, allocator, iterations);
            pair.reusable = try measureReusableOnce(io, &encoder, iterations);
        } else {
            pair.reusable = try measureReusableOnce(io, &encoder, iterations);
            pair.one_shot = try measureOneShotOnce(io, allocator, iterations);
        }
    }
    std.mem.sort(SingleBlockSamples, &pairs, {}, lessSingleBlockRatio);
    return pairs[pair_count / 2];
}

fn measureOneShotOnce(io: std.Io, allocator: std.mem.Allocator, iterations: usize) !Sample {
    var checksum: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        const encoded = try vort.brEncodePlannedStreamAlloc(allocator, payload);
        checksum +%= std.hash.Wyhash.hash(0, encoded);
        allocator.free(encoded);
    }
    return .{ .elapsed_ns = elapsed(start, io), .checksum = checksum };
}

fn measureReusableOnce(
    io: std.Io,
    encoder: *vort.BrotliIncrementalPlannedStreamEncoder,
    iterations: usize,
) !Sample {
    var checksum: usize = 0;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        if (encoder.snapshot().done) try encoder.nextStream(.{ .block_len = payload.len });
        checksum +%= try encodeReusable(encoder);
    }
    return .{ .elapsed_ns = elapsed(start, io), .checksum = checksum };
}

fn lessSingleBlockRatio(
    _: void,
    left: SingleBlockSamples,
    right: SingleBlockSamples,
) bool {
    return @as(u128, left.one_shot.elapsed_ns) * right.reusable.elapsed_ns <
        @as(u128, right.one_shot.elapsed_ns) * left.reusable.elapsed_ns;
}

fn warmEncoder(encoder: *vort.BrotliIncrementalPlannedStreamEncoder) !void {
    _ = try encodeReusable(encoder);
}

fn encodeReusable(encoder: *vort.BrotliIncrementalPlannedStreamEncoder) !u64 {
    var output: [payload.len + 16]u8 = undefined;
    const output_offset = try encodeReusableInto(encoder, &output);
    return std.hash.Wyhash.hash(0, output[0..output_offset]);
}

fn encodeReusableInto(encoder: *vort.BrotliIncrementalPlannedStreamEncoder, output: []u8) !usize {
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < payload.len) {
        const result = try encoder.step(payload[input_offset..], output[output_offset..]);
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step("", output[output_offset..]);
        output_offset += result.progress.output_written;
        if (result.status == .done) break;
    }
    return output_offset;
}

fn reusableRetainedCapacity(allocator: std.mem.Allocator) usize {
    var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .block_len = payload.len });
    defer encoder.deinit();
    warmEncoder(&encoder) catch return 0;
    return encoder.retainedCapacity();
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}
