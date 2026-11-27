"""Deferred source audit. Root release is mandatory before payload reads/hashes."""
import argparse
import difflib
import hashlib
import re
from pathlib import Path
from common import PACKAGE, read_json, require_release, write_json

WORD = re.compile(r"[A-Za-z0-9_]+")


def quoted_end(text, start):
    quote = text[start]
    index = start + 1
    while index < len(text):
        if text[index] == "\\":
            index += 2
        elif text[index] == quote:
            return index + 1
        else:
            index += 1
    raise ValueError("Unterminated source quote")


def trivia_end(text, start):
    index = start
    while index < len(text):
        if text[index].isspace():
            index += 1
        elif text.startswith("//", index):
            end = text.find("\n", index)
            index = len(text) if end < 0 else end + 1
        else:
            return index
    return index


def brace_end(text, start):
    depth = 0
    index = start
    while index < len(text):
        if text.startswith("//", index) or text.startswith("\\\\", index):
            end = text.find("\n", index)
            index = len(text) if end < 0 else end + 1
            continue
        if text[index] in ('"', "'"):
            index = quoted_end(text, index)
            continue
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    raise ValueError("Unbalanced test declaration")


def non_test_tokens(text):
    tokens = []
    depth = 0
    index = 0
    while index < len(text):
        index = trivia_end(text, index)
        if index == len(text):
            break
        char = text[index]
        if text.startswith("\\\\", index):
            end = text.find("\n", index)
            end = len(text) if end < 0 else end
            tokens.append(text[index:end])
            index = end
            continue
        if char in ('"', "'"):
            end = quoted_end(text, index)
            tokens.append(text[index:end])
            index = end
            continue
        word = WORD.match(text, index)
        if word:
            token = word.group()
            end = index + len(token)
            if depth == 0 and token == "test":
                body = trivia_end(text, end)
                if body < len(text) and text[body] == '"':
                    body = trivia_end(text, quoted_end(text, body))
                if body >= len(text) or text[body] != "{":
                    raise ValueError("Unsupported top-level test syntax")
                index = brace_end(text, body)
                continue
            tokens.append(token)
            index = end
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
        tokens.append(char)
        index += 1
    if depth != 0:
        raise ValueError("Unbalanced non-test source")
    return tokens


def audit():
    epochs = read_json(PACKAGE / "source-epochs.json")
    by_id = {entry["id"]: entry for entry in epochs["epochs"]}
    old_root = Path(by_id["public-frozen"]["root"])
    final_root = Path(by_id["final-candidate"]["root"])
    old_map = read_json(by_id["public-frozen"]["manifest"])
    final_map = read_json(by_id["final-candidate"]["manifest"])
    changed = [path for path in sorted(set(old_map) | set(final_map)) if old_map.get(path) != final_map.get(path)]
    if changed != ["src/br.zig"]:
        raise ValueError(f"Source epochs changed beyond declared test import scope: {changed}")
    old_bytes = (old_root / "src/br.zig").read_bytes()
    final_bytes = (final_root / "src/br.zig").read_bytes()
    old, final = old_bytes.decode(), final_bytes.decode()
    hashes = {"public": hashlib.sha256(old_bytes).hexdigest(),
              "final": hashlib.sha256(final_bytes).hexdigest()}
    if hashes["public"] != old_map["src/br.zig"] or hashes["final"] != final_map["src/br.zig"]:
        raise ValueError("Source payload differs from its own recorded manifest")
    equal = non_test_tokens(old) == non_test_tokens(final)
    proof = {"schema": "vort.original-command-split-plans.scope-audit.v1",
             "source_trees_byte_identical": False, "changed_paths": changed,
             "br_source_hashes": hashes, "non_test_tokens_equal": equal,
             "tokenization": "small lexical scanner removes top-level tests, whitespace and line comments; not a Zig semantic parser",
             "scope": "only non-test br.zig token identity; no binary/layout/whole-source identity claim"}
    diff = difflib.unified_diff(old.splitlines(True), final.splitlines(True),
                                fromfile="public-frozen/src/br.zig", tofile="final-candidate/src/br.zig")
    return proof, "".join(diff)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--release", required=True)
    args = parser.parse_args()
    require_release(args.release)
    proof, diff = audit()
    write_json(PACKAGE / "proofs/source-scope-audit.json", proof)
    (PACKAGE / "proofs/public-vs-final-full.diff").write_text(diff)
    if not proof["non_test_tokens_equal"]:
        raise ValueError("Non-test production token identity failed; keep the failed proof")
    print("Distinct source epochs audited; test-declaration difference retained")


if __name__ == "__main__":
    main()
