//! Retain the active frame binding across recoverable destination and heap
//! refusals. A subsequent frame never receives a consumed active prefix.

pub fn retryable(err: anyerror) bool {
    return switch (err) {
        error.OutOfMemory, error.WorkingMemoryLimitExceeded, error.OutputTooSmall, error.OutputLimitExceeded => true,
        else => false,
    };
}
