import json
import math
from pathlib import Path
import random
import statistics
import sys

path = Path(sys.argv[1])
summary = json.loads(path.read_text())
generator = random.Random(20261123)
for name, limit in [('target', 8192), ('control', 65536)]:
    groups = [[r for r in summary['rows'] if r['limit'] == limit and r['quality'] == q]
              for q in (10, 11)]
    samples = []
    for _ in range(10000):
        values = []
        for group in groups:
            indices = [generator.randrange(summary['pairs']) for _ in range(summary['pairs'])]
            values += [statistics.mean(math.log(r['pair_ratios'][i]) for i in indices)
                       for r in group]
        samples.append(math.exp(statistics.mean(values)))
    samples.sort()
    summary[name + '_block_bootstrap_ci95'] = [samples[249], samples[9749]]
summary['ci_scope'] = 'fixed corpus, resample process-pair blocks separately by quality; 10000 seeded bootstrap draws'
summary['adoption_gate'] = {
    'target_geomean_at_least_103': summary['target_geomean'] >= 1.03,
    'target_ci_excludes_parity': summary['target_block_bootstrap_ci95'][0] > 1,
    'every_row_at_least_098': summary['rows_below_098'] == 0,
}
path.write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps({k: v for k, v in summary.items() if k != 'rows'}))
