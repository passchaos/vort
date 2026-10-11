const std = @import("std");
const core = @import("../core.zig");
const bit_reader = @import("lzx/bit_reader.zig");
const lzx_huffman = @import("lzx/huffman.zig");

pub const Error = core.Error || error{ InvalidLzxStream, UnsupportedCabinetFeature };

pub const StreamFormat = enum {
    cabinet,
    wim,
};

const min_window_bits: u5 = 15;
const max_window_bits: u5 = 21;
const frame_size: usize = 32 * 1024;
const min_match: usize = 2;
const primary_length_count: usize = 7;
const secondary_length_count: usize = 249;
const aligned_symbol_count: usize = 8;
const max_main_symbols: usize = 256 + 50 * 8;
const position_slots = [_]u8{ 30, 32, 34, 36, 38, 42, 50 };
const WordBitReader = bit_reader.Reader;
const CanonicalHuffman = lzx_huffman.Canonical;
const readLengths = lzx_huffman.readLengths;

const BlockType = enum(u3) {
    invalid = 0,
    verbatim = 1,
    aligned = 2,
    uncompressed = 3,
    _,
};

pub fn decodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_output_len: usize,
    window_bits: u5,
) ![]u8 {
    return decodeAllocWithFormat(
        allocator,
        input,
        expected_output_len,
        window_bits,
        .cabinet,
    );
}

pub fn decodeAllocWithFormat(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_output_len: usize,
    window_bits: u5,
    stream_format: StreamFormat,
) ![]u8 {
    if (window_bits < min_window_bits or window_bits > max_window_bits)
        return error.UnsupportedCabinetFeature;
    const raw = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(raw);
    if (expected_output_len == 0) return raw;

    var decoder = Decoder.init(input, raw, window_bits, stream_format);
    try decoder.decode();
    if (decoder.written != raw.len) return error.SizeMismatch;

    if (decoder.intel_started_frame) |start_frame| {
        if (stream_format == .cabinet and decoder.intel_filesize != 0)
            applyIntelE8(raw, decoder.intel_filesize, start_frame);
    }
    if (stream_format == .wim and decoder.may_have_e8)
        applyWimIntelE8(raw);
    return raw;
}

const Decoder = struct {
    reader: WordBitReader,
    output: []u8,
    written: usize = 0,
    stream_format: StreamFormat,
    window_bits: u5,
    window_size: usize,
    main_symbol_count: usize,
    r0: usize = 1,
    r1: usize = 1,
    r2: usize = 1,
    block_type: BlockType = .invalid,
    block_length: usize = 0,
    block_remaining: usize = 0,
    main_lengths: [max_main_symbols]u5 = @splat(0),
    length_lengths: [secondary_length_count]u5 = @splat(0),
    aligned_lengths: [aligned_symbol_count]u5 = @splat(0),
    main_tree: CanonicalHuffman(max_main_symbols) = .{},
    length_tree: CanonicalHuffman(secondary_length_count) = .{},
    aligned_tree: CanonicalHuffman(aligned_symbol_count) = .{},
    length_tree_empty: bool = true,
    intel_filesize: i32 = 0,
    intel_started_frame: ?usize = null,
    may_have_e8: bool = false,

    fn init(
        input: []const u8,
        output: []u8,
        window_bits: u5,
        stream_format: StreamFormat,
    ) Decoder {
        return .{
            .reader = .{ .input = input },
            .output = output,
            .stream_format = stream_format,
            .window_bits = window_bits,
            .window_size = @as(usize, 1) << @intCast(window_bits),
            .main_symbol_count = 256 + @as(usize, position_slots[window_bits - min_window_bits]) * 8,
        };
    }

    fn decode(self: *Decoder) !void {
        if (self.stream_format == .cabinet) {
            const intel = try self.reader.readBits(1);
            if (intel != 0) {
                const high = try self.reader.readBits(16);
                const low = try self.reader.readBits(16);
                self.intel_filesize = @bitCast((high << 16) | low);
            }
        }

        if (self.stream_format == .wim) return self.decodeWim();
        var frame_index: usize = 0;
        while (self.written < self.output.len) : (frame_index += 1) {
            const frame_start = self.written;
            const frame_end = @min(self.output.len, frame_start + frame_size);
            while (self.written < frame_end) {
                if (self.block_remaining == 0) try self.readBlockHeader(frame_index);
                const run = @min(self.block_remaining, frame_end - self.written);
                switch (self.block_type) {
                    .verbatim, .aligned => try self.decodeCompressedRun(run),
                    .uncompressed => try self.decodeUncompressedRun(run),
                    else => return error.InvalidLzxStream,
                }
                self.block_remaining -= run;
            }
            self.reader.alignToWord();
        }
    }

    fn decodeWim(self: *Decoder) !void {
        while (self.written < self.output.len) {
            if (self.block_remaining == 0) try self.readBlockHeader(0);
            if (self.block_remaining > self.output.len - self.written)
                return error.InvalidLzxStream;
            const run = self.block_remaining;
            switch (self.block_type) {
                .verbatim, .aligned => try self.decodeCompressedRun(run),
                .uncompressed => try self.decodeUncompressedRun(run),
                else => return error.InvalidLzxStream,
            }
            self.block_remaining = 0;
        }
    }

    fn readBlockHeader(self: *Decoder, frame_index: usize) !void {
        if (self.block_type == .uncompressed and self.block_length & 1 != 0)
            try self.reader.skipAlignedByte();
        self.block_type = @enumFromInt(@as(u3, @intCast(try self.reader.readBits(3))));
        if (self.stream_format == .wim) {
            if (try self.reader.readBits(1) != 0) {
                self.block_length = frame_size;
            } else {
                self.block_length = try self.reader.readBits(16);
                if (self.window_bits >= 16)
                    self.block_length = (self.block_length << 8) |
                        try self.reader.readBits(8);
            }
        } else {
            const high = try self.reader.readBits(16);
            const low = try self.reader.readBits(8);
            self.block_length = (high << 8) | low;
        }
        if (self.block_length == 0) return error.InvalidLzxStream;
        self.block_remaining = self.block_length;

        switch (self.block_type) {
            .aligned => {
                for (&self.aligned_lengths) |*length|
                    length.* = @intCast(try self.reader.readBits(3));
                self.aligned_tree = try CanonicalHuffman(aligned_symbol_count).init(
                    &self.aligned_lengths,
                    false,
                );
                try self.readCompressedTrees(frame_index);
            },
            .verbatim => try self.readCompressedTrees(frame_index),
            .uncompressed => {
                self.may_have_e8 = true;
                if (self.intel_started_frame == null) self.intel_started_frame = frame_index;
                try self.reader.alignForUncompressed();
                self.r0 = try self.reader.readAlignedInt(u32);
                self.r1 = try self.reader.readAlignedInt(u32);
                self.r2 = try self.reader.readAlignedInt(u32);
                if (self.r0 == 0 or self.r1 == 0 or self.r2 == 0)
                    return error.InvalidLzxStream;
            },
            else => return error.InvalidLzxStream,
        }
    }

    fn readCompressedTrees(self: *Decoder, frame_index: usize) !void {
        try readLengths(&self.reader, self.main_lengths[0..256]);
        try readLengths(&self.reader, self.main_lengths[256..self.main_symbol_count]);
        self.main_tree = try CanonicalHuffman(max_main_symbols).init(
            self.main_lengths[0..self.main_symbol_count],
            false,
        );
        if (self.main_lengths[0xe8] != 0 and self.intel_started_frame == null)
            self.intel_started_frame = frame_index;
        if (self.main_lengths[0xe8] != 0) self.may_have_e8 = true;
        try readLengths(&self.reader, &self.length_lengths);
        self.length_tree = try CanonicalHuffman(secondary_length_count).init(
            &self.length_lengths,
            true,
        );
        self.length_tree_empty = self.length_tree.symbol_count == 0;
    }

    fn decodeCompressedRun(self: *Decoder, run_len: usize) !void {
        const run_end = std.math.add(usize, self.written, run_len) catch
            return error.IntegerOverflow;
        while (self.written < run_end) {
            const main_symbol = try self.main_tree.decode(&self.reader);
            if (main_symbol < 256) {
                self.output[self.written] = @intCast(main_symbol);
                self.written += 1;
                continue;
            }

            const match_symbol = main_symbol - 256;
            var match_len = match_symbol & 7;
            if (match_len == primary_length_count) {
                if (self.length_tree_empty) return error.InvalidLzxStream;
                match_len += try self.length_tree.decode(&self.reader);
            }
            match_len += min_match;
            if (match_len > run_end - self.written or match_len > self.block_remaining)
                return error.InvalidLzxStream;

            const slot = match_symbol >> 3;
            const match_offset = try self.decodeOffset(slot);
            if (match_offset == 0 or
                match_offset > self.window_size or
                match_offset > self.written)
                return error.InvalidMatch;
            for (0..match_len) |_| {
                self.output[self.written] = self.output[self.written - match_offset];
                self.written += 1;
            }
        }
    }

    fn decodeOffset(self: *Decoder, slot: usize) !usize {
        switch (slot) {
            0 => return self.r0,
            1 => {
                const value = self.r1;
                self.r1 = self.r0;
                self.r0 = value;
                return value;
            },
            2 => {
                const value = self.r2;
                self.r2 = self.r0;
                self.r0 = value;
                return value;
            },
            else => {},
        }
        if (slot >= (self.main_symbol_count - 256) / 8)
            return error.InvalidLzxStream;
        const extra = positionExtraBits(slot);
        var offset = positionBase(slot) - 2;
        if (extra >= 3 and self.block_type == .aligned) {
            if (extra > 3)
                offset += @as(usize, try self.reader.readBits(@intCast(extra - 3))) << 3;
            offset += try self.aligned_tree.decode(&self.reader);
        } else if (extra != 0) {
            offset += try self.reader.readBits(@intCast(extra));
        }
        self.r2 = self.r1;
        self.r1 = self.r0;
        self.r0 = offset;
        return offset;
    }

    fn decodeUncompressedRun(self: *Decoder, run_len: usize) !void {
        try self.reader.readAlignedBytes(self.output[self.written..][0..run_len]);
        self.written += run_len;
    }
};

fn positionExtraBits(slot: usize) usize {
    if (slot < 4) return 0;
    if (slot < 36) return slot / 2 - 1;
    return 17;
}

fn positionBase(slot: usize) usize {
    var base: usize = 0;
    for (0..slot) |index|
        base += @as(usize, 1) << @intCast(positionExtraBits(index));
    return base;
}

fn applyIntelE8(bytes: []u8, file_size: i32, start_frame: usize) void {
    var frame_index = start_frame;
    while (frame_index < 32_768) : (frame_index += 1) {
        const frame_start = frame_index * frame_size;
        if (frame_start >= bytes.len) break;
        const current_frame_size = @min(frame_size, bytes.len - frame_start);
        if (current_frame_size <= 10) continue;
        const scan_end = frame_start + current_frame_size - 10;
        var index = frame_start;
        var current_position: i32 = @intCast(frame_start);
        while (index < scan_end) {
            if (bytes[index] != 0xe8) {
                index += 1;
                current_position += 1;
                continue;
            }
            index += 1;
            const absolute = std.mem.readInt(i32, bytes[index..][0..4], .little);
            if (absolute >= -current_position and absolute < file_size) {
                const relative = if (absolute >= 0)
                    absolute - current_position
                else
                    absolute + file_size;
                std.mem.writeInt(i32, bytes[index..][0..4], relative, .little);
            }
            index += 4;
            current_position += 5;
        }
    }
}

fn applyWimIntelE8(bytes: []u8) void {
    if (bytes.len <= 10) return;
    const scan_end = bytes.len - 10;
    var index: usize = 0;
    while (index < scan_end) {
        if (bytes[index] != 0xe8) {
            index += 1;
            continue;
        }
        const target_offset = index + 1;
        const absolute = std.mem.readInt(i32, bytes[target_offset..][0..4], .little);
        const position: i32 = @intCast(index);
        if (absolute >= 0) {
            if (absolute < 12_000_000)
                std.mem.writeInt(i32, bytes[target_offset..][0..4], absolute - position, .little);
        } else if (absolute >= -position) {
            std.mem.writeInt(
                i32,
                bytes[target_offset..][0..4],
                absolute + 12_000_000,
                .little,
            );
        }
        index += 5;
    }
}

test "LZX uncompressed block restores recent offsets and applies Intel E8" {
    const allocator = std.testing.allocator;
    var payload = [_]u8{
        'a', 'b', 0xe8, 20,  0,   0,   0,   'c', 'd', 'e', 'f',
        'g', 'h', 'i',  'j', 'k', 'l', 'm', 'n', 'o', 'p',
    };
    var writer = TestWordBitWriter{};
    defer writer.bytes.deinit(allocator);
    try writer.writeBits(allocator, 1, 1);
    try writer.writeBits(allocator, 0, 16);
    try writer.writeBits(allocator, 100, 16);
    try writer.writeBits(allocator, @intFromEnum(BlockType.uncompressed), 3);
    try writer.writeBits(allocator, 0, 16);
    try writer.writeBits(allocator, payload.len, 8);
    try writer.alignForUncompressed(allocator);
    try testAppendU32(allocator, &writer.bytes, 1);
    try testAppendU32(allocator, &writer.bytes, 1);
    try testAppendU32(allocator, &writer.bytes, 1);
    try writer.bytes.appendSlice(allocator, &payload);

    const decoded = try decodeAlloc(allocator, writer.bytes.items, payload.len, 15);
    defer allocator.free(decoded);
    std.mem.writeInt(i32, payload[3..7], 18, .little);
    try std.testing.expectEqualSlices(u8, &payload, decoded);

    try std.testing.expectError(
        error.TruncatedFrame,
        decodeAlloc(allocator, writer.bytes.items[0 .. writer.bytes.items.len - 1], payload.len, 15),
    );
    try std.testing.expectError(
        error.UnsupportedCabinetFeature,
        decodeAlloc(allocator, writer.bytes.items, payload.len, 14),
    );
}

const TestWordBitWriter = struct {
    bytes: std.ArrayList(u8) = .empty,
    word: u16 = 0,
    bit_count: u5 = 0,

    fn writeBits(
        self: *TestWordBitWriter,
        allocator: std.mem.Allocator,
        value: anytype,
        count: u5,
    ) !void {
        var remaining: usize = count;
        while (remaining != 0) {
            remaining -= 1;
            self.word = (self.word << 1) | @as(u1, @truncate(@as(u64, @intCast(value)) >> @intCast(remaining)));
            self.bit_count += 1;
            if (self.bit_count == 16) try self.flushWord(allocator);
        }
    }

    fn alignForUncompressed(self: *TestWordBitWriter, allocator: std.mem.Allocator) !void {
        if (self.bit_count == 0) {
            try testAppendU16(allocator, &self.bytes, 0);
        } else {
            self.word <<= @intCast(16 - @as(usize, self.bit_count));
            try self.flushWord(allocator);
        }
    }

    fn flushWord(self: *TestWordBitWriter, allocator: std.mem.Allocator) !void {
        try testAppendU16(allocator, &self.bytes, self.word);
        self.word = 0;
        self.bit_count = 0;
    }
};

fn testAppendU16(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn testAppendU32(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}
