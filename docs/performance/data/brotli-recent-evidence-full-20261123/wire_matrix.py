import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).parent
candidate = sys.argv[1] if len(sys.argv) > 1 else 'variant'
out = root / (sys.argv[2] if len(sys.argv) > 2 else 'wire-matrix')
baseline_dir = root / sys.argv[3] if len(sys.argv) > 3 else None
out.mkdir(exist_ok=True)
corpus = Path('/home/passchaos/Work/corpora/silesia-20261025/files')
reference = Path('/home/passchaos/Work/brotli/build-vort')
verified = []
for limit in (8192, 65536):
    for quality in (10, 11):
        reports = {}
        for role in ('baseline', 'variant'):
            prefix = out / f'{limit}-q{quality}-{role}'
            if role == 'baseline' and baseline_dir is not None:
                reports[role] = json.loads((baseline_dir / prefix.with_suffix('.json').name).read_text())
                continue
            args = [str(root / (candidate if role == 'variant' else role)), '--planned-quality', str(quality),
                    '--quality', str(quality), '--command-state-max-input-kib=8',
                    '--window-bits', '16', '--reference-lgwin', '16',
                    '--reference-mode', 'generic', '--iterations', '1',
                    '--limit', str(limit), '--csv', str(prefix.with_suffix('.csv')),
                    '--samples-json', str(prefix.with_suffix('.json')),
                    '--libbrotli-encoder', str(reference / 'libbrotlienc.so.1.2.0'),
                    '--libbrotli-decoder', str(reference / 'libbrotlidec.so.1.2.0'),
                    '--libbrotli-common', str(reference / 'libbrotlicommon.so.1.2.0')]
            for path in sorted(corpus.iterdir()):
                args += ['--path', str(path)]
            subprocess.run(args, check=True)
            reports[role] = json.loads(prefix.with_suffix('.json').read_text())
        before, after = reports['baseline'], reports['variant']
        for field in ('optimize', 'zig_version', 'target_arch', 'target_os',
                      'target_abi', 'target_cpu', 'cpu_model', 'benchmark_threads'):
            assert before['provenance'][field] == after['provenance'][field], field
        assert len(before['rows']) == len(after['rows']) == 12
        for a, b in zip(before['rows'], after['rows'], strict=True):
            assert a['case'] == b['case'] and a['input_sha256'] == b['input_sha256']
            assert a['wires'] == b['wires'], (quality, limit, a['case'], 'wire mismatch')
            assert a['settings']['parameters_match'] and b['settings']['parameters_match']
            verified.append(dict(case=a['case'], limit=limit, quality=quality,
                                 input_sha256=a['input_sha256'], wires=a['wires']))
        print(f'q{quality} {limit}: 12 exact wires and cross-library roundtrips passed', flush=True)
(out / 'identity.json').write_text(json.dumps(dict(passed=True, rows=verified), indent=2) + '\n')
