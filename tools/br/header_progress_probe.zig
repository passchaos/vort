//! Measure fragmented incremental Brotli decode and compressed-header work.
const std = @import("std");
const br = @import("vort_br");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const chunk = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 1;
    const iterations = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 1;
    if (args.next() != null) return error.ExtraArguments;
    if (chunk == 0 or iterations == 0 or iterations > 64) return error.InvalidArguments;

    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = try br.encodePlannedStreamRatioAlloc(init.gpa, input);
    defer init.gpa.free(encoded);
    const output = try init.gpa.alloc(u8, input.len);
    defer init.gpa.free(output);

    var total_ns: u64 = 0;
    var snapshot: br.IncrementalCopyStreamDecoder.Snapshot = undefined;
    var index: usize = 0;
    while (index < iterations) : (index += 1) {
        var history: [64 * 1024]u8 = undefined;
        var decoder = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{
            .max_output_len = input.len,
            .expected_output_len = input.len,
        });
        @memset(output, 0xa5);
        const start = std.Io.Clock.awake.now(init.io);
        var input_offset: usize = 0;
        var output_offset: usize = 0;
        while (decoder.snapshot().phase != .done) {
            const input_end = @min(encoded.len, input_offset + chunk);
            const step = try decoder.step(encoded[input_offset..input_end], output[output_offset..]);
            input_offset += step.progress.input_read;
            output_offset += step.progress.output_written;
            if (step.progress.input_read == 0 and step.progress.output_written == 0) {
                if (step.status == .need_input and input_offset == encoded.len) return error.TruncatedFrame;
                if (step.status == .need_output and output_offset == output.len) return error.OutputTooSmall;
            }
        }
        total_ns += @intCast(start.untilNow(init.io, .awake).nanoseconds);
        if (output_offset != input.len or !std.mem.eql(u8, input, output)) return error.BadRoundTrip;
        snapshot = decoder.snapshot();
    }

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded, &digest, .{});
    const encoded_sha = std.fmt.bytesToHex(digest, .lower);
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "input={d} encoded={d} chunk={d} iterations={d} decode_avg_ns={d} header_attempts={d} header_resumes={d} header_trees={d} header_tree_attempts={d} encoded_sha={s}\n",
        .{
            input.len,
            encoded.len,
            chunk,
            iterations,
            total_ns / iterations,
            snapshot.header_parse_attempts,
            snapshot.header_resumes,
            snapshot.header_trees,
            snapshot.header_tree_attempts,
            &encoded_sha,
        },
    );
    try stdout.interface.flush();
}
