const std = @import("std");
const core = @import("../core.zig");
const format = @import("format.zig");
const metadata_writer = @import("writer_metadata.zig");
const security = @import("writer_security.zig");
const streams = @import("writer_streams.zig");
const tree_mod = @import("writer_tree.zig");

pub const Error = core.Error || metadata_writer.Error || security.Error ||
    tree_mod.Error || std.mem.Allocator.Error || error{InvalidWimEntry};

pub const Entry = tree_mod.Entry;
pub const TaggedItem = tree_mod.TaggedItem;

pub const Image = struct {
    name: []const u8 = "Vort Image",
    entries: []const Entry,
    root_creation_time: u64 = 0,
    root_last_access_time: u64 = 0,
    root_last_write_time: u64 = 0,
    root_security_descriptor: ?[]const u8 = null,
    root_tagged_items: []const tree_mod.TaggedItem = &.{},
    creation_time: u64 = 0,
    last_modification_time: u64 = 0,
};

pub const Blob = struct {
    sha1: [std.crypto.hash.Sha1.digest_length]u8,
    data: []const u8,
    reference_count: u32,
    resource: format.ResourceHeader = undefined,
};

pub const PlannedImage = struct {
    tree: tree_mod.Tree,
    metadata: []u8,
    metadata_hash: [std.crypto.hash.Sha1.digest_length]u8,
    metadata_resource: format.ResourceHeader = undefined,
};

pub const Plan = struct {
    allocator: std.mem.Allocator,
    images: std.ArrayList(PlannedImage) = .empty,
    blobs: std.ArrayList(Blob) = .empty,

    pub fn init(
        allocator: std.mem.Allocator,
        source_images: []const Image,
    ) Error!Plan {
        var self = Plan{ .allocator = allocator };
        errdefer self.deinit();
        for (source_images) |image| {
            var tree = try tree_mod.build(allocator, image.entries, .{
                .creation_time = image.root_creation_time,
                .last_access_time = image.root_last_access_time,
                .last_write_time = image.root_last_write_time,
                .security_descriptor = image.root_security_descriptor,
                .tagged_items = image.root_tagged_items,
            });
            errdefer tree.deinit();
            var security_table = try security.plan(allocator, &tree);
            defer security_table.deinit();
            const metadata = try metadata_writer.encodeAlloc(
                allocator,
                &tree,
                security_table.descriptors,
            );
            errdefer allocator.free(metadata);
            var metadata_hash: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
            std.crypto.hash.Sha1.hash(metadata, &metadata_hash, .{});
            try self.images.append(allocator, .{
                .tree = tree,
                .metadata = metadata,
                .metadata_hash = metadata_hash,
            });
        }
        for (self.images.items) |image|
            try collectBlobs(allocator, &self.blobs, image.tree.nodes);
        return self;
    }

    pub fn deinit(self: *Plan) void {
        for (self.images.items) |*image| {
            self.allocator.free(image.metadata);
            image.tree.deinit();
        }
        self.images.deinit(self.allocator);
        self.blobs.deinit(self.allocator);
        self.* = undefined;
    }
};

pub fn deriveGuid(
    planned: []const PlannedImage,
    images: []const Image,
) [16]u8 {
    if (images.len == 1)
        return deriveSingleGuid(&planned[0].metadata_hash, images[0].name);
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update("vort deterministic multi-image WIM\x00");
    for (planned, images) |plan, image| {
        hasher.update(&plan.metadata_hash);
        var name_len: [8]u8 = undefined;
        std.mem.writeInt(u64, &name_len, image.name.len, .little);
        hasher.update(&name_len);
        hasher.update(image.name);
    }
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    hasher.final(&digest);
    return guidFromDigest(&digest);
}

fn deriveSingleGuid(
    metadata_hash: *const [std.crypto.hash.Sha1.digest_length]u8,
    image_name: []const u8,
) [16]u8 {
    var hasher = std.crypto.hash.Sha1.init(.{});
    hasher.update("vort deterministic WIM\x00");
    hasher.update(metadata_hash);
    hasher.update(image_name);
    var digest: [std.crypto.hash.Sha1.digest_length]u8 = undefined;
    hasher.final(&digest);
    return guidFromDigest(&digest);
}

fn guidFromDigest(digest: *const [std.crypto.hash.Sha1.digest_length]u8) [16]u8 {
    var guid: [16]u8 = undefined;
    @memcpy(&guid, digest[0..16]);
    guid[6] = (guid[6] & 0x0f) | 0x50;
    guid[8] = (guid[8] & 0x3f) | 0x80;
    return guid;
}

fn collectBlobs(
    allocator: std.mem.Allocator,
    blobs: *std.ArrayList(Blob),
    nodes: []const tree_mod.Node,
) Error!void {
    for (nodes) |node| {
        const stream_set = node.streamSet();
        if (stream_set.mainData()) |data| try collectBlob(allocator, blobs, data);
        var iterator = stream_set.extraStreams();
        while (iterator.next()) |stream|
            try collectBlob(allocator, blobs, stream.data);
    }
}

fn collectBlob(
    allocator: std.mem.Allocator,
    blobs: *std.ArrayList(Blob),
    data: []const u8,
) Error!void {
    if (data.len == 0) return;
    const sha1 = streams.hash(data);
    for (blobs.items) |*blob| {
        if (!std.mem.eql(u8, &blob.sha1, &sha1)) continue;
        if (!std.mem.eql(u8, blob.data, data)) return error.InvalidWimEntry;
        blob.reference_count = std.math.add(u32, blob.reference_count, 1) catch
            return error.IntegerOverflow;
        return;
    }
    try blobs.append(allocator, .{
        .sha1 = sha1,
        .data = data,
        .reference_count = 1,
    });
}
