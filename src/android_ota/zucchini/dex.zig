//! Zucchini DEX reference extraction and rewriting.

const std = @import("std");
const code = @import("dex_code.zig");
const intel = @import("intel.zig");
const types = @import("dex_types.zig");

pub const Error = std.mem.Allocator.Error || error{
    InvalidDex,
    InvalidReference,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const ReferenceType = types.ReferenceType;
pub const Reference = intel.Reference;
pub const pool_count = types.pool_count;

pub const Options = struct {
    max_map_items: usize = 21,
    max_items: usize = 1 << 24,
    max_references: usize = 1 << 24,
};

const image_size_bound = 0x7fff_0000;

const VariableOffsets = struct {
    type_list: []u32,
    annotation_set_ref: []u32,
    annotation_set: []u32,
    annotations_directory: []u32,
    field_annotation: []u32,
    method_annotation: []u32,
    parameter_annotation: []u32,
    code_item: []u32,

    fn deinit(self: *VariableOffsets, allocator: std.mem.Allocator) void {
        allocator.free(self.type_list);
        allocator.free(self.annotation_set_ref);
        allocator.free(self.annotation_set);
        allocator.free(self.annotations_directory);
        allocator.free(self.field_annotation);
        allocator.free(self.method_annotation);
        allocator.free(self.parameter_annotation);
        allocator.free(self.code_item);
        self.* = undefined;
    }
};

pub const Executable = struct {
    allocator: std.mem.Allocator,
    image: []const u8,
    version: u16,
    maps: types.Maps,
    map_items: []types.MapItem,
    variable_offsets: VariableOffsets,
    references: [types.reference_type_count][]Reference,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: Options,
    ) Error!Executable {
        if (input.len < 112 or input.len >= image_size_bound or
            !std.mem.eql(u8, input[0..4], "dex\n") or input[7] != 0)
        {
            return error.InvalidDex;
        }
        var version: u16 = 0;
        for (input[4..7]) |byte| {
            if (byte < '0' or byte > '9') return error.InvalidDex;
            version = version * 10 + byte - '0';
        }
        if (version != 35 and version != 37 and version != 38 and version != 39)
            return error.InvalidDex;
        const file_size: usize = readU32(input, 32);
        const map_offset: usize = readU32(input, 52);
        if (file_size != input.len or file_size < 112 or map_offset < 112 or
            !rangeFits(map_offset, 4, file_size))
        {
            return error.InvalidDex;
        }
        const map_count: usize = readU32(input, map_offset);
        if (map_count > 21 or map_count > options.max_map_items or
            !rangeFitsArray(map_offset + 4, map_count, 12, file_size))
        {
            return error.InvalidDex;
        }
        const map_items = try allocator.alloc(types.MapItem, map_count);
        errdefer allocator.free(map_items);
        var maps: types.Maps = .{};
        for (map_items, 0..) |*item, index| {
            const base = map_offset + 4 + index * 12;
            item.* = .{
                .kind = readU16(input, base),
                .count = readU32(input, base + 4),
                .offset = readU32(input, base + 8),
            };
            if (item.count > options.max_items or
                !rangeFitsArray(item.offset, item.count, types.baseSize(item.kind), file_size))
            {
                return error.InvalidDex;
            }
            for (map_items[0..index]) |previous|
                if (previous.kind == item.kind) return error.InvalidDex;
            types.installKnownMap(&maps, item.*);
        }

        const type_list = try parseItemOffsetsAlloc(
            allocator,
            input,
            maps.type_list,
            2,
            options.max_items,
        );
        errdefer allocator.free(type_list);
        const annotation_set_ref = try parseItemOffsetsAlloc(
            allocator,
            input,
            maps.annotation_set_ref_list,
            4,
            options.max_items,
        );
        errdefer allocator.free(annotation_set_ref);
        const annotation_set = try parseItemOffsetsAlloc(
            allocator,
            input,
            maps.annotation_set,
            4,
            options.max_items,
        );
        errdefer allocator.free(annotation_set);
        var annotations = try parseAnnotationsAlloc(
            allocator,
            input,
            maps.annotations_directory,
            options.max_items,
        );
        errdefer annotations.deinit(allocator);
        const code_items = code.parseCodeItemsAlloc(
            allocator,
            input,
            maps.code,
            options.max_items,
        ) catch |err| return mapCodeError(err);
        errdefer allocator.free(code_items);

        var lists: code.ReferenceLists = @splat(.empty);
        errdefer for (&lists) |*list| list.deinit(allocator);
        try collectFixedReferences(
            allocator,
            input,
            maps,
            .{
                .type_list = type_list,
                .annotation_set_ref = annotation_set_ref,
                .annotation_set = annotation_set,
                .annotations_directory = annotations.directory.items,
                .field_annotation = annotations.field.items,
                .method_annotation = annotations.method.items,
                .parameter_annotation = annotations.parameter.items,
                .code_item = code_items,
            },
            &lists,
            options.max_references,
        );
        code.collectReferences(
            allocator,
            input,
            maps,
            code_items,
            &lists,
            options.max_references,
        ) catch |err| return mapCodeError(err);
        for (&lists) |*list| std.mem.sort(Reference, list.items, {}, lessReference);

        var references: [types.reference_type_count][]Reference = undefined;
        var converted: usize = 0;
        errdefer for (references[0..converted]) |slice| allocator.free(slice);
        for (&lists, 0..) |*list, index| {
            references[index] = try list.toOwnedSlice(allocator);
            converted += 1;
        }
        const annotation_directories = try annotations.directory.toOwnedSlice(allocator);
        errdefer allocator.free(annotation_directories);
        const field_annotations = try annotations.field.toOwnedSlice(allocator);
        errdefer allocator.free(field_annotations);
        const method_annotations = try annotations.method.toOwnedSlice(allocator);
        errdefer allocator.free(method_annotations);
        const parameter_annotations = try annotations.parameter.toOwnedSlice(allocator);
        errdefer allocator.free(parameter_annotations);
        const variable_offsets = VariableOffsets{
            .type_list = type_list,
            .annotation_set_ref = annotation_set_ref,
            .annotation_set = annotation_set,
            .annotations_directory = annotation_directories,
            .field_annotation = field_annotations,
            .method_annotation = method_annotations,
            .parameter_annotation = parameter_annotations,
            .code_item = code_items,
        };
        annotations.disarm();
        return .{
            .allocator = allocator,
            .image = input,
            .version = version,
            .maps = maps,
            .map_items = map_items,
            .variable_offsets = variable_offsets,
            .references = references,
        };
    }

    pub fn deinit(self: *Executable) void {
        for (self.references) |references| self.allocator.free(references);
        self.variable_offsets.deinit(self.allocator);
        self.allocator.free(self.map_items);
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
        switch (reference_type) {
            .code_relative8 => try writeRelative(i8, image, reference),
            .code_relative16 => try writeRelative(i16, image, reference),
            .code_relative32 => try writeRelative(i32, image, reference),
            .proto_parameters,
            .class_interfaces,
            .annotations_parameter_set_ref,
            .annotation_set_ref_annotation_set,
            .annotations_class_set,
            .annotations_field_set,
            .annotations_method_set,
            .class_data,
            .string_data,
            .annotation,
            .encoded_array,
            .annotations_directory,
            .call_site,
            => {
                if (!rangeFits(reference.location, 4, image.len) or
                    reference.target >= image.len)
                {
                    return error.InvalidReference;
                }
                std.mem.writeInt(
                    u32,
                    image[reference.location..][0..4],
                    reference.target,
                    .little,
                );
            },
            else => {
                const target = targetMap(self.maps, reference_type);
                const item_size = targetItemSize(reference_type);
                if (reference.target < target.offset) return error.InvalidReference;
                const delta = reference.target - target.offset;
                if (item_size == 0 or delta % item_size != 0)
                    return error.InvalidReference;
                const index = delta / item_size;
                if (index >= target.count) return error.InvalidReference;
                const width = referenceWidth(reference_type);
                if (!rangeFits(reference.location, width, image.len))
                    return error.InvalidReference;
                switch (width) {
                    2 => {
                        if (index > std.math.maxInt(u16)) return error.InvalidReference;
                        std.mem.writeInt(
                            u16,
                            image[reference.location..][0..2],
                            @intCast(index),
                            .little,
                        );
                    },
                    4 => std.mem.writeInt(
                        u32,
                        image[reference.location..][0..4],
                        index,
                        .little,
                    ),
                    else => unreachable,
                }
            },
        }
    }
};

const AnnotationOffsets = struct {
    directory: std.ArrayList(u32) = .empty,
    field: std.ArrayList(u32) = .empty,
    method: std.ArrayList(u32) = .empty,
    parameter: std.ArrayList(u32) = .empty,

    fn deinit(self: *AnnotationOffsets, allocator: std.mem.Allocator) void {
        self.directory.deinit(allocator);
        self.field.deinit(allocator);
        self.method.deinit(allocator);
        self.parameter.deinit(allocator);
    }

    fn disarm(self: *AnnotationOffsets) void {
        self.* = .{};
    }
};

fn parseItemOffsetsAlloc(
    allocator: std.mem.Allocator,
    image: []const u8,
    map: types.MapItem,
    item_width: usize,
    max_items: usize,
) Error![]u32 {
    var output: std.ArrayList(u32) = .empty;
    errdefer output.deinit(allocator);
    if (!rangeFitsArray(map.offset, map.count, 4, image.len))
        return error.InvalidDex;
    var cursor: usize = map.offset;
    for (0..map.count) |_| {
        cursor = try alignForward(cursor, 4, image.len);
        if (!rangeFits(cursor, 4, image.len)) return error.InvalidDex;
        const count: usize = readU32(image, cursor);
        cursor += 4;
        if (!rangeFitsArray(cursor, count, item_width, image.len) or
            count > max_items -| output.items.len)
        {
            return error.InvalidDex;
        }
        try output.ensureUnusedCapacity(allocator, count);
        for (0..count) |_| {
            output.appendAssumeCapacity(@intCast(cursor));
            cursor += item_width;
        }
    }
    return output.toOwnedSlice(allocator);
}

fn parseAnnotationsAlloc(
    allocator: std.mem.Allocator,
    image: []const u8,
    map: types.MapItem,
    max_items: usize,
) Error!AnnotationOffsets {
    var output: AnnotationOffsets = .{};
    errdefer output.deinit(allocator);
    if (!rangeFitsArray(map.offset, map.count, 16, image.len))
        return error.InvalidDex;
    var cursor: usize = map.offset;
    for (0..map.count) |_| {
        cursor = try alignForward(cursor, 4, image.len);
        if (!rangeFits(cursor, 16, image.len) or
            output.directory.items.len >= max_items)
        {
            return error.InvalidDex;
        }
        try output.directory.append(allocator, @intCast(cursor));
        const field_count: usize = readU32(image, cursor + 4);
        const method_count: usize = readU32(image, cursor + 8);
        const parameter_count: usize = readU32(image, cursor + 12);
        cursor += 16;
        try parseAnnotationSublist(
            allocator,
            image,
            &cursor,
            field_count,
            max_items,
            &output.field,
        );
        try parseAnnotationSublist(
            allocator,
            image,
            &cursor,
            method_count,
            max_items,
            &output.method,
        );
        try parseAnnotationSublist(
            allocator,
            image,
            &cursor,
            parameter_count,
            max_items,
            &output.parameter,
        );
    }
    return output;
}

fn parseAnnotationSublist(
    allocator: std.mem.Allocator,
    image: []const u8,
    cursor: *usize,
    count: usize,
    max_items: usize,
    output: *std.ArrayList(u32),
) Error!void {
    if (!rangeFitsArray(cursor.*, count, 8, image.len) or
        count > max_items -| output.items.len)
    {
        return error.InvalidDex;
    }
    try output.ensureUnusedCapacity(allocator, count);
    for (0..count) |_| {
        output.appendAssumeCapacity(@intCast(cursor.*));
        cursor.* += 8;
    }
}

fn collectFixedReferences(
    allocator: std.mem.Allocator,
    image: []const u8,
    maps: types.Maps,
    offsets: VariableOffsets,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    try addIndexItems(allocator, image, maps.type_id, 4, 0, 4, maps.string, 4, .type_descriptor_string, lists, max_references);
    try addIndexItems(allocator, image, maps.proto, 12, 0, 4, maps.string, 4, .proto_shorty_string, lists, max_references);
    try addIndexItems(allocator, image, maps.field, 8, 4, 4, maps.string, 4, .field_name_string, lists, max_references);
    try addIndexItems(allocator, image, maps.method, 8, 4, 4, maps.string, 4, .method_name_string, lists, max_references);
    try addIndexItems(allocator, image, maps.class_def, 32, 16, 4, maps.string, 4, .class_source_string, lists, max_references);

    try addIndexItems(allocator, image, maps.proto, 12, 4, 4, maps.type_id, 4, .proto_return_type, lists, max_references);
    try addIndexItems(allocator, image, maps.field, 8, 0, 2, maps.type_id, 4, .field_class_type, lists, max_references);
    try addIndexItems(allocator, image, maps.field, 8, 2, 2, maps.type_id, 4, .field_type, lists, max_references);
    try addIndexItems(allocator, image, maps.method, 8, 0, 2, maps.type_id, 4, .method_class_type, lists, max_references);
    try addIndexItems(allocator, image, maps.class_def, 32, 0, 4, maps.type_id, 4, .class_type, lists, max_references);
    try addIndexItems(allocator, image, maps.class_def, 32, 8, 4, maps.type_id, 4, .class_super_type, lists, max_references);
    try addCachedIndex(allocator, image, offsets.type_list, 0, 2, maps.type_id, 4, .type_list_type, lists, max_references);

    try addIndexItems(allocator, image, maps.method, 8, 2, 2, maps.proto, 12, .method_proto, lists, max_references);
    try addMethodHandles(allocator, image, maps.method_handle, maps.field, 8, 0, 3, .method_handle_field, lists, max_references);
    try addCachedIndex(allocator, image, offsets.field_annotation, 0, 4, maps.field, 8, .annotations_field, lists, max_references);
    try addMethodHandles(allocator, image, maps.method_handle, maps.method, 8, 4, 8, .method_handle_method, lists, max_references);
    try addCachedIndex(allocator, image, offsets.method_annotation, 0, 4, maps.method, 8, .annotations_method, lists, max_references);
    try addCachedIndex(allocator, image, offsets.parameter_annotation, 0, 4, maps.method, 8, .annotations_parameter_method, lists, max_references);

    try addOffsetItems(allocator, image, maps.proto, 12, 8, .proto_parameters, lists, max_references);
    try addOffsetItems(allocator, image, maps.class_def, 32, 12, .class_interfaces, lists, max_references);
    try addCachedOffset(allocator, image, offsets.parameter_annotation, 4, .annotations_parameter_set_ref, lists, max_references);
    try addCachedOffset(allocator, image, offsets.annotation_set_ref, 0, .annotation_set_ref_annotation_set, lists, max_references);
    try addCachedOffset(allocator, image, offsets.annotations_directory, 0, .annotations_class_set, lists, max_references);
    try addCachedOffset(allocator, image, offsets.field_annotation, 4, .annotations_field_set, lists, max_references);
    try addCachedOffset(allocator, image, offsets.method_annotation, 4, .annotations_method_set, lists, max_references);
    try addOffsetItems(allocator, image, maps.class_def, 32, 24, .class_data, lists, max_references);
    try addOffsetItems(allocator, image, maps.string, 4, 0, .string_data, lists, max_references);
    try addCachedOffset(allocator, image, offsets.annotation_set, 0, .annotation, lists, max_references);
    try addOffsetItems(allocator, image, maps.class_def, 32, 28, .encoded_array, lists, max_references);
    try addOffsetItems(allocator, image, maps.class_def, 32, 20, .annotations_directory, lists, max_references);
    try addOffsetItems(allocator, image, maps.call_site, 4, 0, .call_site, lists, max_references);
}

fn addIndexItems(
    allocator: std.mem.Allocator,
    image: []const u8,
    source: types.MapItem,
    source_size: u8,
    relative_location: u8,
    width: u3,
    target: types.MapItem,
    target_size: u8,
    reference_type: ReferenceType,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    for (0..source.count) |index| {
        const location = @as(usize, source.offset) + index * source_size + relative_location;
        const value: u32 = if (width == 2) readU16(image, location) else readU32(image, location);
        if (value == std.math.maxInt(u32)) continue;
        if (value >= target.count) break;
        try appendReference(allocator, reference_type, @intCast(location), target.offset + value * target_size, lists, max_references);
    }
}

fn addOffsetItems(
    allocator: std.mem.Allocator,
    image: []const u8,
    source: types.MapItem,
    source_size: u8,
    relative_location: u8,
    reference_type: ReferenceType,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    for (0..source.count) |index| {
        const location = @as(usize, source.offset) + index * source_size + relative_location;
        const target = readU32(image, location);
        if (target == 0) continue;
        if (target >= image.len) break;
        try appendReference(allocator, reference_type, @intCast(location), target, lists, max_references);
    }
}

fn addCachedIndex(
    allocator: std.mem.Allocator,
    image: []const u8,
    offsets: []const u32,
    relative_location: u8,
    width: u3,
    target: types.MapItem,
    target_size: u8,
    reference_type: ReferenceType,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    for (offsets) |offset| {
        const location: usize = offset + relative_location;
        const value: u32 = if (width == 2) readU16(image, location) else readU32(image, location);
        if (value >= target.count) break;
        try appendReference(allocator, reference_type, @intCast(location), target.offset + value * target_size, lists, max_references);
    }
}

fn addCachedOffset(
    allocator: std.mem.Allocator,
    image: []const u8,
    offsets: []const u32,
    relative_location: u8,
    reference_type: ReferenceType,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    for (offsets) |offset| {
        const location: usize = offset + relative_location;
        const target = readU32(image, location);
        if (target == 0) continue;
        if (target >= image.len) break;
        try appendReference(allocator, reference_type, @intCast(location), target, lists, max_references);
    }
}

fn addMethodHandles(
    allocator: std.mem.Allocator,
    image: []const u8,
    source: types.MapItem,
    target: types.MapItem,
    target_size: u8,
    min_kind: u16,
    max_kind: u16,
    reference_type: ReferenceType,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    for (0..source.count) |index| {
        const item = @as(usize, source.offset) + index * 8;
        const kind = readU16(image, item);
        if (kind >= 9) break;
        if (kind < min_kind or kind > max_kind) continue;
        const value = readU16(image, item + 4);
        if (value >= target.count) break;
        try appendReference(allocator, reference_type, @intCast(item + 4), target.offset + @as(u32, value) * target_size, lists, max_references);
    }
}

fn appendReference(
    allocator: std.mem.Allocator,
    reference_type: ReferenceType,
    location: u32,
    target: u32,
    lists: *code.ReferenceLists,
    max_references: usize,
) Error!void {
    const output = &lists[@intFromEnum(reference_type)];
    if (output.items.len >= max_references) return error.OutputLimitExceeded;
    try output.append(allocator, .{ .location = location, .target = target });
}

fn targetMap(maps: types.Maps, reference_type: ReferenceType) types.MapItem {
    return switch (reference_type.pool()) {
        0 => maps.string,
        1 => maps.type_id,
        2 => maps.proto,
        3 => maps.field,
        4 => maps.method,
        5 => maps.call_site,
        6 => maps.method_handle,
        else => unreachable,
    };
}

fn targetItemSize(reference_type: ReferenceType) u32 {
    return switch (reference_type.pool()) {
        0, 1, 5 => 4,
        2 => 12,
        3, 4, 6 => 8,
        else => 0,
    };
}

fn referenceWidth(reference_type: ReferenceType) u3 {
    return switch (reference_type) {
        .code_string16,
        .field_class_type,
        .field_type,
        .method_class_type,
        .type_list_type,
        .code_type,
        .code_proto,
        .method_proto,
        .code_field,
        .method_handle_field,
        .code_method,
        .method_handle_method,
        .code_call_site,
        .code_method_handle,
        => 2,
        else => 4,
    };
}

fn writeRelative(comptime Int: type, image: []u8, reference: Reference) Error!void {
    const width = @sizeOf(Int);
    if (!rangeFits(reference.location, width, image.len))
        return error.InvalidReference;
    const byte_delta = @as(i64, reference.target) - reference.location;
    if (@mod(byte_delta, 2) != 0) return error.InvalidReference;
    const delta = @divExact(byte_delta, 2) + 1;
    const encoded = std.math.cast(Int, delta) orelse return error.InvalidReference;
    std.mem.writeInt(Int, image[reference.location..][0..width], encoded, .little);
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

fn mapCodeError(err: code.Error) Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.OutputLimitExceeded => error.OutputLimitExceeded,
        error.IntegerOverflow => error.IntegerOverflow,
        error.InvalidDex => error.InvalidDex,
    };
}

fn alignForward(value: usize, alignment: usize, limit: usize) Error!usize {
    const aligned = std.mem.alignForward(usize, value, alignment);
    if (aligned > limit) return error.InvalidDex;
    return aligned;
}

fn rangeFitsArray(offset: anytype, count: anytype, width: usize, total: usize) bool {
    const n = std.math.cast(usize, count) orelse return false;
    const bytes = std.math.mul(usize, n, width) catch return false;
    return rangeFits(offset, bytes, total);
}

fn rangeFits(offset: anytype, length: anytype, total: usize) bool {
    const start = std.math.cast(usize, offset) orelse return false;
    const size = std.math.cast(usize, length) orelse return false;
    return start <= total and size <= total - start;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

test "Zucchini DEX extracts and rewrites fixed code and relative references" {
    const allocator = std.testing.allocator;
    const image = testDex(0);
    var executable = try Executable.initAlloc(allocator, &image, .{});
    defer executable.deinit();
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 0xb8,
        .target = 0xb0,
    }}, executable.references[@intFromEnum(ReferenceType.type_descriptor_string)]);
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 0xce,
        .target = 0xb0,
    }}, executable.references[@intFromEnum(ReferenceType.code_string16)]);
    try std.testing.expectEqualSlices(Reference, &.{.{
        .location = 0xd2,
        .target = 0xd4,
    }}, executable.references[@intFromEnum(ReferenceType.code_relative16)]);
    try std.testing.expectEqualSlices(Reference, &.{
        .{ .location = 0xb0, .target = 0xd6 },
        .{ .location = 0xb4, .target = 0xd9 },
    }, executable.references[@intFromEnum(ReferenceType.string_data)]);

    var modified = image;
    try executable.writeReference(&modified, .code_string16, .{
        .location = 0xce,
        .target = 0xb4,
    });
    try std.testing.expectEqual(@as(u16, 1), readU16(&modified, 0xce));
    try executable.writeReference(&modified, .code_relative16, .{
        .location = 0xd2,
        .target = 0xcc,
    });
    try std.testing.expectEqual(@as(i16, -2), std.mem.readInt(
        i16,
        modified[0xd2..0xd4],
        .little,
    ));
}

test "Zucchini DEX rejects malformed structures and enforces quotas" {
    const allocator = std.testing.allocator;
    var image = testDex(0);
    try std.testing.expectError(
        error.InvalidDex,
        Executable.initAlloc(allocator, &image, .{ .max_map_items = 4 }),
    );
    try std.testing.expectError(
        error.InvalidDex,
        Executable.initAlloc(allocator, &image, .{ .max_items = 0 }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        Executable.initAlloc(allocator, &image, .{ .max_references = 0 }),
    );
    image[0] = 0;
    try std.testing.expectError(
        error.InvalidDex,
        Executable.initAlloc(allocator, &image, .{}),
    );
    image = testDex(0);
    std.mem.writeInt(u32, image[0x70..0x74], 22, .little);
    try std.testing.expectError(
        error.InvalidDex,
        Executable.initAlloc(allocator, &image, .{}),
    );
}

pub fn testDex(string_index: u16) [0xdc]u8 {
    var output: [0xdc]u8 = @splat(0);
    @memcpy(output[0..8], "dex\n039\x00");
    std.mem.writeInt(u32, output[32..36], output.len, .little);
    std.mem.writeInt(u32, output[36..40], 0x70, .little);
    std.mem.writeInt(u32, output[40..44], 0x1234_5678, .little);
    std.mem.writeInt(u32, output[52..56], 0x70, .little);
    std.mem.writeInt(u32, output[56..60], 2, .little);
    std.mem.writeInt(u32, output[60..64], 0xb0, .little);
    std.mem.writeInt(u32, output[64..68], 1, .little);
    std.mem.writeInt(u32, output[68..72], 0xb8, .little);
    std.mem.writeInt(u32, output[104..108], output.len - 0xbc, .little);
    std.mem.writeInt(u32, output[108..112], 0xbc, .little);

    std.mem.writeInt(u32, output[0x70..0x74], 5, .little);
    writeTestMap(&output, 0, types.map_header, 1, 0);
    writeTestMap(&output, 1, types.map_string_id, 2, 0xb0);
    writeTestMap(&output, 2, types.map_type_id, 1, 0xb8);
    writeTestMap(&output, 3, types.map_code, 1, 0xbc);
    writeTestMap(&output, 4, types.map_string_data, 2, 0xd6);

    std.mem.writeInt(u32, output[0xb0..0xb4], 0xd6, .little);
    std.mem.writeInt(u32, output[0xb4..0xb8], 0xd9, .little);
    std.mem.writeInt(u32, output[0xb8..0xbc], 0, .little);
    std.mem.writeInt(u32, output[0xc8..0xcc], 5, .little);
    output[0xcc] = 0x1a;
    std.mem.writeInt(u16, output[0xce..0xd0], string_index, .little);
    output[0xd0] = 0x29;
    std.mem.writeInt(i16, output[0xd2..0xd4], 2, .little);
    output[0xd4] = 0x0e;
    @memcpy(output[0xd6..0xdc], &[_]u8{ 1, 'A', 0, 1, 'B', 0 });
    updateTestIntegrity(&output);
    return output;
}

fn writeTestMap(
    output: []u8,
    index: usize,
    kind: u16,
    count: u32,
    offset: u32,
) void {
    const base = 0x74 + index * 12;
    std.mem.writeInt(u16, output[base..][0..2], kind, .little);
    std.mem.writeInt(u32, output[base + 4 ..][0..4], count, .little);
    std.mem.writeInt(u32, output[base + 8 ..][0..4], offset, .little);
}

fn updateTestIntegrity(output: []u8) void {
    std.crypto.hash.Sha1.hash(output[32..], output[12..32], .{});
    var sum1: u32 = 1;
    var sum2: u32 = 0;
    for (output[12..]) |byte| {
        sum1 = (sum1 + byte) % 65521;
        sum2 = (sum2 + sum1) % 65521;
    }
    std.mem.writeInt(u32, output[8..12], (sum2 << 16) | sum1, .little);
}
