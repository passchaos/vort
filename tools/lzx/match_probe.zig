const std = @import("std");
const vort = @import("vort");
const lzx = vort.lzx;
const cab = vort.cab;
const wof = vort.wof;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.MissingMode;
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const window_bits = if (args.next()) |value| try std.fmt.parseInt(u5, value, 10) else 15;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(input);
    if (std.mem.eql(u8, mode, "cab-set")) {
        var set = try cab.encodeSetAlloc(init.gpa, &.{.{ .name = "payload.bin", .data = input }}, .{ .cabinet = .{ .compression = .lzx, .lzx_window_bits = window_bits }, .max_cabinet_size = 2048 });
        defer set.deinit(init.gpa);
        const archives = try init.gpa.alloc(cab.Archive, set.parts.len);
        defer init.gpa.free(archives);
        for (archives, set.parts) |*archive, part| archive.* = try cab.parse(part.bytes);
        const parsed_set = try cab.initSet(archives);
        const restored = try parsed_set.extractByNameAlloc(init.gpa, "payload.bin");
        defer init.gpa.free(restored);
        if (!std.mem.eql(u8, input, restored)) return error.SizeMismatch;
        try std.Io.Dir.cwd().createDirPath(init.io, output_path);
        var total: usize = 0;
        for (set.parts) |part| {
            const path = try std.fs.path.join(init.gpa, &.{ output_path, part.name });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = part.bytes });
            total += part.bytes.len;
        }
        std.debug.print("{{\"input\":{d},\"encoded\":{d},\"parts\":{d}}}\n", .{ input.len, total, set.parts.len });
        return;
    }
    const encoded = if (std.mem.eql(u8, mode, "cab"))
        try cab.encodeAlloc(init.gpa, &.{.{ .name = "payload.bin", .data = input }}, .{ .compression = .lzx, .lzx_window_bits = window_bits })
    else if (std.mem.eql(u8, mode, "wof"))
        try wof.encodeAlloc(init.gpa, input, .lzx)
    else if (std.mem.eql(u8, mode, "wim"))
        try lzx.encodeAlloc(init.gpa, input, .{ .format = .wim, .window_bits = window_bits })
    else if (std.mem.eql(u8, mode, "reference"))
        try lzx.encodeWimReferenceChunkAlloc(init.gpa, input, window_bits)
    else
        return error.InvalidMode;
    defer init.gpa.free(encoded);
    if (!std.mem.eql(u8, mode, "reference")) {
        const restored = if (std.mem.eql(u8, mode, "cab"))
            try cab.extractByNameAlloc(init.gpa, try cab.parse(encoded), "payload.bin")
        else if (std.mem.eql(u8, mode, "wof"))
            try wof.decodeAllocLimited(init.gpa, try wof.Backing.init(encoded, .lzx, input.len), input.len)
        else
            try lzx.decodeAllocWithFormat(init.gpa, encoded, input.len, window_bits, .wim);
        defer init.gpa.free(restored);
        if (!std.mem.eql(u8, input, restored)) return error.SizeMismatch;
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    std.debug.print("{{\"input\":{d},\"encoded\":{d}}}\n", .{ input.len, encoded.len });
}
