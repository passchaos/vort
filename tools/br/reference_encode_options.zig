//! Explicit standard-window reference settings for the planned encode bench.
const std = @import("std");
const libbrotli = @import("libbrotli_runtime.zig");

pub const Options = struct {
    lgwin: ?c_int = null,
    mode: ?c_int = null,

    pub fn resolve(self: Options, quality: c_int) !libbrotli.Runtime.OneShotOptions {
        const settings: libbrotli.Runtime.OneShotOptions = .{
            .quality = quality,
            .lgwin = self.lgwin orelse 22,
            .mode = self.mode orelse 0,
        };
        try settings.validate();
        // This benchmark's reference decode path exercises RFC 7932 streams.
        if (settings.lgwin > 24) return error.InvalidReferenceParameters;
        return settings;
    }

    pub fn parse(self: *Options, arg: []const u8, args: anytype) !bool {
        if (try valueFor(arg, "--reference-lgwin", args)) |value| {
            self.lgwin = std.fmt.parseInt(c_int, value, 10) catch return error.InvalidReferenceParameters;
        } else if (try valueFor(arg, "--reference-mode", args)) |value| {
            self.mode = try parseMode(value);
        } else return false;
        _ = try self.resolve(3);
        return true;
    }
};

fn valueFor(arg: []const u8, comptime flag: []const u8, args: anytype) !?[]const u8 {
    if (std.mem.eql(u8, arg, flag)) return args.next() orelse error.MissingLimit;
    if (std.mem.startsWith(u8, arg, flag ++ "=")) return arg[flag.len + 1 ..];
    return null;
}

pub fn parseMode(value: []const u8) !c_int {
    if (std.mem.eql(u8, value, "generic")) return 0;
    if (std.mem.eql(u8, value, "text")) return 1;
    if (std.mem.eql(u8, value, "font")) return 2;
    return error.InvalidReferenceParameters;
}

/// Quality and mode are encoder settings, not serialized fields. Window bits
/// come from the validated streams; low-quality libbrotli can change lgwin.
pub fn match(planned_quality: ?u4, planned_mode: []const u8, vort_wire_window: u5, reference: libbrotli.Runtime.OneShotOptions, reference_wire_window: u5) bool {
    const quality = planned_quality orelse return false;
    const mode = parseMode(planned_mode) catch return false;
    return @as(c_int, quality) == reference.quality and mode == reference.mode and
        vort_wire_window == reference_wire_window;
}
