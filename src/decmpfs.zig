const format = @import("decmpfs/format.zig");
const decoder = @import("decmpfs/decoder.zig");

pub const Error = format.Error || decoder.Error;
pub const CompressionType = format.CompressionType;
pub const Header = format.Header;
pub const ResourceLayout = format.ResourceLayout;
pub const ResourceFork = format.ResourceFork;
pub const ResourceChunk = format.ResourceChunk;
pub const Archive = decoder.Archive;
pub const magic = format.magic;
pub const headerSize = format.header_size;
pub const blockSize = format.block_size;
pub const parseHeader = format.parseHeader;
pub const parse = decoder.Archive.init;

test {
    _ = format;
    _ = decoder;
    _ = @import("decmpfs/test.zig");
}
