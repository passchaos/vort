//! Publication and restart coordinates for source-backed stream decoding.
const core = @import("../../core.zig");
const frame_limit = @import("../frame/count_limit.zig");
const FrameFormat = @import("../frame/format.zig").FrameFormat;
const Count = core.StreamCount;

/// A complete-element boundary in the same stable source and format.
pub const Checkpoint = struct {
    compressed_offset: u64 = 0,
    decoded_len: Count = 0,
    data_frames: Count = 0,
    skippable_frames: Count = 0,
    format: FrameFormat = .standard,
};

pub const Progress = struct {
    checkpoint: Checkpoint,
    /// This call's published bytes, including any prefix of a failed frame.
    output_written: usize = 0,
    /// This call's prefix from complete data frames only. Replay replaces the
    /// remainder by restarting at the checkpoint, not inside a frame.
    complete_output_written: usize = 0,
};

pub fn remainingFrames(checkpoint: Checkpoint, maximum: Count) core.Error!Count {
    const completed = try core.stream_count.add(checkpoint.data_frames, checkpoint.skippable_frames);
    if (maximum == frame_limit.unlimited) return frame_limit.unlimited;
    if (completed > maximum) return error.OutputLimitExceeded;
    return maximum - completed;
}
