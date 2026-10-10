const std = @import("std");
const core = @import("../core.zig");
const zstd = @import("../zstd.zig");
const compint = @import("compint.zig");
const container = @import("container.zig");
const hash = @import("hash.zig");

pub const Error = core.Error || zstd.Error || compint.Error || hash.Error ||
    std.mem.Allocator.Error || error{
    InvalidZchunk,
    UnsupportedZchunkHash,
};

pub const Options = struct {
    compression: container.Compression = .zstandard,
    chunk_size: usize = 64 * 1024,
    full_hash_kind: hash.Kind = .sha256,
    chunk_hash_kind: hash.Kind = .sha512_128,
    zstd_options: zstd.FrameOptions = .{},
    uncompressed_source: bool = false,
};

const OwnedEntry = struct {
    digest: [64]u8 = @splat(0),
    uncompressed_digest: [64]u8 = @splat(0),
    compressed_size: usize = 0,
    decoded_size: usize = 0,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: Options,
) Error!usize {
    if (options.chunk_size == 0) return error.InvalidZchunk;
    if (options.full_hash_kind != .sha1 and options.full_hash_kind != .sha256)
        return error.UnsupportedZchunkHash;
    if (options.uncompressed_source and
        (options.chunk_hash_kind == .sha1 or options.chunk_hash_kind == .sha512_128))
        return error.InvalidZchunk;
    const start = output.items.len;
    errdefer output.items.len = start;

    var body: std.ArrayList(u8) = .empty;
    defer body.deinit(allocator);
    var entries: std.ArrayList(OwnedEntry) = .empty;
    defer entries.deinit(allocator);
    try entries.append(allocator, .{}); // Empty dictionary entry is mandatory.

    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const chunk_len = @min(options.chunk_size, input.len - input_offset);
        const chunk = input[input_offset..][0..chunk_len];
        const body_start = body.items.len;
        switch (options.compression) {
            .none => try body.appendSlice(allocator, chunk),
            .zstandard => {
                const encoded = try zstd.encodeFrameWithOptionsAlloc(
                    allocator,
                    chunk,
                    options.zstd_options,
                );
                defer allocator.free(encoded);
                try body.appendSlice(allocator, encoded);
            },
        }
        const payload = body.items[body_start..];
        var entry = OwnedEntry{
            .compressed_size = payload.len,
            .decoded_size = chunk.len,
        };
        var digest_storage: [64]u8 = undefined;
        const digest = hash.digest(options.chunk_hash_kind, payload, &digest_storage);
        @memcpy(entry.digest[0..digest.len], digest);
        if (options.uncompressed_source) {
            var decoded_digest_storage: [64]u8 = undefined;
            const decoded_digest = hash.digest(
                options.chunk_hash_kind,
                chunk,
                &decoded_digest_storage,
            );
            @memcpy(entry.uncompressed_digest[0..decoded_digest.len], decoded_digest);
        }
        try entries.append(allocator, entry);
        input_offset += chunk_len;
    }

    var index: std.ArrayList(u8) = .empty;
    defer index.deinit(allocator);
    try compint.append(allocator, &index, @intFromEnum(options.chunk_hash_kind));
    try compint.append(allocator, &index, entries.items.len);
    const chunk_digest_size = options.chunk_hash_kind.digestSize();
    for (entries.items) |entry| {
        try index.appendSlice(allocator, entry.digest[0..chunk_digest_size]);
        if (options.uncompressed_source)
            try index.appendSlice(
                allocator,
                entry.uncompressed_digest[0..chunk_digest_size],
            );
        try compint.append(allocator, &index, entry.compressed_size);
        try compint.append(allocator, &index, entry.decoded_size);
    }

    var body_digest_storage: [64]u8 = undefined;
    const body_digest = if (options.uncompressed_source)
        body_digest_storage[0..options.full_hash_kind.digestSize()]
    else
        hash.digest(options.full_hash_kind, body.items, &body_digest_storage);
    if (options.uncompressed_source) @memset(body_digest_storage[0..body_digest.len], 0);
    var preface: std.ArrayList(u8) = .empty;
    defer preface.deinit(allocator);
    try preface.appendSlice(allocator, body_digest);
    try compint.append(allocator, &preface, if (options.uncompressed_source) 4 else 0);
    try compint.append(allocator, &preface, @intFromEnum(options.compression));
    try compint.append(allocator, &preface, index.items.len);

    var signatures: std.ArrayList(u8) = .empty;
    defer signatures.deinit(allocator);
    try compint.append(allocator, &signatures, 0);
    const header_body_size = try checkedSum(&.{
        preface.items.len,
        index.items.len,
        signatures.items.len,
    });

    var lead_prefix: std.ArrayList(u8) = .empty;
    defer lead_prefix.deinit(allocator);
    try lead_prefix.appendSlice(allocator, &container.full_magic);
    try compint.append(allocator, &lead_prefix, @intFromEnum(options.full_hash_kind));
    try compint.append(allocator, &lead_prefix, header_body_size);
    var header_digest_storage: [64]u8 = undefined;
    const header_digest = hash.digestSlices(
        options.full_hash_kind,
        &.{ lead_prefix.items, preface.items, index.items, signatures.items },
        &header_digest_storage,
    );

    try output.appendSlice(allocator, lead_prefix.items);
    try output.appendSlice(allocator, header_digest);
    try output.appendSlice(allocator, preface.items);
    try output.appendSlice(allocator, index.items);
    try output.appendSlice(allocator, signatures.items);
    try output.appendSlice(allocator, body.items);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Options,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn checkedSum(values: []const usize) Error!usize {
    var total: usize = 0;
    for (values) |value|
        total = std.math.add(usize, total, value) catch return error.IntegerOverflow;
    return total;
}

test "zchunk deterministic writer round trips Zstd and uncompressed chunks" {
    const allocator = std.testing.allocator;
    const empty = try encodeAlloc(allocator, "", .{});
    defer allocator.free(empty);
    const empty_archive = try container.parseHeader(empty);
    try std.testing.expect(empty_archive.body_present);
    try std.testing.expectEqual(@as(usize, 1), empty_archive.entry_count);

    const input = "zchunk independent deterministic payload\n" ** 4096;
    inline for (.{ container.Compression.zstandard, .none }) |compression| {
        const encoded = try encodeAlloc(allocator, input, .{
            .compression = compression,
            .chunk_size = 4096,
        });
        defer allocator.free(encoded);
        const repeated = try encodeAlloc(allocator, input, .{
            .compression = compression,
            .chunk_size = 4096,
        });
        defer allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, encoded, repeated);
        const archive = try container.parse(encoded);
        try std.testing.expectEqual(compression, archive.compression);
        try std.testing.expect(archive.entry_count > 2);
        const decoded = try container.decodeAllocLimited(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }

    const source_hashes = try encodeAlloc(allocator, input, .{
        .compression = .none,
        .chunk_size = 4096,
        .chunk_hash_kind = .sha256,
        .uncompressed_source = true,
    });
    defer allocator.free(source_hashes);
    const source_archive = try container.parse(source_hashes);
    try std.testing.expect(source_archive.flags.uncompressed_source);
    const source_entry = try source_archive.entryAt(1);
    try std.testing.expect(!source_entry.stored);
    const source_decoded = try container.decodeAllocLimited(
        allocator,
        source_hashes,
        input.len,
    );
    defer allocator.free(source_decoded);
    try std.testing.expectEqualSlices(u8, input, source_decoded);
}

test "zchunk writer supports every specified hash kind" {
    const allocator = std.testing.allocator;
    const input = "zchunk hash coverage" ** 32;
    inline for (.{ hash.Kind.sha1, .sha256, .sha512, .sha512_128 }) |chunk_hash_kind| {
        const encoded = try encodeAlloc(allocator, input, .{
            .compression = .none,
            .chunk_size = 97,
            .full_hash_kind = if (chunk_hash_kind == .sha1) .sha1 else .sha256,
            .chunk_hash_kind = chunk_hash_kind,
        });
        defer allocator.free(encoded);
        const archive = try container.parse(encoded);
        try std.testing.expectEqual(chunk_hash_kind, archive.chunk_hash_kind);
        const decoded = try container.decodeAllocLimited(allocator, encoded, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    try std.testing.expectError(
        error.InvalidZchunk,
        encodeAlloc(allocator, input, .{
            .chunk_hash_kind = .sha1,
            .uncompressed_source = true,
        }),
    );
}
