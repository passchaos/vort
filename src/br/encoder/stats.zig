pub const PlannedEncodeStats = struct {
    input_bytes: usize = 0,
    token_count: usize = 0,
    command_count: usize = 0,
    literal_symbol_count: usize = 0,
    command_symbol_count: usize = 0,
    distance_symbol_count: usize = 0,
    literal_bytes: usize = 0,
    matched_bytes: usize = 0,
    encoded_bytes: usize = 0,
    lz77_ns: u64 = 0,
    command_plan_ns: u64 = 0,
    wire_ns: u64 = 0,
};
