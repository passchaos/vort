//! Dictionary usage on standalone calls has no persistent handle to consume.
//! Each stage passes its own borrowed dictionary explicitly to the public API.
const std = @import("std");
const h = @import("common.zig");
const controls = @import("controls.zig");
const resources = @import("resources.zig");

pub fn run(init: std.process.Init, c: h.Config, assets: []const resources.Loaded) ![]h.Event {
    const events = try init.gpa.alloc(h.Event, assets.len);
    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| resources.releaseEvent(init.gpa, event);
        init.gpa.free(events);
    }
    for (assets, 0..) |asset, index| {
        var failure: ?[]const u8 = null;
        const output = perform(init, c, asset) catch |err| blk: {
            failure = @errorName(err);
            break :blk null;
        };
        defer if (output) |bytes| init.gpa.free(bytes);
        var event = try resources.event(init, index, asset.stage, output orelse "");
        event.error_name = failure;
        event.status = if (failure != null) "error" else "completed";
        events[index] = event;
        initialized += 1;
    }
    return events;
}

fn perform(init: std.process.Init, c: h.Config, asset: resources.Loaded) !?[]u8 {
    if (c.api == .one_shot_decode and asset.stage.operation != .decode) return error.UnsupportedStage;
    if (c.api != .one_shot_decode and asset.stage.operation != .encode) return error.UnsupportedStage;
    const input = asset.input;
    const dictionary = asset.dictionary orelse return error.MissingDictionary;
    const selected = controls.stageConfig(c, asset.stage);
    var decode_options = controls.decodeOptions(selected);
    decode_options.dictionary = dictionary;
    const native_options = controls.nativeOptions(selected);
    const frame_options = controls.frameOptions(selected);
    switch (c.entry) {
        .scratch => return error.UnsupportedEntry,
        .alloc => {
            if (c.api == .one_shot_decode) return try h.Z.decodeFrameAllocWithOptions(init.gpa, input, decode_options);
            if (c.api == .one_shot_level_encode) return try h.Z.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(init.gpa, input, c.level, frame_options, dictionary);
            return (try h.Z.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, native_options, dictionary)).frame;
        },
        .append => {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(init.gpa);
            try output.appendSlice(init.gpa, "guard");
            if (c.api == .one_shot_decode) {
                _ = try h.Z.decodeFrameAppendWithOptions(init.gpa, &output, input, decode_options);
            } else if (c.api == .one_shot_level_encode) {
                _ = try h.Z.encodeFrameAppendWithLevelAndOptionsAndDictionary(init.gpa, &output, input, c.level, frame_options, dictionary);
            } else {
                _ = try h.Z.encodeNativeFrameAppendWithDictionary(init.gpa, &output, input, native_options, dictionary);
            }
            try h.require(std.mem.eql(u8, output.items[0..5], "guard"));
            return try init.gpa.dupe(u8, output.items[5..]);
        },
        .into => {
            const output = try init.gpa.alloc(u8, asset.stage.output_limit + 19);
            defer init.gpa.free(output);
            @memset(output, 0xa5);
            const count = if (c.api == .one_shot_decode)
                try h.Z.decodeFrameIntoWithOptions(init.gpa, input, output[0..asset.stage.output_limit], decode_options)
            else if (c.api == .one_shot_level_encode)
                try h.Z.encodeFrameIntoSliceWithLevelAndOptionsAndDictionary(init.gpa, input, c.level, frame_options, dictionary, output[0..asset.stage.output_limit])
            else
                (try h.Z.encodeNativeFrameIntoSliceWithDictionary(init.gpa, input, native_options, dictionary, output[0..asset.stage.output_limit])).written;
            for (output[count..]) |byte| try h.require(byte == 0xa5);
            return try init.gpa.dupe(u8, output[0..count]);
        },
    }
}
