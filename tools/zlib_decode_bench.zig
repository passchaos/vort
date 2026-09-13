const std = @import("std");
const vort = @import("vort");
const benchmark_provenance = @import("benchmark_provenance");

const Mode = enum { raw_alloc, raw_exact, raw_into, zlib_alloc, zlib_exact, zlib_into, gzip_alloc, gzip_exact, gzip_into };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    if (args.next()) |first| {
        if (std.mem.eql(u8, first, "--benchmark-provenance")) {
            const provenance = try benchmark_provenance.capture(
                init.io,
                init.gpa,
                init.minimal.args,
                "single",
            );
            defer provenance.deinit(init.gpa);
            var buffer: [4096]u8 = undefined;
            var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
            try benchmark_provenance.writeCsv(provenance, &stdout_writer.interface);
            try stdout_writer.interface.flush();
            return;
        }
        return run(init, first, &args);
    }
    return error.MissingCorpusPath;
}

fn run(init: std.process.Init, frame_path: []const u8, args: *std.process.Args.Iterator) !void {
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const mode = parseMode(args.next());
    const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, frame_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(frame);

    // Rust's Vec allocator is the process allocator. Use libc here as well so
    // allocator-returning rows measure codec/allocation work rather than Zig's
    // page allocator mapping every result independently.
    const benchmark_allocator = std.heap.c_allocator;
    const warmup = switch (mode) {
        .raw_alloc, .raw_exact, .raw_into => try vort.decodeRawDeflateAlloc(benchmark_allocator, frame),
        .zlib_alloc, .zlib_exact, .zlib_into => try vort.decodeZlibAlloc(benchmark_allocator, frame),
        .gzip_alloc, .gzip_exact, .gzip_into => try vort.decodeGzipAlloc(benchmark_allocator, frame),
    };
    defer benchmark_allocator.free(warmup);
    var empty_scratch: [0]u8 = .{};
    const uses_scratch = mode == .raw_into or mode == .zlib_into or mode == .gzip_into;
    const scratch = if (uses_scratch) try benchmark_allocator.alloc(u8, warmup.len) else empty_scratch[0..];
    defer if (uses_scratch) benchmark_allocator.free(scratch);
    if (uses_scratch) {
        const written = switch (mode) {
            .raw_into => (try vort.decodeRawDeflate(frame, scratch)).output_written,
            .zlib_into => try vort.decodeZlib(frame, scratch),
            .gzip_into => try vort.decodeGzip(frame, scratch),
            else => unreachable,
        };
        if (written != warmup.len or !std.mem.eql(u8, scratch, warmup)) return error.DecodeLengthMismatch;
    }

    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        switch (mode) {
            .raw_alloc => {
                const decoded = try vort.decodeRawDeflateAlloc(benchmark_allocator, frame);
                {
                    defer benchmark_allocator.free(decoded);
                    mix +%= decoded.len;
                    if (decoded.len != 0) mix +%= decoded[0];
                }
            },
            .raw_exact => {
                const decoded = try vort.decodeRawDeflateAllocExactSize(benchmark_allocator, frame, warmup.len);
                {
                    defer benchmark_allocator.free(decoded);
                    mix +%= decoded.len;
                    if (decoded.len != 0) mix +%= decoded[0];
                }
            },
            .raw_into => {
                const decoded = try vort.decodeRawDeflate(frame, scratch);
                mix +%= decoded.output_written;
                if (decoded.output_written != 0) mix +%= scratch[0];
            },
            .zlib_alloc => {
                const decoded = try vort.decodeZlibAlloc(benchmark_allocator, frame);
                {
                    defer benchmark_allocator.free(decoded);
                    mix +%= decoded.len;
                    if (decoded.len != 0) mix +%= decoded[0];
                }
            },
            .zlib_exact => {
                const decoded = try vort.decodeZlibAllocExactSize(benchmark_allocator, frame, warmup.len);
                {
                    defer benchmark_allocator.free(decoded);
                    mix +%= decoded.len;
                    if (decoded.len != 0) mix +%= decoded[0];
                }
            },
            .zlib_into => {
                const written = try vort.decodeZlib(frame, scratch);
                mix +%= written;
                if (written != 0) mix +%= scratch[0];
            },
            .gzip_alloc => {
                const decoded = try vort.decodeGzipAlloc(benchmark_allocator, frame);
                {
                    defer benchmark_allocator.free(decoded);
                    mix +%= decoded.len;
                    if (decoded.len != 0) mix +%= decoded[0];
                }
            },
            .gzip_exact => {
                const decoded = try vort.decodeGzipAllocExactSize(benchmark_allocator, frame, warmup.len);
                {
                    defer benchmark_allocator.free(decoded);
                    mix +%= decoded.len;
                    if (decoded.len != 0) mix +%= decoded[0];
                }
            },
            .gzip_into => {
                const written = try vort.decodeGzip(frame, scratch);
                mix +%= written;
                if (written != 0) mix +%= scratch[0];
            },
        }
    }
    const elapsed_ns = start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();

    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("elapsed_ns={d} mix={d}\n", .{ elapsed_ns, mix });
    try stdout.flush();
}

fn parseMode(text: ?[]const u8) Mode {
    const value = text orelse return .zlib_alloc;
    if (std.mem.eql(u8, value, "raw")) return .raw_alloc;
    if (std.mem.eql(u8, value, "raw-exact")) return .raw_exact;
    if (std.mem.eql(u8, value, "raw-into")) return .raw_into;
    if (std.mem.eql(u8, value, "into")) return .zlib_into;
    if (std.mem.eql(u8, value, "zlib")) return .zlib_alloc;
    if (std.mem.eql(u8, value, "zlib-exact")) return .zlib_exact;
    if (std.mem.eql(u8, value, "zlib-into")) return .zlib_into;
    if (std.mem.eql(u8, value, "gzip")) return .gzip_alloc;
    if (std.mem.eql(u8, value, "gzip-exact")) return .gzip_exact;
    if (std.mem.eql(u8, value, "gzip-into")) return .gzip_into;
    return .zlib_alloc;
}
