//! File publication for the public bounded ZIP entry and archive readers.
const std = @import("std");
const vort = @import("vort");
const limits = @import("zstd_controls.zig");
const Count = vort.StreamCount;
const chunk_len = 64 * 1024;

const Request = struct {
    input: []const u8,
    entry: []const u8,
    output: []const u8,
    limit: Count,
    password: ?[]const u8,

    fn parse(args: *std.process.Args.Iterator) !Request {
        const input = args.next() orelse return error.MissingCorpusPath;
        const entry = args.next() orelse return error.MissingCorpusPath;
        const output = args.next() orelse return error.MissingCorpusPath;
        const limit = (try limits.parseLogicalLimit(args.next())) orelse std.math.maxInt(Count);
        const password_arg = args.next();
        return .{
            .input = input,
            .entry = entry,
            .output = output,
            .limit = limit,
            .password = if (password_arg) |value| if (std.mem.eql(u8, value, "-")) null else value else null,
        };
    }
};

pub fn extractEntry(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const request = try Request.parse(args);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, request.input, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const archive = try vort.parseZipArchive(bytes);
    const entry = (try archive.find(request.entry)) orelse return error.ZipEntryNotFound;
    const compressed = if (entry.isEncrypted()) try archive.rawEntryData(entry) else try archive.compressedData(entry);
    var decoder = try vort.ZipOwnedIncrementalEntryDecoder.initWithOptions(init.gpa, entry, .{
        .max_output_len = request.limit,
        .password = request.password,
    });
    defer decoder.deinit();
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, request.output, .{ .replace = true });
    defer atomic.deinit(init.io);
    var write_buffer: [chunk_len]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &write_buffer);
    var output: [chunk_len]u8 = undefined;
    var offset: usize = 0;
    var decoded: Count = 0;
    var calls: Count = 0;
    while (true) {
        const end = offset + @min(compressed.len - offset, chunk_len);
        const result = try decoder.step(compressed[offset..end], &output);
        offset += result.progress.input_read;
        try vort.core.stream_count.advance(&decoded, result.progress.output_written);
        try vort.core.stream_count.advance(&calls, 1);
        try writer.interface.writeAll(output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    if (offset != compressed.len or decoded != entry.uncompressed_size) return error.SizeMismatch;
    try writer.interface.flush();
    try atomic.replace(init.io);
    try stdout.print("zip_bytes={d} compressed_bytes={d} decoded_bytes={d} calls={d} entry={s} path={s}\n", .{
        bytes.len, compressed.len, decoded, calls, request.entry, request.output,
    });
}

pub fn extractArchive(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const request = try Request.parse(args);
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, request.input, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const parsed_archive = try vort.parseZipArchive(bytes);
    const stream_offset = if (parsed_archive.entry_count == 0) parsed_archive.central_directory_offset else (try parsed_archive.entryAt(0)).local_header_offset;
    var reader = try vort.ZipIncrementalReader.initWithOptions(init.gpa, .{
        .initial_offset = stream_offset,
        .password = request.password,
    });
    defer reader.deinit();
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, request.output, .{ .replace = true });
    defer atomic.deinit(init.io);
    var write_buffer: [chunk_len]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &write_buffer);
    var output: [chunk_len]u8 = undefined;
    var offset = stream_offset;
    var selected = false;
    var found = false;
    var decoded: Count = 0;
    var calls: Count = 0;
    while (true) {
        const end = offset + @min(bytes.len - offset, chunk_len);
        const result = try reader.step(bytes[offset..end], &output);
        offset += result.progress.input_read;
        try vort.core.stream_count.advance(&calls, 1);
        if (selected and result.progress.output_written != 0) {
            const next = try vort.core.stream_count.addLocal(decoded, result.progress.output_written);
            if (next > request.limit) return error.OutputLimitExceeded;
            try writer.interface.writeAll(output[0..result.progress.output_written]);
            decoded = next;
        }
        switch (result.status) {
            .entry_header => selected = !found and std.mem.eql(u8, reader.currentEntry().?.preferredName(), request.entry),
            .entry_done => {
                if (selected) found = true;
                selected = false;
            },
            .done => break,
            .need_input, .need_output => {},
        }
        if (result.progress.input_read == 0 and result.progress.output_written == 0 and
            result.status != .entry_header and result.status != .entry_done) return error.InvalidBlockPlan;
    }
    if (!found) return error.ZipEntryNotFound;
    try writer.interface.flush();
    try atomic.replace(init.io);
    try stdout.print("zip_bytes={d} entries={d} decoded_bytes={d} calls={d} entry={s} path={s}\n", .{
        bytes.len, reader.snapshot().completed_entries, decoded, calls, request.entry, request.output,
    });
}
