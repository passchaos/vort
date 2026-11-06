#!/usr/bin/env python3
"""Exercise real upstream parameter 4 values and verify all literal 64 maps."""
from __future__ import annotations

import argparse
import base64
import hashlib
import json
from pathlib import Path

from reference import Library


def fixtures():
    sentences = ["压缩数据需要根据上下文统计不同字节。", "编码器保留静态字典并验证兼容性。",
                 "每种块类型都有六十四个上下文。", "Hello reader: complete literal maps matter.",
                 "多语言 JSON 数据与源码可产生统计差异。"]
    return {
        "utf8": "\n".join(sentences[index % 5] + str(index) + " " + sentences[(index * 3 + 1) % 5]
                          for index in range(100)).encode(),
        "json": json.dumps([{"id": index, "active": index % 3 == 0, "label": "literal-model-" + str(index),
                             "name": sentences[index % 5], "value": (index * 7919) % 100001}
                            for index in range(96)], ensure_ascii=False, separators=(",", ":")).encode(),
        "source": "\n".join(f"fn check_{index}(input: []const u8) !u32 {{\n"
                              f"    const seed: u32 = {index * 7919};\n"
                              f"    if (input.len < {index % 17}) return error.InvalidInput;\n"
                              f"    return seed ^ input[{index % 7}];\n}}"
                              for index in range(64)).encode(),
    }


def run(library=None):
    library = library or Library()
    cases = []
    counterexamples = {}
    split_true = False
    utf8_mode_true = False
    for name, payload in fixtures().items():
        expected = hashlib.sha256(payload).hexdigest()
        for quality in (0, 4, 5, 9, 11):
            for large in (False, True):
                for disable in (False, True):
                    wire = library.produce(payload, quality, disable, large=large)
                    result = library.inspect(wire)
                    if not result["reference_decoded"] or result["decoded_sha256"] != expected:
                        raise AssertionError(("reference complete decode", name, quality, large, disable))
                    if base64.b64decode(result["decoded_base64"]) != payload:
                        raise AssertionError(("reference complete content", name, quality, large, disable))
                    if disable and not result["literal_maps_constant"]:
                        raise AssertionError(("parameter 4=true emitted nonconstant map", name, quality, large))
                    if not disable and result["nonconstant_literal_maps"]:
                        counterexamples.setdefault(name, {"quality": quality, "large": large,
                                                         "wire_sha256": result["wire_sha256"]})
                    compressed = [block for block in result["metablocks"] if block["kind"] == "compressed"]
                    if disable:
                        split_true |= any(block["literal_block_types"] > 1 for block in compressed)
                        utf8_mode_true |= any(item["context_mode"] == 2 for block in compressed
                                              for item in block["literal_context_maps"])
                    # Keep the evidence compact; the complete bytes were verified above.
                    result.pop("decoded_base64", None)
                    result.pop("decoded_utf8", None)
                    cases.append({"fixture": name, "quality": quality, "disable": disable,
                                  "large_window": large, "plaintext_sha256": expected,
                                  "wire_size": len(wire), "observation": result})
    if set(counterexamples) != set(fixtures()):
        raise AssertionError(("missing actual false nonconstant-map fixture", counterexamples))
    if not split_true or not utf8_mode_true:
        raise AssertionError(("missing true map fixture preserving block splitting/context mode", split_true, utf8_mode_true))
    for payload in (b"", b"x", bytes(range(256))):
        for disable in (False, True):
            result = library.inspect(library.produce(payload, 5, disable))
            if base64.b64decode(result["decoded_base64"]) != payload or not result["literal_maps_constant"]:
                raise AssertionError("empty/tiny/binary reference control")
    good = library.produce(fixtures()["json"], 11, False)
    for label, wire in (("truncated", good[:-1]), ("trailing", good + b"\x00")):
        try:
            library.inspect(wire)
        except RuntimeError:
            pass
        else:
            raise AssertionError(("reference inspection accepted", label))
    return {"passed": True, "reference": library.identity(), "cases": cases,
            "summary": {"reference_parameter_4_pairs": len(cases) // 2,
                        "complete_reference_decodes": len(cases) + 6,
                        "malformed_rejections": 2, "false_nonconstant_fixture_counterexamples": counterexamples,
                        "true_literal_block_splitting_observed": split_true,
                        "true_utf8_context_mode_observed": utf8_mode_true}}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = run(Library(args.library))
    if args.output:
        args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(json.dumps(report["summary"], ensure_ascii=False, sort_keys=True))
