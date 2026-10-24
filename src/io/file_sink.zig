const std = @import("std");
const byte_sink = @import("sink.zig");

/// Borrows a writable, seekable file and Io; caller remains responsible for closing.
pub const FileSink = struct {
    file: std.Io.File,
    io: std.Io,
    pub fn init(io: std.Io, file: std.Io.File) FileSink {
        return .{ .io = io, .file = file };
    }
    pub fn sink(self: *FileSink) byte_sink.Sink {
        return .{ .context = self, .write_at = writeAt, .set_len = setLen };
    }
    fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
        const self: *FileSink = @ptrCast(@alignCast(raw));
        return self.file.writePositional(self.io, &.{input}, offset) catch error.SinkWriteFailed;
    }
    fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
        const self: *FileSink = @ptrCast(@alignCast(raw));
        self.file.setLength(self.io, length) catch return error.SinkWriteFailed;
    }
};

test "file byte sink writes positional data and truncates without closing" {
    const io = std.testing.io;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const file = try temp.dir.createFile(io, "output", .{ .read = true });
    defer file.close(io);
    var adapter = FileSink.init(io, file);
    const output = adapter.sink();
    try output.writeExact(4, "payload");
    try output.finish(9);
    var bytes: [9]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 9), try file.readPositionalAll(io, &bytes, 0));
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 0, 0, 'p', 'a', 'y', 'l', 'o' }, &bytes);
    try std.testing.expectEqual(@as(u64, 9), (try file.stat(io)).size);
}
