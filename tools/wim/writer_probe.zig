const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression_name = args.next() orelse "xpress";
    const mode = args.next() orelse "basic";
    const source_path = args.next();
    const compression = parseCompression(compression_name) orelse
        return error.InvalidBlockPlan;

    if (std.mem.eql(u8, mode, "streams"))
        return writeStreams(init, output_path, compression);
    if (std.mem.eql(u8, mode, "inode"))
        return writeInodeMetadata(init, output_path, compression);
    if (std.mem.eql(u8, mode, "multi"))
        return writeMultiImage(init, output_path, compression);
    if (std.mem.eql(u8, mode, "solid"))
        return writeSolid(init, output_path);
    if (std.mem.eql(u8, mode, "append"))
        return writeAppended(init, output_path, false);
    if (std.mem.eql(u8, mode, "solid-append"))
        return writeAppended(init, output_path, true);
    if (std.mem.eql(u8, mode, "append-existing"))
        return writeAppendedExisting(
            init,
            output_path,
            source_path orelse return error.MissingCorpusPath,
        );
    if (std.mem.eql(u8, mode, "delete"))
        return writeDeleted(init, output_path, false);
    if (std.mem.eql(u8, mode, "solid-delete"))
        return writeDeleted(init, output_path, true);
    if (std.mem.eql(u8, mode, "delete-existing"))
        return writeDeletedExisting(
            init,
            output_path,
            source_path orelse return error.MissingCorpusPath,
        );
    if (std.mem.eql(u8, mode, "replace"))
        return writeReplaced(init, output_path, false);
    if (std.mem.eql(u8, mode, "solid-replace"))
        return writeReplaced(init, output_path, true);
    if (std.mem.eql(u8, mode, "replace-existing"))
        return writeReplacedExisting(
            init,
            output_path,
            source_path orelse return error.MissingCorpusPath,
        );
    if (std.mem.eql(u8, mode, "compact"))
        return writeCompacted(init, output_path, false);
    if (std.mem.eql(u8, mode, "solid-compact"))
        return writeCompacted(init, output_path, true);
    if (std.mem.eql(u8, mode, "compact-existing"))
        return writeCompactedExisting(
            init,
            output_path,
            source_path orelse return error.MissingCorpusPath,
        );
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
    const unix_data = vort.encodeWimUnixMetadata(.{
        .uid = 1000,
        .gid = 1001,
        .mode = 0o100640,
        .rdev = 7,
    });
    const object_id = vort.encodeWimObjectId(.{
        .object_id = .{
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        },
        .birth_volume_id = @splat(0x55),
        .birth_object_id = @splat(0x55),
        .domain_id = @splat(0x55),
    });
    const xattr_bytes = try vort.encodeWimXattrsAlloc(init.gpa, &.{.{
        .name = "user.vort",
        .value = "Vort WIM xattr",
    }});
    defer init.gpa.free(xattr_bytes);
    const hard_tags = [_]vort.WimEncodeTaggedItem{.{
        .tag = vort.wimTaggedItemWimlibUnixData,
        .data = &unix_data,
    }};
    const object_tags = [_]vort.WimEncodeTaggedItem{
        .{
            .tag = vort.wimTaggedItemObjectId,
            .data = &object_id,
        },
        .{
            .tag = vort.wimTaggedItemXattrs,
            .data = xattr_bytes,
        },
    };
    const entries = [_]vort.WimEncodeEntry{
        .{
            .path = "hard/a.txt",
            .short_name = "HARDLI~1.TXT",
            .data = "hard linked writer payload\n",
            .named_streams = &link_streams,
            .security_descriptor = &null_dacl,
            .tagged_items = &hard_tags,
            .hard_link_id = 0x4242,
        },
        .{
            .path = "hard/b.txt",
            .short_name = "HARDLI~2.TXT",
            .data = "hard linked writer payload\n",
            .named_streams = &link_streams,
            .security_descriptor = &null_dacl,
            .tagged_items = &hard_tags,
            .hard_link_id = 0x4242,
        },
        .{
            .path = "independent.txt",
            .short_name = "INDEPE~1.TXT",
            .data = "independent security descriptor\n",
            .security_descriptor = &world_owner,
            .tagged_items = &object_tags,
        },
        .{
            .path = "no-security.txt",
            .short_name = "NO-SEC~1.TXT",
            .data = "no security descriptor\n",
        },
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

fn writeSolid(
    init: std.process.Init,
    output_path: []const u8,
) !void {
    var repeated: [70_000]u8 = undefined;
    const phrase = "Vort solid LZMS writer payload 0123456789\n";
    for (&repeated, 0..) |*byte, index|
        byte.* = phrase[index % phrase.len];
    var random: [70_000]u8 = undefined;
    fillPseudoRandomSeed(&random, 0x534f_4c49);
    const shared = "shared packed LZMS stream\n" ** 1024;
    const first_entries = [_]vort.WimEncodeEntry{
        .{ .path = "repeat.bin", .data = &repeated },
        .{ .path = "shared.bin", .data = shared },
    };
    const second_entries = [_]vort.WimEncodeEntry{
        .{ .path = "random.bin", .data = &random },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]vort.WimEncodeImage{
        .{ .name = "solid-first", .entries = &first_entries },
        .{ .name = "solid-second", .entries = &second_entries },
    };
    const encoded = try vort.encodeWimImagesSolidAlloc(init.gpa, &images, .{
        .metadata_chunk_size = 32 * 1024,
        .solid_chunk_size = 32 * 1024,
        .boot_index = 2,
    });
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = encoded,
    });
}

fn writeAppended(
    init: std.process.Init,
    output_path: []const u8,
    solid: bool,
) !void {
    const shared = "shared appended WIM payload\n" ** 1024;
    const old_payload = "old image payload\n" ** 2048;
    const new_payload = "new image payload\n" ** 2048;
    const base_entries = [_]vort.WimEncodeEntry{
        .{ .path = "old.bin", .data = old_payload },
        .{ .path = "shared.bin", .data = shared },
    };
    const base = if (solid)
        try vort.encodeWimSolidAlloc(init.gpa, &base_entries, .{
            .metadata_chunk_size = 32 * 1024,
            .solid_chunk_size = 32 * 1024,
            .image_name = "base",
            .bootable = true,
        })
    else
        try vort.encodeWimAlloc(init.gpa, &base_entries, .{
            .compression = .xpress,
            .image_name = "base",
            .bootable = true,
        });
    defer init.gpa.free(base);
    const new_entries = [_]vort.WimEncodeEntry{
        .{ .path = "new.bin", .data = new_payload },
        .{ .path = "shared.bin", .data = shared },
    };
    const updated = try vort.appendWimImageAlloc(init.gpa, base, .{
        .name = "appended",
        .entries = &new_entries,
    }, .{
        .bootable = true,
        .solid_chunk_size = if (solid) 32 * 1024 else null,
    });
    defer init.gpa.free(updated);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = updated,
    });
}

fn writeAppendedExisting(
    init: std.process.Init,
    output_path: []const u8,
    source_path: []const u8,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        source_path,
        init.gpa,
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(source);
    const entries = [_]vort.WimEncodeEntry{.{
        .path = "added.txt",
        .data = "Vort appended to a wimlib archive\n",
    }};
    const updated = try vort.appendWimImageAlloc(init.gpa, source, .{
        .name = "vort-appended",
        .entries = &entries,
    }, .{});
    defer init.gpa.free(updated);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = updated,
    });
}

fn writeDeleted(
    init: std.process.Init,
    output_path: []const u8,
    solid: bool,
) !void {
    const shared = "shared deleted WIM payload\n" ** 1024;
    const first_entries = [_]vort.WimEncodeEntry{
        .{ .path = "first.bin", .data = "first remains after delete\n" ** 1024 },
        .{ .path = "shared.bin", .data = shared },
    };
    const deleted_entries = [_]vort.WimEncodeEntry{
        .{ .path = "deleted.bin", .data = "deleted image payload\n" ** 1024 },
        .{ .path = "shared.bin", .data = shared },
    };
    const third_entries = [_]vort.WimEncodeEntry{
        .{ .path = "shared.bin", .data = shared },
        .{ .path = "third.bin", .data = "third becomes second\n" ** 1024 },
    };
    const images = [_]vort.WimEncodeImage{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "deleted", .entries = &deleted_entries },
        .{ .name = "third", .entries = &third_entries },
    };
    const source = if (solid)
        try vort.encodeWimImagesSolidAlloc(init.gpa, &images, .{
            .metadata_chunk_size = 32 * 1024,
            .solid_chunk_size = 32 * 1024,
            .boot_index = 3,
        })
    else
        try vort.encodeWimImagesAlloc(init.gpa, &images, .{
            .compression = .xpress,
            .boot_index = 3,
        });
    defer init.gpa.free(source);
    const updated = try vort.deleteWimImageAlloc(init.gpa, source, 2, .{});
    defer init.gpa.free(updated);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = updated,
    });
}

fn writeDeletedExisting(
    init: std.process.Init,
    output_path: []const u8,
    source_path: []const u8,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        source_path,
        init.gpa,
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(source);
    const entries = [_]vort.WimEncodeEntry{.{
        .path = "survivor.txt",
        .data = "surviving appended image\n",
    }};
    const appended = try vort.appendWimImageAlloc(init.gpa, source, .{
        .name = "survivor",
        .entries = &entries,
    }, .{});
    defer init.gpa.free(appended);
    const updated = try vort.deleteWimImageAlloc(init.gpa, appended, 1, .{});
    defer init.gpa.free(updated);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = updated,
    });
}

fn writeReplaced(
    init: std.process.Init,
    output_path: []const u8,
    solid: bool,
) !void {
    const shared = "shared replaced WIM payload\n" ** 1024;
    const first_entries = [_]vort.WimEncodeEntry{
        .{ .path = "first.bin", .data = "first remains after replace\n" ** 1024 },
        .{ .path = "shared.bin", .data = shared },
    };
    const old_entries = [_]vort.WimEncodeEntry{
        .{ .path = "old.bin", .data = "old replaced image payload\n" ** 1024 },
        .{ .path = "shared.bin", .data = shared },
    };
    const third_entries = [_]vort.WimEncodeEntry{
        .{ .path = "third.bin", .data = "third remains after replace\n" ** 1024 },
        .{ .path = "shared.bin", .data = shared },
    };
    const images = [_]vort.WimEncodeImage{
        .{ .name = "first", .entries = &first_entries },
        .{ .name = "replace-me", .entries = &old_entries },
        .{ .name = "third", .entries = &third_entries },
    };
    const source = if (solid)
        try vort.encodeWimImagesSolidAlloc(init.gpa, &images, .{
            .metadata_chunk_size = 32 * 1024,
            .solid_chunk_size = 32 * 1024,
            .boot_index = 2,
        })
    else
        try vort.encodeWimImagesAlloc(init.gpa, &images, .{
            .compression = .xpress,
            .boot_index = 2,
        });
    defer init.gpa.free(source);
    const replacement_entries = [_]vort.WimEncodeEntry{
        .{ .path = "new.bin", .data = "new replacement image payload\n" ** 1024 },
        .{ .path = "shared.bin", .data = shared },
    };
    const updated = try vort.replaceWimImageAlloc(init.gpa, source, 2, .{
        .name = "replaced",
        .entries = &replacement_entries,
    }, .{
        .solid_chunk_size = if (solid) 32 * 1024 else null,
    });
    defer init.gpa.free(updated);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = updated,
    });
}

fn writeReplacedExisting(
    init: std.process.Init,
    output_path: []const u8,
    source_path: []const u8,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        source_path,
        init.gpa,
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(source);
    const entries = [_]vort.WimEncodeEntry{.{
        .path = "replacement.txt",
        .data = "Vort replaced a wimlib archive image\n",
    }};
    const updated = try vort.replaceWimImageAlloc(init.gpa, source, 1, .{
        .name = "vort-replaced",
        .entries = &entries,
    }, .{ .bootable = true });
    defer init.gpa.free(updated);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = updated,
    });
}

fn writeCompacted(
    init: std.process.Init,
    output_path: []const u8,
    solid: bool,
) !void {
    const first_entries = [_]vort.WimEncodeEntry{.{
        .path = "first.bin",
        .data = "first survives compaction\n" ** 1024,
    }};
    const base = if (solid)
        try vort.encodeWimSolidAlloc(init.gpa, &first_entries, .{
            .metadata_chunk_size = 32 * 1024,
            .solid_chunk_size = 32 * 1024,
            .image_name = "first",
        })
    else
        try vort.encodeWimAlloc(init.gpa, &first_entries, .{
            .compression = .xpress,
            .image_name = "first",
        });
    defer init.gpa.free(base);
    const dead_entries = [_]vort.WimEncodeEntry{.{
        .path = "dead.bin",
        .data = "dead compacted image payload\n" ** 1024,
    }};
    const with_dead = try vort.appendWimImageAlloc(init.gpa, base, .{
        .name = "dead",
        .entries = &dead_entries,
    }, .{
        .solid_chunk_size = if (solid) 32 * 1024 else null,
    });
    defer init.gpa.free(with_dead);
    const third_entries = [_]vort.WimEncodeEntry{.{
        .path = "third.bin",
        .data = "third survives compaction\n" ** 1024,
    }};
    const with_third = try vort.appendWimImageAlloc(init.gpa, with_dead, .{
        .name = "third",
        .entries = &third_entries,
    }, .{
        .bootable = true,
        .solid_chunk_size = if (solid) 32 * 1024 else null,
    });
    defer init.gpa.free(with_third);
    const deleted = try vort.deleteWimImageAlloc(init.gpa, with_third, 2, .{});
    defer init.gpa.free(deleted);
    const compacted = try vort.compactWimAlloc(init.gpa, deleted, .{});
    defer init.gpa.free(compacted);
    if (compacted.len >= deleted.len) return error.InvalidBlockPlan;
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = compacted,
    });
}

fn writeCompactedExisting(
    init: std.process.Init,
    output_path: []const u8,
    source_path: []const u8,
) !void {
    const source = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        source_path,
        init.gpa,
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(source);
    const compacted = try vort.compactWimAlloc(init.gpa, source, .{});
    defer init.gpa.free(compacted);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = compacted,
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
        .chunk_size = if (compression == .lzx) 64 * 1024 else null,
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
    if (std.mem.eql(u8, name, "lzx")) return .lzx;
    if (std.mem.eql(u8, name, "lzms")) return .lzms;
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
