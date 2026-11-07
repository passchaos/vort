const std = @import("std");
const h = @import("common.zig");
const resources = @import("resources.zig");
const controls = @import("controls.zig");
pub const Kind = enum { native, level, decode };

pub fn run(init: std.process.Init, c: h.Config, assets: []const resources.Loaded, handle: anytype, comptime kind: Kind) ![]h.Event {
    const events = try init.gpa.alloc(h.Event, assets.len);
    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| resources.releaseEvent(init.gpa, event);
        init.gpa.free(events);
    }
    for (assets, 0..) |asset, index| {
        var failure: ?[]const u8 = null;
        const output = perform(init, c, asset, handle, kind) catch |err| blk: {
            failure = @errorName(err);
            break :blk null;
        };
        defer if (output) |bytes| init.gpa.free(bytes);
        var event = try resources.event(init, index, asset.stage, output orelse "");
        errdefer resources.releaseEvent(init.gpa, event);
        event.error_name = failure;
        event.status = if (failure != null) "error" else "completed";
        try controls.capture(init, handle, &event);
        events[index] = event;
        initialized += 1;
    }
    return events;
}

fn perform(init: std.process.Init, c: h.Config, asset: resources.Loaded, handle: anytype, comptime kind: Kind) !?[]u8 {
    if (try controls.apply(handle, asset)) return null;
    const selected = controls.stageConfig(c, asset.stage);
    const input = asset.input[0..@min(asset.input.len, asset.stage.input_limit orelse asset.input.len)];
    if (comptime kind == .decode) {
        if (asset.stage.operation != .decode) return error.UnsupportedStage;
        var options = controls.decodeOptions(selected);
        if (asset.dictionary) |dictionary| options.dictionary = dictionary;
        switch (c.entry) {
            .alloc => return try handle.decodeAllocWithOptions(input, options),
            .scratch => return try init.gpa.dupe(u8, try handle.decodeScratchWithOptions(input, options)),
            .append => {
                var output: std.ArrayList(u8) = .empty;
                defer output.deinit(init.gpa);
                try output.appendSlice(init.gpa, "guard");
                _ = try handle.decodeAppendWithOptions(&output, input, options);
                try h.require(std.mem.eql(u8, output.items[0..5], "guard"));
                return try init.gpa.dupe(u8, output.items[5..]);
            },
            .into => {
                const output = try init.gpa.alloc(u8, asset.stage.output_limit + 19);
                defer init.gpa.free(output);
                @memset(output, 0xa5);
                const count = try handle.decodeIntoSliceWithOptions(input, output[0..asset.stage.output_limit], options);
                for (output[count..]) |byte| try h.require(byte == 0xa5);
                return try init.gpa.dupe(u8, output[0..count]);
            },
        }
    } else {
        if (asset.stage.operation != .encode) return error.UnsupportedStage;
        if (comptime kind == .native) {
            const options = controls.nativeOptions(selected);
            switch (c.entry) {
                .alloc => return (if (asset.dictionary) |dictionary| try handle.encodeWithDictionaryAlloc(input, options, dictionary) else try handle.encodeWithOptionsAlloc(input, options)).frame,
                .scratch => return try init.gpa.dupe(u8, (if (asset.dictionary) |dictionary| try handle.encodeScratchWithDictionary(input, options, dictionary) else try handle.encodeScratch(input, options)).frame),
                .append => {
                    var output: std.ArrayList(u8) = .empty;
                    defer output.deinit(init.gpa);
                    try output.appendSlice(init.gpa, "guard");
                    _ = if (asset.dictionary) |dictionary| try handle.encodeAppendWithDictionary(&output, input, options, dictionary) else try handle.encodeAppend(&output, input, options);
                    try h.require(std.mem.eql(u8, output.items[0..5], "guard"));
                    return try init.gpa.dupe(u8, output.items[5..]);
                },
                .into => {
                    const output = try init.gpa.alloc(u8, asset.stage.output_limit + 19);
                    defer init.gpa.free(output);
                    @memset(output, 0xa5);
                    const result = if (asset.dictionary) |dictionary| try handle.encodeIntoSliceWithDictionary(input, options, dictionary, output[0..asset.stage.output_limit]) else try handle.encodeIntoSlice(input, options, output[0..asset.stage.output_limit]);
                    for (output[result.written..]) |byte| try h.require(byte == 0xa5);
                    return try init.gpa.dupe(u8, output[0..result.written]);
                },
            }
        } else {
            const options = controls.frameOptions(selected);
            switch (c.entry) {
                .alloc => return try handle.encodeWithOptionsAlloc(input, c.level, options),
                .scratch => return try init.gpa.dupe(u8, try handle.encodeScratchWithOptions(input, c.level, options)),
                .append => {
                    var output: std.ArrayList(u8) = .empty;
                    defer output.deinit(init.gpa);
                    try output.appendSlice(init.gpa, "guard");
                    _ = try handle.encodeAppendWithOptions(&output, input, c.level, options);
                    try h.require(std.mem.eql(u8, output.items[0..5], "guard"));
                    return try init.gpa.dupe(u8, output.items[5..]);
                },
                .into => {
                    const output = try init.gpa.alloc(u8, asset.stage.output_limit + 19);
                    defer init.gpa.free(output);
                    @memset(output, 0xa5);
                    const count = try handle.encodeIntoWithOptions(input, c.level, options, output[0..asset.stage.output_limit]);
                    for (output[count..]) |byte| try h.require(byte == 0xa5);
                    return try init.gpa.dupe(u8, output[0..count]);
                },
            }
        }
    }
}
