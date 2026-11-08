//! Ordered traversal of standard or magicless Zstandard stream elements.
//!
//! The cursor parses only the next element header. Data frames are handed to
//! the caller together with their checked layout; the caller executes them
//! with the frame executor and then publishes the exact end offset through
//! `finishData`. Skippable frames are range-checked and advanced without
//! reading their payload bytes. A cursor never holds decoded state, so callers
//! reset their frame-local history and entropy state between data frames.
//!
//! A failed parse leaves the next offset unchanged, which makes retryable
//! source failures resumable at element granularity. Calling `next` while a
//! data frame is pending, or `finishData` without one, is a state error.
const std = @import("std");
const core = @import("../../core.zig");
const frame_format = @import("../frame/format.zig");
const source_frame = @import("frame.zig");
const source_input = @import("input.zig");

pub const Error = core.Error || source_input.Error;
pub const FrameFormat = frame_format.FrameFormat;

pub const Element = source_frame.StreamElement;

pub const Cursor = struct {
    stream: source_input.Range,
    format: FrameFormat,
    next_offset: u64,
    pending_data_start: ?u64 = null,

    pub fn init(stream: source_input.Range, format: FrameFormat) Cursor {
        return .{
            .stream = stream,
            .format = format,
            .next_offset = stream.offset,
        };
    }

    /// Parse the next element header. A skippable element advances the cursor
    /// immediately because its full range is known. A data element remains
    /// pending until `finishData` publishes its exact end.
    pub fn next(self: *Cursor) Error!?Element {
        if (self.pending_data_start != null) return error.InvalidStreamState;
        const end = try self.stream.end();
        if (self.next_offset == end) return null;
        if (self.next_offset < self.stream.offset or self.next_offset > end)
            return error.CorruptFrame;

        const relative = self.next_offset - self.stream.offset;
        const remaining = end - self.next_offset;
        const element_range = try self.stream.subrange(relative, remaining);
        const element = try source_frame.parseStreamElementHeader(
            element_range,
            self.format,
        );
        switch (element) {
            .data => |frame| {
                if (frame.available.offset != self.next_offset)
                    return error.CorruptFrame;
                self.pending_data_start = self.next_offset;
            },
            .skippable => |skippable| {
                if (skippable.next_element_offset <= self.next_offset)
                    return error.CorruptFrame;
                self.next_offset = skippable.next_element_offset;
            },
        }
        return element;
    }

    /// Publish the exact end offset reported by a successful frame executor.
    pub fn finishData(self: *Cursor, frame_end_offset: u64) Error!void {
        const start = self.pending_data_start orelse
            return error.InvalidStreamState;
        const end = try self.stream.end();
        if (frame_end_offset < start or frame_end_offset > end)
            return error.CorruptFrame;
        self.pending_data_start = null;
        self.next_offset = frame_end_offset;
    }

    pub fn pending(self: *const Cursor) bool {
        return self.pending_data_start != null;
    }

    /// Offset of the next element header, or of the pending data frame start.
    pub fn offset(self: *const Cursor) u64 {
        return self.next_offset;
    }
};
