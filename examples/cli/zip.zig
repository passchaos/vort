const std = @import("std");
const vort = @import("vort");

const max_archive_size = 512 * 1024 * 1024;
const max_total_decoded_size = 512 * 1024 * 1024;
const max_entries = 1_000_000;

const OwnedParts = struct {
    allocator: std.mem.Allocator,
    items: std.ArrayList([]u8) = .empty,
    total_len: usize = 0,

    fn read(
        init: std.process.Init,
        args: *std.process.Args.Iterator,
    ) !OwnedParts {
        var result: OwnedParts = .{ .allocator = init.gpa };
        errdefer result.deinit();
        while (args.next()) |input_path| {
            const bytes = try std.Io.Dir.cwd().readFileAlloc(
                init.io,
                input_path,
                init.gpa,
                .limited(max_archive_size),
            );
            const next_total = std.math.add(
                usize,
                result.total_len,
                bytes.len,
            ) catch {
                init.gpa.free(bytes);
                return error.OutputLimitExceeded;
            };
            if (next_total > max_archive_size) {
                init.gpa.free(bytes);
                return error.OutputLimitExceeded;
            }
            result.items.append(init.gpa, bytes) catch |err| {
                init.gpa.free(bytes);
                return err;
            };
            result.total_len = next_total;
        }
        if (result.items.items.len < 2) return error.MissingCorpusPath;
        return result;
    }

    fn deinit(self: *OwnedParts) void {
        for (self.items.items) |bytes| self.allocator.free(bytes);
        self.items.deinit(self.allocator);
        self.* = undefined;
    }
};

pub fn createSplit(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_prefix = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const max_part_size = try parseRequiredLimit(args.next());
    const method = try parseCompression(args.next());
    const zip64 = try parseZip64Mode(args.next());
    const data_descriptor = try parseDescriptorMode(args.next());
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_archive_size),
    );
    defer init.gpa.free(input);
    const entries = [_]vort.ZipEncodeEntry{.{
        .name = entry_name,
        .data = input,
        .method = method,
    }};
    var encoded = try vort.zipEncodeSplitAlloc(init.gpa, &entries, .{
        .zip_options = .{
            .data_descriptor = data_descriptor,
            .zip64 = zip64,
        },
        .max_part_size = max_part_size,
        .max_archive_size = max_archive_size,
    });
    defer encoded.deinit();
    for (encoded.parts, 0..) |part, index| {
        const path = if (index + 1 == encoded.parts.len)
            try std.fmt.allocPrint(init.gpa, "{s}.zip", .{output_prefix})
        else
            try std.fmt.allocPrint(init.gpa, "{s}.z{d:0>2}", .{
                output_prefix,
                index + 1,
            });
        defer init.gpa.free(path);
        try std.Io.Dir.cwd().writeFile(init.io, .{
            .sub_path = path,
            .data = part,
        });
    }
    try stdout.print(
        "zip_parts={d} zip_bytes={d} input_bytes={d} method={s} zip64={s} " ++
            "descriptor={} prefix={s}\n",
        .{
            encoded.parts.len,
            encoded.bytes.len,
            input.len,
            @tagName(method),
            @tagName(zip64),
            data_descriptor,
            output_prefix,
        },
    );
}

pub fn createSplitStream(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const output_prefix = args.next() orelse return error.MissingCorpusPath;
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const max_part_size = try parseRequiredLimit(args.next());
    const method = try parseCompression(args.next());
    const zip64 = try parseZip64Mode(args.next());
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(max_archive_size),
    );
    defer init.gpa.free(input);
    var writer = try vort.ZipSplitIncrementalWriter.initWithOptions(init.gpa, .{
        .writer_options = .{
            .zip64 = zip64,
            .max_entries = 1,
            .max_archive_size = max_archive_size,
        },
        .max_part_size = max_part_size,
        .max_archive_size = max_archive_size,
    });
    defer writer.deinit();
    try writer.beginEntry(.{
        .name = entry_name,
        .method = method,
        .expected_size = input.len,
    });
    var current: std.ArrayList(u8) = .empty;
    defer current.deinit(init.gpa);
    var scratch: [8192]u8 = undefined;
    var input_offset: usize = 0;
    var part_number: usize = 1;
    var archive_bytes: usize = 0;
    var calls: usize = 0;
    while (input_offset < input.len) {
        const input_end = @min(input.len, input_offset + 4096);
        while (input_offset < input_end) {
            const result = try writer.step(input[input_offset..input_end], &scratch);
            input_offset += result.progress.input_read;
            try current.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
            calls += 1;
            if (result.status == .part_done) {
                archive_bytes = try writeSplitIntermediatePart(
                    init,
                    output_prefix,
                    part_number,
                    current.items,
                    archive_bytes,
                );
                part_number += 1;
                current.clearRetainingCapacity();
            } else if (result.progress.input_read == 0 and
                result.progress.output_written == 0)
                return error.InvalidBlockPlan;
        }
    }
    try writer.finishEntry();
    while (writer.snapshot().phase != .ready) {
        const result = try writer.step("", &scratch);
        try current.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        calls += 1;
        if (result.status == .part_done) {
            archive_bytes = try writeSplitIntermediatePart(
                init,
                output_prefix,
                part_number,
                current.items,
                archive_bytes,
            );
            part_number += 1;
            current.clearRetainingCapacity();
        } else if (result.progress.output_written == 0) {
            return error.InvalidBlockPlan;
        }
    }
    try writer.finishArchive();
    while (true) {
        const result = try writer.step("", &scratch);
        try current.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        calls += 1;
        if (result.status == .part_done) {
            archive_bytes = try writeSplitIntermediatePart(
                init,
                output_prefix,
                part_number,
                current.items,
                archive_bytes,
            );
            part_number += 1;
            current.clearRetainingCapacity();
        } else if (result.status == .done) {
            break;
        } else if (result.progress.output_written == 0) {
            return error.InvalidBlockPlan;
        }
    }
    if (current.items.len == 0) return error.InvalidZipArchive;
    const final_path = try std.fmt.allocPrint(init.gpa, "{s}.zip", .{output_prefix});
    defer init.gpa.free(final_path);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = final_path,
        .data = current.items,
    });
    archive_bytes = std.math.add(usize, archive_bytes, current.items.len) catch
        return error.IntegerOverflow;
    try stdout.print(
        "zip_parts={d} zip_bytes={d} input_bytes={d} calls={d} " ++
            "method={s} zip64={s} prefix={s}\n",
        .{
            part_number,
            archive_bytes,
            input.len,
            calls,
            @tagName(method),
            @tagName(zip64),
            output_prefix,
        },
    );
}

fn writeSplitIntermediatePart(
    init: std.process.Init,
    output_prefix: []const u8,
    part_number: usize,
    bytes: []const u8,
    archive_bytes: usize,
) !usize {
    if (bytes.len == 0) return error.InvalidZipArchive;
    const path = try std.fmt.allocPrint(init.gpa, "{s}.z{d:0>2}", .{
        output_prefix,
        part_number,
    });
    defer init.gpa.free(path);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = path,
        .data = bytes,
    });
    return std.math.add(usize, archive_bytes, bytes.len) catch
        error.IntegerOverflow;
}

pub fn extractSplitOwned(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseRequiredLimit(args.next());
    const password = parsePassword(args.next() orelse return error.MissingCorpusPath);
    var parts = try OwnedParts.read(init, args);
    defer parts.deinit();
    var split_archive = try vort.parseSplitZipArchiveAlloc(
        init.gpa,
        parts.items.items,
        .{
            .max_archive_size = max_archive_size,
            .max_entries = max_entries,
        },
    );
    defer split_archive.deinit();
    const decoded = try split_archive.archive.extractByNameAllocWithOptions(
        init.gpa,
        entry_name,
        .{
            .max_output_len = max_output_len,
            .password = password,
        },
    );
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded,
    });
    try stdout.print(
        "zip_parts={d} zip_bytes={d} decoded_bytes={d} entry={s} path={s}\n",
        .{
            parts.items.items.len,
            split_archive.bytes.len,
            decoded.len,
            entry_name,
            output_path,
        },
    );
}

pub fn extractSplitStream(
    init: std.process.Init,
    args: *std.process.Args.Iterator,
    stdout: *std.Io.Writer,
) !void {
    const entry_name = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const max_output_len = try parseRequiredLimit(args.next());
    const password = parsePassword(args.next() orelse return error.MissingCorpusPath);
    var parts = try OwnedParts.read(init, args);
    defer parts.deinit();
    var reader = try vort.ZipSplitIncrementalReader.initAlloc(
        init.gpa,
        parts.items.items,
        .{
            .split_options = .{
                .max_archive_size = max_archive_size,
                .max_entries = max_entries,
            },
            .reader_options = .{
                .max_entries = max_entries,
                .max_entry_output_len = max_total_decoded_size,
                .max_total_output_len = max_total_decoded_size,
                .password = password,
            },
        },
    );
    defer reader.deinit();

    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(init.gpa);
    var selected = false;
    var found = false;
    var calls: usize = 0;
    var normalized_input_read: usize = 0;
    while (true) {
        var output: [8192]u8 = undefined;
        const result = try reader.step(&output);
        normalized_input_read = std.math.add(
            usize,
            normalized_input_read,
            result.progress.input_read,
        ) catch return error.IntegerOverflow;
        if (selected and result.progress.output_written != 0) {
            if (result.progress.output_written > max_output_len -| decoded.items.len)
                return error.OutputLimitExceeded;
            try decoded.appendSlice(
                init.gpa,
                output[0..result.progress.output_written],
            );
        }
        calls += 1;
        switch (result.status) {
            .entry_header => {
                const current = reader.currentEntry().?;
                selected = !found and std.mem.eql(u8, current.name, entry_name);
            },
            .entry_done => {
                if (selected) found = true;
                selected = false;
            },
            .done => break,
            .need_output => {},
            .need_input => return error.InvalidZipArchive,
        }
        if (result.progress.input_read == 0 and
            result.progress.output_written == 0 and
            result.status != .entry_header and
            result.status != .entry_done)
            return error.InvalidBlockPlan;
    }
    try reader.finish();
    if (!found) return error.ZipEntryNotFound;
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = decoded.items,
    });
    try stdout.print(
        "zip_parts={d} zip_bytes={d} normalized_input_read={d} " ++
            "metadata_patches={d} decoded_bytes={d} calls={d} " ++
            "entry={s} path={s}\n",
        .{
            parts.items.items.len,
            reader.normalizedLength(),
            normalized_input_read,
            reader.metadataPatchCount(),
            decoded.items.len,
            calls,
            entry_name,
            output_path,
        },
    );
}

fn parseRequiredLimit(text: ?[]const u8) !usize {
    return std.fmt.parseInt(
        usize,
        text orelse return error.MissingCorpusPath,
        10,
    );
}

fn parsePassword(value: []const u8) ?[]const u8 {
    return if (std.mem.eql(u8, value, "-")) null else value;
}

fn parseCompression(value: ?[]const u8) !vort.ZipCompressionMethod {
    const name = value orelse return .deflate;
    if (std.mem.eql(u8, name, "stored") or std.mem.eql(u8, name, "store"))
        return .stored;
    if (std.mem.eql(u8, name, "deflate")) return .deflate;
    return error.UnsupportedZipCompressionMethod;
}

fn parseZip64Mode(value: ?[]const u8) !vort.Zip64Mode {
    const name = value orelse return .auto;
    if (std.mem.eql(u8, name, "auto")) return .auto;
    if (std.mem.eql(u8, name, "zip32") or std.mem.eql(u8, name, "never"))
        return .never;
    if (std.mem.eql(u8, name, "zip64") or std.mem.eql(u8, name, "always"))
        return .always;
    return error.InvalidZipArchive;
}

fn parseDescriptorMode(value: ?[]const u8) !bool {
    const name = value orelse return true;
    if (std.mem.eql(u8, name, "descriptor")) return true;
    if (std.mem.eql(u8, name, "sizes") or std.mem.eql(u8, name, "known"))
        return false;
    return error.InvalidZipArchive;
}
