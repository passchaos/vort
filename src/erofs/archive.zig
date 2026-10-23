const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const codec = @import("codec.zig");
const chunk = @import("chunk.zig");
const extent_reader = @import("extent.zig");
const xattr = @import("xattr.zig");
const reader_xattrs = @import("reader/xattrs.zig");
const reader_types = @import("reader/types.zig");
const metadata_reader = @import("reader/inode.zig");
const directory_reader = @import("reader/directory.zig");
const directory_stream = @import("reader/directory_stream.zig");
const stream = @import("reader/stream.zig");
const reader_context = @import("reader/context.zig");
const devices_reader = @import("reader/devices.zig");
const byte_sink = @import("../io/sink.zig");
const prefix_table = @import("reader/prefix_table.zig");

pub const Error = prefix_table.Error || stream.Error || directory_stream.Error || byte_sink.Error || metadata_reader.Error || core.Error || format.Error || codec.Error || chunk.Error || extent_reader.Error || xattr.Error ||
    std.mem.Allocator.Error || error{
    InvalidErofs,
    ErofsEntryNotFound,
    ErofsNotDirectory,
    ErofsNotRegularFile,
    ErofsMissingMetabox,
};

pub const Xattr = xattr.Attribute;
pub const Xattrs = xattr.Attributes;
pub const default_packed_extent_limit: usize = 8 * 1024 * 1024;

pub const ReadLimits = struct {
    max_output_len: usize,
    max_packed_extent_len: usize = default_packed_extent_limit,
};

pub const XattrReadLimits = struct {
    max_count: usize,
    max_total_bytes: usize,
    max_packed_extent_len: usize = default_packed_extent_limit,
};

pub const DeviceInfo = chunk.DeviceInfo;
pub const Extractor = stream.Reader;
pub const DirectoryIterator = directory_stream.Reader;

pub const Inode = reader_types.Inode;
pub const DirectoryEntry = reader_types.DirectoryEntry;
pub const Directory = reader_types.Directory;

pub const LoadedMetaboxArchive = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    archive: Archive,

    pub fn deinit(self: *LoadedMetaboxArchive) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    devices: []const []const u8 = &.{},
    metabox_bytes: ?[]const u8 = null,
    superblock: format.Superblock,

    pub fn init(bytes: []const u8) Error!Archive {
        return initWithDevices(bytes, &.{});
    }

    pub fn initWithDevices(
        bytes: []const u8,
        devices: []const []const u8,
    ) Error!Archive {
        const superblock = try format.parseSuperblock(bytes);
        if (prefix_table.isPrimary(superblock))
            try xattr.validatePrefixTable(
                bytes,
                superblock.xattr_prefix_start,
                superblock.xattr_prefix_count,
            );
        const result = Archive{
            .bytes = bytes,
            .devices = devices,
            .superblock = superblock,
        };
        try chunk.validateDevices(bytes, devices, superblock);
        return result;
    }

    pub fn loadMetaboxAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_metabox_len: usize,
        max_packed_extent_len: usize,
    ) Error!LoadedMetaboxArchive {
        if (self.superblock.feature_incompat & format.feature_incompat_metabox == 0 or
            self.superblock.metabox_nid == 0 or self.metabox_bytes != null)
            return error.InvalidErofs;
        const inode_value = try self.inode(self.superblock.metabox_nid);
        if (try inode_value.fileType() != .regular) return error.InvalidErofs;
        const bytes = try self.readFlatAllocWithLimits(allocator, inode_value, .{
            .max_output_len = max_metabox_len,
            .max_packed_extent_len = max_packed_extent_len,
        });
        errdefer allocator.free(bytes);
        var loaded = self;
        loaded.metabox_bytes = bytes;
        if (self.superblock.xattr_prefix_count != 0 and
            self.superblock.feature_compat & format.feature_compat_plain_xattr_prefixes == 0)
            try xattr.validatePrefixTable(
                bytes,
                self.superblock.xattr_prefix_start,
                self.superblock.xattr_prefix_count,
            );
        return .{ .allocator = allocator, .bytes = bytes, .archive = loaded };
    }

    pub fn deviceInfo(self: Archive, index: usize) Error!DeviceInfo {
        return chunk.deviceInfo(self.bytes, self.superblock, index);
    }

    fn metadataBytes(self: Archive, inode_value: Inode) Error![]const u8 {
        return if (inode_value.in_metabox)
            self.metabox_bytes orelse error.ErofsMissingMetabox
        else
            self.bytes;
    }

    pub fn rootInode(self: Archive) Error!Inode {
        return self.inode(self.superblock.root_nid);
    }

    fn inodeReader(self: Archive) metadata_reader.Reader {
        return .{
            .superblock = self.superblock,
            .primary = .{ .slice = self.bytes },
            .metabox = if (self.metabox_bytes) |bytes| .{ .slice = bytes } else null,
        };
    }

    pub fn inode(self: Archive, nid: u64) Error!Inode {
        return self.inodeReader().inode(nid);
    }

    pub fn readXattrsAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        max_count: usize,
        max_total_bytes: usize,
    ) Error!Xattrs {
        return self.readXattrsAllocWithLimits(allocator, inode_value, .{ .max_count = max_count, .max_total_bytes = max_total_bytes });
    }

    pub fn readXattrsAllocWithLimits(self: Archive, allocator: std.mem.Allocator, inode_value: Inode, limits: XattrReadLimits) Error!Xattrs {
        const ibody_start = std.math.add(
            usize,
            inode_value.location,
            inode_value.inode_size,
        ) catch return error.IntegerOverflow;
        const metadata = try self.metadataBytes(inode_value);
        var prefix = try prefix_table.Table.init(self.context(allocator, .{ .max_output_len = 0, .max_packed_extent_len = limits.max_packed_extent_len }));
        defer prefix.deinit(allocator);
        const shared_metadata = if (self.superblock.feature_compat &
            format.feature_compat_shared_xattrs_in_metabox != 0)
            self.metabox_bytes orelse return error.ErofsMissingMetabox
        else
            self.bytes;
        return reader_xattrs.readAllocLimited(
            allocator,
            allocator,
            prefix.input,
            .{ .slice = shared_metadata },
            .{ .slice = metadata },
            self.superblock.block_size,
            self.superblock.xattr_block,
            prefix.start,
            prefix.count,
            ibody_start,
            inode_value.xattr_size,
            limits.max_count,
            limits.max_total_bytes,
        );
    }

    fn context(self: Archive, allocator: std.mem.Allocator, limits: ReadLimits) reader_context.Context {
        return .{
            .allocator = allocator,
            .reader = self.inodeReader(),
            .devices = .{ .slices = .{ .primary = .{ .slice = self.bytes }, .devices = self.devices, .superblock = self.superblock } },
            .limits = .{ .max_encoded_extent_size = std.math.maxInt(usize), .max_decoded_extent_size = std.math.maxInt(usize), .max_packed_extent_size = limits.max_packed_extent_len },
        };
    }

    pub fn initRangeExtractor(self: Archive, allocator: std.mem.Allocator, value: Inode, start: usize, size: usize, limits: ReadLimits) Error!Extractor {
        if (size > limits.max_output_len) return error.OutputLimitExceeded;
        return stream.Reader.init(self.context(allocator, limits), value, start, size);
    }

    pub fn initExtractor(self: Archive, allocator: std.mem.Allocator, value: Inode, limits: ReadLimits) Error!Extractor {
        return self.initRangeExtractor(allocator, value, 0, value.file_size, limits);
    }

    pub fn initPathExtractor(self: Archive, allocator: std.mem.Allocator, path: []const u8, limits: ReadLimits, max_directory_size: usize) Error!Extractor {
        const value = try self.lookup(allocator, path, limits.max_output_len, max_directory_size);
        const file_type = try value.fileType();
        if (file_type != .regular and file_type != .symlink) return error.ErofsNotRegularFile;
        return self.initExtractor(allocator, value, limits);
    }

    pub fn initDirectoryIterator(self: Archive, allocator: std.mem.Allocator, value: Inode, max_size: usize) Error!DirectoryIterator {
        return directory_stream.Reader.init(self.context(allocator, .{ .max_output_len = max_size }), value, max_size);
    }

    pub fn readRangeToSink(self: Archive, allocator: std.mem.Allocator, value: Inode, start: usize, size: usize, sink: byte_sink.Sink, limits: ReadLimits) Error!usize {
        if (sink.max_write_size == 0) return error.SinkWriteFailed;
        var extractor = try self.initRangeExtractor(allocator, value, start, size, limits);
        defer extractor.deinit();
        var buffer: [64 * 1024]u8 = undefined;
        while (true) {
            const progress = try extractor.read(&buffer);
            if (progress.output_written != 0) try sink.writeExact(progress.position - progress.output_written, buffer[0..progress.output_written]);
            if (progress.status == .done) break;
        }
        try sink.finish(size);
        return size;
    }

    pub fn readToSink(self: Archive, allocator: std.mem.Allocator, value: Inode, sink: byte_sink.Sink, limits: ReadLimits) Error!usize {
        return self.readRangeToSink(allocator, value, 0, value.file_size, sink, limits);
    }

    pub fn readFlatAllocLimited(self: Archive, allocator: std.mem.Allocator, value: Inode, max_output_len: usize) Error![]u8 {
        return self.readFlatAllocWithLimits(allocator, value, .{ .max_output_len = max_output_len });
    }

    pub fn readFlatAllocWithLimits(self: Archive, allocator: std.mem.Allocator, value: Inode, limits: ReadLimits) Error![]u8 {
        if (value.file_size > limits.max_output_len) return error.OutputLimitExceeded;
        var output = byte_sink.BufferSink.init(allocator);
        defer output.deinit();
        _ = self.readRangeToSink(allocator, value, 0, value.file_size, output.sink(), limits) catch |err| {
            if (err == error.SinkWriteFailed and output.allocation_failed) return error.OutOfMemory;
            return err;
        };
        return output.take();
    }

    pub fn readDirectoryAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        inode_value: Inode,
        max_directory_bytes: usize,
    ) Error!Directory {
        if (try inode_value.fileType() != .directory) return error.ErofsNotDirectory;
        const bytes = try self.readFlatAllocLimited(
            allocator,
            inode_value,
            max_directory_bytes,
        );
        errdefer allocator.free(bytes);
        return directory_reader.parseOwned(allocator, bytes, self.superblock.block_size);
    }

    pub fn lookup(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_file_size: usize,
        max_directory_bytes: usize,
    ) Error!Inode {
        var current = try self.rootInode();
        var components = std.mem.tokenizeScalar(u8, path, '/');
        while (components.next()) |component| {
            if (!validName(component)) return error.InvalidErofs;
            var directory = try self.initDirectoryIterator(allocator, current, max_directory_bytes);
            defer directory.deinit();
            var found: ?u64 = null;
            while (try directory.next()) |entry| if (std.mem.eql(u8, entry.name, component)) {
                found = entry.nid;
            };
            current = try self.inode(found orelse return error.ErofsEntryNotFound);
            if (current.file_size > max_file_size and
                (try current.fileType() == .regular or try current.fileType() == .symlink))
                return error.OutputLimitExceeded;
        }
        return current;
    }

    pub fn extractByPathAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        max_output_len: usize,
        max_directory_bytes: usize,
    ) Error![]u8 {
        return self.extractByPathAllocWithLimits(
            allocator,
            path,
            .{ .max_output_len = max_output_len },
            max_directory_bytes,
        );
    }

    pub fn extractByPathAllocWithLimits(
        self: Archive,
        allocator: std.mem.Allocator,
        path: []const u8,
        limits: ReadLimits,
        max_directory_bytes: usize,
    ) Error![]u8 {
        const target = try self.lookup(
            allocator,
            path,
            limits.max_output_len,
            max_directory_bytes,
        );
        const file_type = try target.fileType();
        if (file_type != .regular and file_type != .symlink)
            return error.ErofsNotRegularFile;
        return self.readFlatAllocWithLimits(allocator, target, limits);
    }
};

fn validName(name: []const u8) bool {
    return directory_reader.validName(name);
}
