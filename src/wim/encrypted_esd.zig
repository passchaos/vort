//! Encrypted ESD XML/range parsing and complete image reconstruction.

const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const vail = @import("vail_archive_crypto");

pub const Error = core.Error || format.Error || std.mem.Allocator.Error ||
    vail.cryptoapi_rsa.Error || vail.esd.Error || error{
    InvalidEncryptedEsd,
    WimNotEncryptedEsd,
};

pub const Limits = struct {
    max_xml_bytes: usize = 16 * 1024 * 1024,
    max_ranges: usize = 1024 * 1024,
    max_wrapped_key_bytes: usize = 512,
};

pub const Range = struct {
    offset: u64,
    length: u64,
};

pub const Info = struct {
    allocator: std.mem.Allocator,
    wrapped_key: []u8,
    ranges: []Range,
    esd_xml_offset: usize,

    pub fn deinit(self: *Info) void {
        self.allocator.free(self.wrapped_key);
        self.allocator.free(self.ranges);
        self.* = undefined;
    }
};

pub fn parseXmlAlloc(
    allocator: std.mem.Allocator,
    xml: []const u8,
    limits: Limits,
) Error!Info {
    if (xml.len > limits.max_xml_bytes) return error.OutputLimitExceeded;
    if (xml.len & 1 != 0) return error.InvalidEncryptedEsd;
    const esd_start = findAsciiUtf16(xml, 0, "<ESD>") orelse
        return error.WimNotEncryptedEsd;
    const esd_end = findAsciiUtf16(xml, esd_start, "</ESD>") orelse
        return error.InvalidEncryptedEsd;
    const encrypted_start = findAsciiUtf16(
        xml,
        esd_start,
        "<ENCRYPTED Count=\"",
    ) orelse return error.WimNotEncryptedEsd;
    if (encrypted_start >= esd_end) return error.InvalidEncryptedEsd;
    const key_start_tag = findAsciiUtf16(xml, esd_start, "<KEY>") orelse
        return error.InvalidEncryptedEsd;
    const key_data_start = key_start_tag + utf16AsciiLen("<KEY>");
    const key_end = findAsciiUtf16(xml, key_data_start, "</KEY>") orelse
        return error.InvalidEncryptedEsd;
    if (key_end >= esd_end) return error.InvalidEncryptedEsd;
    const wrapped_key = try decodeBase64Utf16Alloc(
        allocator,
        xml[key_data_start..key_end],
        limits.max_wrapped_key_bytes,
    );
    errdefer allocator.free(wrapped_key);
    if (wrapped_key.len != 256 and wrapped_key.len != 512)
        return error.InvalidEncryptedEsd;

    var cursor = encrypted_start + utf16AsciiLen("<ENCRYPTED Count=\"");
    const count = try parseDecimalUtf16(usize, xml, &cursor, limits.max_ranges);
    if (count == 0 or !consumeAsciiUtf16(xml, &cursor, "\">"))
        return error.InvalidEncryptedEsd;
    const ranges = try allocator.alloc(Range, count);
    errdefer allocator.free(ranges);
    var previous_end: u64 = 0;
    for (ranges) |*range| {
        const range_start = findAsciiUtf16(xml, cursor, "<RANGE Offset=\"") orelse
            return error.InvalidEncryptedEsd;
        if (range_start >= esd_end) return error.InvalidEncryptedEsd;
        cursor = range_start + utf16AsciiLen("<RANGE Offset=\"");
        const offset = try parseDecimalUtf16(u64, xml, &cursor, std.math.maxInt(u64));
        if (!consumeAsciiUtf16(xml, &cursor, "\" Bytes=\""))
            return error.InvalidEncryptedEsd;
        const length = try parseDecimalUtf16(u64, xml, &cursor, std.math.maxInt(u32));
        if (!consumeAsciiUtf16(xml, &cursor, "\">"))
            return error.InvalidEncryptedEsd;
        const range_end = findAsciiUtf16(xml, cursor, "</RANGE>") orelse
            return error.InvalidEncryptedEsd;
        if (range_end >= esd_end) return error.InvalidEncryptedEsd;
        cursor = range_end + utf16AsciiLen("</RANGE>");
        if (length == 0 or length % vail.esd.block_len != 0 or offset < previous_end)
            return error.InvalidEncryptedEsd;
        const end = std.math.add(u64, offset, length) catch
            return error.IntegerOverflow;
        range.* = .{ .offset = offset, .length = length };
        previous_end = end;
    }
    const encrypted_end = findAsciiUtf16(xml, cursor, "</ENCRYPTED>") orelse
        return error.InvalidEncryptedEsd;
    if (encrypted_end >= esd_end) return error.InvalidEncryptedEsd;
    if (findAsciiUtf16(xml, cursor, "<RANGE Offset=\"")) |extra_range| {
        if (extra_range < encrypted_end) return error.InvalidEncryptedEsd;
    }
    return .{
        .allocator = allocator,
        .wrapped_key = wrapped_key,
        .ranges = ranges,
        .esd_xml_offset = esd_start,
    };
}

pub fn decryptWithPrivateKeyAllocLimited(
    allocator: std.mem.Allocator,
    archive_bytes: []const u8,
    header: format.Header,
    xml: []const u8,
    info: Info,
    private_key_blob: []const u8,
    max_output_len: usize,
) Error![]u8 {
    try validateInfo(archive_bytes, header, info);
    var key = try vail.cryptoapi_rsa.unwrapEsdAes256Key(
        private_key_blob,
        info.wrapped_key,
    );
    defer std.crypto.secureZero(u8, &key);
    return decryptWithAesKeyAllocLimited(
        allocator,
        archive_bytes,
        header,
        xml,
        info,
        &key,
        max_output_len,
    );
}

pub fn decryptWithAesKeyAllocLimited(
    allocator: std.mem.Allocator,
    archive_bytes: []const u8,
    header: format.Header,
    xml: []const u8,
    info: Info,
    key: *const [vail.esd.key_len]u8,
    max_output_len: usize,
) Error![]u8 {
    try validateInfo(archive_bytes, header, info);
    const decrypted = try allocator.dupe(u8, archive_bytes);
    defer allocator.free(decrypted);
    for (info.ranges) |range| {
        const start: usize = @intCast(range.offset);
        const length: usize = @intCast(range.length);
        try vail.esd.decryptRange(
            key,
            decrypted[start..][0..length],
            decrypted[start..][0..length],
        );
    }

    const integrity = try rebuildIntegrityAlloc(allocator, decrypted, header);
    defer if (integrity) |bytes| allocator.free(bytes);
    const integrity_len = if (integrity) |bytes| bytes.len else 0;
    const xml_offset: usize = @intCast(header.xml_data.offset_in_wim);
    const new_xml = try buildDecryptedXmlAlloc(
        allocator,
        xml,
        info.esd_xml_offset,
        xml_offset,
        integrity_len,
    );
    defer allocator.free(new_xml);
    const output_len = std.math.add(usize, xml_offset, new_xml.len) catch
        return error.IntegerOverflow;
    const final_len = std.math.add(usize, output_len, integrity_len) catch
        return error.IntegerOverflow;
    if (final_len > max_output_len) return error.OutputLimitExceeded;
    if (new_xml.len >= @as(u64, 1) << 56 or integrity_len >= @as(u64, 1) << 56)
        return error.InvalidEncryptedEsd;
    const output = try allocator.alloc(u8, final_len);
    errdefer allocator.free(output);
    @memcpy(output[0..xml_offset], decrypted[0..xml_offset]);
    @memcpy(output[xml_offset..][0..new_xml.len], new_xml);
    if (integrity) |bytes| @memcpy(output[output_len..], bytes);
    writeResourceHeader(
        output,
        72,
        new_xml.len,
        header.xml_data.flags,
        xml_offset,
        new_xml.len,
    );
    if (integrity) |bytes| {
        writeResourceHeader(
            output,
            124,
            bytes.len,
            header.integrity_table.flags,
            output_len,
            bytes.len,
        );
    }
    return output;
}

pub fn validateInfo(
    archive_bytes: []const u8,
    header: format.Header,
    info: Info,
) Error!void {
    if (header.pipable or header.xml_data.isCompressed() or
        header.xml_data.isSolid() or header.xml_data.isSpanned())
        return error.InvalidEncryptedEsd;
    const xml_start = header.xml_data.offset_in_wim;
    const xml_end = std.math.add(
        u64,
        xml_start,
        header.xml_data.size_in_wim,
    ) catch return error.IntegerOverflow;
    const integrity_start = header.integrity_table.offset_in_wim;
    const integrity_end = std.math.add(
        u64,
        integrity_start,
        header.integrity_table.size_in_wim,
    ) catch return error.IntegerOverflow;
    for (info.ranges) |range| {
        const end = std.math.add(u64, range.offset, range.length) catch
            return error.IntegerOverflow;
        if (range.offset < format.header_size or end > archive_bytes.len or
            rangesOverlap(range.offset, end, xml_start, xml_end) or
            (!header.integrity_table.isZero() and
                rangesOverlap(range.offset, end, integrity_start, integrity_end)))
            return error.InvalidEncryptedEsd;
    }
}

fn rebuildIntegrityAlloc(
    allocator: std.mem.Allocator,
    archive_bytes: []const u8,
    header: format.Header,
) Error!?[]u8 {
    if (header.integrity_table.isZero()) return null;
    if (header.integrity_table.isCompressed() or
        header.integrity_table.isSolid() or header.integrity_table.isSpanned())
        return error.InvalidEncryptedEsd;
    const start: usize = @intCast(header.integrity_table.offset_in_wim);
    const size: usize = @intCast(header.integrity_table.size_in_wim);
    const end = try checkedEnd(start, size, archive_bytes.len);
    if (size < 12) return error.InvalidEncryptedEsd;
    const original = archive_bytes[start..end];
    const table_size: usize = format.readU32(original, 0);
    const count: usize = format.readU32(original, 4);
    const chunk_size: usize = format.readU32(original, 8);
    const hashes_size = std.math.mul(usize, count, 20) catch
        return error.IntegerOverflow;
    const expected_size = std.math.add(usize, 12, hashes_size) catch
        return error.IntegerOverflow;
    if (table_size != size or size != expected_size or count == 0 or
        chunk_size == 0)
        return error.InvalidEncryptedEsd;
    const lookup_end_u64 = std.math.add(
        u64,
        header.lookup_table.offset_in_wim,
        header.lookup_table.size_in_wim,
    ) catch return error.IntegerOverflow;
    const lookup_end = std.math.cast(usize, lookup_end_u64) orelse
        return error.IntegerOverflow;
    if (lookup_end < format.header_size or lookup_end > archive_bytes.len)
        return error.InvalidEncryptedEsd;
    const hashed_len = lookup_end - format.header_size;
    const expected_count = (std.math.add(
        usize,
        hashed_len,
        chunk_size - 1,
    ) catch return error.IntegerOverflow) / chunk_size;
    if (expected_count != count) return error.InvalidEncryptedEsd;
    const table = try allocator.alloc(u8, size);
    errdefer allocator.free(table);
    @memcpy(table[0..12], original[0..12]);
    for (0..count) |index| {
        const chunk_start = format.header_size + index * chunk_size;
        const possible_end = std.math.add(usize, chunk_start, chunk_size) catch
            return error.IntegerOverflow;
        const chunk_end = @min(lookup_end, possible_end);
        std.crypto.hash.Sha1.hash(
            archive_bytes[chunk_start..chunk_end],
            table[12 + index * 20 ..][0..20],
            .{},
        );
    }
    return table;
}

fn buildDecryptedXmlAlloc(
    allocator: std.mem.Allocator,
    xml: []const u8,
    esd_start: usize,
    xml_offset: usize,
    integrity_len: usize,
) Error![]u8 {
    if (esd_start > xml.len or esd_start & 1 != 0 or
        (findAsciiUtf16(xml, esd_start, "<ESD>") orelse return error.InvalidEncryptedEsd) !=
            esd_start)
        return error.InvalidEncryptedEsd;
    const total_open = findAsciiUtf16(xml, 0, "<TOTALBYTES>") orelse
        return error.InvalidEncryptedEsd;
    const digits_start = total_open + utf16AsciiLen("<TOTALBYTES>");
    const digits_end = findAsciiUtf16(xml, digits_start, "</TOTALBYTES>") orelse
        return error.InvalidEncryptedEsd;
    if (digits_end >= esd_start) return error.InvalidEncryptedEsd;
    var cursor = digits_start;
    _ = try parseDecimalUtf16(u64, xml, &cursor, std.math.maxInt(u64));
    if (cursor != digits_end) return error.InvalidEncryptedEsd;
    const suffix = "\r\n</WIM>";
    var total_value: usize = 0;
    var digits_buf: [32]u8 = undefined;
    var digits: []const u8 = "0";
    for (0..4) |_| {
        const xml_len = digits_start + utf16AsciiLen(digits) +
            (esd_start - digits_end) + utf16AsciiLen(suffix);
        total_value = std.math.add(usize, xml_offset, xml_len) catch
            return error.IntegerOverflow;
        total_value = std.math.add(usize, total_value, integrity_len) catch
            return error.IntegerOverflow;
        digits = std.fmt.bufPrint(&digits_buf, "{d}", .{total_value}) catch
            return error.IntegerOverflow;
    }
    const new_len = digits_start + utf16AsciiLen(digits) +
        (esd_start - digits_end) + utf16AsciiLen(suffix);
    if (xml_offset + new_len + integrity_len != total_value)
        return error.IntegerOverflow;
    const output = try allocator.alloc(u8, new_len);
    var out: usize = 0;
    @memcpy(output[out..][0..digits_start], xml[0..digits_start]);
    out += digits_start;
    out += writeAsciiUtf16(output[out..], digits);
    const middle = xml[digits_end..esd_start];
    @memcpy(output[out..][0..middle.len], middle);
    out += middle.len;
    out += writeAsciiUtf16(output[out..], suffix);
    std.debug.assert(out == output.len);
    return output;
}

fn decodeBase64Utf16Alloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    max_decoded: usize,
) Error![]u8 {
    const chars_len = input.len / 2;
    const chars = try allocator.alloc(u8, chars_len);
    defer allocator.free(chars);
    var compact_len: usize = 0;
    for (0..chars_len) |index| {
        if (input[index * 2 + 1] != 0) return error.InvalidEncryptedEsd;
        const char = input[index * 2];
        if (char == ' ' or char == '\r' or char == '\n' or char == '\t')
            continue;
        chars[compact_len] = char;
        compact_len += 1;
    }
    const decoder = std.base64.standard.decoderWithIgnore(" \r\n\t");
    const upper = decoder.calcSizeUpperBound(compact_len);
    if (upper > max_decoded) return error.OutputLimitExceeded;
    const decoded = try allocator.alloc(u8, upper);
    errdefer allocator.free(decoded);
    const written = decoder.decode(decoded, chars[0..compact_len]) catch
        return error.InvalidEncryptedEsd;
    return allocator.realloc(decoded, written);
}

fn findAsciiUtf16(bytes: []const u8, start: usize, needle: []const u8) ?usize {
    if (start & 1 != 0) return null;
    const needle_len = utf16AsciiLen(needle);
    var offset = start;
    while (bytes.len -| offset >= needle_len) : (offset += 2) {
        var matches = true;
        for (needle, 0..) |char, index| {
            if (bytes[offset + index * 2] != char or
                bytes[offset + index * 2 + 1] != 0)
            {
                matches = false;
                break;
            }
        }
        if (matches) return offset;
    }
    return null;
}

fn consumeAsciiUtf16(bytes: []const u8, cursor: *usize, text: []const u8) bool {
    const found = findAsciiUtf16(bytes, cursor.*, text) orelse return false;
    if (found != cursor.*) return false;
    cursor.* += utf16AsciiLen(text);
    return true;
}

fn parseDecimalUtf16(
    comptime T: type,
    bytes: []const u8,
    cursor: *usize,
    max_value: T,
) Error!T {
    var value: T = 0;
    var count: usize = 0;
    while (bytes.len -| cursor.* >= 2 and bytes[cursor.* + 1] == 0) {
        const char = bytes[cursor.*];
        if (char < '0' or char > '9') break;
        value = std.math.mul(T, value, 10) catch return error.IntegerOverflow;
        value = std.math.add(T, value, char - '0') catch return error.IntegerOverflow;
        if (value > max_value) return error.OutputLimitExceeded;
        cursor.* += 2;
        count += 1;
    }
    if (count == 0) return error.InvalidEncryptedEsd;
    return value;
}

fn writeAsciiUtf16(output: []u8, text: []const u8) usize {
    for (text, 0..) |char, index| {
        output[index * 2] = char;
        output[index * 2 + 1] = 0;
    }
    return utf16AsciiLen(text);
}

fn writeResourceHeader(
    bytes: []u8,
    offset: usize,
    stored_size: usize,
    flags: u8,
    resource_offset: usize,
    decoded_size: usize,
) void {
    const value: u64 = stored_size;
    for (0..7) |index| bytes[offset + index] = @truncate(value >> @intCast(index * 8));
    bytes[offset + 7] = flags;
    std.mem.writeInt(u64, bytes[offset + 8 ..][0..8], resource_offset, .little);
    std.mem.writeInt(u64, bytes[offset + 16 ..][0..8], decoded_size, .little);
}

fn checkedEnd(start: usize, length: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
    if (end > limit) return error.InvalidEncryptedEsd;
    return end;
}

fn rangesOverlap(a_start: u64, a_end: u64, b_start: u64, b_end: u64) bool {
    return a_start < b_end and b_start < a_end;
}

fn utf16AsciiLen(text: []const u8) usize {
    return text.len * 2;
}
