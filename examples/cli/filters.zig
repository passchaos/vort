const std = @import("std");
const vort = @import("vort");

pub fn parse(text: ?[]const u8, storage: *[3]vort.XzFilter) ![]const vort.XzFilter {
    const value = text orelse return storage[0..0];
    if (std.mem.eql(u8, value, "none")) return storage[0..0];
    var parts = std.mem.splitScalar(u8, value, ',');
    var count: usize = 0;
    while (parts.next()) |part| {
        if (count == storage.len) return error.UnsupportedXzFeature;
        const separator = std.mem.indexOfScalar(u8, part, ':');
        const name = if (separator) |index| part[0..index] else part;
        const parameter = if (separator) |index|
            try std.fmt.parseInt(u32, part[index + 1 ..], 10)
        else
            0;
        storage[count] = if (std.mem.eql(u8, name, "delta"))
            try vort.XzFilter.delta(if (separator == null) 1 else parameter)
        else if (std.mem.eql(u8, name, "x86"))
            vort.XzFilter.x86(parameter)
        else if (std.mem.eql(u8, name, "powerpc"))
            try vort.XzFilter.powerpc(parameter)
        else if (std.mem.eql(u8, name, "ia64"))
            try vort.XzFilter.ia64(parameter)
        else if (std.mem.eql(u8, name, "arm"))
            try vort.XzFilter.arm(parameter)
        else if (std.mem.eql(u8, name, "armthumb") or std.mem.eql(u8, name, "arm-thumb"))
            try vort.XzFilter.armThumb(parameter)
        else if (std.mem.eql(u8, name, "sparc"))
            try vort.XzFilter.sparc(parameter)
        else if (std.mem.eql(u8, name, "arm64"))
            try vort.XzFilter.arm64(parameter)
        else if (std.mem.eql(u8, name, "riscv") or std.mem.eql(u8, name, "risc-v"))
            try vort.XzFilter.riscv(parameter)
        else
            return error.UnsupportedXzFeature;
        count += 1;
    }
    return storage[0..count];
}
