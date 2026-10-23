const std = @import("std");
const tree = @import("tree.zig");
const codec = @import("codec.zig");
const chunks = @import("chunks.zig");
const chunk_stream = @import("chunk_stream.zig");
const xattrs = @import("xattrs.zig");
const metabox = @import("metabox.zig");
const fragments = @import("fragments.zig");
const clusters = @import("clusters.zig");
const directories = @import("directories.zig");
const layout = @import("layout.zig");
const math = @import("math.zig");
const options_module = @import("options.zig");
const wire = @import("wire.zig");
pub const Error = tree.Error || codec.Error || chunks.Error || chunk_stream.Error || xattrs.Error || metabox.Error || fragments.Error || clusters.Error || directories.Error || layout.Error || wire.Error || math.Error;
const Options = options_module.Options;
const block_size: usize = 4096;
const writer_clusters = clusters;

pub fn validate(options: Options, external_chunks: bool) Error!bool {
    if (options.volume_name.len > 16 or options.fixed_nsec >= 1_000_000_000)
        return error.InvalidErofs;
    if (options.compression_extent_size < block_size or
        options.compression_extent_size > writer_clusters.max_extent_size or
        !std.math.isPowerOfTwo(options.compression_extent_size) or
        (options.compression == .stored and options.compression_extent_size != block_size))
        return error.InvalidErofs;
    if (options.max_pcluster_size) |capacity| {
        if (capacity < block_size or capacity > writer_clusters.max_extent_size or
            capacity % block_size != 0 or options.compression == .stored)
            return error.InvalidErofs;
    }
    const grouped = options.compression_extent_size > block_size or options.max_pcluster_size != null;
    if (options.tail_packing != .none and options.compression == .stored)
        return error.InvalidErofs;
    if (options.compress_directories and options.compression == .stored)
        return error.InvalidErofs;
    if (options.directory_metadata_zone and options.compress_directories)
        return error.InvalidErofs;
    if (options.chunk_size != null and
        (options.compression != .stored or options.tail_packing != .none or
            options.compress_directories))
        return error.InvalidErofs;
    if (options.metabox and
        (options.tail_packing != .none or options.chunk_size != null or external_chunks))
        return error.InvalidErofs;
    if (external_chunks and options.chunk_size == null) return error.InvalidErofs;

    return grouped;
}

pub const Plan = struct {
    filesystem: tree.Tree,
    options: Options,
    grouped: bool,
    metadata_end: usize = 0,
    encoder: ?codec.Encoder = null,
    chunks: ?chunks.Plan = null,
    xattrs: ?xattrs.Plan = null,
    fixed_blocks: ?usize = null,

    pub fn init(allocator: std.mem.Allocator, entries: []const tree.Entry, options: Options, external: bool, descriptors: bool) Error!Plan {
        const grouped = try validate(options, external);
        var plan = Plan{ .filesystem = try tree.build(allocator, entries, options.root_xattrs), .options = options, .grouped = grouped };
        errdefer plan.deinit();
        const filesystem = &plan.filesystem;
        filesystem.nodes[0].mode = options.root_mode;
        filesystem.nodes[0].uid = options.root_uid;
        filesystem.nodes[0].gid = options.root_gid;
        filesystem.nodes[0].modification_time = options.root_modification_time;
        filesystem.nodes[0].modification_nsec = options.root_modification_nsec;
        if (options.metabox) try metabox.prepare(allocator, filesystem);
        try directories.allocateDirectoryBuffers(filesystem);
        if (options.tail_packing == .fragments or options.compress_directories)
            try fragments.prepare(allocator, filesystem, block_size, .{ .file_tails = options.tail_packing == .fragments, .directories = options.compress_directories });
        if (options.chunk_size) |size| plan.chunks = if (descriptors) try chunk_stream.prepare(allocator, filesystem, size, external) else try chunks.prepare(allocator, filesystem, size, external);
        if (options.shared_xattrs) plan.xattrs = try xattrs.prepare(allocator, filesystem.nodes, options.xattr_prefixes);
        if (options.compression != .stored) plan.encoder = try codec.Encoder.init(allocator, options.compression);
        if (grouped and options.compression == .zstandard) plan.encoder.?.zstandard_window_log = 15;
        plan.metadata_end = try layout.planMetadata(allocator, filesystem, options, if (plan.encoder) |*encoder| encoder else null, plan.chunks != null and external and plan.chunks.?.active(), if (plan.xattrs) |*attrs| attrs else null);
        try directories.fillDirectories(allocator, filesystem);
        try fragments.syncDirectories(filesystem);
        return plan;
    }

    pub fn deinit(self: *Plan) void {
        if (self.encoder) |*encoder| encoder.deinit();
        if (self.xattrs) |*attrs| attrs.deinit();
        if (self.chunks) |*chunk_plan| chunk_plan.deinit();
        self.filesystem.deinit();
        self.* = undefined;
    }

    pub fn assignFixed(self: *Plan) Error!void {
        var count = try layout.assignDataBlocks(&self.filesystem, try math.alignForward(self.metadata_end, block_size) / block_size, false);
        if (self.chunks) |*chunk_plan| count = try chunk_plan.assign(self.filesystem.nodes, count);
        if (count == 0 or count > std.math.maxInt(u32)) return error.InvalidErofs;
        self.fixed_blocks = count;
    }
};
