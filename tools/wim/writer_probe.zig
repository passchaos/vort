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
    if (std.mem.eql(u8, mode, "split"))
        return writeSplit(init, output_path, compression, false);
    if (std.mem.eql(u8, mode, "pipable-split"))
        return writeSplit(init, output_path, compression, true);
    if (std.mem.eql(u8, mode, "pipable"))
        return writePipable(init, output_path, compression, false);
    if (std.mem.eql(u8, mode, "pipable-integrity"))
        return writePipable(init, output_path, compression, true);
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

fn writeSplit(
    init: std.process.Init,
    output_prefix: []const u8,
    compression: vort.WimEncodeCompression,
    pipable: bool,
) !void {
    var first_data: [70_000]u8 = undefined;
    var second_data: [70_000]u8 = undefined;
    var shared_data: [70_000]u8 = undefined;
    fillPseudoRandomSeed(&first_data, 0x1111_1111);
    fillPseudoRandomSeed(&second_data, 0x2222_2222);
    fillPseudoRandomSeed(&shared_data, 0x3333_3333);
    const first_entries = [_]vort.WimEncodeEntry{
        .{ .path = "first.bin", .data = &first_data },
        .{ .path = "shared.bin", .data = &shared_data },
    };
    const second_entries = [_]vort.WimEncodeEntry{
        .{ .path = "second.bin", .data = &second_data },
        .{ .path = "shared.bin", .data = &shared_data },
    };
    const images = [_]vort.WimEncodeImage{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    var split = if (pipable)
        try vort.encodeWimImagesPipableSplitAlloc(
            init.gpa,
            &images,
            .{ .compression = compression, .boot_index = 2 },
            .{ .max_part_size = 80_000 },
            .{},
        )
    else
        try vort.encodeWimImagesSplitAlloc(
            init.gpa,
            &images,
            .{ .compression = compression, .boot_index = 2 },
            .{ .max_part_size = 80_000 },
        );
    defer split.deinit();
    for (split.parts) |part| {
        const path = try std.fmt.allocPrint(
            init.gpa,
            "{s}.part{d}",
            .{ output_prefix, part.part_number },
        );
        defer init.gpa.free(path);
        try std.Io.Dir.cwd().writeFile(init.io, .{
            .sub_path = path,
            .data = part.bytes,
        });
    }
}

fn writePipable(
    init: std.process.Init,
    output_path: []const u8,
    compression: vort.WimEncodeCompression,
    integrity: bool,
) !void {
    const large = "Vort pipable writer multi-chunk payload\n" ** 4096;
    var random: [70_000]u8 = undefined;
    fillPseudoRandomSeed(&random, 0x5049_5045);
    const first_entries = [_]vort.WimEncodeEntry{
        .{ .path = "large.bin", .data = large },
        .{ .path = "random.bin", .data = &random },
        .{ .path = "empty" },
    };
    const second_entries = [_]vort.WimEncodeEntry{
        .{ .path = "second.txt", .data = "second pipable image\n" },
        .{ .path = "random.bin", .data = &random },
    };
    const images = [_]vort.WimEncodeImage{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "second", .entries = &second_entries },
    };
    const encoded = try vort.encodeWimImagesPipableAlloc(
        init.gpa,
        &images,
        .{ .compression = compression, .boot_index = 2 },
        .{ .integrity = integrity },
    );
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
    fillPseudoRandomSeed(output, 0x5749_4d31);
}

fn fillPseudoRandomSeed(output: []u8, seed: u32) void {
    var state = seed;
    for (output) |*byte| {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        byte.* = @truncate(state);
    }
}
