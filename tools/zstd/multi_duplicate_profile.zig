const std = @import("std");
const zstd = @import("vort_zstd");
const provenance = @import("benchmark_provenance");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("{\"schema\":\"vort.zstd.multi-duplicate-work.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &stdout.interface);
    try stdout.interface.writeAll(",\"rows\":[");
    var row_count: usize = 0;
    var shadow = false;
    var use_anchors = false;
    while (args.next()) |path| {
        if (std.mem.eql(u8, path, "--anchors")) {
            use_anchors = true;
            continue;
        }
        if (std.mem.eql(u8, path, "--no-anchors")) {
            use_anchors = false;
            continue;
        }
        if (std.mem.eql(u8, path, "--shadow")) {
            shadow = true;
            continue;
        }
        const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
        defer file.close(init.io);
        const stat = try file.stat(init.io);
        if (stat.size < 65536 or stat.size > 131072) return error.InvalidBlockPlan;
        const payload = try init.gpa.alloc(u8, @intCast(stat.size));
        defer init.gpa.free(payload);
        var reader_buffer: [4096]u8 = undefined;
        var reader = file.reader(init.io, &reader_buffer);
        if (try reader.interface.readSliceShort(payload) != payload.len) return error.InputTooSmall;
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(init.gpa);
        var profile: zstd.NativeMultiDuplicateProfile = .{};
        const before = std.Io.Clock.awake.now(init.io);
        const available = if (use_anchors)
            try zstd.benchmarkNativeMultiDuplicateAnchorProfile(init.gpa, &out, payload, &profile, if (shadow) .shadow else .prune)
        else
            try zstd.benchmarkNativeMultiDuplicateProfileMode(init.gpa, &out, payload, &profile, if (shadow) .shadow else .prune);
        const elapsed = before.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        var input_hash: [32]u8 = undefined;
        var wire_hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(payload, &input_hash, .{});
        std.crypto.hash.sha2.Sha256.hash(out.items, &wire_hash, .{});
        if (row_count != 0) try stdout.interface.writeByte(',');
        try stdout.interface.writeAll("{\"path\":");
        try std.json.Stringify.value(path, .{}, &stdout.interface);
        try stdout.interface.print(",\"input_bytes\":{d},\"input_sha256\":\"{s}\",\"mode\":\"{s}\",\"anchors\":{s},\"available\":{s},\"encoded_bytes\":{d},\"wire_sha256\":\"{s}\",\"profiled_ns\":{d},\"work\":", .{ payload.len, std.fmt.bytesToHex(input_hash, .lower), if (shadow) "shadow" else "prune", if (use_anchors) "true" else "false", if (available) "true" else "false", out.items.len, std.fmt.bytesToHex(wire_hash, .lower), elapsed });
        try std.json.Stringify.value(profile, .{}, &stdout.interface);
        try stdout.interface.writeAll("}");
        try stdout.interface.flush();
        row_count += 1;
    }
    if (row_count == 0) return error.MissingInput;
    try stdout.interface.writeAll("]}\n");
    try stdout.interface.flush();
}
