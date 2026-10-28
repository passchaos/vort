//! Stable parameter IDs shared by the local 1.6.0 and system 1.4.8 headers.
//! Values read by ZSTD_CCtx_getParameter describe requests, including default
//! sentinels such as zero. They do not describe applied parser internals.
pub const Parameter = enum(c_int) {
    level = 100,
    window_log = 101,
    hash_log = 102,
    chain_log = 103,
    search_log = 104,
    min_match = 105,
    target_length = 106,
    strategy = 107,
    long_distance_matching = 160,
    content_size = 200,
    checksum = 201,
    dict_id = 202,
    workers = 400,
};

pub const RequestedParameters = struct {
    level: c_int,
    window_log: c_int,
    hash_log: c_int,
    chain_log: c_int,
    search_log: c_int,
    min_match: c_int,
    target_length: c_int,
    strategy: c_int,
    content_size: c_int,
    checksum: c_int,
    workers: c_int,
    long_distance_matching: c_int,
    /// Requested ZSTD_c_dictIDFlag, not the loaded dictionary's numeric ID.
    dict_id: c_int,
};
