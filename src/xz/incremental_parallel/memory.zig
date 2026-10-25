//! XZ compatibility aliases for the shared worker-pipeline heap authority.
const shared = @import("../../io/threaded_working_memory.zig");
pub const Error = shared.Error;
pub const control_bytes = shared.control_bytes;
pub const Snapshot = shared.Snapshot;
pub const Control = shared.Control;
pub const Budget = shared.Budget;
pub const Slot = shared.Slot;

test {
    _ = @import("memory_tests.zig");
}
