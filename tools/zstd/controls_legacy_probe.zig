const std = @import("std");
const codec = @import("codec");

pub const Config = struct {
    mode: []const u8 = "level",
    level: c_int = 3,
    selection: []const u8 = "auto",
    dictionary_path: ?[]const u8 = null,
    dictionary_id: u32 = 0,
    full_dictionary: bool = false,
    use_set: bool = false,
    window_log: ?u6 = null,
    max_match_history_len: ?usize = null,
    checksum: bool = false,
    content_size: bool = true,
    block_size: usize = 131072,
};

/// Compile with a frozen historical `codec` module. This helper deliberately
/// uses only public encoding APIs and writes exact legacy wire bytes.
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(input);
    const configuration = try std.Io.Dir.cwd().readFileAlloc(init.io, config_path, init.gpa, .limited(16384));
    defer init.gpa.free(configuration);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, configuration, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const dictionary_bytes = if (config.dictionary_path) |path|
        try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(4 * 1024 * 1024))
    else
        try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?codec.NativeDictionary = if (config.dictionary_path != null)
        if (config.full_dictionary) (try codec.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary else codec.NativeDictionary.init(config.dictionary_id, dictionary_bytes)
    else
        null;
    const frame_options: codec.FrameOptions = .{ .include_content_size = config.content_size, .content_checksum = config.checksum, .window_log = config.window_log, .max_match_history_len = config.max_match_history_len };
    const native_options: codec.NativeFrameOptions = .{ .include_content_size = config.content_size, .content_checksum = config.checksum, .window_log = config.window_log, .max_match_history_len = config.max_match_history_len, .block_size_max = config.block_size, .selection = if (std.mem.eql(u8, config.selection, "raw_or_rle")) .raw_or_rle else if (std.mem.eql(u8, config.selection, "literal_only")) .literal_only else if (std.mem.eql(u8, config.selection, "fast_compressed")) .fast_compressed else .auto };
    const encoded = if (std.mem.eql(u8, config.mode, "default"))
        try codec.encodeFrameAlloc(init.gpa, input)
    else if (std.mem.eql(u8, config.mode, "native-default"))
        try codec.encodeNativeFrameAlloc(init.gpa, input)
    else if (std.mem.eql(u8, config.mode, "native")) blk: {
        if (dictionary) |dict| {
            if (config.use_set) break :blk (try codec.encodeNativeFrameWithDictionarySetAlloc(init.gpa, input, native_options, codec.NativeDictionarySet.init(&.{dict}), dict.id)).frame;
            break :blk (try codec.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, native_options, dict)).frame;
        }
        break :blk (try codec.encodeNativeFrameWithOptionsAlloc(init.gpa, input, native_options)).frame;
    } else blk: {
        if (dictionary) |dict| {
            if (config.use_set) break :blk try codec.encodeFrameWithLevelAndOptionsAndDictionarySetAlloc(init.gpa, input, config.level, frame_options, codec.NativeDictionarySet.init(&.{dict}), dict.id);
            break :blk try codec.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, config.level, frame_options, dict);
        }
        break :blk try codec.encodeFrameWithLevelAndOptionsAlloc(init.gpa, input, config.level, frame_options);
    };
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    std.debug.print("{{\"input\":{d},\"encoded\":{d}}}\n", .{ input.len, encoded.len });
}
