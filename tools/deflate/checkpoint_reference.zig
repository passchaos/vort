//! Independent libz production and Z_BLOCK checkpoint observation.
const std = @import("std");
const ref = @import("incremental_relaxed/reference.zig");
pub const C = ref.C;
pub const Wrapper = ref.Wrapper;

pub const Flush = enum {
    block,
    partial,
    sync_flush,
    full,
    mixed_tail,

    fn code(self: Flush) c_int {
        return switch (self) {
            .block, .mixed_tail => C.Z_BLOCK,
            .partial => C.Z_PARTIAL_FLUSH,
            .sync_flush => C.Z_SYNC_FLUSH,
            .full => C.Z_FULL_FLUSH,
        };
    }
};

pub const Boundary = struct { bits: usize, output: usize };

pub fn encode(a: std.mem.Allocator, wrapper: Wrapper, plain: []const u8, chunk_len: usize, flush: Flush, strategy: c_int) ![]u8 {
    var stream: C.z_stream = std.mem.zeroes(C.z_stream);
    if (C.deflateInit2_(&stream, 6, C.Z_DEFLATED, ref.bits(wrapper), 8, strategy, C.ZLIB_VERSION, @sizeOf(C.z_stream)) != C.Z_OK)
        return error.LibzInit;
    defer _ = C.deflateEnd(&stream);
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(a);
    var offset: usize = 0;
    while (offset < plain.len) {
        const end = @min(offset + chunk_len, plain.len);
        try encodePart(a, &stream, &result, plain[offset..end], flush.code());
        offset = end;
    }
    if (flush == .mixed_tail) {
        for ([_]Flush{ .partial, .sync_flush, .full }) |tail|
            try encodePart(a, &stream, &result, &.{}, tail.code());
    }
    // The final block is empty. The last flush(es) already reached the hard
    // output limit, but the decoder still has block ends and footer to read.
    try encodePart(a, &stream, &result, &.{}, C.Z_FINISH);
    return result.toOwnedSlice(a);
}

fn encodePart(a: std.mem.Allocator, stream: *C.z_stream, result: *std.ArrayList(u8), plain: []const u8, flush: c_int) !void {
    stream.next_in = @constCast(plain.ptr);
    stream.avail_in = @intCast(plain.len);
    while (true) {
        // Libz needs more than six free bytes when beginning a flush marker.
        var scratch: [257]u8 = undefined;
        stream.next_out = &scratch;
        stream.avail_out = scratch.len;
        const status = C.deflate(stream, flush);
        const written = scratch.len - stream.avail_out;
        try result.appendSlice(a, scratch[0..written]);
        if (status == C.Z_STREAM_END and flush == C.Z_FINISH and stream.avail_in == 0) return;
        if (status != C.Z_OK) return error.LibzDeflate;
        if (flush != C.Z_FINISH and stream.avail_in == 0 and stream.avail_out != 0) return;
        if (written == 0) return error.LibzNoProgress;
    }
}

pub const Trace = struct {
    checkpoints: []Boundary,
    final_eob_bits: usize,
};

pub fn boundaries(a: std.mem.Allocator, wrapper: Wrapper, wire: []const u8, plain: []const u8) !Trace {
    var stream: C.z_stream = std.mem.zeroes(C.z_stream);
    if (C.inflateInit2_(&stream, ref.bits(wrapper), C.ZLIB_VERSION, @sizeOf(C.z_stream)) != C.Z_OK)
        return error.LibzInit;
    defer _ = C.inflateEnd(&stream);
    const output = try a.alloc(u8, plain.len + 1);
    defer a.free(output);
    stream.next_in = @constCast(wire.ptr);
    stream.avail_in = @intCast(wire.len);
    stream.next_out = output.ptr;
    stream.avail_out = @intCast(output.len);
    var result: std.ArrayList(Boundary) = .empty;
    errdefer result.deinit(a);
    var wrapper_header_pending = wrapper != .raw;
    var final_eob_bits: ?usize = null;
    while (true) {
        const previous_in = stream.total_in;
        const previous_out = stream.total_out;
        const status = C.inflate(&stream, C.Z_BLOCK);
        if (status == C.Z_STREAM_END) {
            if (wrapper_header_pending or stream.total_in != wire.len or stream.total_out != plain.len or !std.mem.eql(u8, output[0..plain.len], plain))
                return error.LibzPlaintext;
            const end_bits = final_eob_bits orelse return error.LibzMissingFinalBoundary;
            return .{ .checkpoints = try result.toOwnedSlice(a), .final_eob_bits = end_bits };
        }
        if (status != C.Z_OK and status != C.Z_BUF_ERROR) return error.LibzInflate;
        const at_boundary = stream.data_type & 128 != 0;
        if (at_boundary) {
            if (wrapper_header_pending) {
                if (stream.total_out != 0) return error.LibzMissingWrapperHeader;
                wrapper_header_pending = false;
            } else {
                // Z_BLOCK stops after an EOB, possibly partway through the
                // last accepted byte. Keep the final raw end before padding.
                const retained: usize = @intCast(stream.data_type & 63);
                if (retained >= 8) return error.LibzBoundaryAlignment;
                const bits = @as(usize, @intCast(stream.total_in)) * 8 - retained;
                if (final_eob_bits != null or (result.items.len != 0 and bits <= result.items[result.items.len - 1].bits))
                    return error.LibzRepeatedBoundary;
                if (stream.data_type & 64 != 0) {
                    final_eob_bits = bits;
                } else {
                    try result.append(a, .{ .bits = bits, .output = @intCast(stream.total_out) });
                }
            }
        }
        if (!at_boundary and stream.total_in == previous_in and stream.total_out == previous_out)
            return error.LibzNoProgress;
    }
}

pub fn verifyDictionaryAppend(wire: []const u8, dictionary: []const u8, prefix_len: usize, expected: []const u8) !void {
    var stream: C.z_stream = std.mem.zeroes(C.z_stream);
    if (C.inflateInit2_(&stream, ref.bits(.raw), C.ZLIB_VERSION, @sizeOf(C.z_stream)) != C.Z_OK)
        return error.LibzInit;
    defer _ = C.inflateEnd(&stream);
    var output: [16]u8 = undefined;
    stream.next_in = @constCast(wire.ptr);
    stream.avail_in = @intCast(wire.len);
    stream.next_out = &output;
    stream.avail_out = output.len;
    if (C.inflate(&stream, C.Z_BLOCK) != C.Z_OK or stream.data_type & 128 == 0 or stream.total_out != prefix_len)
        return error.LibzMissingDictionaryBoundary;
    if (C.inflateSetDictionary(&stream, dictionary.ptr, @intCast(dictionary.len)) != C.Z_OK)
        return error.LibzDictionary;
    var history: [32 * 1024]u8 = undefined;
    var history_len: c_uint = 0;
    if (C.inflateGetDictionary(&stream, &history, &history_len) != C.Z_OK or
        history_len != prefix_len + dictionary.len or
        !std.mem.eql(u8, history[0..prefix_len], expected[0..prefix_len]) or
        !std.mem.eql(u8, history[prefix_len..history_len], dictionary)) return error.LibzDictionaryHistory;
    if (C.inflate(&stream, C.Z_FINISH) != C.Z_STREAM_END or stream.avail_in != 0 or
        stream.total_out != expected.len or !std.mem.eql(u8, output[0..expected.len], expected)) return error.LibzPlaintext;
}

pub fn verifyRestart(wire: []const u8, byte_offset: usize, bit_offset: u3, history: []const u8, expected: []const u8, output: []u8) !void {
    var stream: C.z_stream = std.mem.zeroes(C.z_stream);
    if (C.inflateInit2_(&stream, ref.bits(.raw), C.ZLIB_VERSION, @sizeOf(C.z_stream)) != C.Z_OK)
        return error.LibzInit;
    defer _ = C.inflateEnd(&stream);
    var next = byte_offset;
    if (bit_offset != 0) {
        if (C.inflatePrime(&stream, 8 - @as(c_int, bit_offset), wire[byte_offset] >> bit_offset) != C.Z_OK)
            return error.LibzPrime;
        next += 1;
    }
    if (history.len != 0 and C.inflateSetDictionary(&stream, history.ptr, @intCast(history.len)) != C.Z_OK)
        return error.LibzDictionary;
    stream.next_in = @constCast(wire[next..].ptr);
    stream.avail_in = @intCast(wire.len - next);
    stream.next_out = output.ptr;
    stream.avail_out = @intCast(output.len);
    if (C.inflate(&stream, C.Z_FINISH) != C.Z_STREAM_END or stream.total_out != expected.len or
        !std.mem.eql(u8, output[0..expected.len], expected)) return error.LibzRestartMismatch;
}
