//! Symbol-progressive BCJ2 folder decoder over four positional packed branches.

const std = @import("std");
const archive_mod = @import("../archive.zig");
const branch_mod = @import("packed_branch.zig");
const checksum = @import("../../checksum.zig");
const codec_mod = @import("codec.zig");
const core = @import("../../core.zig");
const packed_input = @import("../packed_input.zig");
const source_mod = @import("../source.zig");
const streams_mod = @import("../streams.zig");
const types = @import("../types.zig");

const top_value: u32 = 1 << 24;
const probability_total: u32 = 1 << 11;
const move_bits: u5 = 5;

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 512 * 1024 * 1024,
    max_folder_output_len: usize = 512 * 1024 * 1024,
    max_packed_stream_size: usize = 512 * 1024 * 1024,
    max_kdf_cycles_power: u6 = 24,
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

pub const Error = archive_mod.Error || branch_mod.Error || codec_mod.Error || error{
    Invalid7zArchive,
    Unsupported7zFeature,
};

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    entry: types.Entry,
    branches: [4]branch_mod.Reader,
    primary: codec_mod.Codec,
    primary_output: []u8,
    primary_start: usize = 0,
    primary_len: usize = 0,
    primary_input_finished: bool = false,
    primary_done: bool = false,
    entry_start: usize,
    entry_end: usize,
    folder_size: usize,
    folder_position: usize = 0,
    entry_written: usize = 0,
    folder_crc_expected: ?u32,
    folder_crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    entry_crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    range: u32 = std.math.maxInt(u32),
    code: u32 = 0,
    probabilities: [258]u16 = @splat(probability_total / 2),
    range_initialized: bool = false,
    ip: u32,
    context: u32 = 0,
    main_byte: ?u8 = null,
    operand: [4]u8 = undefined,
    operand_start: usize = 0,
    operand_len: usize = 0,
    done: bool = false,
    last_error_name: []const u8 = "",

    pub fn init(
        allocator: std.mem.Allocator,
        source: source_mod.Source,
        streams: *const streams_mod.Streams,
        packed_data_limit: u64,
        entry: types.Entry,
        options: Options,
    ) Error!Decoder {
        const folder_index = entry.folder_index orelse return error.EntryHasNoStream;
        if (folder_index >= streams.folders.len) return error.Invalid7zArchive;
        const folder = streams.folders[folder_index];
        const bcj2_index = folder.bcj2_coder_index orelse return error.Unsupported7zFeature;
        if (folder.pack_stream_count != 4 or options.decoded_buffer_size == 0)
            return error.Invalid7zArchive;
        const folder_size = std.math.cast(usize, folder.unpack_size) orelse
            return error.OutputLimitExceeded;
        const entry_size = std.math.cast(usize, entry.size) orelse
            return error.OutputLimitExceeded;
        const entry_start = std.math.cast(usize, entry.offset_in_folder) orelse
            return error.Invalid7zArchive;
        const entry_end = std.math.add(usize, entry_start, entry_size) catch
            return error.Invalid7zArchive;
        if (entry_size > options.max_output_len or folder_size > options.max_folder_output_len)
            return error.OutputLimitExceeded;
        if (entry_end > folder_size) return error.Invalid7zArchive;

        const input = packed_input.Input.fromSource(
            source,
            packed_data_limit,
            options.max_packed_stream_size,
        );
        try input.validateStreams(streams);
        var branches: [4]branch_mod.Reader = undefined;
        var initialized: usize = 0;
        errdefer for (branches[0..initialized]) |*branch| branch.deinit();
        for (folder.bcj2_branches, 0..) |descriptor, branch_index| {
            const aes_coder = if (descriptor.aes_coder_index) |index|
                folder.coders[index]
            else
                null;
            const aes_plain_size = if (descriptor.aes_coder_index) |index|
                folder.coder_unpack_sizes[index]
            else
                null;
            branches[branch_index] = try branch_mod.Reader.init(
                allocator,
                source,
                streams,
                packed_data_limit,
                folder.pack_index + descriptor.pack_stream_offset,
                aes_coder,
                aes_plain_size,
                options.password,
                options.max_kdf_cycles_power,
                options.max_packed_stream_size,
                options.input_buffer_size,
            );
            initialized += 1;
        }

        const primary_index = folder.primaryCoderIndex() orelse
            return error.Invalid7zArchive;
        const primary_size = std.math.cast(
            usize,
            folder.coder_unpack_sizes[primary_index],
        ) orelse return error.OutputLimitExceeded;
        const side_size = std.math.add(
            usize,
            branches[1].totalPlainSize(),
            branches[2].totalPlainSize(),
        ) catch return error.IntegerOverflow;
        const calculated_size = std.math.add(usize, primary_size, side_size) catch
            return error.IntegerOverflow;
        if (calculated_size != folder_size)
            return error.Invalid7zArchive;
        var primary = try codec_mod.Codec.init(
            allocator,
            folder.coders[primary_index],
            primary_size,
            options.max_dictionary_size,
        );
        errdefer primary.deinit(allocator);
        const primary_output = try allocator.alloc(u8, options.decoded_buffer_size);
        errdefer allocator.free(primary_output);

        const bcj_coder = folder.coders[bcj2_index];
        const start_ip = if (bcj_coder.properties_len == 4)
            std.mem.readInt(u32, bcj_coder.propertyBytes()[0..4], .little)
        else
            0;
        return .{
            .allocator = allocator,
            .options = options,
            .entry = entry,
            .branches = branches,
            .primary = primary,
            .primary_output = primary_output,
            .entry_start = entry_start,
            .entry_end = entry_end,
            .folder_size = folder_size,
            .folder_crc_expected = folder.crc32,
            .ip = start_ip,
        };
    }

    pub fn deinit(self: *Decoder) void {
        for (&self.branches) |*branch| branch.deinit();
        self.primary.deinit(self.allocator);
        self.allocator.free(self.primary_output);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        var remaining: usize = 0;
        var encrypted = false;
        for (&self.branches) |*branch| {
            remaining +|= branch.packed_remaining;
            encrypted = encrypted or branch.decryptor != null;
        }
        return .{
            .folder_produced = self.folder_position,
            .entry_written = self.entry_written,
            .source_bytes_remaining = remaining,
            .buffered_codec_input = self.branches[0].available().len,
            .buffered_decoded_output = self.primary_len - self.primary_start +
                self.operand_len - self.operand_start + @intFromBool(self.main_byte != null),
            .codec_name = "bcj2",
            .encrypted = encrypted,
            .done = self.done,
            .last_error_name = self.last_error_name,
        };
    }

    pub fn step(self: *Decoder, output: []u8) Error!core.StepResult {
        return self.stepInternal(output) catch |err| {
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    fn stepInternal(self: *Decoder, output: []u8) Error!core.StepResult {
        if (self.done) return .{ .status = .done };
        var source_read: usize = 0;
        var output_written: usize = 0;
        if (!self.range_initialized) try self.initRange(&source_read);

        while (true) {
            while (self.operand_start < self.operand_len) {
                if (self.folder_position >= self.folder_size) return error.SizeMismatch;
                if (!self.emitByte(self.operand[self.operand_start], output, &output_written))
                    return result(source_read, output_written, .need_output);
                self.operand_start += 1;
            }
            self.operand_start = 0;
            self.operand_len = 0;

            if (self.folder_position == self.folder_size) {
                try self.finishStreams(&source_read);
                self.done = true;
                return result(source_read, output_written, .done);
            }

            if (self.main_byte == null) {
                try self.normalizeRange(&source_read);
                self.main_byte = (try self.nextMainByte(&source_read)) orelse
                    return error.Invalid7zArchive;
            }
            const byte = self.main_byte.?;
            if (!self.emitByte(byte, output, &output_written))
                return result(source_read, output_written, .need_output);
            self.main_byte = null;
            self.ip +%= 1;
            self.context = (self.context << 24) | byte;
            const marker = byte == 0xe8 or byte == 0xe9 or
                (@as(u8, @truncate(self.context >> 24)) == 0x0f and byte & 0xf0 == 0x80);
            if (!marker) continue;
            if (!try self.decodeDecision()) continue;

            var absolute_bytes: [4]u8 = undefined;
            const branch_index: usize = if (byte == 0xe8) 1 else 2;
            try self.branches[branch_index].readExact(&absolute_bytes, &source_read);
            const absolute = std.mem.readInt(u32, &absolute_bytes, .big);
            self.ip +%= 4;
            const relative = absolute -% self.ip;
            std.mem.writeInt(u32, &self.operand, relative, .little);
            self.operand_len = 4;
            self.context = relative >> 24;
        }
    }

    fn initRange(self: *Decoder, source_read: *usize) Error!void {
        var prefix: [5]u8 = undefined;
        try self.branches[3].readExact(&prefix, source_read);
        if (prefix[0] != 0) return error.Invalid7zArchive;
        self.code = std.mem.readInt(u32, prefix[1..5], .big);
        if (self.code == std.math.maxInt(u32)) return error.Invalid7zArchive;
        self.range_initialized = true;
    }

    fn normalizeRange(self: *Decoder, source_read: *usize) Error!void {
        if (self.range < top_value) {
            self.range <<= 8;
            self.code = (self.code << 8) | try self.branches[3].readByte(source_read);
        }
    }

    fn decodeDecision(self: *Decoder) Error!bool {
        const c = ((self.context +% 0x17) >> 6) & 1;
        const probability_index = (((0 -% c) & (self.context >> 24)) +% c +%
            ((self.context >> 5) & 1)) & 0x1ff;
        if (probability_index >= self.probabilities.len) return error.Invalid7zArchive;
        const probability = self.probabilities[probability_index];
        const bound = (self.range >> 11) * probability;
        if (self.code < bound) {
            self.range = bound;
            self.probabilities[probability_index] = @intCast(
                probability + ((probability_total - probability) >> move_bits),
            );
            return false;
        }
        self.range -= bound;
        self.code -= bound;
        self.probabilities[probability_index] = @intCast(
            probability - (probability >> move_bits),
        );
        return true;
    }

    fn nextMainByte(self: *Decoder, source_read: *usize) Error!?u8 {
        if (self.primary_start < self.primary_len) {
            const byte = self.primary_output[self.primary_start];
            self.primary_start += 1;
            return byte;
        }
        self.primary_start = 0;
        self.primary_len = 0;
        while (!self.primary_done) {
            const available = self.branches[0].available();
            const stepped = try self.primary.step(available, self.primary_output);
            try self.branches[0].consume(stepped.progress.input_read);
            if (stepped.progress.output_written != 0) {
                self.primary_len = stepped.progress.output_written;
                const byte = self.primary_output[0];
                self.primary_start = 1;
                if (stepped.status == .done) self.primary_done = true;
                return byte;
            }
            if (stepped.status == .done) {
                self.primary_done = true;
                break;
            }
            if (stepped.progress.input_read != 0) continue;
            if (available.len != 0) {
                if (self.branches[0].packed_remaining == 0) return error.TruncatedFrame;
                source_read.* = std.math.add(
                    usize,
                    source_read.*,
                    try self.branches[0].fill(),
                ) catch return error.IntegerOverflow;
                continue;
            }
            if (self.branches[0].packed_remaining != 0) {
                source_read.* = std.math.add(
                    usize,
                    source_read.*,
                    try self.branches[0].fill(),
                ) catch return error.IntegerOverflow;
                continue;
            }
            try self.branches[0].finish();
            if (!self.primary_input_finished) {
                try self.primary.finish();
                self.primary_input_finished = true;
                continue;
            }
            return error.TruncatedFrame;
        }
        return null;
    }

    fn emitByte(
        self: *Decoder,
        byte: u8,
        output: []u8,
        output_written: *usize,
    ) bool {
        if (self.folder_position >= self.entry_start and self.folder_position < self.entry_end) {
            if (output_written.* == output.len) return false;
            output[output_written.*] = byte;
            output_written.* += 1;
            self.entry_written += 1;
            self.entry_crc.update(&.{byte});
        }
        self.folder_crc.update(&.{byte});
        self.folder_position += 1;
        return true;
    }

    fn finishStreams(self: *Decoder, source_read: *usize) Error!void {
        if (try self.nextMainByte(source_read) != null) return error.SizeMismatch;
        try self.branches[0].finish();
        try self.branches[1].finish();
        try self.branches[2].finish();
        if (self.range < top_value and self.branches[3].hasRemaining()) {
            self.range <<= 8;
            self.code = (self.code << 8) | try self.branches[3].readByte(source_read);
        }
        try self.branches[3].finish();
        if (self.code != 0) return error.Invalid7zArchive;
        if (self.entry_written != self.entry_end - self.entry_start)
            return error.SizeMismatch;
        if (self.folder_crc_expected) |expected|
            if (self.folder_crc.digest() != expected) return error.ChecksumMismatch;
        if (self.entry.crc32) |expected|
            if (self.entry_crc.digest() != expected) return error.ChecksumMismatch;
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
