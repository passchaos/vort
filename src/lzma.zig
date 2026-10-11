const decoder = @import("lzma/decoder.zig");
const writer = @import("lzma/writer.zig");

pub const Error = decoder.Error || writer.Error;
pub const Header = decoder.Header;
pub const DecodeOptions = decoder.DecodeOptions;
pub const MicroDecodeOptions = decoder.MicroDecodeOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const Properties = writer.Properties;
pub const EncodeMode = writer.Mode;
pub const SizeMode = writer.SizeMode;
pub const parseHeader = decoder.parseHeader;
pub const decodeInto = decoder.decodeInto;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodeAllocWithOptions = decoder.decodeAllocWithOptions;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const decodeMicroInto = decoder.decodeMicroInto;
pub const decodeMicroAllocExactSize = decoder.decodeMicroAllocExactSize;
pub const decodeMicroAllocLimited = decoder.decodeMicroAllocLimited;
pub const decodeMicroAllocWithOptions = decoder.decodeMicroAllocWithOptions;
pub const decodeZipPayloadInto = decoder.decodeZipPayloadInto;
pub const decodeZipPayloadAllocLimited = decoder.decodeZipPayloadAllocLimited;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

test {
    _ = decoder;
    _ = writer;
}

test "LZMA decoder safely wraps output larger than its dictionary" {
    const std = @import("std");
    const input = "small dictionary repeated payload\n" ** 512;
    inline for (.{ SizeMode.known, SizeMode.end_marker }) |size_mode| {
        const encoded = try encodeAlloc(std.testing.allocator, input, .{
            .dictionary_size = 4096,
            .size_mode = size_mode,
        });
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);

        if (size_mode == .known) {
            const corrupt = try std.testing.allocator.dupe(u8, encoded);
            defer std.testing.allocator.free(corrupt);
            std.mem.writeInt(u64, corrupt[5..13], input.len - 1, .little);
            try std.testing.expectError(
                error.SizeMismatch,
                decodeAlloc(std.testing.allocator, corrupt),
            );
        }
    }
}
