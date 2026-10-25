//! Exact size pricing for one sequence with RLE or predefined tables.
//! The caller supplies the canonical classifiers and comptime table masks;
//! no FSE state planning, transition fields, or allocation is required.
const std = @import("std");

pub const Contract = struct {
    literal_initial_bits: u8 = 6,
    offset_initial_bits: u8 = 5,
    match_initial_bits: u8 = 6,
    offset_min_additional_bits: u8 = 2,
    literal_extra_bits_max: u8 = 16,
    offset_extra_bits_max: u8 = 31,
    match_extra_bits_max: u8 = 16,
};

/// Rules provides Error, contract, literalCode/offsetCode/matchCode, and the
/// literal/offset/match _bits and _masks tables. Classifiers must reject values
/// outside their canonical code ranges. Masks must contain exactly the states
/// matching each canonical base and additional width; offset masks exclude
/// states with fewer than two additional bits. These tables remain comptime
/// constants, and initial-state widths are distinct from transition widths.
pub fn Calculator(comptime Rules: type) type {
    comptime validateContract(Rules);
    return struct {
        pub const Error = Rules.Error;

        const Codes = struct { literal: u8, offset: u8, match: u8 };

        pub fn rlePayloadLen(prefix_len: usize, offset: usize, match_len: usize, section_len: usize) Error!usize {
            const codes = try classify(prefix_len, offset, match_len);
            return addSection(section_len, rleBase(extraBits(codes)));
        }

        pub fn predefinedPayloadLen(prefix_len: usize, offset: usize, match_len: usize, section_len: usize) Error!usize {
            // The generic planner tests LL, then OF, then ML availability,
            // mapping classification failures to an unavailable table mode.
            const literal = checkedCode(prefix_len, Rules.literalCode, Rules.literal_bits) catch return error.CorruptFrame;
            if (Rules.literal_masks[literal] == 0) return error.CorruptFrame;
            const offset_code = checkedCode(offset, Rules.offsetCode, Rules.offset_bits) catch return error.CorruptFrame;
            if (Rules.offset_masks[offset_code] == 0) return error.CorruptFrame;
            const match = checkedCode(match_len, Rules.matchCode, Rules.match_bits) catch return error.CorruptFrame;
            if (Rules.match_masks[match] == 0) return error.CorruptFrame;

            const bits = extraBits(.{ .literal = literal, .offset = offset_code, .match = match });
            return addSection(section_len, predefinedBase(bits));
        }

        /// Preserve the old RLE-first result, including overflow before a
        /// smaller predefined cost is considered. Each value is classified
        /// once. A classification failure also makes predefined unavailable,
        /// so the final error is the original RLE classification error.
        pub fn baseLen(prefix_len: usize, offset: usize, match_len: usize, section_len: usize) Error!usize {
            const codes = try classify(prefix_len, offset, match_len);
            const bits = extraBits(codes);
            const rle_len = try addSection(section_len, rleBase(bits));
            const predefined_available = Rules.literal_masks[codes.literal] != 0 and
                Rules.offset_masks[codes.offset] != 0 and Rules.match_masks[codes.match] != 0;

            if (!predefined_available) return rle_len;
            // For E=8q+r, RLE is 6+q. Predefined is 5+q for r<7,
            // or 6+q for r=7. It cannot overflow after RLE succeeds,
            // but keep the original checked-add and strict-compare order.
            const predefined_len = try addSection(section_len, predefinedBase(bits));
            return if (predefined_len < rle_len) predefined_len else rle_len;
        }

        fn classify(prefix_len: usize, offset: usize, match_len: usize) Error!Codes {
            const literal = try checkedCode(prefix_len, Rules.literalCode, Rules.literal_bits);
            const offset_code = try checkedCode(offset, Rules.offsetCode, Rules.offset_bits);
            const match = try checkedCode(match_len, Rules.matchCode, Rules.match_bits);
            return .{ .literal = literal, .offset = offset_code, .match = match };
        }

        fn checkedCode(value: usize, comptime classifier: anytype, comptime bits: []const u8) Error!u8 {
            const code: u8 = try classifier(value);
            if (code >= bits.len) return error.CorruptFrame;
            return code;
        }

        fn extraBits(codes: Codes) usize {
            return @as(usize, Rules.literal_bits[codes.literal]) +
                @as(usize, Rules.offset_bits[codes.offset]) +
                @as(usize, Rules.match_bits[codes.match]);
        }

        fn rleBase(bits: usize) usize {
            // One count byte, one mode byte, three code bytes, E extra bits
            // and the reverse-stream end marker: 5+ceil((E+1)/8).
            return 6 + bits / 8;
        }

        fn predefinedBase(bits: usize) usize {
            // One count byte and one mode byte. Initial states contribute
            // 6+5+6 bits and the end marker one bit. There are no transitions.
            return 2 + (bits + 18 + 7) / 8;
        }

        fn addSection(section_len: usize, sequence_len: usize) Error!usize {
            // Every original intermediate addition is nonnegative and no
            // larger than this final sum, so overflow status is identical.
            return std.math.add(usize, section_len, sequence_len) catch return error.IntegerOverflow;
        }
    };
}

fn validateContract(comptime Rules: type) void {
    const contract: Contract = Rules.contract;
    if (contract.literal_initial_bits != 6 or contract.offset_initial_bits != 5 or contract.match_initial_bits != 6)
        @compileError("single sequence pricing requires predefined initial-state widths 6/5/6");
    if (contract.offset_min_additional_bits != 2)
        @compileError("single sequence pricing requires offset masks with at least two additional bits");
    if (contract.literal_extra_bits_max > 16 or contract.offset_extra_bits_max > 31 or contract.match_extra_bits_max > 16)
        @compileError("single sequence pricing requires canonical extra-bit bounds 16/31/16");

    validateTable(Rules.literal_bits, Rules.literal_masks, contract.literal_extra_bits_max, 6, 0);
    validateTable(Rules.offset_bits, Rules.offset_masks, contract.offset_extra_bits_max, 5, 2);
    validateTable(Rules.match_bits, Rules.match_masks, contract.match_extra_bits_max, 6, 0);
}

fn validateTable(comptime bits: []const u8, comptime masks: []const u64, comptime max_bits: u8, comptime initial_bits: u8, comptime min_bits: u8) void {
    if (bits.len == 0 or bits.len != masks.len or bits.len > 256)
        @compileError("single sequence code widths and masks must have matching nonempty u8-indexed tables");
    const allowed_states: u64 = if (initial_bits == 6) std.math.maxInt(u64) else std.math.maxInt(u32);
    for (bits, masks) |width, mask| {
        if (width > max_bits)
            @compileError("single sequence code width exceeds its declared bound");
        if (mask & ~allowed_states != 0)
            @compileError("single sequence state mask exceeds the initial-state width");
        if (width < min_bits and mask != 0)
            @compileError("single sequence offset mask includes a repeat-offset code");
    }
}

test "zstd scalar single sequence pricing keeps masks ties and RLE first errors" {
    // Synthetic canonical classifiers isolate pricing behavior from the
    // production classifier and table oracle exercised by the codec tests.
    const Rules = struct {
        pub const Error = error{ CorruptFrame, IntegerOverflow };
        pub const contract: Contract = .{};
        pub const literal_bits = &[_]u8{ 0, 1, 2, 3, 4, 5, 6, 7 };
        pub const offset_bits = &[_]u8{ 0, 2, 31 };
        pub const match_bits = &[_]u8{0};
        pub const literal_masks = &([_]u64{1} ** 8);
        pub const offset_masks = &[_]u64{ 0, 1, 0 };
        pub const match_masks = &[_]u64{1};
        var calls: [3]usize = @splat(0);

        pub fn literalCode(value: usize) Error!u8 {
            calls[0] += 1;
            if (value >= literal_bits.len) return error.CorruptFrame;
            return @intCast(value);
        }
        pub fn offsetCode(value: usize) Error!u8 {
            calls[1] += 1;
            if (value >= offset_bits.len) return error.CorruptFrame;
            return @intCast(value);
        }
        pub fn matchCode(value: usize) Error!u8 {
            calls[2] += 1;
            if (value != 3) return error.CorruptFrame;
            return 0;
        }
    };
    const Price = Calculator(Rules);
    try std.testing.expectEqual(@as(usize, 6), try Price.baseLen(0, 0, 3, 0));
    try std.testing.expectError(error.CorruptFrame, Price.predefinedPayloadLen(0, 0, 3, 0));
    try std.testing.expectEqual(@as(usize, 9), try Price.baseLen(0, 2, 3, 0));
    try std.testing.expectError(error.CorruptFrame, Price.predefinedPayloadLen(0, 2, 3, 0));
    try std.testing.expectEqual(@as(usize, 6), try Price.rlePayloadLen(5, 1, 3, 0));
    try std.testing.expectEqual(@as(usize, 6), try Price.predefinedPayloadLen(5, 1, 3, 0));
    try std.testing.expectEqual(@as(usize, 6), try Price.baseLen(5, 1, 3, 0));

    Rules.calls = @splat(0);
    try std.testing.expectEqual(@as(usize, 5), try Price.baseLen(0, 1, 3, 0));
    try std.testing.expectEqualSlices(usize, &.{ 1, 1, 1 }, &Rules.calls);

    const section_len = std.math.maxInt(usize) - 5;
    try std.testing.expectEqual(std.math.maxInt(usize), try Price.predefinedPayloadLen(0, 1, 3, section_len));
    try std.testing.expectError(error.IntegerOverflow, Price.rlePayloadLen(0, 1, 3, section_len));
    try std.testing.expectError(error.IntegerOverflow, Price.baseLen(0, 1, 3, section_len));
    try std.testing.expectError(error.CorruptFrame, Price.baseLen(8, 1, 3, std.math.maxInt(usize)));
    try std.testing.expectError(error.CorruptFrame, Price.baseLen(0, 1, 2, std.math.maxInt(usize)));
}
