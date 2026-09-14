pub const Token = extern struct {
    kind: u8,
    literal: u8,
    length: u16,
    distance: u16,
    reserved: u16 = 0,
};

pub const Stats = extern struct {
    token_count: usize = 0,
    literal_count: usize = 0,
    match_count: usize = 0,
    matched_bytes: usize = 0,
};

pub const hash_head_len: usize = 1 << 15;
pub const hash_head_init_words: usize = hash_head_len / 64;
pub const max_match_len: usize = 258;
