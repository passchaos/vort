//! File-backed RAW dictionary flags shared by the Brotli CLI routes.
const std = @import("std");
const vort = @import("vort");

const default_byte_limit = 32 * 1024 * 1024;

pub const Arguments = struct {
    path: ?[]const u8 = null,
    byte_limit: ?usize = null,

    pub fn consume(self: *Arguments, arg: []const u8, args: anytype) !bool {
        if (try optionValue("--dictionary", arg, args)) |value| {
            if (self.path != null) return error.DuplicateBrotliOption;
            if (value.len == 0) return error.MissingBrotliOptionValue;
            self.path = value;
            return true;
        }
        if (try optionValue("--max-dictionary-bytes", arg, args)) |value| {
            if (self.byte_limit != null) return error.DuplicateBrotliOption;
            self.byte_limit = try std.fmt.parseInt(usize, value, 10);
            return true;
        }
        return false;
    }

    pub fn specified(self: Arguments) bool {
        return self.path != null or self.byte_limit != null;
    }

    pub fn load(self: Arguments, io: std.Io, allocator: std.mem.Allocator) !Binding {
        const path = self.path orelse {
            if (self.byte_limit != null) return error.MissingBrotliDictionary;
            return .{};
        };
        const input = try std.Io.Dir.cwd().openFile(io, path, .{});
        defer input.close(io);
        var adapter = try vort.FileByteSource.init(io, input);
        const source = adapter.source();
        const limit = @min(self.byte_limit orelse default_byte_limit, vort.br.shared_dictionary_max_raw_size);
        if (source.len > limit) return error.OutputLimitExceeded;
        const bytes = try allocator.alloc(u8, @intCast(source.len));
        errdefer allocator.free(bytes);
        try source.readExact(0, bytes);
        return .{ .prefixes = .{bytes} };
    }
};

pub const Binding = struct {
    prefixes: [1][]const u8 = .{""},

    /// The returned view borrows both the prefix descriptor and its bytes.
    pub fn shared(self: *const Binding) vort.BrotliSharedDictionary {
        return .{ .raw_prefixes = if (self.prefixes[0].len == 0) &.{} else &self.prefixes };
    }

    pub fn deinit(self: Binding, allocator: std.mem.Allocator) void {
        allocator.free(self.prefixes[0]);
    }
};

fn optionValue(comptime name: []const u8, arg: []const u8, args: anytype) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingBrotliOptionValue;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}
