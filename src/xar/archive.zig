const std = @import("std");
const bzip2 = @import("../bzip2.zig");
const deflate = @import("../deflate.zig");
const lzma = @import("../lzma.zig");
const xz = @import("../xz.zig");
const format = @import("format.zig");
const xml = @import("xml.zig");

pub const Error = format.Error || xml.Error || bzip2.Error || deflate.Error ||
    lzma.Error || xz.Error || std.mem.Allocator.Error;

pub const ParseOptions = struct {
    max_toc_packed_bytes: usize = 256 * 1024 * 1024,
    max_toc_bytes: usize = 256 * 1024 * 1024,
    max_entries: usize = 1 << 20,
    max_depth: usize = 1024,
    max_entry_decoded_bytes: usize = std.math.maxInt(usize),
    max_lzma_dictionary_bytes: usize = 256 * 1024 * 1024,
    max_xz_dictionary_bytes: usize = 256 * 1024 * 1024,
    verify_toc_checksum: bool = true,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: format.Header,
    toc_xml: []u8,
    entries: []format.Entry,
    heap_offset: usize,
    max_lzma_dictionary_bytes: usize,
    max_xz_dictionary_bytes: usize,

    pub fn parseAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: ParseOptions,
    ) Error!Archive {
        const header = try format.parseHeader(input);
        if (header.toc_packed_size > options.max_toc_packed_bytes or
            header.toc_size > options.max_toc_bytes)
            return error.OutputLimitExceeded;
        const toc_start = header.header_size;
        const toc_end = std.math.add(
            usize,
            toc_start,
            header.toc_packed_size,
        ) catch return error.IntegerOverflow;
        const packed_toc = input[toc_start..toc_end];
        const toc_xml = try deflate.decodeZlibAllocExactSize(
            allocator,
            packed_toc,
            header.toc_size,
        );
        errdefer allocator.free(toc_xml);
        const toc = try xml.parseAlloc(
            allocator,
            toc_xml,
            options.max_entries,
            options.max_depth,
        );
        errdefer toc.deinit(allocator);
        const heap_offset = try header.heapOffset();
        const heap = input[heap_offset..];
        var checksum_start: usize = 0;
        var checksum_end: usize = 0;
        if (header.checksum_algorithm != .none) {
            if (!toc.checksum.defined or
                toc.checksum.algorithm != header.checksum_algorithm or
                toc.checksum.size != header.checksum_algorithm.digestSize())
                return error.InvalidXarToc;
            checksum_start = toc.checksum.offset;
            checksum_end = std.math.add(
                usize,
                toc.checksum.offset,
                toc.checksum.size,
            ) catch return error.IntegerOverflow;
            if (checksum_end > heap.len) return error.TruncatedFrame;
            if (options.verify_toc_checksum) {
                const actual = format.hash(header.checksum_algorithm, packed_toc);
                if (!std.mem.eql(
                    u8,
                    actual.slice(),
                    heap[toc.checksum.offset..checksum_end],
                )) return error.ChecksumMismatch;
            }
        }
        for (toc.entries) |entry| {
            if (entry.data) |data| {
                if (entry.kind == .directory or entry.kind == .symlink)
                    return error.InvalidXarToc;
                if (data.size > options.max_entry_decoded_bytes)
                    return error.OutputLimitExceeded;
                const data_end = std.math.add(
                    usize,
                    data.offset,
                    data.packed_size,
                ) catch return error.IntegerOverflow;
                if (data_end > heap.len) return error.TruncatedFrame;
                if (data.packed_size != 0 and checksum_end > checksum_start and
                    @max(data.offset, checksum_start) < @min(data_end, checksum_end))
                    return error.InvalidXarToc;
                if (data.encoding == .copy and data.size != data.packed_size)
                    return error.SizeMismatch;
            }
        }
        return .{
            .allocator = allocator,
            .bytes = input,
            .header = header,
            .toc_xml = toc_xml,
            .entries = toc.entries,
            .heap_offset = heap_offset,
            .max_lzma_dictionary_bytes = options.max_lzma_dictionary_bytes,
            .max_xz_dictionary_bytes = options.max_xz_dictionary_bytes,
        };
    }

    pub fn deinit(self: *Archive) void {
        for (self.entries) |entry| entry.deinit(self.allocator);
        self.allocator.free(self.entries);
        self.allocator.free(self.toc_xml);
        self.* = undefined;
    }

    pub fn find(self: Archive, path: []const u8) ?usize {
        for (self.entries, 0..) |entry, index|
            if (std.mem.eql(u8, entry.path, path)) return index;
        return null;
    }

    pub fn extractByPathAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_output_len: usize,
    ) Error![]u8 {
        return self.extractAllocLimited(
            allocator,
            self.find(path) orelse return error.RangeOutOfBounds,
            max_output_len,
        );
    }

    pub fn extractAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry_index: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (entry_index >= self.entries.len) return error.RangeOutOfBounds;
        const entry = self.entries[entry_index];
        if (entry.kind != .file)
            return error.UnsupportedXarEntry;
        const data = entry.data orelse {
            return allocator.alloc(u8, 0);
        };
        if (data.size > max_output_len) return error.OutputLimitExceeded;
        const packed_start = std.math.add(usize, self.heap_offset, data.offset) catch
            return error.IntegerOverflow;
        const packed_end = std.math.add(usize, packed_start, data.packed_size) catch
            return error.IntegerOverflow;
        if (packed_end > self.bytes.len) return error.TruncatedFrame;
        const packed_bytes = self.bytes[packed_start..packed_end];
        try verifyDigest(data.archived_checksum, packed_bytes);
        const decoded = switch (data.encoding) {
            .copy => try allocator.dupe(u8, packed_bytes),
            .zlib => try deflate.decodeZlibAllocExactSize(
                allocator,
                packed_bytes,
                data.size,
            ),
            .bzip2 => try bzip2.decodeAllocLimited(
                allocator,
                packed_bytes,
                data.size,
            ),
            .lzma => try lzma.decodeAllocWithOptions(
                allocator,
                packed_bytes,
                .{
                    .max_output_len = data.size,
                    .max_dictionary_size = self.max_lzma_dictionary_bytes,
                },
            ),
            .xz => try xz.decodeAllocWithLimits(
                allocator,
                packed_bytes,
                data.size,
                self.max_xz_dictionary_bytes,
            ),
        };
        errdefer allocator.free(decoded);
        if (decoded.len != data.size) return error.SizeMismatch;
        try verifyDigest(data.extracted_checksum, decoded);
        return decoded;
    }
};

fn verifyDigest(expected: format.Digest, bytes: []const u8) Error!void {
    if (expected.algorithm == .none) return;
    const actual = format.hash(expected.algorithm, bytes);
    if (!std.mem.eql(u8, expected.slice(), actual.slice()))
        return error.ChecksumMismatch;
}
