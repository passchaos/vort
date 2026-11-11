const dispatch = @import("frame_executor_tests/dispatch.zig");
const transactions = @import("frame_executor_tests/transactions.zig");
const output_alias = @import("frame_executor_tests/output_alias.zig");

pub fn contracts(comptime Support: type) !void {
    try dispatch.contracts(Support);
    try transactions.contracts(Support);
    try output_alias.contracts(Support);
}
