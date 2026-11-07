const std = @import("std");
const h = @import("common.zig");
const resources = @import("resources.zig");

fn checked(result: anytype) !void {
    switch (@typeInfo(@TypeOf(result))) {
        .void => {},
        .error_union => try result,
        else => @compileError("Lifecycle setters and resets return void or Error!void"),
    }
}

pub fn apply(handle: anytype, asset: resources.Loaded) !bool {
    switch (asset.stage.operation) {
        .observe => {},
        .set_prefix => {
            if (asset.stage.full_dictionary) {
                try checked(handle.setPrefixWithDictionary(asset.dictionary orelse return error.MissingDictionary));
            } else try checked(handle.setPrefix(asset.dictionary_bytes));
        },
        .set_dictionary => try checked(handle.setDictionary(asset.dictionary orelse return error.MissingDictionary)),
        .clear_dictionary => try checked(handle.clearDictionary()),
        .reset_session => try checked(handle.resetSession()),
        .reset_parameters => try checked(handle.resetParameters()),
        .reset_all => try checked(handle.resetAll()),
        else => return false,
    }
    return true;
}

pub fn capture(init: std.process.Init, handle: anytype, event: *h.Event) !void {
    event.prefix_snapshot_json = try std.json.Stringify.valueAlloc(init.gpa, handle.prefixSnapshot(), .{});
    if (@hasDecl(@typeInfo(@TypeOf(handle)).pointer.child, "snapshot"))
        event.stream_snapshot_json = try std.json.Stringify.valueAlloc(init.gpa, handle.snapshot(), .{});
}

pub fn nativeOptions(c: h.Config) h.Z.NativeFrameOptions {
    return .{ .format = c.format, .content_checksum = c.checksum, .include_content_size = c.known_size, .include_dictionary_id = c.include_dictionary_id, .dictionary_usage = if (c.usage == .prefix) .prefix else .persistent };
}

pub fn stageConfig(c: h.Config, stage: h.Stage) h.Config {
    var selected = c;
    if (stage.dictionary_usage) |usage| selected.usage = usage;
    return selected;
}

pub fn frameOptions(c: h.Config) h.Z.FrameOptions {
    return .{ .format = c.format, .content_checksum = c.checksum, .include_content_size = c.known_size, .include_dictionary_id = c.include_dictionary_id, .dictionary_usage = if (c.usage == .prefix) .prefix else .persistent };
}

pub fn decodeOptions(c: h.Config) h.Z.FrameDecodeOptions {
    return .{ .format = c.format, .ignore_content_checksum = c.ignore_checksum, .dictionary_usage = if (c.usage == .prefix) .prefix else .persistent, .expected_output_len = h.codec.core.stream_count.fromOptionalLocal(c.expected_output_len) };
}
