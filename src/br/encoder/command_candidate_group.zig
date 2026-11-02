//! One immutable command plan owns its common preparation until all of its
//! preferred and split candidates finish. No allocation or borrowed result
//! survives this scope; unsupported callers retain the original controller.
pub noinline fn encode(
    comptime S: type,
    comptime traced: bool,
    trace: anytype,
    allocator: S.Allocator,
    input: []const u8,
    commands: []const S.Command,
    stats: *S.Stats,
    options: S.Options,
) S.Error![]u8 {
    var common: S.Common = .{};
    var shared_options = options;
    shared_options.shared_common = &common;
    return S.encodeFinal(traced, trace, allocator, input, commands, stats, shared_options);
}
