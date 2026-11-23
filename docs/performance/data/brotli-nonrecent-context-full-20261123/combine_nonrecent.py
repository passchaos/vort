import json
import math
from pathlib import Path
import statistics

root = Path(__file__).parent
pilot = json.loads((root / 'nonrecent-pilot/summary.json').read_text())
extra = json.loads((root / 'nonrecent-extra/summary.json').read_text())
rows = pilot['rows'] + extra['rows']
for row in pilot['rows']:
    row['sample_batch'] = f"nonrecent-pilot-{row['limit']}-q{row['quality']}"
keys = {(r['case'], r['limit'], r['quality']) for r in rows}
assert len(rows) == len(keys) == 72
for limit in (4096, 8192, 65536):
    for quality in (10, 11):
        assert sum(r['limit'] == limit and r['quality'] == quality for r in rows) == 12
assert pilot['pairs'] == extra['pairs'] == 3
assert pilot['iterations'] == extra['iterations'] == 3
out = dict(schema='vort.brotli.nonrecent-full-corpus-paired.v1',
           pairs=3, iterations=3, target_limits=[8192, 65536], control_limits=[4096],
           rows=rows, target_rows=48, control_rows=24,
           target_geomean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows if r['limit'] >= 8192)),
           control_geomean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows if r['limit'] == 4096)),
           all_geomean=math.exp(statistics.mean(math.log(r['speed_ratio']) for r in rows)),
           rows_below_098=sum(r['speed_ratio'] < .98 for r in rows),
           sample_sources=['nonrecent-pilot', 'nonrecent-extra'],
           scope_reason='Source preparation gate is input>=8KiB; prior recent-cache pilot labels are retained separately. Full targets+unaffected4KiBcontrols frozen before expansion decision.')
(root / 'nonrecent-combined-summary.json').write_text(json.dumps(out, indent=2) + '\n')
print(json.dumps({k: v for k, v in out.items() if k != 'rows'}))
