const std = @import("std");
const plan_module = @import("plan.zig");
const node_module = @import("node_cursor.zig");
const tree = @import("tree.zig");
const wire = @import("wire.zig");
const clusters = @import("clusters.zig");
const math = @import("math.zig");
const options_module = @import("options.zig");
const working_module = @import("../../io/working_allocator.zig");

pub const Error = plan_module.Error || node_module.Error || error{WorkingMemoryLimitExceeded};
pub const Limits = struct { max_working_memory: usize = 64 * 1024 * 1024 };
pub const Result = struct { image_size: u64, device_size: u64 = 0, peak_working_bytes: usize };
pub const Target = enum { image, device };
pub const Progress = struct { output_written: usize, offset: u64, target: Target, status: enum { need_output, done } };
const block_size = clusters.block_size;
const no_block = std.math.maxInt(u32);
const max_image_size: u64 = @as(u64, std.math.maxInt(u32)) * block_size;

/// Initialize in caller-owned storage and keep its address stable until deinit.
/// Plans, source descriptors and the current codec window are owned here.
pub const Encoder = struct {
    working: working_module.WorkingAllocator,
    plan: ?plan_module.Plan = null,
    metadata: []u8 = &.{},
    phase: enum { nodes, chunks, metadata, done } = .nodes,
    pass: enum { normal, metabox } = .normal,
    node_index: usize = 0,
    node: ?node_module.Cursor = null,
    node_base: u64 = 0,
    expected_blocks: usize = 0,
    cursor: u64 = 0,
    chunk_index: usize = 0,
    chunk_position: usize = 0,
    metadata_position: usize = 0,
    metadata_ready: bool = false,
    final_result: ?Result = null,
    failed: ?Error = null,

    pub fn init(self: *Encoder, allocator: std.mem.Allocator, entries: []const tree.Entry, options: options_module.Options, limits: Limits) Error!void {
        return self.initWithDevice(allocator, entries, options, false, limits);
    }

    pub fn initExternalChunks(self: *Encoder, allocator: std.mem.Allocator, entries: []const tree.Entry, options: options_module.Options, limits: Limits) Error!void {
        if (options.chunk_size == null) return error.InvalidErofs;
        return self.initWithDevice(allocator, entries, options, true, limits);
    }

    fn initWithDevice(self: *Encoder, allocator: std.mem.Allocator, entries: []const tree.Entry, options: options_module.Options, external: bool, limits: Limits) Error!void {
        self.* = .{ .working = working_module.WorkingAllocator.init(allocator, limits.max_working_memory) };
        self.initialize(entries, options, external) catch |err| {
            const mapped_error = self.failure(err);
            self.deinit();
            return mapped_error;
        };
    }

    fn initialize(self: *Encoder, entries: []const tree.Entry, options: options_module.Options, external: bool) Error!void {
        const allocator = self.working.allocator();
        self.plan = try plan_module.Plan.init(allocator, entries, options, external, true);
        const plan = &self.plan.?;
        const size = try math.alignForward(plan.metadata_end, block_size);
        self.metadata = try allocator.alloc(u8, size);
        @memset(self.metadata, 0);
        self.cursor = size;
        if (!plan.grouped) try plan.assignFixed();
        if (plan.chunks) |chunk_plan| {
            if (try chunk_plan.dataSize() / block_size > std.math.maxInt(u32)) return error.InvalidErofs;
        }
    }

    fn failure(self: *Encoder, err: anyerror) Error {
        if (err == error.OutOfMemory and self.working.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return @errorCast(err);
    }

    pub fn deinit(self: *Encoder) void {
        if (self.node) |*node| node.deinit();
        if (self.plan) |*plan| plan.deinit();
        self.working.allocator().free(self.metadata);
        std.debug.assert(self.working.live == 0);
        self.* = undefined;
    }

    pub fn result(self: *const Encoder) ?Result {
        return if (self.phase == .done) self.final_result else null;
    }

    pub fn read(self: *Encoder, output: []u8) Error!Progress {
        if (self.failed) |err| return err;
        return self.readInternal(output) catch |err| {
            const mapped_error = self.failure(err);
            self.failed = mapped_error;
            return mapped_error;
        };
    }

    fn beginNode(self: *Encoder) Error!void {
        const plan = &self.plan.?;
        const node = &plan.filesystem.nodes[self.node_index];
        if (self.pass == .metabox) try wire.populateMetaboxMetadata(&plan.filesystem, plan.options, if (plan.xattrs) |*attrs| attrs else null);
        if (plan.grouped) {
            if (self.cursor / block_size > std.math.maxInt(u32)) return error.InvalidErofs;
            node.start_block = @intCast(self.cursor / block_size);
        }
        self.node_base = if (node.start_block == no_block) self.cursor else @as(u64, node.start_block) * block_size;
        if (self.node_base > max_image_size) return error.InvalidErofs;
        const capacity = std.math.cast(usize, max_image_size - self.node_base) orelse std.math.maxInt(usize);
        self.expected_blocks = node.compressed_block_count;
        self.node = try node_module.Cursor.init(self.working.allocator(), node, if (plan.encoder) |*encoder| encoder else null, plan.options, capacity);
    }

    fn finishNode(self: *Encoder) Error!void {
        const plan = &self.plan.?;
        const node = &plan.filesystem.nodes[self.node_index];
        const written = self.node.?.written;
        if (written % block_size != 0) return error.InvalidErofs;
        if (node.compressed_indexes) |indexes| {
            if (!plan.grouped and node.compressed_block_count != self.expected_blocks) return error.InvalidErofs;
            if (written != 0) {
                const count = try clusters.blocksFor(try clusters.prefixLength(node));
                if (indexes.len < count) return error.InvalidErofs;
                for (indexes[0..count]) |*index| {
                    if (index.kind == 2) continue;
                    index.physical_block = std.math.add(u32, node.start_block, index.physical_block) catch return error.IntegerOverflow;
                }
            }
        }
        if (plan.grouped and written == 0) node.start_block = no_block;
        self.node.?.deinit();
        self.node = null;
        try wire.writeNodeMetadata(self.metadata, &plan.filesystem, self.node_index, plan.options, if (plan.xattrs) |*attrs| attrs else null);
        self.node_index += 1;
    }

    fn readNode(self: *Encoder, output: []u8) Error!?Progress {
        const plan = &self.plan.?;
        while (true) {
            if (self.node_index == plan.filesystem.nodes.len) {
                if (plan.grouped and self.pass == .normal) {
                    self.pass = .metabox;
                    self.node_index = 0;
                    continue;
                }
                self.phase = .chunks;
                return null;
            }
            const role = plan.filesystem.nodes[self.node_index].hidden_role;
            if ((plan.grouped and self.pass == .normal and role == .metabox) or (self.pass == .metabox and role != .metabox)) {
                self.node_index += 1;
                continue;
            }
            if (self.node == null) try self.beginNode();
            const position = self.node.?.written;
            if (try self.node.?.read(output)) |size| {
                const offset = std.math.add(u64, self.node_base, position) catch return error.IntegerOverflow;
                self.cursor = std.math.add(u64, self.node_base, self.node.?.written) catch return error.IntegerOverflow;
                return .{ .output_written = size, .offset = offset, .target = .image, .status = .need_output };
            }
            try self.finishNode();
        }
    }

    fn readChunks(self: *Encoder, output: []u8) Error!?Progress {
        const plan = &self.plan.?;
        const chunk_plan = if (plan.chunks) |*chunks| chunks else {
            self.phase = .metadata;
            return null;
        };
        const sources = chunk_plan.unique_sources orelse return error.InvalidErofs;
        if (self.chunk_index == sources.len) {
            self.phase = .metadata;
            return null;
        }
        const source = sources[self.chunk_index];
        var buffer: [4096]u8 = @splat(0);
        const size = @min(output.len, @min(buffer.len, chunk_plan.chunk_size - self.chunk_position));
        if (self.chunk_position < source.len) try plan.filesystem.nodes[source.node].readContent(try math.checkedAdd(source.offset, self.chunk_position), buffer[0..@min(size, source.len - self.chunk_position)]);
        const base: u64 = if (chunk_plan.external) 0 else @as(u64, chunk_plan.local_start_block) * block_size;
        const relative = std.math.mul(u64, self.chunk_index, chunk_plan.chunk_size) catch return error.IntegerOverflow;
        const offset = std.math.add(u64, base, std.math.add(u64, relative, self.chunk_position) catch return error.IntegerOverflow) catch return error.IntegerOverflow;
        const end = std.math.add(u64, offset, size) catch return error.IntegerOverflow;
        @memcpy(output[0..size], buffer[0..size]);
        self.chunk_position += size;
        if (self.chunk_position == chunk_plan.chunk_size) {
            self.chunk_position = 0;
            self.chunk_index += 1;
        }
        if (!chunk_plan.external) self.cursor = end;
        return .{ .output_written = size, .offset = offset, .target = if (chunk_plan.external) .device else .image, .status = .need_output };
    }

    fn prepareMetadata(self: *Encoder) Error!void {
        const plan = &self.plan.?;
        const size = if (plan.fixed_blocks) |blocks| std.math.mul(u64, blocks, block_size) catch return error.IntegerOverflow else self.cursor;
        if (size == 0 or size % block_size != 0 or size > max_image_size) return error.InvalidErofs;
        const device_size: u64 = if (plan.chunks) |chunks| if (chunks.external) try chunks.dataSize() else 0 else 0;
        try wire.writeSuperblock(self.metadata, plan.filesystem.nodes, @intCast(size / block_size), plan.options, plan.chunks, if (plan.xattrs) |*attrs| attrs else null);
        self.final_result = .{ .image_size = size, .device_size = device_size, .peak_working_bytes = self.working.peak };
        self.metadata_ready = true;
    }

    fn readInternal(self: *Encoder, output: []u8) Error!Progress {
        if (self.phase == .done) return .{ .output_written = 0, .offset = 0, .target = .image, .status = .done };
        if (output.len == 0) return .{ .output_written = 0, .offset = 0, .target = .image, .status = .need_output };
        while (true) {
            switch (self.phase) {
                .nodes => if (try self.readNode(output)) |progress| return progress,
                .chunks => if (try self.readChunks(output)) |progress| return progress,
                .metadata => {
                    if (!self.metadata_ready) try self.prepareMetadata();
                    const offset = self.metadata_position;
                    const size = @min(output.len, self.metadata.len - offset);
                    @memcpy(output[0..size], self.metadata[offset..][0..size]);
                    self.metadata_position += size;
                    if (self.metadata_position == self.metadata.len) self.phase = .done;
                    return .{ .output_written = size, .offset = offset, .target = .image, .status = if (self.phase == .done) .done else .need_output };
                },
                .done => return .{ .output_written = 0, .offset = 0, .target = .image, .status = .done },
            }
        }
    }
};
