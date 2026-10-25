//! Narrow benchmark module rooted at src so codec-relative imports retain
//! their normal boundary without compiling the library's complete root.
const command_plan = @import("br/encoder/command_plan.zig");
pub const PrefixAlphabetFor = command_plan.PrefixAlphabetFor;
pub const alphabetFromFrequencies = command_plan.alphabetFromFrequencies;
pub const CodeLengthsBuildProfile = command_plan.CodeLengthsBuildProfile;
