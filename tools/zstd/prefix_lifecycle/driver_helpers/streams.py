"""Typed streaming adapters for measured prefix lifecycle consequences."""
from __future__ import annotations
from pathlib import Path
from .matrix import INCREMENTAL, REUSABLE, missing_error, prepare_resume_files


def incremental_cases(b, format="standard", *, known_size=True):
    for kind in ("raw", "full"):
        family = b.family(kind)
        for api in INCREMENTAL:
            suffix = "known" if known_size else "unknown"
            case = b.new(f"prefix-{api}-{kind}-{suffix}", api, family, format=format, known_size=known_size)
            b.prefix(case)
            if api == "incremental_decode":
                frame = b.frame(family, format, "once" if known_size else "unknown")
                b.decode(case, frame=frame)
                b.reset(case)
                b.decode(case, frame=frame, error=missing_error(kind))
            else:
                b.encode(case)
                b.reset(case)
                b.encode(case, mode="plain")
            b.add(case, [f"{kind}-{format}-unknown-stream", f"{kind}-{format}-encoder-stream-{suffix}"],
                  ["C returns to a frame boundary automatically; a completed Vort incremental handle requires explicit reset_session"])


def replacement_cases(b, format="standard"):
    # RAW A->B covers reusable handles; FULL persistent->same once FULL covers
    # incremental handles. The final no-prefix decode/failure proves restoration
    # did not occur, rather than inferring it solely from snapshots.
    for api in (*REUSABLE, *INCREMENTAL):
        kind = "raw" if api in REUSABLE else "full"
        old = b.family(kind)
        new = dict(old)
        if kind == "raw":
            new.update(name="raw_b", prefix=b.path("raw_b"), payload=b.path("payload_b"))
        case = b.new(f"replace-persistent-{api}-{kind}", api, new, format=format)
        b.persistent(case, old)
        b.prefix(case, new)
        if api.endswith("decode"):
            b.decode(case, frame=b.frame(new, format), family=new)
            if api == "incremental_decode":
                b.reset(case)
            b.decode(case, frame=b.frame(old, format), family=old, error=missing_error(kind))
        else:
            b.encode(case, family=new)
            if api in INCREMENTAL:
                b.reset(case)
            b.encode(case, family=old, mode="plain")
        b.add(case, [f"raw-{format}-persistent-to-prefix-D" if api.endswith("decode") else f"raw-{format}-persistent-to-prefix-C"],
              ["RAW uses distinct A/B history; FULL uses the same immutable full dictionary for the previous persistent and once selection",
               "A completed incremental frame is reset explicitly; an old persistent dictionary must not reappear"])


def reset_cases(b, format="standard"):
    for kind in ("raw", "full"):
        family = b.family(kind)
        for reset, c_name in (("reset_session", "session"), ("reset_parameters", "parameters"), ("reset_all", "all")):
            case = b.new(f"pending-{reset}-incremental_decode-{kind}", "incremental_decode", family, format=format)
            b.prefix(case)
            b.reset(case, reset, "pending" if reset == "reset_session" else "none")
            b.decode(case, error=None if reset == "reset_session" else missing_error(kind))
            b.add(case, [f"{kind}-{format}-D-reset-{c_name}"],
                  ["C parameter resets restore format/checksum defaults; Vort typed resetParameters clears bindings and keeps its Zig policy, so C parameter-number restoration stages are omitted"])


def header_cases(b, format="standard"):
    for kind in ("raw", "full"):
        family = b.family(kind)
        frame = b.frame(family, format)
        header_size = b.receipt["frames"][f"{kind}-{format}-once"]["header"]["header_size"]
        for complete in (False, True):
            label = "complete" if complete else "partial"
            phase = "active" if complete else "pending"
            case = b.new(f"{label}-header-incremental_decode-{kind}", "incremental_decode", family, format=format)
            b.prefix(case)
            b.stage(case, "step", input_path=frame, input_limit=header_size if complete else header_size - 1,
                    output_limit=113, phase=phase, zero_output=True)
            b.stage(case, "set_prefix", dictionary_path=family["prefix"], full_dictionary=kind == "full",
                    error="InvalidStreamState", phase=phase, zero_output=True)
            b.reset(case, "reset_parameters", phase, error="InvalidStreamState")
            b.reset(case, "reset_session", "none" if complete else "pending")
            b.decode(case, error=missing_error(kind) if complete else None)
            b.add(case, [f"{kind}-{format}-{label}-header"],
                  ["C final decode_once is adapted to a complete incremental decode after explicit session reset; public prefix state and output/error are compared, not opaque C progress bit patterns"])


def skip_cases(b):
    for kind in ("raw", "full"):
        family = b.family(kind)
        joined = b.path(f"{kind}-standard-once-skip")
        for api in ("native_decode", "incremental_decode"):
            case = b.new(f"skippable-prefix-scope-{api}-{kind}", api, family)
            b.prefix(case)
            b.decode(case, frame=joined, error=missing_error(kind) if api == "incremental_decode" else None)
            b.add(case, [f"{kind}-standard-{'drive_decode' if api == 'incremental_decode' else 'decode_once'}-skip"],
                  ["Only standard skippable semantics are compared; standard skip bytes in magicless mode are a retained C parsing fact, not successful metadata skipping"])


def stop_cases(b, format="standard"):
    for kind in ("raw", "full"):
        family = b.family(kind)
        frame = b.frame(family, format)
        joined = b.path(f"{kind}-{format}-once-concat")
        case = b.new(f"stop-next-incremental_decode-{kind}", "incremental_decode", family, format=format,
                     stop_after_first_frame=True, input_chunk=1)
        b.prefix(case)
        b.decode(case, frame=joined)
        case["expectations"][-1]["input_read"] = Path(frame).stat().st_size
        b.stage(case, "next_stream", phase="none", zero_output=True)
        b.decode(case, frame=frame, error=missing_error(kind))
        b.add(case, [f"{kind}-{format}-stop-next"],
              ["input_chunk=1 guarantees no suffix was offered past the first done boundary; its actual input_read is checked before next_stream and only the unaccepted second member is resupplied"])


def directive_cases(b, format="standard"):
    for kind in ("raw", "full"):
        family = b.family(kind)
        case = b.new(f"invalid-directive-incremental_encode-{kind}", "incremental_encode", family, format=format)
        b.prefix(case)
        b.stage(case, "step", input_path=family["payload"], output_limit=113, directive=99,
                error="InvalidStreamState", phase="pending", input_read=0, zero_output=True)
        b.encode(case)
        b.add(case, [f"{kind}-{format}-encoder-invalid-directive"],
              ["Invalid serial directive is rejected before activation; Vort's typed InvalidStreamState is not a mirrored C integer error code",
               "Parallel encoder has no stepWithDirective entry and is excluded from this case"])


def initializer_case(b, api, kind, format, known_size):
    family = b.family(kind)
    suffix = "known" if known_size else "unknown"
    case = b.new(f"initializer-prefix-{api}-{kind}-{suffix}", api, family, format=format, known_size=known_size,
                 initialization="prefix", initial_dictionary_path=family["prefix"], initial_full_dictionary=kind == "full")
    b.stage(case, "observe", phase="pending", zero_output=True)
    if api.endswith("decode"):
        b.decode(case, frame=b.frame(family, format, "once" if known_size else "unknown"))
        b.reset(case)
        b.decode(case, error=missing_error(kind))
    else:
        b.encode(case)
        b.reset(case)
        b.encode(case, mode="plain")
    b.add(case, [f"{kind}-{format}-encoder-once", f"{kind}-{format}-decoder-once"],
          ["RAW serial constructors exercise initWithPrefix/initExactSizeWithPrefix; RAW decoder uses initWithPrefixAndOptions",
           "FULL/pipeline constructors use validated preset metadata and explicit prefix usage; initializer snapshot is the public handle's actual state"])


def initializers(b, format="standard", *, full=False):
    if not full:
        initializer_case(b, "incremental_encode", "raw", format, True)
        initializer_case(b, "incremental_encode", "raw", format, False)
        initializer_case(b, "incremental_decode", "raw", format, True)
        initializer_case(b, "incremental_parallel_encode", "raw", format, True)
    else:
        for api in (*INCREMENTAL, "native_decode"):
            initializer_case(b, api, "full", format, True)
        initializer_case(b, "incremental_encode", "full", format, False)


def recovery_cases(b, format):
    family = b.family("full")
    parts = prepare_resume_files(b, family, format)
    case = b.new("provide-full-dictionary-incremental_decode", "incremental_decode", family, format=format)
    b.stage(case, "step", input_path=parts["header"], output_limit=0, error="NeedDictionary",
            phase="none", input_read=parts["header_size"], zero_output=True)
    b.stage(case, "provide_dictionary", dictionary_path=family["prefix"], full_dictionary=True, phase="none", zero_output=True)
    b.decode(case, frame=parts["suffix"])
    b.add(case, [f"full-{format}-drive_decode-dictionary-recovery"],
          ["C dictionary recovery resets before rearming; Vort's distinct typed provideDictionary API resumes its actual accepted header request",
           "Header and suffix are prepared as separate physical inputs; the error-stage accepted count must equal the header before resuming"])
