const archive = @import("rar/archive.zig");
const writer = @import("rar/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const Version = archive.Version;
pub const Method = archive.Method;
pub const Name = archive.Name;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeKind = writer.Kind;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const isSafePath = archive.isSafePath;

test {
    _ = archive;
    _ = writer;
}
