//! Focused ownership and actual-chooser contracts without the Brotli facade.
comptime {
    _ = @import("br/encoder/literal_context_split/workspace.zig");
    _ = @import("br/encoder/literal_context_split/workspace_reuse_tests.zig");
}
