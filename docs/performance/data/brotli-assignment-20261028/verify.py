import hashlib
import json
import lzma
import math
import statistics
from pathlib import Path


ROOT = Path(__file__).resolve().parent


def load(name):
    return json.loads(lzma.decompress((ROOT / name).read_bytes()))


def geometric(values):
    return math.exp(statistics.mean(math.log(value) for value in values))


shapes = {}
reports = {}
for prefix in ("exploratory", "matched"):
    records = load(f"{prefix}-raw.json.xz")
    assert len(records) in (6, 18)
    expected_samples = len(records) // 6 * 5
    values, reference = {}, {}
    for record in records:
        report = record["result"]
        assert report["reference_version"] == 0x1002000
        assert report["round_count"] == 5 and len(report["rows"]) == 12
        for row in report["rows"]:
            key = (row["case"], row["input_bytes"])
            settings = row["settings"]
            assert settings["parameters_match"]
            assert settings["vort_wire_window_bits"] == settings["reference_wire_window_bits"] == 16
            shape = (row["input_sha256"], row["wires"], settings)
            assert shapes.setdefault(key, shape) == shape
            samples = [item["vort_ns"] / row["iterations"] for item in row["rounds"]]
            assert len(samples) == 5 and row["iterations"] == 3
            values.setdefault((key, record["label"]), []).extend(samples)
            if record["label"] == "candidate":
                reference.setdefault(key, []).extend(
                    item["reference_ns"] / row["iterations"] for item in row["rounds"]
                )
    ratios, reference_ratios, sizes, by_size = [], [], [], {}
    for key in sorted(shapes):
        assert len(values[key, "baseline"]) == len(values[key, "candidate"]) == expected_samples
        old = statistics.median(values[key, "baseline"])
        new = statistics.median(values[key, "candidate"])
        ratio = new / old
        ratios.append(ratio)
        by_size.setdefault(key[1], []).append(ratio)
        reference_ratios.append(new / statistics.median(reference[key]))
        wires = shapes[key][1]
        sizes.append(wires["vort_bytes"] / wires["reference_bytes"])
    summary = json.loads((ROOT / f"{prefix}-summary.json").read_text())
    assert summary["cases"] == len(summary["rows"]) == len(shapes) == 36
    for key, value in (("geometric_ratio", geometric(ratios)),
                       ("reference_time_ratio", geometric(reference_ratios)),
                       ("size_ratio", geometric(sizes))):
        assert math.isclose(summary[key], value, rel_tol=1e-13)
    reports[prefix] = {key: summary[key] for key in
                       ("cases", "geometric_ratio", "reference_time_ratio", "size_ratio")}
    reports[prefix]["by_size"] = {size: geometric(items) for size, items in by_size.items()}


def without_clocks(value):
    if isinstance(value, dict):
        return {key: without_clocks(item) for key, item in value.items()
                if not key.endswith("_ns") and key != "provenance"}
    if isinstance(value, list):
        return [without_clocks(item) for item in value]
    return value


assert without_clocks(load("baseline-stage.json.xz")) == without_clocks(load("candidate-stage.json.xz"))
for line in (ROOT / "SHA256SUMS").read_text().splitlines():
    digest, name = line.split("  ", 1)
    assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
print(json.dumps({"epochs": reports, "cross_epoch_input_wire_settings_equal": True,
                  "diagnostic_non_time_fields_equal": True, "archive_sha256_verified": True}, indent=2))
