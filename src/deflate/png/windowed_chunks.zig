//! A complete PNG transaction over borrowed IDAT spans. Filtered lookback
//! remains contiguous and bounded; compressed input is never concatenated.
const std = @import("std");
const bits = @import("buffered_chunks.zig");
const huffman = @import("../../huffman.zig");
const png = @import("../../png.zig");
const history = @import("windowed_history.zig");
const core = @import("../../core.zig");

pub fn decode(comptime kernels: type, chunks: []const []const u8, scratch: []u8, info: png.PngImageInfo, options: anytype, output: []u8) core.Error!@TypeOf(kernels.result()) {
    const output_len = try png.pngImageOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    var image = try history.ImageState.init(scratch, info, output[0..output_len], !options.ignore_adler);
    for (chunks) |chunk| {
        if (kernels.overlap(chunk, scratch) or kernels.overlap(chunk, image.output))
            return error.UnsupportedDeflateFeature;
    }
    if (kernels.overlap(scratch, image.output)) return error.UnsupportedDeflateFeature;
    const wrapper = try kernels.parse_header(chunks, null);
    var reader = try bits.Reader.initAt(chunks, wrapper.data_offset);
    var final = false;
    while (!final) {
        const header = try kernels.read_header(&reader);
        switch (header.block_type) {
            0 => {
                reader.alignToByte();
                const len = try reader.readAlignedInt(u16, .little);
                if (try reader.readAlignedInt(u16, .little) != ~len) return error.StoredLengthMismatch;
                var remaining: usize = len;
                while (remaining != 0) {
                    const old = image.window.write_pos;
                    const available = image.decodeOutput().len - old;
                    if (available == 0) {
                        if (!try kernels.commit(&image, old, false, false)) return error.OutputTooSmall;
                        continue;
                    }
                    const count = @min(available, remaining);
                    try reader.readAlignedBytes(image.decodeOutput()[old..][0..count]);
                    remaining -= count;
                    const done = remaining == 0;
                    const released = try kernels.commit(&image, old + count, done and header.final, done);
                    if (!done and count == available and !released) return error.OutputTooSmall;
                }
                if (len == 0) _ = try kernels.commit(&image, image.window.write_pos, header.final, true);
                final = header.final;
            },
            1 => {
                const literals = try huffman.fixedLiteralTable();
                const distances = try huffman.fixedDistanceTable();
                const literal_lookup = huffman.FastDecoder(288, 9).init(literals);
                const distance_lookup = huffman.FastDecoder(32, 5).init(distances);
                final = try block(kernels, &reader, &image, header.final, &literal_lookup, &distance_lookup);
            },
            2 => {
                const lengths = try huffman.parseDynamicLengthsAfterHeader(header.final, &reader);
                const literals = try huffman.HuffmanTable(286).init(lengths.literal_lengths[0..lengths.header.hlit]);
                const distances = try huffman.HuffmanTable(30).init(lengths.distance_lengths[0..lengths.header.hdist]);
                const literal_lookup = huffman.FastDecoder(286, 12).init(literals);
                const distance_lookup = huffman.FastDecoder(30, 8).init(distances);
                final = try block(kernels, &reader, &image, header.final, &literal_lookup, &distance_lookup);
            },
            else => return error.InvalidDeflateBlockType,
        }
    }
    try image.finish();
    const footer = reader.byteOffset();
    try kernels.footer(chunks, reader.total_len, footer, if (options.ignore_adler) 0 else image.adlerDigest(), options);
    var result = kernels.result();
    result.rows = image.row_index;
    result.output_written = output_len;
    result.zlib_input_read = footer + 4;
    return result;
}

fn block(comptime kernels: type, reader: *bits.Reader, image: *history.ImageState, final: bool, literals: anytype, distances: anytype) core.Error!bool {
    while (true) {
        const step = try compact(kernels, reader, image.decodeOutput(), image.window.write_pos, literals, distances);
        const done = step.status == .end_of_block;
        const released = try kernels.commit(image, step.output_written, done and final, done);
        if (done) return final;
        if (!released) return error.OutputTooSmall;
    }
}

fn compact(comptime kernels: type, reader: *bits.Reader, output: []u8, initial: usize, literals: anytype, distances: anytype) core.Error!@TypeOf(kernels.step()) {
    var offset = initial;
    while (true) {
        // Only an output tail can reject a complete token. Avoid copying the
        // large chunk cursor on every literal/match in the ordinary loop.
        const tail = output.len - offset < 258;
        var saved: bits.Reader = undefined;
        if (tail) saved = reader.*;
        const symbol = try literals.decodeValue(reader);
        if (symbol < 256) {
            if (offset == output.len) {
                reader.* = saved;
                var step = kernels.step();
                step.output_written = offset;
                return step;
            }
            output[offset] = @truncate(symbol);
            offset += 1;
        } else if (symbol == 256) {
            var step = kernels.step();
            step.output_written = offset;
            step.status = .end_of_block;
            return step;
        } else if (symbol <= 285) {
            const length = try kernels.read_length(symbol, reader);
            const distance = try kernels.read_distance(try distances.decodeValue(reader), reader);
            if (length > output.len - offset) {
                reader.* = saved;
                var step = kernels.step();
                step.output_written = offset;
                return step;
            }
            try kernels.copy_match(output, offset, length, distance);
            offset += length;
        } else return error.InvalidHuffmanCode;
    }
}
