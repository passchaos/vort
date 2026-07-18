const std = @import("std");

const Kernel = enum {
    current,
    nonoverlap_first,
    small_unrolled,

    fn label(self: Kernel) []const u8 {
        return switch (self) {
            .current => "current",
            .nonoverlap_first => "nonoverlap_first",
            .small_unrolled => "small_unrolled",
        };
    }
};

const MatchClass = enum {
    rle,
    small_distance,
    non_overlapping,
    overlapping,

    fn label(self: MatchClass) []const u8 {
        return switch (self) {
            .rle => "rle",
            .small_distance => "small_distance",
            .non_overlapping => "non_overlapping",
            .overlapping => "overlapping",
        };
    }
};

const CaseSpec = struct {
    name: []const u8,
    class: MatchClass,
    length: usize,
    distance: usize,
    ops_per_iter: usize,
};

const BenchResult = struct {
    output_bytes: usize,
    elapsed_ns: i128,
    checksum: u64,
};

const kernels = [_]Kernel{ .current, .nonoverlap_first, .small_unrolled };

const cases = [_]CaseSpec{
    .{ .name = "rle-long", .class = .rle, .length = 258, .distance = 1, .ops_per_iter = 1024 },
    .{ .name = "small-distance-long", .class = .small_distance, .length = 258, .distance = 2, .ops_per_iter = 1024 },
    .{ .name = "nonoverlap-len3", .class = .non_overlapping, .length = 3, .distance = 64, .ops_per_iter = 4096 },
    .{ .name = "nonoverlap-len6", .class = .non_overlapping, .length = 6, .distance = 96, .ops_per_iter = 4096 },
    .{ .name = "nonoverlap-len32", .class = .non_overlapping, .length = 32, .distance = 512, .ops_per_iter = 2048 },
    .{ .name = "overlap-text-like", .class = .overlapping, .length = 258, .distance = 45, .ops_per_iter = 1024 },
    .{ .name = "overlap-distance-heavy", .class = .overlapping, .length = 258, .distance = 16, .ops_per_iter = 1024 },
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    var iterations_override: ?usize = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations_override = try std.fmt.parseInt(usize, args.next() orelse return error.MissingReportPath, 10);
            if (iterations_override.? == 0) return error.InvalidBlockPlan;
            continue;
        }
        return error.UnknownArgument;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("case,class,kernel,length,distance,ops_per_iter,iterations,output_bytes,elapsed_ns,output_mib_per_s,checksum\n");

    for (cases) |case| {
        const iterations = iterations_override orelse iterationsFor(case.length, case.ops_per_iter);
        for (kernels) |kernel| {
            const result = try runCase(init, case, kernel, iterations);
            try writeRow(&csv.writer, case, kernel, iterations, result);
        }
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(csv.written());
    try stdout.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn runCase(init: std.process.Init, case: CaseSpec, kernel: Kernel, iterations: usize) !BenchResult {
    const stride = case.distance + case.length + 16;
    const buffer_len = stride * case.ops_per_iter;
    const buffer = try init.gpa.alloc(u8, buffer_len);
    defer init.gpa.free(buffer);
    fillBuffer(buffer, stride, case);

    const verify_current = try init.gpa.dupe(u8, buffer);
    defer init.gpa.free(verify_current);
    const verify_candidate = try init.gpa.dupe(u8, buffer);
    defer init.gpa.free(verify_candidate);
    try runAllOps(verify_current, stride, case, .current);
    try runAllOps(verify_candidate, stride, case, kernel);
    if (!std.mem.eql(u8, verify_current, verify_candidate)) return error.DecodeLengthMismatch;

    const start = std.Io.Clock.awake.now(init.io);
    var iter: usize = 0;
    while (iter < iterations) : (iter += 1) {
        buffer[0] +%= @as(u8, @truncate(iter + 1));
        try runAllOps(buffer, stride, case, kernel);
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    const checksum = sparseChecksum(buffer);
    std.mem.doNotOptimizeAway(checksum);

    return .{
        .output_bytes = case.length * case.ops_per_iter * iterations,
        .elapsed_ns = elapsed_ns,
        .checksum = checksum,
    };
}

fn runAllOps(buffer: []u8, stride: usize, case: CaseSpec, kernel: Kernel) !void {
    var op: usize = 0;
    while (op < case.ops_per_iter) : (op += 1) {
        const out_offset = op * stride + case.distance;
        try copyKernel(kernel, buffer, out_offset, case.length, case.distance);
    }
}

fn fillBuffer(buffer: []u8, stride: usize, case: CaseSpec) void {
    var op: usize = 0;
    while (op < case.ops_per_iter) : (op += 1) {
        const base = op * stride;
        var i: usize = 0;
        while (i < stride) : (i += 1) {
            buffer[base + i] = @truncate((op * 131 + i * 17 + case.length * 7 + case.distance * 3) & 0xff);
        }
    }
}

fn copyKernel(kernel: Kernel, output: []u8, out_offset: usize, length: usize, distance: usize) !void {
    return switch (kernel) {
        .current => copyCurrent(output, out_offset, length, distance),
        .nonoverlap_first => copyNonOverlapFirst(output, out_offset, length, distance),
        .small_unrolled => copySmallUnrolled(output, out_offset, length, distance),
    };
}

fn copyCurrent(output: []u8, out_offset: usize, length: usize, distance: usize) !void {
    if (distance == 0 or distance > out_offset) return error.InvalidMatch;
    if (out_offset > output.len or output.len - out_offset < length) return error.OutputTooSmall;
    const dest = output[out_offset..][0..length];
    if (distance == 1 and out_offset != 0) {
        @memset(dest, output[out_offset - 1]);
        return;
    }
    if (distance <= 4 and out_offset >= distance) {
        copySmallDistanceMatch(dest, output[out_offset - distance ..], distance);
        return;
    }
    if (distance >= length) {
        @memcpy(dest, output[out_offset - distance ..][0..length]);
        return;
    }
    copyOverlappingMatchAt(output, out_offset, length, distance);
}

fn copyNonOverlapFirst(output: []u8, out_offset: usize, length: usize, distance: usize) !void {
    if (distance == 0 or distance > out_offset) return error.InvalidMatch;
    if (out_offset > output.len or output.len - out_offset < length) return error.OutputTooSmall;
    const dest = output[out_offset..][0..length];
    if (distance == 1 and out_offset != 0) {
        @memset(dest, output[out_offset - 1]);
        return;
    }
    if (distance >= length) {
        @memcpy(dest, output[out_offset - distance ..][0..length]);
        return;
    }
    if (distance <= 4 and out_offset >= distance) {
        copySmallDistanceMatch(dest, output[out_offset - distance ..], distance);
        return;
    }
    copyOverlappingMatchAt(output, out_offset, length, distance);
}

fn copySmallUnrolled(output: []u8, out_offset: usize, length: usize, distance: usize) !void {
    if (distance == 0 or distance > out_offset) return error.InvalidMatch;
    if (out_offset > output.len or output.len - out_offset < length) return error.OutputTooSmall;
    const dest = output[out_offset..][0..length];
    if (distance == 1 and out_offset != 0) {
        @memset(dest, output[out_offset - 1]);
        return;
    }
    if (distance <= 4 and out_offset >= distance) {
        copySmallDistanceMatch(dest, output[out_offset - distance ..], distance);
        return;
    }
    if (distance >= length) {
        copyNonOverlappingSmall(dest, output[out_offset - distance ..], length);
        return;
    }
    copyOverlappingMatchAt(output, out_offset, length, distance);
}

fn copySmallDistanceMatch(dest: []u8, pattern: []const u8, distance: usize) void {
    switch (distance) {
        1 => @memset(dest, pattern[0]),
        2 => {
            const a = pattern[0];
            const b = pattern[1];
            var i: usize = 0;
            while (i + 2 <= dest.len) : (i += 2) {
                dest[i] = a;
                dest[i + 1] = b;
            }
            if (i < dest.len) dest[i] = a;
        },
        3 => {
            const a = pattern[0];
            const b = pattern[1];
            const c = pattern[2];
            var i: usize = 0;
            while (i + 3 <= dest.len) : (i += 3) {
                dest[i] = a;
                dest[i + 1] = b;
                dest[i + 2] = c;
            }
            if (i < dest.len) {
                dest[i] = a;
                i += 1;
            }
            if (i < dest.len) dest[i] = b;
        },
        4 => {
            const a = pattern[0];
            const b = pattern[1];
            const c = pattern[2];
            const d = pattern[3];
            var i: usize = 0;
            while (i + 4 <= dest.len) : (i += 4) {
                dest[i] = a;
                dest[i + 1] = b;
                dest[i + 2] = c;
                dest[i + 3] = d;
            }
            if (i < dest.len) {
                dest[i] = a;
                i += 1;
            }
            if (i < dest.len) {
                dest[i] = b;
                i += 1;
            }
            if (i < dest.len) dest[i] = c;
        },
        else => unreachable,
    }
}

fn copyNonOverlappingSmall(dest: []u8, src: []const u8, length: usize) void {
    switch (length) {
        3 => {
            dest[0] = src[0];
            dest[1] = src[1];
            dest[2] = src[2];
        },
        4 => {
            dest[0] = src[0];
            dest[1] = src[1];
            dest[2] = src[2];
            dest[3] = src[3];
        },
        5 => {
            dest[0] = src[0];
            dest[1] = src[1];
            dest[2] = src[2];
            dest[3] = src[3];
            dest[4] = src[4];
        },
        6 => {
            dest[0] = src[0];
            dest[1] = src[1];
            dest[2] = src[2];
            dest[3] = src[3];
            dest[4] = src[4];
            dest[5] = src[5];
        },
        7 => {
            dest[0] = src[0];
            dest[1] = src[1];
            dest[2] = src[2];
            dest[3] = src[3];
            dest[4] = src[4];
            dest[5] = src[5];
            dest[6] = src[6];
        },
        8 => {
            dest[0] = src[0];
            dest[1] = src[1];
            dest[2] = src[2];
            dest[3] = src[3];
            dest[4] = src[4];
            dest[5] = src[5];
            dest[6] = src[6];
            dest[7] = src[7];
        },
        else => @memcpy(dest[0..length], src[0..length]),
    }
}

fn copyOverlappingMatchAt(output: []u8, out_offset: usize, length: usize, distance: usize) void {
    const first = @min(distance, length);
    @memcpy(output[out_offset..][0..first], output[out_offset - distance ..][0..first]);
    var copied = first;
    while (copied < length) {
        const n = @min(copied, length - copied);
        @memcpy(output[out_offset + copied ..][0..n], output[out_offset..][0..n]);
        copied += n;
    }
}

fn iterationsFor(length: usize, ops_per_iter: usize) usize {
    const target_bytes: usize = 16 * 1024 * 1024;
    return @max(@as(usize, 8), @min(@as(usize, 2048), target_bytes / @max(length * ops_per_iter, 1)));
}

fn throughput(bytes: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return mib / seconds;
}

fn sparseChecksum(bytes: []const u8) u64 {
    if (bytes.len == 0) return 0;
    const stride = @max(@as(usize, 1), bytes.len / 256);
    var sum: u64 = @intCast(bytes.len);
    var i: usize = 0;
    while (i < bytes.len) : (i += stride) sum = sum *% 257 +% bytes[i];
    return sum;
}

fn writeRow(writer: *std.Io.Writer, case: CaseSpec, kernel: Kernel, iterations: usize, result: BenchResult) !void {
    try writer.print("{s},{s},{s},{d},{d},{d},{d},{d},{d},{d:.2},{d}\n", .{
        case.name,
        case.class.label(),
        kernel.label(),
        case.length,
        case.distance,
        case.ops_per_iter,
        iterations,
        result.output_bytes,
        result.elapsed_ns,
        throughput(result.output_bytes, result.elapsed_ns),
        result.checksum,
    });
}
