//! DEX wire constants and Zucchini reference taxonomy.

pub const ReferenceType = enum(u6) {
    type_descriptor_string,
    proto_shorty_string,
    field_name_string,
    method_name_string,
    class_source_string,
    code_string16,
    code_string32,

    proto_return_type,
    field_class_type,
    field_type,
    method_class_type,
    class_type,
    class_super_type,
    type_list_type,
    code_type,

    code_proto,
    method_proto,

    code_field,
    method_handle_field,
    annotations_field,

    code_method,
    method_handle_method,
    annotations_method,
    annotations_parameter_method,

    code_call_site,
    code_method_handle,

    proto_parameters,
    class_interfaces,

    annotations_parameter_set_ref,

    annotation_set_ref_annotation_set,
    annotations_class_set,
    annotations_field_set,
    annotations_method_set,

    class_data,

    code_relative8,
    code_relative16,
    code_relative32,

    string_data,
    annotation,
    encoded_array,
    annotations_directory,
    call_site,

    pub fn pool(self: ReferenceType) u8 {
        return switch (self) {
            .type_descriptor_string,
            .proto_shorty_string,
            .field_name_string,
            .method_name_string,
            .class_source_string,
            .code_string16,
            .code_string32,
            => 0,
            .proto_return_type,
            .field_class_type,
            .field_type,
            .method_class_type,
            .class_type,
            .class_super_type,
            .type_list_type,
            .code_type,
            => 1,
            .code_proto, .method_proto => 2,
            .code_field, .method_handle_field, .annotations_field => 3,
            .code_method,
            .method_handle_method,
            .annotations_method,
            .annotations_parameter_method,
            => 4,
            .code_call_site => 5,
            .code_method_handle => 6,
            .proto_parameters, .class_interfaces => 7,
            .annotations_parameter_set_ref => 8,
            .annotation_set_ref_annotation_set,
            .annotations_class_set,
            .annotations_field_set,
            .annotations_method_set,
            => 9,
            .class_data => 10,
            .code_relative8, .code_relative16, .code_relative32 => 11,
            .string_data => 12,
            .annotation => 13,
            .encoded_array => 14,
            .annotations_directory => 15,
            .call_site => 16,
        };
    }
};

pub const pool_count: usize = 17;
pub const reference_type_count: usize = 42;

pub const MapItem = struct {
    kind: u16 = 0,
    count: u32 = 0,
    offset: u32 = 0,
};

pub const Maps = struct {
    string: MapItem = .{},
    type_id: MapItem = .{},
    proto: MapItem = .{},
    field: MapItem = .{},
    method: MapItem = .{},
    class_def: MapItem = .{},
    call_site: MapItem = .{},
    method_handle: MapItem = .{},
    type_list: MapItem = .{},
    annotation_set_ref_list: MapItem = .{},
    annotation_set: MapItem = .{},
    code: MapItem = .{},
    annotations_directory: MapItem = .{},
};

pub const map_header: u16 = 0x0000;
pub const map_string_id: u16 = 0x0001;
pub const map_type_id: u16 = 0x0002;
pub const map_proto_id: u16 = 0x0003;
pub const map_field_id: u16 = 0x0004;
pub const map_method_id: u16 = 0x0005;
pub const map_class_def: u16 = 0x0006;
pub const map_call_site_id: u16 = 0x0007;
pub const map_method_handle: u16 = 0x0008;
pub const map_list: u16 = 0x1000;
pub const map_type_list: u16 = 0x1001;
pub const map_annotation_set_ref_list: u16 = 0x1002;
pub const map_annotation_set: u16 = 0x1003;
pub const map_class_data: u16 = 0x2000;
pub const map_code: u16 = 0x2001;
pub const map_string_data: u16 = 0x2002;
pub const map_debug_info: u16 = 0x2003;
pub const map_annotation: u16 = 0x2004;
pub const map_encoded_array: u16 = 0x2005;
pub const map_annotations_directory: u16 = 0x2006;
pub const map_hidden_api: u16 = 0xf000;

pub fn baseSize(kind: u16) usize {
    return switch (kind) {
        map_string_id, map_type_id, map_call_site_id => 4,
        map_proto_id => 12,
        map_field_id, map_method_id, map_method_handle => 8,
        map_class_def => 32,
        map_type_list, map_annotation_set_ref_list, map_annotation_set => 4,
        map_code, map_annotations_directory => 16,
        else => 1,
    };
}

pub fn installKnownMap(maps: *Maps, item: MapItem) void {
    switch (item.kind) {
        map_string_id => maps.string = item,
        map_type_id => maps.type_id = item,
        map_proto_id => maps.proto = item,
        map_field_id => maps.field = item,
        map_method_id => maps.method = item,
        map_class_def => maps.class_def = item,
        map_call_site_id => maps.call_site = item,
        map_method_handle => maps.method_handle = item,
        map_type_list => maps.type_list = item,
        map_annotation_set_ref_list => maps.annotation_set_ref_list = item,
        map_annotation_set => maps.annotation_set = item,
        map_code => maps.code = item,
        map_annotations_directory => maps.annotations_directory = item,
        else => {},
    }
}

pub const Format = enum { c, t, other };

pub const Instruction = struct {
    opcode: u8,
    units: u8,
    format: Format,
    variants: u8 = 1,
};

const instructions = [_]Instruction{
    .{ .opcode = 0x00, .units = 1, .format = .other },
    .{ .opcode = 0x01, .units = 1, .format = .other },
    .{ .opcode = 0x02, .units = 2, .format = .other },
    .{ .opcode = 0x03, .units = 3, .format = .other },
    .{ .opcode = 0x04, .units = 1, .format = .other },
    .{ .opcode = 0x05, .units = 2, .format = .other },
    .{ .opcode = 0x06, .units = 3, .format = .other },
    .{ .opcode = 0x07, .units = 1, .format = .other },
    .{ .opcode = 0x08, .units = 2, .format = .other },
    .{ .opcode = 0x09, .units = 3, .format = .other },
    .{ .opcode = 0x0a, .units = 1, .format = .other, .variants = 8 },
    .{ .opcode = 0x12, .units = 1, .format = .other },
    .{ .opcode = 0x13, .units = 2, .format = .other },
    .{ .opcode = 0x14, .units = 3, .format = .other },
    .{ .opcode = 0x15, .units = 2, .format = .other },
    .{ .opcode = 0x16, .units = 2, .format = .other },
    .{ .opcode = 0x17, .units = 3, .format = .other },
    .{ .opcode = 0x18, .units = 5, .format = .other },
    .{ .opcode = 0x19, .units = 2, .format = .other },
    .{ .opcode = 0x1a, .units = 2, .format = .c },
    .{ .opcode = 0x1b, .units = 3, .format = .c },
    .{ .opcode = 0x1c, .units = 2, .format = .c },
    .{ .opcode = 0x1d, .units = 1, .format = .other, .variants = 2 },
    .{ .opcode = 0x1f, .units = 2, .format = .c, .variants = 2 },
    .{ .opcode = 0x21, .units = 1, .format = .other },
    .{ .opcode = 0x22, .units = 2, .format = .c, .variants = 2 },
    .{ .opcode = 0x24, .units = 3, .format = .c, .variants = 2 },
    .{ .opcode = 0x26, .units = 3, .format = .t },
    .{ .opcode = 0x27, .units = 1, .format = .other },
    .{ .opcode = 0x28, .units = 1, .format = .t },
    .{ .opcode = 0x29, .units = 2, .format = .t },
    .{ .opcode = 0x2a, .units = 3, .format = .t },
    .{ .opcode = 0x2b, .units = 3, .format = .t },
    .{ .opcode = 0x2c, .units = 3, .format = .t },
    .{ .opcode = 0x2d, .units = 2, .format = .other, .variants = 5 },
    .{ .opcode = 0x32, .units = 2, .format = .t, .variants = 6 },
    .{ .opcode = 0x38, .units = 2, .format = .t, .variants = 6 },
    .{ .opcode = 0x44, .units = 2, .format = .other, .variants = 14 },
    .{ .opcode = 0x52, .units = 2, .format = .c, .variants = 14 },
    .{ .opcode = 0x60, .units = 2, .format = .c, .variants = 14 },
    .{ .opcode = 0x6e, .units = 3, .format = .c, .variants = 5 },
    .{ .opcode = 0x74, .units = 3, .format = .c, .variants = 5 },
    .{ .opcode = 0x7b, .units = 1, .format = .other, .variants = 21 },
    .{ .opcode = 0x90, .units = 2, .format = .other, .variants = 32 },
    .{ .opcode = 0xb0, .units = 1, .format = .other, .variants = 32 },
    .{ .opcode = 0xd0, .units = 2, .format = .other, .variants = 8 },
    .{ .opcode = 0xd8, .units = 2, .format = .other, .variants = 11 },
    .{ .opcode = 0xfa, .units = 4, .format = .c, .variants = 2 },
    .{ .opcode = 0xfc, .units = 3, .format = .c, .variants = 2 },
    .{ .opcode = 0xfe, .units = 2, .format = .c },
    .{ .opcode = 0xff, .units = 2, .format = .c },
};

const instruction_table = blk: {
    var output: [256]?Instruction = @splat(null);
    for (instructions) |entry| {
        for (0..entry.variants) |delta|
            output[entry.opcode + delta] = entry;
    }
    break :blk output;
};

pub fn instruction(opcode: u8) ?Instruction {
    return instruction_table[opcode];
}

comptime {
    if (@typeInfo(ReferenceType).@"enum".fields.len != reference_type_count)
        @compileError("DEX reference type count drift");
}
