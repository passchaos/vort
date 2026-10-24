const std = @import("std");
const byte_source = @import("source.zig");

/// Borrows a regular file and its Io implementation; never closes the file.
pub const FileSource = struct {
    file: std.Io.File,
    io: std.Io,
    len: u64,

    pub fn init(io: std.Io, file: std.Io.File) (std.Io.File.StatError || error{SourceReadFailed})!FileSource {
        const info = try file.stat(io);
        if (info.kind != .file) return error.SourceReadFailed;
        return .{ .file = file, .io = io, .len = info.size };
    }

    pub fn source(self: *FileSource) byte_source.Source {
        return .{ .context = self, .len = self.len, .read_at = readAt };
    }

    fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
        const self: *FileSource = @ptrCast(@alignCast(context));
        return self.file.readPositional(self.io, &.{output}, offset) catch error.SourceReadFailed;
    }
};

test "file byte source reads bounded ranges without owning the handle" {
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    try temp.dir.writeFile(io, .{ .sub_path = "input", .data = "file source payload" });
    const file = try temp.dir.openFile(io, "input", .{});
    defer file.close(io);
    var adapter = try FileSource.init(io, file);
    var input = adapter.source();
    input.max_read_size = 2;
    var output: [6]u8 = undefined;
    try input.readExact(5, &output);
    try std.testing.expectEqualStrings("source", &output);
    try std.testing.expectEqual(@as(u64, 19), adapter.len);
    // A source does not move the file position or close its caller-owned file.
    var again: [4]u8 = undefined;
    try input.readExact(0, &again);
    try std.testing.expectEqualStrings("file", &again);
}
