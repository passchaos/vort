const std = @import("std");
const dex = @import("dex.zig");
const types = @import("dex_types.zig");

test "Android OTA Zucchini DEX covers all AOSP reference groups" {
    const allocator = std.testing.allocator;
    const image = allReferenceGroupsDex();
    var executable = try dex.Executable.initAlloc(allocator, &image, .{});
    defer executable.deinit();
    var previous_pool: u8 = 0;
    for (std.enums.values(dex.ReferenceType), 0..) |reference_type, index| {
        const references = executable.references[@intFromEnum(reference_type)];
        try std.testing.expect(references.len != 0);
        const pool = reference_type.pool();
        if (index != 0) try std.testing.expect(pool >= previous_pool);
        previous_pool = pool;
    }

    var rewritten = image;
    for (std.enums.values(dex.ReferenceType)) |reference_type|
        for (executable.references[@intFromEnum(reference_type)]) |reference|
            try executable.writeReference(&rewritten, reference_type, reference);
    try std.testing.expectEqualSlices(u8, &image, &rewritten);
}

fn allReferenceGroupsDex() [0x25c]u8 {
    var output: [0x25c]u8 = @splat(0);
    @memcpy(output[0..8], "dex\n039\x00");
    std.mem.writeInt(u32, output[32..36], output.len, .little);
    std.mem.writeInt(u32, output[36..40], 0x70, .little);
    std.mem.writeInt(u32, output[40..44], 0x1234_5678, .little);
    std.mem.writeInt(u32, output[52..56], 0x70, .little);
    std.mem.writeInt(u32, output[0x70..0x74], 18, .little);
    writeMap(&output, 0, types.map_header, 1, 0);
    writeMap(&output, 1, types.map_string_id, 2, 0x150);
    writeMap(&output, 2, types.map_type_id, 2, 0x158);
    writeMap(&output, 3, types.map_proto_id, 2, 0x160);
    writeMap(&output, 4, types.map_field_id, 2, 0x178);
    writeMap(&output, 5, types.map_method_id, 2, 0x188);
    writeMap(&output, 6, types.map_class_def, 1, 0x198);
    writeMap(&output, 7, types.map_call_site_id, 1, 0x1b8);
    writeMap(&output, 8, types.map_method_handle, 2, 0x1bc);
    writeMap(&output, 9, types.map_type_list, 1, 0x1cc);
    writeMap(&output, 10, types.map_annotation_set_ref_list, 1, 0x1d4);
    writeMap(&output, 11, types.map_annotation_set, 1, 0x1dc);
    writeMap(&output, 12, types.map_code, 1, 0x1e4);
    writeMap(&output, 13, types.map_annotations_directory, 1, 0x228);
    writeMap(&output, 14, types.map_string_data, 2, 0x250);
    writeMap(&output, 15, types.map_annotation, 1, 0x256);
    writeMap(&output, 16, types.map_encoded_array, 1, 0x257);
    writeMap(&output, 17, types.map_class_data, 1, 0x258);

    std.mem.writeInt(u32, output[0x150..0x154], 0x250, .little);
    std.mem.writeInt(u32, output[0x154..0x158], 0x253, .little);
    std.mem.writeInt(u32, output[0x158..0x15c], 0, .little);
    std.mem.writeInt(u32, output[0x15c..0x160], 1, .little);
    writeProto(&output, 0x160, 0, 0, 0x1cc);
    writeProto(&output, 0x16c, 1, 1, 0x1cc);
    writeField(&output, 0x178, 0, 0, 0);
    writeField(&output, 0x180, 1, 1, 1);
    writeMethod(&output, 0x188, 0, 0, 0);
    writeMethod(&output, 0x190, 1, 1, 1);

    std.mem.writeInt(u32, output[0x198..0x19c], 1, .little);
    std.mem.writeInt(u32, output[0x1a0..0x1a4], 1, .little);
    std.mem.writeInt(u32, output[0x1a4..0x1a8], 0x1cc, .little);
    std.mem.writeInt(u32, output[0x1a8..0x1ac], 1, .little);
    std.mem.writeInt(u32, output[0x1ac..0x1b0], 0x228, .little);
    std.mem.writeInt(u32, output[0x1b0..0x1b4], 0x258, .little);
    std.mem.writeInt(u32, output[0x1b4..0x1b8], 0x257, .little);
    std.mem.writeInt(u32, output[0x1b8..0x1bc], 0x257, .little);
    std.mem.writeInt(u16, output[0x1bc..0x1be], 0, .little);
    std.mem.writeInt(u16, output[0x1c0..0x1c2], 1, .little);
    std.mem.writeInt(u16, output[0x1c4..0x1c6], 4, .little);
    std.mem.writeInt(u16, output[0x1c8..0x1ca], 1, .little);

    std.mem.writeInt(u32, output[0x1cc..0x1d0], 2, .little);
    std.mem.writeInt(u16, output[0x1d0..0x1d2], 0, .little);
    std.mem.writeInt(u16, output[0x1d2..0x1d4], 1, .little);
    std.mem.writeInt(u32, output[0x1d4..0x1d8], 1, .little);
    std.mem.writeInt(u32, output[0x1d8..0x1dc], 0x1dc, .little);
    std.mem.writeInt(u32, output[0x1dc..0x1e0], 1, .little);
    std.mem.writeInt(u32, output[0x1e0..0x1e4], 0x256, .little);

    std.mem.writeInt(u32, output[0x1f0..0x1f4], 26, .little);
    writeCode(&output);
    std.mem.writeInt(u32, output[0x228..0x22c], 0x1dc, .little);
    std.mem.writeInt(u32, output[0x22c..0x230], 1, .little);
    std.mem.writeInt(u32, output[0x230..0x234], 1, .little);
    std.mem.writeInt(u32, output[0x234..0x238], 1, .little);
    writeAnnotationPair(&output, 0x238, 1, 0x1dc);
    writeAnnotationPair(&output, 0x240, 1, 0x1dc);
    writeAnnotationPair(&output, 0x248, 1, 0x1d4);
    @memcpy(output[0x250..0x256], &[_]u8{ 1, 'A', 0, 1, 'B', 0 });
    output[0x256] = 0;
    output[0x257] = 0;
    output[0x258] = 0;
    updateIntegrity(&output);
    return output;
}

fn writeCode(output: []u8) void {
    output[0x1f4] = 0x1a;
    std.mem.writeInt(u16, output[0x1f6..0x1f8], 1, .little);
    output[0x1f8] = 0x1b;
    std.mem.writeInt(u32, output[0x1fa..0x1fe], 1, .little);
    output[0x1fe] = 0x1c;
    std.mem.writeInt(u16, output[0x200..0x202], 1, .little);
    output[0x202] = 0xff;
    std.mem.writeInt(u16, output[0x204..0x206], 1, .little);
    output[0x206] = 0x52;
    std.mem.writeInt(u16, output[0x208..0x20a], 1, .little);
    output[0x20a] = 0x6e;
    std.mem.writeInt(u16, output[0x20c..0x20e], 1, .little);
    output[0x210] = 0xfc;
    std.mem.writeInt(u16, output[0x212..0x214], 0, .little);
    output[0x216] = 0xfe;
    std.mem.writeInt(u16, output[0x218..0x21a], 1, .little);
    output[0x21a] = 0x28;
    output[0x21b] = 1;
    output[0x21c] = 0x29;
    std.mem.writeInt(i16, output[0x21e..0x220], 5, .little);
    output[0x220] = 0x2a;
    std.mem.writeInt(i32, output[0x222..0x226], 3, .little);
    output[0x226] = 0x0e;
}

fn writeMap(output: []u8, index: usize, kind: u16, count: u32, offset: u32) void {
    const base = 0x74 + index * 12;
    std.mem.writeInt(u16, output[base..][0..2], kind, .little);
    std.mem.writeInt(u32, output[base + 4 ..][0..4], count, .little);
    std.mem.writeInt(u32, output[base + 8 ..][0..4], offset, .little);
}

fn writeProto(output: []u8, offset: usize, shorty: u32, return_type: u32, parameters: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], shorty, .little);
    std.mem.writeInt(u32, output[offset + 4 ..][0..4], return_type, .little);
    std.mem.writeInt(u32, output[offset + 8 ..][0..4], parameters, .little);
}

fn writeField(output: []u8, offset: usize, class: u16, field_type: u16, name: u32) void {
    std.mem.writeInt(u16, output[offset..][0..2], class, .little);
    std.mem.writeInt(u16, output[offset + 2 ..][0..2], field_type, .little);
    std.mem.writeInt(u32, output[offset + 4 ..][0..4], name, .little);
}

fn writeMethod(output: []u8, offset: usize, class: u16, proto: u16, name: u32) void {
    std.mem.writeInt(u16, output[offset..][0..2], class, .little);
    std.mem.writeInt(u16, output[offset + 2 ..][0..2], proto, .little);
    std.mem.writeInt(u32, output[offset + 4 ..][0..4], name, .little);
}

fn writeAnnotationPair(output: []u8, offset: usize, index: u32, target: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], index, .little);
    std.mem.writeInt(u32, output[offset + 4 ..][0..4], target, .little);
}

fn updateIntegrity(output: []u8) void {
    std.crypto.hash.Sha1.hash(output[32..], output[12..32], .{});
    var sum1: u32 = 1;
    var sum2: u32 = 0;
    for (output[12..]) |byte| {
        sum1 = (sum1 + byte) % 65521;
        sum2 = (sum2 + sum1) % 65521;
    }
    std.mem.writeInt(u32, output[8..12], (sum2 << 16) | sum1, .little);
}
