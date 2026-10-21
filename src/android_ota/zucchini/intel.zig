//! Zucchini Intel reference primitives and ELF extraction/rewriting.

const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{
    InvalidElf,
    InvalidReference,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const ReferenceType = enum(u2) {
    relocation = 0,
    absolute = 1,
    relative = 2,

    pub fn pool(self: ReferenceType) u8 {
        return @intFromEnum(self);
    }
};

pub const pool_count: usize = 3;

pub const Reference = struct {
    location: u32,
    target: u32,
};

pub const Options = struct {
    max_sections: usize = 1 << 20,
    max_references: usize = 1 << 24,
};

pub const Kind = enum { x86, x64 };
pub const offset_bound = std.math.maxInt(u32) / 2;
const image_size_bound = 0x7fff_0000;

pub const X86 = Architecture(.x86);
pub const X64 = Architecture(.x64);

fn Architecture(comptime kind: Kind) type {
    return struct {
        pub const ReferenceType = @import("intel.zig").ReferenceType;
        pub const pool_count = @import("intel.zig").pool_count;
        pub const Executable = ElfImpl(kind);
    };
}

const Section = struct {
    kind: u32,
    flags: u64,
    address: u32,
    offset: u32,
    size: u32,
    entry_size: u32,
    useful: bool,
};

pub const Unit = struct {
    offset: u32,
    size: u32,
    rva: u32,
    rva_size: u32,

    fn offsetEnd(self: Unit) u32 {
        return self.offset + self.size;
    }

    fn rvaEnd(self: Unit) u32 {
        return self.rva + self.rva_size;
    }

    fn hasDanglingRva(self: Unit) bool {
        return self.rva_size > self.size;
    }
};

pub const Translator = struct {
    by_offset: []Unit,
    by_rva: []Unit,
    fake_offset_begin: u32,

    pub fn deinit(self: *Translator, allocator: std.mem.Allocator) void {
        allocator.free(self.by_offset);
        allocator.free(self.by_rva);
        self.* = undefined;
    }

    pub fn offsetToRva(self: Translator, offset: u32) ?u32 {
        if (offset >= self.fake_offset_begin) {
            const rva = offset - self.fake_offset_begin;
            const unit = findUnitRva(self.by_rva, rva) orelse return null;
            if (unit.rva_size <= unit.size or rva - unit.rva < unit.size)
                return null;
            return rva;
        }
        const unit = findUnitOffset(self.by_offset, offset) orelse return null;
        return offset - unit.offset + unit.rva;
    }

    pub fn rvaToOffset(self: Translator, rva: u32) ?u32 {
        const unit = findUnitRva(self.by_rva, rva) orelse return null;
        const delta = rva - unit.rva;
        return if (delta < unit.size)
            unit.offset + delta
        else
            self.fake_offset_begin + rva;
    }
};

fn ElfImpl(comptime kind: Kind) type {
    const is_64 = kind == .x64;
    const expected_class: u8 = if (is_64) 2 else 1;
    const expected_machine: u16 = if (is_64) 62 else 3;
    const header_len: usize = if (is_64) 64 else 52;
    const program_entry_len: usize = if (is_64) 56 else 32;
    const section_entry_len: usize = if (is_64) 64 else 40;
    const value_width: usize = if (is_64) 8 else 4;

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        image: []const u8,
        translator: Translator,
        sections: []Section,
        references: [3][]Reference,

        pub fn initAlloc(
            allocator: std.mem.Allocator,
            image: []const u8,
            options: Options,
        ) Error!Self {
            if (image.len < header_len or image.len >= image_size_bound or
                !std.mem.eql(u8, image[0..4], "\x7fELF") or
                image[4] != expected_class or image[5] != 1 or image[6] != 1 or
                (readU16(image, 16) != 2 and readU16(image, 16) != 3) or
                readU16(image, 18) != expected_machine or readU32(image, 20) != 1)
            {
                return error.InvalidElf;
            }
            const program_offset = try headerOffset(image, true);
            const section_offset = try headerOffset(image, false);
            const program_count_offset: usize = if (is_64) 56 else 44;
            const section_size_offset: usize = if (is_64) 58 else 46;
            const section_count_offset: usize = if (is_64) 60 else 48;
            const string_index_offset: usize = if (is_64) 62 else 50;
            // AOSP Zucchini intentionally ignores e_phentsize and reads the
            // architecture's fixed program-header layout. Match that behavior
            // so zero-program-header ELF files with e_phentsize == 0 remain
            // valid inputs.
            if (readU16(image, section_size_offset) != section_entry_len) {
                return error.InvalidElf;
            }
            const program_count: usize = readU16(image, program_count_offset);
            const section_count: usize = readU16(image, section_count_offset);
            const string_index: usize = readU16(image, string_index_offset);
            if (section_count == 0 or section_count > options.max_sections or
                string_index >= section_count)
            {
                return error.InvalidElf;
            }
            const program_bytes = try checkedMul(program_count, program_entry_len);
            const section_bytes = try checkedMul(section_count, section_entry_len);
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
            var units: std.ArrayList(Unit) = .empty;
            defer units.deinit(allocator);
            try units.ensureTotalCapacity(allocator, section_count);
            for (sections, 0..) |*section, index| {
                const base = section_offset + index * section_entry_len;
                const section_kind = readU32(image, base + 4);
                const flags = if (is_64) readU64(image, base + 8) else readU32(image, base + 8);
                const address = try sectionValue(image, base, 12, 16);
                const file_offset = try sectionValue(image, base, 16, 24);
                const size = try sectionValue(image, base, 20, 32);
                const entry_size = try sectionValue(image, base, 36, 56);
                if (!rangeFitsU32(address, size, image_size_bound))
                    return error.InvalidElf;
                const no_bits = section_kind == 8;
                if (!rangeFits(file_offset, size, if (no_bits) image_size_bound else image.len))
                    return error.InvalidElf;
                const useful = size != 0 and address != 0;
                section.* = .{
                    .kind = section_kind,
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
                const base = program_offset + index * program_entry_len;
                const file_offset = if (is_64)
                    try u64ToUsize(readU64(image, base + 8))
                else
                    readU32(image, base + 4);
                const file_size = if (is_64)
                    try u64ToUsize(readU64(image, base + 32))
                else
                    readU32(image, base + 16);
                if (!rangeFits(file_offset, file_size, image.len))
                    return error.InvalidElf;
                physical_end = @max(physical_end, file_offset + file_size);
            }
            if (physical_end != image.len) return error.InvalidElf;
            var translator = try initTranslatorAlloc(allocator, units.items);
            errdefer translator.deinit(allocator);
            var lists: [3]std.ArrayList(Reference) = @splat(.empty);
            errdefer for (&lists) |*list| list.deinit(allocator);
            try collectRelocations(kind, allocator, image, sections, translator, &lists[0], options.max_references);
            try collectAbsolute(kind, allocator, image, translator, lists[0].items, &lists[1], options.max_references);
            try collectRelative(kind, allocator, image, sections, translator, lists[1].items, &lists[2], options.max_references);
            var references: [3][]Reference = undefined;
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

        pub fn deinit(self: *Self) void {
            for (self.references) |references| self.allocator.free(references);
            self.allocator.free(self.sections);
            self.translator.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn referencesInRange(
            self: Self,
            reference_type: ReferenceType,
            low: u32,
            high: u32,
        ) []const Reference {
            const references = self.references[@intFromEnum(reference_type)];
            return references[lowerBound(references, low)..lowerBound(references, high)];
        }

        pub fn writeReference(
            self: Self,
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
                    if (!rangeFits(location, value_width, image.len))
                        return error.InvalidReference;
                    if (is_64)
                        std.mem.writeInt(u64, image[location..][0..8], target_rva, .little)
                    else
                        std.mem.writeInt(u32, image[location..][0..4], target_rva, .little);
                },
                .relative => {
                    if (!rangeFits(location, 4, image.len))
                        return error.InvalidReference;
                    const location_rva = self.translator.offsetToRva(reference.location) orelse
                        return error.InvalidReference;
                    const displacement = target_rva -% (location_rva +% 4);
                    std.mem.writeInt(u32, image[location..][0..4], displacement, .little);
                },
            }
        }
    };
}

fn headerOffset(image: []const u8, comptime program: bool) Error!usize {
    const class = image[4];
    const offset = if (class == 2)
        readU64(image, if (program) 32 else 40)
    else
        readU32(image, if (program) 28 else 32);
    return u64ToUsize(offset);
}

fn sectionValue(
    image: []const u8,
    base: usize,
    offset32: usize,
    offset64: usize,
) Error!u32 {
    const value = if (image[4] == 2)
        readU64(image, base + offset64)
    else
        readU32(image, base + offset32);
    return std.math.cast(u32, value) orelse error.InvalidElf;
}

fn collectRelocations(
    comptime kind: Kind,
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: Translator,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const is_64 = kind == .x64;
    const width: usize = if (is_64) 8 else 4;
    for (sections) |section| {
        const rel_size: u32 = if (is_64) 16 else 8;
        const rela_size: u32 = if (is_64) 24 else 12;
        if (!section.useful or
            !((section.kind == 9 and section.entry_size == rel_size) or
                (section.kind == 4 and section.entry_size == rela_size)))
            continue;
        var cursor: usize = section.offset;
        const end = cursor + section.size;
        while (cursor + section.entry_size <= end) : (cursor += section.entry_size) {
            const target_rva = if (is_64) readU64(image, cursor) else readU32(image, cursor);
            const info = if (is_64) readU64(image, cursor + 8) else readU32(image, cursor + 4);
            const relocation_type: u32 = if (is_64) @truncate(info) else @truncate(info & 0xff);
            if (target_rva > std.math.maxInt(u32) or relocation_type != 8) continue;
            const target = translator.rvaToOffset(@intCast(target_rva)) orelse continue;
            if (!rangeFits(target, width, image.len)) continue;
            if (output.items.len >= max_references) return error.OutputLimitExceeded;
            try output.append(allocator, .{ .location = @intCast(cursor), .target = target });
        }
    }
    std.mem.sort(Reference, output.items, {}, lessReference);
}

fn collectAbsolute(
    comptime kind: Kind,
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: Translator,
    relocations: []const Reference,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const width: usize = if (kind == .x64) 8 else 4;
    const locations = try allocator.alloc(u32, relocations.len);
    defer allocator.free(locations);
    for (relocations, locations) |reference, *location| location.* = reference.target;
    std.mem.sort(u32, locations, {}, std.sort.asc(u32));
    var previous_end: usize = 0;
    for (locations) |location| {
        if (location < previous_end or !rangeFits(location, width, image.len)) continue;
        const raw = if (kind == .x64) readU64(image, location) else readU32(image, location);
        if (raw >= offset_bound) continue;
        const target = translator.rvaToOffset(@intCast(raw)) orelse continue;
        if (output.items.len >= max_references) return error.OutputLimitExceeded;
        try output.append(allocator, .{ .location = location, .target = target });
        previous_end = @as(usize, location) + width;
    }
}

fn collectRelative(
    comptime kind: Kind,
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: Translator,
    absolutes: []const Reference,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const abs_width: usize = if (kind == .x64) 8 else 4;
    for (sections) |section| {
        if (!section.useful or section.kind != 1 or section.flags & 4 == 0) continue;
        const start: usize = section.offset;
        const end = start + section.size;
        var cursor = start;
        while (cursor < end) {
            const candidate = findRelative(kind, image, cursor, end) orelse {
                cursor += 1;
                continue;
            };
            if (overlapsAny(cursor, candidate.instruction_len, absolutes, abs_width)) {
                cursor += 1;
                continue;
            }
            const location_rva = translator.offsetToRva(candidate.location) orelse {
                cursor += 1;
                continue;
            };
            const displacement = readU32(image, candidate.location);
            const target_rva = location_rva +% 4 +% displacement;
            const target = translator.rvaToOffset(target_rva) orelse {
                cursor += 1;
                continue;
            };
            const inside_section = target_rva >= section.address and
                target_rva - section.address < section.size;
            if (!candidate.can_leave_section and !inside_section) {
                cursor += 1;
                continue;
            }
            if (output.items.len >= max_references) return error.OutputLimitExceeded;
            try output.append(allocator, .{
                .location = candidate.location,
                .target = target,
            });
            cursor += candidate.instruction_len;
        }
    }
    std.mem.sort(Reference, output.items, {}, lessReference);
}

pub const RelativeCandidate = struct {
    location: u32,
    instruction_len: usize,
    can_leave_section: bool,
};

pub fn findRelative(
    comptime kind: Kind,
    image: []const u8,
    cursor: usize,
    end: usize,
) ?RelativeCandidate {
    if (cursor + 5 <= end and (image[cursor] == 0xe8 or image[cursor] == 0xe9))
        return .{ .location = @intCast(cursor + 1), .instruction_len = 5, .can_leave_section = false };
    if (cursor + 6 <= end and image[cursor] == 0x0f and image[cursor + 1] & 0xf0 == 0x80)
        return .{ .location = @intCast(cursor + 2), .instruction_len = 6, .can_leave_section = false };
    if (kind == .x64 and cursor + 6 <= end) {
        const first = image[cursor];
        const second = image[cursor + 1];
        if ((first == 0xff and (second == 0x15 or second == 0x25)) or
            ((first == 0x89 or first == 0x8b or first == 0x8d) and second & 0xc7 == 0x05))
        {
            return .{ .location = @intCast(cursor + 2), .instruction_len = 6, .can_leave_section = true };
        }
    }
    return null;
}

fn overlapsAny(
    start: usize,
    length: usize,
    references: []const Reference,
    width: usize,
) bool {
    const end = start + length;
    for (references) |reference| {
        const ref_start: usize = reference.location;
        if (ref_start >= end) break;
        if (ref_start + width > start) return true;
    }
    return false;
}

pub fn initTranslatorAlloc(
    allocator: std.mem.Allocator,
    input: []const Unit,
) Error!Translator {
    var by_rva = try allocator.dupe(Unit, input);
    errdefer allocator.free(by_rva);
    std.mem.sort(Unit, by_rva, {}, lessUnitRva);
    var count: usize = 0;
    for (by_rva) |raw_unit| {
        var unit = raw_unit;
        if (!rangeFitsU32(unit.offset, unit.size, offset_bound) or
            !rangeFitsU32(unit.rva, unit.rva_size, offset_bound))
            return error.InvalidElf;
        unit.size = @min(unit.size, unit.rva_size);
        if (count != 0 and std.meta.eql(by_rva[count - 1], unit)) continue;
        by_rva[count] = unit;
        count += 1;
    }
    var merged: usize = 0;
    for (by_rva[0..count]) |unit| {
        if (unit.rva_size == 0) continue;
        if (merged == 0) {
            by_rva[0] = unit;
            merged = 1;
            continue;
        }
        var previous = &by_rva[merged - 1];
        if (previous.rvaEnd() < unit.rva) {
            by_rva[merged] = unit;
            merged += 1;
            continue;
        }
        const tangent = previous.rvaEnd() == unit.rva;
        const same_shift = unit.offset >= previous.offset and
            unit.offset - previous.offset == unit.rva - previous.rva;
        if (!same_shift) {
            if (!tangent) return error.InvalidElf;
            by_rva[merged] = unit;
            merged += 1;
            continue;
        }
        if ((unit.hasDanglingRva() and unit.offsetEnd() < previous.offsetEnd()) or
            (previous.hasDanglingRva() and previous.offsetEnd() < unit.offsetEnd()))
        {
            if (!tangent) return error.InvalidElf;
            by_rva[merged] = unit;
            merged += 1;
            continue;
        }
        previous.size = @max(previous.offsetEnd(), unit.offsetEnd()) - previous.offset;
        previous.rva_size = @max(previous.rvaEnd(), unit.rvaEnd()) - previous.rva;
    }
    const rva_units = try allocator.dupe(Unit, by_rva[0..merged]);
    errdefer allocator.free(rva_units);
    std.mem.sort(Unit, by_rva[0..merged], {}, lessUnitOffset);
    for (by_rva[0..merged], 0..) |unit, index|
        if (index != 0 and by_rva[index - 1].offsetEnd() > unit.offset)
            return error.InvalidElf;
    var max_offset: u32 = 0;
    var max_rva: u32 = 0;
    for (by_rva[0..merged]) |unit| {
        max_offset = @max(max_offset, unit.offsetEnd());
        max_rva = @max(max_rva, unit.rvaEnd());
    }
    if (max_offset > offset_bound - max_rva) return error.InvalidElf;
    const offset_units = try allocator.dupe(Unit, by_rva[0..merged]);
    allocator.free(by_rva);
    return .{
        .by_offset = offset_units,
        .by_rva = rva_units,
        .fake_offset_begin = max_offset,
    };
}

fn findUnitOffset(units: []const Unit, value: u32) ?Unit {
    var low: usize = 0;
    var high = units.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (units[mid].offset <= value) low = mid + 1 else high = mid;
    }
    if (low == 0) return null;
    const unit = units[low - 1];
    return if (value - unit.offset < unit.size) unit else null;
}

fn findUnitRva(units: []const Unit, value: u32) ?Unit {
    var low: usize = 0;
    var high = units.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (units[mid].rva <= value) low = mid + 1 else high = mid;
    }
    if (low == 0) return null;
    const unit = units[low - 1];
    return if (value - unit.rva < unit.rva_size) unit else null;
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

fn lessReference(_: void, a: Reference, b: Reference) bool {
    return a.location < b.location;
}

fn lessUnitRva(_: void, a: Unit, b: Unit) bool {
    return if (a.rva == b.rva) a.rva_size < b.rva_size else a.rva < b.rva;
}

fn lessUnitOffset(_: void, a: Unit, b: Unit) bool {
    return a.offset < b.offset;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readU64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

fn u64ToUsize(value: anytype) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
}

fn checkedMul(a: usize, b: usize) Error!usize {
    return std.math.mul(usize, a, b) catch error.IntegerOverflow;
}

fn rangeFits(offset: anytype, length: anytype, total: usize) bool {
    const start = std.math.cast(usize, offset) orelse return false;
    const size = std.math.cast(usize, length) orelse return false;
    return start <= total and size <= total - start;
}

fn rangeFitsU32(offset: u32, length: u32, total: u32) bool {
    return offset <= total and length <= total - offset;
}

test "Zucchini Intel ELF32 and ELF64 extract and rewrite all reference groups" {
    const allocator = std.testing.allocator;
    inline for (.{ Kind.x86, Kind.x64 }) |kind| {
        const image = testElf(kind);
        const Engine = if (kind == .x86) X86 else X64;
        var elf = try Engine.Executable.initAlloc(allocator, &image, .{});
        defer elf.deinit();
        try std.testing.expectEqualSlices(
            Reference,
            &.{.{ .location = 0x160, .target = 0x140 }},
            elf.references[@intFromEnum(ReferenceType.relocation)],
        );
        try std.testing.expectEqualSlices(
            Reference,
            &.{.{ .location = 0x140, .target = 0x108 }},
            elf.references[@intFromEnum(ReferenceType.absolute)],
        );
        try std.testing.expectEqualSlices(
            Reference,
            &.{.{ .location = 0x101, .target = 0x108 }},
            elf.references[@intFromEnum(ReferenceType.relative)],
        );
        var modified = image;
        try elf.writeReference(&modified, .relocation, .{
            .location = 0x160,
            .target = if (kind == .x64) 0x148 else 0x144,
        });
        try elf.writeReference(&modified, .absolute, .{
            .location = 0x140,
            .target = 0x10c,
        });
        try elf.writeReference(&modified, .relative, .{
            .location = 0x101,
            .target = 0x10c,
        });
        if (kind == .x64) {
            try std.testing.expectEqual(@as(u64, 0x20008), readU64(&modified, 0x160));
            try std.testing.expectEqual(@as(u64, 0x1000c), readU64(&modified, 0x140));
        } else {
            try std.testing.expectEqual(@as(u32, 0x20004), readU32(&modified, 0x160));
            try std.testing.expectEqual(@as(u32, 0x1000c), readU32(&modified, 0x140));
        }
        try std.testing.expectEqual(@as(u32, 7), readU32(&modified, 0x101));
    }
}

test "Zucchini Intel relative scanner matches AOSP opcode families" {
    const code = [_]u8{
        0xe8, 0, 0, 0, 0, // CALL rel32.
        0xe9, 0, 0, 0, 0, // JMP rel32.
        0x0f, 0x85, 0, 0, 0, 0, // Jcc rel32.
        0xff, 0x15, 0, 0, 0, 0, // CALL [RIP+disp32].
        0xff, 0x25, 0, 0, 0, 0, // JMP [RIP+disp32].
        0x89, 0x05, 0, 0, 0, 0, // MOV [RIP+disp32],reg.
        0x8b, 0x3d, 0, 0, 0, 0, // MOV reg,[RIP+disp32].
        0x8d, 0x05, 0, 0, 0, 0, // LEA reg,[RIP+disp32].
        0x48, 0x8b, 0x05, 0, 0, 0, 0, // Prefixed MOV.
    };
    try expectRelativeCandidates(.x86, &code, &.{
        .{ .location = 1, .instruction_len = 5, .can_leave_section = false },
        .{ .location = 6, .instruction_len = 5, .can_leave_section = false },
        .{ .location = 12, .instruction_len = 6, .can_leave_section = false },
    });
    try expectRelativeCandidates(.x64, &code, &.{
        .{ .location = 1, .instruction_len = 5, .can_leave_section = false },
        .{ .location = 6, .instruction_len = 5, .can_leave_section = false },
        .{ .location = 12, .instruction_len = 6, .can_leave_section = false },
        .{ .location = 18, .instruction_len = 6, .can_leave_section = true },
        .{ .location = 24, .instruction_len = 6, .can_leave_section = true },
        .{ .location = 30, .instruction_len = 6, .can_leave_section = true },
        .{ .location = 36, .instruction_len = 6, .can_leave_section = true },
        .{ .location = 42, .instruction_len = 6, .can_leave_section = true },
        .{ .location = 49, .instruction_len = 6, .can_leave_section = true },
    });
}

test "Zucchini Intel ELF rejects malformed and quota-exceeding images" {
    const allocator = std.testing.allocator;
    inline for (.{ Kind.x86, Kind.x64 }) |kind| {
        const Engine = if (kind == .x86) X86 else X64;
        var image = testElf(kind);

        // e_phentsize is ignored by upstream when there are no program
        // headers, while e_shentsize remains mandatory.
        const program_size_offset: usize = if (kind == .x64) 54 else 42;
        std.mem.writeInt(u16, image[program_size_offset..][0..2], 0, .little);
        var elf = try Engine.Executable.initAlloc(allocator, &image, .{});
        elf.deinit();

        try std.testing.expectError(
            error.InvalidElf,
            Engine.Executable.initAlloc(allocator, &image, .{ .max_sections = 3 }),
        );
        try std.testing.expectError(
            error.OutputLimitExceeded,
            Engine.Executable.initAlloc(allocator, &image, .{ .max_references = 0 }),
        );

        var malformed = image;
        malformed[5] = 2;
        try std.testing.expectError(
            error.InvalidElf,
            Engine.Executable.initAlloc(allocator, &malformed, .{}),
        );

        malformed = image;
        const section_offset_offset: usize = if (kind == .x64) 40 else 32;
        if (kind == .x64)
            std.mem.writeInt(u64, malformed[section_offset_offset..][0..8], std.math.maxInt(u64), .little)
        else
            std.mem.writeInt(u32, malformed[section_offset_offset..][0..4], std.math.maxInt(u32), .little);
        try std.testing.expectError(
            error.InvalidElf,
            Engine.Executable.initAlloc(allocator, &malformed, .{}),
        );
    }
}

test "Zucchini address translator rejects inconsistent dangling RVA overlap" {
    try std.testing.expectError(
        error.InvalidElf,
        initTranslatorAlloc(std.testing.allocator, &.{
            .{ .offset = 0, .size = 10, .rva = 100, .rva_size = 20 },
            .{ .offset = 5, .size = 20, .rva = 105, .rva_size = 20 },
        }),
    );
}

fn expectRelativeCandidates(
    comptime kind: Kind,
    code: []const u8,
    expected: []const RelativeCandidate,
) !void {
    var cursor: usize = 0;
    var index: usize = 0;
    while (cursor < code.len) {
        const candidate = findRelative(kind, code, cursor, code.len) orelse {
            cursor += 1;
            continue;
        };
        if (index >= expected.len) return error.TestUnexpectedResult;
        try std.testing.expectEqual(expected[index].location, candidate.location);
        try std.testing.expectEqual(
            expected[index].instruction_len,
            candidate.instruction_len,
        );
        try std.testing.expectEqual(
            expected[index].can_leave_section,
            candidate.can_leave_section,
        );
        index += 1;
        cursor += candidate.instruction_len;
    }
    try std.testing.expectEqual(expected.len, index);
}

fn testElf(comptime kind: Kind) [if (kind == .x64) 0x300 else 0x2a0]u8 {
    const is_64 = kind == .x64;
    var output: [if (is_64) 0x300 else 0x2a0]u8 = @splat(0);
    @memcpy(output[0..4], "\x7fELF");
    output[4] = if (is_64) 2 else 1;
    output[5] = 1;
    output[6] = 1;
    std.mem.writeInt(u16, output[16..18], 2, .little);
    std.mem.writeInt(u16, output[18..20], if (is_64) 62 else 3, .little);
    std.mem.writeInt(u32, output[20..24], 1, .little);
    if (is_64) {
        std.mem.writeInt(u64, output[40..48], 0x200, .little);
        std.mem.writeInt(u16, output[52..54], 64, .little);
        std.mem.writeInt(u16, output[54..56], 56, .little);
        std.mem.writeInt(u16, output[58..60], 64, .little);
        std.mem.writeInt(u16, output[60..62], 4, .little);
    } else {
        std.mem.writeInt(u32, output[32..36], 0x200, .little);
        std.mem.writeInt(u16, output[40..42], 52, .little);
        std.mem.writeInt(u16, output[42..44], 32, .little);
        std.mem.writeInt(u16, output[46..48], 40, .little);
        std.mem.writeInt(u16, output[48..50], 4, .little);
    }
    writeTestSection(&output, kind, 1, 1, 6, 0x10000, 0x100, 0x20, 0);
    writeTestSection(&output, kind, 2, 1, 3, 0x20000, 0x140, if (is_64) 0x10 else 0x08, 0);
    writeTestSection(
        &output,
        kind,
        3,
        9,
        2,
        0x30000,
        0x160,
        if (is_64) 0x10 else 0x08,
        if (is_64) 16 else 8,
    );
    output[0x100] = 0xe8;
    std.mem.writeInt(u32, output[0x101..0x105], 3, .little);
    if (is_64) {
        std.mem.writeInt(u64, output[0x140..0x148], 0x10008, .little);
        std.mem.writeInt(u64, output[0x160..0x168], 0x20000, .little);
        std.mem.writeInt(u64, output[0x168..0x170], 8, .little);
    } else {
        std.mem.writeInt(u32, output[0x140..0x144], 0x10008, .little);
        std.mem.writeInt(u32, output[0x160..0x164], 0x20000, .little);
        std.mem.writeInt(u32, output[0x164..0x168], 8, .little);
    }
    return output;
}

fn writeTestSection(
    output: []u8,
    comptime kind: Kind,
    index: usize,
    section_kind: u32,
    flags: u64,
    address: u64,
    offset: u64,
    size: u64,
    entry_size: u64,
) void {
    const is_64 = kind == .x64;
    const base = 0x200 + index * (if (is_64) 64 else 40);
    std.mem.writeInt(u32, output[base + 4 ..][0..4], section_kind, .little);
    if (is_64) {
        std.mem.writeInt(u64, output[base + 8 ..][0..8], flags, .little);
        std.mem.writeInt(u64, output[base + 16 ..][0..8], address, .little);
        std.mem.writeInt(u64, output[base + 24 ..][0..8], offset, .little);
        std.mem.writeInt(u64, output[base + 32 ..][0..8], size, .little);
        std.mem.writeInt(u64, output[base + 56 ..][0..8], entry_size, .little);
    } else {
        std.mem.writeInt(u32, output[base + 8 ..][0..4], @intCast(flags), .little);
        std.mem.writeInt(u32, output[base + 12 ..][0..4], @intCast(address), .little);
        std.mem.writeInt(u32, output[base + 16 ..][0..4], @intCast(offset), .little);
        std.mem.writeInt(u32, output[base + 20 ..][0..4], @intCast(size), .little);
        std.mem.writeInt(u32, output[base + 36 ..][0..4], @intCast(entry_size), .little);
    }
}
