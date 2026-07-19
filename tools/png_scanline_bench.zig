const std = @import("std");
const vort = @import("vort");

const iterations: usize = 16;
const row_pixels: usize = 1024;
const rows_per_case: usize = 128;
const bpp_cases = [_]usize{ 1, 2, 3, 4, 6, 8 };

const Filter = enum(u8) {
    none = 0,
    sub = 1,
    up = 2,
    average = 3,
    paeth = 4,

    fn label(self: Filter) []const u8 {
        return switch (self) {
            .none => "none",
            .sub => "sub",
            .up => "up",
            .average => "average",
            .paeth => "paeth",
        };
    }
};

const filters = [_]Filter{ .none, .sub, .up, .average, .paeth };

const Row = struct {
    stage: []const u8,
    bpp: usize,
    iterations: usize,
    input_bytes: usize,
    output_bytes: usize,
    elapsed_ns: i128,
    output_mib_per_s: f64,
    checksum: u64,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var csv_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--csv")) {
            csv_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        return error.UnknownArgument;
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try csv.writer.writeAll("stage,bpp,iterations,input_bytes,output_bytes,elapsed_ns,output_mib_per_s,checksum\n");

    for (bpp_cases) |bpp| {
        for (filters) |filter| {
            const row = try runCase(init, bpp, filter);
            try csv.writer.print("{s},{d},{d},{d},{d},{d},{d:.2},{d}\n", .{
                row.stage,
                row.bpp,
                row.iterations,
                row.input_bytes,
                row.output_bytes,
                row.elapsed_ns,
                row.output_mib_per_s,
                row.checksum,
            });
            std.debug.print("png scanline bench: stage={s} bpp={d} iterations={d} input_bytes={d} output_bytes={d} elapsed_ns={d} output_mib_per_s={d:.2} checksum={d}\n", .{
                row.stage,
                row.bpp,
                row.iterations,
                row.input_bytes,
                row.output_bytes,
                row.elapsed_ns,
                row.output_mib_per_s,
                row.checksum,
            });
        }
    }

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn runCase(init: std.process.Init, bpp: usize, filter: Filter) !Row {
    const row_len = row_pixels * bpp;
    const total_len = row_len * rows_per_case;
    const image = try init.gpa.alloc(u8, total_len);
    defer init.gpa.free(image);
    const filtered = try init.gpa.alloc(u8, total_len);
    defer init.gpa.free(filtered);
    const output = try init.gpa.alloc(u8, total_len);
    defer init.gpa.free(output);

    fillImage(image, row_len, bpp);
    makeFilteredRows(filter, image, row_len, bpp, filtered);

    const start = std.Io.Clock.awake.now(init.io);
    var iter: usize = 0;
    while (iter < iterations) : (iter += 1) {
        var y: usize = 0;
        while (y < rows_per_case) : (y += 1) {
            const filtered_row = filtered[y * row_len ..][0..row_len];
            const previous = if (y == 0) null else output[(y - 1) * row_len ..][0..row_len];
            const out_row = output[y * row_len ..][0..row_len];
            _ = try vort.reconstructPngScanline(@intFromEnum(filter), filtered_row, previous, bpp, out_row);
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    if (!std.mem.eql(u8, image, output)) return error.RoundTripMismatch;
    const checksum = sparseChecksum(output);
    std.mem.doNotOptimizeAway(checksum);

    return .{
        .stage = filter.label(),
        .bpp = bpp,
        .iterations = iterations,
        .input_bytes = filtered.len * iterations,
        .output_bytes = output.len * iterations,
        .elapsed_ns = elapsed_ns,
        .output_mib_per_s = mibPerSecond(output.len * iterations, elapsed_ns),
        .checksum = checksum,
    };
}

fn fillImage(image: []u8, row_len: usize, bpp: usize) void {
    var y: usize = 0;
    while (y < rows_per_case) : (y += 1) {
        const row = image[y * row_len ..][0..row_len];
        for (row, 0..) |*byte, x| {
            byte.* = @truncate((x *% 131 +% y *% 17 +% bpp *% 29 +% ((x >> 3) ^ (y << 1))) & 0xff);
        }
    }
}

fn makeFilteredRows(filter: Filter, image: []const u8, row_len: usize, bpp: usize, filtered: []u8) void {
    var y: usize = 0;
    while (y < rows_per_case) : (y += 1) {
        const image_row = image[y * row_len ..][0..row_len];
        const prev = if (y == 0) null else image[(y - 1) * row_len ..][0..row_len];
        const filtered_row = filtered[y * row_len ..][0..row_len];
        for (image_row, 0..) |byte, x| {
            const left: u8 = if (x >= bpp) image_row[x - bpp] else 0;
            const up: u8 = if (prev) |p| p[x] else 0;
            const up_left: u8 = if (x >= bpp) blk: {
                if (prev) |p| break :blk p[x - bpp];
                break :blk 0;
            } else 0;
            const prediction: u8 = switch (filter) {
                .none => 0,
                .sub => left,
                .up => up,
                .average => @intCast((@as(u16, left) + @as(u16, up)) >> 1),
                .paeth => paethPredictor(left, up, up_left),
            };
            filtered_row[x] = byte -% prediction;
        }
    }
}

fn paethPredictor(left: u8, up: u8, up_left: u8) u8 {
    const a: i32 = left;
    const b: i32 = up;
    const c: i32 = up_left;
    const p = a + b - c;
    const pa = absI32(p - a);
    const pb = absI32(p - b);
    const pc = absI32(p - c);
    if (pa <= pb and pa <= pc) return left;
    if (pb <= pc) return up;
    return up_left;
}

fn absI32(value: i32) i32 {
    return if (value < 0) -value else value;
}

fn sparseChecksum(bytes: []const u8) u64 {
    if (bytes.len == 0) return 0;
    const stride = @max(@as(usize, 1), bytes.len / 128);
    var sum: u64 = @intCast(bytes.len);
    var i: usize = 0;
    while (i < bytes.len) : (i += stride) sum = sum *% 257 +% bytes[i];
    return sum;
}

fn mibPerSecond(bytes: usize, elapsed_ns: i128) f64 {
    if (elapsed_ns <= 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return mib / seconds;
}
