import json
import subprocess
import sys
from pathlib import Path

root = Path(__file__).parent
out = root / sys.argv[1]
out.mkdir(exist_ok=True)
corpus = Path('/home/passchaos/Work/corpora/silesia-20261025/files')
checked = []
for level in (1, 2, 3):
    reports = {}
    for role in ('baseline', 'variant'):
        prefix = out / f'l{level}-{role}'
        args = [str(root / role), '--level', str(level), '--limit', '131072',
                '--iterations', '1', '--rounds', '1', '--libzstd',
                '/usr/lib/x86_64-linux-gnu/libzstd.so.1.4.8',
                '--csv', str(prefix.with_suffix('.csv')),
                '--samples-json', str(prefix.with_suffix('.json'))]
        for case in sorted(corpus.iterdir()):
            args += ['--path', str(case)]
        subprocess.run(args, check=True)
        reports[role] = json.loads(prefix.with_suffix('.json').read_text())
    for before, after in zip(reports['baseline']['rows'], reports['variant']['rows'], strict=True):
        assert before['input_sha256'] == after['input_sha256']
        assert before['wires'] == after['wires'], (level, before['case'], before['wires'], after['wires'])
        checked.append(dict(level=level, case=before['case'], input_sha256=before['input_sha256'], wires=before['wires']))
(out / 'identity.json').write_text(json.dumps(dict(rows=checked, passed=True), indent=2) + '\n')
print('wire identity and cross-library roundtrip passed:', len(checked), flush=True)
