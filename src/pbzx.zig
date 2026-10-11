const format = @import("pbzx/format.zig");
const container = @import("pbzx/container.zig");
const writer = @import("pbzx/writer.zig");

pub const Error = format.Error || container.Error || writer.Error;
pub const Chunk = format.Chunk;
pub const Archive = container.Archive;
pub const Iterator = container.Iterator;
pub const ParseOptions = container.ParseOptions;
pub const Compression = writer.Compression;
pub const EncodeOptions = writer.EncodeOptions;
pub const magic = format.magic;
pub const parse = container.Archive.init;
pub const parseWithOptions = container.Archive.initWithOptions;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

test {
    _ = format;
    _ = container;
    _ = writer;
    _ = @import("pbzx/test.zig");
}
