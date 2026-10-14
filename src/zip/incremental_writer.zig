const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const types = @import("types.zig");
const wire = @import("wire.zig");
const zip_writer = @import("writer.zig");

pub const CompressionMethod = types.CompressionMethod;
pub const Zip64Mode = zip_writer.Zip64Mode;

pub const Error = deflate.Error || std.mem.Allocator.Error || error{
    InvalidZipEntryName,
    InvalidZipTextEncoding,
    UnsupportedZipCompressionMethod,
    Zip32LimitExceeded,
    InvalidZipWriterState,
    ZipWriterPoisoned,
};

/// Archive-wide limits and deterministic encoding options.
///
/// `archive_comment` is copied by `initWithOptions`; callers may release or
/// mutate it as soon as initialization returns. `initial_offset` is the number
/// of bytes preceding this archive (for example, a self-extracting prefix).
pub const Options = struct {
    archive_comment: []const u8 = "",
    initial_offset: u64 = 0,
    utf8: bool = true,
    zip64: Zip64Mode = .auto,
    deflate_options: deflate.RawDeflateIncrementalBestEncoder.Options = .{},
    /// Maximum input bytes retained for one Deflate planning block, including
    /// lookahead but excluding the fixed 32 KiB history and encoded output.
    max_deflate_buffer_size: usize = 1024 * 1024,
    max_entries: u64 = std.math.maxInt(u64),
    max_central_directory_size: usize = std.math.maxInt(usize),
    max_uncompressed_size: u64 = std.math.maxInt(u64),
    max_archive_size: u64 = std.math.maxInt(u64),
};

/// Metadata for one streaming entry. Only Stored and raw Deflate are accepted.
///
/// `name` and `comment` are copied by `beginEntry` and need not remain alive
/// afterward. A non-null `expected_size` is checked when input is accepted and
/// again by `finishEntry` before finalization is requested.
pub const EntryOptions = struct {
    name: []const u8,
    comment: []const u8 = "",
    method: CompressionMethod = .deflate,
    expected_size: ?u64 = null,
};

pub const Phase = enum {
    ready,
    entry_header,
    entry_data,
    entry_descriptor,
    central_directory,
    archive_end,
    done,
    poisoned,
};

/// Resumable ZIP archive writer. A complete payload and already-emitted archive
/// bytes are never retained. Central-directory bytes are retained until
/// `finishArchive`; Deflate additionally keeps one bounded planning block,
/// history/match state, and one encoded pending block.
pub const Writer = struct {
    allocator: std.mem.Allocator,
    options: Options,
    archive_comment: []u8,
    phase: Phase = .ready,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    central: std.ArrayList(u8) = .empty,
    central_offset: usize = 0,
    current: ?CurrentEntry = null,
    archive_output: u64 = 0,
    total_input: u64 = 0,
    entry_count: u64 = 0,
    any_zip64_entry: bool = false,
    final_central_offset: u64 = 0,
    final_central_size: u64 = 0,
    final_archive_zip64: bool = false,
    finish_entry_requested: bool = false,
    finish_archive_requested: bool = false,

    const Self = @This();
    const CurrentEntry = struct {
        metadata: []u8,
        name_len: usize,
        method: CompressionMethod,
        expected_size: ?u64,
        local_header_offset: u64,
        zip64: bool,
        crc: checksum.Crc32Best = checksum.Crc32Best.init(),
        uncompressed_size: u64 = 0,
        compressed_size: u64 = 0,
        deflater: ?deflate.RawDeflateIncrementalBestEncoder = null,

        fn name(self: *const CurrentEntry) []const u8 {
            return self.metadata[0..self.name_len];
        }

        fn comment(self: *const CurrentEntry) []const u8 {
            return self.metadata[self.name_len..];
        }

        fn deinit(self: *CurrentEntry, allocator: std.mem.Allocator) void {
            if (self.deflater) |*encoder| encoder.deinit();
            allocator.free(self.metadata);
            self.* = undefined;
        }
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        output_written: u64,
        current_uncompressed_size: u64,
        current_compressed_size: u64,
        pending_output: usize,
        central_metadata_size: usize,
        entry_count: u64,
        finish_entry_requested: bool,
        finish_archive_requested: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
        if (options.archive_comment.len > std.math.maxInt(u16)) return error.Zip32LimitExceeded;
        if (options.zip64 == .never and options.initial_offset >= std.math.maxInt(u32))
            return error.Zip32LimitExceeded;
        const comment = try allocator.dupe(u8, options.archive_comment);
        errdefer allocator.free(comment);
        const max_end_len = try checkedAdd(
            wire.zip64_end_of_central_len + wire.zip64_end_of_central_locator_len + wire.end_of_central_len,
            options.archive_comment.len,
        );
        var pending: std.ArrayList(u8) = .empty;
        errdefer pending.deinit(allocator);
        try pending.ensureTotalCapacity(allocator, max_end_len);
        var owned_options = options;
        owned_options.archive_comment = "";
        return .{
            .allocator = allocator,
            .options = owned_options,
            .archive_comment = comment,
            .pending = pending,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.current) |*entry| entry.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.central.deinit(self.allocator);
        self.allocator.free(self.archive_comment);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        const uncompressed_size = if (self.current) |entry| entry.uncompressed_size else 0;
        const compressed_size = if (self.current) |entry| entry.compressed_size else 0;
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.archive_output,
            .current_uncompressed_size = uncompressed_size,
            .current_compressed_size = compressed_size,
            .pending_output = self.pending.items.len - self.pending_offset,
            .central_metadata_size = self.central.items.len,
            .entry_count = self.entry_count,
            .finish_entry_requested = self.finish_entry_requested,
            .finish_archive_requested = self.finish_archive_requested,
        };
    }

    /// Request a new entry. This copies its metadata and prepares the local
    /// header, but bytes are only published by `step`.
    pub fn beginEntry(self: *Self, entry_options: EntryOptions) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested) return error.InvalidZipWriterState;
        return self.beginEntryInner(entry_options);
    }

    fn beginEntryInner(self: *Self, entry_options: EntryOptions) Error!void {
        try self.validateEntry(entry_options);
        const next_count = std.math.add(u64, self.entry_count, 1) catch return error.IntegerOverflow;
        if (next_count > self.options.max_entries) return error.OutputLimitExceeded;
        if (self.options.zip64 == .never and next_count >= std.math.maxInt(u16))
            return error.Zip32LimitExceeded;

        const metadata_len = std.math.add(usize, entry_options.name.len, entry_options.comment.len) catch
            return error.IntegerOverflow;

        const local_offset = std.math.add(
            u64,
            self.options.initial_offset,
            self.archive_output,
        ) catch return error.IntegerOverflow;
        const entry_zip64 = try self.chooseEntryZip64(entry_options, local_offset);
        const local_header_len = try checkedAdd(
            try checkedAdd(wire.local_file_header_len, entry_options.name.len),
            if (entry_zip64) 20 else 0,
        );
        const descriptor_len = if (entry_zip64)
            wire.zip64_data_descriptor_len
        else
            wire.data_descriptor_len;
        const central_header_len = try checkedAdd(
            try checkedAdd(
                try checkedAdd(wire.central_file_header_len, entry_options.name.len),
                entry_options.comment.len,
            ),
            if (entry_zip64) 28 else 0,
        );
        if (central_header_len > self.options.max_central_directory_size or
            self.central.items.len > self.options.max_central_directory_size - central_header_len)
            return error.OutputLimitExceeded;
        try self.checkArchiveAddition(local_header_len);

        // Reserve every control record that depends on this entry before any
        // payload byte can be emitted. Capacity changes are harmless if one of
        // these transactional preparations fails; phase remains `ready`.
        try self.pending.ensureTotalCapacity(self.allocator, @max(local_header_len, descriptor_len));
        try self.central.ensureUnusedCapacity(self.allocator, central_header_len);

        const metadata = try self.allocator.alloc(u8, metadata_len);
        @memcpy(metadata[0..entry_options.name.len], entry_options.name);
        @memcpy(metadata[entry_options.name.len..], entry_options.comment);

        var current = CurrentEntry{
            .metadata = metadata,
            .name_len = entry_options.name.len,
            .method = entry_options.method,
            .expected_size = entry_options.expected_size,
            .local_header_offset = local_offset,
            .zip64 = entry_zip64,
        };
        errdefer current.deinit(self.allocator);
        errdefer {
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
        }
        if (entry_options.method == .deflate) {
            if (entry_options.expected_size) |expected| {
                const expected_usize = std.math.cast(usize, expected) orelse return error.OutputLimitExceeded;
                current.deflater = deflate.RawDeflateIncrementalBestEncoder.initExactSize(
                    self.allocator,
                    self.options.deflate_options,
                    expected_usize,
                );
            } else {
                current.deflater = deflate.RawDeflateIncrementalBestEncoder.initWithOptions(
                    self.allocator,
                    self.options.deflate_options,
                );
            }
        }

        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        // Every incremental entry uses a descriptor. For a ZIP64 local header,
        // zero sizes deliberately produce two zero u64 placeholders in the
        // ZIP64 extra while the legacy fields remain 0xffffffff sentinels.
        try wire.appendLocalHeader(self.allocator, &self.pending, .{
            .name = current.name(),
            .comment = current.comment(),
            .method = current.method,
            .flags = wire.descriptor_flag | (if (self.options.utf8) wire.utf8_flag else 0),
            .crc32 = 0,
            .compressed_size = 0,
            .uncompressed_size = 0,
            .local_header_offset = local_offset,
            .zip64 = entry_zip64,
        }, .{ .zip64_size_placeholders = entry_zip64 });
        std.debug.assert(self.pending.items.len == local_header_len);

        self.current = current;
        self.finish_entry_requested = false;
        self.phase = .entry_header;
    }

    /// Request the active entry's final Deflate block and data descriptor.
    /// Continue calling `step` with empty input until it returns `.need_input`.
    pub fn finishEntry(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .entry_header and self.phase != .entry_data)
            return error.InvalidZipWriterState;
        if (self.finish_entry_requested) return error.InvalidZipWriterState;
        if (self.current.?.expected_size) |expected| {
            if (self.current.?.uncompressed_size != expected) return error.SizeMismatch;
        }
        self.finish_entry_requested = true;
    }

    /// Request the central directory and archive terminator. This is only valid
    /// after every entry descriptor has drained.
    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested)
            return error.InvalidZipWriterState;
        try self.prepareArchiveFinish();
        self.finish_archive_requested = true;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        return self.stepInner(input, output) catch |err| {
            self.phase = .poisoned;
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (output.len == 0) {
            if ((self.phase == .ready and !self.finish_archive_requested) or
                (self.phase == .entry_data and !self.finish_entry_requested and input.len == 0))
            {
                if (input.len != 0) return error.InvalidZipWriterState;
                return .{ .status = .need_input };
            }
            return .{ .status = .need_output };
        }

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            switch (self.phase) {
                .ready => {
                    if (input_read != input.len) return error.InvalidZipWriterState;
                    if (!self.finish_archive_requested)
                        return result(input_read, output_written, .need_input);
                    self.phase = .central_directory;
                    continue;
                },
                .entry_header, .entry_descriptor, .archive_end => {
                    try self.drainPending(output, &output_written);
                    if (self.pending_offset != self.pending.items.len)
                        return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    switch (self.phase) {
                        .entry_header => self.phase = .entry_data,
                        .entry_descriptor => self.phase = .ready,
                        .archive_end => {
                            self.phase = .done;
                            return result(input_read, output_written, .done);
                        },
                        else => unreachable,
                    }
                    if (output_written == output.len) {
                        const status: core.StepResult.Status = if (self.phase == .ready and !self.finish_archive_requested)
                            .need_input
                        else
                            .need_output;
                        return result(input_read, output_written, status);
                    }
                    continue;
                },
                .entry_data => {
                    if (self.finish_entry_requested) {
                        if (input_read != input.len) return error.TrailingData;
                        if (self.current.?.method == .stored) {
                            try self.finalizeEntry();
                            continue;
                        }
                        var entry = &self.current.?;
                        var encoder = &entry.deflater.?;
                        encoder.finish();
                        const codec_output = output[output_written..][0..self.limitArchiveWrite(output.len - output_written)];
                        if (codec_output.len == 0) return error.OutputLimitExceeded;
                        const encoded = try encoder.step("", codec_output);
                        try self.accountDeflateProgress(entry, "", encoded.progress, &input_read, &output_written);
                        if (encoded.status == .done) {
                            try self.finalizeEntry();
                            continue;
                        }
                        if (encoded.status == .need_output or output_written == output.len)
                            return result(input_read, output_written, .need_output);
                        return error.InvalidBlockPlan;
                    }

                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    try self.checkInputOffer(input[input_read..].len);
                    var entry = &self.current.?;
                    if (entry.method == .stored) {
                        const wanted = @min(input.len - input_read, output.len - output_written);
                        const take = self.limitArchiveWrite(wanted);
                        if (take == 0) return error.OutputLimitExceeded;
                        const bytes = input[input_read..][0..take];
                        @memcpy(output[output_written..][0..take], bytes);
                        entry.crc.update(bytes);
                        try self.addEntryInput(entry, take);
                        try self.addArchiveOutput(take);
                        entry.compressed_size = std.math.add(u64, entry.compressed_size, @as(u64, @intCast(take))) catch
                            return error.IntegerOverflow;
                        input_read += take;
                        output_written += take;
                        if (input_read != input.len)
                            return result(input_read, output_written, .need_output);
                        return result(input_read, output_written, .need_input);
                    }

                    const codec_output = output[output_written..][0..self.limitArchiveWrite(output.len - output_written)];
                    if (codec_output.len == 0) return error.OutputLimitExceeded;
                    const encoded = try entry.deflater.?.step(
                        input[input_read..],
                        codec_output,
                    );
                    const before = input_read;
                    try self.accountDeflateProgress(entry, input[input_read..], encoded.progress, &input_read, &output_written);
                    if (encoded.status == .need_output)
                        return result(input_read, output_written, .need_output);
                    if (encoded.status == .done) return error.InvalidBlockPlan;
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    if (input_read == before and encoded.progress.output_written == 0)
                        return error.InvalidBlockPlan;
                    continue;
                },
                .central_directory => {
                    if (input_read != input.len) return error.TrailingData;
                    const remaining = self.central.items[self.central_offset..];
                    const wanted = @min(remaining.len, output.len - output_written);
                    const take = self.limitArchiveWrite(wanted);
                    if (take == 0 and remaining.len != 0) return error.OutputLimitExceeded;
                    @memcpy(output[output_written..][0..take], remaining[0..take]);
                    self.central_offset += take;
                    output_written += take;
                    try self.addArchiveOutput(take);
                    if (self.central_offset != self.central.items.len)
                        return result(input_read, output_written, .need_output);
                    self.central.clearRetainingCapacity();
                    self.central_offset = 0;
                    try self.buildArchiveEnd();
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                },
                .done, .poisoned => unreachable,
            }
        }
    }

    fn validateEntry(self: *const Self, entry: EntryOptions) Error!void {
        if (entry.name.len == 0) return error.InvalidZipEntryName;
        if (entry.name.len > std.math.maxInt(u16) or entry.comment.len > std.math.maxInt(u16))
            return error.Zip32LimitExceeded;
        if (entry.method != .stored and entry.method != .deflate)
            return error.UnsupportedZipCompressionMethod;
        if (entry.expected_size) |expected| {
            if (expected > self.options.max_uncompressed_size) return error.OutputLimitExceeded;
            if (self.options.zip64 == .never and expected >= std.math.maxInt(u32))
                return error.Zip32LimitExceeded;
        }
        if (entry.method == .deflate) {
            try deflate.RawDeflateIncrementalBestEncoder.validateOptions(self.options.deflate_options);
            const retained = try deflate.RawDeflateIncrementalBestEncoder.maxBufferedInput(
                self.options.deflate_options,
            );
            if (retained > self.options.max_deflate_buffer_size)
                return error.OutputLimitExceeded;
            if (entry.expected_size) |expected| {
                if (expected > @as(u64, @intCast(self.options.deflate_options.max_input_len)))
                    return error.OutputLimitExceeded;
                _ = std.math.cast(usize, expected) orelse return error.OutputLimitExceeded;
            }
        }
        if (self.options.utf8 and
            (!std.unicode.utf8ValidateSlice(entry.name) or
                !std.unicode.utf8ValidateSlice(entry.comment)))
            return error.InvalidZipTextEncoding;
    }

    fn chooseEntryZip64(self: *const Self, entry: EntryOptions, local_offset: u64) Error!bool {
        if (self.options.zip64 == .always) return true;
        if (self.options.zip64 == .never) {
            if (local_offset >= std.math.maxInt(u32)) return error.Zip32LimitExceeded;
            return false;
        }
        if (local_offset >= std.math.maxInt(u32)) return true;
        const expected = entry.expected_size orelse return true;
        // Raw Deflate has no cheap exact compressed-size bound in this layer;
        // conservatively reserve ZIP64 before emitting its unpatchable header.
        if (entry.method == .deflate) return true;
        return expected >= std.math.maxInt(u32);
    }

    fn checkInputOffer(self: *const Self, offered: usize) Error!void {
        const entry = self.current.?;
        const next_entry = std.math.add(u64, entry.uncompressed_size, @as(u64, @intCast(offered))) catch
            return error.IntegerOverflow;
        if (next_entry > self.options.max_uncompressed_size) return error.OutputLimitExceeded;
        if (entry.method == .deflate and
            (next_entry > std.math.maxInt(usize) or
                next_entry > @as(u64, @intCast(self.options.deflate_options.max_input_len))))
            return error.OutputLimitExceeded;
        if (entry.expected_size) |expected| if (next_entry > expected) return error.SizeMismatch;
    }

    fn addEntryInput(self: *Self, entry: *CurrentEntry, amount: usize) Error!void {
        const amount64: u64 = @intCast(amount);
        entry.uncompressed_size = std.math.add(u64, entry.uncompressed_size, amount64) catch
            return error.IntegerOverflow;
        self.total_input = std.math.add(u64, self.total_input, amount64) catch
            return error.IntegerOverflow;
    }

    fn accountDeflateProgress(
        self: *Self,
        entry: *CurrentEntry,
        input: []const u8,
        progress: core.Progress,
        input_read: *usize,
        output_written: *usize,
    ) Error!void {
        if (progress.input_read > input.len) return error.InvalidBlockPlan;
        entry.crc.update(input[0..progress.input_read]);
        try self.addEntryInput(entry, progress.input_read);
        entry.compressed_size = std.math.add(
            u64,
            entry.compressed_size,
            @as(u64, @intCast(progress.output_written)),
        ) catch return error.IntegerOverflow;
        try self.addArchiveOutput(progress.output_written);
        input_read.* += progress.input_read;
        output_written.* += progress.output_written;
    }

    fn finalizeEntry(self: *Self) Error!void {
        var entry = &self.current.?;
        if (entry.expected_size) |expected| {
            if (entry.uncompressed_size != expected) return error.SizeMismatch;
        }
        if (!entry.zip64 and
            (entry.uncompressed_size >= std.math.maxInt(u32) or
                entry.compressed_size >= std.math.maxInt(u32) or
                entry.local_header_offset >= std.math.maxInt(u32)))
            return error.Zip32LimitExceeded;

        const record = wire.EncodedEntry{
            .name = entry.name(),
            .comment = entry.comment(),
            .method = entry.method,
            .flags = wire.descriptor_flag | (if (self.options.utf8) wire.utf8_flag else 0),
            .crc32 = entry.crc.digest(),
            .compressed_size = entry.compressed_size,
            .uncompressed_size = entry.uncompressed_size,
            .local_header_offset = entry.local_header_offset,
            .zip64 = entry.zip64,
        };

        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        try wire.appendDataDescriptor(self.allocator, &self.pending, record);
        try self.checkArchiveAddition(self.pending.items.len);
        const central_start = self.central.items.len;
        errdefer self.central.items.len = central_start;
        try wire.appendCentralHeader(self.allocator, &self.central, record);
        std.debug.assert(self.central.items.len <= self.options.max_central_directory_size);

        self.entry_count = std.math.add(u64, self.entry_count, 1) catch return error.IntegerOverflow;
        self.any_zip64_entry = self.any_zip64_entry or entry.zip64;
        entry.deinit(self.allocator);
        self.current = null;
        self.finish_entry_requested = false;
        self.phase = .entry_descriptor;
    }

    fn prepareArchiveFinish(self: *Self) Error!void {
        const absolute_central_offset = std.math.add(
            u64,
            self.options.initial_offset,
            self.archive_output,
        ) catch return error.IntegerOverflow;
        const central_size: u64 = @intCast(self.central.items.len);
        const zip64 = self.options.zip64 == .always or self.any_zip64_entry or
            self.entry_count >= std.math.maxInt(u16) or
            central_size >= std.math.maxInt(u32) or
            absolute_central_offset >= std.math.maxInt(u32);
        if (zip64 and self.options.zip64 == .never) return error.Zip32LimitExceeded;
        _ = std.math.add(u64, absolute_central_offset, central_size) catch
            return error.IntegerOverflow;
        const archive_end_len = try checkedAdd(
            if (zip64)
                wire.zip64_end_of_central_len + wire.zip64_end_of_central_locator_len + wire.end_of_central_len
            else
                wire.end_of_central_len,
            self.archive_comment.len,
        );
        try self.checkArchiveAddition(try checkedAdd(self.central.items.len, archive_end_len));
        self.final_central_offset = absolute_central_offset;
        self.final_central_size = central_size;
        self.final_archive_zip64 = zip64;
    }

    fn buildArchiveEnd(self: *Self) Error!void {
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        if (self.final_archive_zip64) {
            const zip64_record_offset = std.math.add(
                u64,
                self.final_central_offset,
                self.final_central_size,
            ) catch return error.IntegerOverflow;
            try wire.appendZip64EndAtOffset(
                self.allocator,
                &self.pending,
                zip64_record_offset,
                self.entry_count,
                self.final_central_size,
                self.final_central_offset,
                self.archive_comment,
            );
        } else {
            try wire.appendLegacyEnd(
                self.allocator,
                &self.pending,
                @intCast(self.entry_count),
                @intCast(self.final_central_size),
                @intCast(self.final_central_offset),
                self.archive_comment,
            );
        }
        try self.checkArchiveAddition(self.pending.items.len);
        self.phase = .archive_end;
    }

    fn drainPending(self: *Self, output: []u8, output_written: *usize) Error!void {
        const remaining = self.pending.items[self.pending_offset..];
        const wanted = @min(remaining.len, output.len - output_written.*);
        const take = self.limitArchiveWrite(wanted);
        if (take == 0 and remaining.len != 0) return error.OutputLimitExceeded;
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        try self.addArchiveOutput(take);
    }

    fn addArchiveOutput(self: *Self, amount: usize) Error!void {
        const amount64: u64 = @intCast(amount);
        const next = std.math.add(u64, self.archive_output, amount64) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
        self.archive_output = next;
    }

    fn checkArchiveAddition(self: *const Self, amount: usize) Error!void {
        const next = std.math.add(u64, self.archive_output, @as(u64, @intCast(amount))) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
    }

    fn limitArchiveWrite(self: *const Self, wanted: usize) usize {
        const remaining = self.options.max_archive_size -| self.archive_output;
        return @min(wanted, std.math.cast(usize, remaining) orelse std.math.maxInt(usize));
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }

    fn checkedAdd(a: usize, b: usize) Error!usize {
        return std.math.add(usize, a, b) catch error.IntegerOverflow;
    }
};

test {
    _ = @import("incremental_writer_tests.zig");
}
