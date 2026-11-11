//! Borrow validation for contiguous caller-buffer Raw Deflate decoding.
//! The complete output slice must be disjoint from compressed input and preset
//! dictionary storage before parsing or copying can modify caller memory.

pub fn validate(input: []const u8, dictionary: []const u8, output: []const u8) error{InvalidBlockPlan}!void {
    if (overlaps(output, input) or overlaps(output, dictionary))
        return error.InvalidBlockPlan;
}

/// Compare half-open byte ranges without adding lengths to addresses.
pub fn overlaps(left: []const u8, right: []const u8) bool {
    if (left.len == 0 or right.len == 0) return false;
    const left_start = @intFromPtr(left.ptr);
    const right_start = @intFromPtr(right.ptr);
    return if (left_start <= right_start)
        right_start - left_start < left.len
    else
        left_start - right_start < right.len;
}
