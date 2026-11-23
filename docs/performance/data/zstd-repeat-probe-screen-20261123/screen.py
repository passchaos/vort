import json
import math
import statistics
import subprocess
import sys
from pathlib import Path

root = Path(__file__).parent
corpus = Path('/home/passchaos/Work/corpora/silesia-20261025/files')
out = root / sys.argv[1]
out.mkdir(exist_ok=True)
pairs = int(sys.argv[2])
cases = ['dickens', 'mozilla', 'nci', 'x-ray']
rows = []
for level in (1, 2, 3):
    values = {case: [] for case in cases}
    for pair in range(pairs):
        runs = {}
        order = ('baseline', 'variant') if pair % 2 == 0 else ('variant', 'baseline')
        for role in order:
            prefix = out / f'l{level}-p{pair}-{role}'
            args = [str(root / role), '--level', str(level), '--limit', '65536',
                    '--iterations', '10', '--rounds', '5', '--libzstd',
                    '/usr/lib/x86_64-linux-gnu/libzstd.so.1.4.8',
                    '--csv', str(prefix.with_suffix('.csv')),
                    '--samples-json', str(prefix.with_suffix('.json'))]
            for case in cases:
                args += ['--path', str(corpus / case)]
            subprocess.run(args, check=True)
            runs[role] = json.loads(prefix.with_suffix('.json').read_text())
        for case, before, after in zip(cases, runs['baseline']['rows'], runs['variant']['rows'], strict=True):
            assert before['input_sha256'] == after['input_sha256']
            assert before['wires'] == after['wires'], (level, before['case'], 'wire mismatch')
            values[case].append(before['summary']['vort_median_ns'] / after['summary']['vort_median_ns'])
    for case, ratios in values.items():
        result = dict(level=level, case=case, pairs=ratios,
                      speed_ratio=math.exp(statistics.mean(map(math.log, ratios))))
        rows.append(result)
        print(json.dumps(result), flush=True)
summary = dict(rows=rows, geometric_mean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows)))
(out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print('geometric mean', summary['geometric_mean'], flush=True)
