const std = @import("std");
const lzms = @import("lzms");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const encoded_path = args.next() orelse return error.MissingOutputPath;
    const plain_path = args.next() orelse return error.MissingOutputPath;
    const mode = args.next() orelse "lz";
    if (std.mem.eql(u8, mode, "wide")) {
        const size = @as(usize, 106685608);
        var encoder = try lzms.PlanEncoder.init(init.gpa, size);
        defer encoder.deinit();
        try encoder.push(.{ .literal = 7 });
        try encoder.push(.{ .lz = .{ .offset = 1, .length = 106685605 } });
        try encoder.push(.{ .lz = .{ .offset = 106685605, .length = 2 } });
        const encoded = try encoder.finishAlloc();
        defer init.gpa.free(encoded);
        const expected = try init.gpa.alloc(u8, size);
        defer init.gpa.free(expected);
        @memset(expected, 7);
        try write(init, encoded_path, plain_path, encoded, expected);
        return;
    }
    const power = try std.fmt.parseInt(u8, args.next() orelse "0", 10);
    if (power > 7) return error.InvalidLzms;
    const delta = std.mem.eql(u8, mode, "delta");
    const span: usize = if (delta) @as(usize, 1) << @intCast(power) else 1;
    const offsets = [_]u32{ 8, 8, 8, 8, 1, 3, 2, 8, 8 };
    const seed = 10 * span;
    const length = 3 * span;
    const size = seed + offsets.len * length + 1;
    const expected = try init.gpa.alloc(u8, size);
    defer init.gpa.free(expected);
    var encoder = try lzms.PlanEncoder.init(init.gpa, size);
    defer encoder.deinit();
    for (0..seed) |index| {
        expected[index] = @truncate(index *% 4 + 7);
        try encoder.push(.{ .literal = expected[index] });
    }
    var position = seed;
    for (offsets, 0..) |raw_offset, index| {
        if (index == 3) {
            expected[position] = 7;
            position += 1;
            try encoder.push(.{ .literal = 7 });
        }
        const offset = raw_offset * span;
        for (0..length) |_| {
            expected[position] = if (delta) expected[position - offset] +% expected[position - span] -% expected[position - offset - span] else expected[position - offset];
            position += 1;
        }
        try encoder.push(if (delta) .{ .delta = .{ .power = power, .raw_offset = raw_offset, .length = @intCast(length) } } else .{ .lz = .{ .offset = raw_offset, .length = @intCast(length) } });
    }
    const encoded = try encoder.finishAlloc();
    defer init.gpa.free(encoded);
    try write(init, encoded_path, plain_path, encoded, expected);
}

fn write(init: std.process.Init, encoded_path: []const u8, plain_path: []const u8, encoded: []const u8, plain: []const u8) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = encoded_path, .data = encoded });
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = plain_path, .data = plain });
}
