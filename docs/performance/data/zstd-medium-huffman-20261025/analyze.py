from pathlib import Path
import hashlib, json, statistics
base=Path('/tmp/vort-zstd-duplicate-profile-20261025')
def read(p): return json.loads(Path(p).read_text())
old=read(base/'public-old/samples.json')
new=read(base/'public-new/samples.json')
wire=read(base/'wire14/samples.json')
prior=read('/tmp/vort-zstd-literal-cost-20261025/quiet-final/candidate14.json')
labels={p['input_sha256']:p['label'] for p in read(base/'input-manifest.json')['input_sets']}
focus=[]
for a,b in zip(old['rows'],new['rows']):
    assert a['input_sha256']==b['input_sha256'] and a['settings']==b['settings']
    assert a['wires']==b['wires']
    times_a=[r['vort_ns'] for r in a['rounds']];times_b=[r['vort_ns'] for r in b['rounds']]
    old_ns=int(statistics.median(times_a));new_ns=int(statistics.median(times_b))
    assert old_ns==a['summary']['vort_median_ns'] and new_ns==b['summary']['vort_median_ns']
    reference_ns=int(statistics.median([r['reference_ns'] for r in b['rounds']]))
    focus.append({'label':labels[b['input_sha256']],'input_sha256':b['input_sha256'],
                  'old_median_ns':old_ns,'new_median_ns':new_ns,'reference_median_ns':reference_ns,
                  'version_speedup':old_ns/new_ns,'new_over_reference_throughput':reference_ns/new_ns,
                  'old_rounds_ns':times_a,'new_rounds_ns':times_b,'wires':b['wires']})
prior_rows={r['input_sha256']:r for r in prior['rows']}
assert len(wire['rows'])==14
checks=[]
for row in wire['rows']:
    before=prior_rows[row['input_sha256']]
    assert before['settings']==row['settings'] and before['wires']==row['wires']
    checks.append({'label':labels[row['input_sha256']],'input_sha256':row['input_sha256'],
                   'vort_bytes':row['wires']['vort_bytes'],'reference_bytes':row['wires']['reference_bytes'],
                   'vort_sha256':row['wires']['vort_sha256'],'wire_unchanged':True})
result={'code_head':'1764f21d','baseline_head':'c56c8255','focus':focus,'wire14':checks,
        'all14_wires_unchanged':True,'wire14_vort_total_bytes':sum(r['vort_bytes'] for r in checks),
        'wire14_reference_total_bytes':sum(r['reference_bytes'] for r in checks),
        'reference_identity':'requested libzstd1.6.0 file SHA; loader dependencies unverified',
        'scope':'Two 64KiB public-level3 workloads, five alternating Vort/reference rounds per executable in separate processes; version runs separated by completed checks. One-round 14-row run is a wire/correctness screen, not a stable ranking. No statistical significance or all-platform/memory claim.',
        'reference_sha256':hashlib.sha256(Path('/home/passchaos/Work/zstd/lib/obj/conf_5c583a1f84006a106cd7292ce5d65f11/dynamic/libzstd.so.1.6.0').read_bytes()).hexdigest()}
(base/'analysis.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
