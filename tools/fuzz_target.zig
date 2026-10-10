const std = @import("std");
const vort = @import("vort");

pub fn fuzzOne(allocator: std.mem.Allocator, data: []const u8) !void {
    _ = vort.store.parseHeader(data) catch |err| switch (err) {
        error.TruncatedFrame, error.InvalidMagic, error.UnsupportedVersion, error.CorruptFrame => {},
        else => return err,
    };
    _ = vort.store.parseSkippable(data) catch |err| switch (err) {
        error.TruncatedFrame, error.InvalidMagic => {},
        else => return err,
    };
    if (vort.store.decodeFrameIndexAlloc(allocator, data)) |entries| {
        allocator.free(entries);
    } else |err| switch (err) {
        error.TruncatedFrame, error.InvalidMagic, error.TrailingData, error.IntegerOverflow => {},
        else => return err,
    }
    if (vort.decodeRawDeflateAlloc(allocator, data)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.InvalidHuffmanCode,
        error.InvalidDynamicBlockHeader,
        error.InvalidMatch,
        error.UnsupportedDeflateFeature,
        error.TrailingData,
        error.OutputTooSmall,
        => {},
        else => return err,
    }
    if (vort.decodeLzfBlockAllocLimited(allocator, data, 1 << 20)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.InvalidLzfBlock,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.decodeLzfAllocLimited(allocator, data, 1 << 20)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.TruncatedFrame,
        error.InvalidMagic,
        error.InvalidLzfBlock,
        error.InvalidLzfStream,
        error.UnsupportedLzfFeature,
        error.SizeMismatch,
        error.TrailingData,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseLhaArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.UnsupportedLhaMethod,
                error.InvalidLhaArchive,
                error.InvalidLegacyLhStream,
                error.InvalidLh1Stream,
                error.InvalidLhStream,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidLhaArchive,
        error.UnsupportedLhaHeaderLevel,
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.TrailingData,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseArjArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.EncryptedArjEntry,
                error.UnsupportedArjFeature,
                error.UnsupportedArjMethod,
                error.InvalidArjArchive,
                error.InvalidArjMethod4Stream,
                error.InvalidLegacyLhStream,
                error.InvalidLh1Stream,
                error.InvalidLhStream,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidArjArchive,
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.TrailingData,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseArcArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.UnsupportedArcMethod,
                error.InvalidArcArchive,
                error.InvalidArcCrunchStream,
                error.InvalidArcCrushedStream,
                error.InvalidArcDistilledStream,
                error.InvalidArcLzwStream,
                error.InvalidArcRleStream,
                error.InvalidArcSqueezeStream,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidArcArchive,
        error.TruncatedFrame,
        error.TrailingData,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseZooArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.OutputTooSmall,
                error.UnsupportedZooMethod,
                error.UnsupportedZooStructure,
                error.DeletedZooEntry,
                error.InvalidZooArchive,
                error.InvalidZooLzdStream,
                error.InvalidLhStream,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidZooArchive,
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseCpioArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (!entry.isExtractable()) continue;
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.OutputTooSmall,
                error.UnsupportedCpioEntry,
                error.InvalidCpioArchive,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidCpioArchive,
        error.TruncatedFrame,
        error.TrailingData,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseRarArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (entry.directory) continue;
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.OutputTooSmall,
                error.UnsupportedRarCompression,
                error.UnsupportedRarEntry,
                error.UnsupportedRarFeature,
                error.EncryptedRarEntry,
                error.SplitRarEntry,
                error.InvalidRarArchive,
                error.TruncatedFrame,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidRarArchive,
        error.EncryptedRarHeaders,
        error.TruncatedFrame,
        error.ChecksumMismatch,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseCabArchive(data)) |cabinet| {
        for (0..cabinet.folder_count) |folder_index| {
            if (vort.decodeCabFolderAllocLimited(allocator, cabinet, folder_index, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.UnsupportedCabinetFeature,
                error.UnsupportedCabinetCompression,
                error.InvalidCabinet,
                error.InvalidLzxStream,
                error.InvalidQuantumStream,
                error.IncompleteCabinetSet,
                error.CabinetSetMismatch,
                error.InvalidMatch,
                error.InvalidDeflateBlockType,
                error.StoredLengthMismatch,
                error.InvalidHuffmanCode,
                error.InvalidDynamicBlockHeader,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.SizeMismatch,
        error.UnsupportedVersion,
        error.UnsupportedCabinetFeature,
        error.InvalidCabinet,
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
}

pub fn main(init: std.process.Init) !void {
    const samples = [_][]const u8{
        "",
        "VORT",
        &.{ 0x01, 0x00, 0x00, 0xff, 0xff },
        &.{ 0xcb, 0x48, 0xcd, 0xc9, 0xc9, 0x07, 0x00 },
        &.{ 'V', 'S', 'K', 'P', 1, 0, 0, 0, 'x' },
        &.{ 'M', 'S', 'C', 'F', 0, 0, 0, 0 },
        &.{ 'Z', 'V', 0, 0, 1, 'x' },
        &.{0},
        &.{ 0x60, 0xea, 0, 0 },
        &.{ 0x1a, 0 },
        "ZOO 2.10 Archive.\x1a\x00\x00\xdc\xa7\xc4\xfd",
        "070701",
        "Rar!\x1a\x07\x01\x00",
    };
    for (samples) |sample| try fuzzOne(init.gpa, sample);

    var stdin_buffer: [4096]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().readerStreaming(init.io, &stdin_buffer);
    const stdin = &stdin_reader.interface;
    const data = stdin.allocRemaining(init.gpa, .limited(1 << 20)) catch |err| switch (err) {
        error.ReadFailed => return stdin_reader.err.?,
        error.StreamTooLong => return error.InputTooSmall,
        else => return err,
    };
    defer init.gpa.free(data);
    if (data.len != 0) try fuzzOne(init.gpa, data);

    var stdout_buffer: [128]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("fuzz target smoke: samples={d} stdin_bytes={d}\n", .{ samples.len, data.len });
    try stdout.flush();
}
