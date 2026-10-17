const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidWimWriterOptions,
};

pub const ImageInfo = struct {
    name: []const u8,
    directory_count: usize,
    file_count: usize,
    total_bytes: u64,
    hard_link_bytes: u64,
    creation_time: u64,
    last_modification_time: u64,
};

pub fn validateName(name: []const u8) Error!void {
    if (!validXmlText(name)) return error.InvalidWimWriterOptions;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    images: []const ImageInfo,
    total_bytes: usize,
) Error![]u8 {
    if (images.len == 0 or images.len > 65_535)
        return error.InvalidWimWriterOptions;
    var utf8 = std.Io.Writer.Allocating.init(allocator);
    defer utf8.deinit();
    try writeAll(&utf8.writer, "<WIM>");
    for (images, 0..) |image, index| {
        try validateName(image.name);
        try print(&utf8.writer, "<IMAGE INDEX=\"{d}\"><NAME>", .{index + 1});
        try writeEscaped(&utf8.writer, image.name);
        try print(
            &utf8.writer,
            "</NAME><DIRCOUNT>{d}</DIRCOUNT><FILECOUNT>{d}</FILECOUNT>" ++
                "<TOTALBYTES>{d}</TOTALBYTES><HARDLINKBYTES>{d}</HARDLINKBYTES>" ++
                "<CREATIONTIME><HIGHPART>{d}</HIGHPART><LOWPART>{d}</LOWPART>" ++
                "</CREATIONTIME><LASTMODIFICATIONTIME><HIGHPART>{d}</HIGHPART>" ++
                "<LOWPART>{d}</LOWPART></LASTMODIFICATIONTIME></IMAGE>",
            .{
                image.directory_count,
                image.file_count,
                image.total_bytes,
                image.hard_link_bytes,
                @as(u32, @truncate(image.creation_time >> 32)),
                @as(u32, @truncate(image.creation_time)),
                @as(u32, @truncate(image.last_modification_time >> 32)),
                @as(u32, @truncate(image.last_modification_time)),
            },
        );
    }
    try print(
        &utf8.writer,
        "<TOTALBYTES>{d}</TOTALBYTES></WIM>",
        .{total_bytes},
    );

    const units = std.unicode.utf8ToUtf16LeAlloc(
        allocator,
        utf8.written(),
    ) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidUtf8 => return error.InvalidWimWriterOptions,
    };
    defer allocator.free(units);
    const byte_len = std.math.mul(usize, units.len, 2) catch
        return error.IntegerOverflow;
    const output_len = std.math.add(usize, 2, byte_len) catch
        return error.IntegerOverflow;
    const output = try allocator.alloc(u8, output_len);
    output[0] = 0xff;
    output[1] = 0xfe;
    for (units, 0..) |unit, index|
        std.mem.writeInt(u16, output[2 + index * 2 ..][0..2], unit, .little);
    return output;
}

fn writeEscaped(output: *std.Io.Writer, text: []const u8) Error!void {
    try validateName(text);
    for (text) |byte| {
        const replacement: []const u8 = switch (byte) {
            '&' => "&amp;",
            '<' => "&lt;",
            '>' => "&gt;",
            else => {
                output.writeByte(byte) catch return error.OutOfMemory;
                continue;
            },
        };
        try writeAll(output, replacement);
    }
}

fn validXmlText(text: []const u8) bool {
    if (!std.unicode.utf8ValidateSlice(text)) return false;
    var view = std.unicode.Utf8View.initUnchecked(text);
    var iterator = view.iterator();
    while (iterator.nextCodepoint()) |codepoint| {
        if (!(codepoint == 0x09 or codepoint == 0x0a or codepoint == 0x0d or
            (codepoint >= 0x20 and codepoint <= 0xd7ff) or
            (codepoint >= 0xe000 and codepoint <= 0xfffd) or
            (codepoint >= 0x10000 and codepoint <= 0x10ffff)))
            return false;
    }
    return true;
}

fn writeAll(output: *std.Io.Writer, bytes: []const u8) Error!void {
    output.writeAll(bytes) catch return error.OutOfMemory;
}

fn print(output: *std.Io.Writer, comptime fmt: []const u8, args: anytype) Error!void {
    output.print(fmt, args) catch return error.OutOfMemory;
}

test "WIM writer XML emits ordered images and escaped names" {
    const xml = try encodeAlloc(std.testing.allocator, &.{
        .{
            .name = "first & one",
            .directory_count = 1,
            .file_count = 2,
            .total_bytes = 3,
            .hard_link_bytes = 0,
            .creation_time = 0,
            .last_modification_time = 0,
        },
        .{
            .name = "second",
            .directory_count = 4,
            .file_count = 5,
            .total_bytes = 6,
            .hard_link_bytes = 7,
            .creation_time = 8,
            .last_modification_time = 9,
        },
    }, 1234);
    defer std.testing.allocator.free(xml);
    try std.testing.expect(std.mem.indexOf(u8, xml, &.{
        '<', 0, 'I', 0, 'M', 0, 'A', 0, 'G', 0, 'E', 0, ' ', 0,
        'I', 0, 'N', 0, 'D', 0, 'E', 0, 'X', 0, '=', 0, '"', 0,
        '2', 0, '"', 0,
    }) != null);
}
