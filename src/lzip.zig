const container = @import("lzip/container.zig");
const incremental_decoder = @import("lzip/incremental_decoder.zig");
const incremental_encoder = @import("lzip/incremental_encoder.zig");
const incremental_encoder_tests = @import("lzip/incremental_encoder_tests.zig");
const incremental_tests = @import("lzip/incremental_tests.zig");
const writer = @import("lzip/writer.zig");

pub const Error = container.Error || writer.Error || incremental_decoder.Decoder.Error || incremental_encoder.Encoder.Error;
pub const Header = container.Header;
pub const MemberInfo = container.MemberInfo;
pub const FileInfo = container.FileInfo;
pub const DecodeOptions = container.DecodeOptions;
pub const EncodeOptions = writer.EncodeOptions;
pub const EncodeMember = writer.EncodeMember;
pub const EncodeMode = writer.Mode;
pub const IncrementalDecoder = incremental_decoder.Decoder;
pub const IncrementalEncoder = incremental_encoder.Encoder;
pub const parseHeader = container.parseHeader;
pub const inspect = container.inspect;
pub const decodeInto = container.decodeInto;
pub const decodeAlloc = container.decodeAlloc;
pub const decodeAllocLimited = container.decodeAllocLimited;
pub const decodeAllocWithOptions = container.decodeAllocWithOptions;
pub const decodedSize = container.decodedSize;
pub const decodedSizeLimited = container.decodedSizeLimited;
pub const decodedSizeWithOptions = container.decodedSizeWithOptions;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeMembersAlloc = writer.encodeMembersAlloc;
pub const encodeMembersAppend = writer.encodeMembersAppend;
pub const encodeMembersInto = writer.encodeMembersInto;

test {
    _ = container;
    _ = incremental_decoder;
    _ = incremental_encoder;
    _ = incremental_encoder_tests;
    _ = incremental_tests;
    _ = writer;
}
