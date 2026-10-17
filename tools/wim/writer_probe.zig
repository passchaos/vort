const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression_name = args.next() orelse "xpress";
    const mode = args.next() orelse "basic";
    const compression = parseCompression(compression_name) orelse
        return error.InvalidBlockPlan;

    if (std.mem.eql(u8, mode, "streams"))
        return writeStreams(init, output_path, compression);
    if (std.mem.eql(u8, mode, "inode"))
        return writeInodeMetadata(init, output_path, compression);
    if (std.mem.eql(u8, mode, "multi"))
        return writeMultiImage(init, output_path, compression);
    if (!std.mem.eql(u8, mode, "basic")) return error.InvalidBlockPlan;

    const large = "Vort WIM writer multichunk payload 0123456789\n" ** 4096;
    var random: [70_000]u8 = undefined;
    fillPseudoRandom(&random);
    const entries = [_]vort.WimEncodeEntry{
        .{ .path = "nested/config.txt", .data = "Vort WIM writer interop\n" },
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "empty.bin" },
        .{ .path = "unicode/文件.txt", .data = "UTF-8 WIM path\n" },
    };
    try writeArchive(init, output_path, compression, &entries, null);
}

fn writeStreams(
    init: std.process.Init,
    output_path: []const u8,
    compression: vort.WimEncodeCompression,
) !void {
    const file_streams = [_]vort.WimEncodeNamedStream{
        .{ .name = "Zone.Identifier", .data = "[ZoneTransfer]\r\nZoneId=3\r\n" },
        .{ .name = "空", .data = "" },
    };
    const directory_streams = [_]vort.WimEncodeNamedStream{.{
        .name = "directory.meta",
        .data = "directory alternate data",
    }};
    const symlink_payload = [_]u8{
        0x00, 0x00, 0x14, 0x00, 0x16, 0x00, 0x14, 0x00,
        0x01, 0x00, 0x00, 0x00, 'c',  0,    'o',  0,
        'n',  0,    'f',  0,    'i',  0,    'g',  0,
        '.',  0,    't',  0,    'x',  0,    't',  0,
        0,    0,    'c',  0,    'o',  0,    'n',  0,
        'f',  0,    'i',  0,    'g',  0,    '.',  0,
        't',  0,    'x',  0,    't',  0,    0,    0,
    };
    const entries = [_]vort.WimEncodeEntry{
        .{ .path = "config.txt", .data = "symlink target\n" },
        .{
            .path = "streamed.txt",
            .data = "ordinary stream\n",
            .named_streams = &file_streams,
        },
        .{
            .path = "ads-dir",
            .kind = .directory,
            .named_streams = &directory_streams,
        },
        .{
            .path = "link",
            .reparse = .{ .tag = 0xa000_000c, .data = &symlink_payload },
        },
        .{
            .path = "dual.bin",
            .data = "ordinary bytes on reparse point",
            .reparse = .{ .tag = 0x8000_001b, .data = "dual reparse bytes" },
        },
        .{ .path = "secret.dat", .encrypted_raw = "opaque EFSRPC raw file data" },
        .{
            .path = "encrypted-dir",
            .kind = .directory,
            .encrypted_raw = "opaque EFSRPC raw directory data",
        },
    };
    try writeArchive(init, output_path, compression, &entries, null);
}

fn writeInodeMetadata(
    init: std.process.Init,
    output_path: []const u8,
    compression: vort.WimEncodeCompression,
) !void {
    const null_dacl = [_]u8{ 1, 0, 4, 0x80 } ++ [_]u8{0} ** 16;
    const world_owner = [_]u8{
        1,  0, 0, 0x80,
        20, 0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        0,  0, 0, 0,
        1,  1, 0, 0,
        0,  0, 0, 1,
        0,  0, 0, 0,
    };
    const link_streams = [_]vort.WimEncodeNamedStream{.{
        .name = "link.ads",
        .data = "hard link alternate stream",
    }};
    const entries = [_]vort.WimEncodeEntry{
        .{
            .path = "hard/a.txt",
            .data = "hard linked writer payload\n",
            .named_streams = &link_streams,
            .security_descriptor = &null_dacl,
            .hard_link_id = 0x4242,
        },
        .{
            .path = "hard/b.txt",
            .data = "hard linked writer payload\n",
            .named_streams = &link_streams,
            .security_descriptor = &null_dacl,
            .hard_link_id = 0x4242,
        },
        .{
            .path = "independent.txt",
            .data = "independent security descriptor\n",
            .security_descriptor = &world_owner,
        },
        .{ .path = "no-security.txt", .data = "no security descriptor\n" },
    };
    try writeArchive(init, output_path, compression, &entries, &null_dacl);
}

fn writeMultiImage(
    init: std.process.Init,
    output_path: []const u8,
    compression: vort.WimEncodeCompression,
) !void {
    const first_entries = [_]vort.WimEncodeEntry{
        .{ .path = "shared.txt", .data = "shared multi-image payload\n" },
        .{ .path = "first.txt", .data = "first image payload\n" },
    };
    const second_entries = [_]vort.WimEncodeEntry{
        .{ .path = "shared.txt", .data = "shared multi-image payload\n" },
        .{ .path = "second.txt", .data = "second image payload\n" },
    };
    const images = [_]vort.WimEncodeImage{
        .{ .name = "first", .entries = &first_entries, .creation_time = 1 },
        .{ .name = "second", .entries = &second_entries, .creation_time = 2 },
        .{ .name = "empty-a", .entries = &.{} },
        .{ .name = "empty-b", .entries = &.{} },
    };
    const encoded = try vort.encodeWimImagesAlloc(init.gpa, &images, .{
        .compression = compression,
        .boot_index = 2,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
}

fn writeArchive(
    init: std.process.Init,
    output_path: []const u8,
    compression: vort.WimEncodeCompression,
    entries: []const vort.WimEncodeEntry,
    root_security_descriptor: ?[]const u8,
) !void {
    const encoded = try vort.encodeWimAlloc(init.gpa, entries, .{
        .compression = compression,
        .image_name = "Vort writer & interoperability",
        .root_security_descriptor = root_security_descriptor,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
}

fn parseCompression(name: []const u8) ?vort.WimEncodeCompression {
    if (std.mem.eql(u8, name, "stored")) return .stored;
    if (std.mem.eql(u8, name, "xpress")) return .xpress;
    return null;
}

fn fillPseudoRandom(output: []u8) void {
    var state: u32 = 0x5749_4d31;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
