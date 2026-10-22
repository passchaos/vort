//! AOSP Zucchini Text Format reference extraction and rewriting.

const std = @import("std");
const intel = @import("intel.zig");

pub const Error = std.mem.Allocator.Error || error{
    InvalidReference,
    InvalidZtf,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const ReferenceType = enum(u5) {
    angles_abs1,
    angles_abs2,
    angles_abs3,
    angles_rel1,
    angles_rel2,
    angles_rel3,
    braces_abs1,
    braces_abs2,
    braces_abs3,
    braces_rel1,
    braces_rel2,
    braces_rel3,
    brackets_abs1,
    brackets_abs2,
    brackets_abs3,
    brackets_rel1,
    brackets_rel2,
    brackets_rel3,
    parentheses_abs1,
    parentheses_abs2,
    parentheses_abs3,
    parentheses_rel1,
    parentheses_rel2,
    parentheses_rel3,

    pub fn pool(self: ReferenceType) u8 {
        return @intCast(@intFromEnum(self) / 6);
    }
};

pub const pool_count: usize = 4;
pub const Reference = intel.Reference;

pub const Options = struct {
    max_lines: usize = 1000,
    max_references: usize = 1 << 24,
};

const LineCol = struct { line: i16, column: i16 };
const Config = struct {
    digits: u2,
    open: u8,
    close: u8,
    relative: bool,

    fn width(self: Config) usize {
        return @as(usize, self.digits) * 2 +
            if (self.relative) @as(usize, 5) else 3;
    }
};

pub const Executable = struct {
    allocator: std.mem.Allocator,
    image: []const u8,
    line_starts: []u32,
    references: [24][]Reference,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: Options,
    ) Error!Executable {
        if (input.len < 9 or input.len > std.math.maxInt(u32) or
            !std.mem.eql(u8, input[0..4], "ZTxt"))
        {
            return error.InvalidZtf;
        }
        const footer = findFooter(input) orelse return error.InvalidZtf;
        if (footer + 5 != input.len) return error.InvalidZtf;
        var starts: std.ArrayList(u32) = .empty;
        errdefer starts.deinit(allocator);
        try starts.append(allocator, 0);
        for (input, 0..) |byte, index| {
            if (byte != '\n') continue;
            if (starts.items.len >= options.max_lines or starts.items.len >= 1000)
                return error.OutputLimitExceeded;
            const next: u32 = @intCast(index + 1);
            if (next - starts.items[starts.items.len - 1] >= 1000)
                return error.InvalidZtf;
            try starts.append(allocator, next);
        }
        if (starts.items[starts.items.len - 1] != input.len)
            return error.InvalidZtf;
        const line_starts = try starts.toOwnedSlice(allocator);
        errdefer allocator.free(line_starts);

        var lists: [24]std.ArrayList(Reference) = @splat(.empty);
        errdefer for (&lists) |*list| list.deinit(allocator);
        for (std.enums.values(ReferenceType)) |reference_type|
            try collectType(
                allocator,
                input,
                line_starts,
                reference_type,
                &lists[@intFromEnum(reference_type)],
                options.max_references,
            );
        var references: [24][]Reference = undefined;
        var converted: usize = 0;
        errdefer for (references[0..converted]) |slice| allocator.free(slice);
        for (&lists, 0..) |*list, index| {
            references[index] = try list.toOwnedSlice(allocator);
            converted += 1;
        }
        return .{
            .allocator = allocator,
            .image = input,
            .line_starts = line_starts,
            .references = references,
        };
    }

    pub fn deinit(self: *Executable) void {
        for (self.references) |references| self.allocator.free(references);
        self.allocator.free(self.line_starts);
        self.* = undefined;
    }

    pub fn referencesInRange(
        self: Executable,
        reference_type: ReferenceType,
        low: u32,
        high: u32,
    ) []const Reference {
        const references = self.references[@intFromEnum(reference_type)];
        return references[lowerBound(references, low)..lowerBound(references, high)];
    }

    pub fn writeReference(
        self: Executable,
        image: []u8,
        reference_type: ReferenceType,
        reference: Reference,
    ) Error!void {
        if (image.len != self.image.len) return error.InvalidReference;
        const config = configFor(reference_type);
        const target = offsetToLineCol(self.line_starts, reference.target) orelse
            return error.InvalidReference;
        const value = if (config.relative) blk: {
            const location = offsetToLineCol(self.line_starts, reference.location) orelse
                return error.InvalidReference;
            break :blk LineCol{
                .line = target.line - location.line,
                .column = target.column - location.column,
            };
        } else target;
        try writeValue(image, reference.location, config, value);
    }
};

fn collectType(
    allocator: std.mem.Allocator,
    image: []const u8,
    line_starts: []const u32,
    reference_type: ReferenceType,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const config = configFor(reference_type);
    var cursor: usize = 0;
    while (cursor < image.len) {
        const value = parseAt(image, cursor, config) orelse {
            cursor += 1;
            continue;
        };
        const target_line_col = if (config.relative) blk: {
            const location = offsetToLineCol(line_starts, @intCast(cursor)) orelse {
                cursor += 1;
                continue;
            };
            const line = @as(i32, location.line) + value.line;
            const column = @as(i32, location.column) + value.column;
            if (line < std.math.minInt(i16) or line > std.math.maxInt(i16) or
                column < std.math.minInt(i16) or column > std.math.maxInt(i16))
            {
                cursor += 1;
                continue;
            }
            break :blk LineCol{ .line = @intCast(line), .column = @intCast(column) };
        } else value;
        const target = lineColToOffset(line_starts, target_line_col) orelse {
            cursor += 1;
            continue;
        };
        if (output.items.len >= max_references) return error.OutputLimitExceeded;
        try output.append(allocator, .{
            .location = @intCast(cursor),
            .target = target,
        });
        cursor += config.width();
    }
}

fn parseAt(image: []const u8, offset: usize, config: Config) ?LineCol {
    const width = config.width();
    if (!rangeFits(offset, width, image.len) or image[offset] != config.open)
        return null;
    var cursor = offset + 1;
    var line_sign: i16 = 1;
    var column_sign: i16 = 1;
    if (config.relative) {
        line_sign = parseSign(image[cursor]) orelse return null;
        cursor += 1;
    }
    const line = parseDigits(image[cursor..][0..config.digits]) orelse return null;
    cursor += config.digits;
    if (image[cursor] != ',') return null;
    cursor += 1;
    if (config.relative) {
        column_sign = parseSign(image[cursor]) orelse return null;
        cursor += 1;
    }
    const column = parseDigits(image[cursor..][0..config.digits]) orelse return null;
    cursor += config.digits;
    if (image[cursor] != config.close or
        (line == 0 and line_sign < 0) or (column == 0 and column_sign < 0))
    {
        return null;
    }
    return .{ .line = line * line_sign, .column = column * column_sign };
}

fn writeValue(
    image: []u8,
    location: u32,
    config: Config,
    value: LineCol,
) Error!void {
    const bound: i16 = switch (config.digits) {
        1 => 10,
        2 => 100,
        3 => 1000,
        else => unreachable,
    };
    if (@abs(value.line) >= bound or @abs(value.column) >= bound or
        !rangeFits(location, config.width(), image.len))
    {
        return error.InvalidReference;
    }
    for (image[location..][0..config.width()]) |byte|
        if (byte == '\n') return error.InvalidReference;
    var cursor: usize = location;
    image[cursor] = config.open;
    cursor += 1;
    if (config.relative) {
        image[cursor] = if (value.line < 0) '-' else '+';
        cursor += 1;
    }
    writeDigits(image[cursor..][0..config.digits], value.line);
    cursor += config.digits;
    image[cursor] = ',';
    cursor += 1;
    if (config.relative) {
        image[cursor] = if (value.column < 0) '-' else '+';
        cursor += 1;
    }
    writeDigits(image[cursor..][0..config.digits], value.column);
    cursor += config.digits;
    image[cursor] = config.close;
}

fn configFor(reference_type: ReferenceType) Config {
    const ordinal: u8 = @intFromEnum(reference_type);
    const pool = ordinal / 6;
    const variant = ordinal % 6;
    const pair: [2]u8 = switch (pool) {
        0 => .{ '<', '>' },
        1 => .{ '{', '}' },
        2 => .{ '[', ']' },
        3 => .{ '(', ')' },
        else => unreachable,
    };
    return .{
        .digits = @intCast(variant % 3 + 1),
        .open = pair[0],
        .close = pair[1],
        .relative = variant >= 3,
    };
}

fn lineColToOffset(starts: []const u32, value: LineCol) ?u32 {
    if (value.line < 1 or value.column < 1) return null;
    const line: usize = @intCast(value.line);
    if (line >= starts.len) return null;
    const length = starts[line] - starts[line - 1];
    if (value.column > length) return null;
    return starts[line - 1] + @as(u32, @intCast(value.column - 1));
}

fn offsetToLineCol(starts: []const u32, offset: u32) ?LineCol {
    if (offset >= starts[starts.len - 1]) return null;
    var low: usize = 0;
    var high = starts.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (starts[mid] <= offset) low = mid + 1 else high = mid;
    }
    if (low == 0) return null;
    return .{
        .line = @intCast(low),
        .column = @intCast(offset - starts[low - 1] + 1),
    };
}

fn findFooter(image: []const u8) ?usize {
    var offset: usize = 0;
    while (offset + 5 <= image.len) : (offset += 1)
        if (std.mem.eql(u8, image[offset..][0..5], "txTZ\n")) return offset;
    return null;
}

fn parseSign(byte: u8) ?i16 {
    return switch (byte) {
        '+' => 1,
        '-' => -1,
        else => null,
    };
}

fn parseDigits(bytes: []const u8) ?i16 {
    var value: i16 = 0;
    for (bytes) |byte| {
        if (byte < '0' or byte > '9') return null;
        value = value * 10 + byte - '0';
    }
    return value;
}

fn writeDigits(output: []u8, input: i16) void {
    var value: u16 = @intCast(@abs(input));
    var cursor = output.len;
    while (cursor != 0) {
        cursor -= 1;
        output[cursor] = @intCast('0' + value % 10);
        value /= 10;
    }
}

fn lowerBound(references: []const Reference, location: u32) usize {
    var low: usize = 0;
    var high = references.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (references[mid].location < location) low = mid + 1 else high = mid;
    }
    return low;
}

fn rangeFits(offset: anytype, length: anytype, total: usize) bool {
    const start = std.math.cast(usize, offset) orelse return false;
    const size = std.math.cast(usize, length) orelse return false;
    return start <= total and size <= total - start;
}

comptime {
    if (@typeInfo(ReferenceType).@"enum".fields.len != 24)
        @compileError("ZTF reference type count drift");
}

test "Zucchini ZTF reads and writes absolute and relative references" {
    const source = "ZTxt\nTargetABC\nRef <2,1> {-1,+0}\ntxTZ\n";
    var executable = try Executable.initAlloc(std.testing.allocator, source, .{});
    defer executable.deinit();
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 19,
        .target = 5,
    }}, executable.references[@intFromEnum(ReferenceType.angles_abs1)]);
    var modified: [source.len]u8 = source.*;
    try executable.writeReference(&modified, .angles_abs1, .{
        .location = 19,
        .target = 6,
    });
    try std.testing.expectEqualStrings("<2,2>", modified[19..24]);
}

test "Zucchini ZTF rejects malformed input and enforces quotas" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidZtf,
        Executable.initAlloc(allocator, "ZTxt\nmissing footer\n", .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Executable.initAlloc(allocator, "ZTxt\ntxTZ\n", .{ .max_lines = 1 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Executable.initAlloc(
            allocator,
            "ZTxt\n<1,1>\ntxTZ\n",
            .{ .max_references = 0 },
        ),
    );
    var executable = try Executable.initAlloc(
        allocator,
        "ZTxt\n<-0,+0>\ntxTZ\n",
        .{},
    );
    defer executable.deinit();
    try std.testing.expectEqual(
        @as(usize, 0),
        executable.references[@intFromEnum(ReferenceType.angles_rel1)].len,
    );
}
