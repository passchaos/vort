//! Captured codec identity and bounded worker geometry for one stream.
const old_parallel = @import("../parallel/types.zig");
const types = @import("types.zig");
const Error = types.Error;

pub const Geometry = struct {
    jobs: usize,
    workers: usize,

    pub fn fromConfig(config: types.Config) Error!Geometry {
        try config.validate();
        const block_size = config.writer_options.block_size;
        const capacity_blocks = 1 + (config.parallel.max_inflight_bytes - 1) / block_size;
        var jobs = @min(config.parallel.max_inflight_blocks, @min(config.max_block_count, capacity_blocks));
        if (config.expected_input_len) |expected| {
            const expected_blocks = if (expected == 0) 1 else 1 + (expected - 1) / block_size;
            jobs = @min(jobs, expected_blocks);
        }
        const full_capacity = @max(@as(usize, 1), config.parallel.max_inflight_bytes / block_size);
        const available_workers = @min(config.parallel.worker_count, @min(jobs, full_capacity));
        const workers = if (old_parallel.target_supports_parallel and available_workers > 1) available_workers else 0;
        return .{ .jobs = jobs, .workers = workers };
    }
};

pub fn capture(config: types.Config) types.Config {
    var owned = config;
    owned.parallel.profile = null;
    if (owned.writer_options.match_options) |*matching| matching.profile = null;
    // Block writing always uses the captured codec; it never starts the
    // unrelated one-shot worker pool from its options.
    owned.writer_options.parallel = null;
    return owned;
}

pub fn tracksWork(config: types.Config) bool {
    return if (config.writer_options.match_options) |matching| matching.profile != null else false;
}
