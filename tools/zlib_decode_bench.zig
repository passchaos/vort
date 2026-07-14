const std = @import("std");
const vort = @import("vort");

const Mode = enum { alloc, into };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    const frame_path = args.next() orelse return error.MissingCorpusPath;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const mode = parseMode(args.next());
    const frame = try std.Io.Dir.cwd().readFileAlloc(init.io, frame_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(frame);

    const warmup = try vort.decodeZlibAlloc(init.gpa, frame);
    defer init.gpa.free(warmup);
    var empty_scratch: [0]u8 = .{};
    const scratch = if (mode == .into) try init.gpa.alloc(u8, warmup.len) else empty_scratch[0..];
    defer if (mode == .into) init.gpa.free(scratch);
    if (mode == .into) {
        const written = try vort.decodeZlib(frame, scratch);
        if (written != warmup.len or !std.mem.eql(u8, scratch, warmup)) return error.DecodeLengthMismatch;
    }

    var mix: u64 = 0;
    const start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        switch (mode) {
            .alloc => {
                const decoded = try vort.decodeZlibAlloc(init.gpa, frame);
                defer init.gpa.free(decoded);
                mix +%= decoded.len;
                if (decoded.len != 0) mix +%= decoded[0];
            },
            .into => {
                const written = try vort.decodeZlib(frame, scratch);
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
    const value = text orelse return .alloc;
    if (std.mem.eql(u8, value, "into")) return .into;
    return .alloc;
}
