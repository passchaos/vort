//! GNU PAX sparse-map parsing and logical file reconstruction.

const std = @import("std");

pub const block_size: usize = 512;

pub const Error = error{
    IntegerOverflow,
    InvalidTarHeader,
    OutputTooSmall,
};

pub const Format = enum {
    gnu_old,
    pax_0_0,
    pax_0_1,
    pax_1_0,
};

pub const Extent = struct {
    offset: usize,
    len: usize,
    data_offset: usize,
};

pub const Info = struct {
    format: Format,
    logical_size: usize,
    extent_count: usize,
    map: []const u8,
    data: []const u8,

    pub fn iterator(self: Info) Iterator {
        return Iterator.init(self.format, self.map, self.extent_count);
    }

    pub fn extractInto(self: Info, output: []u8) Error!usize {
        if (output.len < self.logical_size) return error.OutputTooSmall;
        @memset(output[0..self.logical_size], 0);
        var iterator_value = self.iterator();
        while (try iterator_value.next()) |extent| {
            if (extent.len == 0) continue;
            @memcpy(
                output[extent.offset..][0..extent.len],
                self.data[extent.data_offset..][0..extent.len],
            );
        }
        return self.logical_size;
    }
};

pub const Plan = struct {
    format: Format,
    logical_size: usize,
    extent_count: usize,
    map: []const u8,
    physical_size: usize,

    pub fn iterator(self: Plan) Iterator {
        return Iterator.init(self.format, self.map, self.extent_count);
    }
};

pub const Iterator = struct {
    format: Format,
    map: []const u8,
    extent_count: usize,
    cursor: usize,
    remaining: usize,
    data_offset: usize = 0,

    fn init(format: Format, map: []const u8, extent_count: usize) Iterator {
        var cursor: usize = 0;
        if (format == .pax_1_0) {
            const count = parseDelimited(map, &cursor, '\n') catch unreachable;
            std.debug.assert(count == extent_count);
        }
        return .{
            .format = format,
            .map = map,
            .extent_count = extent_count,
            .cursor = cursor,
            .remaining = extent_count,
        };
    }

    pub fn next(self: *Iterator) Error!?Extent {
        if (self.remaining == 0) return null;
        if (self.format == .pax_0_0)
            return @as(?Extent, try self.nextPax00());
        if (self.format == .gnu_old)
            return @as(?Extent, try self.nextOldGnu());
        const delimiter: u8 = if (self.format == .pax_1_0) '\n' else ',';
        const offset = try parseDelimited(self.map, &self.cursor, delimiter);
        const len = if (self.format == .pax_0_1 and self.remaining == 1)
            try parseFinal(self.map, &self.cursor)
        else
            try parseDelimited(self.map, &self.cursor, delimiter);
        const extent = Extent{
            .offset = offset,
            .len = len,
            .data_offset = self.data_offset,
        };
        self.data_offset = try checkedAdd(self.data_offset, len);
        self.remaining -= 1;
        return extent;
    }

    fn nextPax00(self: *Iterator) Error!Extent {
        while (self.cursor < self.map.len) {
            const offset_record = try nextPaxRecord(self.map, &self.cursor);
            if (!std.mem.eql(u8, offset_record.key, "GNU.sparse.offset")) continue;
            const size_record = try nextPaxRecord(self.map, &self.cursor);
            if (!std.mem.eql(u8, size_record.key, "GNU.sparse.numbytes"))
                return error.InvalidTarHeader;
            const offset = std.fmt.parseInt(usize, offset_record.value, 10) catch
                return error.InvalidTarHeader;
            const len = std.fmt.parseInt(usize, size_record.value, 10) catch
                return error.InvalidTarHeader;
            const extent = Extent{
                .offset = offset,
                .len = len,
                .data_offset = self.data_offset,
            };
            self.data_offset = try checkedAdd(self.data_offset, len);
            self.remaining -= 1;
            return extent;
        }
        return error.InvalidTarHeader;
    }

    fn nextOldGnu(self: *Iterator) Error!Extent {
        const index = self.extent_count - self.remaining;
        const slot = try oldGnuSlot(self.map, index);
        const offset = try parseOldGnuNumber(slot[0..12]);
        const len = try parseOldGnuNumber(slot[12..24]);
        const extent = Extent{
            .offset = offset,
            .len = len,
            .data_offset = self.data_offset,
        };
        self.data_offset = try checkedAdd(self.data_offset, len);
        self.remaining -= 1;
        return extent;
    }
};

/// `map` starts at byte 386 of the old GNU main header and includes the
/// remaining 126 main-header bytes followed by every 512-byte sparse extension.
pub fn parseOldGnu(
    map: []const u8,
    logical_size: usize,
    data: []const u8,
) Error!Info {
    const plan = try inspectOldGnu(map, logical_size);
    return infoFromPlan(plan, data);
}

/// Validates an old-GNU sparse map without requiring its stored file data.
pub fn inspectOldGnu(map: []const u8, logical_size: usize) Error!Plan {
    if (map.len < 126 or (map.len - 126) % block_size != 0)
        return error.InvalidTarHeader;
    const extension_count = (map.len - 126) / block_size;
    if ((map[96] != 0) != (extension_count != 0)) return error.InvalidTarHeader;
    for (map[109..126]) |byte| if (byte != 0) return error.InvalidTarHeader;
    for (0..extension_count) |block| {
        const base = 126 + block * block_size;
        const expected_extended = block + 1 < extension_count;
        if ((map[base + 504] != 0) != expected_extended)
            return error.InvalidTarHeader;
        for (map[base + 505 .. base + block_size]) |byte|
            if (byte != 0) return error.InvalidTarHeader;
    }

    const slot_count = 4 + extension_count * 21;
    var count: usize = 0;
    var absent_seen = false;
    for (0..slot_count) |index| {
        const slot = try oldGnuSlot(map, index);
        const present = fieldPresent(slot[0..12]) or fieldPresent(slot[12..24]);
        if (!present) {
            absent_seen = true;
            continue;
        }
        if (absent_seen) return error.InvalidTarHeader;
        _ = try parseOldGnuNumber(slot[0..12]);
        _ = try parseOldGnuNumber(slot[12..24]);
        count = try checkedAdd(count, 1);
    }
    return validatePlan(.{
        .format = .gnu_old,
        .logical_size = logical_size,
        .extent_count = count,
        .map = map,
        .physical_size = 0,
    });
}

pub fn parsePax00(
    pax_payload: []const u8,
    declared_count: ?usize,
    logical_size: usize,
    data: []const u8,
) Error!Info {
    const plan = try inspectPax00(pax_payload, declared_count, logical_size);
    return infoFromPlan(plan, data);
}

/// Validates a GNU PAX sparse 0.0 map without requiring its stored file data.
pub fn inspectPax00(
    pax_payload: []const u8,
    declared_count: ?usize,
    logical_size: usize,
) Error!Plan {
    var cursor: usize = 0;
    var count: usize = 0;
    while (cursor < pax_payload.len) {
        const offset_record = try nextPaxRecord(pax_payload, &cursor);
        if (!std.mem.eql(u8, offset_record.key, "GNU.sparse.offset")) continue;
        const size_record = try nextPaxRecord(pax_payload, &cursor);
        if (!std.mem.eql(u8, size_record.key, "GNU.sparse.numbytes"))
            return error.InvalidTarHeader;
        _ = std.fmt.parseInt(usize, offset_record.value, 10) catch
            return error.InvalidTarHeader;
        _ = std.fmt.parseInt(usize, size_record.value, 10) catch
            return error.InvalidTarHeader;
        count = try checkedAdd(count, 1);
    }
    if (declared_count) |expected|
        if (count != expected) return error.InvalidTarHeader;
    return validatePlan(.{
        .format = .pax_0_0,
        .logical_size = logical_size,
        .extent_count = count,
        .map = pax_payload,
        .physical_size = 0,
    });
}

pub fn parsePax01(
    map: []const u8,
    declared_count: ?usize,
    logical_size: usize,
    data: []const u8,
) Error!Info {
    const plan = try inspectPax01(map, declared_count, logical_size);
    return infoFromPlan(plan, data);
}

/// Validates a GNU PAX sparse 0.1 map without requiring its stored file data.
pub fn inspectPax01(
    map: []const u8,
    declared_count: ?usize,
    logical_size: usize,
) Error!Plan {
    if (map.len == 0) return error.InvalidTarHeader;
    var cursor: usize = 0;
    var count: usize = 0;
    while (cursor < map.len) {
        _ = try parseDelimited(map, &cursor, ',');
        if (cursor >= map.len) return error.InvalidTarHeader;
        if (std.mem.indexOfScalarPos(u8, map, cursor, ',')) |_| {
            _ = try parseDelimited(map, &cursor, ',');
        } else {
            _ = try parseFinal(map, &cursor);
        }
        count = try checkedAdd(count, 1);
    }
    if (declared_count) |expected|
        if (count != expected) return error.InvalidTarHeader;
    return validatePlan(.{
        .format = .pax_0_1,
        .logical_size = logical_size,
        .extent_count = count,
        .map = map,
        .physical_size = 0,
    });
}

pub fn parsePax10(payload: []const u8, logical_size: usize) Error!Info {
    const map_end = try pax10MapLen(payload);
    const map_padded_len = try roundUpBlock(map_end);
    if (map_padded_len > payload.len) return error.InvalidTarHeader;
    for (payload[map_end..map_padded_len]) |byte|
        if (byte != 0) return error.InvalidTarHeader;
    const plan = try inspectPax10(payload[0..map_end], logical_size);
    return infoFromPlan(plan, payload[map_padded_len..]);
}

/// Validates a complete GNU PAX sparse 1.0 textual map. `map` ends immediately
/// after the final newline and does not include its zero block padding.
pub fn inspectPax10(map: []const u8, logical_size: usize) Error!Plan {
    const map_end = try pax10MapLen(map);
    if (map_end != map.len) return error.InvalidTarHeader;
    var cursor: usize = 0;
    const count = try parseDelimited(map, &cursor, '\n');
    return validatePlan(.{
        .format = .pax_1_0,
        .logical_size = logical_size,
        .extent_count = count,
        .map = map,
        .physical_size = 0,
    });
}

fn infoFromPlan(plan: Plan, data: []const u8) Error!Info {
    if (plan.physical_size != data.len) return error.InvalidTarHeader;
    return .{
        .format = plan.format,
        .logical_size = plan.logical_size,
        .extent_count = plan.extent_count,
        .map = plan.map,
        .data = data,
    };
}

fn validatePlan(plan_arg: Plan) Error!Plan {
    var plan = plan_arg;
    var iterator_value = plan.iterator();
    var previous_end: usize = 0;
    var physical_size: usize = 0;
    var count: usize = 0;
    while (try iterator_value.next()) |extent| {
        const end = try checkedAdd(extent.offset, extent.len);
        if (extent.offset < previous_end or end > plan.logical_size)
            return error.InvalidTarHeader;
        previous_end = end;
        physical_size = try checkedAdd(physical_size, extent.len);
        count = try checkedAdd(count, 1);
    }
    if (count != plan.extent_count) return error.InvalidTarHeader;
    plan.physical_size = physical_size;
    return plan;
}

fn pax10MapLen(bytes: []const u8) Error!usize {
    var cursor: usize = 0;
    const count = try parseDelimited(bytes, &cursor, '\n');
    for (0..count) |_| {
        _ = try parseDelimited(bytes, &cursor, '\n');
        _ = try parseDelimited(bytes, &cursor, '\n');
    }
    return cursor;
}

fn parseDelimited(bytes: []const u8, cursor: *usize, delimiter: u8) Error!usize {
    const end = std.mem.indexOfScalarPos(u8, bytes, cursor.*, delimiter) orelse
        return error.InvalidTarHeader;
    if (end == cursor.*) return error.InvalidTarHeader;
    const value = std.fmt.parseInt(usize, bytes[cursor.*..end], 10) catch
        return error.InvalidTarHeader;
    cursor.* = end + 1;
    return value;
}

fn parseFinal(bytes: []const u8, cursor: *usize) Error!usize {
    if (cursor.* == bytes.len) return error.InvalidTarHeader;
    const value = std.fmt.parseInt(usize, bytes[cursor.*..], 10) catch
        return error.InvalidTarHeader;
    cursor.* = bytes.len;
    return value;
}

const PaxRecord = struct {
    key: []const u8,
    value: []const u8,
};

fn nextPaxRecord(payload: []const u8, cursor: *usize) Error!PaxRecord {
    const space = std.mem.indexOfScalarPos(u8, payload, cursor.*, ' ') orelse
        return error.InvalidTarHeader;
    const record_len = std.fmt.parseInt(usize, payload[cursor.*..space], 10) catch
        return error.InvalidTarHeader;
    if (record_len == 0) return error.InvalidTarHeader;
    const end = try checkedAdd(cursor.*, record_len);
    if (end > payload.len or end <= space + 1 or payload[end - 1] != '\n')
        return error.InvalidTarHeader;
    const record = payload[space + 1 .. end - 1];
    const equals = std.mem.indexOfScalar(u8, record, '=') orelse
        return error.InvalidTarHeader;
    cursor.* = end;
    return .{ .key = record[0..equals], .value = record[equals + 1 ..] };
}

fn oldGnuSlot(map: []const u8, index: usize) Error!*const [24]u8 {
    const offset = if (index < 4)
        index * 24
    else blk: {
        const extension_index = index - 4;
        break :blk 126 + extension_index / 21 * block_size +
            extension_index % 21 * 24;
    };
    if (offset > map.len or map.len - offset < 24) return error.InvalidTarHeader;
    return map[offset..][0..24];
}

fn fieldPresent(field: []const u8) bool {
    for (field) |byte| if (byte != 0) return true;
    return false;
}

fn parseOldGnuNumber(field: []const u8) Error!usize {
    const trimmed = std.mem.trim(u8, field, " \x00");
    if (trimmed.len == 0) return 0;
    for (trimmed) |byte|
        if (byte < '0' or byte > '7') return error.InvalidTarHeader;
    return std.fmt.parseInt(usize, trimmed, 8) catch error.InvalidTarHeader;
}

fn roundUpBlock(value: usize) Error!usize {
    const remainder = value % block_size;
    return checkedAdd(value, if (remainder == 0) 0 else block_size - remainder);
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

test "GNU PAX sparse maps validate and reconstruct logical holes" {
    const map00 =
        "23 GNU.sparse.offset=0\n" ++
        "25 GNU.sparse.numbytes=4\n" ++
        "24 GNU.sparse.offset=12\n" ++
        "25 GNU.sparse.numbytes=3\n" ++
        "24 GNU.sparse.offset=20\n" ++
        "25 GNU.sparse.numbytes=0\n";
    const info00 = try parsePax00(map00, 3, 20, "HEADMID");
    var output00: [20]u8 = undefined;
    _ = try info00.extractInto(&output00);

    const map01 = "0,4,12,3,20,0";
    const info01 = try parsePax01(map01, 3, 20, "HEADMID");
    var output01: [20]u8 = undefined;
    try std.testing.expectEqual(output01.len, try info01.extractInto(&output01));
    try std.testing.expectEqualSlices(u8, "HEAD", output01[0..4]);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 8), output01[4..12]);
    try std.testing.expectEqualSlices(u8, "MID", output01[12..15]);
    try std.testing.expectEqualSlices(u8, &output00, &output01);

    var payload10: [block_size + 7]u8 = @splat(0);
    const map10 = "3\n0\n4\n12\n3\n20\n0\n";
    @memcpy(payload10[0..map10.len], map10);
    @memcpy(payload10[block_size..], "HEADMID");
    const info10 = try parsePax10(&payload10, 20);
    var output10: [20]u8 = undefined;
    _ = try info10.extractInto(&output10);
    try std.testing.expectEqualSlices(u8, &output01, &output10);
}

test "GNU PAX sparse maps reject overlap range count and physical mismatches" {
    try std.testing.expectError(
        error.InvalidTarHeader,
        parsePax01("0,4,3,2", 2, 16, "abcdef"),
    );
    try std.testing.expectError(
        error.InvalidTarHeader,
        parsePax01("0,4", 2, 16, "HEAD"),
    );
    try std.testing.expectError(
        error.InvalidTarHeader,
        parsePax01("0,4", 1, 3, "HEAD"),
    );
    try std.testing.expectError(
        error.InvalidTarHeader,
        parsePax01("0,4", 1, 16, "short"),
    );
}
