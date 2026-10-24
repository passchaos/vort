const std = @import("std");
const tables = @import("tables.zig");
const frame_size = tables.frame_size;
const Model = @import("model.zig").Model;
const ArithmeticDecoder = @import("arithmetic.zig").Decoder;
const ArithmeticEncoder = @import("arithmetic.zig").Encoder;
const MsbBitWriter = @import("bit_stream.zig").Writer;

/// Functionality-first Quantum encoder. It emits literal-only arithmetic
/// frames while preserving the adaptive models across calls. CAB writers add
/// the per-CFDATA 0xff sentinel after each returned payload.
pub const LiteralEncoder = struct {
    literal_models: [4]Model,
    selector_model: Model,

    pub fn init() LiteralEncoder {
        return .{
            .literal_models = .{
                Model.init(0, 64),
                Model.init(64, 64),
                Model.init(128, 64),
                Model.init(192, 64),
            },
            .selector_model = Model.init(0, 7),
        };
    }

    pub fn encodeFrameAlloc(
        self: *LiteralEncoder,
        allocator: std.mem.Allocator,
        input: []const u8,
    ) ![]u8 {
        if (input.len == 0 or input.len > frame_size) return error.InvalidBlockPlan;

        var next = self.*;
        var verify_literals = self.literal_models;
        var verify_selector = self.selector_model;
        var writer = MsbBitWriter{};
        errdefer writer.bytes.deinit(allocator);
        var arithmetic = ArithmeticEncoder{ .writer = &writer };
        arithmetic.startFrame();
        for (input) |byte| {
            const selector = byte >> 6;
            try arithmetic.encodeSymbol(allocator, &next.selector_model, selector);
            try arithmetic.encodeSymbol(allocator, &next.literal_models[selector], byte);
        }
        try arithmetic.finishFrame(allocator);
        try writer.alignToByte(allocator);
        try writer.bytes.appendNTimes(allocator, 0, 4);

        if (input.len == frame_size) {
            // Keep only bytes the arithmetic decoder consumes, then append the
            // format's maximum legal null padding before CAB injects 0xff.
            var verifier = ArithmeticDecoder{ .reader = .{ .input = writer.bytes.items } };
            try verifier.startFrame();
            for (input) |expected| {
                const selector = try verifier.decodeSymbol(&verify_selector);
                if (selector >= verify_literals.len) return error.InvalidQuantumStream;
                const literal = try verifier.decodeSymbol(&verify_literals[selector]);
                if (literal != expected) return error.InvalidQuantumStream;
            }
            verifier.reader.alignToByte();
            if (verifier.reader.byte_offset > writer.bytes.items.len)
                return error.InvalidQuantumStream;
            writer.bytes.shrinkRetainingCapacity(verifier.reader.byte_offset);
            try writer.bytes.appendNTimes(allocator, 0, 4);
        }
        const bytes = try writer.bytes.toOwnedSlice(allocator);
        self.* = next;
        return bytes;
    }
};
