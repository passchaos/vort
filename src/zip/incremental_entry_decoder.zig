const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const reader_api = @import("incremental_reader/api.zig");
const reader_codecs = @import("incremental_reader/codecs.zig");
const reader_encryption = @import("incremental_reader/encryption.zig");
const reader_pkware_strong = @import("incremental_reader/pkware_strong.zig");
const types = @import("types.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const winzip_aes = @import("vail_archive_crypto").winzip_aes;

pub const CompressionMethod = types.CompressionMethod;
pub const Entry = types.Entry;

pub const Error = deflate.Error || reader_codecs.Error || reader_encryption.Error ||
    std.mem.Allocator.Error || error{
    InvalidZipArchive,
    UnsupportedZipCompressionMethod,
    EncryptedZipEntry,
    PasswordRequired,
    ZipEntryDecoderFailed,
};

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
    verify_crc32: bool = true,
    password: ?[]const u8 = null,
    codec_limits: reader_api.Options = .{},
};

pub const Phase = enum {
    data,
    done,
    failed,
};

/// Incrementally decodes one Stored or Deflate ZIP member after its canonical
/// central-directory `Entry` has been parsed. The caller supplies exactly the
/// member's compressed payload; bytes following that payload remain
/// unconsumed when `.done` is returned.
///
/// Deflate entries require a caller-owned 32 KiB history buffer. Stored entries
/// accept an empty history slice. Use `OwnedDecoder` when allocator-owned
/// history is more convenient.
pub const Decoder = struct {
    entry: EntryMetadata,
    options: Options,
    history: []u8,
    raw: ?deflate.RawDeflateIncrementalFixedLiteralDecoder,
    phase: Phase = .data,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",

    pub const required_history_len: usize = 32 * 1024;

    const Self = @This();
    const EntryMetadata = struct {
        method: CompressionMethod,
        crc32: u32,
        compressed_size: usize,
        uncompressed_size: usize,
        pkware_strong_encryption: ?types.PkwareStrongEncryptionInfo,
    };

    pub const Snapshot = struct {
        phase: Phase,
        method: CompressionMethod,
        input_read: usize,
        output_written: usize,
        expected_input_len: usize,
        expected_output_len: usize,
        current_crc32: u32,
        expected_crc32: u32,
        last_error_name: []const u8,
    };

    pub fn init(entry: Entry, history: []u8) Error!Self {
        return initWithOptions(entry, history, .{});
    }

    pub fn initWithOptions(entry: Entry, history: []u8, options: Options) Error!Self {
        try validateEntry(entry, history, options);
        const raw = if (entry.method == .deflate)
            try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{
                .max_output_len = options.max_output_len,
                .expected_output_len = entry.uncompressed_size,
                .allow_trailing_data = true,
            }, history)
        else
            null;
        return .{
            .entry = metadata(entry),
            .options = options,
            .history = history,
            .raw = raw,
        };
    }

    /// Reuses the caller-owned history for another independent member.
    /// Validation is transactional: a rejected entry leaves the old decoder
    /// state untouched.
    pub fn reset(self: *Self, entry: Entry) Error!void {
        return self.resetWithOptions(entry, self.options);
    }

    pub fn resetWithOptions(self: *Self, entry: Entry, options: Options) Error!void {
        const replacement = try initWithOptions(entry, self.history, options);
        self.* = replacement;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .method = self.entry.method,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .expected_input_len = self.entry.compressed_size,
            .expected_output_len = self.entry.uncompressed_size,
            .current_crc32 = self.crc.digest(),
            .expected_crc32 = self.entry.crc32,
            .last_error_name = self.last_error_name,
        };
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = self.entry.uncompressed_size,
            .payload_remaining = self.entry.compressed_size -| self.total_input,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.phase),
            .recoverability_hint_name = if (self.phase == .failed) "entry_corrupt" else "none",
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .failed) return error.ZipEntryDecoderFailed;
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        return self.stepData(input, output) catch |err| {
            self.phase = .failed;
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    /// Signals that no more compressed payload bytes are available. A short
    /// member fails with `TruncatedFrame`; a completed member is idempotent.
    pub fn finish(self: *Self) Error!void {
        if (self.phase == .failed) return error.ZipEntryDecoderFailed;
        if (self.phase == .done) return;
        self.finishData() catch |err| {
            self.phase = .failed;
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    fn stepData(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return switch (self.entry.method) {
            .stored => self.stepStored(input, output),
            .deflate => self.stepDeflate(input, output),
            else => unreachable,
        };
    }

    fn stepStored(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.total_input == self.entry.compressed_size) {
            try self.complete();
            return .{ .status = .done };
        }
        if (input.len == 0) return .{ .status = .need_input };
        if (output.len == 0) return .{ .status = .need_output };

        const remaining = self.entry.compressed_size - self.total_input;
        const take = @min(remaining, @min(input.len, output.len));
        const produced = output[0..take];
        @memcpy(produced, input[0..take]);
        self.crc.update(produced);
        self.total_input += take;
        self.total_output += take;

        if (self.total_input == self.entry.compressed_size) {
            try self.complete();
            return result(take, take, .done);
        }
        return result(take, take, if (take == output.len) .need_output else .need_input);
    }

    fn stepDeflate(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        const remaining = self.entry.compressed_size - self.total_input;
        const offered = input[0..@min(input.len, remaining)];
        const decoded = try self.raw.?.step(offered, output);
        const consumed = decoded.progress.input_read;
        const written = decoded.progress.output_written;
        self.total_input = std.math.add(usize, self.total_input, consumed) catch
            return error.IntegerOverflow;
        self.total_output = std.math.add(usize, self.total_output, written) catch
            return error.IntegerOverflow;
        self.crc.update(output[0..written]);

        if (decoded.status == .done) {
            if (self.total_input != self.entry.compressed_size)
                return error.InvalidZipArchive;
            try self.complete();
            return result(consumed, written, .done);
        }
        if (self.total_input == self.entry.compressed_size and decoded.status == .need_input) {
            try self.raw.?.finish();
            return error.InvalidZipArchive;
        }
        return result(consumed, written, decoded.status);
    }

    fn finishData(self: *Self) Error!void {
        if (self.total_input != self.entry.compressed_size)
            return error.TruncatedFrame;
        if (self.entry.method == .deflate)
            try self.raw.?.finish();
        try self.complete();
    }

    fn complete(self: *Self) Error!void {
        if (self.total_input != self.entry.compressed_size)
            return error.SizeMismatch;
        if (self.total_output != self.entry.uncompressed_size)
            return error.SizeMismatch;
        if (self.options.verify_crc32 and self.crc.digest() != self.entry.crc32)
            return error.ChecksumMismatch;
        self.phase = .done;
    }

    fn metadata(entry: Entry) EntryMetadata {
        return .{
            .method = entry.method,
            .crc32 = entry.crc32,
            .compressed_size = entry.compressed_size,
            .uncompressed_size = entry.uncompressed_size,
            .pkware_strong_encryption = entry.pkware_strong_encryption,
        };
    }

    fn validateEntry(entry: Entry, history: []u8, options: Options) Error!void {
        try validateMetadata(entry, options);
        if (entry.method == .deflate and history.len < required_history_len)
            return error.OutputTooSmall;
    }

    fn validateMetadata(entry: Entry, options: Options) Error!void {
        if (entry.isEncrypted()) return error.EncryptedZipEntry;
        if (entry.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        switch (entry.method) {
            .stored => if (entry.compressed_size != entry.uncompressed_size)
                return error.InvalidZipArchive,
            .deflate => {},
            else => return error.UnsupportedZipCompressionMethod,
        }
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};

/// Allocator-owned convenience wrapper around `Decoder`. It allocates one
/// reusable 32 KiB history buffer and can reset across Stored and Deflate
/// members without further allocation.
pub const OwnedDecoder = struct {
    allocator: std.mem.Allocator,
    history: []u8,
    entry: Decoder.EntryMetadata,
    codec_expected_size: ?usize,
    options: Options,
    state: State,
    encryption: ?reader_encryption.State = null,
    phase: Phase = .data,
    total_input: usize = 0,
    codec_input: usize = 0,
    total_output: usize = 0,
    codec_done: bool = false,
    last_error_name: []const u8 = "",

    const Self = @This();

    const State = union(enum) {
        simple: Decoder,
        deflate: reader_codecs.DeflateState,
        shrink: reader_codecs.ShrinkState,
        reduce: reader_codecs.ReduceState,
        implode: reader_codecs.ImplodeState,
        deflate64: reader_codecs.Deflate64State,
        dcl_implode: reader_codecs.DclImplodeState,
        bzip2: reader_codecs.Bzip2State,
        lzma: reader_codecs.LzmaZipState,
        ppmd: reader_codecs.PpmdZipState,
        xz: reader_codecs.XzState,
        zstd: reader_codecs.ZstdState,

        fn deinit(self: *State) void {
            switch (self.*) {
                .simple => {},
                .deflate => |*state| state.deinit(),
                .shrink => |*state| state.deinit(),
                .reduce => |*state| state.deinit(),
                .implode => |*state| state.deinit(),
                .deflate64 => |*state| state.deinit(),
                .dcl_implode => |*state| state.deinit(),
                .bzip2 => |*state| state.deinit(),
                .lzma => |*state| state.deinit(),
                .ppmd => |*state| state.deinit(),
                .xz => |*state| state.deinit(),
                .zstd => |*state| state.deinit(),
            }
        }

        fn step(self: *State, input: []const u8, output: []u8) Error!core.StepResult {
            return switch (self.*) {
                inline else => |*state| state.step(input, output),
            };
        }

        fn actualCompressedSize(self: *const State) Error!usize {
            return switch (self.*) {
                .simple => |*state| state.snapshot().input_read,
                inline else => |*state| state.actualCompressedSize(),
            };
        }

        fn outputSize(self: *const State) usize {
            return switch (self.*) {
                .simple => |*state| state.snapshot().output_written,
                inline else => |*state| state.outputSize(),
            };
        }

        fn crc32(self: *const State) u32 {
            return switch (self.*) {
                .simple => |*state| state.snapshot().current_crc32,
                inline else => |*state| state.crc32(),
            };
        }

        fn setExpectedCompressedSize(self: *State, size: usize) void {
            switch (self.*) {
                .simple => {},
                .deflate => {},
                .shrink => |*state| state.expected_compressed_size = size,
                .reduce => |*state| state.expected_compressed_size = size,
                .implode => |*state| state.expected_compressed_size = size,
                .deflate64 => |*state| state.expected_compressed_size = size,
                .dcl_implode => |*state| state.expected_compressed_size = size,
                .bzip2 => |*state| state.expected_compressed_size = size,
                .lzma => |*state| state.expected_compressed_size = size,
                .ppmd => |*state| state.expected_compressed_size = size,
                .xz => |*state| state.expected_compressed_size = size,
                .zstd => |*state| state.expected_compressed_size = size,
            }
        }
    };

    const Prepared = struct {
        codec_entry: Entry,
        codec_expected_size: ?usize,
        options: Options,
        encryption: ?reader_encryption.State = null,
    };

    fn prepareEntry(entry: Entry, options: Options) Error!Prepared {
        if (!entry.isEncrypted()) {
            try validateOwnedMetadata(entry, options);
            return .{
                .codec_entry = entry,
                .codec_expected_size = entry.compressed_size,
                .options = options,
            };
        }
        const password = options.password orelse return error.PasswordRequired;
        var codec_entry = entry;
        codec_entry.flags &= ~(@as(u16, 1) | (@as(u16, 1) << 6));
        var prepared_options = options;
        if (entry.isPkwareStrongEncrypted()) {
            const expected_size = if (entry.method == .stored)
                entry.uncompressed_size
            else
                null;
            codec_entry.compressed_size = expected_size orelse 0;
            try validateOwnedMetadata(codec_entry, prepared_options);
            return .{
                .codec_entry = codec_entry,
                .codec_expected_size = expected_size,
                .options = prepared_options,
                .encryption = reader_encryption.State.initPkwareStrong(
                    entry.compressed_size,
                    null,
                ),
            };
        }
        if (entry.winzip_aes) |aes_info| {
            const overhead = aes_info.strength.overhead();
            if (entry.compressed_size < overhead) return error.InvalidZipArchive;
            codec_entry.compressed_size = entry.compressed_size - overhead;
            if (aes_info.version == .ae2) prepared_options.verify_crc32 = false;
            try validateOwnedMetadata(codec_entry, prepared_options);
            return .{
                .codec_entry = codec_entry,
                .codec_expected_size = codec_entry.compressed_size,
                .options = prepared_options,
                .encryption = reader_encryption.State.initWinZipAes(aes_info),
            };
        }
        if (entry.compressed_size < traditional_encryption.header_len)
            return error.InvalidZipArchive;
        codec_entry.compressed_size = entry.compressed_size - traditional_encryption.header_len;
        try validateOwnedMetadata(codec_entry, prepared_options);
        return .{
            .codec_entry = codec_entry,
            .codec_expected_size = codec_entry.compressed_size,
            .options = prepared_options,
            .encryption = reader_encryption.State.initTraditional(
                password,
                if (entry.flags & (1 << 3) != 0)
                    @truncate(entry.modified.time >> 8)
                else
                    @truncate(entry.crc32 >> 24),
            ),
        };
    }

    pub fn init(allocator: std.mem.Allocator, entry: Entry) (Error || std.mem.Allocator.Error)!Self {
        return initWithOptions(allocator, entry, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        entry: Entry,
        options: Options,
    ) (Error || std.mem.Allocator.Error)!Self {
        var prepared = try prepareEntry(entry, options);
        errdefer if (prepared.encryption) |*encryption| encryption.deinit(allocator);
        const history = try allocator.alloc(u8, Decoder.required_history_len);
        errdefer allocator.free(history);
        const state = try initState(
            allocator,
            prepared.codec_entry,
            prepared.codec_expected_size,
            history,
            prepared.options,
        );
        errdefer {
            var cleanup = state;
            cleanup.deinit();
        }
        return .{
            .allocator = allocator,
            .history = history,
            .entry = Decoder.metadata(entry),
            .codec_expected_size = prepared.codec_expected_size,
            .options = prepared.options,
            .state = state,
            .encryption = prepared.encryption,
        };
    }

    pub fn deinit(self: *Self) void {
        self.state.deinit();
        if (self.encryption) |*encryption| encryption.deinit(self.allocator);
        self.allocator.free(self.history);
        self.* = undefined;
    }

    pub fn reset(self: *Self, entry: Entry) Error!void {
        return self.resetWithOptions(entry, self.options);
    }

    pub fn resetWithOptions(self: *Self, entry: Entry, options: Options) Error!void {
        var prepared = try prepareEntry(entry, options);
        errdefer if (prepared.encryption) |*encryption| encryption.deinit(self.allocator);
        const replacement = try initState(
            self.allocator,
            prepared.codec_entry,
            prepared.codec_expected_size,
            self.history,
            prepared.options,
        );
        self.state.deinit();
        if (self.encryption) |*encryption| encryption.deinit(self.allocator);
        self.entry = Decoder.metadata(entry);
        self.codec_expected_size = prepared.codec_expected_size;
        self.options = prepared.options;
        self.state = replacement;
        self.encryption = prepared.encryption;
        self.phase = .data;
        self.total_input = 0;
        self.codec_input = 0;
        self.total_output = 0;
        self.codec_done = false;
        self.last_error_name = "";
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .failed) return error.ZipEntryDecoderFailed;
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        return self.stepData(input, output) catch |err| {
            self.phase = .failed;
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    pub fn finish(self: *Self) Error!void {
        if (self.phase == .failed) return error.ZipEntryDecoderFailed;
        if (self.phase == .done) return;
        if (self.total_input != self.entry.compressed_size) {
            self.phase = .failed;
            self.last_error_name = @errorName(error.TruncatedFrame);
            return error.TruncatedFrame;
        }
        self.phase = .failed;
        self.last_error_name = @errorName(error.TruncatedFrame);
        return error.TruncatedFrame;
    }

    pub fn snapshot(self: *const Self) Decoder.Snapshot {
        return .{
            .phase = self.phase,
            .method = self.entry.method,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .expected_input_len = self.entry.compressed_size,
            .expected_output_len = self.entry.uncompressed_size,
            .current_crc32 = self.state.crc32(),
            .expected_crc32 = self.entry.crc32,
            .last_error_name = self.last_error_name,
        };
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = self.entry.uncompressed_size,
            .payload_remaining = self.entry.compressed_size -| self.total_input,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.phase),
            .recoverability_hint_name = if (self.phase == .failed) "entry_corrupt" else "none",
        };
    }

    fn stepData(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.encryption) |*encryption|
            return switch (encryption.*) {
                .traditional => |*state| self.stepTraditional(state, input, output),
                .winzip_aes => |*state| self.stepWinZipAes(state, input, output),
                .pkware_strong => |*state| self.stepPkwareStrong(state, input, output),
            };
        const decoded = try self.stepCodec(input, output);
        self.total_input = std.math.add(usize, self.total_input, decoded.progress.input_read) catch
            return error.IntegerOverflow;
        if (self.codec_done) {
            try self.complete();
            return .{ .progress = decoded.progress, .status = .done };
        }
        return decoded;
    }

    fn stepCodec(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        const remaining = if (self.codec_expected_size) |expected|
            expected - self.codec_input
        else
            input.len;
        const offered = input[0..@min(input.len, remaining)];
        const decoded = try self.state.step(offered, output);
        if (decoded.progress.input_read > offered.len or
            decoded.progress.output_written > output.len)
            return error.InvalidZipArchive;
        self.codec_input = std.math.add(usize, self.codec_input, decoded.progress.input_read) catch
            return error.IntegerOverflow;
        self.total_output = std.math.add(usize, self.total_output, decoded.progress.output_written) catch
            return error.IntegerOverflow;
        if (decoded.status == .done) {
            self.codec_done = true;
            return .{ .progress = decoded.progress, .status = .done };
        }
        if (self.codec_expected_size != null and
            self.codec_input == self.codec_expected_size.? and
            decoded.status == .need_input)
        {
            const drained = try self.state.step(&.{}, output[decoded.progress.output_written..]);
            if (drained.progress.input_read != 0 or
                drained.progress.output_written > output.len - decoded.progress.output_written)
                return error.InvalidZipArchive;
            self.total_output = std.math.add(
                usize,
                self.total_output,
                drained.progress.output_written,
            ) catch return error.IntegerOverflow;
            var progress = decoded.progress;
            progress.output_written += drained.progress.output_written;
            if (drained.status == .done) {
                self.codec_done = true;
                return .{ .progress = progress, .status = .done };
            }
            return .{ .progress = progress, .status = drained.status };
        }
        return decoded;
    }

    fn stepTraditional(
        self: *Self,
        encryption: *reader_encryption.State.TraditionalState,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        const codec_expected_size = self.codec_expected_size orelse
            return error.InvalidZipArchive;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (encryption.header_len < traditional_encryption.header_len and
            input_read < input.len)
        {
            encryption.header[encryption.header_len] = encryption.cipher.decryptByte(input[input_read]);
            encryption.header_len += 1;
            input_read += 1;
            self.total_input = std.math.add(usize, self.total_input, 1) catch
                return error.IntegerOverflow;
        }
        if (encryption.header_len != traditional_encryption.header_len)
            return result(input_read, output_written, .need_input);
        if (encryption.header[traditional_encryption.header_random_len] != encryption.check_byte)
            return error.InvalidZipPassword;

        while (!self.codec_done) {
            if (self.codec_input == codec_expected_size) {
                const decoded = try self.stepCodec(&.{}, output[output_written..]);
                output_written += decoded.progress.output_written;
                if (self.codec_done) break;
                if (decoded.status != .need_output) return error.TruncatedFrame;
                return result(input_read, output_written, .need_output);
            }
            if (input_read == input.len)
                return result(input_read, output_written, .need_input);
            const take = @min(
                @as(usize, 256),
                @min(input.len - input_read, codec_expected_size - self.codec_input),
            );
            const raw = input[input_read..][0..take];
            var plain: [256]u8 = undefined;
            defer std.crypto.secureZero(u8, &plain);
            var trial = encryption.cipher;
            defer trial.deinit();
            trial.decrypt(raw, plain[0..take]);
            const decoded = try self.stepCodec(plain[0..take], output[output_written..]);
            var committed = encryption.cipher;
            defer committed.deinit();
            var discarded: [256]u8 = undefined;
            defer std.crypto.secureZero(u8, &discarded);
            committed.decrypt(raw[0..decoded.progress.input_read], discarded[0..decoded.progress.input_read]);
            encryption.cipher.deinit();
            encryption.cipher = committed;
            input_read += decoded.progress.input_read;
            self.total_input = std.math.add(usize, self.total_input, decoded.progress.input_read) catch
                return error.IntegerOverflow;
            output_written += decoded.progress.output_written;
            if (decoded.status == .need_output)
                return result(input_read, output_written, .need_output);
            if (decoded.progress.input_read == 0 and decoded.progress.output_written == 0)
                return error.InvalidZipArchive;
        }
        if (self.total_input != self.entry.compressed_size) return error.InvalidZipArchive;
        try self.complete();
        return result(input_read, output_written, .done);
    }

    fn stepWinZipAes(
        self: *Self,
        encryption: *reader_encryption.State.WinZipAesState,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        const codec_expected_size = self.codec_expected_size orelse
            return error.InvalidZipArchive;
        const password = self.options.password orelse return error.PasswordRequired;
        const salt_len = encryption.info.strength.saltLen();
        const header_len = salt_len + winzip_aes.password_verifier_len;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (encryption.header_len < header_len and input_read < input.len) {
            encryption.header[encryption.header_len] = input[input_read];
            encryption.header_len += 1;
            input_read += 1;
            self.total_input = std.math.add(usize, self.total_input, 1) catch
                return error.IntegerOverflow;
        }
        if (encryption.header_len != header_len)
            return result(input_read, output_written, .need_input);
        if (encryption.cipher == null) {
            var cipher = try winzip_aes.Cipher.init(
                password,
                encryption.header[0..salt_len],
                encryption.info.strength,
            );
            errdefer cipher.deinit();
            if (!cipher.verifyPassword(
                encryption.header[salt_len..][0..winzip_aes.password_verifier_len].*,
            )) return error.InvalidZipPassword;
            encryption.cipher = cipher;
        }

        while (!self.codec_done) {
            if (self.codec_input == codec_expected_size) {
                const decoded = try self.stepCodec(&.{}, output[output_written..]);
                output_written += decoded.progress.output_written;
                if (self.codec_done) break;
                if (decoded.status != .need_output) return error.TruncatedFrame;
                return result(input_read, output_written, .need_output);
            }
            if (input_read == input.len)
                return result(input_read, output_written, .need_input);
            const take = @min(
                @as(usize, 256),
                @min(input.len - input_read, codec_expected_size - self.codec_input),
            );
            const raw = input[input_read..][0..take];
            var plain: [256]u8 = undefined;
            defer std.crypto.secureZero(u8, &plain);
            var trial = encryption.cipher.?;
            defer trial.deinit();
            trial.decrypt(raw, plain[0..take]);
            const decoded = try self.stepCodec(plain[0..take], output[output_written..]);
            var committed = encryption.cipher.?;
            defer committed.deinit();
            var discarded: [256]u8 = undefined;
            defer std.crypto.secureZero(u8, &discarded);
            committed.decrypt(raw[0..decoded.progress.input_read], discarded[0..decoded.progress.input_read]);
            encryption.cipher.?.deinit();
            encryption.cipher = committed;
            input_read += decoded.progress.input_read;
            self.total_input = std.math.add(usize, self.total_input, decoded.progress.input_read) catch
                return error.IntegerOverflow;
            output_written += decoded.progress.output_written;
            if (decoded.status == .need_output)
                return result(input_read, output_written, .need_output);
            if (decoded.progress.input_read == 0 and decoded.progress.output_written == 0)
                return error.InvalidZipArchive;
        }

        while (encryption.authentication_len < winzip_aes.authentication_code_len and
            input_read < input.len)
        {
            encryption.authentication[encryption.authentication_len] = input[input_read];
            encryption.authentication_len += 1;
            input_read += 1;
            self.total_input = std.math.add(usize, self.total_input, 1) catch
                return error.IntegerOverflow;
        }
        if (encryption.authentication_len != winzip_aes.authentication_code_len)
            return result(input_read, output_written, .need_input);
        if (!encryption.cipher.?.verifyAuthenticationCode(encryption.authentication))
            return error.InvalidAuthenticationCode;
        if (self.total_input != self.entry.compressed_size) return error.InvalidZipArchive;
        try self.complete();
        return result(input_read, output_written, .done);
    }

    fn stepPkwareStrong(
        self: *Self,
        encryption: *reader_pkware_strong.State,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        const password = self.options.password orelse return error.PasswordRequired;
        var input_read: usize = 0;
        var output_written: usize = 0;
        if (!encryption.ready()) {
            const consumed = try encryption.feedHeader(
                self.allocator,
                input,
                self.options.codec_limits.max_control_record_size,
                password,
                self.entry.crc32,
                self.entry.uncompressed_size,
            );
            input_read += consumed;
            self.total_input = std.math.add(usize, self.total_input, consumed) catch
                return error.IntegerOverflow;
            if (!encryption.ready()) return result(input_read, output_written, .need_input);
            if (self.entry.pkware_strong_encryption) |expected|
                if (encryption.info == null or encryption.info.?.strength != expected.strength)
                    return error.InvalidZipArchive;
        }

        while (true) {
            if (encryption.plaintext_pos < encryption.plaintext_len) {
                if (self.codec_done) return error.InvalidZipArchive;
                const decoded = try self.stepCodec(
                    encryption.plaintext[encryption.plaintext_pos..encryption.plaintext_len],
                    output[output_written..],
                );
                encryption.plaintext_pos += decoded.progress.input_read;
                output_written += decoded.progress.output_written;
                if (encryption.plaintext_pos == encryption.plaintext_len) {
                    std.crypto.secureZero(u8, &encryption.plaintext);
                    encryption.plaintext_pos = 0;
                    encryption.plaintext_len = 0;
                }
                if (decoded.status == .need_output)
                    return result(input_read, output_written, .need_output);
                if (encryption.plaintext_pos < encryption.plaintext_len)
                    return error.InvalidZipArchive;
                continue;
            }

            if (encryption.decrypt_done) {
                if (self.codec_expected_size == null) {
                    self.codec_expected_size = encryption.decrypted_size;
                    self.state.setExpectedCompressedSize(encryption.decrypted_size);
                }
                if (self.codec_input != self.codec_expected_size.?)
                    return error.SizeMismatch;
                if (!self.codec_done) {
                    const decoded = try self.stepCodec(&.{}, output[output_written..]);
                    output_written += decoded.progress.output_written;
                    if (decoded.status == .need_output)
                        return result(input_read, output_written, .need_output);
                    if (!self.codec_done) return error.TruncatedFrame;
                }
                if (self.total_input != self.entry.compressed_size)
                    return error.InvalidZipArchive;
                try self.complete();
                return result(input_read, output_written, .done);
            }

            const remaining = try encryption.remainingKnownCiphertext();
            if (remaining != 0) {
                if (input_read == input.len)
                    return result(input_read, output_written, .need_input);
                const take = @min(
                    @as(usize, 256),
                    @min(input.len - input_read, remaining),
                );
                const decrypted = try encryption.decryptor.?.update(
                    input[input_read..][0..take],
                    &encryption.plaintext,
                );
                if (decrypted.input_read > take or
                    decrypted.output_written > encryption.plaintext.len)
                    return error.InvalidZipArchive;
                input_read += decrypted.input_read;
                self.total_input = std.math.add(
                    usize,
                    self.total_input,
                    decrypted.input_read,
                ) catch return error.IntegerOverflow;
                encryption.ciphertext_consumed = std.math.add(
                    usize,
                    encryption.ciphertext_consumed,
                    decrypted.input_read,
                ) catch return error.IntegerOverflow;
                encryption.ciphertext_remaining.? -= decrypted.input_read;
                encryption.decrypted_size = std.math.add(
                    usize,
                    encryption.decrypted_size,
                    decrypted.output_written,
                ) catch return error.IntegerOverflow;
                encryption.plaintext_pos = 0;
                encryption.plaintext_len = decrypted.output_written;
                if (decrypted.input_read == 0 and decrypted.output_written == 0)
                    return error.InvalidZipArchive;
                continue;
            }

            const decrypted = try encryption.decryptor.?.finish(&encryption.plaintext);
            if (decrypted.input_read != 0 or
                decrypted.output_written > encryption.plaintext.len)
                return error.InvalidZipArchive;
            encryption.decrypted_size = std.math.add(
                usize,
                encryption.decrypted_size,
                decrypted.output_written,
            ) catch return error.IntegerOverflow;
            encryption.plaintext_pos = 0;
            encryption.plaintext_len = decrypted.output_written;
            if (decrypted.status == .done) encryption.decrypt_done = true;
            if (decrypted.status == .need_input) return error.TruncatedFrame;
        }
    }

    fn complete(self: *Self) Error!void {
        if (self.total_input != self.entry.compressed_size or
            self.codec_input != (self.codec_expected_size orelse return error.InvalidZipArchive) or
            try self.state.actualCompressedSize() != self.codec_expected_size.? or
            self.total_output != self.entry.uncompressed_size or
            self.state.outputSize() != self.entry.uncompressed_size)
            return error.SizeMismatch;
        if (self.options.verify_crc32 and self.state.crc32() != self.entry.crc32)
            return error.ChecksumMismatch;
        self.phase = .done;
    }

    fn initState(
        allocator: std.mem.Allocator,
        entry: Entry,
        expected_compressed_size: ?usize,
        history: []u8,
        options: Options,
    ) Error!State {
        try validateOwnedMetadata(entry, options);
        const limit = options.max_output_len;
        const reader_options = options.codec_limits;
        return switch (entry.method) {
            .stored => .{ .simple = try Decoder.initWithOptions(
                entry,
                history,
                options,
            ) },
            .deflate => if (expected_compressed_size != null)
                .{ .simple = try Decoder.initWithOptions(entry, history, options) }
            else
                .{ .deflate = try reader_codecs.DeflateState.init(limit, history, null) },
            .shrink => .{ .shrink = try reader_codecs.ShrinkState.init(
                allocator,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
                0,
                0,
                options.verify_crc32,
            ) },
            .reduce_1, .reduce_2, .reduce_3, .reduce_4 => .{ .reduce = try reader_codecs.ReduceState.init(
                allocator,
                reduceFactor(entry.method).?,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
                0,
                0,
                options.verify_crc32,
            ) },
            .implode => .{ .implode = try reader_codecs.ImplodeState.init(
                allocator,
                entry.flags,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
                0,
                0,
                options.verify_crc32,
            ) },
            .deflate64 => .{ .deflate64 = try reader_codecs.Deflate64State.init(
                allocator,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            .dcl_implode => .{ .dcl_implode = reader_codecs.DclImplodeState.init(
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            .bzip2 => .{ .bzip2 = reader_codecs.Bzip2State.init(
                allocator,
                reader_options,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            .lzma => .{ .lzma = try reader_codecs.LzmaZipState.init(
                allocator,
                reader_options,
                limit,
                entry.flags,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            .ppmd => .{ .ppmd = reader_codecs.PpmdZipState.init(
                allocator,
                reader_options,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            .xz => .{ .xz = reader_codecs.XzState.init(
                allocator,
                reader_options,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            .zstandard_legacy, .zstandard => .{ .zstd = reader_codecs.ZstdState.init(
                allocator,
                reader_options,
                limit,
                expected_compressed_size,
                entry.uncompressed_size,
                null,
            ) },
            else => error.UnsupportedZipCompressionMethod,
        };
    }

    fn validateOwnedMetadata(entry: Entry, options: Options) Error!void {
        if (entry.isEncrypted()) return error.EncryptedZipEntry;
        if (entry.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        switch (entry.method) {
            .stored => if (entry.compressed_size != entry.uncompressed_size)
                return error.InvalidZipArchive,
            .shrink,
            .reduce_1,
            .reduce_2,
            .reduce_3,
            .reduce_4,
            .implode,
            .deflate,
            .deflate64,
            .dcl_implode,
            .bzip2,
            .lzma,
            .zstandard_legacy,
            .zstandard,
            .xz,
            .ppmd,
            => {},
            else => return error.UnsupportedZipCompressionMethod,
        }
    }

    fn reduceFactor(method: CompressionMethod) ?reader_codecs.ReduceFactor {
        return switch (method) {
            .reduce_1 => .factor_1,
            .reduce_2 => .factor_2,
            .reduce_3 => .factor_3,
            .reduce_4 => .factor_4,
            else => null,
        };
    }

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
};

test {
    _ = @import("incremental_entry_decoder_tests.zig");
}
