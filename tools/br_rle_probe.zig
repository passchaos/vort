const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse "rle";
    if (args.next() != null) return error.InvalidBlockPlan;
    const encoded = if (std.mem.eql(u8, mode, "rle"))
        try vort.brEncodeRleStreamAlloc(init.gpa, "a" ** 4096)
    else if (std.mem.eql(u8, mode, "ababa"))
        try vort.brEncodeAbabaStreamAlloc(init.gpa)
    else if (std.mem.eql(u8, mode, "binary-ababa"))
        try vort.brEncodeAbabaPatternStreamAlloc(init.gpa, 0, 0xff)
    else if (std.mem.startsWith(u8, mode, "alternating-"))
        try vort.brEncodeAlternatingStreamAlloc(init.gpa, 'x', 'y', try std.fmt.parseInt(usize, mode["alternating-".len..], 10))
    else if (std.mem.startsWith(u8, mode, "repeated-prefix-"))
        try vort.brEncodeRepeatedPrefixStreamAlloc(init.gpa, "abcd", try std.fmt.parseInt(usize, mode["repeated-prefix-".len..], 10))
    else if (std.mem.startsWith(u8, mode, "repeated-prefix2-"))
        try vort.brEncodeRepeatedPrefixStreamAlloc(init.gpa, "xy", try std.fmt.parseInt(usize, mode["repeated-prefix2-".len..], 10))
    else if (std.mem.startsWith(u8, mode, "repeated-prefix3-"))
        try vort.brEncodeRepeatedPrefixStreamAlloc(init.gpa, "xyz", try std.fmt.parseInt(usize, mode["repeated-prefix3-".len..], 10))
    else if (std.mem.startsWith(u8, mode, "binary-prefix3-"))
        try vort.brEncodeRepeatedPrefixStreamAlloc(init.gpa, &.{ 0, 0x80, 0xff }, try std.fmt.parseInt(usize, mode["binary-prefix3-".len..], 10))
    else if (std.mem.eql(u8, mode, "planned-mixed"))
        try vort.brEncodePlannedStreamAlloc(init.gpa, "abcabcXabcabcXabcabcX")
    else if (std.mem.eql(u8, mode, "planned-distance42"))
        try vort.brEncodePlannedStreamAlloc(init.gpa, ("abcd" ** 10) ++ "aa" ++ ("abcd" ** 10))
    else if (std.mem.eql(u8, mode, "planned-complex"))
        try vort.brEncodePlannedStreamAlloc(init.gpa, "abcdefabcdefXabcdefabcdefXabcdefabcdefX")
    else if (std.mem.eql(u8, mode, "planned-complex16"))
        try vort.brEncodePlannedStreamAlloc(init.gpa, "abcdefghijklmnop" ** 8)
    else if (std.mem.eql(u8, mode, "planned-byte-alphabet")) blk: {
        const payload = try init.gpa.alloc(u8, 768);
        defer init.gpa.free(payload);
        for (payload, 0..) |*byte, i| byte.* = @intCast(i & 0xff);
        break :blk try vort.brEncodePlannedStreamAlloc(init.gpa, payload);
    } else return error.InvalidBlockPlan;
    defer init.gpa.free(encoded);
    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(encoded);
    try stdout_writer.interface.flush();
}
