const std = @import("std");
const h = @import("common.zig");
const controls = @import("controls.zig");
const resources = @import("resources.zig");
const reusable = @import("reusable.zig");
const streaming = @import("streaming.zig");
const initialization = @import("initialization.zig");

pub fn run(init: std.process.Init, c: h.Config, assets: []const resources.Loaded, initial_bytes: []const u8, initial_dictionary: ?h.Z.NativeDictionary) ![]h.Event {
    switch (c.api) {
        .native_encode => {
            var encoder = h.Z.NativeFrameEncoder.init(init.gpa);
            defer encoder.deinit();
            try initialization.install(&encoder, c, initial_bytes, initial_dictionary);
            return reusable.run(init, c, assets, &encoder, .native);
        },
        .level_encode => {
            var encoder = h.Z.LevelFrameEncoder.init(init.gpa);
            defer encoder.deinit();
            try initialization.install(&encoder, c, initial_bytes, initial_dictionary);
            return reusable.run(init, c, assets, &encoder, .level);
        },
        .native_decode => {
            var decoder = h.Z.NativeFrameDecoder.initWithOptions(init.gpa, try initialization.decodeOptions(c, initial_dictionary));
            defer decoder.deinit();
            return reusable.run(init, c, assets, &decoder, .decode);
        },
        .incremental_encode => {
            var encoder = try initialization.serial(init.gpa, c, initial_bytes, initial_dictionary);
            defer encoder.deinit();
            return streaming.run(init, c, assets, &encoder, false);
        },
        .incremental_parallel_encode => {
            var encoder = try initialization.parallel(init, c, initial_dictionary);
            defer encoder.deinit();
            return streaming.run(init, c, assets, &encoder, false);
        },
        .incremental_decode => {
            var decoder = try initialization.decoder(init.gpa, c, initial_bytes, initial_dictionary);
            defer decoder.deinit();
            return streaming.run(init, c, assets, &decoder, true);
        },
        .one_shot_encode, .one_shot_level_encode, .one_shot_decode => return @import("stateless.zig").run(init, c, assets),
    }
}
