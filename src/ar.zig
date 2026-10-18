const archive = @import("ar/archive.zig");
const writer = @import("ar/writer.zig");

pub const Error = archive.Error || writer.Error;
pub const signature = archive.signature;
pub const thin_signature = archive.thin_signature;
pub const header_size = archive.header_size;
pub const Entry = archive.Entry;
pub const Archive = archive.Archive;
pub const Iterator = archive.Iterator;
pub const Symbol = archive.Symbol;
pub const SymbolIterator = archive.SymbolIterator;
pub const SymbolTable = archive.SymbolTable;
pub const SymbolTableFormat = archive.SymbolTableFormat;
pub const EncodeEntry = writer.EncodeEntry;
pub const ThinEncodeEntry = writer.ThinEncodeEntry;
pub const ThinEncodeOptions = writer.ThinEncodeOptions;
pub const ThinSymbolIndexFormat = writer.ThinSymbolIndexFormat;
pub const parse = archive.parse;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeInto = writer.encodeInto;
pub const encodeThinAlloc = writer.encodeThinAlloc;
pub const encodeThinAppend = writer.encodeThinAppend;
pub const encodeThinInto = writer.encodeThinInto;
pub const encodeThinAllocWithOptions = writer.encodeThinAllocWithOptions;
pub const encodeThinAppendWithOptions = writer.encodeThinAppendWithOptions;
pub const encodeThinIntoWithOptions = writer.encodeThinIntoWithOptions;
pub const isSafePath = archive.isSafePath;

test {
    _ = archive;
    _ = @import("ar/symbol_table.zig");
    _ = writer;
    _ = @import("ar/thin_tests.zig");
}
