const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    UnsupportedPipableWimInput,
};

const Utf16Range = struct {
    open_start: usize,
    content_start: usize,
    content_end: usize,
    close_end: usize,
};

pub fn leadingAlloc(
    allocator: std.mem.Allocator,
    xml: []const u8,
) Error![]u8 {
    const range = findTopTotalBytes(xml) orelse return allocator.dupe(u8, xml);
    const output_len = xml.len - (range.close_end - range.open_start);
    const output = try allocator.alloc(u8, output_len);
    @memcpy(output[0..range.open_start], xml[0..range.open_start]);
    @memcpy(output[range.open_start..], xml[range.close_end..]);
    return output;
}

pub fn finalAlloc(
    allocator: std.mem.Allocator,
    xml: []const u8,
    total_bytes: usize,
) Error![]u8 {
    const decimal = try std.fmt.allocPrint(allocator, "{d}", .{total_bytes});
    defer allocator.free(decimal);
    if (findTopTotalBytes(xml)) |range| {
        const replacement_len = std.math.mul(usize, decimal.len, 2) catch
            return error.IntegerOverflow;
        const removed_len = range.content_end - range.content_start;
        const base_len = xml.len - removed_len;
        const output_len = std.math.add(usize, base_len, replacement_len) catch
            return error.IntegerOverflow;
        const output = try allocator.alloc(u8, output_len);
        @memcpy(output[0..range.content_start], xml[0..range.content_start]);
        writeUtf16Ascii(output[range.content_start..][0..replacement_len], decimal);
        @memcpy(
            output[range.content_start + replacement_len ..],
            xml[range.content_end..],
        );
        return output;
    }
    const closing_start = findUtf16Ascii(xml, "</WIM>", true) orelse
        return error.UnsupportedPipableWimInput;
    const tag_prefix = "<TOTALBYTES>";
    const tag_suffix = "</TOTALBYTES>";
    const tag_chars = std.math.add(
        usize,
        tag_prefix.len + tag_suffix.len,
        decimal.len,
    ) catch return error.IntegerOverflow;
    const tag_len = std.math.mul(usize, tag_chars, 2) catch
        return error.IntegerOverflow;
    const output = try allocator.alloc(
        u8,
        std.math.add(usize, xml.len, tag_len) catch return error.IntegerOverflow,
    );
    @memcpy(output[0..closing_start], xml[0..closing_start]);
    var cursor = closing_start;
    writeUtf16Ascii(output[cursor..][0 .. tag_prefix.len * 2], tag_prefix);
    cursor += tag_prefix.len * 2;
    writeUtf16Ascii(output[cursor..][0 .. decimal.len * 2], decimal);
    cursor += decimal.len * 2;
    writeUtf16Ascii(output[cursor..][0 .. tag_suffix.len * 2], tag_suffix);
    cursor += tag_suffix.len * 2;
    @memcpy(output[cursor..], xml[closing_start..]);
    return output;
}

fn findTopTotalBytes(xml: []const u8) ?Utf16Range {
    const open = "<TOTALBYTES>";
    const close = "</TOTALBYTES>";
    const open_start = findUtf16Ascii(xml, open, true) orelse return null;
    const content_start = open_start + open.len * 2;
    const close_relative = findUtf16Ascii(xml[content_start..], close, false) orelse
        return null;
    const content_end = content_start + close_relative;
    return .{
        .open_start = open_start,
        .content_start = content_start,
        .content_end = content_end,
        .close_end = content_end + close.len * 2,
    };
}

fn findUtf16Ascii(
    input: []const u8,
    ascii: []const u8,
    last: bool,
) ?usize {
    const byte_len = ascii.len * 2;
    if (byte_len > input.len) return null;
    var found: ?usize = null;
    var offset: usize = 0;
    while (offset + byte_len <= input.len) : (offset += 2) {
        var matches = true;
        for (ascii, 0..) |byte, index| {
            if (input[offset + index * 2] != byte or
                input[offset + index * 2 + 1] != 0)
            {
                matches = false;
                break;
            }
        }
        if (!matches) continue;
        if (!last) return offset;
        found = offset;
    }
    return found;
}

fn writeUtf16Ascii(output: []u8, ascii: []const u8) void {
    std.debug.assert(output.len == ascii.len * 2);
    for (ascii, 0..) |byte, index| {
        output[index * 2] = byte;
        output[index * 2 + 1] = 0;
    }
}

test "WIM pipable XML omits leading and rewrites final total bytes" {
    const source_ascii = "<WIM><IMAGE INDEX=\"1\"><TOTALBYTES>7</TOTALBYTES>" ++
        "</IMAGE><TOTALBYTES>99</TOTALBYTES></WIM>";
    const source = try std.testing.allocator.alloc(u8, source_ascii.len * 2);
    defer std.testing.allocator.free(source);
    writeUtf16Ascii(source, source_ascii);
    const leading = try leadingAlloc(std.testing.allocator, source);
    defer std.testing.allocator.free(leading);
    try std.testing.expect(leading.len < source.len);
    const final = try finalAlloc(std.testing.allocator, source, 12345);
    defer std.testing.allocator.free(final);
    try std.testing.expect(final.len > source.len);
}
