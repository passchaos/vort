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
    const format_list = args.next() orelse return error.MissingFormats;
    const pattern_name = args.next() orelse return error.MissingInputPattern;
    if (args.next() != null) return error.UnexpectedArgument;
    const pattern: Pattern = if (std.mem.eql(u8, pattern_name, "one"))
        .one
    else if (std.mem.eql(u8, pattern_name, "micro"))
        .micro
    else
        return error.InvalidInputPattern;

    const archive = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        archive_path,
        init.gpa,
        .limited(512 * 1024 * 1024),
    );
    defer init.gpa.free(archive);
    const expected = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        expected_path,
        init.gpa,
        .limited(256 * 1024 * 1024),
    );
    defer init.gpa.free(expected);
    const expected_formats = try parseFormats(init.gpa, format_list);
    defer init.gpa.free(expected_formats);

    var reader = try vort.CpioIncrementalMixedReader.initWithOptions(init.gpa, .{
        .max_members = expected_formats.len,
        .max_padding_size = 64 * 1024 * 1024,
        .max_total_input_size = 512 * 1024 * 1024,
        .max_total_output_size = 512 * 1024 * 1024,
        .decoder_input_chunk_size = 32 * 1024,
        .max_replay_size = 64 * 1024,
        .auto = .{
            .decoded_bridge_size = 31,
            .max_decoded_size = 512 * 1024 * 1024,
            .cpio = .{
                .max_control_record_size = 64 * 1024 * 1024,
                .max_name_size = 64 * 1024 * 1024,
                .max_entry_size = 256 * 1024 * 1024,
                .max_total_output_size = 512 * 1024 * 1024,
                .max_archive_size = 512 * 1024 * 1024,
            },
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
    var found_in_member = false;
    var member_count: usize = 0;
    var finish_sent = false;

    while (true) {
        const input_end = @min(
            archive.len,
            input_offset + nextInputLen(pattern, &input_index),
        );
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try reader.step(archive[input_offset..input_end], output);
        input_offset += stepped.input_read;
        if (current_match)
            try actual.appendSlice(init.gpa, output[0..stepped.output_written]);
        switch (stepped.status) {
            .entry_header => {
                const info = reader.currentEntry() orelse return error.MissingEntryInfo;
                current_match = std.mem.eql(u8, info.name, entry_name);
                if (current_match) {
                    if (found_in_member) return error.DuplicateEntry;
                    actual.clearRetainingCapacity();
                }
            },
            .entry_done => {
                if (current_match) {
                    if (!std.mem.eql(u8, actual.items, expected))
                        return error.EntryDataMismatch;
                    found_in_member = true;
                    current_match = false;
                }
            },
            .archive_done => {
                if (!found_in_member or member_count >= expected_formats.len)
                    return error.EntryNotFound;
                const info = reader.lastArchive() orelse return error.MissingArchiveInfo;
                if (info.index != member_count or info.format != expected_formats[member_count])
                    return error.FormatMismatch;
                member_count += 1;
                found_in_member = false;
            },
            .need_input => if (input_offset == archive.len and !finish_sent) {
                try reader.finish();
                finish_sent = true;
            },
            .need_output => {},
            .done => break,
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            stepped.status != .archive_done and
            !(stepped.status == .need_input and input_offset == archive.len))
        {
            return error.ReaderMadeNoProgress;
        }
    }
    if (input_offset != archive.len) return error.TrailingData;
    if (member_count != expected_formats.len) return error.ArchiveCountMismatch;
}

fn parseFormats(
    allocator: std.mem.Allocator,
    text: []const u8,
) ![]vort.CpioIncrementalAutoReaderFormat {
    var count: usize = 1;
    for (text) |byte| if (byte == ',') {
        count += 1;
    };
    const formats = try allocator.alloc(vort.CpioIncrementalAutoReaderFormat, count);
    errdefer allocator.free(formats);
    var iterator = std.mem.splitScalar(u8, text, ',');
    var index: usize = 0;
    while (iterator.next()) |name| : (index += 1) {
        formats[index] = parseFormat(name) catch return error.UnsupportedFormat;
    }
    if (index != count) return error.InvalidFormatList;
    return formats;
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
