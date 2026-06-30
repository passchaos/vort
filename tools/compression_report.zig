const std = @import("std");
const vort = @import("vort");

const Case = struct { name: []const u8, input: []const u8 };

pub fn main(init: std.process.Init) !void {
    const cases = [_]Case{
        .{ .name = "empty", .input = "" },
        .{ .name = "tiny", .input = "hello vort" },
        .{ .name = "text", .input = "the quick brown fox jumps over the lazy dog\n" ** 64 },
        .{ .name = "jsonish", .input = "{\"key\":\"value\",\"numbers\":[1,2,3,4],\"flag\":true}\n" ** 64 },
        .{ .name = "repeated", .input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ** 64 },
        .{ .name = "ldm-window", .input = ("abcd" ** 9000) ++ "----" ++ ("abcd" ** 32) },
    };

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("name,input_bytes,best_deflate_bytes,zlib_fixed_bytes,gzip_fixed_bytes,native_ldm_bytes,native_ldm_best_bytes,native_ldm_selected,best_ratio,ldm_candidates,ldm_longest,ldm_max_distance,ldm_blocks\n", .{});
    for (cases) |case| {
        const raw = try vort.encodeRawBestAlloc(init.gpa, case.input, .{});
        defer init.gpa.free(raw);
        const zlib_frame = try vort.encodeZlibFixedAlloc(init.gpa, case.input);
        defer init.gpa.free(zlib_frame);
        const gzip_frame = try vort.encodeGzipFixedAlloc(init.gpa, case.input);
        defer init.gpa.free(gzip_frame);
        const ldm_frame = try vort.storeEncodeLongDistanceAlloc(init.gpa, case.input, .{});
        defer init.gpa.free(ldm_frame);
        const ldm_decoded = try vort.storeDecodeAnyAlloc(init.gpa, ldm_frame);
        defer init.gpa.free(ldm_decoded);
        if (!std.mem.eql(u8, case.input, ldm_decoded)) return error.RoundTripMismatch;
        const ldm_best = try vort.storeEncodeBestWithLongDistanceAlloc(init.gpa, case.input, .{});
        defer init.gpa.free(ldm_best);
        const ldm_best_info = try vort.store.parseHeader(ldm_best);
        const ldm_best_decoded = try vort.storeDecodeAnyAlloc(init.gpa, ldm_best);
        defer init.gpa.free(ldm_best_decoded);
        if (!std.mem.eql(u8, case.input, ldm_best_decoded)) return error.RoundTripMismatch;
        const ratio = if (case.input.len == 0) 0.0 else @as(f64, @floatFromInt(raw.len)) / @as(f64, @floatFromInt(case.input.len));
        const ldm = try vort.summarizeLongDistanceAlloc(init.gpa, case.input, .{});
        const blocks = try vort.planBlocksWithLongDistanceAlloc(init.gpa, case.input, .{ .block_len = 8192, .worker_count = 1 }, .{});
        defer init.gpa.free(blocks);
        var ldm_blocks: usize = 0;
        for (blocks) |block| {
            if (block.ldm_candidates != 0) ldm_blocks += 1;
        }
        try stdout.print("{s},{d},{d},{d},{d},{d},{d},{},{d:.4},{d},{d},{d},{d}\n", .{
            case.name,
            case.input.len,
            raw.len,
            zlib_frame.len,
            gzip_frame.len,
            ldm_frame.len,
            ldm_best.len,
            ldm_best_info.flags == 4,
            ratio,
            ldm.candidates,
            ldm.longest,
            ldm.max_distance,
            ldm_blocks,
        });
    }
    try stdout.flush();
}
