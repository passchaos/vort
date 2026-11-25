"""Reconcile archived production-path distance counts and frozen inputs."""
import argparse
import json
from pathlib import Path

from evidence import require


FIELDS = ("requests", "packed_requests", "expansions", "misses_1", "misses_rr2",
          "misses_rr4", "misses_lru2", "misses_lru4")
FIXTURES = {
    "brotli-mozilla-full-q11": "mozilla.full.brotli.11",
    "brotli-mozilla-full-q6": "mozilla.full.brotli.6",
    "brotli-mozilla-1m-q11": "mozilla.1048576.brotli.11",
}


def verify(root):
    verified = json.loads((root / "frozen-verification.json").read_text())
    require(set(verified["rows"]) == FIXTURES.keys(), "Wrong fixture set")
    refs = verified["references"]
    for role in ("encoder", "decoder", "common"):
        path = refs[role]
        require(verified["verified"][path]["sha256"] == refs["file_sha256"][path], "Reference digest drift")
    for key, name in FIXTURES.items():
        row = json.loads((root / (name + ".json")).read_text())
        fixture = verified["rows"][key]
        require(row["schema"] == "vort.brotli.distance-reuse-trace.v1", "Wrong trace schema")
        for scope, src in (("wire", "encoded"), ("plain", "input")):
            path = row[scope + "_path"]
            fixture_path = fixture["encoded_input_path" if src == "encoded" else "input_path"]
            require(path == fixture_path and row[scope + "_bytes"] == fixture[src + "_bytes"], "Fixture drift")
            require(verified["verified"][path] == {"sha256": fixture[src + "_sha256"], "bytes": row[scope + "_bytes"]}, "Fixture digest drift")
        require(row["reference_version"] == refs["version"] == "1.2.0", "Reference version drift")
        require(all(row["reference_" + role] == refs[role] for role in ("encoder", "decoder", "common")), "Wrong reference closure")
        require(row["vort_decodes"] == row["reference_decodes"] == 1 and row["outputs_both_match_frozen_plain"] is True, "Wrong decode scope")
        require(row["expanded_table_bytes"] == 3752, "Wrong expanded-slot size")
        end = 0
        blocks = row["blocks"]
        require(len(blocks) == row["meta_blocks_seen"], "Wrong meta-block count")
        for index, block in enumerate(blocks):
            require(block["meta_block_index"] == index and block["output_start"] == end and block["output_len"] > 0, "Discontinuous block progress")
            end += block["output_len"]
            require(all(type(block[field]) is int and block[field] >= 0 for field in FIELDS), "Invalid counter")
            require(block["requests"] >= block["packed_requests"] >= block["expansions"] == block["misses_1"], "One-slot model differs from actual decode")
            if block["packed_requests"]:
                require(64 < block["tree_count"] <= 256, "Unexpected packed tree tier")
            require(all(block[name] <= block["packed_requests"] for name in FIELDS[4:]), "Shadow miss count exceeds requests")
            require(block["misses_lru4"] <= block["misses_lru2"] <= block["misses_1"], "LRU stack property failed")
        require(end == row["plain_bytes"], "Incomplete decoded output span")
        require(row["totals"] == {field: sum(block[field] for block in blocks) for field in FIELDS}, "Incorrect totals")
    print("Verified all three traced fixtures, block spans and shadow miss totals")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace", type=Path)
    verify(parser.parse_args().trace)
