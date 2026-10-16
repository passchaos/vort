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
    const compression = args.next() orelse return error.MissingCompression;
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

    if (std.mem.eql(u8, compression, "gzip"))
        return runReader(vort.TarGzipIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "bzip2"))
        return runReader(vort.TarBzip2IncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "brotli"))
        return runReader(vort.TarBrotliIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "lzma"))
        return runReader(vort.TarLzmaIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "xz"))
        return runReader(vort.TarXzIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "lz4"))
        return runReader(vort.TarLz4IncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "lz4-legacy"))
        return runReader(vort.TarLz4LegacyIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "lzf"))
        return runReader(vort.TarLzfIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "lzip"))
        return runReader(vort.TarLzipIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "zstd"))
        return runReader(vort.TarZstandardIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    if (std.mem.eql(u8, compression, "lzop"))
        return runReader(vort.TarLzopIncrementalReader, init.gpa, archive, entry_name, expected, pattern);
    return error.UnsupportedCompression;
}

fn runReader(
    comptime ReaderType: type,
    allocator: std.mem.Allocator,
    archive: []const u8,
    entry_name: []const u8,
    expected: []const u8,
    pattern: Pattern,
) !void {
    var reader = try ReaderType.initWithOptions(allocator, .{
        .decoded_bridge_size = 31,
        .max_decoded_size = 512 * 1024 * 1024,
        .tar = .{
            .max_control_record_size = 64 * 1024 * 1024,
            .max_metadata_size = 64 * 1024 * 1024,
            .max_logical_entry_size = 256 * 1024 * 1024,
            .max_total_output_size = 512 * 1024 * 1024,
            .max_archive_size = 512 * 1024 * 1024,
        },
    });
    defer reader.deinit();
    var actual: std.ArrayList(u8) = .empty;
    defer actual.deinit(allocator);
    var output_storage: [7]u8 = undefined;
    var input_offset: usize = 0;
    var input_index: usize = 0;
    var output_index: usize = 0;
    var current_match = false;
    var found = false;
    var finish_sent = false;

    while (true) {
        const input_len = nextInputLen(pattern, &input_index);
        const input_end = @min(archive.len, input_offset + input_len);
        const output = nextOutput(&output_storage, pattern, &output_index);
        const stepped = try reader.step(archive[input_offset..input_end], output);
        input_offset += stepped.input_read;
        if (current_match)
            try actual.appendSlice(allocator, output[0..stepped.output_written]);
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
        if (!finish_sent and input_offset == archive.len) {
            try reader.finish();
            finish_sent = true;
        }
        if (stepped.input_read == 0 and stepped.output_written == 0 and
            stepped.status != .entry_header and stepped.status != .entry_done and
            !(stepped.status == .need_input and !finish_sent))
            return error.ReaderMadeNoProgress;
    }
    if (input_offset != archive.len) return error.TrailingData;
    if (!found) return error.EntryNotFound;
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
