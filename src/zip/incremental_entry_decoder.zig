const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const deflate = @import("../deflate.zig");
const types = @import("types.zig");

pub const CompressionMethod = types.CompressionMethod;
pub const Entry = types.Entry;

pub const Error = deflate.Error || error{
    InvalidZipArchive,
    UnsupportedZipCompressionMethod,
    EncryptedZipEntry,
    ZipEntryDecoderFailed,
};

pub const Options = struct {
    max_output_len: usize = std.math.maxInt(usize),
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
        if (self.crc.digest() != self.entry.crc32)
            return error.ChecksumMismatch;
        self.phase = .done;
    }

    fn metadata(entry: Entry) EntryMetadata {
        return .{
            .method = entry.method,
            .crc32 = entry.crc32,
            .compressed_size = entry.compressed_size,
            .uncompressed_size = entry.uncompressed_size,
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
    decoder: Decoder,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, entry: Entry) (Error || std.mem.Allocator.Error)!Self {
        return initWithOptions(allocator, entry, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        entry: Entry,
        options: Options,
    ) (Error || std.mem.Allocator.Error)!Self {
        try Decoder.validateMetadata(entry, options);
        const history = try allocator.alloc(u8, Decoder.required_history_len);
        errdefer allocator.free(history);
        return .{
            .allocator = allocator,
            .history = history,
            .decoder = try Decoder.initWithOptions(entry, history, options),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.history);
        self.* = undefined;
    }

    pub fn reset(self: *Self, entry: Entry) Error!void {
        return self.decoder.reset(entry);
    }

    pub fn resetWithOptions(self: *Self, entry: Entry, options: Options) Error!void {
        return self.decoder.resetWithOptions(entry, options);
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return self.decoder.step(input, output);
    }

    pub fn finish(self: *Self) Error!void {
        return self.decoder.finish();
    }

    pub fn snapshot(self: *const Self) Decoder.Snapshot {
        return self.decoder.snapshot();
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return self.decoder.diagnostics();
    }
};

test {
    _ = @import("incremental_entry_decoder_tests.zig");
}
