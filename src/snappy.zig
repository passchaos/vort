const std = @import("std");
const core = @import("core.zig");
const checksum = @import("checksum.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const max_uncompressed_chunk_len: usize = 64 * 1024;

const min_match_len = 4;
const hash_bits = 15;
const hash_table_len = 1 << hash_bits;
const invalid_pos = std.math.maxInt(u32);
const max_copy2_offset = std.math.maxInt(u16);
const max_copy4_offset = std.math.maxInt(u32);
const stream_identifier_chunk_type: u8 = 0xff;
const compressed_data_chunk_type: u8 = 0x00;
const uncompressed_data_chunk_type: u8 = 0x01;
const min_skippable_chunk_type: u8 = 0x80;
const stream_identifier_payload = "sNaPpY";

const Header = struct {
    decoded_len: usize,
    index: usize,
};

pub const FrameSummary = struct {
    stream_identifier_count: usize = 0,
    compressed_chunk_count: usize = 0,
    uncompressed_chunk_count: usize = 0,
    skippable_chunk_count: usize = 0,
    skippable_payload_bytes: usize = 0,
    decoded_bytes: usize = 0,
    compressed_payload_bytes: usize = 0,
    uncompressed_payload_bytes: usize = 0,
};

pub fn encodedBlockBound(input_len: usize) Error!usize {
    _ = try checkedUsizeToU32(input_len);
    var bound = try varintEncodedLen(input_len);
    if (input_len != 0) {
        bound = try checkedAdd(bound, try literalHeaderLen(input_len));
        bound = try checkedAdd(bound, input_len);
    }
    return bound;
}

pub fn encodedFrameBound(input_len: usize) Error!usize {
    _ = try checkedUsizeToU32(input_len);
    var bound: usize = 4 + stream_identifier_payload.len; // chunk header + stream identifier.
    if (input_len == 0) return bound;
    const chunk_count = (input_len + max_uncompressed_chunk_len - 1) / max_uncompressed_chunk_len;
    bound = try checkedAdd(bound, input_len);
    // `encodeFrameInto` still tries to compress each chunk before deciding
    // whether to store it. The caller-owned output bound must therefore cover
    // the raw-block header/tag overhead for a worst-case compressed attempt,
    // not just the eventual uncompressed fallback chunk.
    bound = try checkedAdd(bound, try checkedMul(chunk_count, 8)); // chunk header + masked CRC-32C.
    bound = try checkedAdd(bound, try checkedMul(chunk_count, 1 + try literalHeaderLen(max_uncompressed_chunk_len)));
    return bound;
}

pub fn encodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeBlockAppend(allocator, &out, input);
    return out.toOwnedSlice(allocator);
}

pub fn encodeBlockAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8) Error!void {
    if (input.len < min_match_len) return try encodeBlockAppendWithTable(allocator, out, input, &.{});
    const table = try allocator.alloc(u32, hash_table_len);
    defer allocator.free(table);
    try encodeBlockAppendWithTable(allocator, out, input, table);
}

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    table: []u32 = &.{},
    block_scratch: std.ArrayList(u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) Encoder {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Encoder) void {
        if (self.table.len != 0) self.allocator.free(self.table);
        self.block_scratch.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn encodeBlockAlloc(self: *Encoder, input: []const u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        try self.encodeBlockAppend(&out, input);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn encodeBlockAppend(self: *Encoder, out: *std.ArrayList(u8), input: []const u8) Error!void {
        const table = if (input.len >= min_match_len) try self.ensureTable() else self.table;
        try encodeBlockAppendWithTable(self.allocator, out, input, table);
    }

    pub fn encodeFrameAlloc(self: *Encoder, input: []const u8) Error![]u8 {
        var out: std.ArrayList(u8) = .empty;
        errdefer out.deinit(self.allocator);
        try self.encodeFrameAppend(&out, input);
        return out.toOwnedSlice(self.allocator);
    }

    pub fn encodeFrameAppend(self: *Encoder, out: *std.ArrayList(u8), input: []const u8) Error!void {
        try writeChunk(self.allocator, out, stream_identifier_chunk_type, stream_identifier_payload);
        var offset: usize = 0;
        while (offset < input.len) {
            const chunk_len = @min(input.len - offset, max_uncompressed_chunk_len);
            const chunk = input[offset..][0..chunk_len];
            self.block_scratch.clearRetainingCapacity();
            try self.encodeBlockAppend(&self.block_scratch, chunk);
            if (self.block_scratch.items.len < chunk.len) {
                try writeCheckedChunk(self.allocator, out, compressed_data_chunk_type, chunk, self.block_scratch.items);
            } else {
                try writeCheckedChunk(self.allocator, out, uncompressed_data_chunk_type, chunk, chunk);
            }
            offset += chunk_len;
        }
    }

    fn ensureTable(self: *Encoder) Error![]u32 {
        if (self.table.len == 0) self.table = try self.allocator.alloc(u32, hash_table_len);
        return self.table;
    }
};

fn encodeBlockAppendWithTable(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8, table: []u32) Error!void {
    try writeVarint(allocator, out, input.len);
    if (input.len < min_match_len) {
        try emitLiteral(allocator, out, input);
        return;
    }

    if (table.len < hash_table_len) return error.InputTooSmall;
    @memset(table, invalid_pos);

    var ip: usize = 0;
    var literal_start: usize = 0;
    while (ip + min_match_len <= input.len) {
        const h = hash4(input[ip..][0..4]);
        const candidate_pos = table[h];
        table[h] = @intCast(ip);

        if (candidate_pos != invalid_pos) {
            const candidate: usize = candidate_pos;
            const offset = ip - candidate;
            if (offset != 0 and offset <= max_copy4_offset and equal4(input[candidate..][0..4], input[ip..][0..4])) {
                const match_len = countMatch(input, candidate, ip);
                try emitLiteral(allocator, out, input[literal_start..ip]);
                try emitCopy(allocator, out, offset, match_len);
                ip += match_len;
                literal_start = ip;
                continue;
            }
        }

        ip += 1;
    }

    try emitLiteral(allocator, out, input[literal_start..]);
}

fn encodeBlockIntoWithTable(out: *std.ArrayList(u8), input: []const u8, table: []u32) Error!void {
    try writeVarintInto(out, input.len);
    if (input.len < min_match_len) {
        try emitLiteralInto(out, input);
        return;
    }

    if (table.len < hash_table_len) return error.InputTooSmall;
    @memset(table, invalid_pos);

    var ip: usize = 0;
    var literal_start: usize = 0;
    while (ip + min_match_len <= input.len) {
        const h = hash4(input[ip..][0..4]);
        const candidate_pos = table[h];
        table[h] = @intCast(ip);

        if (candidate_pos != invalid_pos) {
            const candidate: usize = candidate_pos;
            const offset = ip - candidate;
            if (offset != 0 and offset <= max_copy4_offset and equal4(input[candidate..][0..4], input[ip..][0..4])) {
                const match_len = countMatch(input, candidate, ip);
                try emitLiteralInto(out, input[literal_start..ip]);
                try emitCopyInto(out, offset, match_len);
                ip += match_len;
                literal_start = ip;
                continue;
            }
        }

        ip += 1;
    }

    try emitLiteralInto(out, input[literal_start..]);
}

pub fn encodeBlockInto(input: []const u8, output: []u8) Error!usize {
    const bound = try encodedBlockBound(input.len);
    if (output.len < bound) return error.OutputTooSmall;
    var out = std.ArrayList(u8).initBuffer(output);
    if (input.len < min_match_len) {
        try writeVarintInto(&out, input.len);
        try emitLiteralInto(&out, input);
    } else {
        var table: [hash_table_len]u32 = undefined;
        try encodeBlockIntoWithTable(&out, input, &table);
    }
    return out.items.len;
}

pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try encodeFrameAppend(allocator, &out, input);
    return out.toOwnedSlice(allocator);
}

pub fn encodeFrameAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), input: []const u8) Error!void {
    var encoder = Encoder.init(allocator);
    defer encoder.deinit();
    try encoder.encodeFrameAppend(out, input);
}

pub fn encodeFrameInto(input: []const u8, output: []u8) Error!usize {
    const bound = try encodedFrameBound(input.len);
    if (output.len < bound) return error.OutputTooSmall;
    var out = std.ArrayList(u8).initBuffer(output);
    try writeChunkInto(&out, stream_identifier_chunk_type, stream_identifier_payload);
    var table: [hash_table_len]u32 = undefined;
    var block_scratch_buffer: [try encodedBlockBound(max_uncompressed_chunk_len)]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const chunk_len = @min(input.len - offset, max_uncompressed_chunk_len);
        const chunk = input[offset..][0..chunk_len];
        var block_scratch = std.ArrayList(u8).initBuffer(&block_scratch_buffer);
        try encodeBlockIntoWithTable(&block_scratch, chunk, &table);
        if (block_scratch.items.len < chunk.len) {
            try writeCheckedChunkInto(&out, compressed_data_chunk_type, chunk, block_scratch.items);
        } else {
            try writeCheckedChunkInto(&out, uncompressed_data_chunk_type, chunk, chunk);
        }
        offset += chunk_len;
    }
    return out.items.len;
}

pub fn summarizeFrame(frame: []const u8) Error!FrameSummary {
    var iterator = try FrameChunkIterator.init(frame);
    var summary: FrameSummary = .{};
    while (try iterator.next()) |chunk| {
        switch (chunk.kind) {
            .stream_identifier => summary.stream_identifier_count += 1,
            .skippable => {
                summary.skippable_chunk_count += 1;
                summary.skippable_payload_bytes = try checkedAdd(summary.skippable_payload_bytes, chunk.payload.len);
            },
            .uncompressed => {
                const payload = chunk.payload[4..];
                summary.uncompressed_chunk_count += 1;
                summary.uncompressed_payload_bytes = try checkedAdd(summary.uncompressed_payload_bytes, payload.len);
                summary.decoded_bytes = try checkedAdd(summary.decoded_bytes, payload.len);
                try verifyMaskedChecksum(payload, std.mem.readInt(u32, chunk.payload[0..4], .little));
            },
            .compressed => {
                const payload = chunk.payload[4..];
                summary.compressed_chunk_count += 1;
                summary.compressed_payload_bytes = try checkedAdd(summary.compressed_payload_bytes, payload.len);
                const decoded_len = try decodedBlockSize(payload);
                if (decoded_len > max_uncompressed_chunk_len) return error.CorruptFrame;
                summary.decoded_bytes = try checkedAdd(summary.decoded_bytes, decoded_len);
                var decoded: [max_uncompressed_chunk_len]u8 = undefined;
                const written = try decodeBlockInto(payload, decoded[0..decoded_len]);
                if (written != decoded_len) return error.SizeMismatch;
                try verifyMaskedChecksum(decoded[0..decoded_len], std.mem.readInt(u32, chunk.payload[0..4], .little));
            },
        }
    }
    return summary;
}

pub fn summarizeFrameChunks(chunks: []const []const u8, compressed_scratch: []u8) Error!FrameSummary {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try summarizeFrame(joined);
}

pub fn decodeBlockAlloc(allocator: std.mem.Allocator, block: []const u8) Error![]u8 {
    return try decodeBlockAllocLimited(allocator, block, std.math.maxInt(usize));
}

pub fn decodeBlockAllocLimited(allocator: std.mem.Allocator, block: []const u8, max_output_len: usize) Error![]u8 {
    const decoded_len = try decodedBlockSizeLimited(block, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeBlockInto(block, out);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeBlockAllocExactSize(allocator: std.mem.Allocator, block: []const u8, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedBlockSize(block);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = try decodeBlockInto(block, out);
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeBlockAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8) Error!usize {
    return try decodeBlockAppendLimited(allocator, out, block, std.math.maxInt(usize));
}

pub fn decodeBlockAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, max_output_len: usize) Error!usize {
    const decoded_len = try decodedBlockSizeLimited(block, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeBlockInto(block, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeBlockAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), block: []const u8, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedBlockSize(block);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeBlockInto(block, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != expected_output_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeBlockInto(block: []const u8, output: []u8) Error!usize {
    const header = try readHeader(block);
    if (output.len < header.decoded_len) return error.OutputTooSmall;
    var input_index = header.index;
    var written: usize = 0;
    while (input_index < block.len) {
        if (written == header.decoded_len) return error.TrailingData;
        const tag = block[input_index];
        input_index += 1;
        switch (tag & 0x03) {
            0 => {
                const literal_len = try readLiteralLen(tag, block, &input_index);
                if (literal_len > header.decoded_len - written) return error.SizeMismatch;
                if (block.len - input_index < literal_len) return error.TruncatedFrame;
                @memcpy(output[written..][0..literal_len], block[input_index..][0..literal_len]);
                input_index += literal_len;
                written += literal_len;
            },
            1 => {
                const len: usize = 4 + ((tag >> 2) & 0x07);
                if (block.len - input_index < 1) return error.TruncatedFrame;
                const offset: usize = (@as(usize, tag & 0xe0) << 3) | block[input_index];
                input_index += 1;
                try copyFromHistory(output[0..header.decoded_len], written, offset, len);
                written += len;
            },
            2 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 2) return error.TruncatedFrame;
                const offset = std.mem.readInt(u16, block[input_index..][0..2], .little);
                input_index += 2;
                try copyFromHistory(output[0..header.decoded_len], written, offset, len);
                written += len;
            },
            3 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 4) return error.TruncatedFrame;
                const offset = std.mem.readInt(u32, block[input_index..][0..4], .little);
                input_index += 4;
                try copyFromHistory(output[0..header.decoded_len], written, offset, len);
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
    return written;
}

pub fn decodeBlockIntoExactSize(block: []const u8, output: []u8, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const decoded_len = try decodedBlockSize(block);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const written = decodeBlockInto(block, output[0..expected_output_len]) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeBlockChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockAlloc(allocator, joined);
}

pub fn decodeBlockChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockAllocExactSize(allocator, joined, expected_output_len);
}

pub fn decodeBlockChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockAllocLimited(allocator, joined, max_output_len);
}

pub fn decodeBlockChunksAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockAppend(allocator, out, joined);
}

pub fn decodeBlockChunksAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockAppendExactSize(allocator, out, joined, expected_output_len);
}

pub fn decodeBlockChunksAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockAppendLimited(allocator, out, joined, max_output_len);
}

pub fn decodeBlockChunksInto(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockInto(joined, output);
}

pub fn decodeBlockChunksIntoExactSize(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeBlockIntoExactSize(joined, output, expected_output_len);
}

pub fn decodedBlockSize(block: []const u8) Error!usize {
    return try decodedBlockSizeLimited(block, std.math.maxInt(usize));
}

pub fn decodedBlockSizeLimited(block: []const u8, max_output_len: usize) Error!usize {
    const header = try readHeader(block);
    if (header.decoded_len > max_output_len) return error.OutputLimitExceeded;
    var input_index = header.index;
    var written: usize = 0;
    while (input_index < block.len) {
        if (written == header.decoded_len) return error.TrailingData;
        const tag = block[input_index];
        input_index += 1;
        switch (tag & 0x03) {
            0 => {
                const literal_len = try readLiteralLen(tag, block, &input_index);
                if (literal_len > header.decoded_len - written) return error.SizeMismatch;
                if (block.len - input_index < literal_len) return error.TruncatedFrame;
                input_index += literal_len;
                written += literal_len;
            },
            1 => {
                const len: usize = 4 + ((tag >> 2) & 0x07);
                if (block.len - input_index < 1) return error.TruncatedFrame;
                const offset: usize = (@as(usize, tag & 0xe0) << 3) | block[input_index];
                input_index += 1;
                try validateCopy(written, header.decoded_len, offset, len);
                written += len;
            },
            2 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 2) return error.TruncatedFrame;
                const offset = std.mem.readInt(u16, block[input_index..][0..2], .little);
                input_index += 2;
                try validateCopy(written, header.decoded_len, offset, len);
                written += len;
            },
            3 => {
                const len: usize = 1 + (tag >> 2);
                if (block.len - input_index < 4) return error.TruncatedFrame;
                const offset = std.mem.readInt(u32, block[input_index..][0..4], .little);
                input_index += 4;
                try validateCopy(written, header.decoded_len, offset, len);
                written += len;
            },
            else => unreachable,
        }
    }
    if (written != header.decoded_len) return error.TruncatedFrame;
    return header.decoded_len;
}

pub fn decodedBlockChunksSize(chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedBlockSize(joined);
}

pub fn decodedBlockChunksSizeLimited(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedBlockSizeLimited(joined, max_output_len);
}

pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    return try decodeFrameAllocLimited(allocator, frame, std.math.maxInt(usize));
}

pub fn decodeFrameAllocLimited(allocator: std.mem.Allocator, frame: []const u8, max_output_len: usize) Error![]u8 {
    const decoded_len = try decodedFrameSizeLimited(frame, max_output_len);
    const out = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(out);
    const written = try decodeFrameInto(frame, out);
    if (written != decoded_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAllocExactSize(allocator: std.mem.Allocator, frame: []const u8, expected_output_len: usize) Error![]u8 {
    const decoded_len = try decodedFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const out = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(out);
    const written = try decodeFrameInto(frame, out);
    if (written != expected_output_len) return error.SizeMismatch;
    return out;
}

pub fn decodeFrameAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8) Error!usize {
    return try decodeFrameAppendLimited(allocator, out, frame, std.math.maxInt(usize));
}

pub fn decodeFrameAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, max_output_len: usize) Error!usize {
    const decoded_len = try decodedFrameSizeLimited(frame, max_output_len);
    try out.ensureUnusedCapacity(allocator, decoded_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(decoded_len);
    const written = decodeFrameInto(frame, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != decoded_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeFrameAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), frame: []const u8, expected_output_len: usize) Error!usize {
    const decoded_len = try decodedFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    try out.ensureUnusedCapacity(allocator, expected_output_len);
    const start = out.items.len;
    const slot = out.addManyAsSliceAssumeCapacity(expected_output_len);
    const written = decodeFrameInto(frame, slot) catch |err| {
        out.items.len = start;
        return err;
    };
    if (written != expected_output_len) {
        out.items.len = start;
        return error.SizeMismatch;
    }
    return written;
}

pub fn decodeFrameInto(frame: []const u8, output: []u8) Error!usize {
    var iterator = try FrameChunkIterator.init(frame);
    var written: usize = 0;
    while (try iterator.next()) |chunk| {
        switch (chunk.kind) {
            .stream_identifier, .skippable => {},
            .uncompressed => {
                const payload = chunk.payload[4..];
                if (output.len - written < payload.len) return error.OutputTooSmall;
                try verifyMaskedChecksum(payload, std.mem.readInt(u32, chunk.payload[0..4], .little));
                @memcpy(output[written..][0..payload.len], payload);
                written += payload.len;
            },
            .compressed => {
                const compressed = chunk.payload[4..];
                const decoded_len = try decodedBlockSize(compressed);
                if (decoded_len > max_uncompressed_chunk_len) return error.CorruptFrame;
                if (output.len - written < decoded_len) return error.OutputTooSmall;
                const decoded = output[written..][0..decoded_len];
                const n = try decodeBlockInto(compressed, decoded);
                if (n != decoded_len) return error.SizeMismatch;
                try verifyMaskedChecksum(decoded, std.mem.readInt(u32, chunk.payload[0..4], .little));
                written += decoded_len;
            },
        }
    }
    return written;
}

pub fn decodeFrameIntoExactSize(frame: []const u8, output: []u8, expected_output_len: usize) Error!usize {
    if (output.len < expected_output_len) return error.OutputTooSmall;
    const decoded_len = try decodedFrameSize(frame);
    if (decoded_len != expected_output_len) return error.SizeMismatch;
    const written = decodeFrameInto(frame, output[0..expected_output_len]) catch |err| switch (err) {
        error.OutputTooSmall => return error.SizeMismatch,
        else => return err,
    };
    if (written != expected_output_len) return error.SizeMismatch;
    return written;
}

pub fn decodeFrameChunksAlloc(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAlloc(allocator, joined);
}

pub fn decodeFrameChunksAllocExactSize(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocExactSize(allocator, joined, expected_output_len);
}

pub fn decodeFrameChunksAllocLimited(allocator: std.mem.Allocator, chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error![]u8 {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAllocLimited(allocator, joined, max_output_len);
}

pub fn decodeFrameChunksAppend(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppend(allocator, out, joined);
}

pub fn decodeFrameChunksAppendExactSize(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendExactSize(allocator, out, joined, expected_output_len);
}

pub fn decodeFrameChunksAppendLimited(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameAppendLimited(allocator, out, joined, max_output_len);
}

pub fn decodeFrameChunksInto(chunks: []const []const u8, compressed_scratch: []u8, output: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameInto(joined, output);
}

pub fn decodeFrameChunksIntoExactSize(chunks: []const []const u8, compressed_scratch: []u8, output: []u8, expected_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodeFrameIntoExactSize(joined, output, expected_output_len);
}

pub fn decodedFrameSize(frame: []const u8) Error!usize {
    return try decodedFrameSizeLimited(frame, std.math.maxInt(usize));
}

pub fn decodedFrameSizeLimited(frame: []const u8, max_output_len: usize) Error!usize {
    var iterator = try FrameChunkIterator.init(frame);
    var total: usize = 0;
    while (try iterator.next()) |chunk| {
        switch (chunk.kind) {
            .stream_identifier, .skippable => {},
            .uncompressed => {
                const payload_len = chunk.payload.len - 4;
                const next_total = std.math.add(usize, total, payload_len) catch return error.IntegerOverflow;
                if (next_total > max_output_len) return error.OutputLimitExceeded;
                try verifyMaskedChecksum(chunk.payload[4..], std.mem.readInt(u32, chunk.payload[0..4], .little));
                total = next_total;
            },
            .compressed => {
                const payload = chunk.payload[4..];
                const decoded_len = try decodedBlockSize(payload);
                if (decoded_len > max_uncompressed_chunk_len) return error.CorruptFrame;
                const next_total = std.math.add(usize, total, decoded_len) catch return error.IntegerOverflow;
                if (next_total > max_output_len) return error.OutputLimitExceeded;
                var decoded: [max_uncompressed_chunk_len]u8 = undefined;
                const written = try decodeBlockInto(payload, decoded[0..decoded_len]);
                if (written != decoded_len) return error.SizeMismatch;
                try verifyMaskedChecksum(decoded[0..decoded_len], std.mem.readInt(u32, chunk.payload[0..4], .little));
                total = next_total;
            },
        }
    }
    return total;
}

pub fn decodedFrameChunksSize(chunks: []const []const u8, compressed_scratch: []u8) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSize(joined);
}

pub fn decodedFrameChunksSizeLimited(chunks: []const []const u8, compressed_scratch: []u8, max_output_len: usize) Error!usize {
    const joined = try joinChunks(chunks, compressed_scratch);
    return try decodedFrameSizeLimited(joined, max_output_len);
}

const FrameChunkKind = enum {
    stream_identifier,
    compressed,
    uncompressed,
    skippable,
};

const FrameChunk = struct {
    kind: FrameChunkKind,
    payload: []const u8,
};

const FrameChunkIterator = struct {
    frame: []const u8,
    index: usize = 0,
    saw_identifier: bool = false,

    fn init(frame: []const u8) Error!FrameChunkIterator {
        return .{ .frame = frame };
    }

    fn next(self: *FrameChunkIterator) Error!?FrameChunk {
        if (self.index == self.frame.len) return null;
        if (self.frame.len - self.index < 4) return error.TruncatedFrame;
        const chunk_type = self.frame[self.index];
        const chunk_len = readU24(self.frame[self.index + 1 ..][0..3]);
        self.index += 4;
        if (self.frame.len - self.index < chunk_len) return error.TruncatedFrame;
        const payload = self.frame[self.index..][0..chunk_len];
        self.index += chunk_len;

        if (!self.saw_identifier and chunk_type != stream_identifier_chunk_type) return error.InvalidMagic;
        switch (chunk_type) {
            stream_identifier_chunk_type => {
                if (!std.mem.eql(u8, payload, stream_identifier_payload)) return error.InvalidMagic;
                self.saw_identifier = true;
                return .{ .kind = .stream_identifier, .payload = payload };
            },
            compressed_data_chunk_type => {
                try self.requireIdentifier();
                if (payload.len < 4) return error.TruncatedFrame;
                return .{ .kind = .compressed, .payload = payload };
            },
            uncompressed_data_chunk_type => {
                try self.requireIdentifier();
                if (payload.len < 4) return error.TruncatedFrame;
                if (payload.len - 4 > max_uncompressed_chunk_len) return error.CorruptFrame;
                return .{ .kind = .uncompressed, .payload = payload };
            },
            else => {
                if (chunk_type >= min_skippable_chunk_type and chunk_type != stream_identifier_chunk_type) {
                    return .{ .kind = .skippable, .payload = payload };
                }
                return error.UnsupportedSnappyFeature;
            },
        }
    }

    fn requireIdentifier(self: FrameChunkIterator) Error!void {
        if (!self.saw_identifier) return error.InvalidMagic;
    }
};

fn joinChunks(chunks: []const []const u8, compressed_scratch: []u8) Error![]const u8 {
    // Snappy's current decoders operate on contiguous compressed bytes.  The
    // chunked convenience APIs deliberately require caller-owned scratch so
    // split-input users do not get a hidden allocation or global buffer.
    var total: usize = 0;
    for (chunks) |chunk| {
        total = std.math.add(usize, total, chunk.len) catch return error.IntegerOverflow;
    }
    if (compressed_scratch.len < total) return error.OutputTooSmall;
    var offset: usize = 0;
    for (chunks) |chunk| {
        @memcpy(compressed_scratch[offset..][0..chunk.len], chunk);
        offset += chunk.len;
    }
    return compressed_scratch[0..total];
}

fn readHeader(block: []const u8) Error!Header {
    var result: usize = 0;
    var shift: u6 = 0;
    var index: usize = 0;
    while (index < block.len and index < 5) : (index += 1) {
        const byte = block[index];
        const payload = byte & 0x7f;
        if (index == 4 and payload > 0x0f) return error.CorruptFrame;
        result |= @as(usize, payload) << shift;
        if ((byte & 0x80) == 0) {
            return .{ .decoded_len = result, .index = index + 1 };
        }
        shift += 7;
    }
    return if (index < 5) error.TruncatedFrame else error.CorruptFrame;
}

fn writeVarint(allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: usize) Error!void {
    if (value > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    var remaining = value;
    while (remaining >= 0x80) {
        try out.append(allocator, @as(u8, @intCast(remaining & 0x7f)) | 0x80);
        remaining >>= 7;
    }
    try out.append(allocator, @intCast(remaining));
}

fn writeVarintInto(out: *std.ArrayList(u8), value: usize) Error!void {
    if (value > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    var remaining = value;
    while (remaining >= 0x80) {
        try out.appendBounded(@as(u8, @intCast(remaining & 0x7f)) | 0x80);
        remaining >>= 7;
    }
    try out.appendBounded(@intCast(remaining));
}

fn varintEncodedLen(value: usize) Error!usize {
    if (value > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    var remaining = value;
    var len: usize = 1;
    while (remaining >= 0x80) {
        remaining >>= 7;
        len += 1;
    }
    return len;
}

fn writeChunk(allocator: std.mem.Allocator, out: *std.ArrayList(u8), chunk_type: u8, payload: []const u8) Error!void {
    if (payload.len > 0x00ff_ffff) return error.OutputLimitExceeded;
    try out.append(allocator, chunk_type);
    var len_bytes: [3]u8 = undefined;
    writeU24(&len_bytes, payload.len);
    try out.appendSlice(allocator, &len_bytes);
    try out.appendSlice(allocator, payload);
}

fn writeChunkInto(out: *std.ArrayList(u8), chunk_type: u8, payload: []const u8) Error!void {
    if (payload.len > 0x00ff_ffff) return error.OutputLimitExceeded;
    try out.appendBounded(chunk_type);
    var len_bytes: [3]u8 = undefined;
    writeU24(&len_bytes, payload.len);
    try out.appendSliceBounded(&len_bytes);
    try out.appendSliceBounded(payload);
}

fn writeCheckedChunk(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    chunk_type: u8,
    plain: []const u8,
    payload: []const u8,
) Error!void {
    var checked: std.ArrayList(u8) = .empty;
    defer checked.deinit(allocator);
    var checksum_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum_bytes, maskedCrc32c(plain), .little);
    try checked.appendSlice(allocator, &checksum_bytes);
    try checked.appendSlice(allocator, payload);
    try writeChunk(allocator, out, chunk_type, checked.items);
}

fn writeCheckedChunkInto(out: *std.ArrayList(u8), chunk_type: u8, plain: []const u8, payload: []const u8) Error!void {
    if (payload.len > 0x00ff_ffff - 4) return error.OutputLimitExceeded;
    try out.appendBounded(chunk_type);
    var len_bytes: [3]u8 = undefined;
    writeU24(&len_bytes, payload.len + 4);
    try out.appendSliceBounded(&len_bytes);
    var checksum_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum_bytes, maskedCrc32c(plain), .little);
    try out.appendSliceBounded(&checksum_bytes);
    try out.appendSliceBounded(payload);
}

fn verifyMaskedChecksum(payload: []const u8, expected: u32) Error!void {
    if (maskedCrc32c(payload) != expected) return error.ChecksumMismatch;
}

fn maskedCrc32c(payload: []const u8) u32 {
    const crc = checksum.crc32c(payload);
    return ((crc >> 15) | (crc << 17)) +% 0xa282_ead8;
}

fn readU24(bytes: *const [3]u8) usize {
    return @as(usize, bytes[0]) | (@as(usize, bytes[1]) << 8) | (@as(usize, bytes[2]) << 16);
}

fn writeU24(bytes: *[3]u8, value: usize) void {
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
    bytes[2] = @intCast((value >> 16) & 0xff);
}

fn readLiteralLen(tag: u8, block: []const u8, input_index: *usize) Error!usize {
    const tag_len = tag >> 2;
    if (tag_len < 60) return @as(usize, tag_len) + 1;
    const byte_count: usize = @as(usize, tag_len) - 59;
    if (block.len - input_index.* < byte_count) return error.TruncatedFrame;
    var len_minus_one: usize = 0;
    var shift: u6 = 0;
    var i: usize = 0;
    while (i < byte_count) : (i += 1) {
        len_minus_one |= @as(usize, block[input_index.* + i]) << shift;
        shift += 8;
    }
    input_index.* += byte_count;
    return std.math.add(usize, len_minus_one, 1) catch error.IntegerOverflow;
}

fn literalHeaderLen(literal_len: usize) Error!usize {
    if (literal_len == 0) return 0;
    const len_minus_one = literal_len - 1;
    if (len_minus_one < 60) return 1;
    var byte_count: usize = 1;
    var tmp = len_minus_one;
    while (tmp >= 0x100) : (tmp >>= 8) byte_count += 1;
    if (byte_count > 4) return error.OutputLimitExceeded;
    return 1 + byte_count;
}

fn emitLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8) Error!void {
    if (literal.len == 0) return;
    const len_minus_one = literal.len - 1;
    if (len_minus_one < 60) {
        try out.append(allocator, @intCast(len_minus_one << 2));
    } else {
        var byte_count: usize = 1;
        var tmp = len_minus_one;
        while (tmp >= 0x100) : (tmp >>= 8) byte_count += 1;
        if (byte_count > 4) return error.OutputLimitExceeded;
        try out.append(allocator, @intCast((59 + byte_count) << 2));
        tmp = len_minus_one;
        var i: usize = 0;
        while (i < byte_count) : (i += 1) {
            try out.append(allocator, @intCast(tmp & 0xff));
            tmp >>= 8;
        }
    }
    try out.appendSlice(allocator, literal);
}

fn emitLiteralInto(out: *std.ArrayList(u8), literal: []const u8) Error!void {
    if (literal.len == 0) return;
    const len_minus_one = literal.len - 1;
    if (len_minus_one < 60) {
        try out.appendBounded(@intCast(len_minus_one << 2));
    } else {
        var byte_count: usize = 1;
        var tmp = len_minus_one;
        while (tmp >= 0x100) : (tmp >>= 8) byte_count += 1;
        if (byte_count > 4) return error.OutputLimitExceeded;
        try out.appendBounded(@intCast((59 + byte_count) << 2));
        tmp = len_minus_one;
        var i: usize = 0;
        while (i < byte_count) : (i += 1) {
            try out.appendBounded(@intCast(tmp & 0xff));
            tmp >>= 8;
        }
    }
    try out.appendSliceBounded(literal);
}

fn emitCopy(allocator: std.mem.Allocator, out: *std.ArrayList(u8), offset: usize, len: usize) Error!void {
    if (offset == 0 or offset > max_copy4_offset) return error.InvalidMatch;
    var remaining = len;
    while (remaining > 0) {
        const chunk: usize = @min(remaining, @as(usize, 60));
        if (offset <= max_copy2_offset) {
            try out.append(allocator, @as(u8, @intCast((chunk - 1) << 2)) | 0x02);
            try out.append(allocator, @intCast(offset & 0xff));
            try out.append(allocator, @intCast((offset >> 8) & 0xff));
        } else {
            try out.append(allocator, @as(u8, @intCast((chunk - 1) << 2)) | 0x03);
            var offset_bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &offset_bytes, @intCast(offset), .little);
            try out.appendSlice(allocator, &offset_bytes);
        }
        remaining -= chunk;
    }
}

fn emitCopyInto(out: *std.ArrayList(u8), offset: usize, len: usize) Error!void {
    if (offset == 0 or offset > max_copy4_offset) return error.InvalidMatch;
    var remaining = len;
    while (remaining > 0) {
        const chunk: usize = @min(remaining, @as(usize, 60));
        if (offset <= max_copy2_offset) {
            try out.appendBounded(@as(u8, @intCast((chunk - 1) << 2)) | 0x02);
            try out.appendBounded(@intCast(offset & 0xff));
            try out.appendBounded(@intCast((offset >> 8) & 0xff));
        } else {
            try out.appendBounded(@as(u8, @intCast((chunk - 1) << 2)) | 0x03);
            var offset_bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &offset_bytes, @intCast(offset), .little);
            try out.appendSliceBounded(&offset_bytes);
        }
        remaining -= chunk;
    }
}

fn hash4(bytes: *const [4]u8) usize {
    const value = std.mem.readInt(u32, bytes, .little);
    return @intCast((value *% 0x1e35_a7bd) >> (32 - hash_bits));
}

fn equal4(a: *const [4]u8, b: *const [4]u8) bool {
    return std.mem.readInt(u32, a, .little) == std.mem.readInt(u32, b, .little);
}

fn countMatch(input: []const u8, candidate: usize, ip: usize) usize {
    var len: usize = min_match_len;
    while (ip + len < input.len and input[candidate + len] == input[ip + len]) {
        len += 1;
    }
    return len;
}

fn validateCopy(written: usize, decoded_len: usize, offset_raw: anytype, len: usize) Error!void {
    const offset: usize = @intCast(offset_raw);
    if (offset == 0 or offset > written) return error.InvalidMatch;
    if (len > decoded_len - written) return error.SizeMismatch;
}

fn copyFromHistory(output: []u8, written: usize, offset_raw: anytype, len: usize) Error!void {
    try validateCopy(written, output.len, offset_raw, len);
    const offset: usize = @intCast(offset_raw);
    var i: usize = 0;
    while (i < len) : (i += 1) {
        output[written + i] = output[written - offset + i];
    }
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedMul(a: usize, b: usize) Error!usize {
    return std.math.mul(usize, a, b) catch error.IntegerOverflow;
}

fn checkedUsizeToU32(value: usize) Error!u32 {
    if (value > std.math.maxInt(u32)) return error.OutputLimitExceeded;
    return @intCast(value);
}

test "snappy raw block encodes empty and hello with known bytes" {
    const empty = try encodeBlockAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqualSlices(u8, &[_]u8{0x00}, empty);
    try std.testing.expectEqual(empty.len, try encodedBlockBound(0));
    try std.testing.expectEqual(@as(usize, 0), try decodedBlockSize(empty));

    const hello = try encodeBlockAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(hello);
    try std.testing.expect(hello.len <= try encodedBlockBound("hello".len));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0x05, 0x10, 'h', 'e', 'l', 'l', 'o' }, hello);
    const decoded = try decodeBlockAlloc(std.testing.allocator, hello);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello", decoded);

    const block_bound = try encodedBlockBound("hello".len);
    const bound_out = try std.testing.allocator.alloc(u8, block_bound);
    defer std.testing.allocator.free(bound_out);
    try std.testing.expectEqual(hello.len, try encodeBlockInto("hello", bound_out));
    try std.testing.expectEqualSlices(u8, hello, bound_out[0..hello.len]);

    var too_small: [1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, encodeBlockInto("hello", &too_small));
    try std.testing.expectError(error.OutputTooSmall, encodeFrameInto("hello", &too_small));
}

test "snappy raw block round trips repeated payload with copy tokens" {
    const payload = "abcabcabcabcabcabc" ** 16;
    const encoded = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < payload.len);
    try std.testing.expectEqual(payload.len, try decodedBlockSize(encoded));
    const decoded = try decodeBlockAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    try std.testing.expectError(error.OutputLimitExceeded, decodedBlockSizeLimited(encoded, payload.len - 1));
}

test "snappy raw block chunked input helpers mirror one-shot decode" {
    const payload = "chunked snappy raw payload " ** 32;
    const encoded = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..1],
        encoded[1..@min(encoded.len, 5)],
        encoded[@min(encoded.len, 5)..],
    };

    const scratch = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(scratch);
    try std.testing.expectEqual(payload.len, try decodedBlockChunksSize(&chunks, scratch));
    try std.testing.expectError(error.OutputLimitExceeded, decodedBlockChunksSizeLimited(&chunks, scratch, payload.len - 1));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try decodeBlockChunksInto(&chunks, scratch, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);

    const decoded = try decodeBlockChunksAllocLimited(std.testing.allocator, &chunks, scratch, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeBlockChunksAppend(std.testing.allocator, &appended, &chunks, scratch));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);

    var too_small: [1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodedBlockChunksSize(&chunks, &too_small));
}

test "snappy raw block exact-size helpers reject size drift" {
    const payload = "snappy exact-size raw payload " ** 16;
    const encoded = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    const exact = try decodeBlockAllocExactSize(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, payload, exact);
    try std.testing.expectError(error.SizeMismatch, decodeBlockAllocExactSize(std.testing.allocator, encoded, payload.len - 1));

    var output: [payload.len + 4]u8 = @splat(0xaa);
    try std.testing.expectEqual(payload.len, try decodeBlockIntoExactSize(encoded, &output, payload.len));
    try std.testing.expectEqualSlices(u8, payload, output[0..payload.len]);
    try std.testing.expectEqual(@as(u8, 0xaa), output[payload.len]);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.SizeMismatch, decodeBlockAppendExactSize(std.testing.allocator, &appended, encoded, payload.len + 1));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items);
    try std.testing.expectEqual(payload.len, try decodeBlockAppendExactSize(std.testing.allocator, &appended, encoded, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
}

test "snappy reusable encoder matches one-shot block and frame output" {
    const payload = "snappy reusable encoder payload " ** 256;
    var encoder = Encoder.init(std.testing.allocator);
    defer encoder.deinit();

    const block = try encoder.encodeBlockAlloc(payload);
    defer std.testing.allocator.free(block);
    const one_shot_block = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(one_shot_block);
    try std.testing.expectEqualSlices(u8, one_shot_block, block);

    const frame = try encoder.encodeFrameAlloc(payload);
    defer std.testing.allocator.free(frame);
    const one_shot_frame = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(one_shot_frame);
    try std.testing.expectEqualSlices(u8, one_shot_frame, frame);

    const second_block = try encoder.encodeBlockAlloc("second payload second payload second payload");
    defer std.testing.allocator.free(second_block);
    const decoded = try decodeBlockAlloc(std.testing.allocator, second_block);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "second payload second payload second payload", decoded);
}

test "snappy raw block decodes copy1 copy2 and copy4 forms" {
    const copy1 = [_]u8{ 12, 0x08, 'a', 'b', 'c', 0x15, 3 };
    var copy1_out: [12]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 12), try decodeBlockInto(&copy1, &copy1_out));
    try std.testing.expectEqualSlices(u8, "abcabcabcabc", &copy1_out);

    const copy2 = [_]u8{ 5, 0x00, 'a', 0x0e, 0x01, 0x00 };
    var copy2_out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeBlockInto(&copy2, &copy2_out));
    try std.testing.expectEqualSlices(u8, "aaaaa", &copy2_out);

    const copy4 = [_]u8{ 5, 0x00, 'z', 0x0f, 0x01, 0x00, 0x00, 0x00 };
    var copy4_out: [5]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 5), try decodeBlockInto(&copy4, &copy4_out));
    try std.testing.expectEqualSlices(u8, "zzzzz", &copy4_out);
}

test "snappy raw block supports extended literal lengths" {
    const payload = "x" ** 300;
    const encoded = try encodeBlockAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeBlockAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
}

test "snappy raw block rejects malformed input" {
    try std.testing.expectError(error.TruncatedFrame, decodedBlockSize(&[_]u8{}));
    try std.testing.expectError(error.CorruptFrame, decodedBlockSize(&[_]u8{ 0x80, 0x80, 0x80, 0x80, 0x80 }));
    try std.testing.expectError(error.TruncatedFrame, decodedBlockSize(&[_]u8{ 5, 0x10, 'h' }));
    try std.testing.expectError(error.InvalidMatch, decodedBlockSize(&[_]u8{ 4, 0x0e, 0x00, 0x00 }));
    try std.testing.expectError(error.InvalidMatch, decodedBlockSize(&[_]u8{ 4, 0x0e, 0x01, 0x00 }));
    try std.testing.expectError(error.TrailingData, decodedBlockSize(&[_]u8{ 0, 0 }));
}

test "snappy framed stream encodes empty identifier only" {
    const encoded = try encodeFrameAlloc(std.testing.allocator, "");
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqual(encoded.len, try encodedFrameBound(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y' }, encoded);
    try std.testing.expectEqual(@as(usize, 0), try decodedFrameSize(encoded));
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "", decoded);
}

test "snappy framed stream round trips and enforces output limits" {
    const payload = "snappy frame payload" ** 1024;
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len <= try encodedFrameBound(payload.len));
    try std.testing.expect(encoded.len < payload.len);
    try std.testing.expectEqual(compressed_data_chunk_type, encoded[10]);
    try std.testing.expectEqual(payload.len, try decodedFrameSize(encoded));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(encoded, payload.len - 1));
    const decoded = try decodeFrameAllocLimited(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const frame_bound = try encodedFrameBound(payload.len);
    const encoded_into = try std.testing.allocator.alloc(u8, frame_bound);
    defer std.testing.allocator.free(encoded_into);
    const written = try encodeFrameInto(payload, encoded_into);
    try std.testing.expectEqual(encoded.len, written);
    try std.testing.expectEqualSlices(u8, encoded, encoded_into[0..written]);
}

test "snappy framed stream chunked input helpers mirror one-shot decode" {
    const payload = "chunked snappy frame payload" ** 512;
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    const chunks = [_][]const u8{
        encoded[0..3],
        encoded[3..@min(encoded.len, 11)],
        encoded[@min(encoded.len, 11)..@min(encoded.len, 29)],
        encoded[@min(encoded.len, 29)..],
    };

    const scratch = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(scratch);
    try std.testing.expectEqual(payload.len, try decodedFrameChunksSize(&chunks, scratch));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameChunksSizeLimited(&chunks, scratch, payload.len - 1));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try decodeFrameChunksInto(&chunks, scratch, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);

    const decoded = try decodeFrameChunksAllocLimited(std.testing.allocator, &chunks, scratch, payload.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectEqual(payload.len, try decodeFrameChunksAppend(std.testing.allocator, &appended, &chunks, scratch));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);

    var too_small: [8]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodedFrameChunksSize(&chunks, &too_small));
}

test "snappy framed stream exact-size helpers reject size drift" {
    const payload = "snappy exact-size frame payload " ** 64;
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);

    const exact = try decodeFrameAllocExactSize(std.testing.allocator, encoded, payload.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, payload, exact);
    try std.testing.expectError(error.SizeMismatch, decodeFrameAllocExactSize(std.testing.allocator, encoded, payload.len + 1));

    var output: [payload.len + 4]u8 = @splat(0xaa);
    try std.testing.expectEqual(payload.len, try decodeFrameIntoExactSize(encoded, &output, payload.len));
    try std.testing.expectEqualSlices(u8, payload, output[0..payload.len]);
    try std.testing.expectEqual(@as(u8, 0xaa), output[payload.len]);

    const chunks = [_][]const u8{ encoded[0..4], encoded[4..@min(encoded.len, 31)], encoded[@min(encoded.len, 31)..] };
    const scratch = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(scratch);
    const chunked_exact = try decodeFrameChunksAllocExactSize(std.testing.allocator, &chunks, scratch, payload.len);
    defer std.testing.allocator.free(chunked_exact);
    try std.testing.expectEqualSlices(u8, payload, chunked_exact);
    try std.testing.expectError(error.SizeMismatch, decodeFrameChunksIntoExactSize(&chunks, scratch, &output, payload.len - 1));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    try std.testing.expectError(error.SizeMismatch, decodeFrameChunksAppendExactSize(std.testing.allocator, &appended, &chunks, scratch, payload.len - 1));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items);
    try std.testing.expectEqual(payload.len, try decodeFrameChunksAppendExactSize(std.testing.allocator, &appended, &chunks, scratch, payload.len));
    try std.testing.expectEqualSlices(u8, "prefix:" ++ payload, appended.items);
}

test "snappy framed stream decodes compressed and skippable chunks" {
    const block = try encodeBlockAlloc(std.testing.allocator, "hello hello");
    defer std.testing.allocator.free(block);

    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try writeChunk(std.testing.allocator, &frame, stream_identifier_chunk_type, stream_identifier_payload);
    try writeChunk(std.testing.allocator, &frame, 0x80, "metadata");

    var checked: std.ArrayList(u8) = .empty;
    defer checked.deinit(std.testing.allocator);
    var checksum_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum_bytes, maskedCrc32c("hello hello"), .little);
    try checked.appendSlice(std.testing.allocator, &checksum_bytes);
    try checked.appendSlice(std.testing.allocator, block);
    try writeChunk(std.testing.allocator, &frame, compressed_data_chunk_type, checked.items);

    const decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "hello hello", decoded);

    const summary = try summarizeFrame(frame.items);
    try std.testing.expectEqual(@as(usize, 1), summary.stream_identifier_count);
    try std.testing.expectEqual(@as(usize, 1), summary.compressed_chunk_count);
    try std.testing.expectEqual(@as(usize, 0), summary.uncompressed_chunk_count);
    try std.testing.expectEqual(@as(usize, 1), summary.skippable_chunk_count);
    try std.testing.expectEqual(@as(usize, "metadata".len), summary.skippable_payload_bytes);
    try std.testing.expectEqual(@as(usize, "hello hello".len), summary.decoded_bytes);
    try std.testing.expectEqual(block.len, summary.compressed_payload_bytes);
    try std.testing.expectEqual(@as(usize, 0), summary.uncompressed_payload_bytes);

    const chunks = [_][]const u8{ frame.items[0..4], frame.items[4..@min(frame.items.len, 13)], frame.items[@min(frame.items.len, 13)..] };
    const scratch = try std.testing.allocator.alloc(u8, frame.items.len);
    defer std.testing.allocator.free(scratch);
    const chunked_summary = try summarizeFrameChunks(&chunks, scratch);
    try std.testing.expectEqual(summary.stream_identifier_count, chunked_summary.stream_identifier_count);
    try std.testing.expectEqual(summary.compressed_chunk_count, chunked_summary.compressed_chunk_count);
    try std.testing.expectEqual(summary.skippable_payload_bytes, chunked_summary.skippable_payload_bytes);
    try std.testing.expectEqual(summary.decoded_bytes, chunked_summary.decoded_bytes);

    var corrupt = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(corrupt);
    var corrupt_iterator = try FrameChunkIterator.init(corrupt);
    while (try corrupt_iterator.next()) |chunk| {
        if (chunk.kind == .compressed) {
            const checksum_offset = @intFromPtr(chunk.payload.ptr) - @intFromPtr(corrupt.ptr);
            corrupt[checksum_offset] ^= 1;
            break;
        }
    }
    try std.testing.expectError(error.ChecksumMismatch, summarizeFrame(corrupt));
}

test "snappy framed stream decodes concatenated streams with repeated identifier" {
    const first = try encodeFrameAlloc(std.testing.allocator, "hello");
    defer std.testing.allocator.free(first);
    const second = try encodeFrameAlloc(std.testing.allocator, "world");
    defer std.testing.allocator.free(second);

    var concatenated: std.ArrayList(u8) = .empty;
    defer concatenated.deinit(std.testing.allocator);
    try concatenated.appendSlice(std.testing.allocator, first);
    try concatenated.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(@as(usize, 10), try decodedFrameSize(concatenated.items));
    const decoded = try decodeFrameAlloc(std.testing.allocator, concatenated.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "helloworld", decoded);
}

test "snappy framed stream rejects malformed chunks" {
    try std.testing.expectError(error.TruncatedFrame, decodedFrameSize(&[_]u8{ 0xff, 0x06 }));
    try std.testing.expectError(error.InvalidMagic, decodedFrameSize(&[_]u8{ 0x01, 0x04, 0x00, 0x00, 0, 0, 0, 0 }));
    try std.testing.expectError(error.InvalidMagic, decodedFrameSize(&[_]u8{ 0x80, 0x00, 0x00, 0x00, 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y' }));
    try std.testing.expectError(error.InvalidMagic, decodedFrameSize(&[_]u8{ 0xff, 0x06, 0x00, 0x00, 'b', 'a', 'd', 'b', 'a', 'd' }));
    try std.testing.expectError(error.TruncatedFrame, decodedFrameSize(&[_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x00, 0x03, 0x00, 0x00, 0, 0, 0 }));
    try std.testing.expectError(error.TruncatedFrame, decodedFrameSize(&[_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x01, 0x03, 0x00, 0x00, 0, 0, 0 }));
    try std.testing.expectError(error.UnsupportedSnappyFeature, decodedFrameSize(&[_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x02, 0x00, 0x00, 0x00 }));
    try std.testing.expectError(error.UnsupportedSnappyFeature, decodedFrameSize(&[_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x7f, 0x00, 0x00, 0x00 }));

    const payload = "bad checksum";
    const encoded = try encodeFrameAlloc(std.testing.allocator, payload);
    defer std.testing.allocator.free(encoded);
    var corrupt = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(corrupt);
    corrupt[14] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodedFrameSize(corrupt));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(corrupt, payload.len - 1));

    const known_payload = "abcabcabcabc";
    const block = [_]u8{ 12, 0x08, 'a', 'b', 'c', 0x15, 3 };
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try writeChunk(std.testing.allocator, &frame, stream_identifier_chunk_type, stream_identifier_payload);
    var compressed_checked: std.ArrayList(u8) = .empty;
    defer compressed_checked.deinit(std.testing.allocator);
    var checksum_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum_bytes, maskedCrc32c(known_payload), .little);
    try compressed_checked.appendSlice(std.testing.allocator, &checksum_bytes);
    try compressed_checked.appendSlice(std.testing.allocator, &block);
    try writeChunk(std.testing.allocator, &frame, compressed_data_chunk_type, compressed_checked.items);
    var corrupt_compressed = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(corrupt_compressed);
    corrupt_compressed[corrupt_compressed.len - 1] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodedFrameSize(corrupt_compressed));
    try std.testing.expectError(error.OutputLimitExceeded, decodedFrameSizeLimited(corrupt_compressed, known_payload.len - 1));
    try std.testing.expectError(error.ChecksumMismatch, decodeFrameAlloc(std.testing.allocator, corrupt_compressed));

    const oversized_compressed = try oversizedCompressedChunkFrame(std.testing.allocator);
    defer std.testing.allocator.free(oversized_compressed);
    try std.testing.expectError(error.CorruptFrame, decodedFrameSize(oversized_compressed));
    try std.testing.expectError(error.CorruptFrame, decodeFrameAlloc(std.testing.allocator, oversized_compressed));

    const unsupported = [_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x02, 0x00, 0x00, 0x00 };
    try std.testing.expectError(error.UnsupportedSnappyFeature, decodeFrameAlloc(std.testing.allocator, &unsupported));
    const skippable_before_identifier = [_]u8{ 0x80, 0x00, 0x00, 0x00, 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y' };
    try std.testing.expectError(error.InvalidMagic, decodeFrameAlloc(std.testing.allocator, &skippable_before_identifier));
    const truncated_compressed_payload = [_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x00, 0x03, 0x00, 0x00, 0, 0, 0 };
    try std.testing.expectError(error.TruncatedFrame, decodeFrameAlloc(std.testing.allocator, &truncated_compressed_payload));
    const truncated_uncompressed_payload = [_]u8{ 0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y', 0x01, 0x03, 0x00, 0x00, 0, 0, 0 };
    try std.testing.expectError(error.TruncatedFrame, decodeFrameAlloc(std.testing.allocator, &truncated_uncompressed_payload));

    var small_output_checksum = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(small_output_checksum);
    small_output_checksum[14] ^= 0x01;
    var too_small: [payload.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeFrameInto(small_output_checksum, &too_small));
}

fn oversizedCompressedChunkFrame(allocator: std.mem.Allocator) Error![]u8 {
    const plain = try allocator.alloc(u8, max_uncompressed_chunk_len + 1);
    defer allocator.free(plain);
    @memset(plain, 'x');

    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(allocator);
    try writeVarint(allocator, &block, plain.len);
    try emitLiteral(allocator, &block, plain);

    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try writeChunk(allocator, &frame, stream_identifier_chunk_type, stream_identifier_payload);
    try writeCheckedChunk(allocator, &frame, compressed_data_chunk_type, plain, block.items);
    return frame.toOwnedSlice(allocator);
}
