const decoder = @import("lzma/decoder.zig");
const chunk_encoder = @import("lzma/encoder.zig");
const wide_match = @import("lzma/wide_match.zig");
const incremental_decoder = @import("lzma/incremental_decoder.zig");
const incremental_encoder = @import("lzma/incremental_encoder.zig");
const incremental_encoder_tests = @import("lzma/incremental_encoder_tests.zig");
const incremental_tests = @import("lzma/incremental_tests.zig");
const contracts_tests = @import("lzma/incremental/contracts_tests.zig");
const resource_tests = @import("lzma/incremental/resource_tests.zig");
const writer = @import("lzma/writer.zig");
const micro_writer = @import("lzma/micro_writer.zig");
const encode_options = @import("lzma/encode_options.zig");

pub const Error = decoder.Error || decoder.DecodeWorkspace.Error || writer.Error || micro_writer.Error || incremental_decoder.Decoder.Error || incremental_encoder.Encoder.Error;
pub const Header = decoder.Header;
pub const DecodeOptions = decoder.DecodeOptions;
pub const DecodeWorkspace = decoder.DecodeWorkspace;
pub const DecodeWorkspaceOptions = decoder.DecodeWorkspaceOptions;
pub const MicroDecodeOptions = decoder.MicroDecodeOptions;
pub const MicroEncodeOptions = micro_writer.Options;
pub const MicroDestSizeResult = micro_writer.DestSizeResult;
pub const MicroEncodedPrefix = micro_writer.EncodedPrefix;
pub const EncodeOptions = writer.EncodeOptions;
pub const CompressionPreset = encode_options.Preset;
pub const MatchFinder = encode_options.MatchFinder;
pub const MatchOptions = encode_options.MatchOptions;
pub const EncodeWorkProfile = encode_options.EncodeWorkProfile;
pub const resolvePreset = encode_options.resolvePreset;
pub const ZipEncodeOptions = writer.ZipEncodeOptions;
pub const max_encode_dictionary_size = encode_options.max_dictionary_size;
pub const validateEncodeOptions = writer.validateOptions;
pub const validateZipEncodeOptions = writer.validateZipOptions;
pub const Properties = writer.Properties;
pub const EncodeMode = writer.Mode;
pub const SizeMode = writer.SizeMode;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const IncrementalEncoder = incremental_encoder.Encoder;
pub const parseHeader = decoder.parseHeader;
pub const decodeInto = decoder.decodeInto;
pub const decodeIntoWithOptions = decoder.decodeIntoWithOptions;
pub const decodeAlloc = decoder.decodeAlloc;
pub const decodeAllocLimited = decoder.decodeAllocLimited;
pub const decodeAllocWithOptions = decoder.decodeAllocWithOptions;
pub const decodedSize = decoder.decodedSize;
pub const decodedSizeLimited = decoder.decodedSizeLimited;
pub const decodedSizeWithOptions = decoder.decodedSizeWithOptions;
pub const decodeMicroInto = decoder.decodeMicroInto;
pub const decodeMicroAllocExactSize = decoder.decodeMicroAllocExactSize;
pub const decodeMicroAllocLimited = decoder.decodeMicroAllocLimited;
pub const decodeMicroAllocWithOptions = decoder.decodeMicroAllocWithOptions;
pub const encodeMicroAlloc = micro_writer.encodeAlloc;
pub const encodeMicroAppend = micro_writer.encodeAppend;
pub const encodeMicroInto = micro_writer.encodeInto;
pub const encodeMicroDestSizeAlloc = micro_writer.encodeDestSizeAlloc;
pub const encodeMicroDestSizeInto = micro_writer.encodeDestSizeInto;
pub const encodeMicroAlignedDestSizeAlloc = micro_writer.encodeAlignedDestSizeAlloc;
pub const encodeMicroAlignedDestSizeInto = micro_writer.encodeAlignedDestSizeInto;
pub const decodeZipPayloadInto = decoder.decodeZipPayloadInto;
pub const decodeZipPayloadAllocLimited = decoder.decodeZipPayloadAllocLimited;
pub const decodeChdPayloadAllocExactSize = decoder.decodeChdPayloadAllocExactSize;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeChdPayloadAlloc = writer.encodeChdPayloadAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeZipPayloadAlloc = writer.encodeZipPayloadAlloc;
pub const encodeZipPayloadAppend = writer.encodeZipPayloadAppend;

test {
    _ = @import("lzma/encode_controls_tests.zig");
    _ = @import("lzma/wrapper_presets_tests.zig");
    _ = @import("lzma/parse_oracle_tests.zig");
    _ = @import("lzma/fast_parse_tests.zig");
    _ = @import("lzma/encode_options.zig");
    _ = @import("lzma/match_finder.zig");
    _ = @import("lzma/one_shot/contracts_tests.zig");
    _ = @import("lzma/one_shot/resources_tests.zig");
    _ = contracts_tests;
    _ = resource_tests;
    _ = decoder;
    _ = chunk_encoder;
    _ = wide_match;
    _ = incremental_decoder;
    _ = incremental_encoder;
    _ = incremental_encoder_tests;
    _ = incremental_tests;
    _ = writer;
    _ = @import("lzma/micro_writer_tests.zig");
    _ = @import("lzma/micro_limited_tests.zig");
    _ = @import("lzma/micro_aligned_tests.zig");
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
