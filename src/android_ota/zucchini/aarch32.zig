//! Zucchini AArch32 ELF reference extraction and rewriting.

const std = @import("std");
const codec = @import("aarch32_codec.zig");
const intel = @import("intel.zig");

pub const Error = std.mem.Allocator.Error || error{
    InvalidElf,
    InvalidReference,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const ReferenceType = codec.ReferenceType;

pub const pool_count: usize = 3;
pub const Reference = intel.Reference;

pub const Options = struct {
    max_sections: usize = 1 << 20,
    max_references: usize = 1 << 24,
};

const image_size_bound = 0x7fff_0000;
const arm_relative_relocation = 23;

const Section = struct {
    kind: u32,
    flags: u32,
    address: u32,
    offset: u32,
    size: u32,
    entry_size: u32,
    useful: bool,

    fn isExecutable(self: Section) bool {
        return self.useful and self.kind == 1 and self.flags & 4 != 0;
    }
};

const ExecRange = struct {
    offset: u32,
    size: u32,
};

pub const Executable = struct {
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: intel.Translator,
    sections: []Section,
    references: [7][]Reference,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        image: []const u8,
        options: Options,
    ) Error!Executable {
        if (image.len < 52 or image.len >= image_size_bound or
            !std.mem.eql(u8, image[0..4], "\x7fELF") or
            image[4] != 1 or image[5] != 1 or image[6] != 1 or
            (readU16(image, 16) != 2 and readU16(image, 16) != 3) or
            readU16(image, 18) != 40 or readU32(image, 20) != 1 or
            readU16(image, 46) != 40)
        {
            return error.InvalidElf;
        }
        const program_offset: usize = readU32(image, 28);
        const section_offset: usize = readU32(image, 32);
        const program_count: usize = readU16(image, 44);
        const section_count: usize = readU16(image, 48);
        const string_index: usize = readU16(image, 50);
        if (section_count > options.max_sections)
            return error.OutputLimitExceeded;
        if (section_count == 0 or string_index >= section_count)
            return error.InvalidElf;
        const program_bytes = try checkedMul(program_count, 32);
        const section_bytes = try checkedMul(section_count, 40);
        if (!rangeFits(program_offset, program_bytes, image.len) or
            !rangeFits(section_offset, section_bytes, image.len))
        {
            return error.InvalidElf;
        }
        var physical_end = @max(
            program_offset + program_bytes,
            section_offset + section_bytes,
        );
        const sections = try allocator.alloc(Section, section_count);
        errdefer allocator.free(sections);
        var units: std.ArrayList(intel.Unit) = .empty;
        defer units.deinit(allocator);
        try units.ensureTotalCapacity(allocator, section_count);
        for (sections, 0..) |*section, index| {
            const base = section_offset + index * 40;
            const kind = readU32(image, base + 4);
            const flags = readU32(image, base + 8);
            const address = readU32(image, base + 12);
            const file_offset = readU32(image, base + 16);
            const size = readU32(image, base + 20);
            const entry_size = readU32(image, base + 36);
            if (!rangeFitsU32(address, size, image_size_bound))
                return error.InvalidElf;
            const no_bits = kind == 8;
            if (!rangeFits(file_offset, size, if (no_bits) image_size_bound else image.len))
                return error.InvalidElf;
            const useful = size != 0 and address != 0;
            section.* = .{
                .kind = kind,
                .flags = flags,
                .address = address,
                .offset = file_offset,
                .size = size,
                .entry_size = entry_size,
                .useful = useful and !no_bits,
            };
            if (useful) units.appendAssumeCapacity(.{
                .offset = file_offset,
                .size = size,
                .rva = address,
                .rva_size = size,
            });
            if (useful and !no_bits)
                physical_end = @max(physical_end, @as(usize, file_offset) + size);
        }
        const strings = sections[string_index];
        if (strings.size != 0 and
            (!rangeFits(strings.offset, strings.size, image.len) or
                image[@as(usize, strings.offset) + strings.size - 1] != 0))
        {
            return error.InvalidElf;
        }
        for (0..program_count) |index| {
            const base = program_offset + index * 32;
            const file_offset: usize = readU32(image, base + 4);
            const file_size: usize = readU32(image, base + 16);
            if (!rangeFits(file_offset, file_size, image.len))
                return error.InvalidElf;
            physical_end = @max(physical_end, file_offset + file_size);
        }
        if (physical_end != image.len) return error.InvalidElf;
        var translator = intel.initTranslatorAlloc(allocator, units.items) catch |err|
            return mapTranslatorError(err);
        errdefer translator.deinit(allocator);

        var lists: [7]std.ArrayList(Reference) = @splat(.empty);
        errdefer for (&lists) |*list| list.deinit(allocator);
        try collectRelocations(
            allocator,
            image,
            sections,
            translator,
            &lists[@intFromEnum(ReferenceType.relocation)],
            options.max_references,
        );
        try collectAbsolute(
            allocator,
            image,
            translator,
            lists[@intFromEnum(ReferenceType.relocation)].items,
            &lists[@intFromEnum(ReferenceType.absolute)],
            options.max_references,
        );
        try collectBranches(
            allocator,
            image,
            sections,
            translator,
            lists[@intFromEnum(ReferenceType.absolute)].items,
            &lists,
            options.max_references,
        );
        var references: [7][]Reference = undefined;
        var converted: usize = 0;
        errdefer for (references[0..converted]) |slice| allocator.free(slice);
        for (&lists, 0..) |*list, index| {
            references[index] = try list.toOwnedSlice(allocator);
            converted += 1;
        }
        return .{
            .allocator = allocator,
            .image = image,
            .translator = translator,
            .sections = sections,
            .references = references,
        };
    }

    pub fn deinit(self: *Executable) void {
        for (self.references) |references| self.allocator.free(references);
        self.allocator.free(self.sections);
        self.translator.deinit(self.allocator);
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
        const location: usize = reference.location;
        const target_rva = self.translator.offsetToRva(reference.target) orelse
            return error.InvalidReference;
        switch (reference_type) {
            .relocation, .absolute => {
                if (!rangeFits(location, 4, image.len))
                    return error.InvalidReference;
                std.mem.writeInt(u32, image[location..][0..4], target_rva, .little);
            },
            .a24, .t8, .t11, .t20, .t24 => {
                const instruction_rva = self.translator.offsetToRva(reference.location) orelse
                    return error.InvalidReference;
                try codec.writeBranch(
                    image,
                    reference_type,
                    reference.location,
                    instruction_rva,
                    target_rva,
                );
            },
        }
    }
};

fn collectRelocations(
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: intel.Translator,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    for (sections) |section| {
        const rel_size: u32 = 8;
        const rela_size: u32 = 12;
        if (!section.useful or
            !((section.kind == 9 and section.entry_size == rel_size) or
                (section.kind == 4 and section.entry_size == rela_size)))
            continue;
        var cursor: usize = section.offset;
        const end = cursor + section.size;
        while (cursor + section.entry_size <= end) : (cursor += section.entry_size) {
            const target_rva = readU32(image, cursor);
            const relocation_type: u8 = @truncate(readU32(image, cursor + 4));
            if (relocation_type != arm_relative_relocation) continue;
            const target = translator.rvaToOffset(target_rva) orelse continue;
            if (!rangeFits(target, 4, image.len)) continue;
            if (output.items.len >= max_references) return error.OutputLimitExceeded;
            try output.append(allocator, .{
                .location = @intCast(cursor),
                .target = target,
            });
        }
    }
    std.mem.sort(Reference, output.items, {}, lessReference);
}

fn collectAbsolute(
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: intel.Translator,
    relocations: []const Reference,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const locations = try allocator.alloc(u32, relocations.len);
    defer allocator.free(locations);
    for (relocations, locations) |reference, *location| location.* = reference.target;
    std.mem.sort(u32, locations, {}, std.sort.asc(u32));
    var previous_end: usize = 0;
    for (locations) |location| {
        if (location < previous_end or !rangeFits(location, 4, image.len)) continue;
        const target_rva = readU32(image, location);
        if (target_rva >= intel.offset_bound) continue;
        const target = translator.rvaToOffset(target_rva) orelse continue;
        if (output.items.len >= max_references) return error.OutputLimitExceeded;
        try output.append(allocator, .{ .location = location, .target = target });
        previous_end = @as(usize, location) + 4;
    }
}

fn collectBranches(
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: intel.Translator,
    absolutes: []const Reference,
    lists: *[7]std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    var exec_ranges: std.ArrayList(ExecRange) = .empty;
    defer exec_ranges.deinit(allocator);
    for (sections) |section|
        if (section.isExecutable())
            try exec_ranges.append(allocator, .{ .offset = section.offset, .size = section.size });
    std.mem.sort(ExecRange, exec_ranges.items, {}, lessExecRange);

    for (sections) |section| {
        if (!section.isExecutable()) continue;
        const thumb = isThumbSection(image, section);
        var cursor: usize = section.offset;
        const end = cursor + section.size;
        var absolute_index = lowerBound(absolutes, section.offset);
        if (absolute_index != 0) {
            const previous = absolutes[absolute_index - 1];
            if (@as(usize, previous.location) + 4 > cursor)
                cursor = @min(end, @as(usize, previous.location) + 4);
        }
        while (absolute_index < absolutes.len and absolutes[absolute_index].location < end) : (absolute_index += 1) {
            const absolute = absolutes[absolute_index];
            const gap_end = @min(end, @as(usize, absolute.location));
            try scanBranchRange(
                allocator,
                image,
                translator,
                exec_ranges.items,
                thumb,
                cursor,
                gap_end,
                lists,
                max_references,
            );
            cursor = @min(end, @as(usize, absolute.location) + 4);
        }
        try scanBranchRange(
            allocator,
            image,
            translator,
            exec_ranges.items,
            thumb,
            cursor,
            end,
            lists,
            max_references,
        );
    }
    inline for (.{
        ReferenceType.a24,
        ReferenceType.t8,
        ReferenceType.t11,
        ReferenceType.t20,
        ReferenceType.t24,
    }) |reference_type| {
        std.mem.sort(
            Reference,
            lists[@intFromEnum(reference_type)].items,
            {},
            lessReference,
        );
    }
}

fn scanBranchRange(
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: intel.Translator,
    exec_ranges: []const ExecRange,
    thumb: bool,
    start: usize,
    end: usize,
    lists: *[7]std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    if (start >= end) return;
    var cursor = alignForward(start, if (thumb) 2 else 4);
    while (cursor < end) {
        const reference_type, const instruction_size = if (thumb) blk: {
            if (end - cursor < 2) break;
            const code16 = readU16(image, cursor);
            const size: usize = codec.thumbInstructionSize(code16);
            if (end - cursor < size) break;
            if (size == 2) {
                if (codec.decodeT8(code16) != null)
                    break :blk .{ ReferenceType.t8, size };
                if (codec.decodeT11(code16) != null)
                    break :blk .{ ReferenceType.t11, size };
            } else {
                const code32 = codec.fetchThumb32(image, cursor);
                if (codec.decodeT20(code32) != null)
                    break :blk .{ ReferenceType.t20, size };
                if (codec.decodeT24(code32) != null)
                    break :blk .{ ReferenceType.t24, size };
            }
            cursor += size;
            continue;
        } else blk: {
            if (end - cursor < 4) break;
            if (codec.decodeA24(readU32(image, cursor)) == null) {
                cursor += 4;
                continue;
            }
            break :blk .{ ReferenceType.a24, @as(usize, 4) };
        };
        const location: u32 = @intCast(cursor);
        const instruction_rva = translator.offsetToRva(location) orelse {
            cursor += instruction_size;
            continue;
        };
        const target_rva = codec.readBranch(
            image,
            reference_type,
            location,
            instruction_rva,
        ) orelse {
            cursor += instruction_size;
            continue;
        };
        const target = translator.rvaToOffset(target_rva) orelse {
            cursor += instruction_size;
            continue;
        };
        if (containsOffset(exec_ranges, target)) {
            const output = &lists[@intFromEnum(reference_type)];
            if (output.items.len >= max_references)
                return error.OutputLimitExceeded;
            try output.append(allocator, .{ .location = location, .target = target });
        }
        cursor += instruction_size;
    }
}

fn isThumbSection(image: []const u8, section: Section) bool {
    return codec.isThumbSection(
        image,
        section.address,
        section.offset,
        section.size,
    );
}

fn alignForward(value: usize, alignment: usize) usize {
    return (value + alignment - 1) & ~(alignment - 1);
}

fn containsOffset(ranges: []const ExecRange, offset: u32) bool {
    var low: usize = 0;
    var high = ranges.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (ranges[mid].offset <= offset) low = mid + 1 else high = mid;
    }
    if (low == 0) return false;
    const range = ranges[low - 1];
    return offset - range.offset < range.size;
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

fn lessReference(_: void, left: Reference, right: Reference) bool {
    return left.location < right.location;
}

fn lessExecRange(_: void, left: ExecRange, right: ExecRange) bool {
    return left.offset < right.offset;
}

fn mapTranslatorError(err: intel.Error) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.OutputLimitExceeded => error.OutputLimitExceeded,
        error.IntegerOverflow => error.IntegerOverflow,
        error.InvalidElf, error.InvalidReference => error.InvalidElf,
    };
}

fn checkedMul(left: usize, right: usize) Error!usize {
    return std.math.mul(usize, left, right) catch error.IntegerOverflow;
}

fn rangeFits(offset: anytype, length: anytype, total: usize) bool {
    const start = std.math.cast(usize, offset) orelse return false;
    const size = std.math.cast(usize, length) orelse return false;
    return start <= total and size <= total - start;
}

fn rangeFitsU32(offset: u32, length: u32, total: u32) bool {
    return offset <= total and length <= total - offset;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

test "Zucchini AArch32 Thumb-2 scanner matches AOSP vectors" {
    const allocator = std.testing.allocator;
    const data = [_]u8{
        0x00, 0xde, 0x00, 0xde, 0x00, 0xde, 0x00, 0xde,
        0x00, 0xe0, 0x00, 0xe0, 0x00, 0xe0, 0x00, 0xe0,
        0x00, 0xf0, 0x00, 0x80, 0x00, 0xf0, 0x00, 0x80,
        0x00, 0xf0, 0x00, 0x80, 0x00, 0xf0, 0x00, 0x80,
        0x00, 0xf0, 0x00, 0xb8, 0x00, 0xf0, 0x00, 0xb8,
        0xfe, 0xde, 0x00, 0xf0, 0x00, 0xf8, 0x00, 0xf0,
        0x00, 0xe8, 0x00, 0x0b, 0x00, 0xf0, 0x00, 0xe8,
        0x00, 0xf0, 0x00, 0xb8,
    };
    var image: [0x40]u8 = @splat(0);
    @memcpy(image[0..data.len], &data);
    var translator = try intel.initTranslatorAlloc(allocator, &.{.{
        .offset = 0,
        .size = image.len,
        .rva = 0,
        .rva_size = image.len,
    }});
    defer translator.deinit(allocator);
    var lists: [7]std.ArrayList(Reference) = @splat(.empty);
    defer for (&lists) |*list| list.deinit(allocator);
    try scanBranchRange(
        allocator,
        &image,
        translator,
        &.{.{ .offset = 0, .size = image.len }},
        true,
        0,
        data.len,
        &lists,
        32,
    );
    try std.testing.expectEqualSlices(Reference, &.{
        .{ .location = 0x00, .target = 0x04 },
        .{ .location = 0x02, .target = 0x06 },
        .{ .location = 0x04, .target = 0x08 },
        .{ .location = 0x06, .target = 0x0a },
        .{ .location = 0x28, .target = 0x28 },
    }, lists[@intFromEnum(ReferenceType.t8)].items);
    try std.testing.expectEqualSlices(Reference, &.{
        .{ .location = 0x08, .target = 0x0c },
        .{ .location = 0x0a, .target = 0x0e },
        .{ .location = 0x0c, .target = 0x10 },
        .{ .location = 0x0e, .target = 0x12 },
    }, lists[@intFromEnum(ReferenceType.t11)].items);
    try std.testing.expectEqualSlices(Reference, &.{
        .{ .location = 0x10, .target = 0x14 },
        .{ .location = 0x14, .target = 0x18 },
        .{ .location = 0x18, .target = 0x1c },
        .{ .location = 0x1c, .target = 0x20 },
    }, lists[@intFromEnum(ReferenceType.t20)].items);
    try std.testing.expectEqualSlices(Reference, &.{
        .{ .location = 0x20, .target = 0x24 },
        .{ .location = 0x24, .target = 0x28 },
        .{ .location = 0x2a, .target = 0x2e },
        .{ .location = 0x2e, .target = 0x30 },
        .{ .location = 0x34, .target = 0x38 },
        .{ .location = 0x38, .target = 0x3c },
    }, lists[@intFromEnum(ReferenceType.t24)].items);
}

test "Zucchini AArch32 reproduces AOSP ARM versus Thumb-2 heuristic" {
    const arm = [_]u8{
        0x00, 0x00, 0xa0, 0xe1,
        0x00, 0x00, 0xa0, 0xe1,
        0x00, 0x00, 0xa0, 0xe1,
        0x00, 0x00, 0xa0, 0xe1,
    };
    const thumb = [_]u8{
        0x00, 0xde, 0x00, 0xde,
        0x00, 0xf0, 0x00, 0x80,
        0x00, 0xf0, 0x00, 0xb8,
        0x00, 0x0b, 0x00, 0xf0,
    };
    const section = Section{
        .kind = 1,
        .flags = 6,
        .address = 0x10000,
        .offset = 0,
        .size = arm.len,
        .entry_size = 0,
        .useful = true,
    };
    try std.testing.expect(!isThumbSection(&arm, section));
    try std.testing.expect(isThumbSection(&thumb, section));
    var unaligned = section;
    unaligned.address += 2;
    try std.testing.expect(isThumbSection(&arm, unaligned));
}

test "Zucchini AArch32 ELF extracts and rewrites every reference pool" {
    const allocator = std.testing.allocator;
    const image = testElf(0x108);
    var executable = try Executable.initAlloc(allocator, &image, .{});
    defer executable.deinit();
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 0x160,
        .target = 0x140,
    }}, executable.references[@intFromEnum(ReferenceType.relocation)]);
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 0x140,
        .target = 0x108,
    }}, executable.references[@intFromEnum(ReferenceType.absolute)]);
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 0x100,
        .target = 0x108,
    }}, executable.references[@intFromEnum(ReferenceType.a24)]);

    var modified = image;
    try executable.writeReference(&modified, .relocation, .{
        .location = 0x160,
        .target = 0x144,
    });
    try executable.writeReference(&modified, .absolute, .{
        .location = 0x140,
        .target = 0x10c,
    });
    try executable.writeReference(&modified, .a24, .{
        .location = 0x100,
        .target = 0x10c,
    });
    try std.testing.expectEqual(@as(u32, 0x20004), readU32(&modified, 0x160));
    try std.testing.expectEqual(@as(u32, 0x1000c), readU32(&modified, 0x140));
    try std.testing.expectEqual(@as(u32, 0xea00_0001), readU32(&modified, 0x100));
}

test "Zucchini AArch32 ELF rejects malformed and quota-exceeding images" {
    const allocator = std.testing.allocator;
    var image = testElf(0x108);
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Executable.initAlloc(allocator, &image, .{ .max_sections = 3 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Executable.initAlloc(allocator, &image, .{ .max_references = 0 }),
    );
    image[5] = 2;
    try std.testing.expectError(
        error.InvalidElf,
        Executable.initAlloc(allocator, &image, .{}),
    );
    image = testElf(0x108);
    std.mem.writeInt(u32, image[32..36], 0xffff_ffff, .little);
    try std.testing.expectError(
        error.InvalidElf,
        Executable.initAlloc(allocator, &image, .{}),
    );
}

pub fn testElf(target_offset: u32) [0x3a0]u8 {
    var output: [0x3a0]u8 = @splat(0);
    @memcpy(output[0..4], "\x7fELF");
    output[4] = 1;
    output[5] = 1;
    output[6] = 1;
    std.mem.writeInt(u16, output[16..18], 2, .little);
    std.mem.writeInt(u16, output[18..20], 40, .little);
    std.mem.writeInt(u32, output[20..24], 1, .little);
    std.mem.writeInt(u32, output[32..36], 0x300, .little);
    std.mem.writeInt(u16, output[40..42], 52, .little);
    std.mem.writeInt(u16, output[42..44], 32, .little);
    std.mem.writeInt(u16, output[46..48], 40, .little);
    std.mem.writeInt(u16, output[48..50], 4, .little);
    writeTestSection(&output, 1, 1, 6, 0x10000, 0x100, 0x20, 0);
    writeTestSection(&output, 2, 1, 3, 0x20000, 0x140, 0x08, 0);
    writeTestSection(&output, 3, 9, 2, 0x30000, 0x160, 0x08, 8);
    var cursor: usize = 0x100;
    while (cursor < 0x120) : (cursor += 4)
        std.mem.writeInt(u32, output[cursor..][0..4], 0xe1a0_0000, .little);
    var branch: u32 = 0xea00_0000;
    std.debug.assert(codec.encodeA24(@as(i64, target_offset) - 0x108, &branch));
    std.mem.writeInt(u32, output[0x100..0x104], branch, .little);
    std.mem.writeInt(u32, output[0x140..0x144], 0x10008, .little);
    std.mem.writeInt(u32, output[0x160..0x164], 0x20000, .little);
    std.mem.writeInt(u32, output[0x164..0x168], arm_relative_relocation, .little);
    return output;
}

fn writeTestSection(
    output: []u8,
    index: usize,
    kind: u32,
    flags: u32,
    address: u32,
    offset: u32,
    size: u32,
    entry_size: u32,
) void {
    const base = 0x300 + index * 40;
    std.mem.writeInt(u32, output[base + 4 ..][0..4], kind, .little);
    std.mem.writeInt(u32, output[base + 8 ..][0..4], flags, .little);
    std.mem.writeInt(u32, output[base + 12 ..][0..4], address, .little);
    std.mem.writeInt(u32, output[base + 16 ..][0..4], offset, .little);
    std.mem.writeInt(u32, output[base + 20 ..][0..4], size, .little);
    std.mem.writeInt(u32, output[base + 36 ..][0..4], entry_size, .little);
}
