//! Snapshot borrowed data that overlaps an output's retained allocation before
//! clearing, reserving, or writing that output. Unrelated data stays borrowed.
const std = @import("std");
const shared_dictionary = @import("../../shared_dictionary.zig");
const serialized_dictionary = @import("../../serialized_dictionary.zig");

pub const Error = std.mem.Allocator.Error || shared_dictionary.ValidationError || serialized_dictionary.Error;

/// Every owned slice and serialized view has a heap address independent of this
/// value's address. Moving a Snapshot transfers ownership without rebinding its
/// views. The supplied allocator and unaliased borrows must outlive the owner.
pub const Snapshot = struct {
    allocator: std.mem.Allocator,
    input: []const u8 = &.{},
    chunks: []const []const u8 = &.{},
    dictionary: shared_dictionary.Dictionary,
    input_storage: ?[]u8 = null,
    chunk_storage: SliceStorage = .{},
    raw_storage: SliceStorage = .{},
    serialized_view: ?*serialized_dictionary.Dictionary = null,
    serialized_storage: ?[]u8 = null,
    owned_bytes: usize = 0,

    /// `target_allocation` includes unused retained capacity, because a reserve
    /// may release it and a later write may overwrite bytes beyond current len.
    /// Initialization never changes that allocation or any borrowed descriptor.
    pub fn initInput(allocator: std.mem.Allocator, target_allocation: []const u8, input: []const u8, dictionary: shared_dictionary.Dictionary) Error!Snapshot {
        const required = try requiredInputBytes(target_allocation, input, dictionary);
        var result: Snapshot = .{ .allocator = allocator, .input = input, .dictionary = dictionary };
        errdefer result.deinit();
        if (overlaps(target_allocation, input)) {
            result.input_storage = try allocator.dupe(u8, input);
            result.input = result.input_storage.?;
            try result.addOwned(input.len);
        }
        try result.snapshotDictionary(target_allocation);
        std.debug.assert(result.owned_bytes == required);
        return result;
    }

    pub fn initChunks(allocator: std.mem.Allocator, target_allocation: []const u8, chunks: []const []const u8, dictionary: shared_dictionary.Dictionary) Error!Snapshot {
        const required = try requiredChunksBytes(target_allocation, chunks, dictionary);
        var result: Snapshot = .{ .allocator = allocator, .chunks = chunks, .dictionary = dictionary };
        errdefer result.deinit();
        result.chunk_storage = try SliceStorage.init(allocator, target_allocation, chunks);
        result.chunks = result.chunk_storage.view;
        try result.addOwned(result.chunk_storage.owned_bytes);
        try result.snapshotDictionary(target_allocation);
        std.debug.assert(result.owned_bytes == required);
        return result;
    }

    pub fn getInput(self: *const Snapshot) []const u8 {
        return self.input;
    }

    pub fn getChunks(self: *const Snapshot) []const []const u8 {
        return self.chunks;
    }

    pub fn getDictionary(self: *const Snapshot) shared_dictionary.Dictionary {
        return self.dictionary;
    }

    /// Exact live requested bytes, including owned descriptors and the stable
    /// serialized view. The caller may charge these to its shared HQ budget.
    pub fn ownedBytes(self: *const Snapshot) usize {
        return self.owned_bytes;
    }

    pub fn deinit(self: *Snapshot) void {
        if (self.input_storage) |bytes| self.allocator.free(bytes);
        self.chunk_storage.deinit(self.allocator);
        self.raw_storage.deinit(self.allocator);
        if (self.serialized_view) |view| self.allocator.destroy(view);
        if (self.serialized_storage) |bytes| self.allocator.free(bytes);
        self.* = undefined;
    }

    fn snapshotDictionary(self: *Snapshot, target_allocation: []const u8) Error!void {
        self.raw_storage = try SliceStorage.init(self.allocator, target_allocation, self.dictionary.raw_prefixes);
        self.dictionary.raw_prefixes = self.raw_storage.view;
        try self.addOwned(self.raw_storage.owned_bytes);
        const borrowed = self.dictionary.serialized orelse return;
        const backing_alias = overlaps(target_allocation, borrowed.encoded);
        const view_alias = overlaps(target_allocation, std.mem.asBytes(borrowed));
        if (!backing_alias and !view_alias) return;
        var encoded = borrowed.encoded;
        if (backing_alias) {
            self.serialized_storage = try self.allocator.dupe(u8, encoded);
            encoded = self.serialized_storage.?;
            try self.addOwned(encoded.len);
        }
        self.serialized_view = try self.allocator.create(serialized_dictionary.Dictionary);
        try self.addOwned(@sizeOf(serialized_dictionary.Dictionary));
        self.serialized_view.?.* = try serialized_dictionary.parse(encoded);
        self.dictionary.serialized = self.serialized_view.?;
    }

    fn addOwned(self: *Snapshot, bytes: usize) Error!void {
        self.owned_bytes = std.math.add(usize, self.owned_bytes, bytes) catch return error.IntegerOverflow;
    }
};

const SliceStorage = struct {
    view: []const []const u8 = &.{},
    descriptors: ?[][]const u8 = null,
    data: ?[]u8 = null,
    owned_bytes: usize = 0,

    const Required = struct { descriptor_bytes: usize, data_bytes: usize, total: usize };

    fn required(target_allocation: []const u8, slices: []const []const u8) Error!Required {
        const descriptor_bytes = std.math.mul(usize, slices.len, @sizeOf([]const u8)) catch return error.IntegerOverflow;
        const descriptor_memory = @as([*]const u8, @ptrCast(slices.ptr))[0..descriptor_bytes];
        var data_bytes: usize = 0;
        for (slices) |slice| {
            if (overlaps(target_allocation, slice))
                data_bytes = std.math.add(usize, data_bytes, slice.len) catch return error.IntegerOverflow;
        }
        return .{
            .descriptor_bytes = descriptor_bytes,
            .data_bytes = data_bytes,
            .total = if (data_bytes == 0 and !overlaps(target_allocation, descriptor_memory)) 0 else std.math.add(usize, descriptor_bytes, data_bytes) catch return error.IntegerOverflow,
        };
    }

    fn init(allocator: std.mem.Allocator, target_allocation: []const u8, slices: []const []const u8) Error!SliceStorage {
        const needed = try required(target_allocation, slices);
        if (needed.total == 0) return .{ .view = slices };
        var result: SliceStorage = .{ .owned_bytes = needed.total };
        errdefer result.deinit(allocator);
        result.descriptors = try allocator.dupe([]const u8, slices);
        result.view = result.descriptors.?;
        if (needed.data_bytes != 0) {
            result.data = try allocator.alloc(u8, needed.data_bytes);
            var offset: usize = 0;
            for (slices, result.descriptors.?) |slice, *descriptor| {
                if (!overlaps(target_allocation, slice)) continue;
                const copy = result.data.?[offset..][0..slice.len];
                @memcpy(copy, slice);
                descriptor.* = copy;
                offset += slice.len;
            }
            std.debug.assert(offset == needed.data_bytes);
        }
        return result;
    }

    fn deinit(self: *SliceStorage, allocator: std.mem.Allocator) void {
        if (self.data) |bytes| allocator.free(bytes);
        if (self.descriptors) |descriptors| allocator.free(descriptors);
        self.* = undefined;
    }
};

/// Predict exact heap storage without allocating or modifying borrowed data.
/// Compare this with the remaining HQ working-memory budget before initInput.
pub fn requiredInputBytes(target_allocation: []const u8, input: []const u8, dictionary: shared_dictionary.Dictionary) Error!usize {
    try dictionary.validate();
    return std.math.add(usize, if (overlaps(target_allocation, input)) input.len else 0, try requiredDictionaryBytes(target_allocation, dictionary)) catch return error.IntegerOverflow;
}

pub fn requiredChunksBytes(target_allocation: []const u8, chunks: []const []const u8, dictionary: shared_dictionary.Dictionary) Error!usize {
    try dictionary.validate();
    return std.math.add(usize, (try SliceStorage.required(target_allocation, chunks)).total, try requiredDictionaryBytes(target_allocation, dictionary)) catch return error.IntegerOverflow;
}

fn requiredDictionaryBytes(target_allocation: []const u8, dictionary: shared_dictionary.Dictionary) Error!usize {
    var bytes = (try SliceStorage.required(target_allocation, dictionary.raw_prefixes)).total;
    if (dictionary.serialized) |view| {
        const backing_alias = overlaps(target_allocation, view.encoded);
        if (backing_alias or overlaps(target_allocation, std.mem.asBytes(view))) {
            bytes = std.math.add(usize, bytes, @sizeOf(serialized_dictionary.Dictionary)) catch return error.IntegerOverflow;
            if (backing_alias) bytes = std.math.add(usize, bytes, view.encoded.len) catch return error.IntegerOverflow;
        }
    }
    return bytes;
}

/// Compare half-open memory ranges without adding lengths to addresses. Empty
/// ranges never overlap, even if their pointers fall inside the other range.
pub fn overlaps(left: []const u8, right: []const u8) bool {
    if (left.len == 0 or right.len == 0) return false;
    const a = @intFromPtr(left.ptr);
    const b = @intFromPtr(right.ptr);
    return if (a <= b) b - a < left.len else a - b < right.len;
}

test {
    _ = @import("alias_tests.zig");
}
