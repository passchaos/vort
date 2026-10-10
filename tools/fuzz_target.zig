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
    if (vort.parseBgzf(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidBgzfStream,
        error.InvalidBgzfBlock,
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.TrailingData,
        error.IntegerOverflow,
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
    if (vort.parseArArchive(data)) |archive| {
        var iterator_value = archive.iterator();
        while (try iterator_value.next()) |entry| {
            if (archive.extractAllocLimited(allocator, entry, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.OutputLimitExceeded,
                error.InvalidArArchive,
                error.TruncatedFrame,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidArArchive,
        error.UnsupportedArFeature,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseDebPackage(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidArArchive,
        error.UnsupportedArFeature,
        error.InvalidDebPackage,
        error.MissingDebControlArchive,
        error.MissingDebDataArchive,
        error.UnsupportedDebCompression,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseRpmPackage(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.InvalidRpmHeader,
        error.InvalidRpmTagType,
        error.InvalidRpmPackage,
        error.UnsupportedRpmPayload,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseRarArchive(data)) |archive| {
        var iterator = archive.iterator();
        while (try iterator.next()) |entry| {
            if (entry.directory) continue;
            if (archive.extractAllocWithOptions(allocator, entry, .{
                .max_output_len = 1 << 20,
                .max_ppmd_memory = 4 << 20,
                .max_vm_instructions = 100_000,
                .max_rar50_dictionary_size = 64 << 20,
            })) |decoded| {
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
                error.InvalidRar15Stream,
                error.InvalidRar20Stream,
                error.InvalidRar29Stream,
                error.InvalidRar50Stream,
                error.InvalidRarPpmd,
                error.RarPpmdMemoryLimitExceeded,
                error.Rar50DictionaryLimitExceeded,
                error.UnsupportedRar29Ppmd,
                error.UnsupportedRar29Filter,
                error.TruncatedFrame,
                error.SizeMismatch,
                error.ChecksumMismatch,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        }
        {
            var session = archive.extractSession(allocator, .{
                .max_output_len = 1 << 20,
                .max_ppmd_memory = 4 << 20,
                .max_vm_instructions = 100_000,
                .max_rar50_dictionary_size = 64 << 20,
            });
            defer session.deinit();
            session_loop: while (true) {
                if (session.nextAlloc()) |decoded_optional| {
                    const decoded = decoded_optional orelse break;
                    allocator.free(decoded.data);
                } else |err| switch (err) {
                    error.OutputLimitExceeded,
                    error.UnsupportedRarCompression,
                    error.UnsupportedRarEntry,
                    error.UnsupportedRarFeature,
                    error.EncryptedRarEntry,
                    error.SplitRarEntry,
                    error.InvalidRarArchive,
                    error.InvalidRar15Stream,
                    error.InvalidRar20Stream,
                    error.InvalidRar29Stream,
                    error.InvalidRar50Stream,
                    error.InvalidRarPpmd,
                    error.MissingRar29SolidState,
                    error.MissingRar50SolidState,
                    error.Rar29DecoderPoisoned,
                    error.RarPpmdMemoryLimitExceeded,
                    error.Rar50DictionaryLimitExceeded,
                    error.UnsupportedRar29Ppmd,
                    error.UnsupportedRar29Filter,
                    error.TruncatedFrame,
                    error.SizeMismatch,
                    error.ChecksumMismatch,
                    error.IntegerOverflow,
                    => break :session_loop,
                    else => return err,
                }
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
    if (vort.parseRarVolumeSetAlloc(allocator, &.{data})) |set_value| {
        var set = set_value;
        set.deinit();
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidRarArchive,
        error.InvalidRarVolumeSet,
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
        &.{ 0x1f, 0x8b, 0x08, 0x04, 0, 0, 0, 0, 0, 0xff },
        &.{ 'V', 'S', 'K', 'P', 1, 0, 0, 0, 'x' },
        &.{ 'M', 'S', 'C', 'F', 0, 0, 0, 0 },
        &.{ 'Z', 'V', 0, 0, 1, 'x' },
        &.{0},
        &.{ 0x60, 0xea, 0, 0 },
        &.{ 0x1a, 0 },
        "ZOO 2.10 Archive.\x1a\x00\x00\xdc\xa7\xc4\xfd",
        "070701",
        "!<arch>\n",
        "\xed\xab\xee\xdb\x03\x00",
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
