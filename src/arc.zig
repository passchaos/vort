const archive = @import("arc/archive.zig");
const crushed = @import("arc/crushed.zig");
const distilled = @import("arc/distilled.zig");
const lzw = @import("arc/lzw.zig");
const old_crunch = @import("arc/old_crunch.zig");
const rle = @import("arc/rle.zig");
const squeeze = @import("arc/squeeze.zig");
const writer = @import("arc/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const Method = archive.Method;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const EncodeEntry = writer.EncodeEntry;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const crc16 = archive.crc16;

pub const decodeCrushedInto = crushed.decodeInto;
pub const encodeCrushedAlloc = crushed.encodeAlloc;
pub const encodeCrushedAppend = crushed.encodeAppend;
pub const decodeDistilledInto = distilled.decodeInto;
pub const encodeDistilledAlloc = distilled.encodeAlloc;
pub const encodeDistilledAppend = distilled.encodeAppend;

pub const decodeRleInto = rle.decodeInto;
pub const encodeRleAlloc = rle.encodeAlloc;
pub const encodeRleAppend = rle.encodeAppend;

pub const decodeSqueezeInto = squeeze.decodeInto;
pub const encodeSqueezeAlloc = squeeze.encodeAlloc;
pub const encodeSqueezeAppend = squeeze.encodeAppend;

pub const LzwMode = lzw.Mode;
pub const decodeLzwInto = lzw.decodeInto;
pub const encodeLzwAlloc = lzw.encodeAlloc;
pub const encodeLzwAppend = lzw.encodeAppend;

test {
    _ = archive;
    _ = crushed;
    _ = distilled;
    _ = lzw;
    _ = old_crunch;
    _ = rle;
    _ = squeeze;
    _ = writer;
}
