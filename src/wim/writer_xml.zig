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
    for (images, 0..) |image, index|
        try writeImage(&utf8.writer, image, index + 1);
    try print(
        &utf8.writer,
        "<TOTALBYTES>{d}</TOTALBYTES></WIM>",
        .{total_bytes},
    );

    return utf8ToXmlAlloc(allocator, utf8.written());
}

pub fn appendImageAlloc(
    allocator: std.mem.Allocator,
    existing_xml: []const u8,
    expected_image_count: usize,
    image: ImageInfo,
    total_bytes: usize,
) Error![]u8 {
    if (expected_image_count == 0 or expected_image_count >= 65_535)
        return error.InvalidWimWriterOptions;
    const existing = try xmlToUtf8Alloc(allocator, existing_xml);
    defer allocator.free(existing);
    const root_end = std.mem.lastIndexOf(u8, existing, "</WIM>") orelse
        return error.InvalidWimWriterOptions;
    var image_count: usize = 0;
    var search_offset: usize = 0;
    const index_prefix = "<IMAGE INDEX=\"";
    while (std.mem.indexOfPos(u8, existing, search_offset, index_prefix)) |start| {
        const digits_start = start + index_prefix.len;
        const digits_end = std.mem.indexOfScalarPos(u8, existing, digits_start, '"') orelse
            return error.InvalidWimWriterOptions;
        if (digits_end == digits_start or digits_end + 1 >= existing.len or
            existing[digits_end + 1] != '>')
            return error.InvalidWimWriterOptions;
        const index = std.fmt.parseInt(usize, existing[digits_start..digits_end], 10) catch
            return error.InvalidWimWriterOptions;
        image_count += 1;
        if (index != image_count) return error.InvalidWimWriterOptions;
        search_offset = digits_end + 2;
    }
    if (image_count != expected_image_count) return error.InvalidWimWriterOptions;

    const total_open = "<TOTALBYTES>";
    const total_close = "</TOTALBYTES>";
    const total_start = std.mem.lastIndexOf(u8, existing[0..root_end], total_open) orelse
        return error.InvalidWimWriterOptions;
    const value_start = total_start + total_open.len;
    const value_end = std.mem.indexOfPos(u8, existing, value_start, total_close) orelse
        return error.InvalidWimWriterOptions;
    if (value_end > root_end or value_end == value_start)
        return error.InvalidWimWriterOptions;
    _ = std.fmt.parseInt(u64, existing[value_start..value_end], 10) catch
        return error.InvalidWimWriterOptions;
    const total_end = value_end + total_close.len;

    var escaped_name = std.Io.Writer.Allocating.init(allocator);
    defer escaped_name.deinit();
    try writeEscaped(&escaped_name.writer, image.name);
    var name_offset: usize = 0;
    while (std.mem.indexOfPos(u8, existing, name_offset, "<NAME>")) |name_start| {
        const name_value_start = name_start + "<NAME>".len;
        const name_end = std.mem.indexOfPos(u8, existing, name_value_start, "</NAME>") orelse
            return error.InvalidWimWriterOptions;
        if (std.ascii.eqlIgnoreCase(existing[name_value_start..name_end], escaped_name.written()))
            return error.InvalidWimWriterOptions;
        name_offset = name_end + "</NAME>".len;
    }

    var updated = std.Io.Writer.Allocating.init(allocator);
    defer updated.deinit();
    try writeAll(&updated.writer, existing[0..total_start]);
    try writeImage(&updated.writer, image, expected_image_count + 1);
    try print(
        &updated.writer,
        "<TOTALBYTES>{d}</TOTALBYTES>",
        .{total_bytes},
    );
    try writeAll(&updated.writer, existing[total_end..]);
    return utf8ToXmlAlloc(allocator, updated.written());
}

pub fn deleteImageAlloc(
    allocator: std.mem.Allocator,
    existing_xml: []const u8,
    expected_image_count: usize,
    image_index: usize,
    total_bytes: usize,
) Error![]u8 {
    if (expected_image_count <= 1 or image_index == 0 or
        image_index > expected_image_count)
        return error.InvalidWimWriterOptions;
    const existing = try xmlToUtf8Alloc(allocator, existing_xml);
    defer allocator.free(existing);
    const Span = struct {
        start: usize,
        end: usize,
        digits_start: usize,
        digits_end: usize,
    };
    var spans: std.ArrayList(Span) = .empty;
    defer spans.deinit(allocator);
    const index_prefix = "<IMAGE INDEX=\"";
    const image_close = "</IMAGE>";
    var search_offset: usize = 0;
    while (std.mem.indexOfPos(u8, existing, search_offset, index_prefix)) |start| {
        const digits_start = start + index_prefix.len;
        const digits_end = std.mem.indexOfScalarPos(u8, existing, digits_start, '"') orelse
            return error.InvalidWimWriterOptions;
        if (digits_end == digits_start or digits_end + 1 >= existing.len or
            existing[digits_end + 1] != '>')
            return error.InvalidWimWriterOptions;
        const index = std.fmt.parseInt(usize, existing[digits_start..digits_end], 10) catch
            return error.InvalidWimWriterOptions;
        if (index != spans.items.len + 1) return error.InvalidWimWriterOptions;
        const close_start = std.mem.indexOfPos(u8, existing, digits_end + 2, image_close) orelse
            return error.InvalidWimWriterOptions;
        const end = close_start + image_close.len;
        try spans.append(allocator, .{
            .start = start,
            .end = end,
            .digits_start = digits_start,
            .digits_end = digits_end,
        });
        search_offset = end;
    }
    if (spans.items.len != expected_image_count)
        return error.InvalidWimWriterOptions;

    var removed = std.Io.Writer.Allocating.init(allocator);
    defer removed.deinit();
    var cursor: usize = 0;
    for (spans.items, 1..) |span, index| {
        try writeAll(&removed.writer, existing[cursor..span.start]);
        if (index != image_index) {
            if (index > image_index) {
                try writeAll(&removed.writer, existing[span.start..span.digits_start]);
                try print(&removed.writer, "{d}", .{index - 1});
                try writeAll(&removed.writer, existing[span.digits_end..span.end]);
            } else {
                try writeAll(&removed.writer, existing[span.start..span.end]);
            }
        }
        cursor = span.end;
    }
    try writeAll(&removed.writer, existing[cursor..]);

    const without_image = removed.written();
    const root_end = std.mem.lastIndexOf(u8, without_image, "</WIM>") orelse
        return error.InvalidWimWriterOptions;
    const total_open = "<TOTALBYTES>";
    const total_close = "</TOTALBYTES>";
    const total_start = std.mem.lastIndexOf(u8, without_image[0..root_end], total_open) orelse
        return error.InvalidWimWriterOptions;
    const value_start = total_start + total_open.len;
    const value_end = std.mem.indexOfPos(u8, without_image, value_start, total_close) orelse
        return error.InvalidWimWriterOptions;
    if (value_end > root_end or value_end == value_start)
        return error.InvalidWimWriterOptions;
    _ = std.fmt.parseInt(u64, without_image[value_start..value_end], 10) catch
        return error.InvalidWimWriterOptions;

    var updated = std.Io.Writer.Allocating.init(allocator);
    defer updated.deinit();
    try writeAll(&updated.writer, without_image[0..total_start]);
    try print(&updated.writer, "<TOTALBYTES>{d}</TOTALBYTES>", .{total_bytes});
    try writeAll(
        &updated.writer,
        without_image[value_end + total_close.len ..],
    );
    return utf8ToXmlAlloc(allocator, updated.written());
}

fn writeImage(output: *std.Io.Writer, image: ImageInfo, index: usize) Error!void {
    try validateName(image.name);
    try print(output, "<IMAGE INDEX=\"{d}\"><NAME>", .{index});
    try writeEscaped(output, image.name);
    try print(
        output,
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

fn xmlToUtf8Alloc(allocator: std.mem.Allocator, xml: []const u8) Error![]u8 {
    if (xml.len < 2 or xml.len & 1 != 0 or xml[0] != 0xff or xml[1] != 0xfe)
        return error.InvalidWimWriterOptions;
    const units = try allocator.alloc(u16, (xml.len - 2) / 2);
    defer allocator.free(units);
    for (units, 0..) |*unit, index|
        unit.* = std.mem.readInt(u16, xml[2 + index * 2 ..][0..2], .little);
    return std.unicode.utf16LeToUtf8Alloc(allocator, units) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidWimWriterOptions,
    };
}

fn utf8ToXmlAlloc(allocator: std.mem.Allocator, utf8: []const u8) Error![]u8 {
    const units = std.unicode.utf8ToUtf16LeAlloc(allocator, utf8) catch |err| switch (err) {
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
            .name = "SECOND",
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

    const updated = try appendImageAlloc(std.testing.allocator, xml, 2, .{
        .name = "third <image>",
        .directory_count = 8,
        .file_count = 9,
        .total_bytes = 10,
        .hard_link_bytes = 11,
        .creation_time = 12,
        .last_modification_time = 13,
    }, 5678);
    defer std.testing.allocator.free(updated);
    try std.testing.expect(std.mem.indexOf(u8, updated, &.{
        '<', 0, 'I', 0, 'M', 0, 'A', 0, 'G', 0, 'E', 0, ' ', 0,
        'I', 0, 'N', 0, 'D', 0, 'E', 0, 'X', 0, '=', 0, '"', 0,
        '3', 0, '"', 0,
    }) != null);
    try std.testing.expect(std.mem.indexOf(u8, updated, &.{
        '<', 0, 'T', 0, 'O', 0, 'T', 0, 'A', 0, 'L', 0, 'B', 0,
        'Y', 0, 'T', 0, 'E', 0, 'S', 0, '>', 0, '5', 0, '6', 0,
        '7', 0, '8', 0, '<', 0, '/', 0,
    }) != null);
    try std.testing.expectError(
        error.InvalidWimWriterOptions,
        appendImageAlloc(std.testing.allocator, xml, 2, .{
            .name = "second",
            .directory_count = 0,
            .file_count = 0,
            .total_bytes = 0,
            .hard_link_bytes = 0,
            .creation_time = 0,
            .last_modification_time = 0,
        }, 0),
    );

    const deleted = try deleteImageAlloc(
        std.testing.allocator,
        updated,
        3,
        2,
        999,
    );
    defer std.testing.allocator.free(deleted);
    const deleted_utf8 = try xmlToUtf8Alloc(std.testing.allocator, deleted);
    defer std.testing.allocator.free(deleted_utf8);
    try std.testing.expect(std.mem.indexOf(u8, deleted_utf8, "second") == null);
    try std.testing.expect(std.mem.indexOf(u8, deleted_utf8, "third &lt;image&gt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, deleted_utf8, "IMAGE INDEX=\"2\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, deleted_utf8, "<TOTALBYTES>999</TOTALBYTES>") != null);
}
