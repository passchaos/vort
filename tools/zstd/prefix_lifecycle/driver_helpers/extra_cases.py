"""Further bounded scripts for the full lifecycle gate, never run implicitly."""
from pathlib import Path
from .common import artifact, materialize
from .matrix import missing_error


def policy_cases(b, format):
    for kind in ("raw", "full"):
        family = b.family(kind)
        bad = b.path(f"{kind}-{format}-once-bad_checksum")
        for api in ("native_decode", "incremental_decode"):
            for ignore in (False, True):
                case = b.new(f"checksum-policy-{api}-{kind}-ignore{int(ignore)}", api, family, format=format, ignore_checksum=ignore)
                b.prefix(case)
                b.decode(case, frame=bad, error=None if ignore else "ChecksumMismatch")
                if not ignore:
                    b.reset(case)
                    b.prefix(case)
                    b.decode(case)
                b.add(case, [f"{kind}-{format}-checksum-ignore"],
                      ["Strict and ignore checksum are separate immutable Zig policies; the C setParameter transition is not mirrored"])


def clear_cases(b, format):
    for kind in ("raw", "full"):
        family = b.family(kind)
        for api in ("native_encode", "native_decode", "incremental_encode", "incremental_parallel_encode", "incremental_decode"):
            case = b.new(f"clear-pending-{api}-{kind}", api, family, format=format)
            b.prefix(case)
            b.stage(case, "clear_dictionary", phase="none", zero_output=True)
            if api.endswith("decode"):
                b.decode(case, error=missing_error(kind))
            else:
                b.encode(case, mode="plain")
            b.add(case, [f"raw-{format}-{'D' if api.endswith('decode') else 'C'}-clear-prefix"],
                  ["C NULL/zero clearing is adapted to the public typed clearDictionary operation"])


def output_failure_cases(b, format):
    for kind in ("raw", "full"):
        family = b.family(kind)
        for api in ("native_encode", "level_encode"):
            case = b.new(f"small-destination-{api}-{kind}", api, family, format=format, entry="into")
            b.prefix(case)
            b.stage(case, "encode", input_path=family["payload"], output_limit=1,
                    error="OutputTooSmall", phase="none", zero_output=True)
            b.encode(case, mode="plain")
            b.add(case, [f"{kind}-{format}-encoder-small-destination"],
                  ["Destination failure occurs after the reusable prefix call begins; subsequent output must decode without any old dictionary"])


def dictionary_looking_raw_cases(b, format, *, encoder_only=False):
    original = b.family("raw_dictionary_bytes")
    apis = ("native_encode",) if encoder_only else ("native_encode", "native_decode", "incremental_decode")
    for api in apis:
        family = dict(original)
        prepared = None
        if api == "native_encode":
            # The archived payload demonstrates decoder compatibility but need
            # not make the native encoder borrow RAW history. Repeat the whole
            # dictionary-looking byte string, including its entropy/header
            # bytes, to exercise its default RAW interpretation directly.
            prefix = Path(family["prefix"]).read_bytes()
            payload = prefix * 2
            family["payload"] = materialize(b.root, "dictionary-looking-raw-prefix-repeat.payload", payload)
            wire = b.library.encode(payload, prefix, kind="default", format=format)
            frame = materialize(b.root, f"dictionary-looking-raw-prefix-repeat-{format}.zst", wire)
            proof = b.library.validate_prefix_wire(wire, prefix, payload, kind="default", format=format)
            if not proof["history_dependency"] or proof["entropy_dependency"]:
                raise AssertionError("Dictionary-looking RAW repetition corpus did not require its actual history")
            prepared = {"dictionary": artifact(family["prefix"]), "payload": artifact(family["payload"]),
                        "frame": artifact(frame), "history_controls": proof,
                        "recipe": "All 256 dictionary-looking bytes used as RAW prefix; payload repeats those exact bytes twice"}
        case = b.new(f"dictionary-looking-default-raw-{api}", api, family, format=format)
        b.prefix(case)
        if api.endswith("decode"):
            b.decode(case)
            if api == "incremental_decode":
                b.reset(case)
            b.decode(case, error="InvalidMatch")
        else:
            b.encode(case)
            b.encode(case, mode="plain")
            case["prepared_reference"] = prepared
        b.add(case, [f"full_default_raw-{format}-decoder-once", f"full_default_raw-{format}-encoder-once"],
              ["Full-dictionary-looking bytes passed to setPrefix remain RAW, with ID zero and no entropy-table interpretation",
               "Only the generated encoder input uses the new RAW repetition corpus; existing C frames and decoder archive payload remain unchanged"])


def flag_replacement_cases(b, format):
    for kind in ("raw", "full"):
        old = b.family(kind)
        if kind == "raw":
            new = dict(old, name="raw_b", prefix=b.path("raw_b"), payload=b.path("payload_b"))
            frame = b.frame(new, format)
            proof = b.library.validate_prefix_wire(Path(frame).read_bytes(), Path(new["prefix"]).read_bytes(),
                                                  Path(new["payload"]).read_bytes(), format=format)
        else:
            original = Path(old["prefix"]).read_bytes()
            header_size = b.library.dictionary_header_size(original)
            dictionary = bytearray(original)
            identifier = b.library.dictionary_id(original) + 1
            dictionary[4:8] = identifier.to_bytes(4, "little")
            dictionary[header_size:] = bytes(value ^ 0x5a for value in original[header_size:])
            dictionary = bytes(dictionary)
            payload = dictionary[header_size:] * 2
            prefix_path = materialize(b.root, "flag-full-B.zdict", dictionary)
            payload_path = materialize(b.root, "flag-full-B.payload", payload)
            new = {"name": "flag_full_b", "kind": "full", "prefix": prefix_path, "payload": payload_path}
            wire = b.library.encode(payload, dictionary, kind="full", format=format)
            frame = materialize(b.root, f"flag-full-B-{format}.zst", wire)
            proof = b.library.validate_prefix_wire(wire, dictionary, payload, kind="full", format=format)
            if not proof["history_dependency"]:
                raise AssertionError("Independent FULL B fixture did not require its history")
        for api in ("native_encode", "native_decode", "level_encode"):
            case = b.new(f"flags-prefix-replaces-persistent-{api}-{kind}", api, new, format=format, usage="prefix")
            b.persistent(case, old)
            if api == "level_encode":
                b.persistent(case, new)
            if api == "native_decode":
                b.decode(case, frame=frame, family=new)
            else:
                b.encode(case, family=new)
            if api != "level_encode":
                case["config"]["stages"][-1].update(dictionary_path=new["prefix"], full_dictionary=kind == "full")
            if api == "native_decode":
                b.decode(case, family=old, frame=b.frame(old, format), error=missing_error(kind))
            else:
                b.encode(case, family=old, mode="plain")
            # The first call uses the explicit prefix flag. The follow-up asks
            # for ordinary stored-dictionary selection so a null prefix option
            # cannot itself erase a wrongly retained old persistent binding.
            case["config"]["stages"][-1]["dictionary_usage"] = "persistent"
            case["prepared_reference"] = {"dictionary": artifact(new["prefix"]), "payload": artifact(new["payload"]),
                                           "frame": artifact(frame), "history_controls": proof,
                                           "recipe": "RAW B is independent raw_b; FULL B preserves entropy/repcodes, changes ID and history"}
            b.add(case, [f"raw-{format}-persistent-to-prefix-D" if api == "native_decode" else f"raw-{format}-persistent-to-prefix-C"],
                  ["First explicit Options.dictionary_usage=prefix call replaces prior persistent selection; no setPrefix substitutes for the flags entry",
                   "Second call uses persistent/default selection so missing old A cannot be masked by another null prefix override",
                   "Level handle has no WithDictionary method: store B persistently then consume it using the per-call prefix flag"])
