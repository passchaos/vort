//! Owns the files and prepared entropy state behind a CLI dictionary catalog.
const std = @import("std");
const vort = @import("vort");

pub const max_files = 64;
pub const default_byte_limit = 32 * 1024 * 1024;

pub const Catalog = struct {
    prepared: []vort.ZstdPreparedDecodeDictionary,
    entries: []vort.ZstdNativeDictionary,

    pub fn load(dir: std.Io.Dir, io: std.Io, allocator: std.mem.Allocator, paths: []const []const u8, byte_limit: usize) !Catalog {
        if (paths.len > max_files) return error.OutputLimitExceeded;
        const prepared = try allocator.alloc(vort.ZstdPreparedDecodeDictionary, paths.len);
        errdefer allocator.free(prepared);
        const entries = try allocator.alloc(vort.ZstdNativeDictionary, paths.len);
        errdefer allocator.free(entries);
        var loaded: usize = 0;
        errdefer freeFiles(allocator, prepared[0..loaded]);
        var remaining = byte_limit;
        for (paths, 0..) |path, i| {
            const bytes = try readFile(dir, io, allocator, path, remaining);
            errdefer allocator.free(bytes);
            const view = try vort.ZstdNativeDictionary.initFromStandardDictionary(bytes);
            prepared[i] = try vort.ZstdPreparedDecodeDictionary.init(view.dictionary);
            entries[i] = prepared[i].handle();
            loaded += 1;
            remaining -= bytes.len;
        }
        _ = try vort.ZstdNativeDictionarySet.initChecked(entries);
        return .{ .prepared = prepared, .entries = entries };
    }

    pub fn binding(self: Catalog) ?vort.ZstdNativeDictionarySet {
        if (self.entries.len == 0) return null;
        return vort.ZstdNativeDictionarySet.init(self.entries);
    }

    pub fn deinit(self: Catalog, allocator: std.mem.Allocator) void {
        freeFiles(allocator, self.prepared);
        allocator.free(self.entries);
        allocator.free(self.prepared);
    }
};

fn freeFiles(allocator: std.mem.Allocator, prepared: []const vort.ZstdPreparedDecodeDictionary) void {
    for (prepared) |*dictionary| allocator.free(dictionary.dictionary.standard_bytes.?);
}

fn readFile(dir: std.Io.Dir, io: std.Io, allocator: std.mem.Allocator, path: []const u8, byte_limit: usize) ![]u8 {
    const file = try dir.openFile(io, path, .{});
    defer file.close(io);
    var adapter = try vort.FileByteSource.init(io, file);
    const source = adapter.source();
    if (source.len > byte_limit) return error.OutputLimitExceeded;
    const bytes = try allocator.alloc(u8, @intCast(source.len));
    errdefer allocator.free(bytes);
    try source.readExact(0, bytes);
    return bytes;
}
