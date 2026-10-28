//! Ordinary allocating APIs shared by validation, diagnostics and timed loops.
const std = @import("std");
const zstd = @import("vort_zstd");
const libzstd = @import("libzstd_runtime.zig");

pub const Pair = struct {
    runtime: libzstd.Runtime,
    level: c_int,
    native_options: ?zstd.NativeFrameOptions,
    reference_options: ?libzstd.Runtime.AdvancedOptions = null,
    dictionary_bytes: ?[]const u8 = null,

    pub fn encodeVort(self: Pair, allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
        if (self.native_options) |options| {
            if (self.dictionary_bytes) |bytes| {
                const dictionary = try parseDictionary(bytes);
                return (try zstd.encodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dictionary)).frame;
            }
            return (try zstd.encodeNativeFrameWithOptionsAlloc(allocator, payload, options)).frame;
        }
        return zstd.encodeFrameWithLevelAlloc(allocator, payload, self.level);
    }

    pub fn encodeReference(self: Pair, allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
        if (self.reference_options) |options|
            return self.runtime.encodeAdvancedWithDictAlloc(allocator, payload, options, self.dictionary_bytes orelse "");
        return self.runtime.encodeAlloc(allocator, payload, self.level);
    }

    pub fn verify(self: Pair, allocator: std.mem.Allocator, payload: []const u8, native_wire: []const u8, reference_wire: []const u8) !void {
        const output = try allocator.alloc(u8, payload.len);
        defer allocator.free(output);
        if (self.dictionary_bytes) |bytes|
            try self.runtime.decodeUsingDict(native_wire, output, bytes)
        else
            try self.runtime.decode(native_wire, output);
        if (!std.mem.eql(u8, payload, output)) return error.SizeMismatch;
        if (self.dictionary_bytes) |bytes| {
            const decoded = try zstd.decodeFrameAllocWithDictionary(allocator, reference_wire, try parseDictionary(bytes));
            defer allocator.free(decoded);
            if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
        } else {
            const written = try zstd.decodeFrameInto(reference_wire, output);
            if (written != payload.len or !std.mem.eql(u8, payload, output)) return error.SizeMismatch;
        }
    }

    pub fn profile(self: Pair, allocator: std.mem.Allocator, payload: []const u8, expected: []const u8) !zstd.EncoderControlProfile {
        var report: zstd.EncoderControlProfile = .{};
        var observed = self;
        var options = observed.native_options.?;
        options.control_profile = &report;
        observed.native_options = options;
        const wire = try observed.encodeVort(allocator, payload);
        defer allocator.free(wire);
        if (!std.mem.eql(u8, expected, wire)) return error.ProfileWireMismatch;
        return report;
    }

    pub fn referenceParameters(self: Pair) !?libzstd.Runtime.RequestedParameters {
        if (self.reference_options) |options|
            return try self.runtime.inspectAdvancedWithDictParameters(options, self.dictionary_bytes orelse "");
        return null;
    }

    pub fn checkRequestedControls(self: Pair, observed: ?libzstd.Runtime.RequestedParameters) !?bool {
        const options = self.reference_options orelse return null;
        const actual = observed orelse return error.ReferenceParametersUnavailable;
        if (actual.level != options.level or actual.strategy != options.strategy.? or
            actual.window_log != options.window_log.? or actual.search_log != options.search_log.? or
            actual.min_match != options.min_match.? or actual.target_length != options.target_length.? or
            actual.content_size != @intFromBool(options.content_size) or
            actual.checksum != @intFromBool(options.checksum) or actual.workers != 0 or
            actual.long_distance_matching != 0 or actual.dict_id != 1)
            return error.ReferenceParameterMismatch;
        return true;
    }
};

pub fn parseDictionary(bytes: []const u8) !zstd.NativeDictionary {
    if (bytes.len >= 4 and std.mem.readInt(u32, bytes[0..4], .little) == 0xec30a437)
        return (try zstd.NativeDictionary.initFromStandardDictionary(bytes)).dictionary;
    return zstd.NativeDictionary.initRawContent(bytes);
}

pub fn readDictionary(init: std.process.Init, path: ?[]const u8) !?[]u8 {
    const name = path orelse return null;
    const file = try std.Io.Dir.cwd().openFile(init.io, name, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    if (stat.size > 256 * 1024 * 1024) return error.DictionaryTooLarge;
    const bytes = try init.gpa.alloc(u8, @intCast(stat.size));
    errdefer init.gpa.free(bytes);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(init.io, &buffer);
    if (try reader.interface.readSliceShort(bytes) != bytes.len) return error.InputTooSmall;
    _ = try parseDictionary(bytes);
    return bytes;
}
