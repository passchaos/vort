const container = @import("lzop/container.zig");
const header = @import("lzop/header.zig");
const writer = @import("lzop/writer.zig");

pub const Error = container.Error || writer.Error;
pub const header_magic = header.magic;
pub const Header = header.Header;
pub const Method = header.Method;
pub const DecodeOptions = container.DecodeOptions;
pub const FileInfo = container.FileInfo;
pub const Checksum = writer.Checksum;
pub const EncodeOptions = writer.EncodeOptions;
pub const parseHeader = header.parse;
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
pub const encodeStoredAlloc = writer.encodeStoredAlloc;
pub const encodeStoredAppend = writer.encodeStoredAppend;
pub const encodeStoredInto = writer.encodeStoredInto;

test {
    _ = container;
    _ = header;
    _ = writer;
}
