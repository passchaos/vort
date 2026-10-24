const core = @import("../core.zig");
const decoder = @import("quantum/decoder.zig");
const literal = @import("quantum/literal_encoder.zig");

pub const Error = core.Error || @import("quantum/encoder.zig").Error;
pub const decodeAlloc = decoder.decodeAlloc;
pub const LiteralEncoder = literal.LiteralEncoder;
pub const PlanEncoder = @import("quantum/item_encoder.zig").Encoder;
pub const EncodeItem = @import("quantum/item_stream.zig").Item;
pub const Encoder = @import("quantum/encoder.zig").Encoder;
pub const Options = @import("quantum/encoder.zig").Options;
pub const Strategy = @import("quantum/encoder.zig").Strategy;

test {
    _ = @import("quantum/reference_tests.zig");
    _ = @import("quantum/item_encoder_tests.zig");
}
