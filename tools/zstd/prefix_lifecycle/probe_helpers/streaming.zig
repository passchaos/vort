const std = @import("std");
const h = @import("common.zig");
const controls = @import("controls.zig");
const resources = @import("resources.zig");

pub fn run(init: std.process.Init, c: h.Config, assets: []const resources.Loaded, handle: anytype, comptime decode: bool) ![]h.Event {
    const events = try init.gpa.alloc(h.Event, assets.len);
    var initialized: usize = 0;
    errdefer {
        for (events[0..initialized]) |event| resources.releaseEvent(init.gpa, event);
        init.gpa.free(events);
    }
    for (assets, 0..) |asset, index| {
        var output: std.ArrayList(u8) = .empty;
        defer output.deinit(init.gpa);
        var input_read: usize = 0;
        var status: ?[]const u8 = null;
        var failure: ?[]const u8 = null;
        perform(init, c, asset, handle, decode, &output, &input_read, &status) catch |err| {
            failure = @errorName(err);
        };
        var event = try resources.event(init, index, asset.stage, output.items);
        errdefer resources.releaseEvent(init.gpa, event);
        event.error_name = failure;
        event.input_read = input_read;
        event.status = if (failure != null) "error" else status orelse "completed";
        try controls.capture(init, handle, &event);
        events[index] = event;
        initialized += 1;
    }
    return events;
}

fn perform(init: std.process.Init, c: h.Config, asset: resources.Loaded, handle: anytype, comptime decode: bool, output: *std.ArrayList(u8), input_read: *usize, status: *?[]const u8) !void {
    if (try controls.apply(handle, asset)) return;
    const stage = asset.stage;
    if (stage.operation == .finish) {
        if (comptime decode) try handle.finish() else handle.finish();
        return;
    }
    if (stage.operation == .next_stream) {
        if (comptime decode) try handle.nextStream() else return error.UnsupportedStage;
        return;
    }
    if (stage.operation == .provide_dictionary) {
        if (comptime decode) try handle.provideDictionary(asset.dictionary orelse return error.MissingDictionary) else return error.UnsupportedStage;
        return;
    }
    const input = asset.input[0..@min(asset.input.len, stage.input_limit orelse asset.input.len)];
    const capacity = if (stage.operation == .step) stage.output_limit else c.output_chunk;
    if (capacity > 65536) return error.InvalidProbeConfig;
    const scratch = try init.gpa.alloc(u8, capacity);
    defer init.gpa.free(scratch);
    if (stage.operation == .step) {
        const result = step(handle, decode, input, scratch, stage.directive) catch |err| {
            if (comptime decode) try recordErrorProgress(init, handle, input.len, scratch, output, input_read);
            return err;
        };
        try h.require(result.progress.input_read <= input.len and result.progress.output_written <= scratch.len);
        input_read.* = result.progress.input_read;
        status.* = @tagName(result.status);
        try output.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        return;
    }
    if (stage.operation != (if (decode) .decode else .encode)) return error.UnsupportedStage;
    var offset: usize = 0;
    var finished = false;
    for (0..input.len * 32 + 4096) |_| {
        if (comptime !decode) {
            if (offset == input.len and !finished) {
                handle.finish();
                finished = true;
            }
        }
        const end = offset + @min(input.len - offset, c.input_chunk);
        const result = step(handle, decode, input[offset..end], scratch, 0) catch |err| {
            if (comptime decode) try recordErrorProgress(init, handle, end - offset, scratch, output, input_read);
            return err;
        };
        try h.require(result.progress.input_read <= end - offset and result.progress.output_written <= scratch.len);
        offset += result.progress.input_read;
        input_read.* = offset;
        status.* = @tagName(result.status);
        try output.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        if (result.status == .done) {
            if (comptime decode) {
                if (!c.stop_after_first_frame and offset < input.len) continue;
            }
            return;
        }
        if (comptime decode) {
            if (offset == input.len and result.status == .need_input) {
                try handle.finish();
                return;
            }
        }
        if (result.progress.input_read == 0 and result.progress.output_written == 0 and scratch.len != 0)
            return error.ProbeDidNotConverge;
    }
    return error.ProbeDidNotConverge;
}

fn recordErrorProgress(init: std.process.Init, handle: anytype, offered: usize, scratch: []const u8, output: *std.ArrayList(u8), input_read: *usize) !void {
    const progress = handle.snapshot().last_step_progress;
    try h.require(progress.input_read <= offered and progress.output_written <= scratch.len);
    input_read.* += progress.input_read;
    try output.appendSlice(init.gpa, scratch[0..progress.output_written]);
}

fn step(handle: anytype, comptime decode: bool, input: []const u8, output: []u8, directive: i32) !h.codec.core.StepResult {
    if (comptime decode) return handle.step(input, output);
    if (@hasDecl(@typeInfo(@TypeOf(handle)).pointer.child, "stepWithDirective"))
        return handle.stepWithDirective(input, output, @enumFromInt(directive));
    if (directive != 0) return error.UnsupportedDirective;
    return handle.step(input, output);
}
