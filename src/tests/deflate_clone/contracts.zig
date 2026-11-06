const std = @import("std");
const encoder = @import("encoder.zig");
const raw_decoder = @import("raw_decoder.zig");
const wrapper_decoder = @import("wrapper_decoder.zig");
const wide = @import("wide.zig");

/// Identical public Deflate copy contracts run on native, x86 and WASI.
pub fn contracts(comptime D: type, allocator: std.mem.Allocator) !void {
    try encoder.contracts(D, allocator);
    try raw_decoder.contracts(D, allocator);
    try wrapper_decoder.contracts(D, allocator);
    try wide.contracts(D, allocator);
}
