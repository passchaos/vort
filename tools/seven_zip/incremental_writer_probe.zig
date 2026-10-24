const std = @import("std");
const vort = @import("vort");

const Entry = struct {
    options: vort.SevenZipIncrementalEntryOptions,
    data: []const u8,
};

const MemorySpool = struct {
    allocator: std.mem.Allocator,
    bytes: std.ArrayList(u8) = .empty,

    fn deinit(self: *MemorySpool) void {
        self.bytes.deinit(self.allocator);
        self.* = undefined;
    }

    fn descriptor(self: *MemorySpool) vort.SevenZipIncrementalSecondarySpool {
        return .{
            .context = self,
            .reset = reset,
            .write = write,
            .read_at = readAt,
        };
    }

    fn reset(context: *anyopaque) !void {
        const self: *MemorySpool = @ptrCast(@alignCast(context));
        self.bytes.clearRetainingCapacity();
    }

    fn write(context: *anyopaque, bytes: []const u8) !void {
        const self: *MemorySpool = @ptrCast(@alignCast(context));
        try self.bytes.appendSlice(self.allocator, bytes);
    }

    fn readAt(context: *anyopaque, offset: u64, output: []u8) !usize {
        const self: *MemorySpool = @ptrCast(@alignCast(context));
        const start = std.math.cast(usize, offset) orelse return error.InvalidSpoolOffset;
        if (start >= self.bytes.items.len) return 0;
        const amount = @min(output.len, self.bytes.items.len - start);
        @memcpy(output[0..amount], self.bytes.items[start..][0..amount]);
        return amount;
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const output_path = args.next() orelse return error.MissingOutputPath;
    const compression = try parseCompression(args.next() orelse "copy");
    const solid = if (args.next()) |value|
        if (std.mem.eql(u8, value, "solid")) true else if (std.mem.eql(u8, value, "independent")) false else return error.InvalidMode
    else
        false;
    const encrypted = if (args.next()) |value|
        if (std.mem.eql(u8, value, "encrypted")) true else if (std.mem.eql(u8, value, "plain")) false else return error.InvalidMode
    else
        false;
    const terminal_compression: ?vort.SevenZipCompression = if (args.next()) |value|
        if (std.mem.eql(u8, value, "inline")) null else try parseCompression(value)
    else
        null;
    const bcj2 = if (args.next()) |value|
        if (std.mem.eql(u8, value, "bcj2")) true else if (std.mem.eql(u8, value, "linear")) false else return error.InvalidMode
    else
        false;
    if (args.next() != null) return error.UnexpectedArgument;

    const filetime_epoch: u64 = 116_444_736_000_000_000;
    const first = "Vort 7z payload\n";
    const second = "Vort 7z UTF-8\n";
    const entries = [_]Entry{
        .{
            .options = .{
                .name = "plain.txt",
                .expected_size = first.len,
                .creation_time = filetime_epoch + 10_000_000,
                .access_time = filetime_epoch + 20_000_000,
                .modification_time = filetime_epoch + 30_000_000,
                .start_position = 0x1_0000_0001,
                .attributes = 0x81a4_0020,
            },
            .data = first,
        },
        .{
            .options = .{
                .name = "empty.txt",
                .expected_size = 0,
                .modification_time = filetime_epoch + 40_000_000,
                .start_position = 0,
                .attributes = 0x81a4_0020,
            },
            .data = "",
        },
        .{
            .options = .{
                .name = "folder",
                .kind = .directory,
                .creation_time = filetime_epoch + 50_000_000,
                .attributes = 0x41ed_0010,
            },
            .data = "",
        },
        .{
            .options = .{
                .name = "utf8-目录/数据.txt",
                .expected_size = second.len,
                .access_time = filetime_epoch + 60_000_000,
                .modification_time = filetime_epoch + 70_000_000,
                .attributes = 0x81a4_0020,
            },
            .data = second,
        },
        .{
            .options = .{
                .name = "deleted.txt",
                .is_anti = true,
                .expected_size = 0,
                .attributes = 0x81a4_0020,
            },
            .data = "",
        },
        .{
            .options = .{
                .name = "deleted-folder",
                .kind = .directory,
                .is_anti = true,
                .attributes = 0x41ed_0010,
            },
            .data = "",
        },
    };
    const encryption: ?vort.SevenZipEncryptionOptions = if (encrypted) .{
        .password = "vort-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = 0x3f,
    } else null;
    var spool = MemorySpool{ .allocator = init.gpa };
    defer spool.deinit();
    var writer = try vort.SevenZipIncrementalWriter.init(init.gpa, .{
        .encode = .{
            .compression = compression,
            .solid = solid,
            .header_compression = terminal_compression,
            .external_names = terminal_compression,
            .external_metadata = terminal_compression,
            .encryption = encryption,
            .encrypt_header = encrypted and terminal_compression != null,
            .bcj2 = bcj2,
            .bcj2_start_ip = 0,
        },
        .bcj2_spool = if (bcj2) spool.descriptor() else null,
        .bcj2_spool_read_buffer_size = 3,
    });
    defer writer.deinit();
    var archive: std.ArrayList(u8) = .empty;
    defer archive.deinit(init.gpa);
    var output_storage: [7]u8 = undefined;
    var output_index: usize = 0;

    for (entries) |entry| {
        try writer.beginEntry(entry.options);
        var input_offset: usize = 0;
        while (input_offset < entry.data.len) {
            const input_end = @min(entry.data.len, input_offset + 3);
            while (input_offset < input_end) {
                const output = nextOutput(&output_storage, &output_index);
                const stepped = try writer.step(entry.data[input_offset..input_end], output);
                input_offset += stepped.progress.input_read;
                try archive.appendSlice(init.gpa, output[0..stepped.progress.output_written]);
                if (stepped.progress.input_read == 0 and stepped.progress.output_written == 0)
                    return error.WriterMadeNoProgress;
            }
        }
        try writer.finishEntry();
        while (writer.snapshot().phase != .ready and writer.snapshot().phase != .start_header) {
            const output = nextOutput(&output_storage, &output_index);
            const stepped = try writer.step(&.{}, output);
            try archive.appendSlice(init.gpa, output[0..stepped.progress.output_written]);
            if (stepped.progress.output_written == 0 and
                writer.snapshot().phase != .ready and writer.snapshot().phase != .start_header)
                return error.WriterMadeNoProgress;
        }
    }
    while (writer.snapshot().phase == .start_header) {
        const output = nextOutput(&output_storage, &output_index);
        const stepped = try writer.step(&.{}, output);
        try archive.appendSlice(init.gpa, output[0..stepped.progress.output_written]);
        if (stepped.progress.output_written == 0) return error.WriterMadeNoProgress;
    }
    try writer.finishArchive();
    while (true) {
        const output = nextOutput(&output_storage, &output_index);
        const stepped = try writer.step(&.{}, output);
        try archive.appendSlice(init.gpa, output[0..stepped.progress.output_written]);
        if (stepped.status == .done) break;
        if (stepped.progress.output_written == 0) return error.WriterMadeNoProgress;
    }
    const start_header = try writer.startHeaderPatch();
    if (archive.items.len < start_header.len) return error.WriterMadeNoProgress;
    @memcpy(archive.items[0..start_header.len], &start_header);
    try std.Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = output_path,
        .data = archive.items,
    });
}

fn parseCompression(name: []const u8) !vort.SevenZipCompression {
    if (std.mem.eql(u8, name, "copy")) return .copy;
    if (std.mem.eql(u8, name, "deflate")) return .deflate;
    if (std.mem.eql(u8, name, "bzip2")) return .bzip2;
    if (std.mem.eql(u8, name, "lzma")) return .lzma;
    if (std.mem.eql(u8, name, "lzma2")) return .lzma2;
    if (std.mem.eql(u8, name, "lzma2-stored")) return .lzma2_stored;
    if (std.mem.eql(u8, name, "ppmd7")) return .ppmd7;
    return error.UnsupportedCompression;
}

fn nextOutput(storage: *[7]u8, index: *usize) []u8 {
    const lengths = [_]usize{ 1, 2, 3, 5, 7 };
    const len = lengths[index.* % lengths.len];
    index.* += 1;
    return storage[0..len];
}
