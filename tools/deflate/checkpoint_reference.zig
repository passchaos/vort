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

pub fn boundaries(a: std.mem.Allocator, wrapper: Wrapper, wire: []const u8, plain: []const u8) ![]Boundary {
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
    while (true) {
        const previous_in = stream.total_in;
        const previous_out = stream.total_out;
        const status = C.inflate(&stream, C.Z_BLOCK);
        if (status == C.Z_STREAM_END) {
            if (wrapper_header_pending or stream.total_in != wire.len or stream.total_out != plain.len or !std.mem.eql(u8, output[0..plain.len], plain))
                return error.LibzPlaintext;
            return result.toOwnedSlice(a);
        }
        if (status != C.Z_OK and status != C.Z_BUF_ERROR) return error.LibzInflate;
        const at_boundary = stream.data_type & 128 != 0;
        if (at_boundary) {
            if (wrapper_header_pending) {
                if (stream.total_out != 0) return error.LibzMissingWrapperHeader;
                wrapper_header_pending = false;
            } else if (stream.data_type & 64 == 0) {
                // Z_BLOCK stops after a nonfinal EOB, possibly partway through
                // the last accepted byte. Compare logical input positions.
                const retained: usize = @intCast(stream.data_type & 63);
                if (retained >= 8) return error.LibzBoundaryAlignment;
                const bits = @as(usize, @intCast(stream.total_in)) * 8 - retained;
                if (result.items.len != 0 and bits <= result.items[result.items.len - 1].bits)
                    return error.LibzRepeatedBoundary;
                try result.append(a, .{ .bits = bits, .output = @intCast(stream.total_out) });
            }
        }
        if (!at_boundary and stream.total_in == previous_in and stream.total_out == previous_out)
            return error.LibzNoProgress;
    }
}
