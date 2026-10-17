//! Chunk-bounded raw LZMA2 decoder for containers that carry properties and
//! output size out of band (notably 7z).

const std = @import("std");
const core = @import("../core.zig");
const lzma_decoder = @import("../lzma/decoder.zig");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .control,
    control: u8 = 0,
    header: [5]u8 = undefined,
    header_len: usize = 0,
    header_needed: usize = 0,
    uncompressed_remaining: usize = 0,
    chunk_unpacked_size: usize = 0,
    compressed: std.ArrayList(u8) = .empty,
    compressed_expected: usize = 0,
    compressed_offset: usize = 0,
    lzma: ?std.compress.lzma.Decode = null,
    range_decoder: ?std.compress.lzma.RangeDecoder = null,
    dictionary: lzma_decoder.CircularBuffer,
    chunk_dictionary_end: usize = 0,
    staging: std.Io.Writer.Allocating,
    staging_offset: usize = 0,
    decoded_total: usize = 0,
    output_written: usize = 0,
    input_finished: bool = false,
    dictionary_initialized: bool = false,
    properties_defined: bool = false,
    state_initialized: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .control,

    pub const Error = core.Error || lzma_decoder.Error || std.mem.Allocator.Error || error{
        InvalidLzma2Stream,
    };

    pub const Options = struct {
        dictionary_property: u8,
        max_dictionary_size: usize = std.math.maxInt(usize),
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
    };

    pub const Phase = enum {
        control,
        header,
        uncompressed,
        compressed_input,
        compressed_decode,
        output,
        done,
    };

    pub const Snapshot = struct {
        phase: Phase,
        decoded_total: usize,
        output_written: usize,
        buffered_compressed_bytes: usize,
        pending_output: usize,
        dictionary_size: usize,
        retained_dictionary_capacity: usize,
        retained_compressed_capacity: usize,
        retained_output_capacity: usize,
        input_finished: bool,
        properties_defined: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!Decoder {
        const dictionary_size_u64 = try dictionarySizeFromProperty(options.dictionary_property);
        if (dictionary_size_u64 > options.max_dictionary_size)
            return error.OutputLimitExceeded;
        const dictionary_size = std.math.cast(usize, dictionary_size_u64) orelse
            return error.OutputLimitExceeded;
        if (options.expected_output_len) |expected|
            if (expected > options.max_output_len) return error.OutputLimitExceeded;
        return .{
            .allocator = allocator,
            .options = options,
            .dictionary = lzma_decoder.CircularBuffer.init(
                dictionary_size,
                options.max_output_len,
            ),
            .staging = std.Io.Writer.Allocating.init(allocator),
        };
    }

    pub fn deinit(self: *Decoder) void {
        if (self.lzma) |*decoder| decoder.deinit(self.allocator);
        self.dictionary.deinit(self.allocator);
        self.staging.deinit();
        self.compressed.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .decoded_total = self.decoded_total,
            .output_written = self.output_written,
            .buffered_compressed_bytes = self.compressed.items.len,
            .pending_output = self.staging.writer.buffered().len - self.staging_offset,
            .dictionary_size = self.dictionary.dictionary_size,
            .retained_dictionary_capacity = self.dictionary.bytes.capacity,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_output_capacity = self.staging.writer.buffer.len,
            .input_finished = self.input_finished,
            .properties_defined = self.properties_defined,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .output_written = snap.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0)
                ""
            else
                @tagName(snap.last_error_phase),
            .recoverability_hint_name = if (std.mem.eql(
                u8,
                snap.last_error_name,
                @errorName(error.TruncatedFrame),
            ))
                "truncated_input"
            else if (std.mem.eql(
                u8,
                snap.last_error_name,
                @errorName(error.OutputLimitExceeded),
            ))
                "raise_output_or_dictionary_limit"
            else if (snap.last_error_name.len == 0)
                "none"
            else
                "payload_corrupt",
        };
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepInternal(input, output) catch |err| {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            return err;
        };
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .control => {
                if (input_read == input.len) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                self.control = input[input_read];
                input_read += 1;
                if (self.control == 0) {
                    if (self.options.expected_output_len) |expected|
                        if (self.decoded_total != expected) return error.SizeMismatch;
                    if (input_read != input.len) return error.TrailingData;
                    self.phase = .done;
                    return result(input_read, output_written, .done);
                }
                self.header_len = 0;
                self.header_needed = if (self.control <= 2)
                    2
                else if ((self.control >> 5) & 3 >= 2)
                    5
                else
                    4;
                if (self.control > 2 and self.control & 0x80 == 0)
                    return error.InvalidLzma2Stream;
                self.phase = .header;
            },
            .header => {
                const take = @min(
                    self.header_needed - self.header_len,
                    input.len - input_read,
                );
                @memcpy(
                    self.header[self.header_len..][0..take],
                    input[input_read..][0..take],
                );
                self.header_len += take;
                input_read += take;
                if (self.header_len != self.header_needed) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                if (self.control <= 2) {
                    self.uncompressed_remaining =
                        @as(usize, std.mem.readInt(u16, self.header[0..2], .big)) + 1;
                    try self.reserveDecoded(self.uncompressed_remaining);
                    if (self.control == 1) {
                        self.dictionary_initialized = true;
                        self.resetDictionary();
                    } else if (!self.dictionary_initialized) {
                        return error.InvalidLzma2Stream;
                    }
                    self.state_initialized = false;
                    self.phase = .uncompressed;
                } else {
                    self.chunk_unpacked_size = ((@as(usize, self.control & 0x1f) << 16) |
                        @as(usize, std.mem.readInt(u16, self.header[0..2], .big))) + 1;
                    self.compressed_expected =
                        @as(usize, std.mem.readInt(u16, self.header[2..4], .big)) + 1;
                    const reset_mode = (self.control >> 5) & 3;
                    if (reset_mode == 3) self.dictionary_initialized = true;
                    if (!self.dictionary_initialized) return error.InvalidLzma2Stream;
                    if (reset_mode >= 2) self.properties_defined = true;
                    if (!self.properties_defined) return error.InvalidLzma2Stream;
                    if (reset_mode >= 1) {
                        self.state_initialized = true;
                    } else if (!self.state_initialized) {
                        return error.InvalidLzma2Stream;
                    }
                    try self.reserveDecoded(self.chunk_unpacked_size);
                    self.compressed.clearRetainingCapacity();
                    self.compressed_offset = 0;
                    self.phase = .compressed_input;
                }
            },
            .uncompressed => {
                if (self.uncompressed_remaining == 0) {
                    self.phase = .control;
                    continue;
                }
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                if (input_read == input.len) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                const take = @min(
                    self.uncompressed_remaining,
                    @min(input.len - input_read, output.len - output_written),
                );
                for (input[input_read..][0..take]) |byte| {
                    try self.recordUncompressed(byte);
                    output[output_written] = byte;
                    output_written += 1;
                }
                input_read += take;
                self.uncompressed_remaining -= take;
                self.decoded_total += take;
                self.output_written += take;
            },
            .compressed_input => {
                const take = @min(
                    self.compressed_expected - self.compressed.items.len,
                    input.len - input_read,
                );
                try self.compressed.appendSlice(
                    self.allocator,
                    input[input_read..][0..take],
                );
                input_read += take;
                if (self.compressed.items.len != self.compressed_expected) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.prepareCompressedChunk();
                self.phase = .compressed_decode;
            },
            .compressed_decode => {
                if (self.dictionary.len == self.chunk_dictionary_end) {
                    if (self.compressed_offset != self.compressed.items.len)
                        return error.SizeMismatch;
                    self.compressed.clearRetainingCapacity();
                    self.compressed_offset = 0;
                    self.range_decoder = null;
                    self.phase = .control;
                    continue;
                }
                self.staging.clearRetainingCapacity();
                self.staging_offset = 0;
                var reader: std.Io.Reader = .fixed(
                    self.compressed.items[self.compressed_offset..],
                );
                var bytes_read: u64 = 0;
                const status = (&self.lzma.?).process(
                    &reader,
                    &self.staging,
                    &self.dictionary,
                    &self.range_decoder.?,
                    &bytes_read,
                ) catch |err| return mapProcessError(err);
                self.compressed_offset += reader.seek;
                if (status == .finished) return error.InvalidLzma2Stream;
                if (self.dictionary.len > self.chunk_dictionary_end)
                    return error.SizeMismatch;
                const staged = self.staging.writer.buffered().len;
                if (staged == 0) return error.InvalidLzma2Stream;
                self.decoded_total = std.math.add(usize, self.decoded_total, staged) catch
                    return error.IntegerOverflow;
                if (self.decoded_total > self.options.max_output_len)
                    return error.OutputLimitExceeded;
                self.phase = .output;
            },
            .output => {
                const staged = self.staging.writer.buffered();
                const remaining = staged[self.staging_offset..];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                output_written += take;
                self.output_written += take;
                self.staging_offset += take;
                if (self.staging_offset != staged.len)
                    return result(input_read, output_written, .need_output);
                self.staging.clearRetainingCapacity();
                self.staging_offset = 0;
                self.phase = .compressed_decode;
            },
            .done => unreachable,
        };
    }

    fn reserveDecoded(self: *const Decoder, additional: usize) Error!void {
        const next = std.math.add(usize, self.decoded_total, additional) catch
            return error.OutputLimitExceeded;
        if (next > self.options.max_output_len) return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (next > expected) return error.SizeMismatch;
    }

    fn resetDictionary(self: *Decoder) void {
        self.dictionary.bytes.clearRetainingCapacity();
        self.dictionary.cursor = 0;
        self.dictionary.len = 0;
        self.dictionary.output_limit = self.options.max_output_len -| self.decoded_total;
    }

    fn recordUncompressed(self: *Decoder, byte: u8) Error!void {
        if (self.dictionary.len >= self.dictionary.output_limit)
            return error.OutputLimitExceeded;
        if (self.dictionary.cursor < self.dictionary.bytes.items.len) {
            self.dictionary.bytes.items[self.dictionary.cursor] = byte;
        } else {
            try self.dictionary.bytes.append(self.allocator, byte);
        }
        self.dictionary.cursor += 1;
        if (self.dictionary.cursor == self.dictionary.dictionary_size)
            self.dictionary.cursor = 0;
        self.dictionary.len += 1;
    }

    fn prepareCompressedChunk(self: *Decoder) Error!void {
        const reset_mode = (self.control >> 5) & 3;
        if (reset_mode == 3) self.resetDictionary();

        var properties: ?std.compress.lzma.Decode.Properties = null;
        if (reset_mode >= 2) {
            properties = try parseProperties(self.header[4]);
            self.properties_defined = true;
        } else if (!self.properties_defined) {
            return error.InvalidLzma2Stream;
        }

        if (reset_mode != 0) {
            const new_properties = properties orelse if (self.lzma) |decoder|
                decoder.properties
            else
                return error.InvalidLzma2Stream;
            try self.resetLzmaState(new_properties);
        } else if (self.lzma == null) {
            return error.InvalidLzma2Stream;
        }

        if (self.compressed.items.len < 5) return error.InvalidLzma2Stream;
        var reader: std.Io.Reader = .fixed(self.compressed.items);
        self.range_decoder = std.compress.lzma.RangeDecoder.init(&reader) catch |err|
            return mapProcessError(err);
        self.compressed_offset = reader.seek;
        self.chunk_dictionary_end = std.math.add(
            usize,
            self.dictionary.len,
            self.chunk_unpacked_size,
        ) catch return error.IntegerOverflow;
    }

    fn resetLzmaState(
        self: *Decoder,
        properties: std.compress.lzma.Decode.Properties,
    ) Error!void {
        if (self.lzma) |*decoder| {
            if (decoder.properties.lc + decoder.properties.lp == properties.lc + properties.lp) {
                decoder.resetState(self.allocator, properties) catch |err|
                    return mapProcessError(err);
                return;
            }
            const replacement = std.compress.lzma.Decode.init(self.allocator, properties) catch |err|
                return mapProcessError(err);
            decoder.deinit(self.allocator);
            self.lzma = replacement;
            return;
        }
        self.lzma = std.compress.lzma.Decode.init(self.allocator, properties) catch |err|
            return mapProcessError(err);
    }
};

pub fn dictionarySizeFromProperty(property: u8) Decoder.Error!u64 {
    if (property > 40) return error.InvalidLzma2Stream;
    if (property == 40) return std.math.maxInt(u32);
    return @as(u64, 2 | (property & 1)) << @intCast(property / 2 + 11);
}

fn parseProperties(encoded: u8) Decoder.Error!std.compress.lzma.Decode.Properties {
    if (encoded >= 225) return error.InvalidLzma2Stream;
    const lc: u4 = @intCast(encoded % 9);
    const remainder = encoded / 9;
    const lp: u3 = @intCast(remainder % 5);
    const pb: u3 = @intCast(remainder / 5);
    if (lc + lp > 4) return error.InvalidLzma2Stream;
    return .{ .lc = lc, .lp = lp, .pb = pb };
}

fn mapProcessError(err: anyerror) Decoder.Error {
    return switch (err) {
        error.OutOfMemory, error.WriteFailed => error.OutOfMemory,
        error.EndOfStream => error.TruncatedFrame,
        error.Overflow => error.IntegerOverflow,
        error.OutputLimitExceeded => error.OutputLimitExceeded,
        else => error.InvalidLzma2Stream,
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

fn decodeFragmented(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    expected: []const u8,
    input_chunk: usize,
    output_chunk: usize,
) !void {
    var decoder = try Decoder.init(allocator, .{
        .dictionary_property = @import("lzma2_writer.zig").dictionary_property,
        .expected_output_len = expected.len,
        .max_output_len = expected.len,
    });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.len, input_offset + input_chunk);
        if (input_offset == encoded.len) decoder.finish();
        const output_end = @min(output.len, output_offset + output_chunk);
        const stepped = try decoder.step(
            encoded[input_offset..input_end],
            output[output_offset..output_end],
        );
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, output);
}

test "raw LZMA2 incremental decoder handles stored and compressed chunks" {
    const writer = @import("lzma2_writer.zig");
    const stored_input = "stored LZMA2 chunks\n" ** 4096;
    var stored: std.ArrayList(u8) = .empty;
    defer stored.deinit(std.testing.allocator);
    _ = try writer.appendStoredPayload(std.testing.allocator, &stored, stored_input);
    try decodeFragmented(std.testing.allocator, stored.items, stored_input, 1, 3);

    const compressed_input = "compressed LZMA2 chunks retain state and dictionary\n" ** 4096;
    var compressed: std.ArrayList(u8) = .empty;
    defer compressed.deinit(std.testing.allocator);
    _ = try writer.appendCompressedPayload(
        std.testing.allocator,
        &compressed,
        compressed_input,
    );
    try decodeFragmented(std.testing.allocator, compressed.items, compressed_input, 7, 5);
}

test "raw LZMA2 incremental decoder enforces limits truncation and OOM" {
    const writer = @import("lzma2_writer.zig");
    const input = "raw LZMA2 allocation failure\n" ** 128;
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(std.testing.allocator);
    _ = try writer.appendCompressedPayload(std.testing.allocator, &encoded, input);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        Decoder.init(std.testing.allocator, .{
            .dictionary_property = writer.dictionary_property,
            .max_dictionary_size = 4095,
        }),
    );
    var missing_resets = try std.testing.allocator.dupe(u8, encoded.items);
    defer std.testing.allocator.free(missing_resets);
    missing_resets[0] = 0x80 | (missing_resets[0] & 0x1f);
    var invalid = try Decoder.init(std.testing.allocator, .{
        .dictionary_property = writer.dictionary_property,
        .expected_output_len = input.len,
    });
    defer invalid.deinit();
    var invalid_output: [input.len]u8 = undefined;
    try std.testing.expectError(
        error.InvalidLzma2Stream,
        invalid.step(missing_resets, &invalid_output),
    );

    var truncated = try Decoder.init(std.testing.allocator, .{
        .dictionary_property = writer.dictionary_property,
        .expected_output_len = input.len,
    });
    defer truncated.deinit();
    _ = try truncated.step(encoded.items[0..1], &.{});
    truncated.finish();
    try std.testing.expectError(error.TruncatedFrame, truncated.step("", &.{}));

    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator, payload: []const u8, expected: []const u8) !void {
            try decodeFragmented(allocator, payload, expected, 11, 13);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ encoded.items, input },
    );
}
