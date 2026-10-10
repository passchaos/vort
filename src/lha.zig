const archive = @import("lha/archive.zig");
const larc = @import("lha/larc.zig");
const lh1 = @import("lha/lh1.zig");
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

pub const LarcMethod = larc.Method;
pub const decodeLarcInto = larc.decodeInto;
pub const decodeLarcAlloc = larc.decodeAlloc;
pub const decodeLarcAllocLimited = larc.decodeAllocLimited;
pub const encodeLarcAlloc = larc.encodeAlloc;
pub const encodeLarcAppend = larc.encodeAppend;
pub const encodeLarcInto = larc.encodeInto;

pub const decodeLh1Into = lh1.decodeInto;
pub const decodeLh1Alloc = lh1.decodeAlloc;
pub const decodeLh1AllocLimited = lh1.decodeAllocLimited;
pub const encodeLh1Alloc = lh1.encodeAlloc;
pub const encodeLh1Append = lh1.encodeAppend;
pub const encodeLh1Into = lh1.encodeInto;

test {
    _ = archive;
    _ = larc;
    _ = lh1;
    _ = lh_new;
    _ = writer;
}
