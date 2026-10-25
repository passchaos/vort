//! Container-level one-shot Deflate64 contracts. ZIP supplies its public
//! namespace; fixed token fields below are inspected without a codec decoder.
const std = @import("std");
const a = std.testing.allocator;

pub fn contracts(comptime Zip: type) type {
    return struct {
        test "ZIP Deflate64 one shot preserves the complete code 285 length in six bytes" {
            const input = try a.alloc(u8, 65_539);
            defer a.free(input);
            @memset(input, 'R');
            // The default, legacy zero stopping value, and full-range nice
            // length all admit the same longest first match of this fixture.
            for ([_]?u32{ null, 0, 65_538 }) |nice| {
                var options: Zip.EncodeOptions = .{ .zip64 = .never, .data_descriptor = true };
                if (nice) |length| options.deflate64_options.nice_length = length;
                const bytes = try Zip.encodeAlloc(a, &.{Zip.EncodeEntry{
                    .name = "long-method9.bin",
                    .data = input,
                    .method = .deflate64,
                    .comment = "full Deflate64 length range",
                }}, options);
                defer a.free(bytes);
                const archive = try Zip.parse(bytes);
                const entry = try archive.entryAt(0);
                try std.testing.expectEqual(Zip.CompressionMethod.deflate64, entry.method);
                try std.testing.expectEqual(input.len, entry.uncompressed_size);
                try std.testing.expectEqual(@as(usize, 6), entry.compressed_size);
                // Independently computed CRC-32/ISO-HDLC for R repeated65539.
                try std.testing.expectEqual(@as(u32, 0x2992_28b2), entry.crc32);
                try std.testing.expectEqualStrings("full Deflate64 length range", entry.comment);
                try std.testing.expect(entry.flags & 8 != 0);
                const compressed = try archive.compressedData(entry);
                var reader: FixedFields = .{ .input = compressed };
                try std.testing.expectEqual(@as(u32, 3), try reader.read(3)); // BFINAL=1, BTYPE=1.
                try std.testing.expectEqual(@as(u32, 0x82), reverse(try reader.read(8), 8)); // Literal R.
                try std.testing.expectEqual(@as(u32, 0xc5), reverse(try reader.read(8), 8)); // Symbol285.
                try std.testing.expectEqual(@as(u32, 65_538), 3 + try reader.read(16));
                try std.testing.expectEqual(@as(u32, 0), try reader.read(5)); // Distance1, code0.
                try std.testing.expectEqual(@as(u32, 0), try reader.read(7)); // EOB256.
                try std.testing.expectEqual(@as(usize, 47), reader.position);
                try std.testing.expectEqual(@as(u32, 0), try reader.read(1)); // Final-byte padding.
                try std.testing.expectEqualSlices(u8, &.{ 0x0b, 0x1a, 0xfd, 0xff, 0x07, 0x00 }, compressed);
                const data_offset = @intFromPtr(compressed.ptr) - @intFromPtr(bytes.ptr);
                const descriptor = data_offset + compressed.len;
                try std.testing.expectEqual(@as(u32, 0x0807_4b50), readU32(bytes, descriptor));
                try std.testing.expectEqual(entry.crc32, readU32(bytes, descriptor + 4));
                try std.testing.expectEqual(@as(u32, 6), readU32(bytes, descriptor + 8));
                try std.testing.expectEqual(@as(u32, 65_539), readU32(bytes, descriptor + 12));
                const plain = try archive.extractAlloc(a, entry);
                defer a.free(plain);
                try std.testing.expectEqualSlices(u8, input, plain);
            }
        }

        test "ZIP Deflate64 one shot compresses a repeated full 64 KiB history and retains metadata" {
            const input = try a.alloc(u8, 131_072);
            defer a.free(input);
            var state: u32 = 0x6536_2026;
            for (input[0..65_536]) |*byte| {
                state = state *% 1_664_525 +% 1_013_904_223;
                byte.* = @truncate(state >> 24);
            }
            @memcpy(input[65_536..], input[0..65_536]);
            const entries = [_]Zip.EncodeEntry{.{
                .name = "distant-method9.bin",
                .data = input,
                .method = .deflate64,
                .comment = "64 KiB history",
                .modified = .{ .date = 0x5a3f, .time = 0xbf7d },
                .creator_system = .unix,
                .external_attributes = Zip.unixExternalAttributes(0o100600),
            }};
            const bytes = try Zip.encodeAlloc(a, &entries, .{
                .zip64 = .always,
                .archive_comment = "one-shot method 9",
                .deflate64_options = .{ .max_chain = 128, .nice_length = 65_538 },
            });
            defer a.free(bytes);
            const archive = try Zip.parse(bytes);
            const entry = try archive.entryAt(0);
            try std.testing.expectEqual(Zip.CompressionMethod.deflate64, entry.method);
            try std.testing.expect(entry.zip64 and archive.zip64);
            try std.testing.expectEqual(input.len, entry.uncompressed_size);
            try std.testing.expect(entry.compressed_size < input.len * 3 / 4);
            // Independent CRC for the fixed LCG seed and duplicated input.
            try std.testing.expectEqual(@as(u32, 0x0c7d_81a6), entry.crc32);
            try std.testing.expectEqualStrings(entries[0].comment, entry.comment);
            try std.testing.expectEqual(entries[0].modified, entry.modified);
            try std.testing.expectEqual(@as(?u16, 0o100600), entry.unixMode());
            try std.testing.expectEqualStrings("one-shot method 9", archive.comment);
            const compressed = try archive.compressedData(entry);
            // The skewed full-window token alphabet benefits from dynamic
            // coding while metadata and the full 65536-distance match remain.
            try std.testing.expectEqual(@as(u8, 2), (compressed[0] >> 1) & 3);
            const plain = try archive.extractAlloc(a, entry);
            defer a.free(plain);
            try std.testing.expectEqualSlices(u8, input, plain);
        }

        test "ZIP Deflate64 one shot invalid nice length preserves caller append prefix" {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(a);
            try output.appendSlice(a, "existing self-extracting prefix");
            const pointer = output.items.ptr;
            const capacity = output.capacity;
            const entries = [_]Zip.EncodeEntry{.{ .name = "invalid.bin", .data = "Deflate64 bounded request", .method = .deflate64 }};
            try std.testing.expectError(error.InvalidBlockPlan, Zip.encodeAppend(a, &output, &entries, .{
                .deflate64_options = .{ .nice_length = 65_539 },
            }));
            try std.testing.expectEqualStrings("existing self-extracting prefix", output.items);
            try std.testing.expect(output.items.ptr == pointer);
            try std.testing.expectEqual(capacity, output.capacity);
        }
    };
}

/// Minimal independent LSB field parser for the locked literal/match wire.
const FixedFields = struct {
    input: []const u8,
    position: usize = 0,

    fn read(self: *FixedFields, width: u5) !u32 {
        if (@as(usize, width) > self.input.len * 8 - self.position) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..width) |bit| {
            const source = self.position + bit;
            value |= @as(u32, (self.input[source / 8] >> @as(u3, @intCast(source % 8))) & 1) << @as(u5, @intCast(bit));
        }
        self.position += width;
        return value;
    }
};
fn reverse(value: u32, width: u5) u32 {
    return @bitReverse(value) >> @as(u5, @intCast(32 - @as(u6, width)));
}
fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}
