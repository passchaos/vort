//! Measure repeated frame decode with an ordinary versus prepared standard
//! Zstd decode dictionary. The fixture is the libzstd trained repeat pair.
const std = @import("std");
const zstd = @import("vort_zstd");

fn readHex(init: std.process.Init, path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const text = try std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(1 << 20));
    defer allocator.free(text);
    const trimmed = std.mem.trim(u8, text, " \r\n\t");
    const bytes = try allocator.alloc(u8, trimmed.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, trimmed);
    return bytes;
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const dictionary_path = args.next() orelse return error.MissingDictionary;
    const frame_path = args.next() orelse return error.MissingFrame;
    const iterations = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 10000;
    if (args.next() != null) return error.ExtraArguments;
    if (iterations == 0 or iterations > 1_000_000) return error.InvalidIterations;

    const dictionary_bytes = try readHex(init, dictionary_path, init.gpa);
    defer init.gpa.free(dictionary_bytes);
    const frame = try readHex(init, frame_path, init.gpa);
    defer init.gpa.free(frame);

    const standard = try zstd.NativeDictionary.initFromStandardDictionary(dictionary_bytes);
    var prepared = try zstd.PreparedDecodeDictionary.init(standard.dictionary);
    const size = try zstd.decodedFrameSizeWithDictionary(frame, standard.dictionary);
    const output_size = std.math.cast(usize, size) orelse return error.IntegerOverflow;
    const output = try init.gpa.alloc(u8, output_size);
    defer init.gpa.free(output);

    const ordinary_written = try zstd.decodeFrameIntoWithDictionary(frame, output, standard.dictionary);
    if (ordinary_written != size) return error.SizeMismatch;
    const ordinary_crc = std.hash.Crc32.hash(output);
    const prepared_written = try zstd.decodeFrameIntoWithDictionary(frame, output, prepared.handle());
    if (prepared_written != size or std.hash.Crc32.hash(output) != ordinary_crc) return error.Mismatch;

    var ordinary_ns: u64 = 0;
    var prepared_ns: u64 = 0;
    var index: usize = 0;
    while (index < iterations) : (index += 1) {
        const start = std.Io.Clock.awake.now(init.io);
        _ = try zstd.decodeFrameIntoWithDictionary(frame, output, standard.dictionary);
        ordinary_ns += @intCast(start.untilNow(init.io, .awake).nanoseconds);
    }
    index = 0;
    while (index < iterations) : (index += 1) {
        const start = std.Io.Clock.awake.now(init.io);
        _ = try zstd.decodeFrameIntoWithDictionary(frame, output, prepared.handle());
        prepared_ns += @intCast(start.untilNow(init.io, .awake).nanoseconds);
    }

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "dictionary={d} frame={d} output={d} crc={d} iterations={d} ordinary_ns={d} prepared_ns={d} ratio={d:.6}\n",
        .{ dictionary_bytes.len, frame.len, size, ordinary_crc, iterations, ordinary_ns, prepared_ns, @as(f64, @floatFromInt(prepared_ns)) / @as(f64, @floatFromInt(ordinary_ns)) },
    );
    try stdout.interface.flush();
}
