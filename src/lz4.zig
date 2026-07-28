const std = @import("std");
const core = @import("core.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

pub const default_compression_level: c_int = 10;

const frame_magic = [_]u8{ 0x04, 0x22, 0x4d, 0x18 };
const max_frame_block_len = 4 * 1024 * 1024;
const hash_table_len = 64 * 1024;
const hash_occupancy_words = hash_table_len / @bitSizeOf(u64);
const chain_table_len = 64 * 1024;
const chain_table_mask = chain_table_len - 1;
const invalid_pos = std.math.maxInt(u32);
const max_chain_depth = 8;
const good_match_len = 64;
const lazy_extra_gain = 1;

const Lz4FrameInfo = extern struct {
    blockSizeID: c_int = 7, // LZ4F_max4MB
    blockMode: c_int = 0, // LZ4F_blockLinked; better ratio than independent blocks.
    contentChecksumFlag: c_int = 1,
    frameType: c_int = 0,
    contentSize: c_ulonglong = 0,
    dictID: c_uint = 0,
    blockChecksumFlag: c_int = 0,
};

const Lz4Preferences = extern struct {
    frameInfo: Lz4FrameInfo = .{},
    compressionLevel: c_int = default_compression_level,
    autoFlush: c_uint = 0,
    favorDecSpeed: c_uint = 0,
    reserved: [3]c_uint = .{ 0, 0, 0 },
};

extern fn LZ4F_compressFrameBound(srcSize: usize, preferencesPtr: ?*const Lz4Preferences) usize;
extern fn LZ4F_compressFrame(dstBuffer: *anyopaque, dstCapacity: usize, srcBuffer: *const anyopaque, srcSize: usize, preferencesPtr: ?*const Lz4Preferences) usize;
extern fn LZ4F_isError(code: usize) c_uint;

const Match = struct {
    start: usize = 0,
    len: usize = 0,
};

/// Encode a complete interoperable LZ4 frame using liblz4's high-compression
/// frame encoder. The default level starts at LZ4HC_CLEVEL_OPT_MIN (10)
/// because it closes the C++ reference ratio gap on MCAP chunk workloads while
/// retaining competitive write time. Vort owns this dependency so downstream
/// formats such as MCAP can use tuned LZ4 without carrying compression code
/// themselves.
pub fn encodeFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    return try encodeFrameWithLevelAlloc(allocator, input, default_compression_level);
}

pub fn encodeFrameWithLevelAlloc(allocator: std.mem.Allocator, input: []const u8, level: c_int) Error![]u8 {
    var preferences = Lz4Preferences{
        .frameInfo = .{ .contentSize = try checkedUsizeToU64(input.len) },
        .compressionLevel = level,
    };
    const bound = LZ4F_compressFrameBound(input.len, &preferences);
    if (LZ4F_isError(bound) != 0) return error.CorruptFrame;
    var out = try allocator.alloc(u8, bound);
    errdefer allocator.free(out);
    const written = LZ4F_compressFrame(@ptrCast(out.ptr), out.len, @ptrCast(input.ptr), input.len, &preferences);
    if (LZ4F_isError(written) != 0) return error.CorruptFrame;
    if (allocator.remap(out, written)) |shrunk| return shrunk;
    const exact = try allocator.dupe(u8, out[0..written]);
    allocator.free(out);
    return exact;
}

/// Dependency-free pure Zig LZ4 frame encoder retained for bootstrapping and
/// differential testing. Blocks use a bounded hash-chain parser with one-byte
/// lazy matching, and fall back to uncompressed storage when compression expands
/// the input.
pub fn encodePureFrameAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try out.appendSlice(allocator, &frame_magic);
    const descriptor_start = out.items.len;
    try out.append(allocator, 0x6c); // version=01, independent blocks, content size + checksum
    try out.append(allocator, 0x70); // max block size 4 MiB
    var content_size: [8]u8 = undefined;
    std.mem.writeInt(u64, &content_size, try checkedUsizeToU64(input.len), .little);
    try out.appendSlice(allocator, &content_size);
    const descriptor = out.items[descriptor_start..];
    try out.append(allocator, @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8));

    var occupancy_bits: []u64 = &.{};
    var hash_table: []u32 = &.{};
    var chain_table: []u32 = &.{};
    if (input.len != 0) {
        const table = try allocator.alloc(u32, hash_table_len);
        const bits = allocator.alloc(u64, hash_occupancy_words) catch |err| {
            allocator.free(table);
            return err;
        };
        const chain = allocator.alloc(u32, chain_table_len) catch |err| {
            allocator.free(bits);
            allocator.free(table);
            return err;
        };
        hash_table = table;
        occupancy_bits = bits;
        chain_table = chain;
    }
    defer {
        if (chain_table.len != 0) allocator.free(chain_table);
        if (occupancy_bits.len != 0) allocator.free(occupancy_bits);
        if (hash_table.len != 0) allocator.free(hash_table);
    }

    var offset: usize = 0;
    while (offset < input.len) {
        const block_len = @min(input.len - offset, max_frame_block_len);
        var header: [4]u8 = undefined;
        const block = input[offset..][0..block_len];
        const header_start = out.items.len;
        try out.appendNTimes(allocator, 0, 4);
        const encoded_start = out.items.len;
        const compressed_len = try encodeBlockInto(allocator, &out, block, hash_table, occupancy_bits, chain_table);
        if (compressed_len < block.len) {
            std.mem.writeInt(u32, out.items[header_start..][0..4], @intCast(compressed_len), .little);
        } else {
            out.items.len = encoded_start;
            std.mem.writeInt(u32, &header, 0x8000_0000 | @as(u32, @intCast(block_len)), .little);
            @memcpy(out.items[header_start..][0..4], &header);
            try out.appendSlice(allocator, block);
        }
        offset += block_len;
    }
    try out.appendSlice(allocator, &.{ 0, 0, 0, 0 }); // end mark
    var checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &checksum, std.hash.XxHash32.hash(0, input), .little);
    try out.appendSlice(allocator, &checksum);
    return out.toOwnedSlice(allocator);
}

pub const encodeNativeFrameAlloc = encodePureFrameAlloc;

/// Decode an LZ4 frame. Independent and linked blocks are supported; external
/// dictionaries are not required for frames produced by `encodeFrameAlloc`.
pub fn decodeFrameAlloc(allocator: std.mem.Allocator, frame: []const u8) Error![]u8 {
    if (frame.len < 7) return error.TruncatedFrame;
    if (!std.mem.eql(u8, frame[0..4], &frame_magic)) return error.CorruptFrame;
    const flg = frame[4];
    const bd = frame[5];
    const version = (flg >> 6) & 0x03;
    if (version != 0x01) return error.UnsupportedVersion;
    if ((flg & 0x02) != 0) return error.CorruptFrame;
    const block_size_max = try blockSizeMaxFromDescriptor(bd);
    const block_independent = (flg & 0x20) != 0;
    const block_checksum = (flg & 0x10) != 0;
    const content_size = (flg & 0x08) != 0;
    const content_checksum = (flg & 0x04) != 0;
    const dict_id = (flg & 0x01) != 0;

    var offset: usize = 6;
    const expected_content_size: ?u64 = if (content_size) blk: {
        if (frame.len - offset < 8) return error.TruncatedFrame;
        const value = std.mem.readInt(u64, frame[offset..][0..8], .little);
        offset += 8;
        break :blk value;
    } else null;
    if (dict_id) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        offset += 4;
    }
    if (offset >= frame.len) return error.TruncatedFrame;
    if (frame[offset] != descriptorChecksum(frame[4..offset])) return error.ChecksumMismatch;
    offset += 1;

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (expected_content_size) |size| try out.ensureTotalCapacity(allocator, try checkedU64ToUsize(size));
    while (true) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const block_header = std.mem.readInt(u32, frame[offset..][0..4], .little);
        offset += 4;
        if (block_header == 0) break;
        const uncompressed_block = (block_header & 0x8000_0000) != 0;
        const block_len: usize = @intCast(block_header & 0x7fff_ffff);
        if (block_len > block_size_max) return error.CorruptFrame;
        if (frame.len - offset < block_len) return error.TruncatedFrame;
        const block = frame[offset..][0..block_len];
        offset += block_len;
        if (uncompressed_block) {
            try out.appendSlice(allocator, block);
        } else {
            const history = if (block_independent)
                &[_]u8{}
            else if (out.items.len <= 64 * 1024)
                out.items
            else
                out.items[out.items.len - 64 * 1024 ..];
            if (block_independent) {
                try decodeBlockInto(allocator, &out, block, null, history);
            } else {
                const decoded = try decodeBlockWithPrefixAlloc(allocator, block, null, history);
                defer allocator.free(decoded);
                try out.appendSlice(allocator, decoded);
            }
        }
        if (block_checksum) {
            if (frame.len - offset < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
            if (std.hash.XxHash32.hash(0, block) != expected) return error.ChecksumMismatch;
            offset += 4;
        }
    }
    if (expected_content_size) |size| {
        if (out.items.len != size) return error.SizeMismatch;
    }
    if (content_checksum) {
        if (frame.len - offset < 4) return error.TruncatedFrame;
        const expected = std.mem.readInt(u32, frame[offset..][0..4], .little);
        if (std.hash.XxHash32.hash(0, out.items) != expected) return error.ChecksumMismatch;
        offset += 4;
    }
    if (offset != frame.len) return error.TrailingData;
    return out.toOwnedSlice(allocator);
}

pub const decodeNativeFrameAlloc = decodeFrameAlloc;

fn descriptorChecksum(descriptor: []const u8) u8 {
    return @truncate(std.hash.XxHash32.hash(0, descriptor) >> 8);
}

fn blockSizeMaxFromDescriptor(bd: u8) Error!usize {
    if ((bd & 0x8f) != 0) return error.CorruptFrame;
    return switch ((bd >> 4) & 0x07) {
        4 => 64 * 1024,
        5 => 256 * 1024,
        6 => 1024 * 1024,
        7 => max_frame_block_len,
        else => error.CorruptFrame,
    };
}

pub fn encodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var occupancy_bits: []u64 = &.{};
    var hash_table: []u32 = &.{};
    var chain_table: []u32 = &.{};
    if (input.len != 0) {
        const table = try allocator.alloc(u32, hash_table_len);
        const bits = allocator.alloc(u64, hash_occupancy_words) catch |err| {
            allocator.free(table);
            return err;
        };
        const chain = allocator.alloc(u32, chain_table_len) catch |err| {
            allocator.free(bits);
            allocator.free(table);
            return err;
        };
        hash_table = table;
        occupancy_bits = bits;
        chain_table = chain;
    }
    defer {
        if (chain_table.len != 0) allocator.free(chain_table);
        if (occupancy_bits.len != 0) allocator.free(occupancy_bits);
        if (hash_table.len != 0) allocator.free(hash_table);
    }
    _ = try encodeBlockInto(allocator, &out, input, hash_table, occupancy_bits, chain_table);
    return out.toOwnedSlice(allocator);
}

pub fn decodeBlockAlloc(allocator: std.mem.Allocator, input: []const u8, expected_size: ?usize) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try decodeBlockInto(allocator, &out, input, expected_size, &.{});
    return out.toOwnedSlice(allocator);
}

pub fn decodeBlockWithPrefixAlloc(allocator: std.mem.Allocator, input: []const u8, expected_size: ?usize, prefix: []const u8) Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    try decodeBlockInto(allocator, &out, input, expected_size, prefix);
    return out.toOwnedSlice(allocator);
}

fn decodeBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    expected_size: ?usize,
    prefix: []const u8,
) Error!void {
    const block_start_len = out.items.len;
    if (expected_size) |size| try out.ensureUnusedCapacity(allocator, size);
    var offset: usize = 0;
    while (offset < input.len) {
        const token = input[offset];
        offset += 1;
        var literal_len: usize = token >> 4;
        if (literal_len == 15) literal_len = try checkedAdd(literal_len, try readLengthExtension(input, &offset));
        if (input.len - offset < literal_len) return error.TruncatedFrame;
        try out.appendSlice(allocator, input[offset..][0..literal_len]);
        offset += literal_len;
        if (offset == input.len) break;
        if (input.len - offset < 2) return error.TruncatedFrame;
        const match_offset = std.mem.readInt(u16, input[offset..][0..2], .little);
        offset += 2;
        if (match_offset == 0 or match_offset > (out.items.len - block_start_len) + prefix.len) return error.InvalidMatch;
        var match_len: usize = (token & 0x0f) + 4;
        if ((token & 0x0f) == 15) match_len = try checkedAdd(match_len, try readLengthExtension(input, &offset));
        try copyMatch(allocator, out, prefix, block_start_len, match_offset, match_len);
    }
    if (expected_size) |size| {
        if (out.items.len - block_start_len != size) return error.SizeMismatch;
    }
}

fn copyMatch(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    prefix: []const u8,
    block_start_len: usize,
    match_offset: usize,
    match_len: usize,
) Error!void {
    try out.ensureUnusedCapacity(allocator, match_len);
    const block_len = out.items.len - block_start_len;
    if (match_offset > block_len) {
        const prefix_len = match_offset - block_len;
        const from_prefix = @min(prefix_len, match_len);
        try out.appendSlice(allocator, prefix[prefix.len - prefix_len ..][0..from_prefix]);
        const remaining = match_len - from_prefix;
        if (remaining == 0) return;
        appendMatchFromOutput(out, block_start_len, remaining);
        return;
    }

    const repeat_start = out.items.len - match_offset;
    appendMatchFromOutput(out, repeat_start, match_len);
}

fn appendMatchFromOutput(out: *std.ArrayList(u8), repeat_start: usize, match_len: usize) void {
    const initial_available = out.items.len - repeat_start;
    _ = out.addManyAsSliceAssumeCapacity(match_len);

    // LZ4 matches may overlap the destination. Instead of appending one byte at
    // a time for short periods (offset=1 run-length encodings are common), seed
    // at most one already-decoded period and then repeatedly copy from the
    // bytes we just produced. Each individual @memcpy range is non-overlapping,
    // while the copied span doubles, so long runs take O(log n) memcpy calls.
    const destination_start = out.items.len - match_len;
    var copied: usize = 0;
    while (copied < match_len) {
        const available = if (copied == 0) initial_available else copied;
        const copy_len = @min(available, match_len - copied);
        const source_start = if (copied == 0) repeat_start else destination_start;
        @memcpy(
            out.items[destination_start + copied ..][0..copy_len],
            out.items[source_start..][0..copy_len],
        );
        copied += copy_len;
    }
}

fn encodeBlockInto(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) Error!usize {
    const out_start = out.items.len;
    if (input.len == 0) return 0;
    if (table.len < hash_table_len or
        occupancy_bits.len < hash_occupancy_words or
        chain_table.len < chain_table_len or
        input.len > std.math.maxInt(u32))
    {
        return error.IntegerOverflow;
    }
    // Only clear a small occupancy bitset per block. The position table is
    // intentionally left uninitialized/reused; entries are read only when their
    // occupancy bit is set. The chain table is also initialized lazily because
    // candidates outside LZ4's 64 KiB window are never followed.
    @memset(occupancy_bits[0..hash_occupancy_words], 0);
    try out.ensureUnusedCapacity(allocator, try maxCompressedLen(input.len));

    var anchor: usize = 0;
    var index: usize = 0;
    while (index + 12 <= input.len) {
        var match_index = index;
        var best = insertAndFindBest(input, index, table, occupancy_bits, chain_table);
        if (best.len != 0 and index + 13 <= input.len and best.len < good_match_len) {
            const next = insertAndFindBest(input, index + 1, table, occupancy_bits, chain_table);
            if (next.len > best.len + lazy_extra_gain) {
                match_index = index + 1;
                best = next;
            }
        }

        if (best.len != 0) {
            var match_start = match_index;
            var candidate_start = best.start;
            var match_len = best.len;
            while (match_start > anchor and candidate_start > 0 and input[match_start - 1] == input[candidate_start - 1]) {
                match_start -= 1;
                candidate_start -= 1;
                match_len += 1;
            }
            try emitSequence(allocator, out, input[anchor..match_start], @intCast(match_start - candidate_start), match_len);
            index = match_start + match_len;
            anchor = index;
            if (index >= input.len) break;
            const seed_start = match_start + 1;
            var seed = seed_start;
            while (seed < index and seed + 4 <= input.len) : (seed += 1) {
                _ = insertHash(input, seed, table, occupancy_bits, chain_table);
            }
        } else {
            index += 1;
        }
    }
    try emitLastLiteral(allocator, out, input[anchor..]);
    return out.items.len - out_start;
}

fn insertAndFindBest(
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) Match {
    const candidate_entry = insertHash(input, index, table, occupancy_bits, chain_table);

    var best: Match = .{};
    var candidate = candidate_entry;
    var depth: usize = 0;
    while (candidate != invalid_pos and depth < max_chain_depth) : (depth += 1) {
        const candidate_start: usize = @intCast(candidate);
        if (candidate_start >= index) break;
        if (index - candidate_start > std.math.maxInt(u16)) break;
        if (input[candidate_start] == input[index] and
            input[candidate_start + 1] == input[index + 1] and
            input[candidate_start + 2] == input[index + 2] and
            input[candidate_start + 3] == input[index + 3])
        {
            var match_len: usize = 4;
            while (index + match_len < input.len and input[candidate_start + match_len] == input[index + match_len]) {
                match_len += 1;
            }
            if (match_len > best.len) {
                best = .{ .start = candidate_start, .len = match_len };
                if (match_len >= good_match_len) break;
            }
        }
        candidate = chain_table[candidate_start & chain_table_mask];
    }
    return best;
}

fn insertHash(
    input: []const u8,
    index: usize,
    table: []u32,
    occupancy_bits: []u64,
    chain_table: []u32,
) u32 {
    const h = hash4(input[index..][0..4]);
    const candidate_seen = hashOccupied(occupancy_bits, h);
    const candidate_entry = if (candidate_seen) table[h] else invalid_pos;
    markHashOccupied(occupancy_bits, h);

    // Lazy matching can probe index+1 before knowing whether the current match
    // wins; back-extension and seeding can later revisit the same index. Avoid
    // turning that ring slot into a self-loop that wastes bounded chain depth.
    if (candidate_entry == index) return chain_table[index & chain_table_mask];

    table[h] = @intCast(index);
    chain_table[index & chain_table_mask] = candidate_entry;
    return candidate_entry;
}

fn maxCompressedLen(input_len: usize) Error!usize {
    return try checkedAdd(try checkedAdd(input_len, input_len / 255), 16);
}

fn hashOccupied(occupancy_bits: []const u64, hash: usize) bool {
    const word = hash >> 6;
    const bit: u6 = @intCast(hash & 63);
    return (occupancy_bits[word] & (@as(u64, 1) << bit)) != 0;
}

fn markHashOccupied(occupancy_bits: []u64, hash: usize) void {
    const word = hash >> 6;
    const bit: u6 = @intCast(hash & 63);
    occupancy_bits[word] |= @as(u64, 1) << bit;
}

fn hash4(bytes: *const [4]u8) usize {
    const value = std.mem.readInt(u32, bytes, .little);
    return @intCast((value *% 2654435761) >> 16);
}

fn emitSequence(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8, match_offset: u16, match_len: usize) Error!void {
    const token_index = out.items.len;
    try out.append(allocator, 0);
    var token: u8 = 0;
    if (literal.len < 15) {
        token |= @intCast(literal.len << 4);
    } else {
        token |= 15 << 4;
        try writeLengthExtension(allocator, out, literal.len - 15);
    }
    try out.appendSlice(allocator, literal);
    var offset_bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &offset_bytes, match_offset, .little);
    try out.appendSlice(allocator, &offset_bytes);

    const encoded_match_len = match_len - 4;
    if (encoded_match_len < 15) {
        token |= @intCast(encoded_match_len);
    } else {
        token |= 15;
        try writeLengthExtension(allocator, out, encoded_match_len - 15);
    }
    out.items[token_index] = token;
}

fn emitLastLiteral(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8) Error!void {
    if (literal.len == 0) return;
    const token_index = out.items.len;
    try out.append(allocator, 0);
    if (literal.len < 15) {
        out.items[token_index] = @intCast(literal.len << 4);
    } else {
        out.items[token_index] = 15 << 4;
        try writeLengthExtension(allocator, out, literal.len - 15);
    }
    try out.appendSlice(allocator, literal);
}

fn writeLengthExtension(allocator: std.mem.Allocator, out: *std.ArrayList(u8), extra_len: usize) Error!void {
    var remaining = extra_len;
    while (remaining >= 255) : (remaining -= 255) try out.append(allocator, 255);
    try out.append(allocator, @intCast(remaining));
}

fn readLengthExtension(input: []const u8, offset: *usize) Error!usize {
    var len: usize = 0;
    while (true) {
        if (offset.* >= input.len) return error.TruncatedFrame;
        const byte = input[offset.*];
        offset.* += 1;
        len = try checkedAdd(len, byte);
        if (byte != 255) return len;
    }
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch return error.IntegerOverflow;
}

fn checkedU64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn checkedUsizeToU64(value: usize) Error!u64 {
    return std.math.cast(u64, value) orelse error.IntegerOverflow;
}

test "lz4 lib frame encoder round trips and compresses repetitive payloads" {
    const repeated = "payload payload payload payload payload payload payload payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < repeated.len);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);
}

test "lz4 frame encoder compresses repetitive payloads and round trips" {
    const repeated = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const encoded = try encodePureFrameAlloc(std.testing.allocator, repeated);
    defer std.testing.allocator.free(encoded);
    try std.testing.expect(encoded.len < repeated.len);
    const decoded = try decodeFrameAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, repeated, decoded);
}

test "lz4 decoder handles independent frame and raw overlapping matches" {
    const plain = "hello-lz4-frame";
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.appendSlice(std.testing.allocator, &.{ 0x60, 0x40 });
    try frame.append(std.testing.allocator, descriptorChecksum(frame.items[4..]));
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, @intCast(plain.len)), .little);
    try frame.appendSlice(std.testing.allocator, &block_header);
    try frame.appendSlice(std.testing.allocator, plain);
    try frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });

    const decoded = try decodeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);

    const raw_match = [_]u8{ 0x33, 'a', 'b', 'c', 3, 0 };
    const raw_decoded = try decodeBlockAlloc(std.testing.allocator, &raw_match, 10);
    defer std.testing.allocator.free(raw_decoded);
    try std.testing.expectEqualSlices(u8, "abcabcabca", raw_decoded);

    var long_run: std.ArrayList(u8) = .empty;
    defer long_run.deinit(std.testing.allocator);
    try long_run.appendSlice(std.testing.allocator, &.{ 0x1f, 'a', 1, 0 });
    try long_run.appendNTimes(std.testing.allocator, 255, 15);
    try long_run.append(std.testing.allocator, 251);
    const long_run_decoded = try decodeBlockAlloc(std.testing.allocator, long_run.items, 4096);
    defer std.testing.allocator.free(long_run_decoded);
    for (long_run_decoded) |byte| try std.testing.expectEqual(@as(u8, 'a'), byte);

    const prefix_match = [_]u8{ 0x04, 4, 0 };
    const prefixed = try decodeBlockWithPrefixAlloc(std.testing.allocator, &prefix_match, 8, "abcdefghijklmnop");
    defer std.testing.allocator.free(prefixed);
    try std.testing.expectEqualSlices(u8, "mnopmnop", prefixed);
}

test "lz4 frame decoder rejects size and checksum mismatches" {
    const input = "payload payload payload";
    const encoded = try encodeFrameAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(encoded);

    var bad_size = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_size);
    std.mem.writeInt(u64, bad_size[6..][0..8], input.len + 1, .little);
    try std.testing.expectError(error.ChecksumMismatch, decodeFrameAlloc(std.testing.allocator, bad_size));

    var bad_checksum = try std.testing.allocator.dupe(u8, encoded);
    defer std.testing.allocator.free(bad_checksum);
    bad_checksum[bad_checksum.len - 1] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeFrameAlloc(std.testing.allocator, bad_checksum));
}

test "lz4 native frame decoder validates header, block checksum, and block size" {
    const plain = "hello-lz4-native-block";
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(std.testing.allocator);
    try frame.appendSlice(std.testing.allocator, &frame_magic);
    try frame.appendSlice(std.testing.allocator, &.{ 0x70, 0x40 }); // independent blocks + block checksum, 64 KiB max
    try frame.append(std.testing.allocator, descriptorChecksum(frame.items[4..]));
    var block_header: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_header, 0x8000_0000 | @as(u32, @intCast(plain.len)), .little);
    try frame.appendSlice(std.testing.allocator, &block_header);
    try frame.appendSlice(std.testing.allocator, plain);
    var block_checksum: [4]u8 = undefined;
    std.mem.writeInt(u32, &block_checksum, std.hash.XxHash32.hash(0, plain), .little);
    try frame.appendSlice(std.testing.allocator, &block_checksum);
    try frame.appendSlice(std.testing.allocator, &.{ 0, 0, 0, 0 });

    const decoded = try decodeNativeFrameAlloc(std.testing.allocator, frame.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, plain, decoded);

    var bad_header = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(bad_header);
    bad_header[4] ^= 0x08;
    try std.testing.expectError(error.ChecksumMismatch, decodeNativeFrameAlloc(std.testing.allocator, bad_header));

    var bad_block_checksum = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(bad_block_checksum);
    bad_block_checksum[bad_block_checksum.len - 5] ^= 0x01;
    try std.testing.expectError(error.ChecksumMismatch, decodeNativeFrameAlloc(std.testing.allocator, bad_block_checksum));

    var bad_block_size = try std.testing.allocator.dupe(u8, frame.items);
    defer std.testing.allocator.free(bad_block_size);
    std.mem.writeInt(u32, bad_block_size[7..][0..4], 0x8000_0000 | (64 * 1024 + 1), .little);
    try std.testing.expectError(error.CorruptFrame, decodeNativeFrameAlloc(std.testing.allocator, bad_block_size));
}
