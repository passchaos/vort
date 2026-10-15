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
