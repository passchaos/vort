"""Future package-only replay of the producer's three pure statistics functions."""
import ast
import contextlib
import io
import json
import math
import random
import statistics


def replay(campaign_source, manifest, raw_jsonl, preflight, expected):
    # Only these pure bodies are retained. No producer imports, sample/build,
    # filesystem or subprocess functions are evaluated.
    tree = ast.parse(campaign_source)
    functions = [node for node in tree.body if isinstance(node, ast.FunctionDef) and node.name in ("percentile", "paired_ci", "analyze")]
    if {node.name for node in functions} != {"percentile", "paired_ci", "analyze"}:
        raise ValueError("Producer statistics interface changed; finalize the schema before replay")
    class Path:
        def __init__(self, name=""):
            self.name = name
        def __truediv__(self, name):
            return Path(str(name))
        def read_text(self):
            if self.name == "samples/raw.jsonl":
                return raw_jsonl.decode()
            if self.name == "preflight.json":
                return json.dumps(preflight)
            raise ValueError("Statistics attempted an unarchived read")
    result = {}
    namespace = {"__name__": "packaged_statistics", "math": math, "random": random, "statistics": statistics,
                 "json": json, "BASE": Path(), "load_manifest": lambda: manifest, "now": lambda: expected["utc"],
                 "write_json": lambda path, value: result.update(value)}
    code = ast.Module(body=functions, type_ignores=[])
    exec(compile(code, "packaged_campaign_statistics", "exec"), namespace)
    with contextlib.redirect_stdout(io.StringIO()):
        actual = namespace["analyze"]()
    if actual != expected:
        raise ValueError("All packaged row/gate/CI results differ from the producer")
    return actual
