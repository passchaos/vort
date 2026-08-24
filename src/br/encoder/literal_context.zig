pub const mode_utf8: u2 = 2;

pub fn value(mode: u2, previous: u8, second_previous: u8) usize {
    return switch (mode) {
        0 => previous & 0x3f,
        1 => previous >> 2,
        mode_utf8 => utf8(previous, second_previous),
        3 => (signedBucket(previous) << 3) | signedBucket(second_previous),
    };
}

/// A two-tree UTF-8 split that isolates the letter-heavy final context bucket.
/// Context 56 represents a previous lowercase vowel; contexts 60...63 cover
/// lowercase consonants with the second-last-byte class in the low two bits.
/// Grouping all four consonant contexts with vowels keeps the map compact while
/// separating text continuation bytes from punctuation/binary contexts.
pub fn utf8TextTree(context: usize) u1 {
    return @intFromBool(context >= 56);
}

fn utf8(previous: u8, second_previous: u8) usize {
    return utf8LastByte(previous) | utf8SecondLastByte(second_previous);
}

fn utf8LastByte(value_: u8) usize {
    if (value_ >= 192) return 2 + (value_ & 1);
    if (value_ >= 128) return value_ & 1;
    if ((value_ < 32 and value_ != 9 and value_ != 10 and value_ != 13) or value_ == 127) return 0;
    return switch (value_) {
        9, 10, 13 => 4,
        32 => 8,
        '"', '\'' => 16,
        '%' => 20,
        '(', '<', '[', '{' => 24,
        ')', '>', ']', '}' => 28,
        ',', ';', ':' => 32,
        '.' => 36,
        '=' => 40,
        '0'...'9' => 44,
        'A', 'E', 'I', 'O', 'U' => 48,
        'B'...'D', 'F'...'H', 'J'...'N', 'P'...'T', 'V'...'Z' => 52,
        'a', 'e', 'i', 'o', 'u' => 56,
        'b'...'d', 'f'...'h', 'j'...'n', 'p'...'t', 'v'...'z' => 60,
        else => 12,
    };
}

fn utf8SecondLastByte(value_: u8) usize {
    if (value_ >= 208) return 2;
    if (value_ >= 128) return 0;
    return switch (value_) {
        0...32, 127 => 0,
        '0'...'9', 'A'...'Z' => 2,
        'a'...'z' => 3,
        else => 1,
    };
}

fn signedBucket(value_: u8) usize {
    return switch (value_) {
        0 => 0,
        1...15 => 1,
        16...63 => 2,
        64...127 => 3,
        128...191 => 4,
        192...239 => 5,
        240...254 => 6,
        255 => 7,
    };
}

test "utf8 text tree selects lowercase letter contexts" {
    try std.testing.expectEqual(@as(u1, 1), utf8TextTree(value(mode_utf8, 'a', ' ')));
    try std.testing.expectEqual(@as(u1, 1), utf8TextTree(value(mode_utf8, 'z', 'a')));
    try std.testing.expectEqual(@as(u1, 0), utf8TextTree(value(mode_utf8, ' ', 'a')));
    try std.testing.expectEqual(@as(u1, 0), utf8TextTree(value(mode_utf8, 0xff, 0xff)));
}
const std = @import("std");
