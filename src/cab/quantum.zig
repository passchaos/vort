const core = @import("../core.zig");
const decoder = @import("quantum/decoder.zig");
const literal = @import("quantum/literal_encoder.zig");

pub const Error = core.Error || error{ InvalidQuantumStream, UnsupportedCabinetFeature };
pub const decodeAlloc = decoder.decodeAlloc;
pub const LiteralEncoder = literal.LiteralEncoder;

test {
    _ = @import("quantum/reference_tests.zig");
}
