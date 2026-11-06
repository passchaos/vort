//! Validation and pointer rebinding for caller-owned decoder copies.
const std = @import("std");

pub const Error = error{ InvalidCloneStorage, OverlappingCloneStorage };

pub fn disjoint(first: []const u8, second: []const u8) Error!void {
    if (first.len == 0 or second.len == 0) return;
    const a = @intFromPtr(first.ptr);
    const b = @intFromPtr(second.ptr);
    const overlaps = if (a <= b) b - a < first.len else a - b < second.len;
    if (overlaps) return error.OverlappingCloneStorage;
}

pub fn rejectDestinationOverlap(destination: anytype, storage: anytype, borrowed: []const u8) Error!void {
    try disjoint(std.mem.asBytes(destination), borrowed);
    try disjoint(storage.history, borrowed);
    if (storage.semantic_workspace) |workspace|
        try disjoint(std.mem.asBytes(workspace), borrowed);
}

/// A raw clone checks its own object; wrappers also protect their surrounding
/// header, checksum and dictionary state before making any writes.
pub fn validateWrapper(source: anytype, destination: anytype, storage: anytype) Error!void {
    const source_bytes = std.mem.asBytes(source);
    const destination_bytes = std.mem.asBytes(destination);
    try disjoint(source_bytes, destination_bytes);
    try disjoint(source_bytes, source.raw.history);
    try disjoint(source_bytes, source.raw.semantic_scratch);
    try disjoint(source_bytes, storage.history);
    try disjoint(destination_bytes, source.raw.history);
    try disjoint(destination_bytes, source.raw.semantic_scratch);
    try disjoint(destination_bytes, storage.history);
    if (source.raw.semantic_decoder) |workspace| {
        try disjoint(source_bytes, std.mem.asBytes(workspace));
        try disjoint(destination_bytes, std.mem.asBytes(workspace));
    }
    if (storage.semantic_workspace) |workspace| {
        try disjoint(source_bytes, std.mem.asBytes(workspace));
        try disjoint(destination_bytes, std.mem.asBytes(workspace));
    }
}

/// Call only after placing the copied raw decoder at its final stable address.
pub fn rebindRaw(raw: anytype) void {
    if (comptime @hasField(@TypeOf(raw.*).SemanticWorkspace, "compact_literal")) {
        if (raw.semantic_decoder) |workspace| {
            workspace.compact_literal = &raw.dynamic_literal_table;
            workspace.compact_distance = &raw.dynamic_distance_table;
        }
    }
}
