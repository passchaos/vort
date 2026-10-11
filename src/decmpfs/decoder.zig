const std = @import("std");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const lzfse = @import("../lzfse.zig");
const format = @import("format.zig");

pub const Error = core.Error || deflate.Error || lzfse.Error || format.Error ||
    std.mem.Allocator.Error || error{InvalidDecmpfs};

pub const Archive = struct {
    header: format.Header,
    resource: ?format.ResourceFork,

    pub fn init(xattr: []const u8, resource_bytes: ?[]const u8) Error!Archive {
        const header = try format.parseHeader(xattr);
        if (header.compression_type.isResource()) {
            const bytes = resource_bytes orelse return error.MissingDecmpfsResourceFork;
            return .{
                .header = header,
                .resource = try format.ResourceFork.init(
                    bytes,
                    header.compression_type,
                    header.uncompressed_size,
                ),
            };
        }
        return .{ .header = header, .resource = null };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const expected_size = std.math.cast(usize, self.header.uncompressed_size) orelse
            return error.IntegerOverflow;
        if (expected_size > max_output_len) return error.OutputLimitExceeded;
        if (self.resource) |resource| {
            const output = try allocator.alloc(u8, expected_size);
            errdefer allocator.free(output);
            try decodeResourceRangeInto(allocator, resource, 0, output);
            return output;
        }
        return decodeInlineAlloc(allocator, self.header, expected_size);
    }

    pub fn decodeRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const expected_size = std.math.cast(usize, self.header.uncompressed_size) orelse
            return error.IntegerOverflow;
        const end = std.math.add(usize, offset, length) catch
            return error.IntegerOverflow;
        if (end > expected_size) return error.RangeOutOfBounds;
        if (length == 0) return allocator.alloc(u8, 0);
        if (self.resource) |resource| {
            const output = try allocator.alloc(u8, length);
            errdefer allocator.free(output);
            try decodeResourceRangeInto(allocator, resource, offset, output);
            return output;
        }
        // Inline codecs have no independently addressable blocks. Their full
        // logical output is temporary working memory, so the caller's limit
        // must cover it as well as the returned range.
        if (expected_size > max_output_len) return error.OutputLimitExceeded;
        const full = try decodeInlineAlloc(allocator, self.header, expected_size);
        defer allocator.free(full);
        return allocator.dupe(u8, full[offset..end]);
    }
};

fn decodeInlineAlloc(
    allocator: std.mem.Allocator,
    header: format.Header,
    expected_size: usize,
) Error![]u8 {
    const payload = header.inline_payload;
    return switch (header.compression_type) {
        .uncompressed_inline => copyExact(allocator, payload, expected_size),
        .raw_inline => blk: {
            if (payload.len == 0 or payload[0] != 0xcc)
                return error.InvalidDecmpfs;
            break :blk copyExact(allocator, payload[1..], expected_size);
        },
        .zlib_inline => if (isZlibStored(payload))
            copyMarked(allocator, payload, expected_size)
        else
            deflate.decodeZlibAllocExactSize(allocator, payload, expected_size),
        .lzvn_inline => if (isLzvnStored(payload))
            copyMarked(allocator, payload, expected_size)
        else blk: {
            const output = try allocator.alloc(u8, expected_size);
            errdefer allocator.free(output);
            _ = try lzfse.decodeLzvnInto(payload, output, expected_size);
            break :blk output;
        },
        .lzfse_inline => decodeLzfseExact(allocator, payload, expected_size),
        .dataless, .raw_resource => error.UnsupportedDecmpfsType,
        .zlib_resource, .lzvn_resource, .lzfse_resource => unreachable,
    };
}

fn decodeResourceRangeInto(
    allocator: std.mem.Allocator,
    resource: format.ResourceFork,
    offset: usize,
    output: []u8,
) Error!void {
    const range_end = std.math.add(usize, offset, output.len) catch
        return error.IntegerOverflow;
    if (range_end > resource.uncompressed_size) return error.RangeOutOfBounds;
    if (output.len == 0) return;
    const first_chunk = offset / format.block_size;
    const last_chunk = (range_end - 1) / format.block_size;
    const scratch = try allocator.alloc(u8, format.block_size);
    defer allocator.free(scratch);
    var copied: usize = 0;
    for (first_chunk..last_chunk + 1) |chunk_index| {
        const chunk = try resource.chunk(chunk_index);
        const decoded = scratch[0..chunk.decoded_size];
        try decodeResourceChunk(allocator, resource.compression_type, chunk.encoded, decoded);
        const chunk_start = chunk_index * format.block_size;
        const chunk_end = chunk_start + chunk.decoded_size;
        const copy_start = @max(offset, chunk_start);
        const copy_end = @min(range_end, chunk_end);
        const copy_len = copy_end - copy_start;
        @memcpy(
            output[copy_start - offset ..][0..copy_len],
            decoded[copy_start - chunk_start ..][0..copy_len],
        );
        copied += copy_len;
    }
    if (copied != output.len) return error.InvalidDecmpfs;
}

fn decodeResourceChunk(
    allocator: std.mem.Allocator,
    compression_type: format.CompressionType,
    input: []const u8,
    output: []u8,
) Error!void {
    switch (compression_type) {
        .zlib_resource => {
            if (isZlibStored(input)) {
                try copyMarkedInto(input, output);
            } else {
                const decoded = try decodeZlibResourceExact(allocator, input, output.len);
                defer allocator.free(decoded);
                @memcpy(output, decoded);
            }
        },
        .lzvn_resource => {
            if (isLzvnStored(input)) {
                try copyMarkedInto(input, output);
            } else {
                _ = try lzfse.decodeLzvnInto(input, output, output.len);
            }
        },
        .lzfse_resource => {
            const decoded = try lzfse.decodeAllocLimited(allocator, input, output.len);
            defer allocator.free(decoded);
            if (decoded.len != output.len) return error.SizeMismatch;
            @memcpy(output, decoded);
        },
        else => return error.UnsupportedDecmpfsType,
    }
}

fn decodeZlibResourceExact(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    return deflate.decodeZlibAllocWithOptionsExactSize(
        allocator,
        input,
        .{ .allow_trailing_data = true },
        expected_size,
    ) catch |err| switch (err) {
        // Some HFS decmpfs resources omit the Adler-32 footer. Only accept
        // that form when a complete raw DEFLATE member consumes every byte
        // after a valid, dictionary-free two-byte zlib header.
        error.TruncatedFrame => decodeZlibResourceWithoutAdler(
            allocator,
            input,
            expected_size,
        ),
        else => err,
    };
}

fn decodeZlibResourceWithoutAdler(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    if (input.len < 2) return error.TruncatedFrame;
    const cmf = input[0];
    const flg = input[1];
    if (cmf & 0x0f != 8 or cmf >> 4 > 7 or
        (@as(u16, cmf) << 8 | flg) % 31 != 0)
        return error.BadZlibHeader;
    if (flg & 0x20 != 0) return error.NeedDictionary;
    const decoded = try deflate.decodeRawAutoAllocPartialLimited(
        allocator,
        input[2..],
        expected_size,
    );
    errdefer decoded.deinit(allocator);
    if (decoded.input_read != input.len - 2) return error.TruncatedFrame;
    if (decoded.bytes.len != expected_size) return error.SizeMismatch;
    return decoded.bytes;
}

fn isZlibStored(payload: []const u8) bool {
    return payload.len != 0 and payload[0] & 0x0f == 0x0f;
}

fn isLzvnStored(payload: []const u8) bool {
    return payload.len != 0 and payload[0] == 0x06;
}

fn copyExact(
    allocator: std.mem.Allocator,
    payload: []const u8,
    expected_size: usize,
) Error![]u8 {
    if (payload.len != expected_size) return error.SizeMismatch;
    return allocator.dupe(u8, payload);
}

fn copyMarked(
    allocator: std.mem.Allocator,
    payload: []const u8,
    expected_size: usize,
) Error![]u8 {
    if (payload.len == 0) return error.InvalidDecmpfs;
    return copyExact(allocator, payload[1..], expected_size);
}

fn copyMarkedInto(input: []const u8, output: []u8) Error!void {
    if (input.len != output.len + 1) return error.SizeMismatch;
    @memcpy(output, input[1..]);
}

fn decodeLzfseExact(
    allocator: std.mem.Allocator,
    input: []const u8,
    expected_size: usize,
) Error![]u8 {
    const decoded = try lzfse.decodeAllocLimited(allocator, input, expected_size);
    errdefer allocator.free(decoded);
    if (decoded.len != expected_size) return error.SizeMismatch;
    return decoded;
}
