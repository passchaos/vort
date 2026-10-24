const std = @import("std");
const vort = @import("vort");

const word_len: usize = 8;
const word_count: usize = 256;
const transform_count: usize = 12;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(
        init.minimal.args,
        init.gpa,
    );
    defer args.deinit();
    _ = args.next();
    var iterations: usize = 100;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(
                usize,
                args.next() orelse return error.MissingIterations,
                10,
            );
            if (iterations == 0) return error.InvalidIterations;
        } else return error.UnknownArgument;
    }

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(init.gpa);
    try buildDictionary(init.gpa, &encoded);
    const dictionary = try vort.brParseSerializedSharedDictionary(encoded.items);
    var matcher = vort.BrotliSerializedSharedDictionaryMatcher.init(init.gpa);
    defer matcher.deinit();
    const prepare_start = std.Io.Clock.awake.now(init.io);
    try matcher.prepare(&dictionary);
    const prepare_ns = prepare_start.durationTo(
        std.Io.Clock.awake.now(init.io),
    ).toNanoseconds();
    if (!matcher.usesIndex()) return error.IndexUnavailable;

    const target = "W0000255";
    var indexed_scratch: [541]u8 = undefined;
    var reference_scratch: [541]u8 = undefined;
    const indexed_match = (try matcher.findLongest(
        0,
        target,
        &indexed_scratch,
    )) orelse return error.MatchMissing;
    const reference_match = (try dictionary.findLongest(
        0,
        target,
        &reference_scratch,
    )) orelse return error.MatchMissing;
    if (!std.meta.eql(indexed_match, reference_match))
        return error.MatchMismatch;

    var checksum: usize = 0;
    const indexed_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const match = (try matcher.findLongest(
            0,
            target,
            &indexed_scratch,
        )).?;
        checksum +%= match.address + match.output_len + match.copy_len;
    }
    const indexed_ns = indexed_start.durationTo(
        std.Io.Clock.awake.now(init.io),
    ).toNanoseconds();

    const reference_start = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        const match = (try dictionary.findLongest(
            0,
            target,
            &reference_scratch,
        )).?;
        checksum +%= match.address + match.output_len + match.copy_len;
    }
    const reference_ns = reference_start.durationTo(
        std.Io.Clock.awake.now(init.io),
    ).toNanoseconds();

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(
        init.io,
        &stdout_buffer,
    );
    defer stdout_writer.interface.flush() catch {};
    try stdout_writer.interface.writeAll(
        "words,transforms,indexed_candidates,index_bytes,prepare_ns,iterations,indexed_ns,reference_ns,speedup,checksum\n",
    );
    try stdout_writer.interface.print(
        "{d},{d},{d},{d},{d},{d},{d},{d},{d:.3},{d}\n",
        .{
            word_count,
            transform_count,
            matcher.indexedCandidateCount(),
            matcher.retainedCapacity(),
            prepare_ns,
            iterations,
            indexed_ns,
            reference_ns,
            @as(f64, @floatFromInt(reference_ns)) /
                @as(f64, @floatFromInt(indexed_ns)),
            checksum,
        },
    );
}

fn buildDictionary(
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
) !void {
    try encoded.appendSlice(allocator, &.{ 0x91, 0, 0, 1 });
    var bits: [28]u8 = @splat(0);
    bits[word_len - 4] = 8;
    try encoded.appendSlice(allocator, &bits);
    var word: [word_len]u8 = undefined;
    for (0..word_count) |index| {
        word[0] = 'w';
        var value = index;
        var cursor = word.len;
        while (cursor > 1) {
            cursor -= 1;
            word[cursor] = @intCast('0' + value % 10);
            value /= 10;
        }
        try encoded.appendSlice(allocator, &word);
    }
    try encoded.appendSlice(allocator, &.{
        1, // transform lists
        1,               0, 0, // one empty stringlet
        transform_count,
    });
    for (0..transform_count) |kind|
        try encoded.appendSlice(allocator, &.{ 0, @intCast(kind), 0 });
    try encoded.appendSlice(allocator, &.{
        1, // dictionary count
        0, 0, // custom words and transforms
        0, // context map disabled
    });
}
