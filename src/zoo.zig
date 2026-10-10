const archive = @import("zoo/archive.zig");
const lzd = @import("zoo/lzd.zig");
const writer = @import("zoo/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const Method = archive.Method;
pub const Name = archive.Name;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeEntry = writer.EncodeEntry;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;

pub const decodeLzdInto = lzd.decodeInto;
pub const decodeLzdAlloc = lzd.decodeAlloc;
pub const decodeLzdAllocLimited = lzd.decodeAllocLimited;
pub const encodeLzdAlloc = lzd.encodeAlloc;
pub const encodeLzdAppend = lzd.encodeAppend;
pub const encodeLzdInto = lzd.encodeInto;

test {
    _ = archive;
    _ = lzd;
    _ = writer;
}
