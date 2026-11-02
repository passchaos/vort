//! Guarded raw Deflate incremental comparison harness. Compile against either
//! source snapshot with --dep deflate -Mroot=... -Mdeflate=.../src/deflate.zig.

const std = @import("std");
const codec = @import("deflate");

const Decoder = codec.RawDeflateIncrementalFixedLiteralDecoder;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const wire_path = args.next() orelse return error.MissingWire;
    const plain_path = args.next() orelse return error.MissingPlain;
    const input_chunk = try std.fmt.parseInt(usize, args.next() orelse "4096", 10);
    const output_chunk = try std.fmt.parseInt(usize, args.next() orelse "4096", 10);
    const iterations = try std.fmt.parseInt(usize, args.next() orelse "0", 10);
    const semantic = std.mem.eql(u8, args.next() orelse "semantic", "semantic");
    if (input_chunk == 0 or output_chunk == 0 or args.next() != null) return error.InvalidArgument;
    const wire = try std.Io.Dir.cwd().readFileAlloc(init.io, wire_path, init.gpa, .limited(256 * 1024 * 1024));
    defer init.gpa.free(wire);
    const plain = try std.Io.Dir.cwd().readFileAlloc(init.io, plain_path, init.gpa, .limited(256 * 1024 * 1024));
    defer init.gpa.free(plain);
    const storage = try init.gpa.alloc(u8, plain.len + 64);
    defer init.gpa.free(storage);
    @memset(storage, 0xa5);
    const output = storage[32..][0..plain.len];
    var history: [65536]u8 = undefined;

    var ns: u64 = 0;
    var sum: u64 = 0;
    for (0..iterations + 1) |iteration| {
        var decoder = try Decoder.initWithHistory(
            .{},
            if (semantic) &history else history[0..Decoder.required_history_len],
        );
        var workspace: Decoder.SemanticWorkspace = undefined;
        if (semantic) try decoder.attachSemanticWorkspace(&workspace);
        var in_pos: usize = 0;
        var out_pos: usize = 0;
        const start = std.Io.Clock.awake.now(init.io);
        while (decoder.phase != .done) {
            const in_end = @min(wire.len, in_pos + input_chunk);
            const out_end = @min(output.len, out_pos + output_chunk);
            const step = try decoder.step(wire[in_pos..in_end], output[out_pos..out_end]);
            if (step.status != .done and step.progress.input_read == 0 and step.progress.output_written == 0)
                return error.NoProgress;
            in_pos += step.progress.input_read;
            out_pos += step.progress.output_written;
            if (step.status == .need_input and in_pos == wire.len) {
                try decoder.finish();
                break;
            }
        }
        if (iteration != 0) ns += @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds);
        try decoder.finish();
        if (in_pos != wire.len) return error.BadInputLen;
        if (out_pos != plain.len) return error.BadOutputLen;
        if (!std.mem.eql(u8, output, plain)) return error.BadDecode;
        sum +%= out_pos;
    }
    for (storage[0..32]) |byte| if (byte != 0xa5) return error.Guard;
    for (storage[plain.len + 32 ..]) |byte| if (byte != 0xa5) return error.Guard;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(output, &digest, .{});
    const hash = std.fmt.bytesToHex(digest, .lower);
    var buf: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buf);
    try writer.interface.print("codec=deflate-incremental input={d} output={d} iterations={d} ns={d} checksum={d} plain_sha={s} guards=1\n", .{ wire.len, plain.len, iterations, ns, sum, &hash });
    try writer.interface.flush();
}
