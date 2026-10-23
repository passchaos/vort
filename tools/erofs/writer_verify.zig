const std = @import("std");
const vort = @import("vort");

pub fn verify(init: std.process.Init, path: []const u8, entries: []const vort.ErofsEntry, root_attrs: []const vort.ErofsXattr, index_format: vort.ErofsWriterIndexFormat) !void {
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    var input = try vort.FileByteSource.init(init.io, file);
    var archive = try vort.ErofsSourceArchive.init(init.gpa, input.source(), .{});
    defer archive.deinit();
    try attributes(init.gpa, &archive, try archive.rootInode(), root_attrs);
    for (entries) |entry| {
        const inode = try archive.lookup(entry.path, 1024 * 1024, 1024 * 1024);
        try attributes(init.gpa, &archive, inode, entry.xattrs);
        if (entry.kind == .directory) {
            if (try inode.fileType() != .directory) return error.InvalidErofs;
            continue;
        }
        const expected = if (entry.kind == .symlink) entry.target else entry.data;
        if (entry.kind == .file and expected.len > 4096) {
            if (inode.layout != .compressed_compact or
                (inode.compressed_advise & 1 != 0) != (index_format == .compact) or
                (inode.compressed_advise & 2 != 0) != (inode.compressed_advise & 4 != 0)) return error.InvalidErofs;
        }
        var reader = try archive.initExtractor(inode, .{ .max_output_len = expected.len });
        defer reader.deinit();
        var buffer: [257]u8 = undefined;
        var delivered: usize = 0;
        while (true) {
            const progress = try reader.read(&buffer);
            if (!std.mem.eql(u8, expected[delivered..][0..progress.output_written], buffer[0..progress.output_written])) return error.SizeMismatch;
            delivered += progress.output_written;
            if (progress.status == .done) break;
        }
        if (delivered != expected.len) return error.SizeMismatch;
        for ([_]usize{ 0, 4093, 65533 }) |start| {
            if (start >= expected.len) continue;
            const size = @min(@as(usize, 31), expected.len - start);
            var range = try archive.initRangeExtractor(inode, start, size, .{ .max_output_len = size });
            defer range.deinit();
            delivered = 0;
            while (true) {
                const progress = try range.read(&buffer);
                if (!std.mem.eql(u8, expected[start + delivered ..][0..progress.output_written], buffer[0..progress.output_written])) return error.SizeMismatch;
                delivered += progress.output_written;
                if (progress.status == .done) break;
            }
            if (delivered != size) return error.SizeMismatch;
        }
    }
}

fn attributes(allocator: std.mem.Allocator, archive: *vort.ErofsSourceArchive, inode: vort.ErofsInode, expected: []const vort.ErofsXattr) !void {
    var attrs = try archive.readXattrsAllocLimited(allocator, inode, 100, 4096);
    defer attrs.deinit();
    if (attrs.entries.len != expected.len) return error.InvalidErofs;
    for (expected) |attr| {
        const actual = attrs.find(attr.name) orelse return error.InvalidErofs;
        if (!std.mem.eql(u8, actual.value, attr.value)) return error.InvalidErofs;
    }
}
