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
    if (std.mem.eql(u8, mode, "rar5-comment-encrypted")) {
        if (version != .rar5) return error.UnsupportedRarVersion;
        const password = "rar5-comment-password";
        const header_ivs = [_][16]u8{
            [_]u8{0x11} ** 16,
            [_]u8{0x12} ** 16,
            [_]u8{0x13} ** 16,
            [_]u8{0x14} ** 16,
        };
        const entries = [_]vort.RarEncodeEntry{.{
            .name = "hidden-comment.txt",
            .data = "encrypted RAR5 archive comment interoperability\n",
            .encryption = .{
                .password = password,
                .salt = [_]u8{0x21} ** 16,
                .iv = [_]u8{0x22} ** 16,
                .kdf_count = 2,
            },
        }};
        const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{
            .version = .rar5,
            .comment = "Encrypted Vort comment 世界",
            .comment_encryption = .{
                .password = password,
                .salt = [_]u8{0x31} ** 16,
                .iv = [_]u8{0x32} ** 16,
                .kdf_count = 2,
            },
            .header_encryption = .{
                .password = password,
                .salt = [_]u8{0x41} ** 16,
                .kdf_count = 2,
                .ivs = &header_ivs,
            },
        });
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = output_path, .data = bytes },
        );
        return;
    }
    if (std.mem.eql(u8, mode, "rar5-comment")) {
        if (version != .rar5) return error.UnsupportedRarVersion;
        const entries = [_]vort.RarEncodeEntry{.{
            .name = "commented.txt",
            .data = "RAR5 archive comment interoperability\n",
        }};
        const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{
            .version = .rar5,
            .comment = "Vort RAR5 comment 世界",
        });
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = output_path, .data = bytes },
        );
        return;
    }
    if (std.mem.eql(u8, mode, "rar5-redirections")) {
        if (version != .rar5) return error.UnsupportedRarVersion;
        const entries = [_]vort.RarEncodeEntry{
            .{ .name = "target.txt", .data = "RAR5 redirection target\n" },
            .{
                .name = "unix-link",
                .redirection = .{ .kind = .unix_symlink, .target = "target.txt" },
            },
            .{
                .name = "hard-link",
                .redirection = .{ .kind = .hard_link, .target = "target.txt" },
            },
            .{ .name = "folder", .kind = .directory },
            .{
                .name = "folder-link",
                .redirection = .{
                    .kind = .unix_symlink,
                    .target = "folder",
                    .target_is_directory = true,
                },
            },
        };
        const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{
            .version = .rar5,
            .compression = .rar50,
            .solid = true,
        });
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = output_path, .data = bytes },
        );
        return;
    }
    if (std.mem.eql(u8, mode, "rar4-encrypted-volumes-stored") or
        std.mem.eql(u8, mode, "rar4-encrypted-volumes-rar29"))
    {
        if (version != .rar4) return error.UnsupportedRarVersion;
        var payload: [4096]u8 = undefined;
        var state: u64 = 0x7261_7234_766f_6c73;
        for (&payload) |*byte| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            byte.* = @truncate(state);
        }
        const password = "rar4-volume-password";
        const salt = [_]u8{0x44} ** 8;
        const entries = [_]vort.RarEncodeEntry{.{
            .name = "payload.bin",
            .data = &payload,
            .rar4_encryption = .{ .password = password, .salt = salt },
        }};
        var volumes = try vort.encodeRarVolumesAlloc(init.gpa, &entries, .{
            .version = .rar4,
            .compression = if (std.mem.endsWith(u8, mode, "rar29")) .rar29 else .stored,
            .rar4_header_encryption = .{ .password = password, .salt = salt },
        }, 700);
        defer volumes.deinit();
        for (volumes.volumes, 1..) |volume, number| {
            const path = try std.fmt.allocPrint(init.gpa, "{s}.part{d}.rar", .{
                output_path,
                number,
            });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = volume });
        }
        return;
    }
    if (std.mem.eql(u8, mode, "encrypted-volumes-stored") or
        std.mem.eql(u8, mode, "encrypted-volumes-rar50"))
    {
        if (version != .rar5) return error.UnsupportedRarVersion;
        var payload: [4096]u8 = undefined;
        var state: u64 = 0x7261_725f_766f_6c73;
        for (&payload) |*byte| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            byte.* = @truncate(state);
        }
        const password = "rar-volume-password";
        const entries = [_]vort.RarEncodeEntry{.{
            .name = "payload.bin",
            .data = &payload,
            .encryption = .{
                .password = password,
                .salt = [_]u8{0x11} ** 16,
                .iv = [_]u8{0x21} ** 16,
                .kdf_count = 2,
            },
        }};
        var options = vort.RarEncodeOptions{
            .compression = if (std.mem.endsWith(u8, mode, "rar50")) .rar50 else .stored,
        };
        const payload_budget = 700;
        var baseline = try vort.encodeRarVolumesAlloc(
            init.gpa,
            &entries,
            options,
            payload_budget,
        );
        defer baseline.deinit();
        var fragment_count: usize = 0;
        for (baseline.volumes) |volume|
            fragment_count += (try vort.parseRarArchive(volume)).entry_count;
        const iv_count = 2 * baseline.volumes.len + fragment_count;
        const header_ivs = try init.gpa.alloc([16]u8, iv_count);
        defer init.gpa.free(header_ivs);
        for (header_ivs, 0..) |*iv, index| {
            iv.* = @splat(@intCast(index + 1));
            std.mem.writeInt(u64, iv[0..8], index, .little);
        }
        options.header_encryption = .{
            .password = password,
            .salt = [_]u8{0x31} ** 16,
            .kdf_count = 2,
            .ivs = header_ivs,
        };
        var volumes = try vort.encodeRarVolumesAlloc(
            init.gpa,
            &entries,
            options,
            payload_budget,
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
        return;
    }
    if (std.mem.eql(u8, mode, "rar29-filtered-solid") or
        std.mem.eql(u8, mode, "rar29-filtered-solid-encrypted"))
    {
        if (version != .rar4) return error.UnsupportedRarVersion;
        const payload = "solid history payload alpha beta gamma\n" ** 128;
        const encryption: ?vort.RarEncodeRar4EncryptionOptions =
            if (std.mem.endsWith(u8, mode, "encrypted"))
                .{
                    .password = "rar29-filtered-solid-secret",
                    .salt = [_]u8{0x73} ** 8,
                }
            else
                null;
        const entries = [_]vort.RarEncodeEntry{
            .{ .name = "first.txt", .data = payload, .rar4_encryption = encryption },
            .{ .name = "second.txt", .data = payload, .rar4_encryption = encryption },
        };
        const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{
            .version = .rar4,
            .compression = .rar29,
            .block_size = 257,
            .filter = .{ .delta = 2 },
            .solid = true,
        });
        defer init.gpa.free(bytes);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
        return;
    }
    if (std.mem.eql(u8, mode, "ppmd-solid") or
        std.mem.eql(u8, mode, "ppmd-filtered-solid"))
    {
        if (version != .rar4) return error.UnsupportedRarVersion;
        const payload = "solid history payload alpha beta gamma\n" ** 128;
        const entries = [_]vort.RarEncodeEntry{
            .{ .name = "first.txt", .data = payload },
            .{ .name = "second.txt", .data = payload },
        };
        const bytes = try vort.encodeRarAlloc(init.gpa, &entries, .{
            .version = .rar4,
            .compression = .rar29_ppmd,
            .block_size = 257,
            .filter = if (std.mem.eql(u8, mode, "ppmd-filtered-solid"))
                .{ .delta = 2 }
            else
                null,
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
