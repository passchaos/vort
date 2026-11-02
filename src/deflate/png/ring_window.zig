//! Fast contiguous ring laps reuse the semantic window kernel. The boundary
//! retires one checked token, allowing exact-end wrapping without a rebase.
const std = @import("std");
const bitstream = @import("../../bitstream.zig");
const huffman = @import("../../huffman.zig");
const ring = @import("ring_sink.zig");
const Error = @import("../../core.zig").Error;

pub fn decode(comptime API: type, input: []const u8, sink: *ring.RingSemanticSink, options: anytype) Error!void {
    if (sink.ring.scratch.len != ring.ring_len) return error.UnsupportedDeflateFeature;
    const header = try API.header(input, null);
    if (header.uses_dictionary) return error.UnsupportedDeflateFeature;
    var reader = bitstream.BufferedBitReader.init(input[header.data_offset..]);
    while (true) {
        const block = try API.block(&reader);
        switch (block.block_type) {
            0 => {
                reader.alignToByte();
                const len = try reader.readAlignedInt(u16, .little);
                const inverse = try reader.readAlignedInt(u16, .little);
                if (len != ~inverse) return error.StoredLengthMismatch;
                var remaining: usize = len;
                while (remaining != 0) {
                    const limit = sink.ring.writeLimit();
                    const space = limit - sink.ring.write_pos;
                    if (space == 0) {
                        const before = sink.ring.total_consumed;
                        try sink.drainRows(false);
                        if (sink.ring.total_consumed == before) return error.OutputTooSmall;
                        continue;
                    }
                    const count = @min(space, remaining);
                    if (count > sink.expected_virtual_len - sink.ring.total_written) return error.SizeMismatch;
                    try reader.readAlignedBytes(sink.ring.scratch[sink.ring.write_pos..][0..count]);
                    try sink.ring.advanceWrite(count);
                    remaining -= count;
                }
            },
            1 => {
                const literals = try huffman.fixedLiteralTable();
                const distances = try huffman.fixedDistanceTable();
                try decodeCompact(API, &reader, sink, &literals, &distances);
            },
            2 => {
                const parsed = try huffman.parseDynamicLengthsAfterHeader(block.final, &reader);
                const literals = try huffman.HuffmanTable(286).init(parsed.literal_lengths[0..parsed.header.hlit]);
                const distances = try huffman.HuffmanTable(30).init(parsed.distance_lengths[0..parsed.header.hdist]);
                var decoder: API.Decoder = undefined;
                if (API.init(&decoder, &literals, &distances)) {
                    try decodeFast(API, &reader, sink, &decoder);
                } else {
                    try decodeCompact(API, &reader, sink, &literals, &distances);
                }
            },
            else => return error.InvalidDeflateBlockType,
        }
        try sink.drainRows(false);
        if (block.final) break;
    }
    try sink.drainRows(true);
    try sink.finish();
    try API.footer(input, header.data_offset + reader.byteOffset(), if (options.ignore_adler) 0 else sink.adlerDigest(), options);
}

fn decodeFast(comptime API: type, reader: *bitstream.BufferedBitReader, sink: *ring.RingSemanticSink, decoder: *const API.Decoder) Error!void {
    while (true) {
        const start = sink.ring.write_pos;
        const remaining = sink.expected_virtual_len - sink.ring.total_written;
        const limit = @min(sink.ring.writeLimit(), start + @min(remaining, sink.ring.scratch.len - start));
        const step = try API.fast(reader, sink.ring.scratch, start, decoder, limit, sink.ring.total_written - start);
        try sink.ring.advanceWrite(step.output_written - start);
        if (step.status == .end_of_block) return;
        try sink.drainRows(false);
        const tail = try API.tail(reader, sink, decoder);
        if (tail == .end_of_block) return;
        try ensureProgress(sink, tail == .need_output);
    }
}

fn decodeCompact(comptime API: type, reader: *bitstream.BufferedBitReader, sink: *ring.RingSemanticSink, literals: anytype, distances: anytype) Error!void {
    while (true) {
        const tail = try API.compact(reader, sink, literals, distances);
        if (tail == .end_of_block) return;
        try ensureProgress(sink, tail == .need_output);
    }
}

fn ensureProgress(sink: *ring.RingSemanticSink, blocked: bool) Error!void {
    if (!blocked) return;
    const before = sink.ring.total_consumed;
    try sink.drainRows(false);
    if (before == sink.ring.total_consumed) return error.OutputTooSmall;
}

test {
    _ = @import("ring_copy.zig");
    _ = @import("ring_window_tests.zig");
}
