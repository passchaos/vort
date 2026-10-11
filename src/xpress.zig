const plain = @import("xpress/plain.zig");
const huffman = @import("xpress/huffman.zig");

pub const Error = plain.Error || huffman.Error;
pub const PlainEncodeOptions = plain.EncodeOptions;
pub const PlainSummary = plain.Summary;
pub const HuffmanEncodeOptions = huffman.EncodeOptions;
pub const HuffmanSummary = huffman.Summary;
pub const huffmanMaxBlockSize = huffman.max_block_size;

pub const plainEncodedBound = plain.encodedBound;
pub const summarizePlain = plain.summarize;
pub const summarizePlainLimited = plain.summarizeLimited;
pub const plainDecodedSize = plain.decodedSize;
pub const plainDecodedSizeLimited = plain.decodedSizeLimited;
pub const decodePlainInto = plain.decodeInto;
pub const decodePlainAlloc = plain.decodeAlloc;
pub const decodePlainAllocLimited = plain.decodeAllocLimited;
pub const encodePlainInto = plain.encodeInto;
pub const encodePlainAppend = plain.encodeAppend;
pub const encodePlainAlloc = plain.encodeAlloc;

pub const huffmanEncodedBound = huffman.encodedBound;
pub const summarizeHuffman = huffman.summarize;
pub const decodeHuffmanInto = huffman.decodeInto;
pub const decodeHuffmanAllocExactSize = huffman.decodeAllocExactSize;
pub const encodeHuffmanInto = huffman.encodeInto;
pub const encodeHuffmanAppend = huffman.encodeAppend;
pub const encodeHuffmanAlloc = huffman.encodeAlloc;

test {
    _ = plain;
    _ = huffman;
}
