const dispatch = @import("frame_executor_tests/dispatch.zig");
const transactions = @import("frame_executor_tests/transactions.zig");

pub fn contracts(comptime Support: type) !void {
    try dispatch.contracts(Support);
    try transactions.contracts(Support);
}
