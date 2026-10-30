const builtin = @import("builtin");

/// Keep the ordinary complete-output semantic loop outside the other decoder
/// text. Subsequent hot-loop changes leave ordinary decoder text ordering intact.
pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_semantic_full",
    .macho => "__TEXT,__vort_sem_full",
    .coff => ".text$vort_semantic_full",
    else => ".text",
};
