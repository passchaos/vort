const archive = @import("lha/archive.zig");
const lh_new = @import("lha/lh_new.zig");
const writer = @import("lha/writer.zig");

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

pub const LhMethod = lh_new.Method;
pub const decodeLhInto = lh_new.decodeInto;
pub const decodeLhAlloc = lh_new.decodeAlloc;
pub const decodeLhAllocLimited = lh_new.decodeAllocLimited;
pub const encodeLhAlloc = lh_new.encodeAlloc;
pub const encodeLhAppend = lh_new.encodeAppend;
pub const encodeLhInto = lh_new.encodeInto;

test {
    _ = archive;
    _ = lh_new;
    _ = writer;
}
