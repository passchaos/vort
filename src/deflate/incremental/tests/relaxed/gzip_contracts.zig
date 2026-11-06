//! Relaxed gzip validation, member boundaries, and error-progress contracts.
pub fn contracts(comptime D: type) !void {
    try @import("gzip_footer.zig").contracts(D);
    try @import("gzip_members.zig").contracts(D);
    try @import("gzip_progress.zig").contracts(D);
}
