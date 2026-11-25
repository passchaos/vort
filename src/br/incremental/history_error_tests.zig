const std = @import("std");
const br = @import("../../br.zig");
const core = @import("../../core.zig");
const BitWriter = @import("../encoder/bit_writer.zig").Writer;

fn singleton(writer: *BitWriter, symbol: usize, symbol_bits: u6) !void {
    try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix
    try writer.writeBits(std.testing.allocator, 0, 2); // one symbol
    try writer.writeBits(std.testing.allocator, symbol, symbol_bits);
}

fn pair(writer: *BitWriter, first: usize, second: usize, symbol_bits: u6) !void {
    try writer.writeBits(std.testing.allocator, 1, 2); // simple prefix
    try writer.writeBits(std.testing.allocator, 1, 2); // two symbols
    try writer.writeBits(std.testing.allocator, first, symbol_bits);
    try writer.writeBits(std.testing.allocator, second, symbol_bits);
}

// Every fixture uses real RFC headers and Huffman trees. The first command
// inserts `a`; dictionary fixtures then request an invalid two-byte word or
// overrun a one-byte RAW prefix. The zero-distance fixture first installs
// distance one, then applies short code four (last distance minus one).
fn malformedWire(zero_distance: bool, output_len: usize) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(std.testing.allocator);
    var writer = BitWriter{ .out = &wire };
    const allocator = std.testing.allocator;
    try writer.writeBits(allocator, 0, 1); // WBITS = 16
    try writer.writeBits(allocator, 1, 1); // ISLAST
    try writer.writeBits(allocator, 0, 1); // ISLASTEMPTY = false
    try writer.writeBits(allocator, 0, 2); // MNIBBLES = 4
    try writer.writeBits(allocator, output_len - 1, 16); // MLEN - 1
    try writer.writeBits(allocator, 0, 1); // NBLTYPESL = 1
    try writer.writeBits(allocator, 0, 1); // NBLTYPESI = 1
    try writer.writeBits(allocator, 0, 1); // NBLTYPESD = 1
    try writer.writeBits(allocator, 0, 2); // NPOSTFIX = 0
    try writer.writeBits(allocator, if (zero_distance) 1 else 2, 4); // NDIRECT
    try writer.writeBits(allocator, 0, 2); // literal context mode
    try writer.writeBits(allocator, 0, 1); // NTREESL = 1
    try writer.writeBits(allocator, 0, 1); // NTREESD = 1
    try singleton(&writer, 'a', 8);
    if (zero_distance) {
        try pair(&writer, 136, 128, 10); // insert 1/copy 2; insert 0/copy 2
        try pair(&writer, 16, 4, 7); // distance 1; recent distance minus 1
        try writer.writeBits(allocator, 1, 1); // command 136
        try writer.writeBits(allocator, 1, 1); // distance 1
        try writer.writeBits(allocator, 0, 1); // command 128
        try writer.writeBits(allocator, 0, 1); // short code 4 => distance 0
    } else {
        try singleton(&writer, 136, 10); // insert 1/copy 2
        try singleton(&writer, 17, 7); // direct distance 2
    }
    return wire.toOwnedSlice(allocator);
}

const Failure = struct { input: br.Counter, output: br.Counter };

fn expectFailure(decoder: anytype, wire: []const u8, prefix: []const u8, expected: br.Error, fragmented: bool) !Failure {
    const initial = decoder.snapshot();
    var output: [132]u8 = @splat(0xa5);
    var read: usize = 0;
    var written: usize = 0;
    while (true) {
        const input_end = if (fragmented) @min(wire.len, read + 1) else wire.len;
        const output_end = if (fragmented) written + 2 else output.len - 1;
        const stepped = decoder.step(wire[read..input_end], output[written + 1 .. output_end]) catch |err| {
            try std.testing.expectEqual(expected, err);
            const snap = decoder.snapshot();
            try std.testing.expect(snap.last_step_progress.input_read <= input_end - read);
            try std.testing.expect(snap.last_step_progress.output_written <= output_end - written - 1);
            read += snap.last_step_progress.input_read;
            written += snap.last_step_progress.output_written;
            try std.testing.expectEqual(initial.total_compressed + read, snap.total_compressed);
            try std.testing.expectEqual(initial.total_output + written, snap.total_output);
            try std.testing.expectEqual(@as(?br.Counter, snap.total_compressed), snap.error_input_offset);
            try std.testing.expectEqual(@as(?br.Counter, snap.total_output), snap.error_output_offset);
            try std.testing.expectEqualDeep(snap.last_step_progress, decoder.diagnostics().last_step_progress.?);
            try std.testing.expectEqualSlices(u8, prefix, output[1 .. written + 1]);
            try std.testing.expectEqual(@as(u8, 0xa5), output[0]);
            for (output[written + 1 ..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
            try std.testing.expectError(expected, decoder.step(wire, &output));
            try std.testing.expectEqualDeep(core.Progress{}, decoder.snapshot().last_step_progress);
            try std.testing.expectEqual(snap.total_compressed, decoder.snapshot().total_compressed);
            try std.testing.expectEqual(snap.total_output, decoder.snapshot().total_output);
            try std.testing.expectEqual(snap.error_input_offset, decoder.snapshot().error_input_offset);
            try std.testing.expectEqual(snap.error_output_offset, decoder.snapshot().error_output_offset);
            try std.testing.expectError(expected, decoder.finish());
            try std.testing.expectError(expected, decoder.nextFrame(.{}));
            return .{ .input = snap.total_compressed, .output = snap.total_output };
        };
        try std.testing.expectEqualDeep(stepped.progress, decoder.snapshot().last_step_progress);
        read += stepped.progress.input_read;
        written += stepped.progress.output_written;
        try std.testing.expect(stepped.status != .done);
        try std.testing.expect(stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
    }
}

fn drain(decoder: anytype, wire: []const u8, expected: []const u8) !void {
    var output: [128]u8 = undefined;
    var read: usize = 0;
    var written: usize = 0;
    while (decoder.snapshot().phase != .done) {
        const stepped = try decoder.step(wire[read..@min(wire.len, read + 1)], output[written..@min(expected.len, written + 1)]);
        read += stepped.progress.input_read;
        written += stepped.progress.output_written;
        try std.testing.expect(stepped.status == .done or stepped.progress.input_read != 0 or stepped.progress.output_written != 0);
    }
    try decoder.finish();
    try std.testing.expectEqual(wire.len, read);
    try std.testing.expectEqualSlices(u8, expected, output[0..written]);
}

test "Brotli history errors preserve malformed wire errors with capped and caller history" {
    const valid = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "a");
    defer std.testing.allocator.free(valid);
    for ([_]bool{ false, true }) |zero_distance| {
        const output_len: usize = if (zero_distance) 5 else 3;
        const wire = try malformedWire(zero_distance, output_len);
        defer std.testing.allocator.free(wire);
        const prefix = if (zero_distance) "aaa" else "a";
        for ([_]bool{ false, true }) |compound| {
            if (zero_distance and compound) continue;
            const decode: br.DecodeOptions = .{ .shared_dictionary = if (compound)
                .{ .raw_prefixes = &.{"x"} }
            else
                .{} };
            for ([_]bool{ false, true }) |fragmented| {
                var capped = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = output_len, .max_history_len = 1, .decode = decode });
                defer capped.deinit();
                var full = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = output_len, .decode = decode });
                defer full.deinit();
                var history: [5]u8 = undefined;
                var caller = br.IncrementalCopyStreamDecoder.initWithOptions(history[0..1], .{ .expected_output_len = output_len, .decode = decode });
                const full_failure = try expectFailure(&full, wire, prefix, error.InvalidMatch, fragmented);
                try std.testing.expectEqualDeep(full_failure, try expectFailure(&caller, wire, prefix, error.InvalidMatch, fragmented));
                try std.testing.expectEqualDeep(full_failure, try expectFailure(&capped, wire, prefix, error.InvalidMatch, fragmented));
                try std.testing.expect(capped.history_capped);
                capped.reset();
                caller.reset();
                try std.testing.expectEqual(@as(?br.Counter, null), capped.snapshot().error_input_offset);
                try std.testing.expectEqual(@as(?br.Counter, null), caller.snapshot().error_input_offset);
                try capped.resetWithOptions(.{ .expected_output_len = 1, .max_history_len = 1 });
                caller.resetWithOptions(.{ .expected_output_len = 1 });
                try drain(&capped, valid, "a");
                try drain(&caller, valid, "a");
                try capped.nextFrame(.{ .expected_output_len = output_len, .max_history_len = 1, .decode = decode });
                try caller.nextFrame(.{ .expected_output_len = output_len, .decode = decode });
                _ = try expectFailure(&capped, wire, prefix, error.InvalidMatch, fragmented);
                _ = try expectFailure(&caller, wire, prefix, error.InvalidMatch, fragmented);
            }
        }
    }
}

test "Brotli history errors keep real history exhaustion bounded and reset retry clears its cause" {
    const wire = try br.encodeRepeatedPrefixStreamAlloc(std.testing.allocator, "abcd", 32);
    defer std.testing.allocator.free(wire);
    const malformed = try malformedWire(false, 128);
    defer std.testing.allocator.free(malformed);
    const valid = try br.IncrementalTestSupport.encodeStored(std.testing.allocator, "a");
    defer std.testing.allocator.free(valid);
    // A RAW prefix disables the fast history classifier, covering both
    // production capacity checks with the same valid history reference.
    for ([_]bool{ false, true }) |compound| {
        const decode: br.DecodeOptions = .{ .shared_dictionary = if (compound)
            .{ .raw_prefixes = &.{"x"} }
        else
            .{} };
        for ([_]bool{ false, true }) |fragmented| {
            var capped = br.IncrementalStreamDecoder.initWithOptions(std.testing.allocator, .{ .expected_output_len = 128, .max_history_len = 2, .max_working_memory = 2, .decode = decode });
            defer capped.deinit();
            var history: [4]u8 = undefined;
            var caller = br.IncrementalCopyStreamDecoder.initWithOptions(history[0..2], .{ .expected_output_len = 128, .decode = decode });
            const failure = try expectFailure(&caller, wire, "abcd", error.InvalidMatch, fragmented);
            try std.testing.expectEqualDeep(failure, try expectFailure(&capped, wire, "abcd", error.OutputLimitExceeded, fragmented));
            try std.testing.expect(capped.peakWorkingMemoryBytes() <= 2);
            capped.reset();
            caller.reset();
            _ = try expectFailure(&capped, malformed, "a", error.InvalidMatch, fragmented);
            _ = try expectFailure(&caller, malformed, "a", error.InvalidMatch, fragmented);
            // The next frame grows a retained one-byte ring to two bytes;
            // replacement correctly counts both allocations simultaneously.
            try capped.resetWithOptions(.{ .expected_output_len = 1, .max_history_len = 2, .max_working_memory = 3 });
            caller.resetWithOptions(.{ .expected_output_len = 1 });
            try drain(&capped, valid, "a");
            try drain(&caller, valid, "a");
            try capped.nextFrame(.{ .expected_output_len = 128, .max_history_len = 2, .decode = decode });
            try caller.nextFrame(.{ .expected_output_len = 128, .decode = decode });
            _ = try expectFailure(&capped, malformed, "a", error.InvalidMatch, fragmented);
            _ = try expectFailure(&caller, malformed, "a", error.InvalidMatch, fragmented);
            try capped.resetWithOptions(.{ .expected_output_len = 128, .max_history_len = 4, .max_working_memory = 4, .decode = decode });
            caller = br.IncrementalCopyStreamDecoder.initWithOptions(&history, .{ .expected_output_len = 128, .decode = decode });
            try drain(&capped, wire, "abcd" ** 32);
            try drain(&caller, wire, "abcd" ** 32);
        }
    }
}
