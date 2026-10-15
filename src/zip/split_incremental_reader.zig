//! Pull-style sequential ZIP reader over ordered split archive slices.

const std = @import("std");
const core = @import("../core.zig");
const incremental_reader = @import("incremental_reader.zig");
const split = @import("split.zig");

pub const Error = split.Error || incremental_reader.Error || error{
    InvalidZipArchive,
    OutputLimitExceeded,
};

pub const Options = struct {
    split_options: split.Options = .{},
    /// `initial_offset` is replaced with the first normalized ZIP record.
    reader_options: incremental_reader.Options = .{},
    /// Bounded bridge buffer between borrowed part slices and the ZIP reader.
    input_buffer_size: usize = 32 * 1024,
};

pub const StepResult = incremental_reader.StepResult;
pub const EntryInfo = incremental_reader.EntryInfo;

/// Sequentially decodes a sparse normalized view without allocating a joined
/// archive. The part payload slices remain caller-owned and must outlive this
/// reader; their outer descriptor array is copied by the normalized stream.
pub const Reader = struct {
    allocator: std.mem.Allocator,
    stream: split.NormalizedStream,
    inner: incremental_reader.Reader,
    input: []u8,
    input_pos: usize = 0,
    input_len: usize = 0,
    source_offset: usize,

    const Self = @This();

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        ordered_parts: []const []const u8,
        options: Options,
    ) (Error || std.mem.Allocator.Error)!Self {
        if (options.input_buffer_size == 0) return error.OutputLimitExceeded;
        var stream = try split.NormalizedStream.initAlloc(
            allocator,
            ordered_parts,
            options.split_options,
        );
        errdefer stream.deinit();
        var reader_options = options.reader_options;
        reader_options.initial_offset = stream.firstRecordOffset();
        var inner = try incremental_reader.Reader.initWithOptions(
            allocator,
            reader_options,
        );
        errdefer inner.deinit();
        const input = try allocator.alloc(u8, options.input_buffer_size);
        errdefer allocator.free(input);
        return .{
            .allocator = allocator,
            .stream = stream,
            .inner = inner,
            .input = input,
            .source_offset = reader_options.initial_offset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.inner.deinit();
        self.stream.deinit();
        self.allocator.free(self.input);
        self.* = undefined;
    }

    pub fn currentEntry(self: *const Self) ?EntryInfo {
        return self.inner.currentEntry();
    }

    pub fn archiveComment(self: *const Self) []const u8 {
        return self.inner.archiveComment();
    }

    pub fn snapshot(self: *const Self) incremental_reader.Reader.Snapshot {
        return self.inner.snapshot();
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return self.inner.diagnostics();
    }

    pub fn normalizedLength(self: *const Self) usize {
        return self.stream.len();
    }

    pub fn metadataPatchCount(self: *const Self) usize {
        return self.stream.patchCount();
    }

    pub fn finish(self: *Self) Error!void {
        return self.inner.finish();
    }

    /// Pulls normalized input internally and returns the same entry boundary
    /// statuses as `ZipIncrementalReader.step`.
    pub fn step(self: *Self, output: []u8) Error!StepResult {
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.input_pos == self.input_len) {
                self.input_pos = 0;
                self.input_len = 0;
                if (self.source_offset != self.stream.len()) {
                    self.input_len = try self.stream.readAt(self.source_offset, self.input);
                    if (self.input_len == 0) return error.InvalidZipArchive;
                    self.source_offset = std.math.add(
                        usize,
                        self.source_offset,
                        self.input_len,
                    ) catch return error.IntegerOverflow;
                }
            }

            const result = try self.inner.step(
                self.input[self.input_pos..self.input_len],
                output[output_written..],
            );
            self.input_pos += result.progress.input_read;
            input_read = std.math.add(
                usize,
                input_read,
                result.progress.input_read,
            ) catch return error.IntegerOverflow;
            output_written = std.math.add(
                usize,
                output_written,
                result.progress.output_written,
            ) catch return error.IntegerOverflow;
            if (self.input_pos > self.input_len or output_written > output.len)
                return error.InvalidZipArchive;

            switch (result.status) {
                .entry_header, .entry_done, .done => return makeResult(
                    input_read,
                    output_written,
                    result.status,
                ),
                .need_output => return makeResult(
                    input_read,
                    output_written,
                    .need_output,
                ),
                .need_input => {
                    if (self.input_pos != self.input_len)
                        return error.InvalidZipArchive;
                    if (self.source_offset == self.stream.len()) {
                        try self.inner.finish();
                        return error.InvalidZipArchive;
                    }
                },
            }
        }
    }
};

fn makeResult(
    input_read: usize,
    output_written: usize,
    status: StepResult.Status,
) StepResult {
    return .{
        .progress = .{
            .input_read = input_read,
            .output_written = output_written,
        },
        .status = status,
    };
}
