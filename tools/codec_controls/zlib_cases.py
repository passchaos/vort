"""Bounded source fixtures and configurations for the zlib control probes.

No encoder produces these fixtures. The driver supplies output_path and checks
every emitted stream with the independent RFC 1950/1951 oracle.
"""

from pathlib import Path


WINDOW_BITS = tuple(range(9, 16))
MODES = ("stored", "fixed", "dynamic", "dynamic_literal", "best", "adaptive", "png_ultrafast")
_NEAR_COPIES = b"\x00near-window-control:" + b"xyz" * 96 + b"\xff"


def _xorshift_bytes(size: int, seed: int) -> bytes:
    state = seed & 0xffffffff
    output = bytearray()
    for _ in range(size):
        state ^= (state << 13) & 0xffffffff
        state ^= state >> 17
        state ^= (state << 5) & 0xffffffff
        output.append(state & 255)
    return bytes(output)


def _window_payload(bits: int) -> bytes:
    window = 1 << bits
    base = _xorshift_bytes(window + 1, 0x19510A71 ^ bits)
    # The first repeated prefix is W+1 bytes from the original, while the
    # second repeated prefix is exactly W bytes from the preceding prefix.
    return base + base[:window] + base[:window] + _NEAR_COPIES


def cases(out_dir: Path) -> list[dict]:
    """Write reusable source .bin files and return 136 JSON-safe probe cases.

    All cases explicitly use input_chunk=13 and output_chunk=3. A scheduled
    incremental case only enables the probe's own params/flush/reset/nextStream
    scenario; this generator does not synthesize a wire or expected receipt.
    Empty dictionaries remain a real empty source file, distinct from null.
    """
    directory = Path(out_dir).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    result = []

    def source(name: str, payload: bytes) -> str:
        path = directory / f"zlib-{name}.bin"
        path.write_bytes(payload)
        return str(path)

    payloads = {bits: source(f"window-{bits}", _window_payload(bits)) for bits in WINDOW_BITS}
    # One zero literal, four distance-one length-258 copies, one zero tail byte.
    png_payload = source("png-zero-tail1", b"\0" * (1 + 4 * 258 + 1))
    empty_dictionary = source("dictionary-empty", b"")
    long_dictionaries, dictionary_payloads = {}, {}
    for bits in (9, 15):
        window = 1 << bits
        dictionary = _xorshift_bytes(2 * window + 37, 0xD1C710A7 ^ bits)
        long_dictionaries[bits] = source(f"dictionary-long-{bits}", dictionary)
        dictionary_payloads[bits] = source(
            f"dictionary-payload-{bits}",
            dictionary[-window:] + dictionary[-257:] * 2 + _NEAR_COPIES,
        )

    def add(api: str, bits: int, mode: str, *, suffix: str = "",
            payload_path: str | None = None, dictionary_path: str | None = None,
            block_len: int | None = None, runtime_schedule: bool = False) -> None:
        config = {
            "family": "zlib", "api": api,
            "payload_path": payload_path or payloads[bits],
            "dictionary_path": dictionary_path,
            "window_bits": bits, "zlib_mode": mode,
            "runtime_schedule": runtime_schedule, "input_chunk": 13, "output_chunk": 3,
        }
        if block_len is not None:
            config["block_len"] = block_len
        result.append({"name": f"zlib-{api}-w{bits}-{mode}{suffix}", "config": config})

    for bits in WINDOW_BITS:
        for mode in MODES:
            add("frame_alloc", bits, mode,
                payload_path=png_payload if mode == "png_ultrafast" else payloads[bits])
        for mode in ("fixed", "dynamic", "best"):
            add("frame_alloc", bits, mode, suffix="-split257", block_len=257)
        for api, mode in (("incremental_fixed", "fixed"), ("incremental_best", "best")):
            add(api, bits, mode, suffix="-normal")
            add(api, bits, mode, suffix="-scheduled", runtime_schedule=True)

    for bits in (9, 15):
        for kind, dictionary_path in (("long", long_dictionaries[bits]), ("empty", empty_dictionary)):
            payload_path = dictionary_payloads[bits] if kind == "long" else payloads[bits]
            add("frame_alloc", bits, "fixed", suffix=f"-dict-{kind}",
                payload_path=payload_path, dictionary_path=dictionary_path)
            for api, mode in (("incremental_fixed", "fixed"), ("incremental_best", "best")):
                add(api, bits, mode, suffix=f"-dict-{kind}",
                    payload_path=payload_path, dictionary_path=dictionary_path)
        for api in ("frame_append", "frame_into", "frame_scratch"):
            for mode in ("stored", "fixed", "best"):
                add(api, bits, mode)
        for api in ("stored_chunks_alloc", "stored_chunks_append", "stored_chunks_into", "stored_chunks_scratch"):
            add(api, bits, "stored")
    return result
