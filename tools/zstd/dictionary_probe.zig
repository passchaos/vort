const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingCorpusPath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(bytes);
    const owned = try vort.ZstdOwnedStandardDictionary.initCopy(init.gpa, bytes);
    defer owned.deinit(init.gpa);
    const parsed = try vort.ZstdNativeDictionary.initFromStandardDictionary(owned.bytes);
    const owned_dictionary = owned.asDictionary();
    if (owned_dictionary.id != parsed.dictionary.id or owned_dictionary.content.ptr != owned.view.content.ptr) return error.InvalidDictionaryMetadata;
    if (owned_dictionary.kind() != .standard_full or (try owned_dictionary.standardView()) == null) return error.InvalidDictionaryMetadata;
    const view = parsed.view;
    if (parsed.dictionary.id != view.id or parsed.dictionary.content.ptr != view.content.ptr) return error.InvalidDictionaryMetadata;
    var buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("id={d} content_offset={d} content={d} repcodes={d}/{d}/{d}\n", .{ view.id, view.content_offset, view.content.len, view.repcodes[0], view.repcodes[1], view.repcodes[2] });
    try stdout.interface.flush();
}
