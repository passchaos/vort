//! Symbol-progressive decoder for one entry in a source-backed 7z archive.
//!
//! The decoder reads packed bytes positionally, optionally decrypts 7zAES in
//! CBC blocks, drives a caller-output codec, discards solid-folder prefixes and
//! suffixes, and validates packed/folder/entry CRCs before reporting `.done`.

const std = @import("std");
const archive_mod = @import("archive.zig");
const aes = @import("aes.zig");
const bcj2_decoder = @import("source_entry/bcj2_decoder.zig");
const checksum = @import("../checksum.zig");
const codec_mod = @import("source_entry/codec.zig");
const core = @import("../core.zig");
const crypto = @import("vail_archive_crypto").seven_zip;
const packed_input = @import("packed_input.zig");
const source_mod = @import("source.zig");
const streams_mod = @import("streams.zig");
const types = @import("types.zig");
const xz = @import("../xz.zig");
const xz_filters = @import("../xz/filters.zig");

pub const LinearDecoder = struct {
    allocator: std.mem.Allocator,
    source: source_mod.Source,
    options: Options,
    entry: types.Entry,
    folder_size: usize,
    entry_start: usize,
    entry_end: usize,
    stream_offset: u64 = 0,
    packed_remaining: usize = 0,
    packed_crc_expected: ?u32 = null,
    folder_crc_expected: ?u32 = null,
    packed_crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    folder_crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    entry_crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    input_buffer: []u8,
    input_start: usize = 0,
    input_len: usize = 0,
    decoded_buffer: []u8,
    codec_output_size: usize,
    decoded_start: usize = 0,
    decoded_len: usize = 0,
    decoded_base: usize = 0,
    folder_produced: usize = 0,
    entry_written: usize = 0,
    codec: codec_mod.Codec,
    filters: ?xz.IncrementalFilterDecoder = null,
    filtered: std.ArrayList(u8) = .empty,
    filters_flushed: bool = false,
    decryptor: ?crypto.Decryptor = null,
    aes_plain_remaining: usize = 0,
    packed_validated: bool = false,
    codec_input_finished: bool = false,
    codec_done: bool = false,
    empty_entry: bool = false,
    done: bool = false,
    last_error_name: []const u8 = "",

    pub const Error = archive_mod.Error || source_mod.Error || codec_mod.Error ||
        xz.Error || crypto.Error || error{
        Invalid7zArchive,
        Unsupported7zFeature,
    };

    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_dictionary_size: usize = 512 * 1024 * 1024,
        max_folder_output_len: usize = 512 * 1024 * 1024,
        max_packed_stream_size: usize = 512 * 1024 * 1024,
        max_kdf_cycles_power: u6 = aes.max_cycles_power,
        password: ?[]const u8 = null,
        input_buffer_size: usize = 64 * 1024,
        decoded_buffer_size: usize = 64 * 1024,
    };

    pub const Snapshot = struct {
        folder_produced: usize,
        entry_written: usize,
        source_bytes_remaining: usize,
        buffered_codec_input: usize,
        buffered_decoded_output: usize,
        codec_name: []const u8,
        encrypted: bool,
        done: bool,
        last_error_name: []const u8,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        source: source_mod.Source,
        streams: *const streams_mod.Streams,
        packed_data_limit: u64,
        entry: types.Entry,
        options: Options,
    ) Error!LinearDecoder {
        if (entry.is_anti) return error.EntryHasNoStream;
        const entry_size = std.math.cast(usize, entry.size) orelse
            return error.OutputLimitExceeded;
        if (entry_size > options.max_output_len) return error.OutputLimitExceeded;
        if (options.input_buffer_size == 0 or options.decoded_buffer_size == 0)
            return error.OutputLimitExceeded;

        const folder_index = entry.folder_index orelse {
            if (entry.kind != .file or entry.size != 0) return error.EntryHasNoStream;
            const input_buffer = try allocator.alloc(u8, options.input_buffer_size);
            errdefer allocator.free(input_buffer);
            const decoded_buffer = try allocator.alloc(u8, options.decoded_buffer_size);
            return .{
                .allocator = allocator,
                .source = source,
                .options = options,
                .entry = entry,
                .folder_size = 0,
                .entry_start = 0,
                .entry_end = 0,
                .input_buffer = input_buffer,
                .decoded_buffer = decoded_buffer,
                .codec_output_size = options.decoded_buffer_size,
                .codec = .{ .copy = .{ .expected = 0 } },
                .empty_entry = true,
            };
        };
        if (folder_index >= streams.folders.len) return error.Invalid7zArchive;
        const folder = streams.folders[folder_index];
        if (folder.bcj2_coder_index != null or folder.pack_stream_count != 1)
            return error.Unsupported7zFeature;
        const folder_size = std.math.cast(usize, folder.unpack_size) orelse
            return error.OutputLimitExceeded;
        if (folder_size > options.max_folder_output_len) return error.OutputLimitExceeded;
        const entry_start = std.math.cast(usize, entry.offset_in_folder) orelse
            return error.Invalid7zArchive;
        const entry_end = std.math.add(usize, entry_start, entry_size) catch
            return error.Invalid7zArchive;
        if (entry_end > folder_size) return error.Invalid7zArchive;

        const primary_index = folder.primaryCoderIndex() orelse
            return error.Invalid7zArchive;
        var primary_order: ?usize = null;
        for (folder.decode_order[0..folder.coder_count], 0..) |coder_index, order|
            if (coder_index == primary_index) {
                primary_order = order;
                break;
            };
        const compression_order = primary_order orelse return error.Invalid7zArchive;
        const aes_index = folder.aes_coder_index;
        if ((aes_index == null and compression_order != 0) or
            (aes_index != null and
                (compression_order != 1 or folder.decode_order[0] != aes_index.?)))
            return error.Unsupported7zFeature;
        var filter_values: [3]xz.Filter = undefined;
        var filter_count: usize = 0;
        for (folder.decode_order[compression_order + 1 .. folder.coder_count]) |coder_index| {
            if (filter_count == filter_values.len) return error.Unsupported7zFeature;
            filter_values[filter_count] = try parseFilter(folder.coders[coder_index]);
            filter_count += 1;
        }
        const primary = folder.coders[primary_index];
        const primary_size = std.math.cast(
            usize,
            folder.coder_unpack_sizes[primary_index],
        ) orelse return error.OutputLimitExceeded;
        if (primary_size != folder_size) return error.Unsupported7zFeature;

        const input = packed_input.Input.fromSource(
            source,
            packed_data_limit,
            options.max_packed_stream_size,
        );
        const stream_range = try packed_input.packRange(input, streams, folder.pack_index);
        const packed_size = std.math.cast(usize, stream_range.size) orelse
            return error.OutputLimitExceeded;
        if (packed_size > options.max_packed_stream_size)
            return error.OutputLimitExceeded;

        var input_buffer_size = options.input_buffer_size;
        if (aes_index != null) {
            input_buffer_size &= ~(crypto.block_len - 1);
            if (input_buffer_size < crypto.block_len) return error.OutputLimitExceeded;
        }
        const input_buffer = try allocator.alloc(u8, input_buffer_size);
        errdefer allocator.free(input_buffer);
        const decoded_allocation_size = std.math.add(
            usize,
            options.decoded_buffer_size,
            3 * 32,
        ) catch return error.OutputLimitExceeded;
        const decoded_buffer = try allocator.alloc(u8, decoded_allocation_size);
        errdefer allocator.free(decoded_buffer);
        var codec = try codec_mod.Codec.init(
            allocator,
            primary,
            primary_size,
            options.max_dictionary_size,
        );
        errdefer codec.deinit(allocator);
        var filter_decoder: ?xz.IncrementalFilterDecoder = null;
        if (filter_count != 0)
            filter_decoder = try xz.IncrementalFilterDecoder.init(
                allocator,
                filter_values[0..filter_count],
            );
        errdefer if (filter_decoder) |*decoder| decoder.deinit();

        var decryptor: ?crypto.Decryptor = null;
        var plain_size = packed_size;
        if (aes_index) |coder_index| {
            const coder = folder.coders[coder_index];
            const properties = aes.parseProperties(coder.propertyBytes()) catch
                return error.Invalid7zArchive;
            plain_size = std.math.cast(
                usize,
                folder.coder_unpack_sizes[coder_index],
            ) orelse return error.OutputLimitExceeded;
            if (packed_size & (crypto.block_len - 1) != 0 or
                plain_size > packed_size or packed_size - plain_size >= crypto.block_len)
                return error.Invalid7zArchive;
            const password = options.password orelse return error.PasswordRequired;
            var key = try aes.deriveKey(
                allocator,
                password,
                properties,
                options.max_kdf_cycles_power,
            );
            defer std.crypto.secureZero(u8, &key);
            decryptor = crypto.Decryptor.init(key, properties.iv);
        }

        return .{
            .allocator = allocator,
            .source = source,
            .options = options,
            .entry = entry,
            .folder_size = folder_size,
            .entry_start = entry_start,
            .entry_end = entry_end,
            .stream_offset = stream_range.start,
            .packed_remaining = packed_size,
            .packed_crc_expected = streams.pack_crcs[folder.pack_index],
            .folder_crc_expected = folder.crc32,
            .input_buffer = input_buffer,
            .decoded_buffer = decoded_buffer,
            .codec_output_size = options.decoded_buffer_size,
            .codec = codec,
            .filters = filter_decoder,
            .decryptor = decryptor,
            .aes_plain_remaining = if (decryptor != null) plain_size else 0,
        };
    }

    pub fn deinit(self: *LinearDecoder) void {
        if (self.decryptor) |*decryptor| decryptor.deinit();
        if (self.filters) |*filters| filters.deinit();
        self.filtered.deinit(self.allocator);
        self.codec.deinit(self.allocator);
        self.allocator.free(self.input_buffer);
        self.allocator.free(self.decoded_buffer);
        self.* = undefined;
    }

    pub fn snapshot(self: *const LinearDecoder) Snapshot {
        return .{
            .folder_produced = self.folder_produced,
            .entry_written = self.entry_written,
            .source_bytes_remaining = self.packed_remaining,
            .buffered_codec_input = self.input_len - self.input_start,
            .buffered_decoded_output = self.decoded_len - self.decoded_start,
            .codec_name = self.codec.name(),
            .encrypted = self.decryptor != null,
            .done = self.done,
            .last_error_name = self.last_error_name,
        };
    }

    pub fn step(self: *LinearDecoder, output: []u8) Error!core.StepResult {
        return self.stepInternal(output) catch |err| {
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    fn stepInternal(self: *LinearDecoder, output: []u8) Error!core.StepResult {
        if (self.done) return .{ .status = .done };
        if (self.empty_entry) {
            self.done = true;
            return .{ .status = .done };
        }

        var source_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (!self.drainDecoded(output, &output_written))
                return result(source_read, output_written, .need_output);
            if (self.codec_done) {
                if (!self.filters_flushed) {
                    try self.acceptDecoded("", true);
                    self.filters_flushed = true;
                    if (self.decoded_len != 0) continue;
                }
                try self.finishChecks();
                self.done = true;
                return result(source_read, output_written, .done);
            }

            if (self.input_start == self.input_len and self.packed_remaining != 0) {
                self.input_start = 0;
                self.input_len = 0;
            }
            if (self.input_len - self.input_start < self.input_buffer.len and
                self.packed_remaining != 0)
            {
                source_read = std.math.add(
                    usize,
                    source_read,
                    try self.fillInput(),
                ) catch return error.IntegerOverflow;
            }

            self.decoded_start = 0;
            self.decoded_len = 0;
            const codec_input = self.input_buffer[self.input_start..self.input_len];
            const stepped = try self.codec.step(
                codec_input,
                self.decoded_buffer[0..self.codec_output_size],
            );
            if (stepped.progress.input_read > codec_input.len or
                stepped.progress.output_written > self.decoded_buffer.len)
                return error.Invalid7zArchive;
            self.input_start += stepped.progress.input_read;
            if (stepped.progress.output_written != 0) {
                try self.acceptDecoded(
                    self.decoded_buffer[0..stepped.progress.output_written],
                    false,
                );
            }

            if (stepped.status == .done) {
                if (self.input_start != self.input_len or self.packed_remaining != 0)
                    return error.TrailingData;
                try self.validatePackedEnd();
                self.codec_done = true;
                continue;
            }
            if (stepped.progress.input_read != 0 or stepped.progress.output_written != 0)
                continue;
            if (stepped.status == .need_output) return error.Invalid7zArchive;

            if (self.input_start != self.input_len) {
                if (self.packed_remaining == 0) return error.TruncatedFrame;
                if (self.input_len == self.input_buffer.len)
                    return error.OutputLimitExceeded;
                try self.compactInput();
                continue;
            }
            if (self.packed_remaining != 0) continue;
            try self.validatePackedEnd();
            if (!self.codec_input_finished) {
                try self.codec.finish();
                self.codec_input_finished = true;
                continue;
            }
            return error.TruncatedFrame;
        }
    }

    fn fillInput(self: *LinearDecoder) Error!usize {
        try self.compactInput();
        const available = self.input_buffer.len - self.input_len;
        if (available == 0) return 0;
        var count = @min(available, self.packed_remaining);
        if (self.decryptor != null) {
            count &= ~(crypto.block_len - 1);
            if (count == 0) return error.OutputLimitExceeded;
        }
        const destination = self.input_buffer[self.input_len..][0..count];
        try self.source.readExact(self.stream_offset, destination);
        self.packed_crc.update(destination);
        self.stream_offset = std.math.add(u64, self.stream_offset, count) catch
            return error.IntegerOverflow;
        self.packed_remaining -= count;

        const exposed = if (self.decryptor) |*decryptor| decrypted: {
            decryptor.decryptBlocks(destination, destination) catch
                return error.Invalid7zArchive;
            const plain = @min(count, self.aes_plain_remaining);
            self.aes_plain_remaining -= plain;
            break :decrypted plain;
        } else count;
        self.input_len += exposed;
        return count;
    }

    fn acceptDecoded(self: *LinearDecoder, raw: []const u8, finish: bool) Error!void {
        const bytes = if (self.filters) |*filter_decoder| filtered: {
            self.filtered.clearRetainingCapacity();
            try filter_decoder.push(raw, finish, &self.filtered);
            if (self.filtered.items.len > self.decoded_buffer.len)
                return error.OutputLimitExceeded;
            @memcpy(self.decoded_buffer[0..self.filtered.items.len], self.filtered.items);
            break :filtered self.decoded_buffer[0..self.filtered.items.len];
        } else raw;
        self.decoded_start = 0;
        self.decoded_base = self.folder_produced;
        self.decoded_len = bytes.len;
        self.folder_produced = std.math.add(
            usize,
            self.folder_produced,
            bytes.len,
        ) catch return error.IntegerOverflow;
        if (self.folder_produced > self.folder_size) return error.SizeMismatch;
        self.folder_crc.update(bytes);
    }

    fn compactInput(self: *LinearDecoder) Error!void {
        if (self.input_start == 0) return;
        const remaining = self.input_len - self.input_start;
        std.mem.copyForwards(
            u8,
            self.input_buffer[0..remaining],
            self.input_buffer[self.input_start..self.input_len],
        );
        self.input_start = 0;
        self.input_len = remaining;
    }

    fn drainDecoded(
        self: *LinearDecoder,
        output: []u8,
        output_written: *usize,
    ) bool {
        while (self.decoded_start < self.decoded_len) {
            const absolute = self.decoded_base + self.decoded_start;
            if (absolute < self.entry_start) {
                self.decoded_start += @min(
                    self.decoded_len - self.decoded_start,
                    self.entry_start - absolute,
                );
                continue;
            }
            if (absolute >= self.entry_end) {
                self.decoded_start = self.decoded_len;
                continue;
            }
            if (output_written.* == output.len) return false;
            const count = @min(
                self.decoded_len - self.decoded_start,
                @min(self.entry_end - absolute, output.len - output_written.*),
            );
            const bytes = self.decoded_buffer[self.decoded_start..][0..count];
            @memcpy(output[output_written.*..][0..count], bytes);
            self.entry_crc.update(bytes);
            self.decoded_start += count;
            output_written.* += count;
            self.entry_written += count;
        }
        self.decoded_start = 0;
        self.decoded_len = 0;
        return true;
    }

    fn validatePackedEnd(self: *LinearDecoder) Error!void {
        if (self.packed_validated) return;
        if (self.packed_remaining != 0 or self.input_start != self.input_len or
            self.aes_plain_remaining != 0)
            return error.SizeMismatch;
        if (self.packed_crc_expected) |expected|
            if (self.packed_crc.digest() != expected) return error.ChecksumMismatch;
        self.packed_validated = true;
    }

    fn finishChecks(self: *LinearDecoder) Error!void {
        if (self.folder_produced != self.folder_size or
            self.entry_written != self.entry_end - self.entry_start)
            return error.SizeMismatch;
        if (self.folder_crc_expected) |expected|
            if (self.folder_crc.digest() != expected) return error.ChecksumMismatch;
        if (self.entry.crc32) |expected|
            if (self.entry_crc.digest() != expected) return error.ChecksumMismatch;
    }
};

fn parseFilter(coder: streams_mod.Coder) LinearDecoder.Error!xz.Filter {
    const filter_id: u64 = switch (coder.method) {
        .delta => 0x03,
        .x86 => 0x04,
        .powerpc => 0x05,
        .ia64 => 0x06,
        .arm => 0x07,
        .arm_thumb => 0x08,
        .sparc => 0x09,
        .arm64 => 0x0a,
        .riscv => 0x0b,
        else => return error.Unsupported7zFeature,
    };
    return xz_filters.parse(filter_id, coder.propertyBytes()) catch |err| switch (err) {
        error.InvalidXzHeader => error.Invalid7zArchive,
        error.UnsupportedXzFeature => error.Unsupported7zFeature,
    };
}

pub const Decoder = union(enum) {
    linear: LinearDecoder,
    bcj2: bcj2_decoder.Decoder,

    pub const Options = LinearDecoder.Options;
    pub const Snapshot = LinearDecoder.Snapshot;
    pub const Error = LinearDecoder.Error || bcj2_decoder.Error;

    pub fn init(
        allocator: std.mem.Allocator,
        source: source_mod.Source,
        streams: *const streams_mod.Streams,
        packed_data_limit: u64,
        entry: types.Entry,
        options: Options,
    ) Error!Decoder {
        if (entry.folder_index) |folder_index| {
            if (folder_index >= streams.folders.len) return error.Invalid7zArchive;
            if (streams.folders[folder_index].bcj2_coder_index != null)
                return .{ .bcj2 = try bcj2_decoder.Decoder.init(
                    allocator,
                    source,
                    streams,
                    packed_data_limit,
                    entry,
                    .{
                        .max_output_len = options.max_output_len,
                        .max_dictionary_size = options.max_dictionary_size,
                        .max_folder_output_len = options.max_folder_output_len,
                        .max_packed_stream_size = options.max_packed_stream_size,
                        .max_kdf_cycles_power = options.max_kdf_cycles_power,
                        .password = options.password,
                        .input_buffer_size = options.input_buffer_size,
                        .decoded_buffer_size = options.decoded_buffer_size,
                    },
                ) };
        }
        return .{ .linear = try LinearDecoder.init(
            allocator,
            source,
            streams,
            packed_data_limit,
            entry,
            options,
        ) };
    }

    pub fn deinit(self: *Decoder) void {
        switch (self.*) {
            .linear => |*decoder| decoder.deinit(),
            .bcj2 => |*decoder| decoder.deinit(),
        }
        self.* = undefined;
    }

    pub fn step(self: *Decoder, output: []u8) Error!core.StepResult {
        return switch (self.*) {
            .linear => |*decoder| decoder.step(output),
            .bcj2 => |*decoder| decoder.step(output),
        };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return switch (self.*) {
            .linear => |*decoder| decoder.snapshot(),
            .bcj2 => |*decoder| blk: {
                const snap = decoder.snapshot();
                break :blk .{
                    .folder_produced = snap.folder_produced,
                    .entry_written = snap.entry_written,
                    .source_bytes_remaining = snap.source_bytes_remaining,
                    .buffered_codec_input = snap.buffered_codec_input,
                    .buffered_decoded_output = snap.buffered_decoded_output,
                    .codec_name = snap.codec_name,
                    .encrypted = snap.encrypted,
                    .done = snap.done,
                    .last_error_name = snap.last_error_name,
                };
            },
        };
    }
};

fn result(
    input_read: usize,
    output_written: usize,
    status: core.StepResult.Status,
) core.StepResult {
    return .{
        .progress = .{ .input_read = input_read, .output_written = output_written },
        .status = status,
    };
}
