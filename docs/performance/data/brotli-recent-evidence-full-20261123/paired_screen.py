import json
import math
from pathlib import Path
import statistics
import subprocess
import sys

root = Path(__file__).parent
out = root / sys.argv[1]
out.mkdir(exist_ok=True)
pairs = int(sys.argv[2])
iterations = int(sys.argv[3])
candidate = sys.argv[4] if len(sys.argv) > 4 else 'variant'
corpus = Path('/home/passchaos/Work/corpora/silesia-20261025/files')
reference = Path('/home/passchaos/Work/brotli/build-vort')
groups = [(8192, sorted(p.name for p in corpus.iterdir())),
          (65536, ['dickens', 'mozilla', 'nci', 'x-ray'])]
rows = []
for limit, cases in groups:
    for quality in (10, 11):
        ratios = {case: [] for case in cases}
        for pair in range(pairs):
            reports = {}
            order = ('baseline', 'variant') if pair % 2 == 0 else ('variant', 'baseline')
            for role in order:
                prefix = out / f'{limit}-q{quality}-p{pair}-{role}'
                args = [str(root / (candidate if role == 'variant' else role)), '--planned-quality', str(quality),
                        '--quality', str(quality), '--command-state-max-input-kib=8',
                        '--window-bits', '16', '--reference-lgwin', '16',
                        '--reference-mode', 'generic', '--iterations', str(iterations),
                        '--limit', str(limit), '--csv', str(prefix.with_suffix('.csv')),
                        '--samples-json', str(prefix.with_suffix('.json')),
                        '--libbrotli-encoder', str(reference / 'libbrotlienc.so.1.2.0'),
                        '--libbrotli-decoder', str(reference / 'libbrotlidec.so.1.2.0'),
                        '--libbrotli-common', str(reference / 'libbrotlicommon.so.1.2.0')]
                for case in cases:
                    args += ['--path', str(corpus / case)]
                subprocess.run(args, check=True)
                reports[role] = json.loads(prefix.with_suffix('.json').read_text())
            for case, before, after in zip(cases, reports['baseline']['rows'], reports['variant']['rows'], strict=True):
                assert before['case'] == after['case']
                assert before['input_sha256'] == after['input_sha256']
                assert before['wires'] == after['wires'], (case, quality, limit)
                assert before['settings'] == after['settings']
                ratios[case].append(before['summary']['vort_median_ns'] / after['summary']['vort_median_ns'])
        for case, values in ratios.items():
            row = dict(case=case, limit=limit, quality=quality, pair_ratios=values,
                       speed_ratio=math.exp(statistics.mean(map(math.log, values))))
            rows.append(row)
            print(json.dumps(row), flush=True)
        (out / 'rows.json').write_text(json.dumps(rows, indent=2) + '\n')
summary = dict(pairs=pairs, iterations=iterations, rows=rows,
               target_geomean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows if r['limit'] == 8192)),
               control_geomean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows if r['limit'] == 65536)),
               all_geomean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows)),
               rows_below_098=sum(r['speed_ratio'] < .98 for r in rows))
(out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps({k: v for k, v in summary.items() if k != 'rows'}), flush=True)
