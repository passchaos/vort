"""Curated handle and standalone-call scripts linked to measured C recipes."""
from __future__ import annotations
from pathlib import Path
from .common import materialize

ENTRIES = ("alloc", "scratch", "append", "into")
STATELESS_ENTRIES = ("alloc", "append", "into")
REUSABLE = ("native_encode", "level_encode", "native_decode")
STATELESS = ("one_shot_encode", "one_shot_level_encode", "one_shot_decode")
INCREMENTAL = ("incremental_encode", "incremental_parallel_encode", "incremental_decode")


class Builder:
    def __init__(self, receipt, root, library=None):
        self.receipt, self.root, self.library = receipt, root, library
        self.cases = []
        self.recipes = {case["name"] for case in receipt["cases"]}

    def path(self, name):
        table = self.receipt["assets"] if name in self.receipt["assets"] else self.receipt["frames"]
        return table[name]["path"]

    def family(self, kind):
        if kind == "raw":
            return {"name": "raw", "kind": "raw", "prefix": self.path("raw_a"), "payload": self.path("payload_a")}
        if kind == "raw_dictionary_bytes":
            return {"name": "full_default_raw", "kind": "raw", "prefix": self.path("full"), "payload": self.path("payload_full")}
        return {"name": "full", "kind": "full", "prefix": self.path("full"), "payload": self.path("payload_full")}

    def frame(self, family, format, mode="once"):
        return self.path(f"{family['name']}-{format}-{mode}")

    def payload_size(self, family):
        return Path(family["payload"]).stat().st_size

    def new(self, name, api, family, *, format="standard", entry="alloc", known_size=True, usage="persistent", **options):
        config = {"api": api, "entry": entry, "format": format, "usage": usage,
                  "known_size": known_size, "checksum": True, "ignore_checksum": False,
                  "include_dictionary_id": True, "expected_input_len": self.payload_size(family),
                  "input_chunk": 1 if api == "incremental_decode" else 31, "output_chunk": 113,
                  "stages": [], **options}
        return {"name": name + "-" + format, "kind": family["kind"], "config": config,
                "expectations": [], "reference_recipe_names": [], "adapters": [], "family": family}

    def stage(self, case, operation, *, error=None, phase=None, **values):
        expectation_keys = ("encoded", "decoded_payload_path", "input_read", "zero_output", "stateless")
        expectation = {"error": error}
        if phase is not None:
            expectation["phase"] = phase
        for name in expectation_keys:
            if name in values:
                expectation[name] = values.pop(name)
        stage = {"operation": operation, **values}
        case["config"]["stages"].append(stage)
        case["expectations"].append(expectation)
        return case

    def prefix(self, case, family=None):
        family = case["family"] if family is None else family
        return self.stage(case, "set_prefix", dictionary_path=family["prefix"], full_dictionary=family["kind"] == "full",
                          phase="pending", zero_output=True)

    def persistent(self, case, family=None):
        family = case["family"] if family is None else family
        return self.stage(case, "set_dictionary", dictionary_path=family["prefix"], full_dictionary=family["kind"] == "full",
                          phase="none", zero_output=True)

    def encode(self, case, *, mode="prefix", family=None, stateless=False):
        family = case["family"] if family is None else family
        metadata = {"mode": mode, "payload_path": family["payload"], "prefix_path": family["prefix"], "kind": family["kind"]}
        values = {"input_path": family["payload"], "encoded": metadata, "output_limit": 65536}
        if stateless:
            values.update(dictionary_path=family["prefix"], full_dictionary=family["kind"] == "full", stateless=True)
        return self.stage(case, "encode", phase=None if stateless else "none", **values)

    def decode(self, case, *, frame=None, family=None, error=None, stateless=False):
        family = case["family"] if family is None else family
        frame = self.frame(family, case["config"]["format"]) if frame is None else frame
        values = {"input_path": frame, "output_limit": 65536}
        if error is None:
            values["decoded_payload_path"] = family["payload"]
        if stateless:
            values.update(dictionary_path=family["prefix"], full_dictionary=family["kind"] == "full", stateless=True)
        return self.stage(case, "decode", error=error, phase=None if stateless else "none", **values)

    def reset(self, case, operation="reset_session", phase="none", error=None):
        return self.stage(case, operation, phase=phase, error=error, zero_output=True)

    def add(self, case, recipes=(), adapters=()):
        case["reference_recipe_names"] = [name for name in recipes if name in self.recipes]
        case["adapters"].extend(adapters)
        self.cases.append(case)


def missing_error(kind):
    return "NeedDictionary" if kind == "full" else "InvalidMatch"


def handle_cases(builder, format):
    b = builder
    for kind in ("raw", "full"):
        f = b.family(kind)
        for api in REUSABLE:
            for entry in ENTRIES:
                case = b.new(f"prefix-{api}-{entry}-{kind}", api, f, format=format, entry=entry)
                b.prefix(case)
                if api == "native_decode":
                    b.decode(case)
                    b.decode(case, error=missing_error(kind))
                    recipe = f"{kind}-{format}-decoder-once"
                else:
                    b.encode(case)
                    b.encode(case, mode="plain")
                    recipe = f"{kind}-{format}-encoder-once"
                b.add(case, [recipe], ["C frame bytes are an oracle artifact; generated Vort bytes are independently decoded"])
        for api in STATELESS:
            for entry in STATELESS_ENTRIES:
                case = b.new(f"explicit-prefix-{api}-{entry}-{kind}", api, f, format=format, entry=entry, usage="prefix")
                for _ in range(2):
                    if api == "one_shot_decode":
                        b.decode(case, stateless=True)
                    else:
                        b.encode(case, stateless=True)
                b.add(case, [f"{kind}-{format}-decoder-once" if api == "one_shot_decode" else f"{kind}-{format}-encoder-once"],
                      ["Each standalone call explicitly supplies its borrowed dictionary and prefix usage; no once-context is invented"])


def persistent_cases(builder, format):
    b = builder
    for kind in ("raw", "full"):
        f = b.family(kind)
        for reusable, standalone, label in (("native_encode", "one_shot_encode", "native"),
                                             ("level_encode", "one_shot_level_encode", "level")):
            for api in (reusable, standalone):
                stateless = api == standalone
                case = b.new(f"persistent-{api}-{kind}", api, f, format=format)
                case["equivalence_group"] = f"persistent-{label}-{kind}-{format}"
                if not stateless:
                    b.persistent(case)
                b.encode(case, mode="persistent", stateless=stateless)
                b.encode(case, mode="persistent", stateless=stateless)
                b.add(case, [f"raw-{format}-prefix-to-persistent"], ["Default persistent bytes must match reusable and explicit standalone public entrypoints"])
        case = b.new(f"persistent-native_decode-{kind}", "native_decode", f, format=format)
        b.persistent(case)
        b.decode(case)
        b.decode(case)
        b.add(case, [f"raw-{format}-prefix-to-persistent"], ["Persistent dictionary supports repeated public decode calls"])


def prepare_resume_files(builder, family, format):
    key = f"{family['name']}-{format}-once"
    frame = builder.receipt["frames"][key]
    wire = Path(frame["path"]).read_bytes()
    header_size = frame["header"]["header_size"]
    return {"header_size": header_size,
            "header": materialize(builder.root, f"{key}-header.bin", wire[:header_size]),
            "suffix": materialize(builder.root, f"{key}-suffix.bin", wire[header_size:])}


def build_matrix(receipt, root, *, preflight, library):
    from . import streams, extra_cases
    b = Builder(receipt, root, library)
    for format in (("standard",) if preflight else ("standard", "magicless")):
        handle_cases(b, format)
        persistent_cases(b, format)
        streams.incremental_cases(b, format)
        streams.replacement_cases(b, format)
        streams.reset_cases(b, format)
        streams.header_cases(b, format)
        streams.stop_cases(b, format)
        streams.directive_cases(b, format)
        streams.initializers(b, format)
        extra_cases.flag_replacement_cases(b, format)
        if format == "standard":
            streams.skip_cases(b)
            if preflight:
                extra_cases.dictionary_looking_raw_cases(b, format, encoder_only=True)
        if not preflight:
            streams.incremental_cases(b, format, known_size=False)
            streams.initializers(b, format, full=True)
            streams.recovery_cases(b, format)
            extra_cases.policy_cases(b, format)
            extra_cases.clear_cases(b, format)
            extra_cases.output_failure_cases(b, format)
            extra_cases.dictionary_looking_raw_cases(b, format)
    names = [case["name"] for case in b.cases]
    if len(names) != len(set(names)):
        raise AssertionError("Duplicate lifecycle case name")
    if preflight and len(b.cases) != 93:
        raise AssertionError(("Preflight case count", len(b.cases)))
    return b.cases
