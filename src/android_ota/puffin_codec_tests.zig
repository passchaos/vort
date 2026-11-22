const valid = @import("puffin_codec_tests/valid.zig");
const invalid = @import("puffin_codec_tests/invalid.zig");
const resources = @import("puffin_codec_tests/resources.zig");
const padding = @import("puffin_codec_tests/padding.zig");
pub fn contracts(comptime Codec: type) !void {
    try valid.contracts(Codec);
    try invalid.contracts(Codec);
    try resources.contracts(Codec);
    try padding.contracts(Codec);
}
