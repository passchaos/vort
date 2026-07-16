const std = @import("std");
const vort = @import("vort");

const Case = struct {
    name: []const u8,
    interlace: []const u8,
    width: usize,
    height: usize,
    bit_depth: u8,
    color_type: []const u8,
    zlib_scratch_bytes: usize,
    filtered_row_scratch_bytes: usize,
    previous_row_scratch_bytes: usize,
    image_output_bytes: usize,

    fn workingScratch(self: Case) usize {
        return self.zlib_scratch_bytes + self.filtered_row_scratch_bytes + self.previous_row_scratch_bytes;
    }

    fn totalCallerOwned(self: Case) usize {
        return self.workingScratch() + self.image_output_bytes;
    }
};

pub fn main(init: std.process.Init) !void {
    var rows: std.ArrayList(Case) = .empty;
    defer rows.deinit(init.gpa);

    try rows.append(init.gpa, try nonInterlacedCase("png_rgb8_noninterlaced", 5, 5, 8, .truecolor));
    try rows.append(init.gpa, try nonInterlacedCase("png_indexed1_noninterlaced", 13, 3, 1, .indexed));
    try rows.append(init.gpa, try nonInterlacedCase("png_rgba16_noninterlaced", 5, 5, 16, .truecolor_alpha));
    try rows.append(init.gpa, try adam7Case("png_rgb8_adam7", 5, 5, 8, .truecolor));
    try rows.append(init.gpa, try adam7Case("png_indexed2_adam7", 5, 5, 2, .indexed));
    try rows.append(init.gpa, try adam7Case("png_rgba16_adam7", 5, 5, 16, .truecolor_alpha));

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,interlace,width,height,bit_depth,color_type,zlib_scratch_bytes,filtered_row_scratch_bytes,previous_row_scratch_bytes,image_output_bytes,working_scratch_bytes,total_caller_owned_bytes\n", .{});
    for (rows.items) |row| {
        try stdout.print("{s},{s},{d},{d},{d},{s},{d},{d},{d},{d},{d},{d}\n", .{
            row.name,
            row.interlace,
            row.width,
            row.height,
            row.bit_depth,
            row.color_type,
            row.zlib_scratch_bytes,
            row.filtered_row_scratch_bytes,
            row.previous_row_scratch_bytes,
            row.image_output_bytes,
            row.workingScratch(),
            row.totalCallerOwned(),
        });
    }
    try stdout.flush();
}

fn nonInterlacedCase(name: []const u8, width: usize, height: usize, bit_depth: u8, color_type: vort.PngColorType) !Case {
    const info = try vort.pngImageInfo(width, height, bit_depth, color_type);
    const sizes = try vort.pngZlibDecodeBufferSizes(info);
    return .{
        .name = name,
        .interlace = "none",
        .width = width,
        .height = height,
        .bit_depth = bit_depth,
        .color_type = colorTypeName(color_type),
        .zlib_scratch_bytes = sizes.zlib_scratch_len,
        .filtered_row_scratch_bytes = sizes.filtered_row_scratch_len,
        .previous_row_scratch_bytes = sizes.previous_row_scratch_len,
        .image_output_bytes = sizes.image_output_len,
    };
}

fn adam7Case(name: []const u8, width: usize, height: usize, bit_depth: u8, color_type: vort.PngColorType) !Case {
    const info = try vort.pngAdam7Info(width, height, bit_depth, color_type);
    const sizes = vort.pngAdam7DecodeBufferSizes(info);
    return .{
        .name = name,
        .interlace = "adam7",
        .width = width,
        .height = height,
        .bit_depth = bit_depth,
        .color_type = colorTypeName(color_type),
        .zlib_scratch_bytes = sizes.zlib_scratch_len,
        .filtered_row_scratch_bytes = sizes.filtered_row_scratch_len,
        .previous_row_scratch_bytes = sizes.previous_row_scratch_len,
        .image_output_bytes = sizes.image_output_len,
    };
}

fn colorTypeName(color_type: vort.PngColorType) []const u8 {
    return switch (color_type) {
        .grayscale => "grayscale",
        .truecolor => "truecolor",
        .indexed => "indexed",
        .grayscale_alpha => "grayscale_alpha",
        .truecolor_alpha => "truecolor_alpha",
    };
}
