const std = @import("std");

/// Recognize bounded, printable, fixed-width records whose columns are mostly
/// stable across rows. Ordinary prose and binary payloads are rejected.
pub fn isStableFixedWidth(input: []const u8) bool {
    if (input.len < 4 * 1024 or input.len > 64 * 1024) return false;
    const row_len = (std.mem.indexOfScalar(u8, input, '\n') orelse return false) + 1;
    if (row_len < 32 or row_len > 1024 or input.len % row_len != 0 or input.len / row_len < 16) return false;
    const template = input[0..row_len];
    for (template[0 .. row_len - 1]) |byte|
        if (byte != '\t' and (byte < 32 or byte > 126)) return false;
    var start = row_len;
    while (start < input.len) : (start += row_len) {
        const row = input[start..][0..row_len];
        if (row[row_len - 1] != '\n') return false;
        var equal_columns: usize = 0;
        for (row[0 .. row_len - 1], template[0 .. row_len - 1]) |byte, expected| {
            if (byte == '\n' or (byte != '\t' and (byte < 32 or byte > 126))) return false;
            equal_columns += @intFromBool(byte == expected);
        }
        if (equal_columns * 8 < (row_len - 1) * 7) return false;
    }
    return true;
}

test "fixed-width classifier rejects unstable and malformed rows" {
    var records: [32 * 128]u8 = undefined;
    for (0..32) |row_index| {
        const row = records[row_index * 128 ..][0..128];
        @memset(row, 'a');
        row[4] = @intCast('0' + row_index % 10);
        row[127] = '\n';
    }
    try std.testing.expect(isStableFixedWidth(&records));
    var unstable = records;
    @memset(unstable[128..][0..32], 'z');
    try std.testing.expect(!isStableFixedWidth(&unstable));
    var ragged = records;
    ragged[128 + 126] = '\n';
    try std.testing.expect(!isStableFixedWidth(&ragged));
    var binary = records;
    binary[128 + 5] = 0xff;
    try std.testing.expect(!isStableFixedWidth(&binary));
    try std.testing.expect(!isStableFixedWidth(records[0 .. 15 * 128]));
    try std.testing.expect(!isStableFixedWidth("ordinary prose without fixed records"));
}
