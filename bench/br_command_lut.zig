const std = @import("std");
const lut = @import("br_command_lut");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 4096;
    var table_ns: i96 = 0;
    var formula_ns: i96 = 0;
    var table_mix: u64 = 0;
    var formula_mix: u64 = 0;
    for (0..iterations) |iteration| {
        if (iteration & 1 == 0) {
            const start = std.Io.Clock.awake.now(init.io);
            for (lut.entries) |entry| table_mix +%= entry.insert_base + entry.copy_base;
            table_ns += start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            const other = std.Io.Clock.awake.now(init.io);
            for (0..lut.entries.len) |symbol| {
                const entry = lut.formula(@intCast(symbol));
                formula_mix +%= entry.insert_base + entry.copy_base;
            }
            formula_ns += other.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        } else {
            const other = std.Io.Clock.awake.now(init.io);
            for (0..lut.entries.len) |symbol| {
                const entry = lut.formula(@intCast(symbol));
                formula_mix +%= entry.insert_base + entry.copy_base;
            }
            formula_ns += other.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
            const start = std.Io.Clock.awake.now(init.io);
            for (lut.entries) |entry| table_mix +%= entry.insert_base + entry.copy_base;
            table_ns += start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds();
        }
    }
    if (table_mix != formula_mix) return error.SizeMismatch;
    var buffer: [512]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try writer.interface.print("mode,iterations,elapsed_ns,mix\ntable,{d},{d},{d}\nformula,{d},{d},{d}\n", .{ iterations, table_ns, table_mix, iterations, formula_ns, formula_mix });
    try writer.interface.flush();
}
