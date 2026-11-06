const std = @import("std");
pub const Direction = enum { encode, decode };
pub const Family = enum { raw_stored, raw_fixed, raw_best, zlib_fixed, zlib_best, gzip_fixed, gzip_best, raw, zlib, gzip };
pub const Stage = enum { pending, header, bits, params, trailer, dynamic, match, semantic };
pub const Flush = enum { none, block, partial, sync, full };
pub const Config = struct {
    direction: Direction,
    family: Family,
    stage: Stage = .pending,
    prefix_path: []const u8,
    tail_a_path: []const u8,
    tail_b_path: []const u8,
    dictionary_path: ?[]const u8 = null,
    wire_a_path: []const u8,
    wire_b_path: []const u8,
    reset_path: []const u8,
    report_path: []const u8,
    window_bits: u8 = 15,
    flush: Flush = .partial,
    fork_input: usize = 0,
    fork_output_limit: usize = 65536,
    history_len: usize = 32768,
    semantic: bool = false,
    logical_counter_base: u64 = 0,
};
pub const Fork = struct {
    input_read: u64,
    output_written: u64,
    pending_output: usize = 0,
    pending_bits: u3 = 0,
    phase: []const u8 = "",
    raw_phase: []const u8 = "",
    match_remaining: usize = 0,
    semantic_active: bool = false,
    semantic_generated: usize = 0,
    semantic_delivered: usize = 0,
    history_len: usize = 0,
    params_queued: bool = false,
    flushing: bool = false,
    footer_written: bool = false,
};
pub const Branch = struct {
    input_read: u64,
    output_written: u64,
    actual_input: usize,
    actual_output: usize,
    crc32: u32,
    calls: usize,
    eof: bool,
};
pub const Receipt = struct {
    fork: Fork,
    branches: [2]Branch,
    source_destroyed_first: bool = true,
    branch_a_reset_before_b: bool = true,
    heap_live_after_free: usize,
    heap_peak: usize,
    dictionary_ownership: []const u8 = "immutable caller borrow retained until both branches and resets complete",
    input_ownership: []const u8 = "immutable fixture buffers remain valid until both branches finish",
    logical_counter_base: u64 = 0,
    physical_four_gib_decoded: bool = false,
};
pub const reset_plain = "reset keeps owned branch storage independent";

pub fn load(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, try ioPath(path), init.gpa, .limited(1024 * 1024));
}
pub fn save(init: std.process.Init, path: []const u8, bytes: []const u8) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try ioPath(path), .data = bytes });
}
fn ioPath(path: []const u8) ![]const u8 {
    if (@import("builtin").os.tag == .wasi) {
        // Zig 0.16 treats the first preopen as Dir.cwd(); path_open expects a
        // relative path below that descriptor rather than its virtual prefix.
        if (!std.mem.startsWith(u8, path, "/work/")) return error.InvalidWasiPath;
        return path["/work/".len..];
    }
    return path;
}
pub fn append(allocator: std.mem.Allocator, bytes: *std.ArrayList(u8), suffix: []const u8) !void {
    if (bytes.items.len + suffix.len > 1024 * 1024) return error.FixtureTooLarge;
    try bytes.appendSlice(allocator, suffix);
}

/// Tracks only stream objects, their owned buffers and caller clone storage.
pub const Ledger = struct {
    backing: std.mem.Allocator,
    live: usize = 0,
    peak: usize = 0,
    pub fn allocator(self: *Ledger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn change(self: *Ledger, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const bytes = self.backing.rawAlloc(len, alignment, ret) orelse return null;
        self.change(0, len);
        return bytes;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        if (!self.backing.rawResize(bytes, alignment, len, ret)) return false;
        self.change(bytes.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        const bytes_new = self.backing.rawRemap(bytes, alignment, len, ret) orelse return null;
        self.change(bytes.len, len);
        return bytes_new;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *Ledger = @ptrCast(@alignCast(raw));
        self.backing.rawFree(bytes, alignment, ret);
        self.change(bytes.len, 0);
    }
};
