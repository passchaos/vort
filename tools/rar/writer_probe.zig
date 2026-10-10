const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const version_text = args.next() orelse "rar5";
    const version: vort.RarVersion = if (std.mem.eql(u8, version_text, "rar4")) .rar4 else .rar5;
    const mode = args.next() orelse "stored";
    if (std.mem.eql(u8, mode, "ppmd-solid")) {
        if (version != .rar4) return error.UnsupportedRarVersion;
        const payload = "solid history payload alpha beta gamma\n" ** 128;
        const entries = [_]vort.RarEncodeEntry{
            .{ .name = "first.txt", .data = payload },
            .{ .name = "second.txt", .data = payload },
        };
        const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .solid = true,
            .ppmd_memory_size = 1024 * 1024,
        });
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
        return;
    }
    if (std.mem.eql(u8, mode, "solid") or std.mem.eql(u8, mode, "volumes")) {
        if (std.mem.eql(u8, mode, "volumes") and version != .rar5)
            return error.UnsupportedRarVersion;
        const payload = "solid history payload alpha beta gamma\n" ** 128;
        const solid_entries = [_]vort.RarEncodeEntry{
            .{ .name = "first.txt", .data = payload },
            .{ .name = "second.txt", .data = payload },
        };
        const options = vort.RarEncodeOptions{
            .version = version,
            .compression = if (version == .rar4) .rar29 else .rar50,
            .solid = true,
        };
        if (std.mem.eql(u8, mode, "solid")) {
            const solid_bytes = try vort.encodeRarAlloc(init.gpa, &solid_entries, options);
            defer init.gpa.free(solid_bytes);
            try std.Io.Dir.cwd().writeFile(
                init.io,
                .{ .sub_path = output_path, .data = solid_bytes },
            );
        } else {
            var volumes = try vort.encodeRarVolumesAlloc(
                init.gpa,
                &solid_entries,
                options,
                40,
            );
            defer volumes.deinit();
            for (volumes.volumes, 1..) |volume, number| {
                const path = try std.fmt.allocPrint(init.gpa, "{s}.part{d}.rar", .{
                    output_path,
                    number,
                });
                defer init.gpa.free(path);
                try std.Io.Dir.cwd().writeFile(
                    init.io,
                    .{ .sub_path = path, .data = volume },
                );
            }
        }
        return;
    }
    const second_name: []const u8 = if (version == .rar5) "目录/数据.txt" else "folder/data.txt";
    const entries = [_]vort.RarEncodeEntry{
        .{ .name = "plain.txt", .data = "Vort RAR payload\n", .mode = 0o100640 },
        .{ .name = "folder", .kind = .directory },
        .{ .name = second_name, .data = &.{ 0, 1, 2, 0xff } },
    };
    const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{ .version = version });
    defer init.gpa.free(bytes);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
}
