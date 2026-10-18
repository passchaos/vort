const archive = @import("ar/archive.zig");
const writer = @import("ar/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeEntry = writer.EncodeEntry;
pub const ThinEncodeEntry = writer.ThinEncodeEntry;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeThinAlloc = writer.encodeThinAlloc;
pub const encodeThinAppend = writer.encodeThinAppend;
pub const encodeThinInto = writer.encodeThinInto;
pub const isSafePath = archive.isSafePath;

test {
    _ = archive;
    _ = writer;
    _ = @import("ar/thin_tests.zig");
}
