const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.InvalidBlockPlan;
    const lazy = std.mem.startsWith(u8, mode, "lazy-");
    const ratio = std.mem.startsWith(u8, mode, "ratio-");
    const static_dictionary = std.mem.startsWith(u8, mode, "dictionary-");
    const stable_fast = std.mem.startsWith(u8, mode, "stable-fast-");
    const stable_balanced = std.mem.startsWith(u8, mode, "stable-balanced-");
    const dictionary_index_bytes = std.mem.eql(u8, mode, "dictionary-index-bytes");
    if (dictionary_index_bytes) {
        var text: [32]u8 = undefined;
        const written = try std.fmt.bufPrint(&text, "{d}\n", .{vort.brPlannedStaticDictionaryIndexBytes()});
        try std.Io.File.stdout().writeStreamingAll(init.io, written);
        return;
    }
    const name = if (lazy) mode["lazy-".len..] else if (ratio) mode["ratio-".len..] else if (static_dictionary) mode["dictionary-".len..] else if (stable_fast) mode["stable-fast-".len..] else if (stable_balanced) mode["stable-balanced-".len..] else mode;
    const payload = if (std.mem.eql(u8, name, "json"))
        "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48
    else if (std.mem.eql(u8, name, "source"))
        "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40
    else if (std.mem.eql(u8, name, "log"))
        "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40
    else if (std.mem.eql(u8, name, "words"))
        " information follows the information"
    else if (std.mem.eql(u8, name, "dictionary-short"))
        "Information about compression performance and dictionary support."
    else if (std.mem.eql(u8, name, "dictionary-mixed"))
        "abcdefghabcdefgh information follows abcdefghabcdefgh"
    else if (std.mem.eql(u8, name, "dictionary-word"))
        "information"
    else if (std.mem.eql(u8, name, "dictionary-uppercase"))
        "INFORMATION"
    else if (std.mem.eql(u8, name, "dictionary-unmatched"))
        "qzxwvbnm"
    else if (std.mem.eql(u8, name, "ratio-incompressible"))
        "qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
    else if (std.mem.eql(u8, name, "incompressible"))
        "qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
    else if (std.mem.eql(u8, name, "tiny"))
        "abcd"
    else
        return error.InvalidBlockPlan;
    const encoded = if (stable_fast)
        try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, payload, .{ .level = .fast })
    else if (stable_balanced)
        try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, payload, .{ .level = .balanced })
    else if (lazy)
        try vort.brEncodePlannedStreamLazyAlloc(init.gpa, payload)
    else if (ratio)
        try vort.brEncodePlannedStreamRatioAlloc(init.gpa, payload)
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
