const std = @import("std");
const core = @import("../../core.zig");

pub const symbol_input_guard: usize = 64;
pub const max_symbol_output: usize = 273;
pub const Error = core.Error || error{ InvalidLzma2Stream, CompressedBufferLimitExceeded };

pub const Options = struct {
    dictionary_property: u8,
    max_dictionary_size: usize = std.math.maxInt(usize),
    max_output_len: usize = std.math.maxInt(usize),
    expected_output_len: ?usize = null,
    /// Range-coded input retained for one symbol transaction. LZMA needs at
    /// most 64 lookahead bytes; this cap never limits the declared chunk size.
    max_compressed_buffer_len: usize = symbol_input_guard,
    max_working_memory: usize = std.math.maxInt(usize),
    /// Leave the input suffix after control zero to the enclosing container.
    stop_after_end_marker: bool = false,

    pub fn validate(self: Options) Error!usize {
        const size = try dictionarySizeFromProperty(self.dictionary_property);
        if (size > self.max_dictionary_size) return error.OutputLimitExceeded;
        const dictionary_size = std.math.cast(usize, size) orelse return error.OutputLimitExceeded;
        if (self.expected_output_len) |expected|
            if (expected > self.max_output_len) return error.OutputLimitExceeded;
        return dictionary_size;
    }
};

pub fn dictionarySizeFromProperty(property: u8) Error!u64 {
    if (property > 40) return error.InvalidLzma2Stream;
    if (property == 40) return std.math.maxInt(u32);
    return @as(u64, 2 | (property & 1)) << @intCast(property / 2 + 11);
}
