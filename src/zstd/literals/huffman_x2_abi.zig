pub const Status = enum(c_int) {
    success = 0,
    unsupported = 1,
    truncated = 2,
    corrupt = 3,
};

pub const Request = extern struct {
    tree: *const anyopaque,
    stream_ptrs: [4][*]const u8,
    stream_lens: [4]usize,
    dest_ptr: [*]u8,
    dest_len: usize,
};
