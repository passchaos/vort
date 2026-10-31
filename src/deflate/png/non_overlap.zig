const builtin = @import("builtin");
const std = @import("std");

/// Keep the deep-distance PNG policy and specialized semantic loop outside
/// ordinary DEFLATE text. Active/control binaries can then remain comparable
/// without moving the generic loop or unrelated PNG paths.
pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_png_non_overlap",
    .macho => "__TEXT,__vort_png_nonov",
    .coff => ".text$vort_png_non_overlap",
    else => ".text",
};

/// Select the measured Kodak-style table shape: a primary-coverable literal
/// tree paired with a deep distance tree dominated by short non-overlap
/// matches. Fifteen-bit literal trees such as the Fantasy fixture retain the
/// ordinary window loop, where this specialization is a measured regression.
/// The 14-bit branch layout was selected on x86-64. Other architectures keep
/// the specialization only for shorter primary-coverable literal trees until
/// equivalent target-local evidence justifies widening the policy.
pub noinline fn shouldUse(
    literal_max_bits: u4,
    distance_max_bits: u4,
) linksection(text_section) u32 {
    if (comptime builtin.cpu.arch == .aarch64 or
        builtin.cpu.arch == .aarch64_be)
    {
        return asm volatile (
            \\and w8, %[distance:w], #0xf
            \\mov w9, #14
            \\bics wzr, w9, %[literal:w]
            \\ccmp w8, #11, #0, ne
            \\cset %[result:w], hi
            : [result] "={x0}" (-> u32),
            : [literal] "{x0}" (literal_max_bits),
              [distance] "{x1}" (distance_max_bits),
            : .{ .nzcv = true, .x8 = true, .x9 = true });
    }

    const literal_mask: u32 = if (builtin.cpu.arch == .x86_64) 0xf else 0xe;
    return @intFromBool(
        (literal_mask & ~@as(u32, literal_max_bits)) != 0 and
            distance_max_bits >= 12,
    );
}

/// Copy a short non-overlapping match inside the resumable window fast loop.
///
/// That loop retains 258 bytes of destination headroom. Requiring an 8-byte
/// distance makes the fixed source/destination words disjoint and initialized;
/// bytes after the logical match remain speculative until later tokens replace
/// them or the committed write position advances only by `length`.
pub inline fn copyShortWindowMatch(
    output: []u8,
    out_pos: usize,
    length: usize,
    distance: usize,
) bool {
    if (length > 8 or distance < 8) return false;
    std.debug.assert(length != 0);
    std.debug.assert(distance <= out_pos);
    std.debug.assert(output.len - out_pos >= 8);
    const bytes = output[out_pos - distance ..][0..8].*;
    output[out_pos..][0..8].* = bytes;
    return true;
}

test "deep-distance PNG non-overlap policy has an exact threshold" {
    try std.testing.expectEqual(@as(u32, 0), shouldUse(13, 11));
    try std.testing.expectEqual(@as(u32, 1), shouldUse(13, 12));
    try std.testing.expectEqual(@as(u32, 1), shouldUse(13, 15));
    try std.testing.expectEqual(@as(u32, 0), shouldUse(15, 12));
    try std.testing.expectEqual(@as(u32, 0), shouldUse(15, 15));
    try std.testing.expectEqual(
        @as(u32, @intFromBool(builtin.cpu.arch == .x86_64)),
        shouldUse(14, 12),
    );
}

test "short non-overlapping window match matches reference and bounds speculation" {
    var source: [80]u8 = undefined;
    for (&source, 0..) |*byte, i| byte.* = @truncate(i *% 73 +% 19);

    for (1..9) |length| {
        for (8..41) |distance| {
            const out_pos: usize = 40;
            var actual = source;
            var expected = source;
            @memcpy(
                expected[out_pos..][0..length],
                expected[out_pos - distance ..][0..length],
            );
            try std.testing.expect(copyShortWindowMatch(
                &actual,
                out_pos,
                length,
                distance,
            ));
            try std.testing.expectEqualSlices(
                u8,
                expected[0 .. out_pos + length],
                actual[0 .. out_pos + length],
            );
            try std.testing.expectEqualSlices(
                u8,
                expected[0..out_pos],
                actual[0..out_pos],
            );
            try std.testing.expectEqualSlices(
                u8,
                source[out_pos + 8 ..],
                actual[out_pos + 8 ..],
            );
        }
    }

    var unchanged = source;
    try std.testing.expect(!copyShortWindowMatch(&unchanged, 40, 9, 9));
    try std.testing.expect(!copyShortWindowMatch(&unchanged, 40, 8, 7));
    try std.testing.expectEqualSlices(u8, &source, &unchanged);
}
