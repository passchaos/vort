//! Compile this tiny fixture producer against the read-only old br module.
const std = @import("std");
const br = @import("br");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingOutput;
    if (args.next() != null) return error.TooManyArguments;
    const wire = try br.encodeRleStreamAlloc(init.gpa, &@as([64]u8, @splat('R')));
    defer init.gpa.free(wire);
    const decoded = try br.decodeStreamAlloc(init.gpa, wire);
    defer init.gpa.free(decoded);
    if (!std.mem.eql(u8, decoded, &@as([64]u8, @splat('R')))) return error.InvalidOldTail;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = wire });
}
