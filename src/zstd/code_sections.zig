const builtin = @import("builtin");

pub const wide_sequence_emit = switch (builtin.object_format) {
    .elf => ".vort_zstd_wide_sequence",
    .macho => "__TEXT,__vort_zstd_seq",
    .coff => ".text$vort_zstd_wide_sequence",
    else => ".text",
};

pub const fast_encode_helper = switch (builtin.object_format) {
    .elf => ".vort_zstd_fast_encode",
    .macho => "__TEXT,__vort_zstd_fast",
    .coff => ".text$vort_zstd_fast_encode",
    else => ".text",
};

pub const fast_sequence_record = switch (builtin.object_format) {
    .elf => ".vort_zstd_fast_records",
    .macho => "__TEXT,__vort_zstd_rec",
    .coff => ".text$vort_zstd_fast_records",
    else => ".text",
};

pub const fse_encode_helper = switch (builtin.object_format) {
    .elf => ".vort_zstd_fse_encode",
    .macho => "__TEXT,__vort_zstd_fse",
    .coff => ".text$vort_zstd_fse_encode",
    else => ".text",
};

pub const dominance_helper = switch (builtin.object_format) {
    .elf => ".vort_zstd_dominance",
    .macho => "__TEXT,__vort_zstd_dom",
    .coff => ".text$vort_zstd_dominance",
    else => ".text",
};

pub const huffman_build = switch (builtin.object_format) {
    .elf => ".vort_zstd_huffman_build",
    .macho => "__TEXT,__vort_zstd_hb",
    .coff => ".text$vort_zstd_huffman_build",
    else => ".text",
};

pub const reusable_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_reusable_decode",
    .macho => "__TEXT,__vort_zstd_rd",
    .coff => ".text$vort_zstd_reusable_decode",
    else => ".text",
};

pub const raw_fse_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_raw_fse_decode",
    .macho => "__TEXT,__vort_zstd_rfd",
    .coff => ".text$vort_zstd_raw_fse_decode",
    else => ".text",
};

pub const fse_fse_rle_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_ffr_decode",
    .macho => "__TEXT,__vort_zstd_ffr",
    .coff => ".text$vort_zstd_ffr_decode",
    else => ".text",
};

pub const fse_fse_rle_pair = switch (builtin.object_format) {
    .elf => ".vort_zstd_zz_ffr_pair",
    .macho => "__TEXT,__vort_zstd_ffp",
    .coff => ".text$vort_zstd_zz_ffr_pair",
    else => ".text",
};

pub const fse_rle_rle_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_frr_decode",
    .macho => "__TEXT,__vort_zstd_frr",
    .coff => ".text$vort_zstd_frr_decode",
    else => ".text",
};

pub const fse_rle_rle_pair = switch (builtin.object_format) {
    .elf => ".vort_zstd_zz_frr_pair",
    .macho => "__TEXT,__vort_zstd_frp",
    .coff => ".text$vort_zstd_zz_frr_pair",
    else => ".text",
};

pub const huffman_only_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_huffman_only_decode",
    .macho => "__TEXT,__vort_zstd_hod",
    .coff => ".text$vort_zstd_huffman_only_decode",
    else => ".text",
};

pub const small_sequence_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_small_sequence_decode",
    .macho => "__TEXT,__vort_zstd_ssd",
    .coff => ".text$vort_zstd_small_sequence_decode",
    else => ".text",
};

pub const small_frame_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_small_frame_decode",
    .macho => "__TEXT,__vort_zstd_sfd",
    .coff => ".text$vort_zstd_small_frame_decode",
    else => ".text",
};

pub const split_literal_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_split_literal_decode",
    .macho => "__TEXT,__vort_zstd_sld",
    .coff => ".text$vort_zstd_split_literal_decode",
    else => ".text",
};

pub const split_wide_literal_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_split_wide_literal_decode",
    .macho => "__TEXT,__vort_zstd_slw",
    .coff => ".text$vort_zstd_split_wide_literal_decode",
    else => ".text",
};

pub const split_dense_literal_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_split_dense_literal_decode",
    .macho => "__TEXT,__vort_zstd_sldn",
    .coff => ".text$vort_zstd_split_dense_literal_decode",
    else => ".text",
};

pub const split_generic_literal_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_split_zz",
    .macho => "__TEXT,__vort_zstd_slz",
    .coff => ".text$vort_zstd_split_zz",
    else => ".text",
};

pub const medium_split_literal_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_medium_split",
    .macho => "__TEXT,__vort_zstd_msl",
    .coff => ".text$vort_zstd_medium_split",
    else => ".text",
};

pub const multi_sequence_winner = switch (builtin.object_format) {
    .elf => ".vort_zstd_multi_sequence_winner",
    .macho => "__TEXT,__vort_zstd_msw",
    .coff => ".text$vort_zstd_multi_sequence_winner",
    else => ".text",
};

pub const long_match_decode = @import("sequence/code_sections.zig").long_match_decode;
