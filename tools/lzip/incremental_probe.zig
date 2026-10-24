const std = @import("std");
const vort = @import("vort");

const Pattern = enum { one, micro };
const input_chunks = [_]usize{ 1, 2, 3, 5, 7 };
const output_chunks = [_]usize{ 2, 3, 5, 7 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const archive_path = args.next() orelse return error.MissingArchivePath;
    const expected_path = args.next() orelse return error.MissingExpectedPath;
    const pattern_name = args.next() orelse return error.MissingInputPattern;
    if (args.next() != null) return error.UnexpectedArgument;
    const pattern: Pattern = if (std.mem.eql(u8, pattern_name, "one"))
        .one
    else if (std.mem.eql(u8, pattern_name, "micro"))
        .micro
    else
        return error.InvalidInputPattern;

    const encoded = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        archive_path,
        init.gpa,
        .limited(512 * 1024 * 1024),
    );
    defer init.gpa.free(encoded);
    const expected = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        expected_path,
        init.gpa,
        .limited(512 * 1024 * 1024),
    );
    defer init.gpa.free(expected);

    var decoder = vort.LzipIncrementalDecoder.initWithOptions(init.gpa, .{
        .max_output_len = expected.len,
        .expected_output_len = expected.len,
        .max_dictionary_size = 512 * 1024 * 1024,
    });
    defer decoder.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var output_storage: [7]u8 = undefined;
    var input_offset: usize = 0;
    var input_index: usize = 0;
    var output_index: usize = 0;
    var finish_sent = false;
    while (true) {
        const input_end = @min(
            encoded.len,
            input_offset + nextInputLen(pattern, &input_index),
        );
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try decoder.step(encoded[input_offset..input_end], output);
        input_offset += stepped.progress.input_read;
        try actual.appendSlice(init.gpa, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (!finish_sent and input_offset == encoded.len) {
            decoder.finish();
            finish_sent = true;
        }
    }
    if (input_offset != encoded.len) return error.TrailingData;
    if (!std.mem.eql(u8, actual.items, expected)) return error.DataMismatch;
}

fn nextInputLen(pattern: Pattern, index: *usize) usize {
    const len = switch (pattern) {
        .one => 1,
        .micro => input_chunks[index.* % input_chunks.len],
    };
    index.* += 1;
    return len;
}

fn nextOutput(storage: *[7]u8, pattern: Pattern, index: *usize) []u8 {
    const len = switch (pattern) {
        .one => 1,
        .micro => output_chunks[index.* % output_chunks.len],
    };
    index.* += 1;
    return storage[0..len];
}
