const std = @import("std");

pub const stream_count = @import("io/stream_count.zig");
pub const StreamCount = stream_count.Counter;

/// Errors shared by early Vort parsers and streaming primitives.
pub const Error = error{
    OutputTooSmall,
    InputTooSmall,
    InvalidMagic,
    UnsupportedVersion,
    TruncatedFrame,
    CorruptFrame,
    ChecksumMismatch,
    SizeMismatch,
    IntegerOverflow,
    InvalidDeflateBlockType,
    StoredLengthMismatch,
    BadZlibHeader,
    BadGzipHeader,
    NeedDictionary,
    DictionaryMismatch,
    InvalidStreamState,
    InvalidHuffmanCode,
    UnsupportedDeflateFeature,
    UnsupportedZstdFeature,
    UnsupportedBrotliFeature,
    UnsupportedSnappyFeature,
    InvalidMatch,
    InvalidDynamicBlockHeader,
    InvalidBlockPlan,
    InvalidDictionaryTraining,
    RangeOutOfBounds,
    OutputLimitExceeded,
    SearchLimitExceeded,
    TrailingData,
    DuplicateDictionaryId,
    InvalidDictionaryMetadata,
};

/// Input/output accounting for resumable streaming APIs.
pub const Progress = struct {
    input_read: usize = 0,
    output_written: usize = 0,

    pub fn add(self: *Progress, other: Progress) Error!void {
        self.input_read = std.math.add(usize, self.input_read, other.input_read) catch return error.IntegerOverflow;
        self.output_written = std.math.add(usize, self.output_written, other.output_written) catch return error.IntegerOverflow;
    }
};

/// Result used by bounded-buffer streaming steps.
pub const StepResult = struct {
    progress: Progress = .{},
    status: Status = .need_input,

    pub const Status = enum {
        need_input,
        need_output,
        done,
    };
};

/// How incremental frame decoders retain encoded data. Block streaming is the
/// normal bounded-memory mode; prevalidated_frame preserves the established
/// complete-frame preflight/direct paths and their validation timing.
pub const CompressedInputPolicy = enum { block_stream, prevalidated_frame };

pub const StreamingDiagnostics = struct {
    phase_name: []const u8,
    input_read: ?StreamCount = null,
    header_received: ?usize = null,
    frame_input_read: ?StreamCount = null,
    output_written: StreamCount = 0,
    expected_output_len: ?StreamCount = null,
    payload_remaining: ?usize = null,
    last_error_name: []const u8 = "",
    last_error_phase_name: []const u8 = "",
    recoverability_hint_name: []const u8 = "none",
    error_input_offset: ?StreamCount = null,
    error_output_offset: ?StreamCount = null,
    last_step_progress: ?Progress = null,
};

test "streaming diagnostics keep cumulative counts wide and caller progress local" {
    const boundary: StreamCount = @as(StreamCount, 1) << 32;
    const expected: ?usize = 19;
    const value: StreamingDiagnostics = .{
        .phase_name = "payload",
        .input_read = boundary + 3,
        .frame_input_read = boundary + 1,
        .output_written = boundary + 7,
        .expected_output_len = stream_count.fromOptionalLocal(expected),
        .error_input_offset = boundary + 2,
        .error_output_offset = boundary + 6,
        .header_received = 8,
        .payload_remaining = 5,
        .last_step_progress = .{ .input_read = 3, .output_written = 7 },
    };
    try std.testing.expectEqual(@as(?StreamCount, boundary + 3), value.input_read);
    try std.testing.expectEqual(@as(StreamCount, boundary + 7), value.output_written);
    try std.testing.expectEqual(@as(?StreamCount, 19), value.expected_output_len);
    try std.testing.expectEqual(@as(?StreamCount, boundary + 6), value.error_output_offset);
    try std.testing.expect(@TypeOf(value.header_received) == ?usize);
    try std.testing.expect(@TypeOf(value.payload_remaining) == ?usize);
    try std.testing.expect(@TypeOf(value.last_step_progress.?.input_read) == usize);
}

/// Caller-visible format metadata emitted by parsers before payload materialization.
pub const FrameInfo = struct {
    version: u8,
    flags: u8,
    uncompressed_size: u64,
    stored_size: u64,
    checksum: u32,
};

test "Progress add checks overflow" {
    var p = Progress{ .input_read = std.math.maxInt(usize), .output_written = 0 };
    try std.testing.expectError(error.IntegerOverflow, p.add(.{ .input_read = 1 }));

    var q = Progress{ .input_read = 1, .output_written = 2 };
    try q.add(.{ .input_read = 3, .output_written = 4 });
    try std.testing.expectEqual(@as(usize, 4), q.input_read);
    try std.testing.expectEqual(@as(usize, 6), q.output_written);
}
