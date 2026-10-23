const std = @import("std");
const tree = @import("writer/tree.zig");
const writer_options = @import("writer/options.zig");
const encoder_state = @import("writer/encoder_state.zig");
const byte_sink = @import("../io/sink.zig");

pub const Error = encoder_state.Error || byte_sink.Error;

pub const Entry = tree.Entry;
pub const EntryKind = tree.EntryKind;
pub const Xattr = tree.Xattr;
pub const Source = tree.Source;

pub const Compression = writer_options.Compression;
pub const TailPacking = writer_options.TailPacking;
pub const InodeVersion = writer_options.InodeVersion;
pub const IndexFormat = writer_options.IndexFormat;
pub const Options = writer_options.Options;
pub const Sink = byte_sink.Sink;
pub const Encoder = encoder_state.Encoder;
pub const EncodeProgress = encoder_state.Progress;
pub const EncodeTarget = encoder_state.Target;
/// Live requested bytes in library allocations, excluding stack, caller-owned
/// entry/source/sink storage and backing-allocator bookkeeping.
pub const SinkLimits = encoder_state.Limits;
pub const SinkResult = encoder_state.Result;

pub const EncodedExternalChunks = struct {
    image: []u8,
    device: []u8,

    pub fn deinit(self: *EncodedExternalChunks, allocator: std.mem.Allocator) void {
        allocator.free(self.image);
        allocator.free(self.device);
        self.* = undefined;
    }
};

pub fn encodeAlloc(allocator: std.mem.Allocator, entries: []const Entry, options: Options) Error![]u8 {
    var output = byte_sink.BufferSink.init(allocator);
    defer output.deinit();
    _ = encodeToSink(allocator, entries, options, output.sink(), .{ .max_working_memory = std.math.maxInt(usize) }) catch |err| {
        if (err == error.SinkWriteFailed and output.allocation_failed) return error.OutOfMemory;
        return err;
    };
    return output.take();
}

pub fn encodeExternalChunksAlloc(allocator: std.mem.Allocator, entries: []const Entry, options: Options) Error!EncodedExternalChunks {
    var image = byte_sink.BufferSink.init(allocator);
    defer image.deinit();
    var device = byte_sink.BufferSink.init(allocator);
    defer device.deinit();
    _ = encodeExternalChunksToSinks(allocator, entries, options, image.sink(), device.sink(), .{ .max_working_memory = std.math.maxInt(usize) }) catch |err| {
        if (err == error.SinkWriteFailed and (image.allocation_failed or device.allocation_failed)) return error.OutOfMemory;
        return err;
    };
    const image_bytes = try image.take();
    errdefer allocator.free(image_bytes);
    return .{ .image = image_bytes, .device = try device.take() };
}

/// Emits positional pieces from the resumable core. Errors may leave partial
/// output; lengths are committed only after successful emission.
pub fn encodeToSink(allocator: std.mem.Allocator, entries: []const Entry, options: Options, sink: Sink, limits: SinkLimits) Error!SinkResult {
    return encodeSinks(allocator, entries, options, sink, null, limits);
}

/// Device completion precedes primary completion and is not atomic across sinks.
pub fn encodeExternalChunksToSinks(allocator: std.mem.Allocator, entries: []const Entry, options: Options, sink: Sink, device: Sink, limits: SinkLimits) Error!SinkResult {
    if (options.chunk_size == null) return error.InvalidErofs;
    return encodeSinks(allocator, entries, options, sink, device, limits);
}

fn encodeSinks(allocator: std.mem.Allocator, entries: []const Entry, options: Options, sink: Sink, device: ?Sink, limits: SinkLimits) Error!SinkResult {
    if (sink.max_write_size == 0) return error.SinkWriteFailed;
    if (device) |output| if (output.max_write_size == 0) return error.SinkWriteFailed;
    var encoder: Encoder = undefined;
    if (device != null) try encoder.initExternalChunks(allocator, entries, options, limits) else try encoder.init(allocator, entries, options, limits);
    defer encoder.deinit();
    var buffer: [64 * 1024]u8 = undefined;
    while (true) {
        const progress = try encoder.read(&buffer);
        if (progress.output_written != 0) {
            const output = if (progress.target == .image) sink else device orelse return error.InvalidErofs;
            try output.writeExact(progress.offset, buffer[0..progress.output_written]);
        }
        if (progress.status == .done) break;
    }
    const result = encoder.result().?;
    if (device) |output| try output.finish(result.device_size);
    try sink.finish(result.image_size);
    return result;
}
