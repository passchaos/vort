const std = @import("std");

pub const lzvn = @import("lzfse/lzvn.zig");
const fse = @import("lzfse/fse.zig");
const format = @import("lzfse/format.zig");
const decoder = @import("lzfse/decoder.zig");
const container = @import("lzfse/container.zig");

pub const Error = container.Error || std.mem.Allocator.Error;

pub const Archive = container.Archive;
pub const Block = container.Block;
pub const BlockIterator = container.BlockIterator;
pub const BlockKind = container.BlockKind;
pub const Options = container.Options;

pub const parse = container.parse;
pub const parseLimited = container.parseLimited;
pub const parseBlock = container.parseBlock;
pub const encodeAlloc = container.encodeAlloc;
pub const encodeAppend = container.encodeAppend;
pub const encodeInto = container.encodeInto;
pub const decodeAlloc = container.decodeAlloc;
pub const decodeAllocLimited = container.decodeAllocLimited;
pub const decodeInto = container.decodeInto;

pub const decodedLzvnSize = lzvn.decodedSize;
pub const decodedLzvnSizeLimited = lzvn.decodedSizeLimited;
pub const decodedLzvnSizeWithPrefixLimited = lzvn.decodedSizeWithPrefixLimited;
pub const encodeLzvnAlloc = lzvn.encodeAlloc;
pub const encodeLzvnAppend = lzvn.encodeAppend;
pub const encodeLzvnInto = lzvn.encodeInto;
pub const decodeLzvnAlloc = lzvn.decodeAlloc;
pub const decodeLzvnAllocLimited = lzvn.decodeAllocLimited;
pub const decodeLzvnInto = lzvn.decodeInto;
pub const decodeLzvnIntoWithPrefix = lzvn.decodeIntoWithPrefix;

test {
    _ = lzvn;
    _ = fse;
    _ = format;
    _ = decoder;
    _ = container;
}
