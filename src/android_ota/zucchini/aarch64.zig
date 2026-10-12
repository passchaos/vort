const std = @import("std");

pub const Error = std.mem.Allocator.Error || error{
    InvalidElf,
    InvalidReference,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const ReferenceType = enum(u3) {
    relocation = 0,
    absolute = 1,
    immediate14 = 2,
    immediate19 = 3,
    immediate26 = 4,

    pub fn pool(self: ReferenceType) u8 {
        return switch (self) {
            .relocation => 0,
            .absolute => 1,
            .immediate14, .immediate19, .immediate26 => 2,
        };
    }
};

pub const Reference = struct {
    location: u32,
    target: u32,
};

pub const Equivalence = struct {
    source_offset: usize,
    destination_offset: usize,
    length: usize,
};

pub const Options = struct {
    max_sections: usize = 1 << 20,
    max_references: usize = 1 << 24,
};

const invalid_offset = std.math.maxInt(u32) - 1;
const offset_bound = std.math.maxInt(u32) / 2;
const rva_bound = std.math.maxInt(u32) / 2;
const image_size_bound = 0x7fff_0000;

const Section = struct {
    kind: u32,
    flags: u64,
    address: u32,
    offset: u32,
    size: u32,
    entry_size: u32,
    useful: bool,
};

const Unit = struct {
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
};

const Translator = struct {
    units_by_offset: []Unit,
    units_by_rva: []Unit,
    fake_offset_begin: u32,

    fn deinit(self: *Translator, allocator: std.mem.Allocator) void {
        allocator.free(self.units_by_offset);
        allocator.free(self.units_by_rva);
        self.* = undefined;
    }

    fn offsetToRva(self: Translator, offset: u32) ?u32 {
        if (offset >= self.fake_offset_begin) {
            const rva = offset - self.fake_offset_begin;
            const unit = findUnitByRva(self.units_by_rva, rva) orelse return null;
            if (unit.rva_size <= unit.size or rva - unit.rva < unit.size)
                return null;
            return rva;
        }
        const unit = findUnitByOffset(self.units_by_offset, offset) orelse
            return null;
        return offset - unit.offset + unit.rva;
    }

    fn rvaToOffset(self: Translator, rva: u32) ?u32 {
        const unit = findUnitByRva(self.units_by_rva, rva) orelse return null;
        const delta = rva - unit.rva;
        return if (delta < unit.size)
            unit.offset + delta
        else
            self.fake_offset_begin + rva;
    }
};

pub const Elf = struct {
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: Translator,
    sections: []Section,
    references: [5][]Reference,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        image: []const u8,
        options: Options,
    ) Error!Elf {
        if (image.len < 64 or image.len >= image_size_bound)
            return error.InvalidElf;
        if (!std.mem.eql(u8, image[0..4], "\x7fELF") or
            image[4] != 2 or image[5] != 1 or image[6] != 1 or
            (readU16(image, 16) != 2 and readU16(image, 16) != 3) or
            readU16(image, 18) != 183 or readU32(image, 20) != 1 or
            readU16(image, 58) != 64)
            return error.InvalidElf;
        const program_offset = try u64ToUsize(readU64(image, 32));
        const section_offset = try u64ToUsize(readU64(image, 40));
        const program_count: usize = readU16(image, 56);
        const section_count: usize = readU16(image, 60);
        const string_section_index: usize = readU16(image, 62);
        if (section_count > options.max_sections)
            return error.OutputLimitExceeded;
        if (section_count == 0 or string_section_index >= section_count)
            return error.InvalidElf;
        const program_bytes = try checkedMul(program_count, 56);
        const section_bytes = try checkedMul(section_count, 64);
        if (!rangeFits(program_offset, program_bytes, image.len) or
            !rangeFits(section_offset, section_bytes, image.len))
            return error.InvalidElf;
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
            const base = section_offset + index * 64;
            const kind = readU32(image, base + 4);
            const flags = readU64(image, base + 8);
            const address64 = readU64(image, base + 16);
            const offset64 = readU64(image, base + 24);
            const size64 = readU64(image, base + 32);
            const entry_size64 = readU64(image, base + 56);
            if (address64 > std.math.maxInt(u32) or
                offset64 > std.math.maxInt(u32) or
                size64 > std.math.maxInt(u32) or
                entry_size64 > std.math.maxInt(u32))
                return error.InvalidElf;
            const address: u32 = @intCast(address64);
            const file_offset: u32 = @intCast(offset64);
            const size: u32 = @intCast(size64);
            const entry_size: u32 = @intCast(entry_size64);
            if (!rangeFitsU32(address, size, image_size_bound))
                return error.InvalidElf;
            const is_no_bits = kind == 8;
            const file_limit: usize = if (is_no_bits) image_size_bound else image.len;
            if (!rangeFits(file_offset, size, file_limit))
                return error.InvalidElf;
            const useful = size != 0 and address != 0;
            section.* = .{
                .kind = kind,
                .flags = flags,
                .address = address,
                .offset = file_offset,
                .size = size,
                .entry_size = entry_size,
                .useful = useful and !is_no_bits,
            };
            if (useful) units.appendAssumeCapacity(.{
                .offset = file_offset,
                .size = size,
                .rva = address,
                .rva_size = size,
            });
            if (useful and !is_no_bits)
                physical_end = @max(physical_end, @as(usize, file_offset) + size);
        }
        const string_section = sections[string_section_index];
        if (string_section.size != 0) {
            if (!rangeFits(string_section.offset, string_section.size, image.len) or
                image[@as(usize, string_section.offset) + string_section.size - 1] != 0)
                return error.InvalidElf;
        }
        for (0..program_count) |index| {
            const base = program_offset + index * 56;
            const file_offset = try u64ToUsize(readU64(image, base + 8));
            const file_size = try u64ToUsize(readU64(image, base + 32));
            if (!rangeFits(file_offset, file_size, image.len))
                return error.InvalidElf;
            physical_end = @max(physical_end, file_offset + file_size);
        }
        if (physical_end != image.len) return error.InvalidElf;
        var translator = try initTranslatorAlloc(allocator, units.items);
        errdefer translator.deinit(allocator);

        var reference_lists: [5]std.ArrayList(Reference) = @splat(.empty);
        errdefer for (&reference_lists) |*list| list.deinit(allocator);
        try collectRelocations(
            allocator,
            image,
            sections,
            translator,
            &reference_lists[@intFromEnum(ReferenceType.relocation)],
            options.max_references,
        );
        try collectAbsoluteReferences(
            allocator,
            image,
            translator,
            reference_lists[@intFromEnum(ReferenceType.relocation)].items,
            &reference_lists[@intFromEnum(ReferenceType.absolute)],
            options.max_references,
        );
        try collectBranches(
            allocator,
            image,
            sections,
            translator,
            reference_lists[@intFromEnum(ReferenceType.absolute)].items,
            &reference_lists,
            options.max_references,
        );
        var references: [5][]Reference = undefined;
        var converted: usize = 0;
        errdefer for (references[0..converted]) |slice| allocator.free(slice);
        for (&reference_lists, 0..) |*list, index| {
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

    pub fn deinit(self: *Elf) void {
        for (self.references) |references| self.allocator.free(references);
        self.allocator.free(self.sections);
        self.translator.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn referencesInRange(
        self: Elf,
        reference_type: ReferenceType,
        low: u32,
        high: u32,
    ) []const Reference {
        const references = self.references[@intFromEnum(reference_type)];
        const start = lowerBoundReference(references, low);
        const end = lowerBoundReference(references, high);
        return references[start..end];
    }

    pub fn writeReference(
        self: Elf,
        image: []u8,
        reference_type: ReferenceType,
        reference: Reference,
    ) Error!void {
        if (image.len != self.image.len) return error.InvalidReference;
        const location: usize = reference.location;
        switch (reference_type) {
            .relocation, .absolute => {
                if (!rangeFits(location, 8, image.len))
                    return error.InvalidReference;
                const rva = self.translator.offsetToRva(reference.target) orelse
                    return error.InvalidReference;
                std.mem.writeInt(u64, image[location..][0..8], rva, .little);
            },
            .immediate14, .immediate19, .immediate26 => {
                if (!rangeFits(location, 4, image.len))
                    return error.InvalidReference;
                const instruction_rva = self.translator.offsetToRva(reference.location) orelse
                    return error.InvalidReference;
                const target_rva = self.translator.offsetToRva(reference.target) orelse
                    return error.InvalidReference;
                var code = readU32(image, location);
                try encodeBranch(reference_type, instruction_rva, target_rva, &code);
                std.mem.writeInt(u32, image[location..][0..4], code, .little);
            },
        }
    }
};

fn initTranslatorAlloc(
    allocator: std.mem.Allocator,
    input_units: []const Unit,
) Error!Translator {
    var by_rva = try allocator.dupe(Unit, input_units);
    errdefer allocator.free(by_rva);
    std.mem.sort(Unit, by_rva, {}, lessUnitRva);
    var unique_count: usize = 0;
    for (by_rva) |unit| {
        if (!rangeFitsU32(unit.offset, unit.size, offset_bound) or
            !rangeFitsU32(unit.rva, unit.rva_size, rva_bound))
            return error.InvalidElf;
        if (unique_count != 0 and std.meta.eql(by_rva[unique_count - 1], unit))
            continue;
        by_rva[unique_count] = unit;
        unique_count += 1;
    }
    var merged_count: usize = 0;
    for (by_rva[0..unique_count]) |unit| {
        if (unit.rva_size == 0) continue;
        if (merged_count == 0) {
            by_rva[0] = unit;
            merged_count = 1;
            continue;
        }
        var previous = &by_rva[merged_count - 1];
        if (previous.rvaEnd() < unit.rva) {
            by_rva[merged_count] = unit;
            merged_count += 1;
            continue;
        }
        const tangent = previous.rvaEnd() == unit.rva;
        const same_shift = unit.offset >= previous.offset and
            unit.offset - previous.offset == unit.rva - previous.rva;
        if (!same_shift) {
            if (!tangent) return error.InvalidElf;
            by_rva[merged_count] = unit;
            merged_count += 1;
            continue;
        }
        previous.size = @max(previous.offsetEnd(), unit.offsetEnd()) - previous.offset;
        previous.rva_size = @max(previous.rvaEnd(), unit.rvaEnd()) - previous.rva;
    }
    const rva_units = try allocator.dupe(Unit, by_rva[0..merged_count]);
    errdefer allocator.free(rva_units);
    std.mem.sort(Unit, by_rva[0..merged_count], {}, lessUnitOffset);
    for (by_rva[0..merged_count], 0..) |unit, index| {
        if (index != 0 and by_rva[index - 1].offsetEnd() > unit.offset)
            return error.InvalidElf;
    }
    var max_offset: u32 = 0;
    var max_rva: u32 = 0;
    for (by_rva[0..merged_count]) |unit| {
        max_offset = @max(max_offset, unit.offsetEnd());
        max_rva = @max(max_rva, unit.rvaEnd());
    }
    if (max_offset > offset_bound - max_rva) return error.InvalidElf;
    const offset_units = try allocator.dupe(Unit, by_rva[0..merged_count]);
    allocator.free(by_rva);
    return .{
        .units_by_offset = offset_units,
        .units_by_rva = rva_units,
        .fake_offset_begin = max_offset,
    };
}

fn collectRelocations(
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: Translator,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    for (sections) |section| {
        if (!section.useful or
            !((section.kind == 9 and section.entry_size == 16) or
                (section.kind == 4 and section.entry_size == 24)))
            continue;
        var cursor: usize = section.offset;
        const end = cursor + section.size;
        while (cursor + section.entry_size <= end) : (cursor += section.entry_size) {
            const target_rva64 = readU64(image, cursor);
            const info = readU64(image, cursor + 8);
            if (target_rva64 > std.math.maxInt(u32) or
                @as(u32, @truncate(info)) != 0x403)
                continue;
            const target = translator.rvaToOffset(@intCast(target_rva64)) orelse
                continue;
            if (!rangeFits(target, 8, image.len)) continue;
            if (output.items.len >= max_references)
                return error.OutputLimitExceeded;
            try output.append(allocator, .{
                .location = @intCast(cursor),
                .target = target,
            });
        }
    }
    std.mem.sort(Reference, output.items, {}, lessReference);
}

fn collectAbsoluteReferences(
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: Translator,
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
        if (location < previous_end or !rangeFits(location, 8, image.len))
            continue;
        const raw = readU64(image, location);
        if (raw >= rva_bound) continue;
        const target = translator.rvaToOffset(@intCast(raw)) orelse continue;
        if (output.items.len >= max_references)
            return error.OutputLimitExceeded;
        try output.append(allocator, .{ .location = location, .target = target });
        previous_end = @as(usize, location) + 8;
    }
}

fn collectBranches(
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: Translator,
    absolute_references: []const Reference,
    outputs: *[5]std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    for (sections) |section| {
        if (!section.useful or section.kind != 1 or section.flags & 4 == 0)
            continue;
        var location: usize = std.mem.alignForward(usize, section.offset, 4);
        const end = @as(usize, section.offset) + section.size;
        while (location + 4 <= end) : (location += 4) {
            if (overlapsAbsolute(location, absolute_references)) continue;
            const instruction_rva = translator.offsetToRva(@intCast(location)) orelse
                continue;
            const code = readU32(image, location);
            const decoded = decodeBranch(instruction_rva, code) orelse continue;
            const target = translator.rvaToOffset(decoded.target_rva) orelse continue;
            if (!targetInExecSection(target, sections)) continue;
            const list = &outputs[@intFromEnum(decoded.reference_type)];
            if (list.items.len >= max_references)
                return error.OutputLimitExceeded;
            try list.append(allocator, .{
                .location = @intCast(location),
                .target = target,
            });
        }
    }
    inline for (.{
        ReferenceType.immediate14,
        ReferenceType.immediate19,
        ReferenceType.immediate26,
    }) |reference_type| {
        std.mem.sort(
            Reference,
            outputs[@intFromEnum(reference_type)].items,
            {},
            lessReference,
        );
    }
}

const DecodedBranch = struct {
    reference_type: ReferenceType,
    target_rva: u32,
};

fn decodeBranch(instruction_rva: u32, code: u32) ?DecodedBranch {
    if (code & 0x7f00_0000 == 0x3600_0000 or
        code & 0x7f00_0000 == 0x3700_0000)
    {
        const encoded = (code >> 5) & 0x3fff;
        const displacement = signExtend(encoded, 14) << 2;
        return .{
            .reference_type = .immediate14,
            .target_rva = instruction_rva +% @as(u32, @bitCast(displacement)),
        };
    }
    if (code & 0xff00_0010 == 0x5400_0000 or
        code & 0x7f00_0000 == 0x3400_0000 or
        code & 0x7f00_0000 == 0x3500_0000)
    {
        const encoded = (code >> 5) & 0x7ffff;
        const displacement = signExtend(encoded, 19) << 2;
        return .{
            .reference_type = .immediate19,
            .target_rva = instruction_rva +% @as(u32, @bitCast(displacement)),
        };
    }
    if (code & 0xfc00_0000 == 0x1400_0000 or
        code & 0xfc00_0000 == 0x9400_0000)
    {
        const encoded = code & 0x03ff_ffff;
        const displacement = signExtend(encoded, 26) << 2;
        return .{
            .reference_type = .immediate26,
            .target_rva = instruction_rva +% @as(u32, @bitCast(displacement)),
        };
    }
    return null;
}

fn encodeBranch(
    reference_type: ReferenceType,
    instruction_rva: u32,
    target_rva: u32,
    code: *u32,
) Error!void {
    const displacement: i32 = @bitCast(target_rva -% instruction_rva);
    if (displacement & 3 != 0) return error.InvalidReference;
    switch (reference_type) {
        .immediate14 => {
            if (!signedFits(displacement, 16) or
                !((code.* & 0x7f00_0000 == 0x3600_0000) or
                    (code.* & 0x7f00_0000 == 0x3700_0000)))
                return error.InvalidReference;
            code.* = (code.* & 0xfff8_001f) |
                ((@as(u32, @bitCast(displacement)) >> 2 & 0x3fff) << 5);
        },
        .immediate19 => {
            if (!signedFits(displacement, 21) or
                !((code.* & 0xff00_0010 == 0x5400_0000) or
                    (code.* & 0x7f00_0000 == 0x3400_0000) or
                    (code.* & 0x7f00_0000 == 0x3500_0000)))
                return error.InvalidReference;
            code.* = (code.* & 0xff00_001f) |
                ((@as(u32, @bitCast(displacement)) >> 2 & 0x7ffff) << 5);
        },
        .immediate26 => {
            if (!signedFits(displacement, 28) or
                !((code.* & 0xfc00_0000 == 0x1400_0000) or
                    (code.* & 0xfc00_0000 == 0x9400_0000)))
                return error.InvalidReference;
            code.* = (code.* & 0xfc00_0000) |
                (@as(u32, @bitCast(displacement)) >> 2 & 0x03ff_ffff);
        },
        else => return error.InvalidReference,
    }
}

fn signExtend(value: u32, bit_count: u5) i32 {
    const shift: u5 = @intCast(@as(u6, 32) - bit_count);
    return @as(i32, @bitCast(value << shift)) >> shift;
}

fn signedFits(value: i32, bit_count: u5) bool {
    const shift: u5 = @intCast(@as(u6, 32) - bit_count);
    return (value << shift) >> shift == value;
}

fn overlapsAbsolute(location: usize, references: []const Reference) bool {
    var low: usize = 0;
    var high = references.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (references[middle].location < location + 4)
            low = middle + 1
        else
            high = middle;
    }
    if (low == 0) return false;
    return references[low - 1].location + 8 > location;
}

fn targetInExecSection(target: u32, sections: []const Section) bool {
    for (sections) |section|
        if (section.useful and section.kind == 1 and section.flags & 4 != 0 and
            target >= section.offset and target - section.offset < section.size)
            return true;
    return false;
}

fn findUnitByOffset(units: []const Unit, offset: u32) ?Unit {
    var low: usize = 0;
    var high = units.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (units[middle].offset <= offset)
            low = middle + 1
        else
            high = middle;
    }
    if (low == 0) return null;
    const unit = units[low - 1];
    return if (offset - unit.offset < unit.size) unit else null;
}

fn findUnitByRva(units: []const Unit, rva: u32) ?Unit {
    var low: usize = 0;
    var high = units.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (units[middle].rva <= rva)
            low = middle + 1
        else
            high = middle;
    }
    if (low == 0) return null;
    const unit = units[low - 1];
    return if (rva - unit.rva < unit.rva_size) unit else null;
}

fn lowerBoundReference(references: []const Reference, location: u32) usize {
    var low: usize = 0;
    var high = references.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (references[middle].location < location)
            low = middle + 1
        else
            high = middle;
    }
    return low;
}

fn lessReference(_: void, left: Reference, right: Reference) bool {
    return left.location < right.location;
}

fn lessUnitRva(_: void, left: Unit, right: Unit) bool {
    return if (left.rva == right.rva)
        left.rva_size < right.rva_size
    else
        left.rva < right.rva;
}

fn lessUnitOffset(_: void, left: Unit, right: Unit) bool {
    return left.offset < right.offset;
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

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.IntegerOverflow;
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

test "Zucchini AArch64 branch immediate readers and writers match AOSP vectors" {
    const cases = [_]struct {
        reference_type: ReferenceType,
        original: u32,
        instruction_rva: u32,
        target_rva: u32,
        expected: u32,
    }{
        .{ .reference_type = .immediate26, .original = 0x1400_0002, .instruction_rva = 0x30008, .target_rva = 0x30000, .expected = 0x17ff_fffe },
        .{ .reference_type = .immediate19, .original = 0x3500_0025, .instruction_rva = 0x30010, .target_rva = 0x30000, .expected = 0x35ff_ff85 },
        .{ .reference_type = .immediate19, .original = 0x54ff_ffca, .instruction_rva = 0x30018, .target_rva = 0x3001c, .expected = 0x5400_002a },
        .{ .reference_type = .immediate14, .original = 0x368f_ff4c, .instruction_rva = 0x3001c, .target_rva = 0x30010, .expected = 0x368f_ffac },
    };
    for (cases) |case| {
        var code = case.original;
        try encodeBranch(
            case.reference_type,
            case.instruction_rva,
            case.target_rva,
            &code,
        );
        try std.testing.expectEqual(case.expected, code);
        const decoded = decodeBranch(case.instruction_rva, code).?;
        try std.testing.expectEqual(case.reference_type, decoded.reference_type);
        try std.testing.expectEqual(case.target_rva, decoded.target_rva);
    }
}

test "Zucchini AArch64 ELF extracts and writes relocation absolute and branch groups" {
    const allocator = std.testing.allocator;
    const image = testElf();
    var elf = try Elf.initAlloc(allocator, &image, .{});
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
        &.{.{ .location = 0x100, .target = 0x108 }},
        elf.references[@intFromEnum(ReferenceType.immediate26)],
    );
    var modified = image;
    try elf.writeReference(&modified, .relocation, .{
        .location = 0x160,
        .target = 0x148,
    });
    try elf.writeReference(&modified, .absolute, .{
        .location = 0x140,
        .target = 0x10c,
    });
    try elf.writeReference(&modified, .immediate26, .{
        .location = 0x100,
        .target = 0x10c,
    });
    try std.testing.expectEqual(@as(u64, 0x20008), readU64(&modified, 0x160));
    try std.testing.expectEqual(@as(u64, 0x1000c), readU64(&modified, 0x140));
    try std.testing.expectEqual(@as(u32, 0x1400_0003), readU32(&modified, 0x100));
}

fn testElf() [0x300]u8 {
    var output: [0x300]u8 = @splat(0);
    @memcpy(output[0..4], "\x7fELF");
    output[4] = 2;
    output[5] = 1;
    output[6] = 1;
    std.mem.writeInt(u16, output[16..18], 2, .little);
    std.mem.writeInt(u16, output[18..20], 183, .little);
    std.mem.writeInt(u32, output[20..24], 1, .little);
    std.mem.writeInt(u64, output[40..48], 0x200, .little);
    std.mem.writeInt(u16, output[52..54], 64, .little);
    std.mem.writeInt(u16, output[54..56], 56, .little);
    std.mem.writeInt(u16, output[58..60], 64, .little);
    std.mem.writeInt(u16, output[60..62], 4, .little);
    writeTestSection(&output, 1, 1, 6, 0x10000, 0x100, 0x20, 4, 0);
    writeTestSection(&output, 2, 1, 3, 0x20000, 0x140, 0x10, 8, 0);
    writeTestSection(&output, 3, 4, 2, 0x30000, 0x160, 0x18, 8, 24);
    std.mem.writeInt(u32, output[0x100..0x104], 0x1400_0002, .little);
    for (output[0x104..0x120]) |*byte| byte.* = 0x1f;
    std.mem.writeInt(u64, output[0x140..0x148], 0x10008, .little);
    std.mem.writeInt(u64, output[0x160..0x168], 0x20000, .little);
    std.mem.writeInt(u64, output[0x168..0x170], 0x403, .little);
    return output;
}

fn writeTestSection(
    output: []u8,
    index: usize,
    kind: u32,
    flags: u64,
    address: u64,
    offset: u64,
    size: u64,
    alignment: u64,
    entry_size: u64,
) void {
    const base = 0x200 + index * 64;
    std.mem.writeInt(u32, output[base + 4 ..][0..4], kind, .little);
    std.mem.writeInt(u64, output[base + 8 ..][0..8], flags, .little);
    std.mem.writeInt(u64, output[base + 16 ..][0..8], address, .little);
    std.mem.writeInt(u64, output[base + 24 ..][0..8], offset, .little);
    std.mem.writeInt(u64, output[base + 32 ..][0..8], size, .little);
    std.mem.writeInt(u64, output[base + 48 ..][0..8], alignment, .little);
    std.mem.writeInt(u64, output[base + 56 ..][0..8], entry_size, .little);
}
