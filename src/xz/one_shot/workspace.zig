const std = @import("std");
const container = @import("../container.zig");
const block_mod = @import("../incremental/block_decoder.zig");
const checks = @import("../incremental/checks.zig");
const filters_mod = @import("../incremental_filters.zig");
const working = @import("../../io/working_allocator.zig");
const options_mod = @import("options.zig");

pub const Error = container.Error || block_mod.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
pub const Options = options_mod.Options;

const BlockPlan = struct {
    header: container.BlockHeader,
    check: container.Check,
    body_offset: usize,
    packed_size: usize,
    body_size: usize,
    decoded_size: usize,
};

/// Strict bounded one-shot XZ decoding. Validation drains all decoded bytes
/// through a fixed scratch buffer and retains only numeric block metadata and
/// reusable dictionary, probability and inverse-filter workspaces.
pub const DecodeWorkspace = struct {
    allocator: std.mem.Allocator,
    options: Options,
    budget: working.WorkingAllocator,
    block: ?block_mod.Decoder = null,
    plans: std.ArrayList(BlockPlan) = .empty,
    records: std.ArrayList(container.BlockRecord) = .empty,
    owned_input: std.ArrayList(u8) = .empty,
    prepared_input: ?[]const u8 = null,
    prepared_output_len: usize = 0,
    stream_count: usize = 0,
    output_limit_hit: bool = false,
    info: container.StreamInfo = std.mem.zeroes(container.StreamInfo),
    scratch: [4096]u8 = undefined,

    pub const Mode = enum { single, concatenated };
    pub const Snapshot = struct {
        prepared: bool,
        prepared_output_len: usize,
        stream_count: usize,
        block_count: usize,
        working_bytes: usize,
        peak_working_bytes: usize,
        retained_dictionary_capacity: usize,
        retained_probability_bytes: usize,
        retained_compressed_capacity: usize,
        /// Inverse-filter buffers, excluding the separately reported stage.
        retained_filter_bytes: usize,
        retained_stage_capacity: usize,
        /// Metadata capacities are measured in records rather than bytes.
        retained_block_capacity: usize,
        retained_index_capacity: usize,
        retained_input_capacity: usize,
    };

    pub fn init(allocator: std.mem.Allocator) DecodeWorkspace {
        return .{ .allocator = allocator, .options = .{}, .budget = working.WorkingAllocator.init(allocator, std.math.maxInt(usize)) };
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!DecodeWorkspace {
        try options.validate();
        return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory) };
    }

    pub fn deinit(self: *DecodeWorkspace) void {
        self.bind();
        if (self.block) |*block| block.deinit();
        self.plans.deinit(self.budget.allocator());
        self.records.deinit(self.budget.allocator());
        self.owned_input.deinit(self.budget.allocator());
        std.debug.assert(self.budget.live == 0);
        self.* = undefined;
    }

    /// Invalidate the prepared input while preserving all heap capacities.
    pub fn reset(self: *DecodeWorkspace) void {
        self.bind();
        self.plans.clearRetainingCapacity();
        self.records.clearRetainingCapacity();
        self.owned_input.clearRetainingCapacity();
        self.prepared_input = null;
        self.prepared_output_len = 0;
        self.stream_count = 0;
        self.output_limit_hit = false;
        self.info = std.mem.zeroes(container.StreamInfo);
        self.budget.peak = self.budget.live;
        self.budget.hit_limit = false;
        self.budget.last_failure_was_limit = false;
    }

    pub fn resetWithOptions(self: *DecodeWorkspace, options: Options) Error!void {
        try options.validate();
        const allocator = self.allocator;
        self.deinit();
        self.* = try initWithOptions(allocator, options);
    }

    pub fn workingMemoryBytes(self: *const DecodeWorkspace) usize {
        return self.budget.live;
    }

    pub fn peakWorkingMemoryBytes(self: *const DecodeWorkspace) usize {
        return self.budget.peak;
    }

    pub fn snapshot(self: *const DecodeWorkspace) Snapshot {
        const dictionary = if (self.block) |*block| block.raw.dictionary.bytes.capacity else 0;
        const compressed = if (self.block) |*block| block.raw.compressed.capacity else 0;
        return .{
            .prepared = self.prepared_input != null,
            .prepared_output_len = self.prepared_output_len,
            .stream_count = self.stream_count,
            .block_count = self.plans.items.len,
            .working_bytes = self.budget.live,
            .peak_working_bytes = self.budget.peak,
            .retained_dictionary_capacity = dictionary,
            .retained_probability_bytes = if (self.block) |*block| block.raw.workingMemoryBytes() - dictionary - compressed else 0,
            .retained_compressed_capacity = compressed,
            .retained_filter_bytes = if (self.block) |*block| block.staging_budget.live - block.staged.capacity else 0,
            .retained_stage_capacity = if (self.block) |*block| block.staged.capacity else 0,
            .retained_block_capacity = self.plans.capacity,
            .retained_index_capacity = self.records.capacity,
            .retained_input_capacity = self.owned_input.capacity,
        };
    }

    /// Borrow input, keeping its bytes immutable across every replay until the
    /// next preparation, reset or deinit. Replay output must not overlap it;
    /// prepareInto supports overlap by owning a compressed copy.
    pub fn prepare(self: *DecodeWorkspace, input: []const u8, mode: Mode) Error!usize {
        return self.prepareBounded(input, mode, self.options.max_output_len, null);
    }

    /// Validate for this output ceiling and copy compressed input, if needed,
    /// before preparation completes. No output byte is written here.
    pub fn prepareInto(self: *DecodeWorkspace, input: []const u8, output: []u8, mode: Mode) Error!usize {
        const limit = @min(output.len, self.options.max_output_len);
        return self.prepareBounded(input, mode, limit, output) catch |err| {
            return if (err == error.OutputLimitExceeded and self.output_limit_hit and output.len <= self.options.max_output_len) error.OutputTooSmall else err;
        };
    }

    pub fn decodeInto(self: *DecodeWorkspace, input: []const u8, output: []u8) Error!usize {
        _ = try self.prepareInto(input, output, .single);
        return self.replayInto(output);
    }

    pub fn decodeConcatenatedInto(self: *DecodeWorkspace, input: []const u8, output: []u8) Error!usize {
        _ = try self.prepareInto(input, output, .concatenated);
        return self.replayInto(output);
    }

    pub fn decodedSize(self: *DecodeWorkspace, input: []const u8) Error!usize {
        return self.prepare(input, .single);
    }

    pub fn decodedSizeConcatenated(self: *DecodeWorkspace, input: []const u8) Error!usize {
        return self.prepare(input, .concatenated);
    }

    pub fn inspect(self: *DecodeWorkspace, input: []const u8) Error!container.StreamInfo {
        _ = try self.prepare(input, .single);
        return self.info;
    }

    /// Replay a complete validated plan. Its fixed schedule and retained model
    /// shapes require no allocator calls, even across blocks/filter changes.
    pub fn replayInto(self: *DecodeWorkspace, output: []u8) Error!usize {
        self.bind();
        const input = self.prepared_input orelse return error.InvalidBlockPlan;
        if (output.len < self.prepared_output_len) return error.OutputTooSmall;
        if (overlaps(input, output[0..self.prepared_output_len])) return error.InvalidBlockPlan;
        var written: usize = 0;
        for (self.plans.items) |plan| {
            try self.configure(plan);
            var read: usize = 0;
            var produced: usize = 0;
            while (true) {
                const target = output[written + produced ..][0..@min(self.scratch.len, plan.decoded_size - produced)];
                const step = try self.block.?.step(input[plan.body_offset + read ..][0 .. plan.packed_size - read], target);
                read += step.progress.input_read;
                produced += step.progress.output_written;
                if (step.status == .done) break;
                if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.InvalidXzStream;
            }
            if (read != plan.packed_size or produced != plan.decoded_size) return error.SizeMismatch;
            written += produced;
        }
        return written;
    }

    fn bind(self: *DecodeWorkspace) void {
        if (self.block) |*block| block.rebindAllocator(self.budget.allocator());
    }

    fn prepareBounded(self: *DecodeWorkspace, input: []const u8, mode: Mode, limit: usize, output: ?[]u8) Error!usize {
        self.reset();
        const result = self.validate(input, mode, limit, output) catch |original| {
            self.prepared_input = null;
            return if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else original;
        };
        return result;
    }

    fn validate(self: *DecodeWorkspace, input: []const u8, mode: Mode, limit: usize, output: ?[]u8) Error!usize {
        if (mode == .concatenated and input.len == 0) return error.InvalidMagic;
        var offset: usize = 0;
        while (true) {
            const parsed = try self.validateStream(input[offset..], offset, limit);
            if (self.stream_count == 0) self.info = parsed.info;
            self.stream_count += 1;
            offset = try checkedEnd(offset, parsed.consumed, input.len);
            offset = try container.skipStreamPadding(input, offset);
            if (mode == .single) {
                if (offset != input.len) return error.TrailingData;
                break;
            }
            if (offset == input.len) break;
        }
        var replay_input = input;
        if (output) |destination| {
            if (overlaps(input, destination[0..self.prepared_output_len])) {
                try self.owned_input.ensureTotalCapacityPrecise(self.budget.allocator(), input.len);
                self.owned_input.items.len = input.len;
                std.mem.copyForwards(u8, self.owned_input.items, input);
                replay_input = self.owned_input.items;
            }
        }
        self.prepared_input = replay_input;
        return self.prepared_output_len;
    }

    const ValidatedStream = struct { consumed: usize, info: container.StreamInfo };

    fn validateStream(self: *DecodeWorkspace, input: []const u8, base: usize, limit: usize) Error!ValidatedStream {
        const stream_header = try container.parseStreamHeader(input);
        var info = std.mem.zeroes(container.StreamInfo);
        info.check = stream_header.check;
        self.records.clearRetainingCapacity();
        var offset: usize = 12;
        while (true) {
            if (offset >= input.len) return error.TruncatedFrame;
            if (input[offset] == 0) break;
            const header = try container.parseBlockHeader(input, offset);
            if (header.dictionary_size > self.options.max_dictionary_size) return error.OutputLimitExceeded;
            const scan = container.scanLzma2(input[header.end_offset..], limit -| self.prepared_output_len) catch |err| {
                if (err == error.OutputLimitExceeded) self.output_limit_hit = true;
                return err;
            };
            if (header.packed_size) |declared| if (declared != scan.packed_size) return error.SizeMismatch;
            if (header.unpacked_size) |declared| if (declared != scan.unpacked_size) return error.SizeMismatch;
            const data_end = try checkedEnd(header.end_offset, scan.packed_size, input.len);
            const padding = (4 - ((header.header_size + scan.packed_size) % 4)) % 4;
            const padding_end = try checkedEnd(data_end, padding, input.len);
            for (input[data_end..padding_end]) |byte| if (byte != 0) return error.InvalidXzStream;
            const check_end = try checkedEnd(padding_end, try checks.size(stream_header.check), input.len);
            const plan = BlockPlan{
                .header = header,
                .check = stream_header.check,
                .body_offset = base + header.end_offset,
                .packed_size = scan.packed_size,
                .body_size = check_end - header.end_offset,
                .decoded_size = scan.unpacked_size,
            };
            try self.configure(plan);
            var read: usize = 0;
            var produced: usize = 0;
            while (true) {
                const target = self.scratch[0..@min(self.scratch.len, scan.unpacked_size - produced)];
                const step = self.block.?.step(input[header.end_offset + read .. data_end], target) catch |err| {
                    return switch (err) {
                        error.OutOfMemory, error.WorkingMemoryLimitExceeded => err,
                        else => error.InvalidXzStream,
                    };
                };
                read += step.progress.input_read;
                produced += step.progress.output_written;
                if (step.status == .done) break;
                if (step.progress.input_read == 0 and step.progress.output_written == 0) return error.SizeMismatch;
            }
            if (read != scan.packed_size or produced != scan.unpacked_size) return error.SizeMismatch;
            try self.block.?.check_state.verify(stream_header.check, input[padding_end..check_end]);
            const record = container.BlockRecord{
                .unpadded_size = header.header_size + scan.packed_size + try checks.size(stream_header.check),
                .uncompressed_size = scan.unpacked_size,
            };
            try self.records.append(self.budget.allocator(), record);
            try self.plans.append(self.budget.allocator(), plan);
            self.prepared_output_len = std.math.add(usize, self.prepared_output_len, produced) catch return error.OutputLimitExceeded;
            if (self.prepared_output_len > limit) return error.OutputLimitExceeded;
            info.uncompressed_size = std.math.add(usize, info.uncompressed_size, produced) catch return error.OutputLimitExceeded;
            info.block_count += 1;
            info.max_dictionary_size = @max(info.max_dictionary_size, header.dictionary_size);
            noteFilters(&info, header);
            offset = check_end;
        }
        const footer_len = try container.validateIncrementalIndexFooter(input[offset..], &stream_header.flags, self.records.items);
        info.compressed_size = try checkedEnd(offset, footer_len, input.len);
        return .{ .consumed = info.compressed_size, .info = info };
    }

    fn configure(self: *DecodeWorkspace, plan: BlockPlan) Error!void {
        self.bind();
        if (self.block) |*block| {
            try block.resetRetaining(plan.header, plan.check, plan.decoded_size, false, plan.body_size, 64, std.math.maxInt(usize), self.options.max_dictionary_size);
        } else {
            self.block = try block_mod.Decoder.init(self.budget.allocator(), plan.header, plan.check, plan.decoded_size, false, plan.body_size, 64, std.math.maxInt(usize), self.options.max_dictionary_size);
        }
        const block = &self.block.?;
        block.raw.retain_property_workspaces = true;
        // Keep the same 256-byte raw/filter schedule even for an empty chain,
        // so validation and replay warm exactly the same nested capacities.
        if (block.inverse == null) block.inverse = try filters_mod.Decoder.init(block.stagingAllocator(), block.inverse_chain[0..plan.header.filter_count]);
    }
};

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.IntegerOverflow;
    if (end > limit) return error.TruncatedFrame;
    return end;
}

fn overlaps(input: []const u8, output: []const u8) bool {
    if (input.len == 0 or output.len == 0) return false;
    const source = @intFromPtr(input.ptr);
    const target = @intFromPtr(output.ptr);
    return if (source <= target) target - source < input.len else source - target < output.len;
}

fn noteFilters(info: *container.StreamInfo, header: container.BlockHeader) void {
    for (header.filters[0..header.filter_count]) |filter| switch (filter.kind) {
        .delta => info.delta_filter_blocks += 1,
        .x86 => {
            info.bcj_filter_blocks += 1;
            info.x86_filter_blocks += 1;
        },
        .powerpc => {
            info.bcj_filter_blocks += 1;
            info.powerpc_filter_blocks += 1;
        },
        .ia64 => {
            info.bcj_filter_blocks += 1;
            info.ia64_filter_blocks += 1;
        },
        .arm => {
            info.bcj_filter_blocks += 1;
            info.arm_filter_blocks += 1;
        },
        .arm_thumb => {
            info.bcj_filter_blocks += 1;
            info.arm_thumb_filter_blocks += 1;
        },
        .sparc => {
            info.bcj_filter_blocks += 1;
            info.sparc_filter_blocks += 1;
        },
        .arm64 => {
            info.bcj_filter_blocks += 1;
            info.arm64_filter_blocks += 1;
        },
        .riscv => {
            info.bcj_filter_blocks += 1;
            info.riscv_filter_blocks += 1;
        },
    };
}
