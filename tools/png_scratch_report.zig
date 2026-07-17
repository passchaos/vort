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

    fn streamingWorkingScratch(self: Case) usize {
        return self.filtered_row_scratch_bytes + self.previous_row_scratch_bytes;
    }

    fn streamingScratchSavings(self: Case) usize {
        return self.zlib_scratch_bytes;
    }

    fn streamingScratchRatioX10000(self: Case) usize {
        const working = self.workingScratch();
        if (working == 0) return 0;
        return (self.streamingWorkingScratch() * 10000) / working;
    }

    fn totalCallerOwned(self: Case) usize {
        return self.workingScratch() + self.image_output_bytes;
    }

    fn streamingTotalCallerOwned(self: Case) usize {
        return self.streamingWorkingScratch() + self.image_output_bytes;
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var json_path: ?[]const u8 = null;
    var markdown_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            json_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingReportPath;
            continue;
        }
        return error.UnknownArgument;
    }

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
    try writeCsv(stdout, rows.items);
    try stdout.flush();

    if (json_path) |path| try writeJson(init, path, rows.items);
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items);
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Case) !void {
    try writer.print("case,interlace,width,height,bit_depth,color_type,zlib_scratch_bytes,filtered_row_scratch_bytes,previous_row_scratch_bytes,image_output_bytes,working_scratch_bytes,streaming_working_scratch_bytes,streaming_scratch_savings_bytes,streaming_scratch_ratio_x10000,total_caller_owned_bytes,streaming_total_caller_owned_bytes\n", .{});
    for (rows) |row| {
        try writer.print("{s},{s},{d},{d},{d},{s},{d},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
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
            row.streamingWorkingScratch(),
            row.streamingScratchSavings(),
            row.streamingScratchRatioX10000(),
            row.totalCallerOwned(),
            row.streamingTotalCallerOwned(),
        });
    }
}

fn writeJson(init: std.process.Init, path: []const u8, rows: []const Case) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    try w.print(
        "{{\n  \"schema\": \"vort.png_scratch_report\",\n  \"schema_version\": 1,\n  \"case_count\": {d},\n  \"cases\": [\n",
        .{rows.len},
    );
    for (rows, 0..) |row, i| {
        try w.print("    {{\"case\": ", .{});
        try std.json.Stringify.value(row.name, .{}, w);
        try w.print(", \"interlace\": ", .{});
        try std.json.Stringify.value(row.interlace, .{}, w);
        try w.print(", \"width\": {d}, \"height\": {d}, \"bit_depth\": {d}, \"color_type\": ", .{ row.width, row.height, row.bit_depth });
        try std.json.Stringify.value(row.color_type, .{}, w);
        try w.print(
            ", \"zlib_scratch_bytes\": {d}, \"filtered_row_scratch_bytes\": {d}, \"previous_row_scratch_bytes\": {d}, \"image_output_bytes\": {d}, \"working_scratch_bytes\": {d}, \"streaming_working_scratch_bytes\": {d}, \"streaming_scratch_savings_bytes\": {d}, \"streaming_scratch_ratio_x10000\": {d}, \"total_caller_owned_bytes\": {d}, \"streaming_total_caller_owned_bytes\": {d}}}{s}\n",
            .{
                row.zlib_scratch_bytes,
                row.filtered_row_scratch_bytes,
                row.previous_row_scratch_bytes,
                row.image_output_bytes,
                row.workingScratch(),
                row.streamingWorkingScratch(),
                row.streamingScratchSavings(),
                row.streamingScratchRatioX10000(),
                row.totalCallerOwned(),
                row.streamingTotalCallerOwned(),
                if (i + 1 == rows.len) "" else ",",
            },
        );
    }
    try w.print("  ]\n}}\n", .{});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const Case) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    try w.print(
        \\# PNG scratch footprint report
        \\
        \\| case | interlace | dimensions | bit depth | color type | zlib scratch | filtered row scratch | previous row scratch | image output | working scratch | streaming scratch target | scratch savings | target ratio x10000 | total caller-owned | streaming total target |
        \\| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
        \\
    , .{});
    for (rows) |row| {
        try w.print("| {s} | {s} | {d}x{d} | {d} | {s} | {d} | {d} | {d} | {d} | {d} | {d} | {d} | {d} | {d} | {d} |\n", .{
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
            row.streamingWorkingScratch(),
            row.streamingScratchSavings(),
            row.streamingScratchRatioX10000(),
            row.totalCallerOwned(),
            row.streamingTotalCallerOwned(),
        });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
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
