//! Zucchini Windows PE32/PE32+ reference extraction and rewriting.

const std = @import("std");
const intel = @import("intel.zig");

pub const Error = std.mem.Allocator.Error || error{
    InvalidPe,
    InvalidReference,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const ReferenceType = intel.ReferenceType;
pub const Reference = intel.Reference;
pub const pool_count = intel.pool_count;

pub const Options = struct {
    max_sections: usize = 1 << 20,
    max_reloc_blocks: usize = 1 << 20,
    max_references: usize = 1 << 24,
};

pub const X86 = Architecture(.x86);
pub const X64 = Architecture(.x64);

fn Architecture(comptime kind: intel.Kind) type {
    return struct {
        pub const ReferenceType = @import("pe.zig").ReferenceType;
        pub const pool_count = @import("pe.zig").pool_count;
        pub const Executable = ImageImpl(kind);
    };
}

const image_size_bound = 0x7fff_0000;
const pe_signature = "PE\x00\x00";
const code_characteristics: u32 = 0x6000_0000;
const base_relocation_index = 5;

const Section = struct {
    virtual_size: u32,
    virtual_address: u32,
    raw_size: u32,
    raw_offset: u32,
    characteristics: u32,

    fn isCode(self: Section) bool {
        return self.characteristics & code_characteristics == code_characteristics;
    }
};

const RelocBlock = struct {
    offset: u32,
    end: u32,
    rva_hi: u32,
};

fn ImageImpl(comptime kind: intel.Kind) type {
    const is_64 = kind == .x64;
    const optional_magic: u16 = if (is_64) 0x20b else 0x10b;
    const optional_header_len: usize = if (is_64) 0xf0 else 0xe0;
    const data_directory_offset: usize = if (is_64) 0x70 else 0x60;
    const directory_count_offset: usize = if (is_64) 0x6c else 0x5c;
    const image_base_offset: usize = if (is_64) 0x18 else 0x1c;
    const value_width: usize = if (is_64) 8 else 4;
    const relocation_type: u16 = if (is_64) 10 else 3;

    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        image: []const u8,
        image_base: u64,
        translator: intel.Translator,
        sections: []Section,
        reloc_blocks: []RelocBlock,
        references: [3][]Reference,

        pub fn initAlloc(
            allocator: std.mem.Allocator,
            image: []const u8,
            options: Options,
        ) Error!Self {
            if (image.len < 0x40 or image.len >= image_size_bound or
                !std.mem.eql(u8, image[0..2], "MZ"))
            {
                return error.InvalidPe;
            }
            const pe_offset: usize = readU32(image, 0x3c);
            if (pe_offset & 7 != 0 or pe_offset < 0x40 or
                !rangeFits(pe_offset, 4 + 20, image.len) or
                !std.mem.eql(u8, image[pe_offset..][0..4], pe_signature))
            {
                return error.InvalidPe;
            }
            const coff_offset = pe_offset + 4;
            const section_count: usize = readU16(image, coff_offset + 2);
            const optional_size: usize = readU16(image, coff_offset + 16);
            const optional_offset = coff_offset + 20;
            if (section_count > options.max_sections or
                optional_size < data_directory_offset or
                !rangeFits(optional_offset, optional_header_len, image.len) or
                readU16(image, optional_offset) != optional_magic)
            {
                return error.InvalidPe;
            }
            const directory_bytes = optional_size - data_directory_offset;
            if (directory_bytes % 8 != 0) return error.InvalidPe;
            const directory_count = directory_bytes / 8;
            if (directory_count != readU32(image, optional_offset + directory_count_offset) or
                directory_count > 16 or directory_count <= base_relocation_index)
            {
                return error.InvalidPe;
            }
            const relocation_directory = optional_offset + data_directory_offset +
                base_relocation_index * 8;
            const relocation_rva = readU32(image, relocation_directory);
            const relocation_size = readU32(image, relocation_directory + 4);
            const image_base = if (is_64)
                readU64(image, optional_offset + image_base_offset)
            else
                readU32(image, optional_offset + image_base_offset);
            const rva_bound = readU32(image, optional_offset + 0x38);
            if (rva_bound >= intel.offset_bound) return error.InvalidPe;

            const section_offset = optional_offset + optional_header_len;
            const section_bytes = try checkedMul(section_count, 40);
            if (!rangeFits(section_offset, section_bytes, image.len))
                return error.InvalidPe;
            var physical_end = section_offset + section_bytes;
            const sections = try allocator.alloc(Section, section_count);
            errdefer allocator.free(sections);
            var units: std.ArrayList(intel.Unit) = .empty;
            defer units.deinit(allocator);
            try units.ensureTotalCapacity(allocator, section_count);
            var has_code = false;
            for (sections, 0..) |*section, index| {
                const base = section_offset + index * 40;
                section.* = .{
                    .virtual_size = readU32(image, base + 8),
                    .virtual_address = readU32(image, base + 12),
                    .raw_size = readU32(image, base + 16),
                    .raw_offset = readU32(image, base + 20),
                    .characteristics = readU32(image, base + 36),
                };
                if (!rangeFits(section.raw_offset, section.raw_size, image.len) or
                    !rangeFitsU32(
                        section.virtual_address,
                        section.virtual_size,
                        rva_bound,
                    ))
                {
                    return error.InvalidPe;
                }
                units.appendAssumeCapacity(.{
                    .offset = section.raw_offset,
                    .size = section.raw_size,
                    .rva = section.virtual_address,
                    .rva_size = section.virtual_size,
                });
                physical_end = @max(
                    physical_end,
                    @as(usize, section.raw_offset) + section.raw_size,
                );
                has_code = has_code or section.isCode();
            }
            if (!has_code or physical_end != image.len) return error.InvalidPe;
            var translator = intel.initTranslatorAlloc(allocator, units.items) catch |err|
                return mapTranslatorError(err);
            errdefer translator.deinit(allocator);
            const reloc_blocks = try parseRelocBlocksAlloc(
                allocator,
                image,
                translator,
                relocation_rva,
                relocation_size,
                options.max_reloc_blocks,
            );
            errdefer allocator.free(reloc_blocks);

            var lists: [3]std.ArrayList(Reference) = @splat(.empty);
            errdefer for (&lists) |*list| list.deinit(allocator);
            try collectRelocations(
                kind,
                allocator,
                image,
                translator,
                reloc_blocks,
                relocation_type,
                &lists[0],
                options.max_references,
            );
            try collectAbsolute(
                kind,
                allocator,
                image,
                image_base,
                translator,
                lists[0].items,
                &lists[1],
                options.max_references,
            );
            try collectRelative(
                kind,
                allocator,
                image,
                sections,
                translator,
                lists[1].items,
                &lists[2],
                options.max_references,
            );
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
                .image_base = image_base,
                .translator = translator,
                .sections = sections,
                .reloc_blocks = reloc_blocks,
                .references = references,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.references) |references| self.allocator.free(references);
            self.allocator.free(self.reloc_blocks);
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
                .relocation => {
                    const block = findRelocBlock(self.reloc_blocks, reference.location) orelse
                        return error.InvalidReference;
                    if (location < @as(usize, block.offset) + 8 or
                        !rangeFits(location, 2, block.end) or
                        (location - block.offset) % 2 != 0 or
                        target_rva < block.rva_hi or target_rva - block.rva_hi > 0xfff)
                    {
                        return error.InvalidReference;
                    }
                    std.mem.writeInt(
                        u16,
                        image[location..][0..2],
                        @as(u16, relocation_type << 12) | @as(u16, @intCast(target_rva - block.rva_hi)),
                        .little,
                    );
                },
                .absolute => {
                    if (!rangeFits(location, value_width, image.len))
                        return error.InvalidReference;
                    const value = std.math.add(u64, self.image_base, target_rva) catch
                        return error.InvalidReference;
                    if (is_64)
                        std.mem.writeInt(u64, image[location..][0..8], value, .little)
                    else {
                        if (value > std.math.maxInt(u32)) return error.InvalidReference;
                        std.mem.writeInt(u32, image[location..][0..4], @intCast(value), .little);
                    }
                },
                .relative => {
                    if (!rangeFits(location, 4, image.len))
                        return error.InvalidReference;
                    const location_rva = self.translator.offsetToRva(reference.location) orelse
                        return error.InvalidReference;
                    std.mem.writeInt(
                        u32,
                        image[location..][0..4],
                        target_rva -% (location_rva +% 4),
                        .little,
                    );
                },
            }
        }
    };
}

fn parseRelocBlocksAlloc(
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: intel.Translator,
    relocation_rva: u32,
    relocation_size: u32,
    max_blocks: usize,
) Error![]RelocBlock {
    var output: std.ArrayList(RelocBlock) = .empty;
    errdefer output.deinit(allocator);
    if (relocation_size == 0) return output.toOwnedSlice(allocator);
    const offset = translator.rvaToOffset(relocation_rva) orelse
        return output.toOwnedSlice(allocator);
    if (!rangeFits(offset, relocation_size, image.len))
        return output.toOwnedSlice(allocator);
    var cursor: usize = offset;
    const end = cursor + relocation_size;
    var valid = true;
    while (end - cursor >= 8) {
        const size: usize = readU32(image, cursor + 4);
        if (size < 8 or size % 4 != 0 or size > end - cursor) {
            valid = false;
            break;
        }
        if (output.items.len >= max_blocks) return error.OutputLimitExceeded;
        try output.append(allocator, .{
            .offset = @intCast(cursor),
            .end = @intCast(cursor + size),
            .rva_hi = readU32(image, cursor),
        });
        cursor += size;
    }
    if (cursor != end) valid = false;
    if (!valid) output.clearRetainingCapacity();
    return output.toOwnedSlice(allocator);
}

fn collectRelocations(
    comptime kind: intel.Kind,
    allocator: std.mem.Allocator,
    image: []const u8,
    translator: intel.Translator,
    blocks: []const RelocBlock,
    relocation_type: u16,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const width: usize = if (kind == .x64) 8 else 4;
    for (blocks) |block| {
        var cursor: usize = block.offset + 8;
        while (cursor + 2 <= block.end) : (cursor += 2) {
            const entry = readU16(image, cursor);
            if (entry >> 12 != relocation_type) continue;
            const target_rva = block.rva_hi +% (entry & 0xfff);
            const target = translator.rvaToOffset(target_rva) orelse continue;
            if (!rangeFits(target, width, image.len)) continue;
            if (output.items.len >= max_references) return error.OutputLimitExceeded;
            try output.append(allocator, .{
                .location = @intCast(cursor),
                .target = target,
            });
        }
    }
}

fn collectAbsolute(
    comptime kind: intel.Kind,
    allocator: std.mem.Allocator,
    image: []const u8,
    image_base: u64,
    translator: intel.Translator,
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
        const value = if (kind == .x64) readU64(image, location) else readU32(image, location);
        if (value < image_base) continue;
        const raw_rva = value - image_base;
        if (raw_rva >= intel.offset_bound) continue;
        const target = translator.rvaToOffset(@intCast(raw_rva)) orelse continue;
        if (output.items.len >= max_references) return error.OutputLimitExceeded;
        try output.append(allocator, .{ .location = location, .target = target });
        previous_end = @as(usize, location) + width;
    }
}

fn collectRelative(
    comptime kind: intel.Kind,
    allocator: std.mem.Allocator,
    image: []const u8,
    sections: []const Section,
    translator: intel.Translator,
    absolutes: []const Reference,
    output: *std.ArrayList(Reference),
    max_references: usize,
) Error!void {
    const abs_width: usize = if (kind == .x64) 8 else 4;
    for (sections) |section| {
        if (!section.isCode()) continue;
        const start: usize = section.raw_offset;
        const end = start + @min(section.virtual_size, section.raw_size);
        var cursor = start;
        while (cursor < end) {
            const candidate = intel.findRelative(kind, image, cursor, end) orelse {
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
            const target_rva = location_rva +% 4 +% readU32(image, candidate.location);
            const target = translator.rvaToOffset(target_rva) orelse {
                cursor += 1;
                continue;
            };
            const inside_section = target_rva >= section.virtual_address and
                target_rva - section.virtual_address < section.virtual_size;
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

fn findRelocBlock(blocks: []const RelocBlock, location: u32) ?RelocBlock {
    var low: usize = 0;
    var high = blocks.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        if (blocks[mid].offset <= location) low = mid + 1 else high = mid;
    }
    if (low == 0) return null;
    const block = blocks[low - 1];
    return if (location < block.end) block else null;
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

fn mapTranslatorError(err: intel.Error) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.OutputLimitExceeded => error.OutputLimitExceeded,
        error.IntegerOverflow => error.IntegerOverflow,
        error.InvalidElf, error.InvalidReference => error.InvalidPe,
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

fn readU64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

test "Zucchini PE32 and PE32+ extract and rewrite all reference groups" {
    const allocator = std.testing.allocator;
    inline for (.{ intel.Kind.x86, intel.Kind.x64 }) |kind| {
        const image = testPe(kind, 0x208);
        const Engine = if (kind == .x86) X86 else X64;
        var pe = try Engine.Executable.initAlloc(allocator, &image, .{});
        defer pe.deinit();
        try std.testing.expectEqualSlices(
            Reference,
            &.{.{ .location = 0x328, .target = 0x300 }},
            pe.references[@intFromEnum(ReferenceType.relocation)],
        );
        try std.testing.expectEqualSlices(
            Reference,
            &.{.{ .location = 0x300, .target = 0x208 }},
            pe.references[@intFromEnum(ReferenceType.absolute)],
        );
        try std.testing.expectEqualSlices(
            Reference,
            &.{.{ .location = 0x201, .target = 0x208 }},
            pe.references[@intFromEnum(ReferenceType.relative)],
        );

        var modified = image;
        try pe.writeReference(&modified, .relocation, .{
            .location = 0x328,
            .target = 0x308,
        });
        try pe.writeReference(&modified, .absolute, .{
            .location = 0x300,
            .target = 0x20c,
        });
        try pe.writeReference(&modified, .relative, .{
            .location = 0x201,
            .target = 0x20c,
        });
        try std.testing.expectEqual(
            @as(u16, if (kind == .x64) 0xa008 else 0x3008),
            readU16(&modified, 0x328),
        );
        if (kind == .x64)
            try std.testing.expectEqual(@as(u64, 0x14000100c), readU64(&modified, 0x300))
        else
            try std.testing.expectEqual(@as(u32, 0x40100c), readU32(&modified, 0x300));
        try std.testing.expectEqual(@as(u32, 7), readU32(&modified, 0x201));
    }
}

test "Zucchini PE base-relocation reader matches AOSP vectors" {
    const allocator = std.testing.allocator;
    var image: [0x3000]u8 = @splat(0xff);
    const relocation_data = [_]u8{
        0x00, 0x10, 0x04, 0x00, 0x10, 0x00, 0x00, 0x00,
        0xc0, 0x32, 0x18, 0xa3, 0xf8, 0xa7, 0xff, 0x0f,
        0x00, 0x20, 0x04, 0x00, 0x10, 0x00, 0x00, 0x00,
        0x80, 0xa0, 0x65, 0x31, 0xf8, 0x37, 0xbc, 0x3a,
    };
    @memcpy(image[0x600..][0..relocation_data.len], &relocation_data);
    var translator = try intel.initTranslatorAlloc(allocator, &.{.{
        .offset = 0,
        .size = image.len,
        .rva = 0x40000,
        .rva_size = image.len,
    }});
    defer translator.deinit(allocator);
    const blocks = try parseRelocBlocksAlloc(
        allocator,
        &image,
        translator,
        0x40600,
        relocation_data.len,
        8,
    );
    defer allocator.free(blocks);
    try std.testing.expectEqualSlices(RelocBlock, &.{
        .{ .offset = 0x600, .end = 0x610, .rva_hi = 0x41000 },
        .{ .offset = 0x610, .end = 0x620, .rva_hi = 0x42000 },
    }, blocks);
    var references: std.ArrayList(Reference) = .empty;
    defer references.deinit(allocator);
    try collectRelocations(
        .x86,
        allocator,
        &image,
        translator,
        blocks,
        3,
        &references,
        8,
    );
    try std.testing.expectEqualSlices(Reference, &.{
        .{ .location = 0x608, .target = 0x12c0 },
        .{ .location = 0x61a, .target = 0x2165 },
        .{ .location = 0x61c, .target = 0x27f8 },
        .{ .location = 0x61e, .target = 0x2abc },
    }, references.items);
}

test "Zucchini PE rejects malformed headers and enforces quotas" {
    const allocator = std.testing.allocator;
    inline for (.{ intel.Kind.x86, intel.Kind.x64 }) |kind| {
        const Engine = if (kind == .x86) X86 else X64;
        var image = testPe(kind, 0x208);
        try std.testing.expectError(
            error.InvalidPe,
            Engine.Executable.initAlloc(allocator, &image, .{ .max_sections = 1 }),
        );
        try std.testing.expectError(
            error.OutputLimitExceeded,
            Engine.Executable.initAlloc(allocator, &image, .{ .max_reloc_blocks = 0 }),
        );
        try std.testing.expectError(
            error.OutputLimitExceeded,
            Engine.Executable.initAlloc(allocator, &image, .{ .max_references = 0 }),
        );

        image[0] = 0;
        try std.testing.expectError(
            error.InvalidPe,
            Engine.Executable.initAlloc(allocator, &image, .{}),
        );
        image = testPe(kind, 0x208);
        std.mem.writeInt(u32, image[0x3c..0x40], 0xffff_fff8, .little);
        try std.testing.expectError(
            error.InvalidPe,
            Engine.Executable.initAlloc(allocator, &image, .{}),
        );

        // AOSP treats a malformed relocation directory as a PE with no
        // relocation/absolute groups; executable rel32 scanning still works.
        image = testPe(kind, 0x208);
        std.mem.writeInt(u32, image[0x324..0x328], 10, .little);
        var pe = try Engine.Executable.initAlloc(allocator, &image, .{});
        defer pe.deinit();
        try std.testing.expectEqual(@as(usize, 0), pe.references[0].len);
        try std.testing.expectEqual(@as(usize, 0), pe.references[1].len);
        try std.testing.expectEqual(@as(usize, 1), pe.references[2].len);
    }
}

pub fn testPe(
    comptime kind: intel.Kind,
    target_offset: u32,
) [0x400]u8 {
    const is_64 = kind == .x64;
    const optional_len: usize = if (is_64) 0xf0 else 0xe0;
    const directory_offset: usize = if (is_64) 0x70 else 0x60;
    const image_base: u64 = if (is_64) 0x1_4000_0000 else 0x40_0000;
    var output: [0x400]u8 = @splat(0);
    @memcpy(output[0..2], "MZ");
    std.mem.writeInt(u32, output[0x3c..0x40], 0x80, .little);
    @memcpy(output[0x80..0x84], pe_signature);
    std.mem.writeInt(u16, output[0x84..0x86], if (is_64) 0x8664 else 0x14c, .little);
    std.mem.writeInt(u16, output[0x86..0x88], 2, .little);
    std.mem.writeInt(u16, output[0x94..0x96], optional_len, .little);
    const optional = 0x98;
    std.mem.writeInt(u16, output[optional..][0..2], if (is_64) 0x20b else 0x10b, .little);
    if (is_64)
        std.mem.writeInt(u64, output[optional + 0x18 ..][0..8], image_base, .little)
    else
        std.mem.writeInt(u32, output[optional + 0x1c ..][0..4], @intCast(image_base), .little);
    std.mem.writeInt(u32, output[optional + 0x38 ..][0..4], 0x3000, .little);
    std.mem.writeInt(
        u32,
        output[optional + (if (is_64) 0x6c else 0x5c) ..][0..4],
        16,
        .little,
    );
    const reloc_directory = optional + directory_offset + base_relocation_index * 8;
    std.mem.writeInt(u32, output[reloc_directory..][0..4], 0x2020, .little);
    std.mem.writeInt(u32, output[reloc_directory + 4 ..][0..4], 12, .little);

    const sections = optional + optional_len;
    writeTestSection(&output, sections, 0, 0x40, 0x1000, 0x40, 0x200, code_characteristics);
    writeTestSection(&output, sections, 1, 0x100, 0x2000, 0x100, 0x300, 0x4000_0000);
    output[0x200] = 0xe8;
    std.mem.writeInt(u32, output[0x201..0x205], target_offset - 0x205, .little);
    if (is_64)
        std.mem.writeInt(u64, output[0x300..0x308], image_base + 0x1008, .little)
    else
        std.mem.writeInt(u32, output[0x300..0x304], @intCast(image_base + 0x1008), .little);
    std.mem.writeInt(u32, output[0x320..0x324], 0x2000, .little);
    std.mem.writeInt(u32, output[0x324..0x328], 12, .little);
    std.mem.writeInt(u16, output[0x328..0x32a], if (is_64) 0xa000 else 0x3000, .little);
    return output;
}

fn writeTestSection(
    output: []u8,
    section_offset: usize,
    index: usize,
    virtual_size: u32,
    virtual_address: u32,
    raw_size: u32,
    raw_offset: u32,
    characteristics: u32,
) void {
    const base = section_offset + index * 40;
    std.mem.writeInt(u32, output[base + 8 ..][0..4], virtual_size, .little);
    std.mem.writeInt(u32, output[base + 12 ..][0..4], virtual_address, .little);
    std.mem.writeInt(u32, output[base + 16 ..][0..4], raw_size, .little);
    std.mem.writeInt(u32, output[base + 20 ..][0..4], raw_offset, .little);
    std.mem.writeInt(u32, output[base + 36 ..][0..4], characteristics, .little);
}
