const std = @import("std");

const compint = @import("zchunk/compint.zig");
const hash = @import("zchunk/hash.zig");
const container = @import("zchunk/container.zig");
const writer = @import("zchunk/writer.zig");

pub const Error = container.Error || compint.Error || hash.Error || std.mem.Allocator.Error;

pub const Archive = container.Archive;
pub const Compression = container.Compression;
pub const Entry = container.Entry;
pub const EntryIterator = container.EntryIterator;
pub const Flags = container.Flags;
pub const HashKind = hash.Kind;
pub const Options = writer.Options;
pub const parse = container.parse;
pub const parseHeader = container.parseHeader;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const decodeAllocLimited = container.decodeAllocLimited;
pub const decodeStreamAllocLimited = container.decodeStreamAllocLimited;
pub const decodeChunkAllocLimited = container.decodeChunkAllocLimited;

test {
    _ = compint;
    _ = hash;
    _ = container;
    _ = writer;
}
