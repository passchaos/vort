const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingOutputPath;
    const count = try std.fmt.parseInt(usize, args.next() orelse "10000", 10);
    if (count > 65535) return error.OutputLimitExceeded;
    const mode = args.next() orelse "stored";
    const stored = std.mem.eql(u8, mode, "stored");
    const metabox = std.mem.eql(u8, mode, "metabox");
    if (!stored and !metabox and !std.mem.eql(u8, mode, "lz4")) return error.InvalidBlockPlan;
    const entries = try init.gpa.alloc(vort.ErofsEntry, count);
    defer init.gpa.free(entries);
    const names = try init.gpa.alloc([16]u8, count);
    defer init.gpa.free(names);
    for (entries, 0..) |*entry, index| entry.* = .{ .path = try std.fmt.bufPrint(&names[index], "f{d:0>5}", .{index}) };
    const file = try std.Io.Dir.cwd().createFile(init.io, path, .{});
    defer file.close(init.io);
    var output = vort.FileByteSink.init(init.io, file);
    _ = try vort.encodeErofsToSink(init.gpa, entries, .{ .compression = if (stored) .stored else .lz4, .compress_directories = !stored, .compression_extent_size = if (stored) 4096 else 65536, .metabox = metabox, .force_48bit = metabox }, output.sink(), .{});
}
