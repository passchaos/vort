const std = @import("std");
const vort = @import("vort");

/// All files and adapter addresses remain valid until archive states are gone.
pub const Set = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    adapters: std.ArrayList(vort.FileByteSource) = .empty,
    borrowed_sources: ?[]vort.ByteSource = null,

    pub fn init(allocator: std.mem.Allocator, io: std.Io) Set {
        return .{ .allocator = allocator, .io = io };
    }

    pub fn deinit(self: *Set) void {
        if (self.borrowed_sources) |sources| self.allocator.free(sources);
        for (self.adapters.items) |adapter| adapter.file.close(self.io);
        self.adapters.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn add(self: *Set, path: []const u8) !void {
        std.debug.assert(self.borrowed_sources == null);
        const file = try std.Io.Dir.cwd().openFile(self.io, path, .{});
        errdefer file.close(self.io);
        const adapter = try vort.FileByteSource.init(self.io, file);
        try self.adapters.append(self.allocator, adapter);
    }

    pub fn view(self: *Set) ![]const vort.ByteSource {
        if (self.borrowed_sources) |sources| return sources;
        const sources = try self.allocator.alloc(vort.ByteSource, self.adapters.items.len);
        for (self.adapters.items, 0..) |*adapter, index| sources[index] = adapter.source();
        self.borrowed_sources = sources;
        return sources;
    }
};
