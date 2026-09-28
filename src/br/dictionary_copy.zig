const std = @import("std");

/// Append a materialized Brotli dictionary word without a dynamic-length
/// memcpy for the short transform results produced by the RFC dictionary.
pub inline fn append(output: []u8, written: *usize, word: []const u8) void {
    const destination = written.*;
    std.debug.assert(word.len <= output.len - destination);
    written.* += word.len;

    if (word.len < 4 or word.len >= 32) {
        @memcpy(output[destination..][0..word.len], word);
        return;
    }
    if (word.len < 8) {
        const first = word[0..4].*;
        const last = word[word.len - 4 ..][0..4].*;
        output[destination..][0..4].* = first;
        output[destination + word.len - 4 ..][0..4].* = last;
        return;
    }
    if (word.len < 16) {
        const first = word[0..8].*;
        const last = word[word.len - 8 ..][0..8].*;
        output[destination..][0..8].* = first;
        output[destination + word.len - 8 ..][0..8].* = last;
        return;
    }
    const first: @Vector(16, u8) = word[0..16].*;
    const last: @Vector(16, u8) = word[word.len - 16 ..][0..16].*;
    output[destination..][0..16].* = first;
    output[destination + word.len - 16 ..][0..16].* = last;
}

test "Brotli dictionary copy preserves every short length and output suffix" {
    var source: [64]u8 = undefined;
    for (&source, 0..) |*byte, index| byte.* = @intCast(index);
    for (0..65) |len| {
        var output: [80]u8 = @splat(0xa5);
        var written: usize = 7;
        append(&output, &written, source[0..len]);
        try std.testing.expectEqual(@as(usize, 7 + len), written);
        try std.testing.expectEqualSlices(u8, source[0..len], output[7..written]);
        for (output[written..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    }
}
