//! Dictionary calls snapshot their borrowed bytes before changing history.
const raw = @import("dictionary_borrows/raw.zig");
const wrappers = @import("dictionary_borrows/wrappers.zig");
const stopped = @import("dictionary_borrows/stopped.zig");

test {
    _ = raw;
    _ = wrappers;
    _ = stopped;
}
