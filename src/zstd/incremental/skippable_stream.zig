//! Inline skippable header and direct caller-buffer delivery shared by both
//! incremental encoders. The owners admit borrows, limits and lifecycle.
const std = @import("std");
const core = @import("../../core.zig");
const frame_format = @import("../frame/format.zig");
const wire = @import("../frame/skippable.zig");
const count = core.stream_count;
const Count = core.StreamCount;

pub fn wireLen(payload_len: u32) Count {
    return @as(Count, payload_len) + wire.encoded_len;
}

pub const State = struct {
    header: [wire.encoded_len]u8,
    header_offset: u8 = 0,
    remaining: u32,

    pub fn init(id: u4, payload_len: u32) State {
        var state: State = .{ .header = undefined, .remaining = payload_len };
        std.mem.writeInt(u32, state.header[0..4], frame_format.skippable_magic_min + @as(u32, id), .little);
        std.mem.writeInt(u32, state.header[4..8], payload_len, .little);
        return state;
    }

    pub fn pendingHeaderLen(self: *const State) usize {
        return wire.encoded_len - self.header_offset;
    }

    /// Input and output are disjoint and already admitted by the owner.
    /// Output-limit failure may deliver a prefix; integer overflow does not.
    pub fn step(
        self: *State,
        input: []const u8,
        output: []u8,
        progress: *core.Progress,
        frame_output: *Count,
        stream_output: *Count,
        output_limit: Count,
    ) core.Error!core.StepResult.Status {
        if (input.len > self.remaining) return error.SizeMismatch;
        const offered_header = @min(self.pendingHeaderLen(), output.len);
        const wanted = offered_header + @min(input.len, output.len - offered_header);
        _ = try count.addLocal(frame_output.*, wanted);
        _ = try count.addLocal(stream_output.*, wanted);
        const available = count.bounded(output_limit -| stream_output.*, wanted);
        const head = @min(available, offered_header);
        const body = available - head;
        @memcpy(output[0..head], self.header[self.header_offset..][0..head]);
        @memcpy(output[head..available], input[0..body]);
        self.header_offset += @intCast(head);
        self.remaining -= @intCast(body);
        frame_output.* += count.fromLocal(available);
        stream_output.* += count.fromLocal(available);
        progress.* = .{ .input_read = body, .output_written = available };
        if (available != wanted) return error.OutputLimitExceeded;
        if (self.pendingHeaderLen() == 0 and self.remaining == 0) return .done;
        return if (self.pendingHeaderLen() != 0 or body != input.len) .need_output else .need_input;
    }
};
