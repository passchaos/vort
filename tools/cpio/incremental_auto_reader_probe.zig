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
    const entry_name = args.next() orelse return error.MissingEntryName;
    const expected_path = args.next() orelse return error.MissingExpectedPath;
    const format_name = args.next() orelse return error.MissingFormat;
    const pattern_name = args.next() orelse return error.MissingInputPattern;
    if (args.next() != null) return error.UnexpectedArgument;
    const expected_format = try parseFormat(format_name);
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
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(expected);

    var reader = vort.CpioIncrementalAutoReader.initWithOptions(init.gpa, .{
        .decoded_bridge_size = 31,
        .max_decoded_size = 512 * 1024 * 1024,
        .max_input_size = 512 * 1024 * 1024,
        .cpio = .{
            .max_control_record_size = 64 * 1024 * 1024,
            .max_name_size = 64 * 1024 * 1024,
            .max_entry_size = 256 * 1024 * 1024,
            .max_total_output_size = 512 * 1024 * 1024,
            .max_archive_size = 512 * 1024 * 1024,
        },
    });
    defer reader.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(init.gpa);
    var output_storage: [7]u8 = undefined;
    var input_offset: usize = 0;
    var input_index: usize = 0;
    var output_index: usize = 0;
    var current_match = false;
    var found = false;
    var finish_sent = false;

    while (true) {
        const input_end = @min(
            encoded.len,
            input_offset + nextInputLen(pattern, &input_index),
        );
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try reader.step(encoded[input_offset..input_end], output);
        input_offset += stepped.input_read;
        if (current_match)
            try actual.appendSlice(init.gpa, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                const info = reader.currentEntry() orelse return error.MissingEntryInfo;
                current_match = std.mem.eql(u8, info.name, entry_name);
                if (current_match) {
                    if (found) return error.DuplicateEntry;
                    actual.clearRetainingCapacity();
                }
            },
            .entry_done => {
                if (current_match) {
                    if (!std.mem.eql(u8, actual.items, expected))
                        return error.EntryDataMismatch;
                    found = true;
                    current_match = false;
                }
            },
            .done => break,
            .need_input, .need_output => {},
        }
        if (!finish_sent and input_offset == encoded.len) {
            try reader.finish();
            finish_sent = true;
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            !(stepped.status == .need_input and !finish_sent))
        {
            return error.ReaderMadeNoProgress;
        }
    }
    if (input_offset != encoded.len) return error.TrailingData;
    if (!found) return error.EntryNotFound;
    if (reader.detectedFormat() != expected_format) return error.FormatMismatch;
}

fn parseFormat(name: []const u8) !vort.CpioIncrementalAutoReaderFormat {
    inline for (std.meta.tags(vort.CpioIncrementalAutoReaderFormat)) |format|
        if (std.mem.eql(u8, name, @tagName(format))) return format;
    return error.UnsupportedFormat;
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
