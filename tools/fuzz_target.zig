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
    if (vort.parseXerialSnappy(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidXerialSnappyStream,
        error.InvalidMatch,
        error.UnsupportedSnappyFeature,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseHadoopSnappy(data)) |_| {} else |err| switch (err) {
        error.InvalidHadoopSnappyStream,
        error.InvalidMatch,
        error.UnsupportedSnappyFeature,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseHadoopLz4(data)) |_| {} else |err| switch (err) {
        error.InvalidHadoopLz4Stream,
        error.InvalidMatch,
        error.TruncatedFrame,
        error.IntegerOverflow,
        error.OutputLimitExceeded,
        => {},
        else => return err,
    }
    if (vort.decodeLz4LegacyAllocLimited(allocator, data, 1 << 20)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidLz4LegacyStream,
        error.InvalidMatch,
        error.TruncatedFrame,
        error.IntegerOverflow,
        error.OutputLimitExceeded,
        => {},
        else => return err,
    }
    if (vort.decodeLznt1AllocLimited(allocator, data, 1 << 20)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.InvalidLznt1,
        error.InvalidMatch,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.TrailingData,
        error.IntegerOverflow,
        error.OutputLimitExceeded,
        => {},
        else => return err,
    }
    if (vort.decodeXpressPlainAllocLimited(allocator, data, 1 << 20)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.InvalidXpress,
        error.InvalidMatch,
        error.TruncatedFrame,
        error.IntegerOverflow,
        error.OutputLimitExceeded,
        => {},
        else => return err,
    }
    if (data.len >= 2) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        if (vort.decodeXpressHuffmanAllocExactSize(
            allocator,
            data[2..],
            expected_size,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| switch (err) {
            error.InvalidXpress,
            error.InvalidHuffmanCode,
            error.InvalidMatch,
            error.TruncatedFrame,
            error.TrailingData,
            error.IntegerOverflow,
            error.OutputLimitExceeded,
            => {},
            else => return err,
        }
    }
    if (data.len >= 3) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        const dictionary_size: u32 = @as(u32, 4096) << @intCast(@min(data[2] & 0x0f, 11));
        if (vort.decodeMicroLzmaAllocLimited(
            allocator,
            data[3..],
            expected_size,
            dictionary_size,
            1 << 20,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| switch (err) {
            error.InvalidLzmaHeader,
            error.InvalidLzmaStream,
            error.TruncatedFrame,
            error.TrailingData,
            error.SizeMismatch,
            error.OutputLimitExceeded,
            error.IntegerOverflow,
            => {},
            else => return err,
        }
    }
    if (data.len >= 5) {
        const algorithm: vort.WofAlgorithm = @enumFromInt(data[0] & 3);
        const expected_size: usize = std.mem.readInt(u32, data[1..5], .little);
        if (vort.parseWofBacking(data[5..], algorithm, expected_size)) |backing| {
            if (vort.decodeWofAllocLimited(allocator, backing, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.InvalidWof,
                error.InvalidXpress,
                error.InvalidLzxStream,
                error.InvalidHuffmanCode,
                error.InvalidMatch,
                error.UnsupportedCabinetFeature,
                error.TruncatedFrame,
                error.TrailingData,
                error.SizeMismatch,
                error.OutputLimitExceeded,
                error.IntegerOverflow,
                => {},
                else => return err,
            }
        } else |err| switch (err) {
            error.InvalidWof,
            error.TruncatedFrame,
            error.TrailingData,
            error.IntegerOverflow,
            => {},
            else => return err,
        }
    }
    if (vort.parseWofExternalInfo(data)) |_| {} else |err| switch (err) {
        error.InvalidWof,
        error.UnsupportedWofProvider,
        error.UnsupportedWofCompression,
        => {},
        else => return err,
    }
    if (vort.parseWofReparsePoint(data)) |_| {} else |err| switch (err) {
        error.InvalidWof,
        error.UnsupportedWofProvider,
        error.UnsupportedWofCompression,
        => {},
        else => return err,
    }
    if (data.len >= 2) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        if (vort.decodeLzmsAllocLimited(
            allocator,
            data[2..],
            expected_size,
            1 << 20,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| switch (err) {
            error.InvalidLzms,
            error.InvalidHuffmanCode,
            error.CorruptFrame,
            error.OutputLimitExceeded,
            error.IntegerOverflow,
            => {},
            else => return err,
        }
    }
    if (vort.decodeLzfseAllocLimited(allocator, data, 1 << 20)) |decoded| {
        allocator.free(decoded);
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidLzfseStream,
        error.InvalidLzvnStream,
        error.TruncatedFrame,
        error.TrailingData,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.OutputLimitExceeded,
        => {},
        else => return err,
    }
    if (data.len >= 2) {
        const xattr_len = @min(
            @as(usize, std.mem.readInt(u16, data[0..2], .little)),
            data.len - 2,
        );
        const xattr = data[2..][0..xattr_len];
        const resource_bytes = data[2 + xattr_len ..];
        const resource: ?[]const u8 = if (resource_bytes.len == 0)
            null
        else
            resource_bytes;
        if (vort.parseDecmpfs(xattr, resource)) |archive| {
            if (archive.decodeAllocLimited(allocator, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| switch (err) {
                error.InvalidDecmpfs,
                error.UnsupportedDecmpfsType,
                error.InvalidMagic,
                error.TruncatedFrame,
                error.TrailingData,
                error.IntegerOverflow,
                error.RangeOutOfBounds,
                error.OutputLimitExceeded,
                error.OutputTooSmall,
                error.SizeMismatch,
                error.BadZlibHeader,
                error.NeedDictionary,
                error.ChecksumMismatch,
                error.InvalidDeflateBlockType,
                error.StoredLengthMismatch,
                error.InvalidHuffmanCode,
                error.InvalidDynamicBlockHeader,
                error.InvalidMatch,
                error.UnsupportedDeflateFeature,
                error.InvalidLzfseStream,
                error.InvalidLzvnStream,
                => {},
                else => return err,
            }
        } else |err| switch (err) {
            error.InvalidDecmpfs,
            error.UnsupportedDecmpfsType,
            error.MissingDecmpfsResourceFork,
            error.InvalidMagic,
            error.TruncatedFrame,
            error.TrailingData,
            error.IntegerOverflow,
            => {},
            else => return err,
        }
    }
    if (vort.parseZchunkHeader(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidZchunk,
        error.InvalidZchunkInteger,
        error.UnsupportedZchunkCompression,
        error.UnsupportedZchunkFeature,
        error.UnsupportedZchunkHash,
        error.TruncatedFrame,
        error.TrailingData,
        error.ChecksumMismatch,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseDmgAlloc(allocator, data, .{
        .max_xml_bytes = 1 << 20,
        .max_partitions = 256,
        .max_blocks_per_partition = 4096,
        .max_block_decoded_bytes = 1 << 20,
        .max_xz_dictionary_bytes = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        if (archive.partitions.len != 0) {
            const decoded_size = std.math.cast(
                usize,
                archive.partitions[0].decoded_size,
            ) orelse 0;
            const length = @min(decoded_size, 4096);
            if (archive.decodePartitionRangeAllocLimited(
                allocator,
                0,
                0,
                length,
                length,
            )) |decoded| {
                allocator.free(decoded);
            } else |err| {
                if (!isExpectedDmgError(err)) return err;
            }
        }
    } else |err| {
        if (!isExpectedDmgError(err)) return err;
    }
    if (vort.parsePbzxWithOptions(data, .{
        .max_output_len = 1 << 20,
        .max_chunk_decoded_bytes = 1 << 20,
        .max_chunks = 4096,
        .max_xz_dictionary_bytes = 1 << 20,
    })) |archive| {
        const length = @min(archive.decoded_size, 4096);
        if (archive.decodeRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedPbzxError(err)) return err;
        }
    } else |err| {
        if (!isExpectedPbzxError(err)) return err;
    }
    if (vort.parseXarAlloc(allocator, data, .{
        .max_toc_packed_bytes = 1 << 20,
        .max_toc_bytes = 1 << 20,
        .max_entries = 256,
        .max_depth = 64,
        .max_entry_decoded_bytes = 1 << 20,
        .max_lzma_dictionary_bytes = 1 << 20,
        .max_xz_dictionary_bytes = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        for (archive.entries, 0..) |entry, index| {
            if (entry.data == null) continue;
            if (archive.extractAllocLimited(allocator, index, 1 << 20)) |decoded| {
                allocator.free(decoded);
            } else |err| {
                if (!isExpectedXarError(err)) return err;
            }
            break;
        }
    } else |err| {
        if (!isExpectedXarError(err)) return err;
    }
    if (vort.parseSquashfs(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidSquashfs,
        error.UnsupportedSquashfsVersion,
        error.UnsupportedSquashfsCompression,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseErofs(data)) |_| {} else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidErofs,
        error.UnsupportedErofsFeature,
        error.UnsupportedErofsLayout,
        error.TruncatedFrame,
        error.ChecksumMismatch,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseWim(data)) |archive| {
        if (archive.readXmlAllocLimited(allocator, 1 << 20)) |xml| {
            allocator.free(xml);
        } else |err| switch (err) {
            error.InvalidWim,
            error.InvalidLzms,
            error.InvalidXpress,
            error.InvalidLzxStream,
            error.InvalidHuffmanCode,
            error.CorruptFrame,
            error.InvalidMatch,
            error.UnsupportedWimCompression,
            error.UnsupportedWimFeature,
            error.UnsupportedCabinetFeature,
            error.TruncatedFrame,
            error.TrailingData,
            error.OutputLimitExceeded,
            error.IntegerOverflow,
            error.SizeMismatch,
            => {},
            else => return err,
        }
        if (archive.header.image_count != 0) {
            if (archive.readImageMetadataAlloc(allocator, 1, .{
                .max_metadata_bytes = 1 << 20,
                .max_solid_chunk_bytes = 1 << 20,
                .max_lookup_entries = 4096,
                .max_lookup_bytes = 1 << 20,
                .max_directory_entries = 4096,
                .max_path_depth = 64,
            })) |image_value| {
                var image = image_value;
                defer image.deinit();
                if (image.readDirectoryAlloc(allocator, image.root, 4096)) |directory_value| {
                    var directory = directory_value;
                    directory.deinit();
                } else |err| switch (err) {
                    error.InvalidWimMetadata,
                    error.OutputLimitExceeded,
                    error.IntegerOverflow,
                    => {},
                    else => return err,
                }
            } else |err| switch (err) {
                error.InvalidWim,
                error.InvalidWimMetadata,
                error.InvalidLzms,
                error.InvalidXpress,
                error.InvalidLzxStream,
                error.InvalidHuffmanCode,
                error.CorruptFrame,
                error.InvalidMatch,
                error.UnsupportedWimCompression,
                error.UnsupportedWimFeature,
                error.UnsupportedCabinetFeature,
                error.WimResourceInOtherPart,
                error.TruncatedFrame,
                error.TrailingData,
                error.OutputLimitExceeded,
                error.IntegerOverflow,
                error.SizeMismatch,
                error.ChecksumMismatch,
                => {},
                else => return err,
            }
        }
    } else |err| switch (err) {
        error.InvalidMagic,
        error.InvalidWim,
        error.UnsupportedWimVersion,
        error.UnsupportedWimCompression,
        error.UnsupportedWimFeature,
        error.TruncatedFrame,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    const metadata_copy = try allocator.dupe(u8, data);
    if (vort.parseWimImageMetadataOwned(allocator, metadata_copy)) |image_value| {
        var image = image_value;
        defer image.deinit();
        if (image.readDirectoryAlloc(allocator, image.root, 4096)) |directory_value| {
            var directory = directory_value;
            directory.deinit();
        } else |err| switch (err) {
            error.InvalidWimMetadata,
            error.OutputLimitExceeded,
            error.IntegerOverflow,
            => {},
            else => return err,
        }
    } else |err| switch (err) {
        error.InvalidWimMetadata,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseHadoopLzoIndex(data)) |_| {} else |err| switch (err) {
        error.InvalidHadoopLzoIndex,
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
        "\x82SNAPPY\x00\x00\x00\x00\x01\x00\x00\x00\x01",
        &.{ 0, 0, 0, 1 },
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
        "\x02\x21\x4c\x18\x04\x00\x00\x00\x30abc",
        "bvx-\x03\x00\x00\x00abcbvx$",
        "bvxn\x30\x00\x00\x00\x11\x00\x00\x00\xc8\x03abc\xf0\x18\xe1c\x06\x00\x00\x00\x00\x00\x00\x00bvx$",
        "\x00ZCK1\x81",
        "hsqs\x00\x00\x00\x00",
        "EROFS",
    };
    for (samples) |sample| try fuzzOne(init.gpa, sample);

    const base64 = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const raw_lzms_text = vort.fuzz.lzms_raw_fixture_base64;
    const raw_lzms = try init.gpa.alloc(
        u8,
        2 + base64.calcSizeUpperBound(raw_lzms_text.len),
    );
    defer init.gpa.free(raw_lzms);
    const raw_lzms_size = vort.fuzz.lzms_raw_fixture_decoded_size;
    std.mem.writeInt(u16, raw_lzms[0..2], raw_lzms_size, .little);
    const raw_lzms_len = try base64.decode(raw_lzms[2..], raw_lzms_text);
    try fuzzOne(init.gpa, raw_lzms[0 .. raw_lzms_len + 2]);

    const esd_text = vort.fuzz.wim_lzms_fixture_base64;
    const esd = try init.gpa.alloc(u8, base64.calcSizeUpperBound(esd_text.len));
    defer init.gpa.free(esd);
    const esd_len = try base64.decode(esd, esd_text);
    try fuzzOne(init.gpa, esd[0..esd_len]);

    const micro_text = vort.fuzz.microlzma_fixture_base64;
    const micro = try init.gpa.alloc(
        u8,
        3 + base64.calcSizeUpperBound(micro_text.len),
    );
    defer init.gpa.free(micro);
    std.mem.writeInt(u16, micro[0..2], vort.fuzz.microlzma_fixture_decoded_size, .little);
    micro[2] = 3; // 4 KiB << 3 = 32 KiB dictionary.
    const micro_len = try base64.decode(micro[3..], micro_text);
    try fuzzOne(init.gpa, micro[0 .. micro_len + 3]);

    const wof_text = vort.fuzz.wof_fixture_base64;
    const wof = try init.gpa.alloc(
        u8,
        5 + base64.calcSizeUpperBound(wof_text.len),
    );
    defer init.gpa.free(wof);
    wof[0] = @intFromEnum(vort.WofAlgorithm.xpress4k);
    std.mem.writeInt(u32, wof[1..5], vort.fuzz.wof_fixture_decoded_size, .little);
    const wof_len = try base64.decode(wof[5..], wof_text);
    try fuzzOne(init.gpa, wof[0 .. wof_len + 5]);

    const decmpfs_text = vort.fuzz.decmpfs_fixture_base64;
    const decmpfs = try init.gpa.alloc(
        u8,
        2 + 16 + base64.calcSizeUpperBound(decmpfs_text.len),
    );
    defer init.gpa.free(decmpfs);
    std.mem.writeInt(u16, decmpfs[0..2], 16, .little);
    std.mem.writeInt(u32, decmpfs[2..6], vort.decmpfsMagic, .little);
    std.mem.writeInt(u32, decmpfs[6..10], @intFromEnum(vort.DecmpfsCompressionType.lzvn_resource), .little);
    std.mem.writeInt(u64, decmpfs[10..18], vort.fuzz.decmpfs_fixture_decoded_size, .little);
    const decmpfs_len = try base64.decode(decmpfs[18..], decmpfs_text);
    try fuzzOne(init.gpa, decmpfs[0 .. 18 + decmpfs_len]);

    const dmg_text = vort.fuzz.dmg_fixture_base64;
    const dmg = try init.gpa.alloc(u8, base64.calcSizeUpperBound(dmg_text.len));
    defer init.gpa.free(dmg);
    const dmg_len = try base64.decode(dmg, dmg_text);
    try fuzzOne(init.gpa, dmg[0..dmg_len]);

    const pbzx = try vort.encodePbzxAlloc(
        init.gpa,
        "PBZX fuzz target valid stream" ** 64,
        .{ .chunk_size = 257 },
    );
    defer init.gpa.free(pbzx);
    try fuzzOne(init.gpa, pbzx);

    const xar_text = vort.fuzz.xar_fixture_base64;
    const xar = try init.gpa.alloc(u8, base64.calcSizeUpperBound(xar_text.len));
    defer init.gpa.free(xar);
    const xar_len = try base64.decode(xar, xar_text);
    try fuzzOne(init.gpa, xar[0..xar_len]);

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
    try stdout.print("fuzz target smoke: samples={d} stdin_bytes={d}\n", .{
        samples.len + 8,
        data.len,
    });
    try stdout.flush();
}

fn isExpectedDmgError(err: anyerror) bool {
    return switch (err) {
        error.InvalidDmg,
        error.InvalidDmgPlist,
        error.UnsupportedDmgFeature,
        error.UnsupportedDmgMetadata,
        error.UnsupportedDmgChunk,
        error.UnsupportedDmgChecksum,
        error.EncryptedDmg,
        error.InvalidAppleAdcStream,
        error.InvalidBzip2Header,
        error.InvalidBzip2Stream,
        error.UnsupportedBzip2Feature,
        error.InvalidLzfseStream,
        error.InvalidLzvnStream,
        error.InvalidXzHeader,
        error.InvalidXzStream,
        error.UnsupportedXzFeature,
        error.InvalidLzmaHeader,
        error.InvalidLzmaStream,
        error.UnsupportedLzmaFeature,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.TrailingData,
        error.ChecksumMismatch,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.RangeOutOfBounds,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.BadZlibHeader,
        error.NeedDictionary,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.InvalidHuffmanCode,
        error.InvalidDynamicBlockHeader,
        error.InvalidMatch,
        error.UnsupportedDeflateFeature,
        => true,
        else => false,
    };
}

fn isExpectedPbzxError(err: anyerror) bool {
    return switch (err) {
        error.InvalidPbzx,
        error.UnsupportedPbzxCompression,
        error.InvalidXzHeader,
        error.InvalidXzStream,
        error.UnsupportedXzFeature,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.TrailingData,
        error.ChecksumMismatch,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.RangeOutOfBounds,
        error.SizeMismatch,
        error.IntegerOverflow,
        => true,
        else => false,
    };
}

fn isExpectedXarError(err: anyerror) bool {
    return switch (err) {
        error.InvalidXar,
        error.InvalidXarToc,
        error.UnsupportedXarCompression,
        error.UnsupportedXarChecksum,
        error.UnsupportedXarEntry,
        error.EncryptedXarEntry,
        error.InvalidBzip2Header,
        error.InvalidBzip2Stream,
        error.UnsupportedBzip2Feature,
        error.InvalidLzmaHeader,
        error.InvalidLzmaStream,
        error.UnsupportedLzmaFeature,
        error.InvalidXzHeader,
        error.InvalidXzStream,
        error.UnsupportedXzFeature,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.TrailingData,
        error.ChecksumMismatch,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.RangeOutOfBounds,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.BadZlibHeader,
        error.NeedDictionary,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.InvalidHuffmanCode,
        error.InvalidDynamicBlockHeader,
        error.InvalidMatch,
        error.UnsupportedDeflateFeature,
        => true,
        else => false,
    };
}
