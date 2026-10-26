//! Captured per-frame codec and immutable worker policy.
const types = @import("types.zig");

pub fn validate(comptime Codec: type, config: types.Config(Codec)) Codec.Error!void {
    try config.parallel.validate();
    const geometry = config.geometry;
    if (geometry.block_size == 0 or geometry.job_size == 0 or geometry.slot_count == 0 or
        geometry.job_size % geometry.block_size != 0 or geometry.worker_count > 64 or
        geometry.worker_count > geometry.slot_count or config.max_job_count == 0)
        return error.InvalidBlockPlan;
}

pub fn capture(comptime Codec: type, config: types.Config(Codec)) types.Config(Codec) {
    var owned = config;
    owned.parallel.profile = null;
    if (comptime @hasField(Codec.Options, "control_profile")) owned.frame_options.control_profile = null;
    if (comptime @hasField(Codec.Options, "memory_profile")) owned.frame_options.memory_profile = null;
    if (comptime @hasField(Codec.Options, "parallel")) owned.frame_options.parallel = null;
    return owned;
}
