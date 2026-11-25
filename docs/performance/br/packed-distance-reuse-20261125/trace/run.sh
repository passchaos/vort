#!/usr/bin/env bash
set -euxo pipefail
if [ "$#" -ne 5 ]; then
    echo "usage: $0 WORKTREE OUTPUT HOTSPOT_MANIFEST FIXTURES BROTLI_LIBRARY_DIR" >&2
    exit 2
fi
worktree=$(realpath "$1")
artifacts=$(realpath -m "$2")
manifest=$(realpath "$3")
fixtures=$(realpath "$4")
reference=$(realpath "$5")
zig=${ZIG:-zig}
cpu=${TRACE_CPUS:-4,12}
mkdir "$artifacts"
cd "$worktree"

"$zig" version
"$zig" fmt src/br.zig src/br/diagnostics/distance_reuse_trace.zig tools/br/decode_mozilla/distance_reuse_probe.zig
# All build caches and outputs are inside the authorized scratch tree.
taskset -c "$cpu" "$zig" build-exe -O ReleaseFast -mcpu=native -lc \
    --cache-dir "$artifacts/local-cache" --global-cache-dir "$artifacts/global-cache" \
    --dep br --dep libbrotli_runtime -Mroot=tools/br/decode_mozilla/distance_reuse_probe.zig \
    -O ReleaseFast -mcpu=native -Mbr=src/br.zig \
    -O ReleaseFast -mcpu=native -Mlibbrotli_runtime=tools/br/libbrotli_runtime.zig \
    -femit-bin="$artifacts/vort-br-distance-reuse-probe"
for key in mozilla.full.brotli.11 mozilla.full.brotli.6 mozilla.1048576.brotli.11; do
    prefix=${key%%.brotli.*}
    LD_LIBRARY_PATH="$reference" taskset -c "$cpu" "$artifacts/vort-br-distance-reuse-probe" \
        "$fixtures/$key.wire" "$fixtures/$prefix.plain" \
        "$reference/libbrotlienc.so.1.2.0" "$reference/libbrotlidec.so.1.2.0" "$reference/libbrotlicommon.so.1.2.0" \
        > "$artifacts/$key.json"
done
printf 'Pinned compile and all instrumented decodes completed.\n'

# Independently confirm every input file and exact reference library against the frozen manifest.
python3 - "$manifest" <<'PY' > "$artifacts/frozen-verification.json"
import hashlib, json, sys
from pathlib import Path

path = Path(sys.argv[1])
manifest = json.loads(path.read_bytes())
rows = {k: manifest['rows'][k]['task']['fixture'] for k in ('brotli-mozilla-full-q11', 'brotli-mozilla-full-q6', 'brotli-mozilla-1m-q11')}
refs = manifest['references']['brotli']

expected = dict(refs['file_sha256'])
for row in rows.values():
    expected[row['input_path']] = row['input_sha256']
    expected[row['encoded_input_path']] = row['encoded_sha256']
verified = {}
for name, want in sorted(expected.items()):
    file = Path(name)
    with file.open('rb') as stream:
        digest = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
        got = digest.hexdigest()
    assert got == want, (name, got, want)
    verified[name] = {'sha256': got, 'bytes': file.stat().st_size}
print(json.dumps({'manifest': str(path), 'manifest_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                  'rows': rows, 'references': refs, 'verified': verified}, indent=2))
PY
"$zig" fmt --check src/br.zig src/br/diagnostics/distance_reuse_trace.zig tools/br/decode_mozilla/distance_reuse_probe.zig
git diff --check
