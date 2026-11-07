const std = @import("std");
const h = @import("common.zig");
const controls = @import("controls.zig");

pub fn install(handle: anytype, c: h.Config, bytes: []const u8, dictionary: ?h.Z.NativeDictionary) !void {
    switch (c.initialization) {
        .default => {},
        .persistent => try handle.setDictionary(dictionary orelse return error.MissingDictionary),
        .prefix => if (c.initial_full_dictionary) {
            try handle.setPrefixWithDictionary(dictionary orelse return error.MissingDictionary);
        } else try handle.setPrefix(bytes),
    }
}

pub fn decodeOptions(c: h.Config, dictionary: ?h.Z.NativeDictionary) !h.Z.FrameDecodeOptions {
    var options = controls.decodeOptions(c);
    if (c.initialization != .default) {
        options.dictionary = dictionary orelse return error.MissingDictionary;
        options.dictionary_usage = if (c.initialization == .prefix) .prefix else .persistent;
    }
    return options;
}

pub fn serial(allocator: std.mem.Allocator, c: h.Config, bytes: []const u8, dictionary: ?h.Z.NativeDictionary) !h.Z.NativeIncrementalFrameEncoder {
    var options = controls.nativeOptions(c);
    if (c.initialization == .prefix) options.dictionary_usage = .prefix;
    if (c.initialization == .prefix and !c.initial_full_dictionary) {
        return if (c.known_size) h.Z.NativeIncrementalFrameEncoder.initExactSizeWithPrefix(allocator, options, c.expected_input_len, bytes) else h.Z.NativeIncrementalFrameEncoder.initWithPrefix(allocator, options, bytes);
    }
    if (c.initialization != .default) {
        const dict = dictionary orelse return error.MissingDictionary;
        return if (c.known_size) h.Z.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(allocator, options, c.expected_input_len, dict) else h.Z.NativeIncrementalFrameEncoder.initWithPresetDictionary(allocator, options, dict);
    }
    return if (c.known_size) h.Z.NativeIncrementalFrameEncoder.initExactSize(allocator, options, c.expected_input_len) else h.Z.NativeIncrementalFrameEncoder.init(allocator, options);
}

pub fn parallel(init: std.process.Init, c: h.Config, dictionary: ?h.Z.NativeDictionary) !h.Z.NativeIncrementalParallelFrameEncoder {
    var options: h.Z.NativeIncrementalParallelFrameEncoder.Options = .{ .frame = controls.nativeOptions(c), .parallel = .{ .io = if (c.synchronous) std.Io.failing else init.io, .worker_count = 2, .job_size = 4096, .max_inflight_jobs = 2, .max_inflight_bytes = 8192 } };
    if (c.initialization == .prefix) options.frame.dictionary_usage = .prefix;
    if (c.initialization != .default) {
        const dict = dictionary orelse return error.MissingDictionary;
        return if (c.known_size) h.Z.NativeIncrementalParallelFrameEncoder.initExactSizeWithPresetDictionary(init.gpa, options, c.expected_input_len, dict) else h.Z.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(init.gpa, options, dict);
    }
    return if (c.known_size) h.Z.NativeIncrementalParallelFrameEncoder.initExactSize(init.gpa, options, c.expected_input_len) else h.Z.NativeIncrementalParallelFrameEncoder.init(init.gpa, options);
}

pub fn decoder(allocator: std.mem.Allocator, c: h.Config, bytes: []const u8, dictionary: ?h.Z.NativeDictionary) !h.Z.NativeIncrementalFrameDecoder {
    var options: h.Z.NativeIncrementalFrameDecoder.Options = .{ .format = c.format, .ignore_content_checksum = c.ignore_checksum, .dictionary_usage = if (c.usage == .prefix) .prefix else .persistent, .expected_output_len = h.codec.core.stream_count.fromOptionalLocal(c.expected_output_len), .stop_after_first_frame = c.stop_after_first_frame };
    if (c.initialization == .prefix) options.dictionary_usage = .prefix;
    if (c.initialization == .prefix and !c.initial_full_dictionary)
        return construct(h.Z.NativeIncrementalFrameDecoder.initWithPrefixAndOptions(allocator, bytes, options));
    if (c.initialization != .default)
        return h.Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(allocator, dictionary orelse return error.MissingDictionary, options);
    return h.Z.NativeIncrementalFrameDecoder.initWithOptions(allocator, options);
}

fn ConstructorValue(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => |value| value.payload,
        else => T,
    };
}
fn construct(result: anytype) !ConstructorValue(@TypeOf(result)) {
    return switch (@typeInfo(@TypeOf(result))) {
        .error_union => try result,
        else => result,
    };
}
