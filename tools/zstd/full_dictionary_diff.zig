const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(bytes);
    const parsed = try vort.ZstdNativeDictionary.initFromStandardDictionary(bytes);
    const payload = "standard dictionary sample alpha standard dictionary sample beta";
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();

    const vort_encoded = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(init.gpa, payload, .{ .content_checksum = false }, parsed.dictionary);
    defer init.gpa.free(vort_encoded.frame);
    var output: [payload.len]u8 = undefined;
    try runtime.decodeUsingDict(vort_encoded.frame, &output, bytes);
    if (!std.mem.eql(u8, payload, &output)) return error.SizeMismatch;
    const reference_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, bytes, 1);
    defer init.gpa.free(reference_encoded);
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(init.gpa, reference_encoded, parsed.dictionary);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;

    var buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("zstd_full_dictionary_diff=ok version={s} id={d} vort={d} reference={d}\n", .{ runtime.version(), parsed.view.id, vort_encoded.frame.len, reference_encoded.len });
    try stdout.interface.flush();
}
