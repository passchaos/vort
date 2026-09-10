#!/usr/bin/env python3
"""Generate deterministic upstream Zstd corpora and decode them with Vort."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path


SUMMARY_PREFIX = "zstd_compat_probe "
COMPLETE_MODE_MASK = (1 << 64) - 1
BLOCK_STREAM_COMPRESSED_LIMIT = 128 * 1024 + 32


@dataclass(frozen=True)
class Campaign:
    name: str
    seed: int
    count: int
    dictionary_size: int | None = None
    generator_args: tuple[str, ...] = ()
    require_block_stream: bool = True
    expected_mode_mask: int | None = None
    min_max_block_count: int = 0


CAMPAIGNS = (
    Campaign("plain-17", 17, 200),
    Campaign("plain-919", 919, 1_000),
    Campaign("dict-2027-64k", 2_027, 200, 64 * 1024),
    Campaign("dict-4242-1m", 4_242, 1_000, 1024 * 1024),
    Campaign("dict-31337-64k", 31_337, 1_000, 64 * 1024),
    Campaign("dict-65521-256k", 65_521, 2_000, 256 * 1024),
    Campaign(
        "rle-content-32452843",
        32_452_843,
        2_000,
        generator_args=("--content-size", "--block-type=1", "--max-content-size-log=20"),
        require_block_stream=False,
        expected_mode_mask=0,
        min_max_block_count=2,
    ),
    Campaign(
        "raw-8b-49979693",
        49_979_693,
        2_000,
        generator_args=("--block-type=0", "--max-block-size-log=3", "--max-content-size-log=14"),
        require_block_stream=False,
        expected_mode_mask=0,
        min_max_block_count=2,
    ),
    Campaign(
        "compressed-16b-67867979",
        67_867_979,
        500,
        generator_args=("--block-type=2", "--max-block-size-log=4", "--max-content-size-log=13"),
        require_block_stream=False,
        expected_mode_mask=COMPLETE_MODE_MASK,
        min_max_block_count=2,
    ),
)
CAMPAIGNS_BY_NAME = {campaign.name: campaign for campaign in CAMPAIGNS}


def parse_summary(output: str) -> dict[str, str]:
    for line in reversed(output.splitlines()):
        if line.startswith(SUMMARY_PREFIX):
            fields = {}
            for field in line.split()[1:]:
                if "=" not in field:
                    continue
                key, value = field.split("=", 1)
                fields[key] = value
            return fields
    raise ValueError("compat probe did not emit a zstd_compat_probe summary")


def resolve_decodecorpus(explicit: str | None) -> Path:
    if explicit:
        candidate = Path(explicit).expanduser()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
        raise FileNotFoundError(f"upstream decodecorpus executable is not executable: {candidate}")
    if os.environ.get("DECODECORPUS"):
        candidate = Path(os.environ["DECODECORPUS"]).expanduser()
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
        raise FileNotFoundError(f"$DECODECORPUS is not executable: {candidate}")

    candidates = [Path.home() / "Work" / "zstd" / "tests" / "decodecorpus"]
    installed = shutil.which("decodecorpus")
    if installed:
        candidates.append(Path(installed))

    for candidate in candidates:
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate.resolve()
    rendered = ", ".join(str(candidate) for candidate in candidates)
    raise FileNotFoundError(
        "upstream decodecorpus executable not found; build it with "
        "`make -C ~/Work/zstd/tests decodecorpus` or pass --decodecorpus PATH "
        f"(checked: {rendered})"
    )


def run_command(command: list[str], label: str) -> str:
    result = subprocess.run(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        if result.stdout:
            print(result.stdout, end="", file=sys.stderr)
        raise RuntimeError(f"{label} failed with exit code {result.returncode}")
    return result.stdout


def generator_version(executable: Path) -> str:
    root = executable.parent.parent
    result = subprocess.run(
        ["git", "-C", str(root), "describe", "--tags", "--always", "--dirty"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        check=False,
    )
    return result.stdout.strip() if result.returncode == 0 and result.stdout.strip() else "unknown"


def select_campaigns(names: list[str] | None) -> tuple[Campaign, ...]:
    if not names:
        return CAMPAIGNS
    selected: list[Campaign] = []
    seen: set[str] = set()
    for name in names:
        if name in seen:
            raise ValueError(f"duplicate campaign: {name}")
        seen.add(name)
        selected.append(CAMPAIGNS_BY_NAME[name])
    return tuple(selected)


def validate_final_coverage(campaigns: tuple[Campaign, ...], combined_mask: int) -> None:
    complete_suite = {campaign.name for campaign in campaigns} == set(CAMPAIGNS_BY_NAME)
    if complete_suite and combined_mask != COMPLETE_MODE_MASK:
        raise RuntimeError(
            f"full campaign suite covered only {combined_mask.bit_count()}/64 sequence-mode "
            f"combinations (mask={combined_mask:#018x})"
        )


def validate_generated_files(root: Path, campaign: Campaign) -> None:
    frames = list(root.glob("z[0-9][0-9][0-9][0-9][0-9][0-9].zst"))
    plain = [path for path in root.glob("z[0-9][0-9][0-9][0-9][0-9][0-9]") if path.is_file()]
    if len(frames) != campaign.count or len(plain) != campaign.count:
        raise RuntimeError(
            f"{campaign.name} generated {len(frames)} frames and {len(plain)} plain files; "
            f"expected {campaign.count} of each"
        )
    if campaign.dictionary_size is not None and not (root / "dictionary").is_file():
        raise RuntimeError(f"{campaign.name} did not generate its dictionary")


def validate_campaign_summary(
    fields: dict[str, str], campaign: Campaign, prior_mask: int
) -> tuple[int, int, int, int, int]:
    try:
        decoded_cases = int(fields["decodecorpus_cases"], 0)
        incremental_cases = int(fields["decodecorpus_incremental_cases"], 0)
        block_stream_cases = int(fields["decodecorpus_block_stream_cases"], 0)
        max_compressed_buffered = int(fields["decodecorpus_max_compressed_buffered"], 0)
        max_compressed_capacity = int(fields["decodecorpus_max_compressed_capacity"], 0)
        streamed_literal_blocks = int(fields["decodecorpus_streamed_literal_blocks"], 0)
        streamed_sequence_blocks = int(fields["decodecorpus_streamed_sequence_blocks"], 0)
        max_block_stream_decoded_buffered = int(fields["decodecorpus_max_block_stream_decoded_buffered"], 0)
        max_block_stream_decoded_capacity = int(fields["decodecorpus_max_block_stream_decoded_capacity"], 0)
        unsupported = int(fields["unsupported"], 0)
        max_sequence_count = int(fields["decodecorpus_max_sequence_count"], 0)
        max_block_count = int(fields["decodecorpus_max_block_count"], 0)
        sequence_count_tiers = int(fields["decodecorpus_sequence_count_tiers"], 0)
        mode_combinations = int(fields["decodecorpus_sequence_mode_combinations"], 0)
        mode_mask = int(fields["decodecorpus_sequence_mode_mask"], 0)
        combined_combinations = int(fields["decodecorpus_combined_mode_combinations"], 0)
        combined_mask = int(fields["decodecorpus_combined_mode_mask"], 0)
    except (KeyError, ValueError) as error:
        raise RuntimeError(f"malformed compat summary for {campaign.name}: {fields}") from error
    if decoded_cases != campaign.count:
        raise RuntimeError(
            f"{campaign.name} decoded {decoded_cases} generated cases; expected {campaign.count}"
        )
    if incremental_cases != campaign.count:
        raise RuntimeError(
            f"{campaign.name} incrementally decoded {incremental_cases} generated cases; "
            f"expected {campaign.count}"
        )
    if campaign.require_block_stream and block_stream_cases == 0:
        raise RuntimeError(f"{campaign.name} did not exercise bounded block streaming")
    if not 0 < max_compressed_buffered <= BLOCK_STREAM_COMPRESSED_LIMIT:
        raise RuntimeError(
            f"{campaign.name} retained {max_compressed_buffered} compressed bytes; "
            f"limit is {BLOCK_STREAM_COMPRESSED_LIMIT}"
        )
    if not 0 < max_compressed_capacity <= BLOCK_STREAM_COMPRESSED_LIMIT:
        raise RuntimeError(
            f"{campaign.name} allocated {max_compressed_capacity} compressed-buffer bytes; "
            f"limit is {BLOCK_STREAM_COMPRESSED_LIMIT}"
        )
    if unsupported != 0:
        raise RuntimeError(f"{campaign.name} reported {unsupported} unsupported frames")
    if mode_combinations != mode_mask.bit_count():
        raise RuntimeError(
            f"{campaign.name} reported {mode_combinations} mode combinations for "
            f"mask {mode_mask:#018x}"
        )
    if combined_combinations != combined_mask.bit_count():
        raise RuntimeError(
            f"{campaign.name} reported {combined_combinations} cumulative mode combinations "
            f"for mask {combined_mask:#018x}"
        )
    if campaign.expected_mode_mask is not None and mode_mask != campaign.expected_mode_mask:
        raise RuntimeError(
            f"{campaign.name} mode mask {mode_mask:#018x} does not match required "
            f"{campaign.expected_mode_mask:#018x}"
        )
    if max_block_count < campaign.min_max_block_count:
        raise RuntimeError(
            f"{campaign.name} maximum block count {max_block_count} is below required "
            f"{campaign.min_max_block_count}"
        )
    if mode_mask != 0 and (max_sequence_count == 0 or sequence_count_tiers == 0):
        raise RuntimeError(f"{campaign.name} reported sequence modes without sequence coverage")
    if max_block_stream_decoded_buffered != 0 or max_block_stream_decoded_capacity != 0:
        raise RuntimeError(
            f"{campaign.name} retained decoded block scratch while block streaming: "
            f"bytes={max_block_stream_decoded_buffered} capacity={max_block_stream_decoded_capacity}"
        )
    expected_combined = prior_mask | mode_mask
    if combined_mask != expected_combined:
        raise RuntimeError(
            f"{campaign.name} combined mask {combined_mask:#018x} does not match "
            f"{expected_combined:#018x}"
        )
    return combined_mask, block_stream_cases, max_compressed_buffered, streamed_literal_blocks, streamed_sequence_blocks


def run_campaign(
    probe: Path,
    decodecorpus: Path,
    campaign: Campaign,
    prior_mask: int,
    reference_library: Path | None,
) -> tuple[int, int, int, int, int, str]:
    with tempfile.TemporaryDirectory(prefix=f"vort-zstd-{campaign.name}-") as temp:
        root = Path(temp)
        generator_command = [
            str(decodecorpus),
            f"-s{campaign.seed}",
            f"-n{campaign.count}",
            f"-p{root}",
            f"-o{root}",
        ]
        if campaign.dictionary_size is not None:
            generator_command.append(f"--use-dict={campaign.dictionary_size}")
        generator_command.extend(campaign.generator_args)
        run_command(generator_command, f"decodecorpus campaign {campaign.name}")
        validate_generated_files(root, campaign)

        probe_command = [
            str(probe),
            "--decodecorpus",
            str(root),
            str(root),
            "--decodecorpus-count",
            str(campaign.count),
            "--prior-mode-mask",
            hex(prior_mask),
        ]
        if campaign.dictionary_size is not None:
            probe_command.extend(("--decodecorpus-dictionary", str(root / "dictionary")))
        if reference_library is not None:
            probe_command.extend(("--libzstd", str(reference_library)))
        output = run_command(probe_command, f"Vort compat probe for {campaign.name}")
        fields = parse_summary(output)
        combined_mask, block_stream_cases, max_compressed_buffered, streamed_literal_blocks, streamed_sequence_blocks = validate_campaign_summary(
            fields, campaign, prior_mask
        )
        max_decoded_buffered = int(fields["decodecorpus_max_block_stream_decoded_buffered"], 0)
        max_decoded_capacity = int(fields["decodecorpus_max_block_stream_decoded_capacity"], 0)
        mode_mask = int(fields["decodecorpus_sequence_mode_mask"], 0)
        max_block_count = int(fields["decodecorpus_max_block_count"], 0)
        max_sequence_count = int(fields["decodecorpus_max_sequence_count"], 0)
        sequence_count_tiers = int(fields["decodecorpus_sequence_count_tiers"], 0)
        reference_version = fields["version"]
        if not reference_version:
            raise RuntimeError(f"{campaign.name} reported an empty reference version")
        print(
            f"zstd_decodecorpus_campaign=ok name={campaign.name} seed={campaign.seed} "
            f"cases={campaign.count} dictionary_bytes={campaign.dictionary_size or 0} "
            f"block_stream_cases={block_stream_cases} max_compressed_buffered={max_compressed_buffered} "
            f"streamed_literal_blocks={streamed_literal_blocks} "
            f"streamed_sequence_blocks={streamed_sequence_blocks} "
            f"max_block_stream_decoded_buffered={max_decoded_buffered} "
            f"max_block_stream_decoded_capacity={max_decoded_capacity} "
            f"max_sequence_count={max_sequence_count} max_block_count={max_block_count} "
            f"sequence_count_tiers={sequence_count_tiers:#x} "
            f"mode_mask={mode_mask:#018x} combined_mode_mask={combined_mask:#018x} "
            f"reference_version={reference_version}",
            flush=True,
        )
        return combined_mask, block_stream_cases, max_compressed_buffered, streamed_literal_blocks, streamed_sequence_blocks, reference_version


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", type=Path, help="built Vort zstd compatibility probe")
    parser.add_argument("--decodecorpus", help="upstream tests/decodecorpus executable")
    parser.add_argument(
        "--libzstd",
        type=Path,
        help="explicit libzstd shared library used by the compatibility probe",
    )
    parser.add_argument(
        "--campaign",
        action="append",
        choices=tuple(CAMPAIGNS_BY_NAME),
        help="run only a named campaign; may be repeated (default: all nine)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    probe = args.probe.resolve()
    if not probe.is_file() or not os.access(probe, os.X_OK):
        raise SystemExit(f"Vort compatibility probe is not executable: {probe}")
    try:
        decodecorpus = resolve_decodecorpus(args.decodecorpus)
        reference_library = args.libzstd.expanduser().resolve() if args.libzstd else None
        if reference_library is not None and not reference_library.is_file():
            raise FileNotFoundError(f"libzstd shared library is not a file: {reference_library}")
        campaigns = select_campaigns(args.campaign)
        combined_mask = 0
        total_cases = 0
        total_block_stream_cases = 0
        max_compressed_buffered = 0
        total_streamed_literal_blocks = 0
        total_streamed_sequence_blocks = 0
        reference_version: str | None = None
        for campaign in campaigns:
            combined_mask, block_stream_cases, campaign_max_buffered, streamed_literal_blocks, streamed_sequence_blocks, campaign_reference_version = run_campaign(
                probe, decodecorpus, campaign, combined_mask, reference_library
            )
            if reference_version is None:
                reference_version = campaign_reference_version
            elif reference_version != campaign_reference_version:
                raise RuntimeError(
                    f"reference library version changed from {reference_version} to "
                    f"{campaign_reference_version}"
                )
            total_cases += campaign.count
            total_block_stream_cases += block_stream_cases
            max_compressed_buffered = max(max_compressed_buffered, campaign_max_buffered)
            total_streamed_literal_blocks += streamed_literal_blocks
            total_streamed_sequence_blocks += streamed_sequence_blocks
        validate_final_coverage(campaigns, combined_mask)
        if len(campaigns) == len(CAMPAIGNS) and total_streamed_literal_blocks == 0:
            raise RuntimeError("full campaign suite did not stream a sequence-free compressed block")
        if len(campaigns) == len(CAMPAIGNS) and total_streamed_sequence_blocks == 0:
            raise RuntimeError("full campaign suite did not stream a sequence-bearing compressed block")
    except (FileNotFoundError, RuntimeError, ValueError) as error:
        raise SystemExit(f"zstd decodecorpus gate failed: {error}") from error

    print(
        f"zstd_decodecorpus_gate=ok campaigns={len(campaigns)} cases={total_cases} "
        f"block_stream_cases={total_block_stream_cases} "
        f"max_compressed_buffered={max_compressed_buffered} "
        f"streamed_literal_blocks={total_streamed_literal_blocks} "
        f"streamed_sequence_blocks={total_streamed_sequence_blocks} "
        f"max_block_stream_decoded_buffered=0 "
        f"max_block_stream_decoded_capacity=0 "
        f"sequence_mode_combinations={combined_mask.bit_count()} "
        f"sequence_mode_mask={combined_mask:#018x} generator={decodecorpus} "
        f"generator_version={generator_version(decodecorpus)} "
        f"reference_library={reference_library or 'system'} "
        f"reference_version={reference_version}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
