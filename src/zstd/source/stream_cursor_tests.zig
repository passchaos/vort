const dispatch = @import("stream_cursor_tests/dispatch.zig");
const transactions = @import("stream_cursor_tests/transactions.zig");

pub fn contracts(comptime Support: type) !void {
    try dispatch.contracts(Support);
    try transactions.contracts(Support);
}
