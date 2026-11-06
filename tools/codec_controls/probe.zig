const std = @import("std");
const h = @import("common.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingConfig;
    const json = try h.read(init, path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(h.Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    if (config.family == .zlib) {
        const receipt = try @import("zlib_probe.zig").run(init, config);
        try std.json.Stringify.value(.{ .schema = "vort.codec-controls.v1", .family = config.family, .api = config.api, .window_bits = config.window_bits, .receipt = receipt, .pointer_bits = @bitSizeOf(usize), .build_mode = @tagName(@import("builtin").mode) }, .{}, &stdout.interface);
    } else {
        const receipt = try @import("zstd_probe.zig").run(init, config);
        try std.json.Stringify.value(.{ .schema = "vort.codec-controls.v1", .family = config.family, .api = config.api, .ignore_content_checksum = config.ignore_content_checksum, .receipt = receipt, .pointer_bits = @bitSizeOf(usize), .build_mode = @tagName(@import("builtin").mode) }, .{}, &stdout.interface);
    }
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
