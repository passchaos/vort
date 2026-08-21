const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.InvalidBlockPlan;
    const lazy = std.mem.startsWith(u8, mode, "lazy-");
    const static_dictionary = std.mem.startsWith(u8, mode, "dictionary-");
    const name = if (lazy) mode["lazy-".len..] else if (static_dictionary) mode["dictionary-".len..] else mode;
    const payload = if (std.mem.eql(u8, name, "json"))
        "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48
    else if (std.mem.eql(u8, name, "source"))
        "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40
    else if (std.mem.eql(u8, name, "log"))
        "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40
    else if (std.mem.eql(u8, name, "words"))
        " information follows the information"
    else
        return error.InvalidBlockPlan;
    const encoded = if (lazy)
        try vort.brEncodePlannedStreamLazyAlloc(init.gpa, payload)
    else if (static_dictionary)
        try vort.brEncodePlannedStreamStaticDictionaryAlloc(init.gpa, payload)
    else
        try vort.brEncodePlannedStreamAlloc(init.gpa, payload);
    defer init.gpa.free(encoded);
    var buffer: [256]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try writer.interface.writeAll(encoded);
    try writer.interface.flush();
}
