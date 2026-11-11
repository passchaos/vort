//! Output publication must preserve every borrowed workspace and dictionary.
const std = @import("std");
const core = @import("../../core.zig");
const stable = @import("../decode/stable_output.zig");

pub fn validateRegions(destination: []const u8, regions: []const []const u8) core.Error!void {
    for (regions) |region| try stable.validateAlias(destination, region);
}

pub fn validateWorkspace(destination: []const u8, workspace: anytype) core.Error!void {
    try validateRegions(destination, &.{ workspace.history, workspace.staging, workspace.literal_page, workspace.sequence_page });
}

fn validateDictionary(destination: []const u8, dictionary: anytype) core.Error!void {
    try stable.validateAlias(destination, dictionary.content);
    if (dictionary.standard_bytes) |bytes| try stable.validateAlias(destination, bytes);
    if (dictionary.prepared) |prepared| try stable.validateAlias(destination, std.mem.asBytes(prepared));
}

/// Validate the complete configured catalog before an earlier frame can
/// overwrite a dictionary or a descriptor needed by a later frame.
pub fn validateOptions(destination: []const u8, options: anytype) core.Error!void {
    if (options.dictionary) |dictionary| try validateDictionary(destination, dictionary);
    if (options.dictionary_set) |set| {
        _ = std.math.mul(usize, set.dictionaries.len, @sizeOf(@TypeOf(set.dictionaries[0]))) catch return error.IntegerOverflow;
        try stable.validateAlias(destination, std.mem.sliceAsBytes(set.dictionaries));
        for (set.dictionaries) |dictionary| try validateDictionary(destination, dictionary);
    }
}

pub fn validateOperation(destination: []const u8, workspace: anytype, options: anytype) core.Error!void {
    try validateWorkspace(destination, workspace);
    try validateOptions(destination, options);
    inline for (.{ "history", "staging", "literal_page", "sequence_page" }) |field|
        try validateOptions(@field(workspace, field), options);
}
