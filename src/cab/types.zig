const std = @import("std");

pub const Compression = enum(u4) {
    none = 0,
    mszip = 1,
    quantum = 2,
    lzx = 3,
    _,
};

pub const Continuation = enum {
    none,
    from_previous,
    to_next,
    from_previous_and_next,

    pub fn startsBefore(self: Continuation) bool {
        return self == .from_previous or self == .from_previous_and_next;
    }

    pub fn continuesAfter(self: Continuation) bool {
        return self == .to_next or self == .from_previous_and_next;
    }
};

pub const Entry = struct {
    name: []const u8,
    size: usize,
    folder_offset: usize,
    folder_index: usize,
    date: u16,
    time: u16,
    attributes: u16,
    record_offset: usize,
    continuation: Continuation = .none,

    pub fn isUtf8(self: Entry) bool {
        return self.attributes & 0x0080 != 0;
    }

    pub fn isSafeRelative(self: Entry) bool {
        if (self.name.len == 0 or self.name[0] == '/' or self.name[0] == '\\') return false;
        if (self.name.len >= 2 and std.ascii.isAlphabetic(self.name[0]) and self.name[1] == ':') return false;
        var component_start: usize = 0;
        while (component_start < self.name.len) {
            const component_end = findSeparator(self.name, component_start) orelse self.name.len;
            const component = self.name[component_start..component_end];
            if (component.len == 0 or
                std.mem.eql(u8, component, ".") or
                std.mem.eql(u8, component, "..")) return false;
            if (component_end == self.name.len) break;
            component_start = component_end + 1;
        }
        return true;
    }
};

pub const Folder = struct {
    data_offset: usize,
    data_block_count: usize,
    compression: Compression,
    type_compress: u16,
    decoded_size: usize,
    data_end: usize,
    index: usize,
};

pub const DataBlock = struct {
    checksum: u32,
    compressed: []const u8,
    reserve: []const u8,
    uncompressed_size: usize,
    record_offset: usize,
    next_offset: usize,
};

fn findSeparator(path: []const u8, start: usize) ?usize {
    for (start..path.len) |index|
        if (path[index] == '/' or path[index] == '\\') return index;
    return null;
}
