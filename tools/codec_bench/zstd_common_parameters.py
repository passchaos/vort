"""Validate requested common HQ controls without claiming internal equivalence."""


def validate(settings, require):
    primary = settings["resolved_primary"]
    reference = settings["reference"]
    params = reference.get("requested_parameters")
    require(reference["api"] == "ZSTD_compress2", "common HQ: wrong reference API")
    require(reference["internal_parameters"].startswith("public_requested_parameters"),
            "common HQ: missing requested-parameter scope")
    require(settings["api"] == "native_frame", "common HQ: explicit native API required")
    require(settings.get("requested_controls_match") is True, "common HQ: missing accepted control match")
    require(isinstance(settings.get("search_budget_scope"), str)
            and "nominal" in settings["search_budget_scope"], "common HQ: search scope must remain nominal")
    require(isinstance(params, dict), "common HQ: missing requested reference parameters")
    required = {"level", "window_log", "hash_log", "chain_log", "search_log", "min_match",
                "target_length", "strategy", "content_size", "checksum", "workers",
                "long_distance_matching", "dict_id"}
    require(set(params) >= required, "common HQ: incomplete requested reference parameters")
    require(all(type(params[key]) is int for key in required), "common HQ: reference values must be integers")
    require(params["level"] == reference["level"] == settings["level"], "common HQ: reference level differs")
    strategies = {"btopt": 7, "btultra": 8, "btultra2": 9}
    require(primary["strategy"] in strategies, "common HQ: unsupported strategy")
    require(params["strategy"] == strategies[primary["strategy"]], "common HQ: strategy differs")
    require(settings["requested_strategy"] == primary["strategy"], "common HQ: requested strategy differs")
    require(settings["requested_fast_acceleration"] is None
            and settings["requested_native_selection"] is None
            and primary["fast_acceleration"] is None
            and primary["selection"] == "fast_compressed", "common HQ: incompatible acceleration/selection")
    window = primary["window_log"]
    require(type(window) is int and 10 <= window <= 30, "common HQ: invalid window")
    require(params["window_log"] == window, "common HQ: window request differs")
    ceiling = min(1 << window, 131072)
    require(settings.get("reference_block_ceiling") == primary["block_size_max"] == ceiling,
            "common HQ: natural block ceiling differs")
    require(primary["max_match_history_len"] == 1 << window, "common HQ: native history cap differs")
    hq = primary["hq"]
    require(isinstance(hq, dict), "common HQ: missing explicit HQ controls")
    depth = hq["search_depth"]
    require(type(depth) is int and 2 <= depth <= 65536 and depth & (depth - 1) == 0, "common HQ: nonrepresentable depth")
    require(params["search_log"] == depth.bit_length() - 1, "common HQ: nominal search budget differs")
    require(params["min_match"] == hq["min_match"] and hq["min_match"] in (3, 4), "common HQ: minimum differs")
    require(params["target_length"] == hq["nice_len"], "common HQ: nice length request differs")
    require(hq["min_match"] <= hq["nice_len"] <= 131072, "common HQ: invalid nice length")
    require(params["hash_log"] == 0 and params["chain_log"] == 0, "common HQ: undeclared hash/chain requests")
    require(hq["parse_mode"] == "bounded" and hq["match_lengths"] == "sampled"
            and hq["max_price_evaluations"] is None, "common HQ: unsupported search policy")
    require(params["workers"] == 0 and params["long_distance_matching"] == 0 and params["dict_id"] == 1,
            "common HQ: worker/LDM/dictionary flag differs")
    require(params["checksum"] == int(primary["content_checksum"]), "common HQ: checksum request differs")
    require(params["content_size"] == int(primary["include_content_size"]), "common HQ: size request differs")
    require(primary["control_profile_enabled"] is False and primary["memory_profile_enabled"] is False,
            "common HQ: timed calls include diagnostic profiles")
    for header in (settings["wire_header"], reference["wire_header"]):
        require(header["content_checksum"] == primary["content_checksum"], "common HQ: actual checksum differs")
        require((header["content_size"] is not None) == primary["include_content_size"],
                "common HQ: actual size declaration differs")
        require(header["window_size"] <= 1 << window, "common HQ: actual frame window exceeds request")
    require(settings["wire_header"]["dictionary_id"] == reference["wire_header"]["dictionary_id"],
            "common HQ: actual dictionary IDs differ")
    profile = settings.get("vort_profile")
    require(isinstance(profile, dict) and profile.get("available") is True, "common HQ: missing native diagnostics")
    require(profile.get("resolved_strategy") == primary["strategy"], "common HQ: native resolved strategy differs")
    require(profile.get("requested_window_size") == 1 << window, "common HQ: native requested window differs")
    require(profile.get("effective_match_history_len") == 1 << window, "common HQ: native history differs")
    if profile.get("hq_used"):
        require(profile.get("effective_hq_search_depth") == depth
                and profile.get("effective_hq_nice_len") == hq["nice_len"]
                and profile.get("effective_hq_min_match") == hq["min_match"], "common HQ: native applied HQ controls differ")
    kind = settings.get("dictionary_kind")
    size = settings.get("dictionary_bytes")
    digest = settings.get("dictionary_sha256")
    if kind is None:
        require(size == 0 and digest is None and settings.get("dictionary_preparation_timed") is False,
                "common HQ: inconsistent absent dictionary")
    else:
        require(kind in ("raw_content", "standard_full") and type(size) is int and size >= 0,
                "common HQ: invalid dictionary metadata")
        require(isinstance(digest, str) and len(digest) == 64
                and all(c in "0123456789abcdef" for c in digest), "common HQ: invalid dictionary digest")
        require(settings.get("dictionary_preparation_timed") is True, "common HQ: dictionary preparation scope differs")
        if kind == "raw_content":
            require(settings["wire_header"]["dictionary_id"] == 0, "common HQ: raw dictionary declares an ID")
