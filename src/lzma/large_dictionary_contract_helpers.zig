//! Independent frozen fixtures from commit a549b7a2.
//! Never replace these wire bytes with output from the implementation under test.
const std = @import("std");

pub const min_dictionary_size: u32 = 4096;
pub const max_dictionary_size: u32 = 1610612736;
pub const preset_plain = "large dictionary preset: ab0ab1ab2ab3";
pub const PresetWire = struct { level: u32, extreme: bool, hex: []const u8 };

pub const DictionaryCase = struct { requested: u32, property: u8, advertised: u32 };
/// Independently checked by liblzma 5.8.4 properties_encode/properties_decode.
pub const dictionary_cases = [_]DictionaryCase{
    .{ .requested = 4096, .property = 0, .advertised = 4096 },
    .{ .requested = 67108865, .property = 29, .advertised = 100663296 },
    .{ .requested = 100663297, .property = 30, .advertised = 134217728 },
    .{ .requested = 1073741825, .property = 37, .advertised = 1610612736 },
    .{ .requested = 1610612735, .property = 37, .advertised = 1610612736 },
    .{ .requested = 1610612736, .property = 37, .advertised = 1610612736 },
};

pub fn legacyPlain() [512]u8 {
    return @import("encode_controls_helpers.zig").legacyPlain();
}

pub fn hexBytes(comptime hex: []const u8) [hex.len / 2]u8 {
    var bytes: [hex.len / 2]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, hex) catch unreachable;
    return bytes;
}

pub fn decodeWire(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    const bytes = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, hex);
    return bytes;
}

/// Requested allocation bytes only: caller storage and allocator bookkeeping
/// are outside this ledger. Tiny high-dictionary tests impose a real heap cap.
pub const HeapLedger = struct {
    backing: std.mem.Allocator,
    limit: usize,
    live: usize = 0,
    peak: usize = 0,
    largest_request: usize = 0,
    denied_requests: usize = 0,

    pub fn init(backing: std.mem.Allocator, limit: usize) HeapLedger {
        return .{ .backing = backing, .limit = limit };
    }

    pub fn allocator(self: *HeapLedger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn permit(self: *HeapLedger, previous_len: usize, next_len: usize) bool {
        self.largest_request = @max(self.largest_request, next_len);
        const next_live = std.math.add(usize, self.live - previous_len, next_len) catch {
            self.denied_requests += 1;
            return false;
        };
        if (next_live > self.limit) {
            self.denied_requests += 1;
            return false;
        }
        return true;
    }

    fn update(self: *HeapLedger, previous_len: usize, next_len: usize) void {
        self.live = self.live - previous_len + next_len;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (!self.permit(0, len)) return null;
        const result = self.backing.rawAlloc(len, alignment, return_address) orelse return null;
        self.update(0, len);
        return result;
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (!self.permit(memory.len, new_len)) return false;
        if (!self.backing.rawResize(memory, alignment, new_len, return_address)) return false;
        self.update(memory.len, new_len);
        return true;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (!self.permit(memory.len, new_len)) return null;
        const result = self.backing.rawRemap(memory, alignment, new_len, return_address) orelse return null;
        self.update(memory.len, new_len);
        return result;
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        self.backing.rawFree(memory, alignment, return_address);
        self.update(memory.len, 0);
    }
};

/// Format readers deliberately avoid production header/property helpers.
pub fn aloneDictionary(bytes: []const u8) !u32 {
    try std.testing.expect(bytes.len >= 13);
    return std.mem.readInt(u32, bytes[1..5], .little);
}

pub fn zipDictionary(bytes: []const u8) !u32 {
    try std.testing.expect(bytes.len >= 9);
    try std.testing.expectEqualSlices(u8, &.{ 9, 4, 5, 0 }, bytes[0..4]);
    return std.mem.readInt(u32, bytes[5..9], .little);
}

pub const default_hex =
    "5d00800000ffffffffffffffff003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd3" ++
    "70fc5a17977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0" ++
    "c7a24679eaae07079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720" ++
    "a68a22266f4f510d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd4856fd4e2f3fd99ca24";

pub const preset_wires = [_]PresetWire{
    .{ .level = 0, .extreme = false, .hex = "5d0000040025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 1, .extreme = false, .hex = "5d0000100025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 2, .extreme = false, .hex = "5d0000200025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 3, .extreme = false, .hex = "5d0000400025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 4, .extreme = false, .hex = "5d0000400025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 5, .extreme = false, .hex = "5d0000800025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 6, .extreme = false, .hex = "5d0000800025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 7, .extreme = false, .hex = "5d0000000125000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 8, .extreme = false, .hex = "5d0000000225000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 9, .extreme = false, .hex = "5d0000000425000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 0, .extreme = true, .hex = "5d0000040025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 1, .extreme = true, .hex = "5d0000100025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 2, .extreme = true, .hex = "5d0000200025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 3, .extreme = true, .hex = "5d0000400025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 4, .extreme = true, .hex = "5d0000400025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 5, .extreme = true, .hex = "5d0000800025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 6, .extreme = true, .hex = "5d0000800025000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 7, .extreme = true, .hex = "5d0000000125000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 8, .extreme = true, .hex = "5d0000000225000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
    .{ .level = 9, .extreme = true, .hex = "5d0000000425000000000000000036184aab18a8c8d87c2c44352e906966b066678f544c39c63de4319f0d0e43ba0666f99f4a8200" },
};

pub const micro_default_hex =
    "a23318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd370fc5a17977688f8afbb17f0b4" ++
    "8ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0c7a24679eaae07079504e71cff" ++
    "ad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720a68a22266f4f510d65a5d1174b" ++
    "97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd48335b472";

pub const zip_default_hex =
    "090405005d00800000003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd370fc5a17" ++
    "977688f8afbb17f0b48ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0c7a24679" ++
    "eaae07079504e71cffad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720a68a2226" ++
    "6f4f510d65a5d1174b97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd4856fd4e2f3fd99ca24";

pub const chd_default_hex =
    "003318c896782a692c14846974654b3af042c8c7204dd7becd97efa96467bcca85fcd370fc5a17977688f8afbb17f0b4" ++
    "8ab73650685ecf5033b7414779407403ca9fcae8257e3822df91bae48df818524feef0c7a24679eaae07079504e71cff" ++
    "ad774f75f38b5c1644ac66fc23310a1f0b8e0704be1ec2d113b07b3b56a81c47d2e720a68a22266f4f510d65a5d1174b" ++
    "97161d41b0d4d51d84a7d39ee9a71e8bfdb3739bd48335b472";
