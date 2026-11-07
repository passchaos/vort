const std = @import("std");
const h = @import("common.zig");

pub const Loaded = struct {
    stage: h.Stage,
    input: []u8,
    dictionary_bytes: []u8,
    dictionary: ?h.Z.NativeDictionary,
    input_hash: [64]u8,
    dictionary_hash: [64]u8,
};

pub fn load(init: std.process.Init, stages: []const h.Stage) ![]Loaded {
    const result = try init.gpa.alloc(Loaded, stages.len);
    var initialized: usize = 0;
    errdefer {
        free(init.gpa, result[0..initialized]);
        init.gpa.free(result);
    }
    for (stages, 0..) |stage, index| {
        const input = if (stage.input_path) |path| try h.read(init, path) else try init.gpa.alloc(u8, 0);
        errdefer init.gpa.free(input);
        const bytes = if (stage.dictionary_path) |path| try h.read(init, path) else try init.gpa.alloc(u8, 0);
        errdefer init.gpa.free(bytes);
        const dictionary = if (stage.dictionary_path != null) try h.dictionary(bytes, stage.full_dictionary) else null;
        result[index] = .{ .stage = stage, .input = input, .dictionary_bytes = bytes, .dictionary = dictionary, .input_hash = h.digest(input), .dictionary_hash = h.digest(bytes) };
        initialized += 1;
    }
    return result;
}

fn free(allocator: std.mem.Allocator, values: []const Loaded) void {
    for (values) |value| {
        allocator.free(value.input);
        allocator.free(value.dictionary_bytes);
    }
}

pub fn deinit(allocator: std.mem.Allocator, values: []Loaded) void {
    free(allocator, values);
    allocator.free(values);
}

pub fn verify(values: []const Loaded) !void {
    for (values) |value| {
        const input_hash = h.digest(value.input);
        const dictionary_hash = h.digest(value.dictionary_bytes);
        try h.require(std.mem.eql(u8, &input_hash, &value.input_hash));
        try h.require(std.mem.eql(u8, &dictionary_hash, &value.dictionary_hash));
    }
}

pub fn event(init: std.process.Init, index: usize, stage: h.Stage, output: []const u8) !h.Event {
    if (stage.output_path) |path| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = output });
    const hash = h.digest(output);
    return .{ .stage = index, .operation = stage.operation, .output_written = output.len, .output_sha256 = try init.gpa.dupe(u8, &hash), .output_path = stage.output_path };
}

pub fn releaseEvent(allocator: std.mem.Allocator, value: h.Event) void {
    allocator.free(value.output_sha256);
    if (!std.mem.eql(u8, value.prefix_snapshot_json, "null")) allocator.free(value.prefix_snapshot_json);
    if (!std.mem.eql(u8, value.stream_snapshot_json, "null")) allocator.free(value.stream_snapshot_json);
}

pub fn freeEvents(allocator: std.mem.Allocator, events: []h.Event) void {
    for (events) |value| releaseEvent(allocator, value);
    allocator.free(events);
}
