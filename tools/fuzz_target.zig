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
        error.TrailingData,
        error.IntegerOverflow,
        => {},
        else => return err,
    }
    if (vort.parseHadoopSnappy(data)) |_| {} else |err| switch (err) {
        error.InvalidHadoopSnappyStream,
        error.InvalidMatch,
        error.UnsupportedSnappyFeature,
        error.TruncatedFrame,
        error.TrailingData,
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
    if (data.len >= 4) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        const source_len = @min(
            @as(usize, std.mem.readInt(u16, data[2..4], .little)),
            data.len - 4,
        );
        const source = data[4..][0..source_len];
        const patch = data[4 + source_len ..];
        if (vort.applyAndroidPuffinAlloc(
            allocator,
            source,
            patch,
            expected_size,
            .{
                .max_output_len = 1 << 20,
                .max_header_len = 1 << 20,
                .max_extents = 4096,
                .max_puff_stream_len = 1 << 20,
                .max_bsdiff_control_bytes = 1 << 20,
            },
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedAndroidOtaError(err)) return err;
        }
    }
    if (data.len >= 4) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        const source_len = @min(
            @as(usize, std.mem.readInt(u16, data[2..4], .little)),
            data.len - 4,
        );
        const source = data[4..][0..source_len];
        const patch = data[4 + source_len ..];
        if (vort.applyAndroidZucchiniAlloc(
            allocator,
            source,
            patch,
            expected_size,
            .{
                .max_output_len = 1 << 20,
                .max_elements = 4096,
                .max_equivalences = 1 << 16,
                .max_target_pools = 4096,
            },
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedAndroidOtaError(err)) return err;
        }
    }
    if (data.len >= 4) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        const source_len = @min(
            @as(usize, std.mem.readInt(u16, data[2..4], .little)),
            data.len - 4,
        );
        const source = data[4..][0..source_len];
        const patch = data[4 + source_len ..];
        if (vort.applyAndroidLz4diffAlloc(
            allocator,
            source,
            patch,
            expected_size,
            .{
                .max_output_len = 1 << 20,
                .max_header_len = 1 << 20,
                .max_blocks = 4096,
                .max_decompressed_len = 1 << 20,
                .max_bsdiff_control_bytes = 1 << 20,
                .max_puffin_header_len = 1 << 20,
                .max_puffin_extents = 4096,
                .max_puff_stream_len = 1 << 20,
            },
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedAndroidOtaError(err)) return err;
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
    if (data.len >= 5) {
        const algorithm = std.enums.fromInt(
            vort.ZfsCompressionAlgorithm,
            data[0] % 17,
        ) orelse unreachable;
        const expected_size: usize = std.mem.readInt(u32, data[1..5], .little);
        if (expected_size <= 1 << 20) {
            if (vort.decodeZfsBlockAllocExactSize(
                allocator,
                algorithm,
                data[5..],
                expected_size,
            )) |decoded| {
                allocator.free(decoded);
            } else |err| {
                if (!isExpectedZfsCompressionError(err)) return err;
            }
        }
    }
    if (vort.parseQcow2(data, .{
        .max_l1_entries = 4096,
        .max_cluster_size = 1 << 20,
        .max_compressed_bytes = 1 << 20,
    })) |archive| {
        const virtual_size = std.math.cast(
            usize,
            archive.header.virtual_size,
        ) orelse 0;
        const length = @min(virtual_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedQcow2Error(err)) return err;
        }
    } else |err| {
        if (!isExpectedQcow2Error(err)) return err;
    }
    if (vort.parseVmdk(data, .{
        .max_descriptor_bytes = 1 << 16,
        .max_grain_bytes = 1 << 20,
        .max_gd_entries = 4096,
        .max_compressed_bytes = 1 << 20,
    })) |archive| {
        const virtual_size = std.math.cast(
            usize,
            archive.header.virtual_size,
        ) orelse 0;
        const length = @min(virtual_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedVmdkError(err)) return err;
        }
    } else |err| {
        if (!isExpectedVmdkError(err)) return err;
    }
    if (vort.parseEwfAlloc(allocator, data, .{
        .max_sections_per_segment = 256,
        .max_chunks = 4096,
        .max_chunk_bytes = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        const media_size = std.math.cast(
            usize,
            archive.geometry.media_size,
        ) orelse 0;
        const length = @min(media_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedEwfError(err)) return err;
        }
    } else |err| {
        if (!isExpectedEwfError(err)) return err;
    }
    if (vort.parseChdAlloc(allocator, data, .{
        .max_hunks = 4096,
        .max_expanded_map_bytes = 4096 * 12,
        .max_metadata_entries = 256,
        .max_compressed_hunk_bytes = 1 << 20,
        .max_self_reference_depth = 4096,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        const logical_size = std.math.cast(
            usize,
            archive.header.logical_bytes,
        ) orelse 0;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedChdError(err)) return err;
        }
    } else |err| {
        if (!isExpectedChdError(err)) return err;
    }
    if (vort.parseVhd(data, .{
        .max_table_entries = 4096,
        .max_block_size = 1 << 20,
    })) |archive| {
        const logical_size = std.math.cast(
            usize,
            archive.footer.current_size,
        ) orelse 0;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedVhdError(err)) return err;
        }
    } else |err| {
        if (!isExpectedVhdError(err)) return err;
    }
    if (vort.parseVhdx(data, .{
        .max_bat_entries = 4096,
        .max_block_size = 16 * 1024 * 1024,
    })) |archive| {
        const logical_size = std.math.cast(
            usize,
            archive.metadata.virtual_disk_size,
        ) orelse 0;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedVhdxError(err)) return err;
        }
    } else |err| {
        if (!isExpectedVhdxError(err)) return err;
    }
    if (vort.parseCso(data, .{
        .max_blocks = 4096,
        .max_block_size = 256 * 1024,
        .max_compressed_block_bytes = 512 * 1024,
    })) |archive| {
        const logical_size = std.math.cast(
            usize,
            archive.header.uncompressed_size,
        ) orelse 0;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedCsoError(err)) return err;
        }
    } else |err| {
        if (!isExpectedCsoError(err)) return err;
    }
    if (vort.parseDax(data, .{
        .max_frames = 4096,
        .max_nc_areas = 4096,
        .max_compressed_frame_bytes = std.math.maxInt(u16),
    })) |archive| {
        const logical_size: usize = archive.header.uncompressed_size;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedDaxError(err)) return err;
        }
    } else |err| {
        if (!isExpectedDaxError(err)) return err;
    }
    if (vort.parseGcz(data, .{
        .max_blocks = 4096,
        .max_block_size = 1 << 20,
        .max_compressed_block_bytes = (1 << 20) + 64,
    })) |archive| {
        const logical_size = std.math.cast(
            usize,
            archive.header.logical_size,
        ) orelse 0;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedGczError(err)) return err;
        }
    } else |err| {
        if (!isExpectedGczError(err)) return err;
    }
    if (vort.parseWiaAlloc(allocator, data, .{
        .max_header2_bytes = 4096,
        .max_partition_entries = 4096,
        .max_partition_entry_size = 4096,
        .max_raw_entries = 4096,
        .max_group_entries = 4096,
        .max_chunk_size = 2 << 20,
        .max_metadata_bytes = 1 << 20,
        .max_group_stored_bytes = 2 << 20,
        .max_dictionary_size = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        const logical_size = std.math.cast(
            usize,
            archive.header1.logical_size,
        ) orelse 0;
        const length = @min(logical_size, 4096);
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            length,
            length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWiaError(err)) return err;
        }
        if (archive.partitions.len != 0) {
            const partition_offset = std.math.cast(
                usize,
                archive.partitions[0].data[0].logicalOffset(),
            ) orelse 0;
            const partition_length = if (partition_offset < logical_size)
                @min(logical_size - partition_offset, 4096)
            else
                0;
            if (archive.readRangeAllocLimited(
                allocator,
                partition_offset,
                partition_length,
                partition_length,
            )) |decoded| {
                allocator.free(decoded);
            } else |err| {
                if (!isExpectedWiaError(err)) return err;
            }
        }
    } else |err| {
        if (!isExpectedWiaError(err)) return err;
    }
    if (vort.parseWbfsAlloc(allocator, data, .{
        .max_hd_sector_size = 4096,
        .max_wbfs_sector_size = 2 << 20,
        .max_parts = 4,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            4096,
            4096,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWbfsError(err)) return err;
        }
        if (archive.readRangeAllocLimited(
            allocator,
            vort.wbfsLogicalSize - 4096,
            4096,
            4096,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWbfsError(err)) return err;
        }
    } else |err| {
        if (!isExpectedWbfsError(err)) return err;
    }
    if (vort.parseWdfAlloc(allocator, data, .{
        .max_chunks = 4096,
        .max_parts = 4,
        .max_alignment = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        const logical_size = archive.header.logical_size;
        const first_length: usize = @intCast(@min(logical_size, 4096));
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            first_length,
            first_length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWdfError(err)) return err;
        }
        const tail_length: usize = @intCast(@min(logical_size, 4096));
        if (archive.readRangeAllocLimited(
            allocator,
            logical_size - tail_length,
            tail_length,
            tail_length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWdfError(err)) return err;
        }
    } else |err| {
        if (!isExpectedWdfError(err)) return err;
    }
    if (vort.parseWuxAlloc(allocator, data, .{
        .max_sectors = 4096,
        .max_sector_size = 2 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        const first_length: usize = @intCast(@min(
            archive.header.logical_size,
            4096,
        ));
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            first_length,
            first_length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWuxError(err)) return err;
        }
        const tail_length: usize = @intCast(@min(
            archive.header.logical_size,
            4096,
        ));
        if (archive.readRangeAllocLimited(
            allocator,
            archive.header.logical_size - tail_length,
            tail_length,
            tail_length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedWuxError(err)) return err;
        }
    } else |err| {
        if (!isExpectedWuxError(err)) return err;
    }
    if (vort.parseAndroidSparseAlloc(allocator, data, .{
        .max_chunks = 4096,
        .max_block_size = 2 << 20,
        .max_checksum_bytes = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        const first_length: usize = @intCast(@min(
            archive.header.logical_size,
            4096,
        ));
        if (archive.readRangeAllocLimited(
            allocator,
            0,
            first_length,
            first_length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedAndroidSparseError(err)) return err;
        }
        const tail_length: usize = @intCast(@min(
            archive.header.logical_size,
            4096,
        ));
        if (archive.readRangeAllocLimited(
            allocator,
            archive.header.logical_size - tail_length,
            tail_length,
            tail_length,
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedAndroidSparseError(err)) return err;
        }
    } else |err| {
        if (!isExpectedAndroidSparseError(err)) return err;
    }
    if (vort.parseAndroidOtaAlloc(allocator, data, .{
        .max_manifest_size = 1 << 20,
        .max_metadata_signature_size = 1 << 20,
        .max_partitions = 256,
        .max_operations = 4096,
        .max_extents = 8192,
        .max_partition_name_bytes = 256,
        .max_block_size = 2 << 20,
        .max_partition_size = 1 << 30,
        .max_blob_size = 1 << 20,
        .max_data_hash_bytes = 1 << 20,
    })) |archive_value| {
        var archive = archive_value;
        defer archive.deinit();
        if (archive.partitions.len != 0) {
            const length: usize = @intCast(@min(
                archive.partitions[0].new_info.size,
                4096,
            ));
            const output = try allocator.alloc(u8, length);
            defer allocator.free(output);
            archive.readPartitionRangeInto(
                allocator,
                0,
                null,
                0,
                output,
                .{
                    .max_output_len = length,
                    .max_operation_output_len = 1 << 20,
                    .verify_partition_hash = false,
                },
            ) catch |err| {
                if (!isExpectedAndroidOtaError(err)) return err;
            };
        }
    } else |err| {
        if (!isExpectedAndroidOtaError(err)) return err;
    }
    if (data.len >= 2) {
        const expected_size: usize = std.mem.readInt(u16, data[0..2], .little);
        if (vort.applyAndroidBsdiffAlloc(
            allocator,
            "",
            data[2..],
            expected_size,
            .{
                .max_output_len = 1 << 20,
                .max_control_bytes = 1 << 20,
            },
        )) |decoded| {
            allocator.free(decoded);
        } else |err| {
            if (!isExpectedAndroidOtaError(err)) return err;
        }
    }
    const fuzz_wii_keys = [_]vort.WiaWiiCommonKey{
        .{ .index = 0, .key = @splat(0) },
        .{ .index = 1, .key = @splat(0) },
    };
    if (vort.discoverWiiDiscPartitionsAlloc(
        allocator,
        data,
        &fuzz_wii_keys,
        .{ .max_partitions = 64 },
    )) |layout_value| {
        var layout = layout_value;
        layout.deinit();
    } else |err| {
        if (!isExpectedWiiDiscError(err)) return err;
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

    const zfs_text = vort.fuzz.zfs_lzjb_fixture_base64;
    const zfs_lzjb = try init.gpa.alloc(
        u8,
        5 + base64.calcSizeUpperBound(zfs_text.len),
    );
    defer init.gpa.free(zfs_lzjb);
    zfs_lzjb[0] = @intFromEnum(vort.ZfsCompressionAlgorithm.lzjb);
    std.mem.writeInt(
        u32,
        zfs_lzjb[1..5],
        vort.fuzz.zfs_lzjb_fixture_decoded_size,
        .little,
    );
    const zfs_lzjb_len = try base64.decode(zfs_lzjb[5..], zfs_text);
    try fuzzOne(init.gpa, zfs_lzjb[0 .. 5 + zfs_lzjb_len]);

    const qcow2 = try vort.encodeQcow2Alloc(
        init.gpa,
        "QCOW2 fuzz target valid cluster\n" ** 128,
        .{ .cluster_bits = 12, .compression = .zstd },
    );
    defer init.gpa.free(qcow2);
    try fuzzOne(init.gpa, qcow2);

    const vmdk = try vort.encodeVmdkAlloc(
        init.gpa,
        "VMDK fuzz target valid grain\n" ** 128,
        .{ .grain_sectors = 8, .compression = .zlib },
    );
    defer init.gpa.free(vmdk);
    try fuzzOne(init.gpa, vmdk);

    const ewf = try vort.encodeEwfAlloc(
        init.gpa,
        "EWF fuzz target valid chunk\n" ** 128,
        .{ .sectors_per_chunk = 16, .compression = .auto },
    );
    defer init.gpa.free(ewf);
    try fuzzOne(init.gpa, ewf);

    const chd = try vort.encodeChdAlloc(
        init.gpa,
        "CHD fuzz target valid hunk\n" ** 128,
        .{ .hunk_bytes = 4096, .unit_bytes = 512, .compression = .auto },
    );
    defer init.gpa.free(chd);
    try fuzzOne(init.gpa, chd);
    inline for (.{
        vort.ChdCompression.lzma,
        vort.ChdCompression.huffman,
        vort.ChdCompression.zstd,
    }) |compression| {
        const codec_chd = try vort.encodeChdAlloc(
            init.gpa,
            "CHD codec fuzz target valid hunk\n" ** 128,
            .{ .hunk_bytes = 4096, .unit_bytes = 512, .compression = compression },
        );
        defer init.gpa.free(codec_chd);
        try fuzzOne(init.gpa, codec_chd);
    }

    inline for (.{ vort.VhdDiskType.fixed, vort.VhdDiskType.dynamic }) |disk_type| {
        const vhd = try vort.encodeVhdAlloc(
            init.gpa,
            "VHD fuzz target valid block\n" ** 128,
            .{ .disk_type = disk_type, .block_size = 4096 },
        );
        defer init.gpa.free(vhd);
        try fuzzOne(init.gpa, vhd);
    }

    const vhdx = try vort.encodeVhdxAlloc(
        init.gpa,
        "VHDX fuzz target valid block\n" ** 128,
        .{ .image_type = .dynamic, .block_size = 1024 * 1024 },
    );
    defer init.gpa.free(vhdx);
    try fuzzOne(init.gpa, vhdx);
    const vhdx_parent = try vort.parseVhdx(vhdx, .{});
    const differencing_vhdx = try vort.encodeVhdxAlloc(
        init.gpa,
        "WHDX fuzz target valid block\n" ** 128,
        .{
            .image_type = .differencing,
            .block_size = 1024 * 1024,
            .parent = &vhdx_parent,
        },
    );
    defer init.gpa.free(differencing_vhdx);
    try fuzzOne(init.gpa, differencing_vhdx);

    inline for (.{
        vort.CsoFormat.cso1,
        vort.CsoFormat.cso2,
        vort.CsoFormat.zso,
    }) |image_format| {
        const cso = try vort.encodeCsoAlloc(
            init.gpa,
            "CSO fuzz target valid block\n" ** 128,
            .{ .format = image_format, .compression = .auto },
        );
        defer init.gpa.free(cso);
        try fuzzOne(init.gpa, cso);
    }
    inline for (.{ vort.DaxCompression.zlib, vort.DaxCompression.raw }) |compression| {
        const dax = try vort.encodeDaxAlloc(
            init.gpa,
            "DAX fuzz target valid frame\n" ** 320,
            .{ .compression = compression },
        );
        defer init.gpa.free(dax);
        try fuzzOne(init.gpa, dax);
    }
    inline for (.{ vort.GczCompression.auto, vort.GczCompression.raw }) |compression| {
        const gcz = try vort.encodeGczAlloc(
            init.gpa,
            "GCZ fuzz target valid block\n" ** 320,
            .{ .compression = compression, .block_size = 4096 },
        );
        defer init.gpa.free(gcz);
        try fuzzOne(init.gpa, gcz);
    }
    const wbfs_input = try init.gpa.alloc(u8, 2 * 256 * 1024);
    defer init.gpa.free(wbfs_input);
    @memset(wbfs_input, 0);
    for (wbfs_input[0 .. 256 * 1024], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    const wbfs = try vort.encodeWbfsAlloc(init.gpa, wbfs_input, .{
        .wbfs_sector_shift = 18,
    });
    defer init.gpa.free(wbfs);
    try fuzzOne(init.gpa, wbfs);
    const wdf_input = try init.gpa.alloc(u8, 3 * 64 * 1024 + 137);
    defer init.gpa.free(wdf_input);
    @memset(wdf_input, 0);
    for (wdf_input[0 .. 64 * 1024], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    for (wdf_input[2 * 64 * 1024 ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 3);
    inline for (.{ vort.WdfVersion.v1, vort.WdfVersion.v2 }) |version| {
        const wdf = try vort.encodeWdfAlloc(init.gpa, wdf_input, .{
            .version = version,
        });
        defer init.gpa.free(wdf);
        try fuzzOne(init.gpa, wdf);
    }
    const wux_input = try init.gpa.alloc(u8, 3 * 4096 + 137);
    defer init.gpa.free(wux_input);
    @memset(wux_input, 0);
    for (wux_input[0..4096], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    @memcpy(wux_input[2 * 4096 .. 3 * 4096], wux_input[0..4096]);
    for (wux_input[3 * 4096 ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 7);
    const wux = try vort.encodeWuxAlloc(init.gpa, wux_input, .{
        .sector_size = 4096,
    });
    defer init.gpa.free(wux);
    try fuzzOne(init.gpa, wux);
    const android_sparse_input = try init.gpa.alloc(u8, 4 * 4096);
    defer init.gpa.free(android_sparse_input);
    @memset(android_sparse_input, 0);
    for (android_sparse_input[0..4096], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    var fill_pattern: [4]u8 = undefined;
    std.mem.writeInt(u32, &fill_pattern, 0x1122_3344, .little);
    for (android_sparse_input[2 * 4096 .. 3 * 4096], 0..) |*byte, index|
        byte.* = fill_pattern[index % fill_pattern.len];
    for (android_sparse_input[3 * 4096 ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 7);
    const android_sparse = try vort.encodeAndroidSparseAlloc(
        init.gpa,
        android_sparse_input,
        .{ .emit_crc32_chunk = true, .write_image_checksum = true },
    );
    defer init.gpa.free(android_sparse);
    try fuzzOne(init.gpa, android_sparse);
    const android_ota_input = try init.gpa.alloc(u8, 4 * 4096);
    defer init.gpa.free(android_ota_input);
    @memset(android_ota_input, 0);
    for (android_ota_input[0..4096], 0..) |*byte, index|
        byte.* = @truncate(index * 17 + index / 31);
    for (android_ota_input[2 * 4096 ..], 0..) |*byte, index|
        byte.* = @truncate(index * 29 + 7);
    const android_ota = try vort.encodeAndroidOtaAlloc(
        init.gpa,
        &.{.{ .name = "system", .data = android_ota_input }},
        .{ .operation_size = 4096 },
    );
    defer init.gpa.free(android_ota);
    try fuzzOne(init.gpa, android_ota);
    const bsdiff_sample = try makeBsdiffFuzzSampleAlloc(init.gpa);
    defer init.gpa.free(bsdiff_sample);
    try fuzzOne(init.gpa, bsdiff_sample);
    const puffin_sample = try makePuffinFuzzSampleAlloc(init.gpa);
    defer init.gpa.free(puffin_sample);
    try fuzzOne(init.gpa, puffin_sample);
    const lz4diff_sample = try makeLz4diffFuzzSampleAlloc(init.gpa);
    defer init.gpa.free(lz4diff_sample);
    try fuzzOne(init.gpa, lz4diff_sample);
    const zucchini_sample = try makeZucchiniFuzzSampleAlloc(init.gpa);
    defer init.gpa.free(zucchini_sample);
    try fuzzOne(init.gpa, zucchini_sample);
    inline for (.{
        .{ vort.WiaContainer.wia, vort.WiaCompression.bzip2, @as(u32, 2 * 1024 * 1024) },
        .{ vort.WiaContainer.rvz, vort.WiaCompression.zstd, @as(u32, 128 * 1024) },
    }) |case| {
        const wia = try vort.encodeWiaAlloc(
            init.gpa,
            "WIA RVZ fuzz target valid group\n" ** 128,
            .{
                .container = case[0],
                .compression = case[1],
                .chunk_size = case[2],
            },
        );
        defer init.gpa.free(wia);
        try fuzzOne(init.gpa, wia);
    }
    inline for (.{
        vort.fuzz.wia_partition_fixture_base64,
        vort.fuzz.rvz_partition_fixture_base64,
    }, 0..) |text, fixture_index| {
        const compressed = try init.gpa.alloc(
            u8,
            base64.calcSizeUpperBound(text.len),
        );
        defer init.gpa.free(compressed);
        const compressed_len = try base64.decode(compressed, text);
        const wia = try vort.bzip2.decodeAllocLimited(
            init.gpa,
            compressed[0..compressed_len],
            3 * 1024 * 1024,
        );
        defer init.gpa.free(wia);
        try fuzzOne(init.gpa, wia);
        if (fixture_index == 1) {
            var archive = try vort.parseWiaAlloc(init.gpa, wia, .{});
            defer archive.deinit();
            const source = try archive.decodeAllocLimited(
                init.gpa,
                3 * 1024 * 1024,
            );
            defer init.gpa.free(source);
            const partition = archive.partitions[0];
            const generated = try vort.encodeWiaWithPartitionsAlloc(
                init.gpa,
                source,
                &.{.{
                    .key = partition.key,
                    .data = .{
                        .{
                            .offset = partition.data[0].logicalOffset(),
                            .size = partition.data[0].logicalSize(),
                        },
                        .{ .offset = 0, .size = 0 },
                    },
                }},
                .{
                    .container = .rvz,
                    .compression = .zstd,
                    .chunk_size = 128 * 1024,
                },
            );
            defer init.gpa.free(generated);
            try fuzzOne(init.gpa, generated);

            const disc = try makeDiscoverableWiiDiscAlloc(init.gpa, source);
            defer init.gpa.free(disc);
            try fuzzOne(init.gpa, disc);
            const auto_generated = try vort.encodeWiaDiscAlloc(
                init.gpa,
                disc,
                &.{.{
                    .index = 1,
                    .key = .{
                        0x10, 0x21, 0x32, 0x43,
                        0x54, 0x65, 0x76, 0x87,
                        0x98, 0xa9, 0xba, 0xcb,
                        0xdc, 0xed, 0xfe, 0x0f,
                    },
                }},
                .{
                    .container = .rvz,
                    .compression = .zstd,
                    .chunk_size = 128 * 1024,
                },
            );
            defer init.gpa.free(auto_generated);
            try fuzzOne(init.gpa, auto_generated);
        }
    }

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
        samples.len + 38,
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

fn isExpectedZfsCompressionError(err: anyerror) bool {
    return switch (err) {
        error.InvalidZfsBlock,
        error.UnsupportedZfsCompression,
        error.IncompressibleZfsBlock,
        error.InvalidLzjbStream,
        error.InvalidZleStream,
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
        error.UnsupportedZstdFeature,
        error.CorruptFrame,
        => true,
        else => false,
    };
}

fn isExpectedQcow2Error(err: anyerror) bool {
    return switch (err) {
        error.InvalidQcow2,
        error.UnsupportedQcow2Feature,
        error.UnsupportedQcow2Compression,
        error.MissingQcow2BackingFile,
        error.MissingQcow2DataFile,
        error.EncryptedQcow2,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.BadZlibHeader,
        error.BadGzipHeader,
        error.NeedDictionary,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.UnsupportedZstdFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        error.DuplicateDictionaryId,
        error.InvalidDictionaryMetadata,
        => true,
        else => false,
    };
}

fn isExpectedVmdkError(err: anyerror) bool {
    return switch (err) {
        error.InvalidVmdk,
        error.UnsupportedVmdkFeature,
        error.UnsupportedVmdkCompression,
        error.MissingVmdkBackingFile,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.BadZlibHeader,
        error.NeedDictionary,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedEwfError(err: anyerror) bool {
    return switch (err) {
        error.InvalidEwf,
        error.UnsupportedEwfFeature,
        error.UnsupportedEwfCompression,
        error.IncompleteEwf,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.BadZlibHeader,
        error.NeedDictionary,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedChdError(err: anyerror) bool {
    return switch (err) {
        error.InvalidChd,
        error.InvalidChdMap,
        error.InvalidChdMetadata,
        error.UnsupportedChdCodec,
        error.MissingChdParent,
        error.InvalidLzmaHeader,
        error.InvalidLzmaStream,
        error.UnsupportedLzmaFeature,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.BadZlibHeader,
        error.BadGzipHeader,
        error.NeedDictionary,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.UnsupportedZstdFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        error.DuplicateDictionaryId,
        error.InvalidDictionaryMetadata,
        => true,
        else => false,
    };
}

fn isExpectedVhdError(err: anyerror) bool {
    return switch (err) {
        error.InvalidVhd,
        error.UnsupportedVhdFeature,
        error.MissingVhdParent,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.ChecksumMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        => true,
        else => false,
    };
}

fn isExpectedVhdxError(err: anyerror) bool {
    return switch (err) {
        error.InvalidVhdx,
        error.UnsupportedVhdxFeature,
        error.MissingVhdxParent,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.ChecksumMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        => true,
        else => false,
    };
}

fn isExpectedCsoError(err: anyerror) bool {
    return switch (err) {
        error.InvalidCso,
        error.UnsupportedCsoCodec,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedDaxError(err: anyerror) bool {
    return switch (err) {
        error.InvalidDax,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.BadZlibHeader,
        error.NeedDictionary,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.ChecksumMismatch,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedGczError(err: anyerror) bool {
    return switch (err) {
        error.InvalidGcz,
        error.InvalidMagic,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.InvalidDeflateBlockType,
        error.StoredLengthMismatch,
        error.BadZlibHeader,
        error.NeedDictionary,
        error.InvalidHuffmanCode,
        error.UnsupportedDeflateFeature,
        error.InvalidMatch,
        error.InvalidDynamicBlockHeader,
        error.ChecksumMismatch,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedWiaError(err: anyerror) bool {
    return switch (err) {
        error.InvalidWia,
        error.UnsupportedWiaFeature,
        error.UnsupportedWiaCodec,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.ChecksumMismatch,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.TrailingData,
        error.InvalidBzip2Header,
        error.InvalidBzip2Stream,
        error.UnsupportedBzip2Feature,
        error.InvalidLzmaHeader,
        error.InvalidLzmaStream,
        error.UnsupportedLzmaFeature,
        error.InvalidLzmaOptions,
        error.InvalidXzHeader,
        error.InvalidXzStream,
        error.UnsupportedXzFeature,
        error.UnsupportedZstdFeature,
        error.InvalidMatch,
        error.InvalidHuffmanCode,
        error.NeedDictionary,
        error.DuplicateDictionaryId,
        error.InvalidDictionaryMetadata,
        => true,
        else => false,
    };
}

fn isExpectedWbfsError(err: anyerror) bool {
    return switch (err) {
        error.InvalidWbfs,
        error.UnsupportedWbfsFeature,
        error.InvalidMagic,
        error.TruncatedFrame,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        => true,
        else => false,
    };
}

fn isExpectedWdfError(err: anyerror) bool {
    return switch (err) {
        error.InvalidWdf,
        error.UnsupportedWdfFeature,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.TrailingData,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        => true,
        else => false,
    };
}

fn isExpectedWuxError(err: anyerror) bool {
    return switch (err) {
        error.InvalidWux,
        error.UnsupportedWuxFeature,
        error.InvalidMagic,
        error.TruncatedFrame,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        => true,
        else => false,
    };
}

fn isExpectedAndroidSparseError(err: anyerror) bool {
    return switch (err) {
        error.InvalidAndroidSparse,
        error.UnsupportedAndroidSparseFeature,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedAndroidOtaError(err: anyerror) bool {
    return switch (err) {
        error.InvalidAndroidOta,
        error.InvalidProtobuf,
        error.UnsupportedProtobufWireType,
        error.UnsupportedAndroidOtaOperation,
        error.MissingAndroidOtaSource,
        error.DuplicateAndroidOtaPartition,
        error.IncompleteAndroidOtaPartition,
        error.InvalidBsdiffPatch,
        error.UnsupportedBsdiffCompression,
        error.InvalidPuffinPatch,
        error.InvalidPuffinStream,
        error.UnsupportedPuffinPatch,
        error.InvalidLz4diffPatch,
        error.UnsupportedLz4diffPatch,
        error.UnsupportedLz4diffCompression,
        error.InvalidZucchiniPatch,
        error.UnsupportedZucchiniPatch,
        error.InvalidMagic,
        error.UnsupportedVersion,
        error.TruncatedFrame,
        error.ChecksumMismatch,
        error.SizeMismatch,
        error.IntegerOverflow,
        error.RangeOutOfBounds,
        error.OutputLimitExceeded,
        error.OutputTooSmall,
        error.InvalidBzip2Header,
        error.InvalidBzip2Stream,
        error.UnsupportedBzip2Feature,
        error.InvalidXzHeader,
        error.InvalidXzStream,
        error.UnsupportedXzFeature,
        error.InvalidLzmaOptions,
        error.InvalidMatch,
        error.InvalidHuffmanCode,
        error.CorruptFrame,
        error.UnsupportedBrotliFeature,
        error.InputTooSmall,
        error.TrailingData,
        => true,
        else => false,
    };
}

fn isExpectedWiiDiscError(err: anyerror) bool {
    return switch (err) {
        error.InvalidWiiDisc,
        error.UnsupportedWiiDisc,
        error.MissingWiiCommonKey,
        error.OutputLimitExceeded,
        error.IntegerOverflow,
        error.TruncatedFrame,
        => true,
        else => false,
    };
}

fn makeBsdiffFuzzSampleAlloc(allocator: std.mem.Allocator) ![]u8 {
    var control: [24]u8 = @splat(0);
    std.mem.writeInt(u64, control[0..8], 4, .little);
    const control_compressed = try vort.encodeBzip2Alloc(
        allocator,
        &control,
        .{},
    );
    defer allocator.free(control_compressed);
    const diff_compressed = try vort.encodeBzip2Alloc(
        allocator,
        "abXY",
        .{},
    );
    defer allocator.free(diff_compressed);
    const extra_compressed = try vort.encodeBzip2Alloc(allocator, "", .{});
    defer allocator.free(extra_compressed);
    var sample: std.ArrayList(u8) = .empty;
    errdefer sample.deinit(allocator);
    var expected_size: [2]u8 = undefined;
    std.mem.writeInt(u16, &expected_size, 4, .little);
    try sample.appendSlice(allocator, &expected_size);
    try sample.appendSlice(allocator, "BSDIFF40");
    var lengths: [24]u8 = @splat(0);
    std.mem.writeInt(u64, lengths[0..8], control_compressed.len, .little);
    std.mem.writeInt(u64, lengths[8..16], diff_compressed.len, .little);
    std.mem.writeInt(u64, lengths[16..24], 4, .little);
    try sample.appendSlice(allocator, &lengths);
    try sample.appendSlice(allocator, control_compressed);
    try sample.appendSlice(allocator, diff_compressed);
    try sample.appendSlice(allocator, extra_compressed);
    return sample.toOwnedSlice(allocator);
}

fn makePuffinFuzzSampleAlloc(allocator: std.mem.Allocator) ![]u8 {
    const source = [_]u8{
        0x11, 0x22, 0x63, 0x64, 0x62, 0x66, 0x61, 0x05, 0x00,
        0x33, 0x03, 0x00, 0x63, 0x04, 0x00, 0x44, 0x55,
    };
    var sample: std.ArrayList(u8) = .empty;
    errdefer sample.deinit(allocator);
    var sizes: [4]u8 = undefined;
    std.mem.writeInt(u16, sizes[0..2], 22, .little);
    std.mem.writeInt(u16, sizes[2..4], source.len, .little);
    try sample.appendSlice(allocator, &sizes);
    try sample.appendSlice(allocator, &source);
    try sample.appendSlice(allocator, &vort.fuzz.android_ota_puffdiff_fixture);
    return sample.toOwnedSlice(allocator);
}

fn makeLz4diffFuzzSampleAlloc(allocator: std.mem.Allocator) ![]u8 {
    const source = [_]u8{0} ** 32;
    const target = "abcabcabcabcabcabcabcabc01234567";
    var control: [24]u8 = @splat(0);
    std.mem.writeInt(u64, control[0..8], target.len, .little);
    const control_compressed = try vort.encodeBzip2Alloc(
        allocator,
        &control,
        .{},
    );
    defer allocator.free(control_compressed);
    const diff_compressed = try vort.encodeBzip2Alloc(
        allocator,
        target,
        .{},
    );
    defer allocator.free(diff_compressed);
    const extra_compressed = try vort.encodeBzip2Alloc(allocator, "", .{});
    defer allocator.free(extra_compressed);
    var inner_patch: std.ArrayList(u8) = .empty;
    defer inner_patch.deinit(allocator);
    try inner_patch.appendSlice(allocator, "BSDIFF40");
    var lengths: [24]u8 = @splat(0);
    std.mem.writeInt(u64, lengths[0..8], control_compressed.len, .little);
    std.mem.writeInt(u64, lengths[8..16], diff_compressed.len, .little);
    std.mem.writeInt(u64, lengths[16..24], target.len, .little);
    try inner_patch.appendSlice(allocator, &lengths);
    try inner_patch.appendSlice(allocator, control_compressed);
    try inner_patch.appendSlice(allocator, diff_compressed);
    try inner_patch.appendSlice(allocator, extra_compressed);

    const source_info = [_]u8{
        0x12, 0x04,
        0x10, source.len,
        0x18, source.len,
    };
    const destination_info = [_]u8{
        0x0a, 0x04,
        0x08, 0x02,
        0x10, 0x05,
        0x12, 0x04,
        0x10, target.len,
        0x18, 0x10,
    };
    var header: [22]u8 = undefined;
    var offset: usize = 0;
    header[offset] = 0x0a;
    header[offset + 1] = source_info.len;
    offset += 2;
    @memcpy(header[offset..][0..source_info.len], &source_info);
    offset += source_info.len;
    header[offset] = 0x12;
    header[offset + 1] = destination_info.len;
    offset += 2;
    @memcpy(header[offset..][0..destination_info.len], &destination_info);

    var sample: std.ArrayList(u8) = .empty;
    errdefer sample.deinit(allocator);
    var sizes: [4]u8 = undefined;
    std.mem.writeInt(u16, sizes[0..2], 16, .little);
    std.mem.writeInt(u16, sizes[2..4], source.len, .little);
    try sample.appendSlice(allocator, &sizes);
    try sample.appendSlice(allocator, &source);
    try sample.appendSlice(allocator, "LZ4DIFF");
    var number: [4]u8 = undefined;
    std.mem.writeInt(u32, &number, 1, .big);
    try sample.appendSlice(allocator, &number);
    std.mem.writeInt(u32, &number, header.len, .big);
    try sample.appendSlice(allocator, &number);
    try sample.append(allocator, 0);
    try sample.appendSlice(allocator, &header);
    try sample.appendSlice(allocator, inner_patch.items);
    return sample.toOwnedSlice(allocator);
}

fn makeZucchiniFuzzSampleAlloc(allocator: std.mem.Allocator) ![]u8 {
    return allocator.dupe(u8, &.{
        0x04, 0x00, 0x04, 0x00, 0x61, 0x62, 0x63, 0x64,
        0x5a, 0x75, 0x63, 0x63, 0x01, 0x00, 0x00, 0x00,
        0x04, 0x00, 0x00, 0x00, 0x11, 0xcd, 0x82, 0xed,
        0x04, 0x00, 0x00, 0x00, 0x4c, 0x24, 0x63, 0xc3,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x04, 0x00, 0x00, 0x00, 0x4e, 0x6f, 0x4f, 0x70,
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00,
        0x77, 0x78, 0x79, 0x7a, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    });
}

fn makeDiscoverableWiiDiscAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
) ![]u8 {
    const block_size = 0x8000;
    const group_size = 0x20_0000;
    const partition_offset = 0x50000;
    const data_relative = 0x20000;
    const data_offset = partition_offset + data_relative;
    if (source.len != block_size + group_size) return error.InvalidWiiDisc;
    const output = try allocator.alloc(u8, data_offset + group_size);
    @memset(output, 0);
    @memcpy(output[0..0x80], source[0..0x80]);
    std.mem.writeInt(u32, output[0x18..0x1c], 0x5d1c9ea3, .big);
    output[0x60] = 0;
    output[0x61] = 0;
    std.mem.writeInt(u32, output[0x40000..0x40004], 1, .big);
    std.mem.writeInt(u32, output[0x40004..0x40008], 0x40020 / 4, .big);
    std.mem.writeInt(u32, output[0x40020..0x40024], partition_offset / 4, .big);
    std.mem.writeInt(u32, output[partition_offset..][0..4], 0x0001_0001, .big);
    @memcpy(
        output[partition_offset + 0x1bf ..][0..16],
        &[_]u8{
            0x5f, 0x5e, 0x6a, 0xa1, 0x87, 0x46, 0xd1, 0xbb,
            0xce, 0xc4, 0xc7, 0x05, 0xfe, 0x96, 0x58, 0x3e,
        },
    );
    @memcpy(
        output[partition_offset + 0x1dc ..][0..8],
        &[_]u8{ 0x00, 0x01, 0x00, 0x00, 0x57, 0x49, 0x49, 0x31 },
    );
    output[partition_offset + 0x1f1] = 1;
    std.mem.writeInt(
        u32,
        output[partition_offset + 0x2b8 ..][0..4],
        data_relative / 4,
        .big,
    );
    std.mem.writeInt(
        u32,
        output[partition_offset + 0x2bc ..][0..4],
        group_size / 4,
        .big,
    );
    @memcpy(output[data_offset..], source[block_size..]);
    return output;
}
