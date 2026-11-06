//! Derive wire metadata without changing the selected dictionary's identity.
const std = @import("std");

pub fn wireId(options: anytype) u32 {
    return if (options.include_dictionary_id) options.dictionary_id else 0;
}

pub fn flag(id: u32) u2 {
    if (id == 0) return 0;
    if (id <= std.math.maxInt(u8)) return 1;
    if (id <= std.math.maxInt(u16)) return 2;
    return 3;
}

pub fn fieldLen(id: u32) usize {
    return switch (flag(id)) {
        0 => 0,
        1 => 1,
        2 => 2,
        3 => 4,
    };
}

pub fn write(allocator: std.mem.Allocator, out: *std.ArrayList(u8), id: u32) std.mem.Allocator.Error!void {
    switch (flag(id)) {
        0 => {},
        1 => try out.append(allocator, @intCast(id)),
        2 => {
            var bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &bytes, @intCast(id), .little);
            try out.appendSlice(allocator, &bytes);
        },
        3 => {
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, id, .little);
            try out.appendSlice(allocator, &bytes);
        },
    }
}
