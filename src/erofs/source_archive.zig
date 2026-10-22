const std = @import("std");
const archive_module = @import("archive.zig");
const source_module = @import("../io/source.zig");
const sink_module = @import("../io/sink.zig");
const working_module = @import("../io/working_allocator.zig");
const input_module = @import("reader/input.zig");
const metadata = @import("reader/inode.zig");
const superblock = @import("reader/superblock.zig");
const devices_module = @import("reader/devices.zig");
const context_module = @import("reader/context.zig");
const stream = @import("reader/stream.zig");
const directory = @import("reader/directory.zig");
const types = @import("reader/types.zig");
const xattr = @import("xattr.zig");
const source_xattrs = @import("reader/xattrs.zig");
const format = @import("format.zig");

pub const Error = stream.Error || sink_module.Error || source_xattrs.Error || directory.Error || error{
    ErofsNotDirectory,
    ErofsEntryNotFound,
    ErofsNotRegularFile,
    WorkingMemoryLimitExceeded,
};
pub const Limits = struct {
    max_working_memory: usize = 64 * 1024 * 1024,
    max_metabox_size: usize = 64 * 1024 * 1024,
    max_encoded_extent_size: usize = 8 * 1024 * 1024,
    max_decoded_extent_size: usize = 8 * 1024 * 1024,
    load_metabox: bool = true,
};
pub const ReadLimits = archive_module.ReadLimits;
pub const ReadResult = struct { decoded_size: u64, peak_working_bytes: usize };
pub const ExtractProgress = stream.Progress;

/// Owns only bounded metabox metadata and working-allocation accounting.
/// Source contexts and device arrays remain borrowed and stable for its lifetime.
pub const SourceArchive = struct {
    source: source_module.Source,
    devices: []const source_module.Source,
    superblock: format.Superblock,
    limits: Limits,
    working: working_module.WorkingAllocator,
    metabox_bytes: ?[]u8 = null,
    active_extractors: usize = 0,

    pub fn init(allocator: std.mem.Allocator, source: source_module.Source, limits: Limits) Error!SourceArchive {
        return initWithDevices(allocator, source, &.{}, limits);
    }

    pub fn initWithDevices(allocator: std.mem.Allocator, source: source_module.Source, devices: []const source_module.Source, limits: Limits) Error!SourceArchive {
        if (source.max_read_size == 0) return error.SourceReadFailed;
        for (devices) |device| if (device.max_read_size == 0) return error.SourceReadFailed;
        const header = try superblock.read(.{ .source = source });
        var primary = source;
        primary.len = try header.imageSize64();
        var owner = SourceArchive{ .source = primary, .devices = devices, .superblock = header, .limits = limits, .working = working_module.WorkingAllocator.init(allocator, limits.max_working_memory) };
        errdefer owner.deinit();
        try owner.deviceReader().validate();
        if (header.feature_compat & format.feature_compat_plain_xattr_prefixes != 0 or header.xattr_prefix_count == 0)
            try xattr.validatePrefixTableInput(.{ .source = primary }, header.xattr_prefix_start, header.xattr_prefix_count);
        if (limits.load_metabox and header.metabox_nid != 0) try owner.loadMetabox();
        return owner;
    }

    pub fn deinit(self: *SourceArchive) void {
        std.debug.assert(self.active_extractors == 0);
        if (self.metabox_bytes) |bytes| self.working.allocator().free(bytes);
        std.debug.assert(self.working.live == 0);
        self.* = undefined;
    }

    pub fn peakWorkingBytes(self: *const SourceArchive) usize {
        return self.working.peak;
    }

    fn begin(self: *SourceArchive) void {
        self.working.last_failure_was_limit = false;
    }

    fn failure(self: *SourceArchive, err: anyerror) Error {
        if (err == error.OutOfMemory and self.working.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return @errorCast(err);
    }

    fn reader(self: *const SourceArchive) metadata.Reader {
        return .{ .superblock = self.superblock, .primary = .{ .source = self.source }, .metabox = if (self.metabox_bytes) |bytes| .{ .slice = bytes } else null };
    }

    fn deviceReader(self: *const SourceArchive) devices_module.Devices(source_module.Source) {
        return .{ .primary = .{ .source = self.source }, .devices = self.devices, .superblock = self.superblock };
    }

    fn context(self: *SourceArchive, limits: ReadLimits) context_module.Context {
        return .{ .allocator = self.working.allocator(), .reader = self.reader(), .devices = self.deviceReader(), .limits = .{ .max_encoded_extent_size = self.limits.max_encoded_extent_size, .max_decoded_extent_size = self.limits.max_decoded_extent_size, .max_packed_extent_size = limits.max_packed_extent_len } };
    }

    pub fn inode(self: *const SourceArchive, nid: u64) Error!types.Inode {
        return self.reader().inode(nid);
    }

    pub fn rootInode(self: *const SourceArchive) Error!types.Inode {
        return self.inode(self.superblock.root_nid);
    }

    pub fn deviceInfo(self: *const SourceArchive, index: usize) Error!types.DeviceInfo {
        return self.deviceReader().info(index);
    }

    fn initRangeExtractorInternal(self: *SourceArchive, value: types.Inode, start: usize, size: usize, limits: ReadLimits) Error!Extractor {
        if (size > limits.max_output_len) return error.OutputLimitExceeded;
        const state = try stream.Reader.init(self.context(limits), value, start, size);
        self.active_extractors = std.math.add(usize, self.active_extractors, 1) catch return error.IntegerOverflow;
        return .{ .archive = self, .state = state };
    }

    /// The archive and borrowed Sources must stay at stable addresses until
    /// the extractor is deinitialized, including after done or failure.
    pub fn initRangeExtractor(self: *SourceArchive, value: types.Inode, start: usize, size: usize, limits: ReadLimits) Error!Extractor {
        self.begin();
        return self.initRangeExtractorInternal(value, start, size, limits) catch |err| self.failure(err);
    }

    pub fn initExtractor(self: *SourceArchive, value: types.Inode, limits: ReadLimits) Error!Extractor {
        return self.initRangeExtractor(value, 0, value.file_size, limits);
    }

    pub fn initPathExtractor(self: *SourceArchive, path: []const u8, limits: ReadLimits, max_directory_size: usize) Error!Extractor {
        self.begin();
        const value = self.lookupInternal(path, limits.max_output_len, max_directory_size) catch |err| return self.failure(err);
        const file_type = try value.fileType();
        if (file_type != .regular and file_type != .symlink) return error.ErofsNotRegularFile;
        return self.initRangeExtractorInternal(value, 0, value.file_size, limits) catch |err| self.failure(err);
    }

    pub fn loadMetabox(self: *SourceArchive) Error!void {
        self.begin();
        return self.loadMetaboxInternal() catch |err| self.failure(err);
    }

    fn loadMetaboxInternal(self: *SourceArchive) Error!void {
        if (self.superblock.metabox_nid == 0 or self.metabox_bytes != null) return error.InvalidErofs;
        const value = try self.inode(self.superblock.metabox_nid);
        if (try value.fileType() != .regular) return error.InvalidErofs;
        if (value.file_size > self.limits.max_metabox_size) return error.OutputLimitExceeded;
        const allocator = self.working.allocator();
        const bytes = try allocator.alloc(u8, value.file_size);
        errdefer allocator.free(bytes);
        var output = FixedSink{ .bytes = bytes };
        _ = try self.readRangeInternal(value, 0, value.file_size, output.sink(), .{ .max_output_len = self.limits.max_metabox_size });
        if (self.superblock.xattr_prefix_count != 0 and self.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes == 0)
            try xattr.validatePrefixTableInput(.{ .slice = bytes }, self.superblock.xattr_prefix_start, self.superblock.xattr_prefix_count);
        self.metabox_bytes = bytes;
    }

    fn readRangeInternal(self: *SourceArchive, value: types.Inode, start: usize, size: usize, sink: sink_module.Sink, limits: ReadLimits) Error!ReadResult {
        if (sink.max_write_size == 0) return error.SinkWriteFailed;
        if (size > limits.max_output_len) return error.OutputLimitExceeded;
        var reader_state = try stream.Reader.init(self.context(limits), value, start, size);
        defer reader_state.deinit();
        var buffer: [64 * 1024]u8 = undefined;
        while (true) {
            const progress = try reader_state.read(&buffer);
            if (progress.output_written != 0) try sink.writeExact(progress.position - progress.output_written, buffer[0..progress.output_written]);
            if (progress.status == .done) break;
        }
        try sink.finish(size);
        return .{ .decoded_size = size, .peak_working_bytes = self.working.peak };
    }

    pub fn readRangeToSink(self: *SourceArchive, value: types.Inode, start: usize, size: usize, sink: sink_module.Sink, limits: ReadLimits) Error!ReadResult {
        self.begin();
        return self.readRangeInternal(value, start, size, sink, limits) catch |err| self.failure(err);
    }

    pub fn readToSink(self: *SourceArchive, value: types.Inode, sink: sink_module.Sink, limits: ReadLimits) Error!ReadResult {
        return self.readRangeToSink(value, 0, value.file_size, sink, limits);
    }

    fn readAllocInternal(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, limits: ReadLimits) Error![]u8 {
        var output = sink_module.BufferSink.init(allocator);
        defer output.deinit();
        _ = self.readRangeInternal(value, 0, value.file_size, output.sink(), limits) catch |err| {
            if (err == error.SinkWriteFailed and output.allocation_failed) return error.OutOfMemory;
            return err;
        };
        return output.take();
    }

    /// The returned caller-owned buffer is outside the working-memory budget.
    pub fn readFlatAllocWithLimits(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, limits: ReadLimits) Error![]u8 {
        self.begin();
        return self.readAllocInternal(allocator, value, limits) catch |err| self.failure(err);
    }

    pub fn readFlatAllocLimited(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, max_output_len: usize) Error![]u8 {
        return self.readFlatAllocWithLimits(allocator, value, .{ .max_output_len = max_output_len });
    }

    fn readDirectoryInternal(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, max_size: usize) Error!types.Directory {
        if (try value.fileType() != .directory) return error.ErofsNotDirectory;
        const bytes = try self.readAllocInternal(allocator, value, .{ .max_output_len = max_size });
        errdefer allocator.free(bytes);
        return directory.parseOwned(allocator, bytes, self.superblock.block_size);
    }

    pub fn readDirectoryAlloc(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, max_size: usize) Error!types.Directory {
        self.begin();
        return self.readDirectoryInternal(allocator, value, max_size) catch |err| self.failure(err);
    }

    fn lookupInternal(self: *SourceArchive, path: []const u8, max_file_size: usize, max_directory_size: usize) Error!types.Inode {
        var current = try self.rootInode();
        var components = std.mem.tokenizeScalar(u8, path, '/');
        while (components.next()) |component| {
            if (!directory.validName(component)) return error.InvalidErofs;
            var listing = try self.readDirectoryInternal(self.working.allocator(), current, max_directory_size);
            defer listing.deinit();
            const entry = listing.find(component) orelse return error.ErofsEntryNotFound;
            current = try self.inode(entry.nid);
            if (current.file_size > max_file_size and (try current.fileType() == .regular or try current.fileType() == .symlink)) return error.OutputLimitExceeded;
        }
        return current;
    }

    pub fn lookup(self: *SourceArchive, path: []const u8, max_file_size: usize, max_directory_size: usize) Error!types.Inode {
        self.begin();
        return self.lookupInternal(path, max_file_size, max_directory_size) catch |err| self.failure(err);
    }

    fn extractByPathInternal(self: *SourceArchive, path: []const u8, sink: sink_module.Sink, limits: ReadLimits, max_directory_size: usize) Error!ReadResult {
        if (sink.max_write_size == 0) return error.SinkWriteFailed;
        const value = try self.lookupInternal(path, limits.max_output_len, max_directory_size);
        const file_type = try value.fileType();
        if (file_type != .regular and file_type != .symlink) return error.ErofsNotRegularFile;
        return self.readRangeInternal(value, 0, value.file_size, sink, limits);
    }

    pub fn extractByPathToSink(self: *SourceArchive, path: []const u8, sink: sink_module.Sink, limits: ReadLimits, max_directory_size: usize) Error!ReadResult {
        self.begin();
        return self.extractByPathInternal(path, sink, limits, max_directory_size) catch |err| self.failure(err);
    }

    pub fn extractByPathAllocWithLimits(self: *SourceArchive, allocator: std.mem.Allocator, path: []const u8, limits: ReadLimits, max_directory_size: usize) Error![]u8 {
        self.begin();
        var output = sink_module.BufferSink.init(allocator);
        defer output.deinit();
        _ = self.extractByPathInternal(path, output.sink(), limits, max_directory_size) catch |err| {
            if (err == error.SinkWriteFailed and output.allocation_failed) return self.failure(error.OutOfMemory);
            return self.failure(err);
        };
        return output.take() catch |err| self.failure(err);
    }

    pub fn extractByPathAllocLimited(self: *SourceArchive, allocator: std.mem.Allocator, path: []const u8, max_output_len: usize, max_directory_size: usize) Error![]u8 {
        return self.extractByPathAllocWithLimits(allocator, path, .{ .max_output_len = max_output_len }, max_directory_size);
    }

    pub fn readXattrsAllocLimited(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, max_count: usize, max_total_bytes: usize) Error!xattr.Attributes {
        self.begin();
        return self.readXattrsInternal(allocator, value, max_count, max_total_bytes) catch |err| self.failure(err);
    }

    fn readXattrsInternal(self: *SourceArchive, allocator: std.mem.Allocator, value: types.Inode, max_count: usize, max_total_bytes: usize) Error!xattr.Attributes {
        const ibody_start = try context_module.add(value.location, value.inode_size);
        const ibody = try self.reader().metadataInput(value);
        const prefix: input_module.Input = if (self.superblock.xattr_prefix_count == 0 or self.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes != 0) .{ .source = self.source } else .{ .slice = self.metabox_bytes orelse return error.ErofsMissingMetabox };
        const shared: input_module.Input = if (self.superblock.feature_compat & format.feature_compat_shared_xattrs_in_metabox != 0) .{ .slice = self.metabox_bytes orelse return error.ErofsMissingMetabox } else .{ .source = self.source };
        return source_xattrs.readAllocLimited(self.working.allocator(), allocator, prefix, shared, ibody, self.superblock.block_size, self.superblock.xattr_block, self.superblock.xattr_prefix_start, self.superblock.xattr_prefix_count, ibody_start, value.xattr_size, max_count, max_total_bytes);
    }
};

/// Resumable caller-owned extraction. Errors are sticky and leave the current
/// output buffer unchanged. position() counts bytes delivered by earlier reads.
pub const Extractor = struct {
    archive: *SourceArchive,
    state: stream.Reader,
    failed: ?Error = null,

    pub fn read(self: *Extractor, output: []u8) Error!ExtractProgress {
        if (self.failed) |err| return err;
        self.archive.begin();
        return self.state.read(output) catch |err| {
            const failure = self.archive.failure(err);
            self.failed = failure;
            return failure;
        };
    }

    pub fn position(self: *const Extractor) usize {
        return self.state.position;
    }

    pub fn deinit(self: *Extractor) void {
        self.state.deinit();
        std.debug.assert(self.archive.active_extractors != 0);
        self.archive.active_extractors -= 1;
        self.* = undefined;
    }
};

const FixedSink = struct {
    bytes: []u8,
    fn sink(self: *FixedSink) sink_module.Sink {
        return .{ .context = self, .write_at = writeAt, .set_len = setLen };
    }
    fn writeAt(raw: *anyopaque, offset: u64, input: []const u8) error{SinkWriteFailed}!usize {
        const self: *FixedSink = @ptrCast(@alignCast(raw));
        const start = std.math.cast(usize, offset) orelse return error.SinkWriteFailed;
        if (start > self.bytes.len or input.len > self.bytes.len - start) return error.SinkWriteFailed;
        @memcpy(self.bytes[start..][0..input.len], input);
        return input.len;
    }
    fn setLen(raw: *anyopaque, length: u64) error{SinkWriteFailed}!void {
        const self: *FixedSink = @ptrCast(@alignCast(raw));
        if (length != self.bytes.len) return error.SinkWriteFailed;
    }
};
