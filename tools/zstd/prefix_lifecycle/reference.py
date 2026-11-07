#!/usr/bin/env python3
"""Stateful, independent libzstd prefix-lifecycle oracle.

Low-level Context operations return actual C results, including errors, rather
than hiding recovery transitions behind exceptions. Snapshots contain only
publicly observable counters and getParameter values; they do not invent C
prefix state. The retained 188-observation audit pins consumption semantics.
"""
from __future__ import annotations
import ctypes as C
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
_spec = importlib.util.spec_from_file_location("_prefix_reference_abi", HERE / "reference/abi.py")
_abi = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_abi)
ReferenceUnavailable, ZstdError = _abi.ReferenceUnavailable, _abi.ZstdError
Buffer, FrameHeader = _abi.Buffer, _abi.FrameHeader
_entropy_spec = importlib.util.spec_from_file_location("_prefix_reference_entropy", HERE / "reference/entropy.py")
_entropy = importlib.util.module_from_spec(_entropy_spec)
_entropy_spec.loader.exec_module(_entropy)
OUTPUT_LIMIT = 64 * 1024 * 1024


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def artifact(path: Path) -> dict:
    return {"path": str(path.resolve()), "size": path.stat().st_size, "sha256": _abi.sha256(path)}


def category(result: dict) -> str:
    error = result.get("error")
    if error is None:
        return "truncated" if result.get("incomplete") else "success"
    for text, name in (("current processing stage", "stage_error"), ("Dictionary mismatch", "dictionary_mismatch"),
                       ("checksum", "checksum"), ("Data corruption", "corruption"),
                       ("Destination buffer", "output_too_small"), ("Allocation error", "allocation"),
                       ("Src size", "source_size"), ("Parameter is out of bound", "parameter_bounds"),
                       ("frame descriptor", "header"), ("frame parameter", "header")):
        if text in error:
            return name
    return "reference_error"


class Library(_abi.ABI):
    def __init__(self, path=None, *, header=None, max_output_size=OUTPUT_LIMIT):
        super().__init__(path, header=header)
        if max_output_size < 0:
            raise ValueError("Invalid output limit")
        self.max_output_size = max_output_size

    def context(self, side: str, *, format="standard", checksum=True, ignore_checksum=False, level=3):
        return Context(self, side, format=format, checksum=checksum, ignore_checksum=ignore_checksum, level=level)

    def format_value(self, format: str) -> int:
        if format not in ("standard", "magicless"):
            raise ValueError("Unknown Zstd format")
        return self.parameters["ZSTD_f_zstd1_magicless" if format == "magicless" else "ZSTD_f_zstd1"]

    def inspect_header(self, wire: bytes, format="standard") -> dict:
        header = FrameHeader()
        ret = self.fn["ZSTD_getFrameHeader_advanced"](C.byref(header), wire, len(wire), self.format_value(format))
        result = self.result(ret)
        result.update(complete=ret == 0, wanted_size=ret if not result["error"] and ret else None)
        if ret == 0:
            result.update(content_size=None if header.frameContentSize == (1 << 64) - 1 else header.frameContentSize,
                          window_size=header.windowSize, block_size_max=header.blockSizeMax,
                          frame_type="skippable" if header.frameType == 1 else "data", header_size=header.headerSize,
                          dictionary_id=header.dictID, checksum=bool(header.checksumFlag))
        return result

    def dictionary_id(self, data: bytes) -> int:
        return self.fn["ZSTD_getDictID_fromDict"](data, len(data))

    def dictionary_header_size(self, data: bytes) -> int:
        return self.check(self.fn["ZDICT_getDictHeaderSize"](data, len(data)), "dictionary header")

    def encode(self, payload: bytes, prefix: bytes | None = None, *, kind="default", dictionary=None,
               format="standard", streaming=False, known_size=True, checksum=True) -> bytes:
        with self.context("C", format=format, checksum=checksum) as context:
            if dictionary is not None:
                self.check(context.load_dictionary(dictionary)["ret"], "load dictionary")
            if prefix is not None:
                self.check(context.ref_prefix(prefix, kind=kind)["ret"], "reference prefix")
            self.check(context.set_parameter("ZSTD_c_contentSizeFlag", int(known_size or streaming))["ret"], "content size")
            if streaming:
                if known_size:
                    self.check(context.pledge(len(payload))["ret"], "source pledge")
                result, output = context.drive_encode(payload)
            else:
                result, output = context.encode_one_shot(payload)
            self.check(result["ret"], "encode")
            return output

    def decode(self, wire: bytes, prefix: bytes | None = None, *, kind="default", dictionary=None,
               format="standard", api="streaming", ignore_checksum=False, input_chunk_size=1,
               output_capacity=113, stop_at_frame=False) -> bytes:
        with self.context("D", format=format, ignore_checksum=ignore_checksum) as context:
            if dictionary is not None:
                self.check(context.load_dictionary(dictionary)["ret"], "load dictionary")
            if prefix is not None:
                self.check(context.ref_prefix(prefix, kind=kind)["ret"], "reference prefix")
            if api == "one_shot":
                result, output = context.decode_one_shot(wire, capacity=self.max_output_size)
            elif api == "streaming":
                result, output = context.drive_decode(wire, chunk_size=input_chunk_size,
                                                      output_capacity=output_capacity, stop_at_frame=stop_at_frame)
            else:
                raise ValueError("Unknown decode API")
            self.check(result["ret"], "decode " + api)
            if result.get("incomplete"):
                raise ZstdError("decode streaming: incomplete or truncated input")
            return output

    def skippable(self, payload=b"xyz", tag=3) -> bytes:
        output = C.create_string_buffer(len(payload) + 8)
        size = self.check(self.fn["ZSTD_writeSkippableFrame"](output, len(output), payload, len(payload), tag), "skippable writer")
        return output.raw[:size]

    def validate_prefix_wire(self, wire, prefix, payload, *, kind="default", format="standard") -> dict:
        """Check C or future Vort wire with correct, missing and changed history.

        For a FULL dictionary the ID, entropy tables and repcodes stay byte-for-
        byte identical. Only its history changes, so a header ID mismatch cannot
        explain the negative control.
        """
        full = kind == "full" or kind == 2 or kind in ("auto", 0) and self.dictionary_id(prefix) > 0
        offset = self.dictionary_header_size(prefix) if full else 0
        wrong = prefix[:offset] + bytes(value ^ 0x5a for value in prefix[offset:])
        observations = {}
        for label, value in (("correct_prefix", prefix), ("missing_prefix", None), ("wrong_history", wrong)):
            with self.context("D", format=format) as context:
                control = context.ref_prefix(value, kind=kind) if value is not None else None
                if control is not None and control["error"]:
                    result, output = control, b""
                else:
                    result, output = context.drive_decode(wire)
                observations[label] = {"result": {key: val for key, val in result.items() if key != "snapshot"},
                                       "accepted": not result.get("error") and not result.get("incomplete"),
                                       "equals_payload": output == payload, "output_size": len(output),
                                       "output_sha256": digest(output)}
        observations["history_dependency"] = (observations["correct_prefix"]["accepted"]
            and observations["correct_prefix"]["equals_payload"]
            and not (observations["missing_prefix"]["accepted"] and observations["missing_prefix"]["equals_payload"])
            and not (observations["wrong_history"]["accepted"] and observations["wrong_history"]["equals_payload"]))
        observations["wrong_history_control"] = {"full_dictionary_header_unchanged": full,
            "history_offset": offset, "prefix_size": len(prefix), "correct_prefix_sha256": digest(prefix),
            "wrong_prefix_sha256": digest(wrong), "mutation": "XOR 0x5a on history; FULL header, ID, entropy and repcodes unchanged"}
        entropy = _entropy.observe(self, wire, prefix, payload, format) if full else None
        observations["entropy_control"] = entropy
        observations["entropy_dependency"] = entropy is not None and entropy["entropy_dependency"]
        observations["prefix_dependency"] = observations["history_dependency"] or observations["entropy_dependency"]
        return observations

    def provenance(self) -> dict:
        return {"version": self.version, "version_number": self.version_number, "path": str(self.path),
                "sha256": _abi.sha256(self.path), "header_path": str(self.header_path),
                "header_version": self.version, "header_sha256": _abi.sha256(self.header_path),
                "parameters": self.parameters, "frame_header_abi_size": C.sizeof(FrameHeader),
                "reference": artifact(Path(__file__)), "abi": artifact(HERE / "reference/abi.py"),
                "entropy_reference": artifact(HERE / "reference/entropy.py"),
                "audit_source": artifact(HERE / "reference/audit_probe.py"),
                "audit_baseline": artifact(HERE / "reference/audit_baseline.jsonl"),
                "dictionary_header": artifact(self.header_path.with_name("zdict.h")) if self.header_path.with_name("zdict.h").is_file() else None,
                "notes": artifact(HERE / "reference_notes.md"),
                "prefix_default_type": "raw_content", "persistent_default_type": "auto",
                "snapshot_scope": "actual parameter getters and API progress; opaque dictionary phases are not exposed",
                "max_output_size": self.max_output_size}

    def replay_audit(self, root: Path | str) -> dict:
        """Rerun all 188 retained observations and compare actual C receipts."""
        root = Path(root).resolve()
        root.mkdir(parents=True, exist_ok=True)
        observed, stderr = root / "audit-observed.jsonl", root / "audit-stderr.log"
        command = [sys.executable, str(HERE / "reference/audit_probe.py"), str(self.path), str(REPO / "src/zstd/testdata")]
        with observed.open("w") as out, stderr.open("w") as err:
            completed = subprocess.run(command, stdout=out, stderr=err, timeout=60)
        baseline = [json.loads(row) for row in (HERE / "reference/audit_baseline.jsonl").read_text().splitlines()]
        actual = [json.loads(row) for row in observed.read_text().splitlines()]
        differences = []
        if len(baseline) != len(actual):
            differences.append({"record_count": [len(baseline), len(actual)]})
        for expected, found in zip(baseline, actual):
            expected, found = dict(expected), dict(found)
            if expected.get("case") == "environment":
                expected.pop("lib", None)
                found.pop("lib", None)
            if expected != found:
                differences.append({"expected": expected, "actual": found})
        passed = completed.returncode == 0 and not differences and bool(actual) and actual[-1].get("checks") == "passed"
        return {"command": command, "exit_code": completed.returncode, "passed": passed,
                "observations": len(actual) - 1, "summary": actual[-1] if actual else None,
                "baseline": artifact(HERE / "reference/audit_baseline.jsonl"),
                "observed": artifact(observed), "stderr": artifact(stderr), "differences": differences,
                "comparison_note": "Only environment.lib symlink spelling is normalized"}


class Context:
    """Owned CCtx/DCtx; borrowed prefix buffers remain alive until close()."""
    def __init__(self, library: Library, side: str, *, format, checksum, ignore_checksum, level):
        if side not in ("C", "D"):
            raise ValueError("Context side must be C or D")
        self.library, self.side = library, side
        self.pointer = library.fn["ZSTD_create" + side + "Ctx"]()
        if not self.pointer:
            raise ReferenceUnavailable("Context allocation failed")
        self.held, self.events = [], []
        self.input_read_total, self.output_written_total, self.frame_ends_observed = 0, 0, 0
        parameters = [("ZSTD_c_compressionLevel", level), ("ZSTD_c_checksumFlag", int(checksum)),
                      ("ZSTD_c_format", library.format_value(format))] if side == "C" else [
                          ("ZSTD_d_format", library.format_value(format)), ("ZSTD_d_forceIgnoreChecksum", int(ignore_checksum))]
        for name, value in parameters:
            library.check(self.set_parameter(name, value)["ret"], "initialize context")

    def __enter__(self):
        return self

    def __exit__(self, *arguments):
        self.close()

    def close(self):
        if self.pointer:
            self.library.fn["ZSTD_free" + self.side + "Ctx"](self.pointer)
            self.pointer = None
            self.held.clear()

    def _function(self, suffix):
        if not self.pointer:
            raise RuntimeError("Closed context")
        return self.library.fn["ZSTD_" + self.side + "Ctx_" + suffix]

    def query_parameter(self, name):
        number = self.library.parameters[name] if isinstance(name, str) else name
        value = C.c_int()
        result = self.library.result(self._function("getParameter")(self.pointer, number, C.byref(value)))
        result["value"] = None if result["error"] else value.value
        return result

    def snapshot(self):
        names = ("ZSTD_c_compressionLevel", "ZSTD_c_contentSizeFlag", "ZSTD_c_checksumFlag", "ZSTD_c_dictIDFlag", "ZSTD_c_format") if self.side == "C" else ("ZSTD_d_format", "ZSTD_d_forceIgnoreChecksum")
        return {"parameters": {name: self.query_parameter(name) for name in names},
                "last_call": self.events[-1]["operation"] if self.events else None,
                "input_read_total": self.input_read_total, "output_written_total": self.output_written_total,
                "frame_ends_observed": self.frame_ends_observed, "calls_observed": len(self.events)}

    def _record(self, operation, return_code, **extra):
        result = {"operation": operation, **self.library.result(return_code), **extra}
        self.events.append(result)
        result["snapshot"] = self.snapshot()
        return result

    def set_parameter(self, name, value):
        number = self.library.parameters[name] if isinstance(name, str) else name
        return self._record("set_parameter", self._function("setParameter")(self.pointer, number, value), parameter=name, value=value)

    def reset(self, directive="session"):
        number = {"session": 1, "parameters": 2, "all": 3}.get(directive, directive)
        return self._record("reset", self._function("reset")(self.pointer, number), directive=directive)

    def ref_prefix(self, data=b"", *, kind="default", null=False, size=None):
        data = bytes(data)
        size = len(data) if size is None else size
        if size < 0 or (not null and size > len(data)):
            raise ValueError("Prefix size exceeds its buffer")
        source = None if null else C.create_string_buffer(data, len(data) + 1)
        if source is not None:
            self.held.append(source)
        if kind == "default":
            ret = self._function("refPrefix")(self.pointer, source, size)
        else:
            number = {"auto": 0, "raw": 1, "full": 2}.get(kind, kind)
            ret = self._function("refPrefix_advanced")(self.pointer, source, size, number)
        return self._record("ref_prefix", ret, kind=kind, prefix_size=size, prefix_sha256=digest(data), null=null)

    def load_dictionary(self, data=b"", *, kind="auto"):
        data = bytes(data)
        number = {"auto": 0, "raw": 1, "full": 2}.get(kind, kind)
        ret = self._function("loadDictionary_advanced")(self.pointer, data, len(data), 0, number)
        return self._record("load_dictionary", ret, kind=kind, dictionary_size=len(data), dictionary_sha256=digest(data))

    def pledge(self, size=None):
        if self.side != "C":
            raise ValueError("Only encoders accept source pledges")
        ret = self.library.fn["ZSTD_CCtx_setPledgedSrcSize"](self.pointer, (1 << 64) - 1 if size is None else size)
        return self._record("pledge", ret, size=size)

    def encode_one_shot(self, payload: bytes, *, capacity=None):
        if self.side != "C":
            raise ValueError("Wrong context side")
        capacity = self.library.fn["ZSTD_compressBound"](len(payload)) if capacity is None else capacity
        return self._one_shot("encode_once", "ZSTD_compress2", payload, capacity)

    def decode_one_shot(self, wire: bytes, *, capacity=None):
        if self.side != "D":
            raise ValueError("Wrong context side")
        return self._one_shot("decode_once", "ZSTD_decompressDCtx", wire, self.library.max_output_size if capacity is None else capacity)

    def _one_shot(self, operation, function, data, capacity):
        if capacity < 0:
            raise ValueError("Negative output capacity")
        data = bytes(data)
        output = C.create_string_buffer(max(1, capacity))
        ret = self.library.fn[function](self.pointer, output, capacity, data, len(data))
        error = self.library.result(ret)["error"]
        result_data = b"" if error else output.raw[:ret]
        if not error:
            self.output_written_total += ret
        result = self._record(operation, ret, source_size=len(data), input_read=None,
                              output_written=None if error else ret, output_sha256=None if error else digest(result_data))
        return result, result_data

    def encode_step(self, data: bytes, *, directive="continue", output_capacity=113):
        if self.side != "C":
            raise ValueError("Wrong context side")
        number = {"continue": 0, "flush": 1, "end": 2}.get(directive, directive)
        return self._step("encode_step", data, output_capacity, number)

    def decode_step(self, data: bytes, *, output_capacity=113):
        if self.side != "D":
            raise ValueError("Wrong context side")
        return self._step("decode_step", data, output_capacity, None)

    def _step(self, operation, data, capacity, directive):
        if capacity < 0:
            raise ValueError("Negative output capacity")
        data = bytes(data)
        source = C.create_string_buffer(data, len(data) + 1)
        output = C.create_string_buffer(max(1, capacity))
        input_ = Buffer(C.addressof(source), len(data), 0)
        destination = Buffer(C.addressof(output), capacity, 0)
        arguments = (self.pointer, C.byref(destination), C.byref(input_))
        ret = self.library.fn["ZSTD_decompressStream"](*arguments) if directive is None else self.library.fn["ZSTD_compressStream2"](*arguments, directive)
        self.input_read_total += input_.pos
        self.output_written_total += destination.pos
        if ret == 0 and (directive == 2 or directive is None):
            self.frame_ends_observed += 1
        result_data = output.raw[:destination.pos]
        return self._record(operation, ret, source_size=len(data), input_read=input_.pos, output_written=destination.pos,
                            output_sha256=digest(result_data), directive=directive), result_data

    def drive_encode(self, payload, *, chunk_size=31, output_capacity=113):
        if chunk_size <= 0 or output_capacity <= 0:
            raise ValueError("Invalid streaming chunk size")
        chunks, offset = [], 0
        # Even empty continue initializes the encoder and consumes its prefix.
        first = True
        while first or offset < len(payload):
            first = False
            result, output = self.encode_step(payload[offset:offset + chunk_size], output_capacity=output_capacity)
            chunks.append(output)
            offset += result["input_read"]
            if result["error"]:
                return {**result, "accepted": offset}, b"".join(chunks)
            if result["input_read"] == 0 and not output and offset < len(payload):
                raise ZstdError("Encoder made no progress")
        while True:
            result, output = self.encode_step(b"", directive="end", output_capacity=output_capacity)
            chunks.append(output)
            if result["error"] or result["ret"] == 0:
                return {**result, "accepted": offset, "total_output": sum(map(len, chunks))}, b"".join(chunks)
            if not output:
                raise ZstdError("Encoder end made no progress")

    def drive_decode(self, wire, *, chunk_size=1, output_capacity=113, stop_at_frame=False):
        if chunk_size <= 0 or output_capacity <= 0:
            raise ValueError("Invalid streaming chunk size")
        offset, chunks, total = 0, [], 0
        while True:
            result, output = self.decode_step(wire[offset:offset + chunk_size], output_capacity=output_capacity)
            chunks.append(output)
            total += len(output)
            offset += result["input_read"]
            if total > self.library.max_output_size:
                raise ZstdError("Decoder output exceeds configured limit")
            if result["error"] or result["ret"] == 0 and (stop_at_frame or offset == len(wire)):
                return {**result, "accepted": offset, "total_output": total, "incomplete": False}, b"".join(chunks)
            if not result["input_read"] and not output:
                if offset == len(wire):
                    return {**result, "accepted": offset, "total_output": total, "incomplete": result["ret"] != 0}, b"".join(chunks)
                raise ZstdError("Decoder made no progress")
