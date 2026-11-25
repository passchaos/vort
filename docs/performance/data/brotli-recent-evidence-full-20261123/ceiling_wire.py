import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).parent
candidate = sys.argv[1] if len(sys.argv) > 1 else 'variant'
out = root / (sys.argv[2] if len(sys.argv) > 2 else 'ceiling-wire')
baseline_dir = root / sys.argv[3] if len(sys.argv) > 3 else None
out.mkdir(exist_ok=True)
reference = Path('/home/passchaos/Work/brotli/build-vort')
rows = []
for quality, limit, ceiling in [(10, 65536, 64), (11, 32768, 32)]:
    payload = out / f'periodic-{limit}'
    payload.write_bytes(b'abcdefghijklmnopqrstuvwxyz012345' * (limit // 32))
    reports = {}
    for role in ('baseline', 'variant'):
        prefix = out / f'q{quality}-{role}'
        if role == 'baseline' and baseline_dir is not None:
            reports[role] = json.loads((baseline_dir / prefix.with_suffix('.json').name).read_text())
            continue
        args = [str(root / (candidate if role == 'variant' else role)), '--planned-quality', str(quality),
                '--quality', str(quality), f'--command-state-max-input-kib={ceiling}',
                '--window-bits', '16', '--reference-lgwin', '16',
                '--reference-mode', 'generic', '--iterations', '1',
                '--limit', str(limit), '--path', str(payload),
                '--csv', str(prefix.with_suffix('.csv')),
                '--samples-json', str(prefix.with_suffix('.json')),
                '--libbrotli-encoder', str(reference / 'libbrotlienc.so.1.2.0'),
                '--libbrotli-decoder', str(reference / 'libbrotlidec.so.1.2.0'),
                '--libbrotli-common', str(reference / 'libbrotlicommon.so.1.2.0')]
        subprocess.run(args, check=True)
        reports[role] = json.loads(prefix.with_suffix('.json').read_text())
    a, b = reports['baseline']['rows'][0], reports['variant']['rows'][0]
    assert a['input_sha256'] == b['input_sha256'] and a['wires'] == b['wires']
    assert a['settings'] == b['settings']
    rows.append(dict(quality=quality, limit=limit, ceiling=ceiling,
                     input_sha256=a['input_sha256'], wires=a['wires']))
    print(f'q{quality} ceiling {ceiling} KiB: full wire and independent roundtrip matched', flush=True)
(out / 'identity.json').write_text(json.dumps(dict(passed=True, rows=rows), indent=2) + '\n')
