const std = @import("std");

pub const Snapshot = struct {
    bytes: []const u8,
    owned: ?[]u8 = null,

    pub fn deinit(self: Snapshot, allocator: std.mem.Allocator) void {
        if (self.owned) |bytes| allocator.free(bytes);
    }
};

/// Compare against the allocation, not just initialized ArrayList.items: an
/// input may legitimately borrow initialized spare capacity. Check arithmetic
/// before touching input bytes or requesting its alias snapshot.
pub fn overlaps(input: []const u8, output: *const std.ArrayList(u8)) error{IntegerOverflow}!bool {
    if (input.len == 0 or output.capacity == 0) return false;
    const input_start = @intFromPtr(input.ptr);
    const output_start = @intFromPtr(output.items.ptr);
    const input_end = std.math.add(usize, input_start, input.len) catch return error.IntegerOverflow;
    const output_end = std.math.add(usize, output_start, output.capacity) catch return error.IntegerOverflow;
    return input_start < output_end and output_start < input_end;
}

/// Called after options validation and before any output write. Nonaliased
/// plaintext stays borrowed and incurs no allocation or copy.
pub fn preserve(allocator: std.mem.Allocator, input: []const u8, output: *const std.ArrayList(u8)) !Snapshot {
    if (!try overlaps(input, output)) return .{ .bytes = input };
    const owned = try allocator.dupe(u8, input);
    return .{ .bytes = owned, .owned = owned };
}

pub fn DictionarySnapshot(comptime Dictionary: type) type {
    return struct {
        dictionary: ?Dictionary,
        owned: ?[]u8 = null,

        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            if (self.owned) |bytes| allocator.free(bytes);
        }
    };
}

/// Preserve every dictionary span that can be invalidated by output growth.
/// A full dictionary is validated, copied as one complete byte allocation and
/// reparsed so its content and entropy description both point into that owner.
/// Generic dictionary construction avoids importing the codec into this helper.
pub fn preserveDictionary(comptime Dictionary: type, allocator: std.mem.Allocator, dictionary: ?Dictionary, output: *const std.ArrayList(u8)) !DictionarySnapshot(Dictionary) {
    const borrowed = dictionary orelse return .{ .dictionary = null };
    if (borrowed.standard_bytes) |bytes| {
        _ = try borrowed.standardView();
        if (!try overlaps(bytes, output) and !try overlaps(borrowed.content, output)) return .{ .dictionary = borrowed };
        const owned = try allocator.dupe(u8, bytes);
        errdefer allocator.free(owned);
        const parsed = try Dictionary.initFromStandardDictionary(owned);
        return .{ .dictionary = parsed.dictionary, .owned = owned };
    }
    const content = try preserve(allocator, borrowed.content, output);
    return .{ .dictionary = Dictionary.init(borrowed.id, content.bytes), .owned = content.owned };
}
