#!/usr/bin/env python3
"""Generate prefix frames, actual staged observations, and the retained audit.

Run: fixtures.py OUTPUT_DIRECTORY [--library PATH] [--header PATH]
Every stage records its operation/provider/frames, actual observable result,
expected payload or error category, and public parameter/progress snapshots.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import random

HERE = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location("_prefix_fixture_reference", HERE / "reference.py")
reference = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(reference)
Library = reference.Library


def _write(path, data):
    path.write_bytes(data)
    return reference.artifact(path)


def _action(operation, **arguments):
    return {"operation": operation, "arguments": arguments}


def _execute(root, library, recipe, data, assets, frames):
    stages = []
    with library.context(recipe["side"], format=recipe["format"]) as context:
        for index, action in enumerate(recipe.pop("actions")):
            args = dict(action["arguments"])
            operation = action["operation"]
            source = args.get("input")
            output_expected = args.get("expect_output")
            output = None
            actual_frames = [frames[source]] if source in frames else []
            if operation == "ref_prefix":
                result = context.ref_prefix(data.get(source, b""), kind=args.get("kind", "default"),
                                            null=args.get("null", False), size=args.get("size"))
            elif operation == "load_dictionary":
                result = context.load_dictionary(data.get(source, b""), kind=args.get("kind", "auto"))
            elif operation == "reset":
                result = context.reset(args["directive"])
            elif operation == "set_parameter":
                result = context.set_parameter(args["parameter"], args["value"])
            elif operation == "pledge":
                result = context.pledge(args.get("size"))
            elif operation == "encode_once":
                result, output = context.encode_one_shot(data[source], capacity=args.get("capacity"))
            elif operation == "decode_once":
                result, output = context.decode_one_shot(data[source], capacity=args.get("capacity", 20000))
            elif operation == "encode_step":
                result, output = context.encode_step(data.get(source, b""), directive=args.get("directive", "continue"),
                                                      output_capacity=args.get("output_capacity", 113))
            elif operation == "decode_step":
                result, output = context.decode_step(data.get(source, b""), output_capacity=args.get("output_capacity", 113))
            elif operation == "drive_encode":
                result, output = context.drive_encode(data[source], chunk_size=args.get("chunk_size", 31))
            elif operation == "drive_decode":
                result, output = context.drive_decode(data.get(source, b""), chunk_size=args.get("chunk_size", 1),
                                                       stop_at_frame=args.get("stop_at_frame", False))
            else:
                raise ValueError("Unknown recipe operation " + operation)
            expected = {"category": reference.category(result), "error": result.get("error")}
            if output is not None:
                output_artifact = _write(root / f"{recipe['name']}-stage{index}.output", output)
                expected["output"] = output_artifact
                if output_expected is not None:
                    expected["equals_payload"] = not result.get("error") and output == data[output_expected]
                    expected["payload"] = assets.get(output_expected, frames.get(output_expected))
            if args.get("require_success") and result.get("error"):
                raise AssertionError((recipe["name"], operation, result))
            if args.get("require_error") and not result.get("error"):
                raise AssertionError((recipe["name"], "expected actual C error", result))
            if args.get("require_match") and not expected.get("equals_payload"):
                raise AssertionError((recipe["name"], "actual C output mismatch", expected))
            if source is not None:
                args["input_path"] = assets.get(source, frames.get(source, {})).get("path")
            snapshot = result.pop("snapshot")
            stages.append({"operation": operation, "provider": "libzstd", "arguments": args,
                           "frames": actual_frames, "observable_result": result,
                           "expected": expected, "snapshot": snapshot})
    recipe["stages"] = stages
    return recipe


def generate(root: Path | str, library: Library | None = None) -> dict:
    root = Path(root).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    library = Library() if library is None else library
    audit = library.replay_audit(root / "audit")
    if not audit["passed"]:
        (root / "audit-failure.json").write_text(json.dumps(audit, indent=2) + "\n")
        raise AssertionError("Retained prefix audit did not match; see audit-failure.json")
    data = {"raw_a": random.Random(81).randbytes(16384), "raw_b": random.Random(82).randbytes(16384),
            "empty": b"", "invalid_full": b"not a full dictionary"}
    data["payload_a"], data["payload_b"] = data["raw_a"][-4096:] * 2, data["raw_b"][-4096:] * 2
    testdata = reference.REPO / "src/zstd/testdata"
    dictionary_source = testdata / "libzstd-trained-repeat.dict.hex"
    frame_source = testdata / "libzstd-trained-repeat.frame.hex"
    data["full"] = bytes.fromhex(dictionary_source.read_text())
    archived = bytes.fromhex(frame_source.read_text())
    data["payload_full"] = library.decode(archived, dictionary=data["full"], api="one_shot")
    assets = {name: _write(root / (name + ".bin"), value) for name, value in data.items()}
    data["skip"] = library.skippable()
    data["skip_empty"] = library.skippable(b"", 0)
    assets.update({name: _write(root / (name + ".zst"), data[name]) for name in ("skip", "skip_empty")})
    families = {"raw": ("raw_a", "payload_a", "default"),
                "full_default_raw": ("full", "payload_full", "default"),
                "full": ("full", "payload_full", "full")}
    frames = {}

    def add_frame(name, value, format):
        data[name] = value
        frames[name] = {**_write(root / (name + ".zst"), value), "header": library.inspect_header(value, format)}

    for format in ("standard", "magicless"):
        for family, (prefix_name, payload_name, kind) in families.items():
            for mode, streaming, known in (("once", False, True), ("known", True, True), ("unknown", True, False)):
                name = f"{family}-{format}-{mode}"
                wire = library.encode(data[payload_name], data[prefix_name], kind=kind, format=format,
                                      streaming=streaming, known_size=known)
                add_frame(name, wire, format)
                assert frames[name]["header"]["content_size"] == (len(data[payload_name]) if known else None)
                assert library.decode(wire, data[prefix_name], kind=kind, format=format) == data[payload_name]
                dependency = library.validate_prefix_wire(wire, data[prefix_name], data[payload_name], kind=kind, format=format)
                if not dependency["history_dependency"]:
                    raise AssertionError((name, "Frame did not require prefix history", dependency))
                frames[name]["prefix_controls"] = dependency
            plain = library.encode(data[payload_name], format=format)
            add_frame(f"{family}-{format}-plain", plain, format)
            for mode, known in (("known", True), ("unknown", False)):
                add_frame(f"{family}-{format}-plain-{mode}", library.encode(data[payload_name], format=format,
                          streaming=True, known_size=known), format)
        add_frame(f"raw_b-{format}-once", library.encode(data["payload_b"], data["raw_b"], format=format), format)
        add_frame(f"empty-{format}", library.encode(b"", format=format), format)
    recipes = []

    def recipe(name, side, format, actions, *, inference=None, fact_only=False):
        used = [frames[action["arguments"]["input"]] for action in actions if action["arguments"].get("input") in frames]
        prefix_actions = [action for action in actions if action["operation"] == "ref_prefix"]
        kind = "full" if (any(action["arguments"].get("kind") == "full" for action in prefix_actions)
                          or not prefix_actions and name.startswith("full-")) else "raw"
        streaming = any(action["operation"] in ("encode_step", "decode_step", "drive_encode", "drive_decode") for action in actions)
        preflight = (format == "standard" and not fact_only and
                     any(name.endswith(suffix) for suffix in ("encoder-once", "decoder-once", "unknown-stream",
                         "partial-header", "complete-header", "stop-next", "persistent-to-prefix-C", "persistent-to-prefix-D")))
        recipes.append({"name": name, "provider": "libzstd", "side": side, "format": format,
                        "frames": used, "actions": actions, "streaming": streaming, "kind": kind,
                        "preflight": preflight, "vort_supported": not fact_only,
                        "typed_boundary": ("C ABI invalid dictionary bytes; Vort accepts parsed valid NativeDictionary only" if fact_only
                                           else "parsed valid NativeDictionary" if kind == "full" else "borrowed raw prefix bytes"),
                        "semantic_inference": {"scope": "inference from measured follow-up output/error; C opaque state is not a snapshot",
                                               "basis": inference or "See actual staged results and retained 188 observations"},
                        "reference_fact_only": fact_only})

    a = _action
    for format in ("standard", "magicless"):
        for family, (prefix, payload, kind) in families.items():
            frame = f"{family}-{format}-once"
            plain = f"{family}-{format}-plain"
            ref = a("ref_prefix", input=prefix, kind=kind, require_success=True)
            recipe(f"{family}-{format}-encoder-once", "C", format, [ref,
                   a("encode_once", input=payload, expect_output=frame, require_match=True),
                   a("encode_once", input=payload, expect_output=plain, require_match=True)], inference="First encoding uses prefix; second equals a plain frame")
            for mode, known in (("known", True), ("unknown", False)):
                pledge = [a("pledge", size=len(data[payload]))] if known else []
                recipe(f"{family}-{format}-encoder-stream-{mode}", "C", format,
                       [ref, *pledge, a("drive_encode", input=payload, expect_output=f"{family}-{format}-{mode}", require_match=True),
                        *pledge, a("drive_encode", input=payload, expect_output=f"{family}-{format}-plain-{mode}", require_match=True)],
                       inference="Prefix is used by the first actual streaming initialization and is absent from the second completed stream")
            recipe(f"{family}-{format}-decoder-once", "D", format, [ref,
                   a("decode_once", input=frame, expect_output=payload, require_match=True),
                   a("decode_once", input=frame, expect_output=payload, require_error=True)])
            recipe(f"{family}-{format}-unknown-stream", "D", format, [ref,
                   a("drive_decode", input=f"{family}-{format}-unknown", expect_output=payload, require_match=True),
                   a("drive_decode", input=f"{family}-{format}-unknown", require_error=True)])
            recipe(f"{family}-{format}-empty-data-consumes", "D", format, [ref,
                   a("drive_decode", input=f"empty-{format}", expect_output="empty", require_match=True),
                   a("drive_decode", input=frame, require_error=True)], inference="A complete empty data frame consumes the pending prefix")
            if family == "full_default_raw":
                continue
            joined = frame + "-concat"
            add_frame(joined, data[frame] * 2, format)
            twice = payload + "-twice"
            data[twice] = data[payload] * 2
            assets[twice] = _write(root / (twice + ".bin"), data[twice])
            recipe(f"{family}-{format}-oneshot-concat", "D", format, [ref,
                   a("decode_once", input=joined, expect_output=twice, require_match=True),
                   a("decode_once", input=frame, require_error=True)], inference="A single one-shot call shares the once prefix across its concatenated data frames")
            recipe(f"{family}-{format}-stop-next", "D", format, [ref,
                   a("drive_decode", input=joined, chunk_size=len(data[joined]), stop_at_frame=True,
                     expect_output=payload, require_match=True), a("drive_decode", input=frame, require_error=True)],
                   inference="Streaming returns at the first frame boundary and subsequent dependent frame lacks the consumed prefix")
            header_size = frames[frame]["header"]["header_size"]
            for label, size in (("partial", header_size - 1), ("complete", header_size)):
                partial = frame + "-" + label + "-header"
                data[partial] = data[frame][:size]
                assets[partial] = _write(root / (partial + ".bin"), data[partial])
                recipe(f"{family}-{format}-{label}-header", "D", format, [ref,
                       a("decode_step", input=partial), a("ref_prefix", input=prefix, kind=kind, require_error=True),
                       a("reset", directive="parameters", require_error=True), a("reset", directive="session", require_success=True),
                       a("decode_once", input=frame, expect_output=payload, **({"require_match": True} if label == "partial" else {"require_error": True}))],
                       inference="Partial valid header retains pending prefix across session reset; complete header consumes it")
            for label, value in (("empty", b""), ("bad_header", (b"BAD!" + data[frame][4:]) if format == "standard" else b"\xff" + data[frame][1:]),
                                 ("bad_checksum", data[frame][:-1] + bytes([data[frame][-1] ^ 1])), ("truncated", data[frame][:-1])):
                asset_name = frame + "-" + label
                data[asset_name] = value
                assets[asset_name] = _write(root / (asset_name + ".bin"), value)
                for api, operation in (("once", "decode_once"), ("stream", "drive_decode")):
                    preserves = api == "stream" and label in ("empty", "bad_header")
                    recipe(f"{family}-{format}-{api}-{label}-recovery", "D", format, [ref,
                           a(operation, input=asset_name), a("reset", directive="session", require_success=True),
                           a("decode_once", input=frame, expect_output=payload, **({"require_match": True} if preserves else {"require_error": True}))])
            for directive in ("session", "parameters", "all"):
                for side in ("C", "D"):
                    operation = "encode_once" if side == "C" else "decode_once"
                    restore = [a("set_parameter", parameter="ZSTD_c_format" if side == "C" else "ZSTD_d_format", value=library.format_value(format))]
                    if side == "C":
                        restore.append(a("set_parameter", parameter="ZSTD_c_checksumFlag", value=1))
                    expect = frame if directive == "session" else plain
                    follow = a(operation, input=payload if side == "C" else frame,
                               expect_output=expect if side == "C" else payload,
                               **({"require_match": True} if side == "C" or directive == "session" else {"require_error": True}))
                    recipe(f"{family}-{format}-{side}-reset-{directive}", side, format, [ref, a("reset", directive=directive), *restore, follow])
            recipe(f"{family}-{format}-encoder-active", "C", format, [ref, a("encode_step", input="empty"),
                   a("ref_prefix", input=prefix, kind=kind, require_error=True), a("reset", directive="parameters", require_error=True),
                   a("reset", directive="session"), a("encode_once", input=payload, expect_output=plain, require_match=True)])
            recipe(f"{family}-{format}-encoder-small-destination", "C", format, [ref,
                   a("encode_once", input=payload, capacity=1, require_error=True), a("reset", directive="session"),
                   a("encode_once", input=payload, expect_output=plain, require_match=True)])
            recipe(f"{family}-{format}-encoder-bad-pledge", "C", format, [ref, a("pledge", size=len(data[payload]) + 1),
                   a("encode_step", input=payload), a("encode_step", input="empty", directive="end", require_error=True),
                   a("reset", directive="session"), a("encode_once", input=payload, expect_output=plain, require_match=True)])
            recipe(f"{family}-{format}-encoder-invalid-directive", "C", format, [ref,
                   a("encode_step", input=payload, directive=99, require_error=True), a("reset", directive="session"),
                   a("encode_once", input=payload, expect_output=frame, require_match=True)])
            recipe(f"{family}-{format}-checksum-ignore", "D", format, [ref,
                   a("set_parameter", parameter="ZSTD_d_forceIgnoreChecksum", value=1),
                   a("drive_decode", input=frame + "-bad_checksum", expect_output=payload, require_match=True),
                   a("reset", directive="all"), a("set_parameter", parameter="ZSTD_d_format", value=library.format_value(format)), ref,
                   a("drive_decode", input=frame + "-bad_checksum", require_error=True)])
            recipe(f"{family}-{format}-persistent-after-fatal", "D", format,
                   [a("load_dictionary", input=prefix), a("drive_decode", input=frame + "-bad_checksum", require_error=True),
                    a("reset", directive="session"), a("decode_once", input=frame, expect_output=payload, require_match=True)],
                   inference="Persistent dictionaries survive fatal checksum failure and session-only reset")
            for skip in ("skip", "skip_empty"):
                joined = frame + "-" + skip
                add_frame(joined, data[skip] + data[frame], format)
                for operation in ("decode_once", "drive_decode"):
                    require = {"require_match": True} if format == "standard" and operation == "decode_once" else {}
                    if format == "standard" and operation == "drive_decode":
                        require = {"require_error": True}
                    recipe(f"{family}-{format}-{operation}-{skip}", "D", format,
                           [ref, a(operation, input=joined, expect_output=payload, **require)],
                           inference="Standard one-shot shares prefix past skippable; standard streaming consumes at skippable header; standard skip bytes in magicless mode are parsed as magicless data")
        fa, fb = f"raw-{format}-once", f"raw_b-{format}-once"
        recipe(f"raw-{format}-persistent-to-prefix-D", "D", format,
               [a("load_dictionary", input="raw_a"), a("ref_prefix", input="raw_b"),
                a("decode_once", input=fb, expect_output="payload_b", require_match=True), a("decode_once", input=fa, require_error=True)],
               inference="After B prefix consumption, replaced persistent A does not return")
        recipe(f"raw-{format}-persistent-to-prefix-C", "C", format,
               [a("load_dictionary", input="raw_a"), a("ref_prefix", input="raw_b"),
                a("encode_once", input="payload_b", expect_output=fb, require_match=True),
                a("encode_once", input="payload_a", expect_output=f"raw-{format}-plain", require_match=True)])
        recipe(f"raw-{format}-prefix-to-persistent", "D", format,
               [a("ref_prefix", input="raw_b"), a("load_dictionary", input="raw_a"),
                a("decode_once", input=fa, expect_output="payload_a", require_match=True),
                a("decode_once", input=fa, expect_output="payload_a", require_match=True)])
        for side in ("C", "D"):
            recipe(f"raw-{format}-{side}-clear-prefix", side, format,
                   [a("load_dictionary", input="raw_a"), a("ref_prefix", input="raw_b"),
                    a("ref_prefix", input="empty", null=True, size=0, require_success=True),
                    a("encode_once" if side == "C" else "decode_once", input="payload_a" if side == "C" else fa,
                      **({"expect_output": f"raw-{format}-plain", "require_match": True} if side == "C" else {"require_error": True}))],
                   inference="A NULL/zero prefix explicitly clears both previous dictionary and previous prefix")
        recipe(f"full-{format}-persistent-to-default-raw", "D", format,
               [a("load_dictionary", input="full"), a("ref_prefix", input="full"),
                a("decode_once", input=f"full_default_raw-{format}-once", expect_output="payload_full", require_match=True),
                a("decode_once", input=f"full-{format}-once", require_error=True)])
        for operation in ("decode_once", "drive_decode"):
            recovery = [a("reset", directive="session")] if operation == "drive_decode" else []
            recipe(f"full-{format}-{operation}-dictionary-recovery", "D", format,
                   [a("ref_prefix", input="raw_a"), a(operation, input=f"full-{format}-once", require_error=True),
                    *recovery, a("ref_prefix", input="full", kind="full", require_success=True),
                    a(operation, input=f"full-{format}-once", expect_output="payload_full", require_match=True)],
                   inference="Missing/wrong dictionary recovery is measured explicitly; streaming recovery resets the failed session before rearming")
    for side in ("C", "D"):
        recipe("invalid-full-" + side, side, "standard",
               [a("load_dictionary", input="raw_a"), a("ref_prefix", input="invalid_full", kind="full"),
                a("encode_once" if side == "C" else "decode_once", input="payload_a" if side == "C" else "raw-standard-once", require_error=True)],
               inference="C validates full prefix at encode initialization; D ref fails immediately and old persistent dictionary is lost; Vort typed valid NativeDictionary setters have a narrower input boundary", fact_only=True)
    cases = [_execute(root, library, value, data, assets, frames) for value in recipes]
    receipt = {"schema": "vort.zstd.prefix_lifecycle.fixtures.v1", "reference": library.provenance(),
               "fixtures_source": reference.artifact(Path(__file__)), "assets": assets, "frames": frames,
               "archived": {"dictionary_hex": reference.artifact(dictionary_source), "frame_hex": reference.artifact(frame_source)},
               "audit": audit, "cases": cases, "counters": {"audit_observations": audit["observations"],
               "recipes": len(cases), "stages": sum(len(case["stages"]) for case in cases),
               "frame_artifacts": len(frames),
               "data_frames": sum(value["header"].get("frame_type") == "data" for value in frames.values()),
               "skippable_headers": sum(value["header"].get("frame_type") == "skippable" for value in frames.values()),
               "reference_fact_only": sum(case["reference_fact_only"] for case in cases)},
               "snapshot_note": "Only actual getParameter results and API counters; semantic prefix phases are explicitly inference",
               "receipt_path": str(root / "receipt.json")}
    (root / "receipt.json").write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--library", type=Path)
    parser.add_argument("--header", type=Path)
    args = parser.parse_args()
    receipt = generate(args.output, Library(args.library, header=args.header))
    print(json.dumps({"receipt_path": receipt["receipt_path"], "reference": receipt["reference"], "counters": receipt["counters"]}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
