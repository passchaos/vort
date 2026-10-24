const std = @import("std");
const vort = @import("vort");
const Config = struct {
    format: []const u8 = "alone",
    mode: []const u8 = "greedy",
    dictionary_size: ?u32 = null,
    known_size: bool = false,
    block_size: usize = 1024 * 1024,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(8 * 1024 * 1024));
    defer init.gpa.free(input);
    const json = try std.Io.Dir.cwd().readFileAlloc(init.io, config_path, init.gpa, .limited(64 * 1024));
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const mode = std.meta.stringToEnum(vort.lzma.EncodeMode, config.mode) orelse return error.InvalidMode;
    const bytes = if (std.mem.eql(u8, config.format, "alone"))
        try vort.lzma.encodeAlloc(init.gpa, input, .{ .mode = mode, .dictionary_size = config.dictionary_size orelse 32768, .size_mode = if (config.known_size) .known else .end_marker })
    else if (std.mem.eql(u8, config.format, "micro"))
        try vort.lzma.encodeMicroAlloc(init.gpa, input, .{ .mode = mode, .dictionary_size = config.dictionary_size orelse 32768 })
    else if (std.mem.eql(u8, config.format, "xz")) blk: {
        const options: vort.xz.EncodeOptions = .{ .block_size = config.block_size, .dictionary_size = config.dictionary_size orelse 4096 };
        if (mode == .lazy) break :blk try vort.xz.encodeLazyAlloc(init.gpa, input, options);
        break :blk try vort.xz.encodeAlloc(init.gpa, input, options);
    } else if (std.mem.eql(u8, config.format, "raw2")) blk: {
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(init.gpa);
        _ = try vort.xz.encodeRawLzma2Append(init.gpa, &output, input);
        break :blk try output.toOwnedSlice(init.gpa);
    } else if (std.mem.eql(u8, config.format, "zip_payload")) blk: {
        // The old public facade exposes Alone but not method-14 encoding.
        // Its raw LZMA1 body is exactly the EOS payload used by method 14;
        // reconstruct only that standardized nine-byte ZIP property prefix.
        const alone = try vort.lzma.encodeAlloc(init.gpa, input, .{ .mode = mode, .dictionary_size = config.dictionary_size orelse 32768 });
        defer init.gpa.free(alone);
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(init.gpa);
        try output.appendSlice(init.gpa, &.{ 9, 4, 5, 0 });
        try output.appendSlice(init.gpa, alone[0..5]);
        try output.appendSlice(init.gpa, alone[13..]);
        break :blk try output.toOwnedSlice(init.gpa);
    } else return error.InvalidFormat;
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
