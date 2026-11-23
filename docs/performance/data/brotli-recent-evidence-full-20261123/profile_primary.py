import collections
import json
from pathlib import Path
import re

root = Path(__file__).parent
text = (root / 'q10-perf-script.txt').read_text()
header = re.compile(r'^\S+\s+\d+\s+[0-9.]+:\s+(\d+)\s+cycles:P:')
all_count = all_period = selected_count = selected_period = 0
leaves = collections.Counter()
inclusive = collections.Counter()
chains = collections.Counter()
for block in text.split('\n\n'):
    lines = block.splitlines()
    if not lines:
        continue
    match = header.match(lines[0].strip())
    if not match:
        continue
    period = int(match[1])
    symbols = [line.strip().split(' ', 1)[1].rsplit(' (', 1)[0].strip()
               for line in lines[1:] if line.strip() and ' ' in line.strip()]
    all_count += 1
    all_period += period
    if not any('planned_encode_bench.measureVort' in s for s in symbols) or not any(
            s.startswith('br.encodePlannedStreamQualityWithOptionsAllocRecorded') for s in symbols):
        continue
    selected_count += 1
    selected_period += period
    normalized = [re.sub(r'__anon_\d+', '', s) for s in symbols]
    if normalized:
        leaves[normalized[0]] += period
    for symbol in set(normalized):
        inclusive[symbol] += period
    if any('context_candidate_group.encodePreparedPrimary' in s for s in symbols):
        chains['prepared_context'] += period
    elif any('br.encodePreferredCommandPlanAllocRecorded' in s for s in symbols):
        chains['legacy_preferred_context'] += period
    else:
        chains['other'] += period
assert all_count == 13895 and selected_count == 10552
assert selected_period == 12919026601
report = dict(schema='vort.brotli.primary-quality-profile.v1',
              scope='AND of measureVort and quality-preset encode call chains; includes untimed per-round warmup; routing evidence, not throughput',
              all_samples=all_count, all_period_cycles=all_period,
              selected_samples=selected_count, selected_period_cycles=selected_period,
              primary_self=[dict(symbol=s, period_cycles=n, fraction=n/selected_period)
                            for s, n in leaves.most_common(25)],
              primary_inclusive=[dict(symbol=s, period_cycles=n, fraction=n/selected_period)
                                 for s, n in inclusive.most_common(40)],
              chain_fractions={s: n/selected_period for s, n in chains.items()})
(root / 'q10-primary-profile.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k not in ('primary_self', 'primary_inclusive')}, indent=2))
print(json.dumps(report['primary_self'][:10], indent=2))
