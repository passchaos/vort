const container = @import("lzip/container.zig");

pub const Error = container.Error;
pub const Header = container.Header;
pub const MemberInfo = container.MemberInfo;
pub const FileInfo = container.FileInfo;
pub const DecodeOptions = container.DecodeOptions;
pub const parseHeader = container.parseHeader;
pub const inspect = container.inspect;
pub const decodeInto = container.decodeInto;
pub const decodeAlloc = container.decodeAlloc;
pub const decodeAllocLimited = container.decodeAllocLimited;
pub const decodeAllocWithOptions = container.decodeAllocWithOptions;
pub const decodedSize = container.decodedSize;
pub const decodedSizeLimited = container.decodedSizeLimited;
pub const decodedSizeWithOptions = container.decodedSizeWithOptions;

test {
    _ = container;
}
