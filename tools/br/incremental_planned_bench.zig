const std = @import("std");
const vort = @import("vort");

const payload = "incremental planned Brotli payload with repeated fields and values=1234567890\n" ** 64;
const Sample = struct { elapsed_ns: u64, checksum: usize };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |arg| try std.fmt.parseInt(usize, arg, 10) else 1_000;
    if (iterations == 0 or args.next() != null) return error.InvalidBlockPlan;

    const one_shot = try measureOneShot(init.io, init.gpa, iterations);
    const reusable = try measureReusable(init.io, init.gpa, iterations);
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

    try stdout.interface.writeAll("input_bytes,iterations,one_shot_bytes,reusable_bytes,one_shot_ns,reusable_ns,speedup,one_shot_checksum,reusable_checksum,retained_bytes\n");
    try stdout.interface.print("{d},{d},{d},{d},{d},{d},{d:.4},{d},{d},{d}\n", .{ payload.len, iterations, one_shot_wire.len, reusable_len, one_shot.elapsed_ns, reusable.elapsed_ns, @as(f64, @floatFromInt(one_shot.elapsed_ns)) / @as(f64, @floatFromInt(reusable.elapsed_ns)), one_shot.checksum, reusable.checksum, reusableRetainedCapacity(init.gpa) });
    try stdout.interface.flush();
}

fn measureOneShot(io: std.Io, allocator: std.mem.Allocator, iterations: usize) !Sample {
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .checksum = 0 };
    for (0..5) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            const encoded = try vort.brEncodePlannedStreamAlloc(allocator, payload);
            checksum +%= std.hash.Wyhash.hash(0, encoded);
            allocator.free(encoded);
        }
        const elapsed_ns = elapsed(start, io);
        if (elapsed_ns < best.elapsed_ns) best = .{ .elapsed_ns = elapsed_ns, .checksum = checksum };
    }
    return best;
}

fn measureReusable(io: std.Io, allocator: std.mem.Allocator, iterations: usize) !Sample {
    var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .block_len = payload.len });
    defer encoder.deinit();
    try warmEncoder(&encoder);
    var best = Sample{ .elapsed_ns = std.math.maxInt(u64), .checksum = 0 };
    for (0..5) |_| {
        var checksum: usize = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            if (encoder.snapshot().done) try encoder.nextStream(.{ .block_len = payload.len });
            checksum +%= try encodeReusable(&encoder);
        }
        const elapsed_ns = elapsed(start, io);
        if (elapsed_ns < best.elapsed_ns) best = .{ .elapsed_ns = elapsed_ns, .checksum = checksum };
    }
    return best;
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
