const dictionary = @import("compressed_block_tests/dictionary.zig");
const dictionary_workspace = @import("compressed_block_tests/dictionary_workspace.zig");
const happy = @import("compressed_block_tests/happy.zig");
const state = @import("compressed_block_tests/state.zig");
const transactions = @import("compressed_block_tests/transactions.zig");
const workspace = @import("compressed_block_tests/workspace.zig");

pub fn contracts(comptime Support: type) !void {
    try happy.contracts(Support);
    try state.contracts(Support);
    try transactions.contracts(Support);
    try workspace.contracts(Support);
    try dictionary.contracts(Support);
    try dictionary_workspace.contracts(Support);
}
