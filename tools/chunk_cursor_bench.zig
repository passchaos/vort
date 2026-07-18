const std = @import("std");

const Operation = enum {
    read_byte,
    copy_to,

    fn label(self: Operation) []const u8 {
        return switch (self) {
            .read_byte => "read-byte",
            .copy_to => "copy-to",
        };
    }
};

const Kernel = enum {
    current,
    skip_empty_advance,

    fn label(self: Kernel) []const u8 {
        return switch (self) {
            .current => "current",
            .skip_empty_advance => "skip_empty_advance",
        };
    }
};

const CaseSpec = struct {
    name: []const u8,
    operation: Operation,
    payload_len: usize,
    chunk_bytes: usize,
    include_empty_chunks: bool,
};

const Row = struct {
    case: []const u8,
    operation: []const u8,
    kernel: []const u8,
    payload_bytes: usize,
    chunk_bytes: usize,
    chunk_count: usize,
    include_empty_chunks: bool,
    iterations: usize,
    elapsed_ns: i128,
    bytes_per_s: f64,
    mib_per_s: f64,
    checksum: u64,
};

const kernels = [_]Kernel{ .current, .skip_empty_advance };

const cases = [_]CaseSpec{
    .{ .name = "read-1b-empty", .operation = .read_byte, .payload_len = 8 * 1024, .chunk_bytes = 1, .include_empty_chunks = true },
    .{ .name = "copy-1b-empty", .operation = .copy_to, .payload_len = 8 * 1024, .chunk_bytes = 1, .include_empty_chunks = true },
    .{ .name = "copy-7b-empty", .operation = .copy_to, .payload_len = 32 * 1024, .chunk_bytes = 7, .include_empty_chunks = true },
    .{ .name = "copy-256b", .operation = .copy_to, .payload_len = 64 * 1024, .chunk_bytes = 256, .include_empty_chunks = false },
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
    try csv.writer.writeAll("case,operation,kernel,payload_bytes,chunk_bytes,chunk_count,include_empty_chunks,iterations,elapsed_ns,bytes_per_s,mib_per_s,checksum\n");

    for (cases) |case| {
        const input = try init.gpa.alloc(u8, case.payload_len);
        defer init.gpa.free(input);
        fillPayload(input);
        const chunks = try makeChunks(init.gpa, input, case.chunk_bytes, case.include_empty_chunks);
        defer init.gpa.free(chunks);

        try verifyCase(init.gpa, case, chunks, input);
        const iterations = iterations_override orelse iterationsFor(case.payload_len);
        for (kernels) |kernel| {
            const row = try runCase(init, case, kernel, chunks, input, iterations);
            try writeRow(&csv.writer, row);
        }
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(csv.written());
    try stdout_writer.interface.flush();

    if (csv_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = csv.written() });
}

fn verifyCase(allocator: std.mem.Allocator, case: CaseSpec, chunks: []const []const u8, expected: []const u8) !void {
    const current = try runCaseOnce(allocator, case.operation, .current, chunks, expected.len);
    defer allocator.free(current.bytes);
    const candidate = try runCaseOnce(allocator, case.operation, .skip_empty_advance, chunks, expected.len);
    defer allocator.free(candidate.bytes);
    if (!std.mem.eql(u8, current.bytes, expected) or !std.mem.eql(u8, candidate.bytes, expected)) return error.DecodeLengthMismatch;
    if (current.checksum != candidate.checksum) return error.DecodeLengthMismatch;
}

const CaseOnceResult = struct { bytes: []u8, checksum: u64 };

fn runCaseOnce(allocator: std.mem.Allocator, operation: Operation, kernel: Kernel, chunks: []const []const u8, payload_len: usize) !CaseOnceResult {
    const output = try allocator.alloc(u8, payload_len);
    errdefer allocator.free(output);
    var cursor = Cursor.init(chunks, payload_len, 0);
    switch (operation) {
        .read_byte => {
            for (output) |*byte| byte.* = try cursor.readByte(kernel);
        },
        .copy_to => try cursor.copyTo(kernel, output),
    }
    return .{ .bytes = output, .checksum = sparseChecksum(output) };
}

fn runCase(init: std.process.Init, case: CaseSpec, kernel: Kernel, chunks: []const []const u8, input: []const u8, iterations: usize) !Row {
    const output = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(output);

    const start = std.Io.Clock.awake.now(init.io);
    var checksum: u64 = 0;
    for (0..iterations) |iteration| {
        var cursor = Cursor.init(chunks, input.len, 0);
        switch (case.operation) {
            .read_byte => {
                for (output) |*byte| byte.* = try cursor.readByte(kernel);
            },
            .copy_to => try cursor.copyTo(kernel, output),
        }
        if (!std.mem.eql(u8, output, input)) return error.DecodeLengthMismatch;
        checksum +%= sparseChecksum(output) +% iteration;
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
    std.mem.doNotOptimizeAway(checksum);
    return .{
        .case = case.name,
        .operation = case.operation.label(),
        .kernel = kernel.label(),
        .payload_bytes = input.len,
        .chunk_bytes = case.chunk_bytes,
        .chunk_count = chunks.len,
        .include_empty_chunks = case.include_empty_chunks,
        .iterations = iterations,
        .elapsed_ns = elapsed_ns,
        .bytes_per_s = bytesPerSecond(input.len, iterations, elapsed_ns),
        .mib_per_s = mibPerSecond(input.len, iterations, elapsed_ns),
        .checksum = checksum,
    };
}

const Cursor = struct {
    chunks: []const []const u8,
    total_len: usize,
    absolute: usize,
    chunk_index: usize = 0,
    chunk_start: usize = 0,

    fn init(chunks: []const []const u8, total_len: usize, offset: usize) Cursor {
        var cursor = Cursor{ .chunks = chunks, .total_len = total_len, .absolute = offset };
        cursor.sync();
        return cursor;
    }

    fn sync(self: *Cursor) void {
        if (self.absolute >= self.total_len) {
            self.chunk_index = self.chunks.len;
            self.chunk_start = self.total_len;
            return;
        }
        if (self.chunk_index >= self.chunks.len or self.absolute < self.chunk_start) {
            self.chunk_index = 0;
            self.chunk_start = 0;
        }
        while (self.chunk_index < self.chunks.len) {
            const end = self.chunk_start + self.chunks[self.chunk_index].len;
            if (self.absolute < end) return;
            self.chunk_start = end;
            self.chunk_index += 1;
        }
    }

    fn readByte(self: *Cursor, kernel: Kernel) !u8 {
        if (self.absolute >= self.total_len) return error.TruncatedFrame;
        self.sync();
        if (self.chunk_index >= self.chunks.len) return error.TruncatedFrame;
        const chunk = self.chunks[self.chunk_index];
        const local = self.absolute - self.chunk_start;
        const byte = chunk[local];
        self.absolute += 1;
        if (kernel == .skip_empty_advance and local + 1 == chunk.len) self.advancePastEmptyChunks();
        return byte;
    }

    fn copyTo(self: *Cursor, kernel: Kernel, output: []u8) !void {
        var absolute = self.absolute;
        var chunk_index = self.chunk_index;
        var chunk_start = self.chunk_start;
        if (chunk_index >= self.chunks.len or absolute < chunk_start) {
            chunk_index = 0;
            chunk_start = 0;
        }

        var out_offset: usize = 0;
        while (out_offset < output.len) {
            if (absolute >= self.total_len) return error.TruncatedFrame;
            while (chunk_index < self.chunks.len) {
                const end = chunk_start + self.chunks[chunk_index].len;
                if (absolute < end) break;
                chunk_start = end;
                chunk_index += 1;
            }
            if (chunk_index >= self.chunks.len) return error.TruncatedFrame;
            const chunk = self.chunks[chunk_index];
            const local = absolute - chunk_start;
            const n = @min(output.len - out_offset, chunk.len - local);
            @memcpy(output[out_offset..][0..n], chunk[local..][0..n]);
            out_offset += n;
            absolute += n;
            if (kernel == .skip_empty_advance and local + n == chunk.len) {
                chunk_start += chunk.len;
                chunk_index += 1;
                while (chunk_index < self.chunks.len and self.chunks[chunk_index].len == 0) chunk_index += 1;
            }
        }

        self.absolute = absolute;
        self.chunk_index = chunk_index;
        self.chunk_start = chunk_start;
        self.sync();
    }

    fn advancePastEmptyChunks(self: *Cursor) void {
        const chunk = self.chunks[self.chunk_index];
        self.chunk_start += chunk.len;
        self.chunk_index += 1;
        while (self.chunk_index < self.chunks.len and self.chunks[self.chunk_index].len == 0) self.chunk_index += 1;
    }
};

fn fillPayload(output: []u8) void {
    for (output, 0..) |*byte, i| byte.* = @intCast((i * 31 + (i / 7) * 17 + 11) & 0xff);
}

fn makeChunks(allocator: std.mem.Allocator, input: []const u8, chunk_bytes: usize, include_empty_chunks: bool) ![][]const u8 {
    if (chunk_bytes == 0) return error.InvalidBlockPlan;
    var chunks: std.ArrayList([]const u8) = .empty;
    errdefer chunks.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        if (include_empty_chunks) try chunks.append(allocator, input[offset..offset]);
        const n = @min(chunk_bytes, input.len - offset);
        try chunks.append(allocator, input[offset..][0..n]);
        offset += n;
    }
    if (include_empty_chunks) try chunks.append(allocator, input[input.len..input.len]);
    return chunks.toOwnedSlice(allocator);
}

fn iterationsFor(payload_len: usize) usize {
    const target_bytes: usize = 128 * 1024 * 1024;
    return @max(@as(usize, 32), @min(@as(usize, 8000), target_bytes / @max(payload_len, 1)));
}

fn bytesPerSecond(payload_len: usize, iterations: usize, elapsed_ns: i128) f64 {
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    if (seconds == 0) return 0;
    return @as(f64, @floatFromInt(payload_len)) * @as(f64, @floatFromInt(iterations)) / seconds;
}

fn mibPerSecond(payload_len: usize, iterations: usize, elapsed_ns: i128) f64 {
    return bytesPerSecond(payload_len, iterations, elapsed_ns) / (1024.0 * 1024.0);
}

fn sparseChecksum(bytes: []const u8) u64 {
    var sum: u64 = 0;
    if (bytes.len == 0) return 1;
    const step = @max(@as(usize, 1), bytes.len / 64);
    var i: usize = 0;
    while (i < bytes.len) : (i += step) sum = sum *% 131 +% bytes[i];
    return sum +% bytes.len;
}

fn writeRow(writer: *std.Io.Writer, row: Row) !void {
    try writer.print("{s},{s},{s},{d},{d},{d},{},{d},{d},{d:.2},{d:.2},{d}\n", .{
        row.case,
        row.operation,
        row.kernel,
        row.payload_bytes,
        row.chunk_bytes,
        row.chunk_count,
        row.include_empty_chunks,
        row.iterations,
        row.elapsed_ns,
        row.bytes_per_s,
        row.mib_per_s,
        row.checksum,
    });
}
