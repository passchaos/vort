const std = @import("std");
const types = @import("types.zig");

pub const CorpusInfo = struct {
    bytes: usize = 0,
    dmers: usize = 0,
    readable_positions: usize = 0,
    max_sample_dmers: usize = 0,
};

pub const Layout = struct {
    offset_words: usize,
    table_len: usize,
    words: usize,

    pub fn init(sample_count: usize, hash_log: u8) !Layout {
        const offsets = try add(sample_count, 1);
        const table_len = @as(usize, 1) << @intCast(hash_log);
        const table_bytes = try multiply(try multiply(table_len, 3), @sizeOf(u32));
        const allocation_bytes = try add(try multiply(offsets, @sizeOf(usize)), table_bytes);
        const words = try add(allocation_bytes, @sizeOf(usize) - 1) / @sizeOf(usize);
        _ = try multiply(words, @sizeOf(usize));
        return .{ .offset_words = offsets, .table_len = table_len, .words = words };
    }

    pub fn bytes(self: Layout) usize {
        return self.words * @sizeOf(usize);
    }
};

pub fn add(a: usize, b: usize) !usize {
    return std.math.add(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}

pub fn multiply(a: usize, b: usize) !usize {
    return std.math.mul(usize, a, b) catch error.WorkingMemoryLimitExceeded;
}

pub fn check(bytes: usize, maximum: usize) !void {
    if (bytes > maximum) return error.WorkingMemoryLimitExceeded;
}

pub fn validateScalar(options: types.TrainOptions) !usize {
    if ((options.dmer_size != 6 and options.dmer_size != 8) or
        options.hash_log < types.min_hash_log or options.hash_log > types.max_hash_log or
        options.acceleration == 0 or options.acceleration > types.max_acceleration or
        options.target_size > options.max_dictionary_size or options.target_size > std.math.maxInt(u32))
        return error.InvalidDictionaryTraining;
    if (options.target_size == 0) return 0;
    const segment = options.segment_size orelse @min(options.target_size, 64);
    if (segment < options.dmer_size or segment > options.target_size) return error.InvalidDictionaryTraining;
    return segment;
}

pub fn corpusInfo(samples: []const []const u8, options: types.TrainOptions) !CorpusInfo {
    var info: CorpusInfo = .{};
    for (samples) |sample| {
        info.bytes = std.math.add(usize, info.bytes, sample.len) catch return error.InvalidDictionaryTraining;
        const dmers = dmerCount(sample.len, options.dmer_size);
        info.dmers = std.math.add(usize, info.dmers, dmers) catch return error.InvalidDictionaryTraining;
        info.readable_positions = std.math.add(usize, info.readable_positions, dmerCount(sample.len, 8)) catch return error.InvalidDictionaryTraining;
        info.max_sample_dmers = @max(info.max_sample_dmers, dmers);
    }
    if (info.bytes > options.max_corpus_size or info.bytes > std.math.maxInt(u32)) return error.InvalidDictionaryTraining;
    if (options.target_size != 0 and (samples.len < 5 or info.readable_positions == 0)) return error.InvalidDictionaryTraining;
    return info;
}

pub fn dmerCount(sample_len: usize, width: usize) usize {
    return if (sample_len >= width) sample_len - width + 1 else 0;
}

pub fn ringCount(info: CorpusInfo, segment_size: usize, dmer_size: usize) usize {
    if (segment_size == 0) return 0;
    return @min(info.max_sample_dmers, segment_size - dmer_size + 1);
}

/// Exact peak for the known workspace/ring/scratch allocations, including old
/// and new buffers during growth. Owned output is separately charged by its
/// actual selected length immediately before its allocation.
pub fn selectionPeak(workspace_bytes: usize, ring_capacity: usize, scratch_capacity: usize, ring_needed: usize, target_size: usize) !usize {
    var resident = try add(try add(workspace_bytes, try multiply(ring_capacity, @sizeOf(u32))), scratch_capacity);
    var maximum = resident;
    if (ring_needed > ring_capacity) {
        const allocation_bytes = try multiply(ring_needed, @sizeOf(u32));
        maximum = @max(maximum, try add(resident, allocation_bytes));
        resident = try add(resident - ring_capacity * @sizeOf(u32), allocation_bytes);
    }
    if (target_size > scratch_capacity) {
        maximum = @max(maximum, try add(resident, target_size));
        resident = try add(resident - scratch_capacity, target_size);
    }
    return @max(maximum, resident);
}

/// Required cold preparation/selection peak, before output length is known.
pub fn requiredPeak(samples: []const []const u8, options: types.TrainOptions) !usize {
    const segment = try validateScalar(options);
    const info = try corpusInfo(samples, options);
    if (options.target_size == 0) return 0;
    const layout = try Layout.init(samples.len, options.hash_log);
    return selectionPeak(layout.bytes(), 0, 0, ringCount(info, segment, options.dmer_size), options.target_size);
}

/// Conservative one-shot upper bound for planning, not an allocation quota
/// check: underfilled results can succeed with a smaller actual live budget.
pub fn estimatedPeak(samples: []const []const u8, options: types.TrainOptions) !usize {
    const required = try requiredPeak(samples, options);
    if (options.target_size == 0) return required;
    return add(required, options.target_size);
}
