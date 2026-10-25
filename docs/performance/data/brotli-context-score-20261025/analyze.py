from pathlib import Path
import json, math, statistics
base=Path('/tmp/vort-brotli-context-cache-20261025')
old=json.loads((base/'baseline14/samples.json').read_text());new=json.loads((base/'public14/samples.json').read_text())
assert len(old['rows'])==len(new['rows'])==14
prior={r['input_sha256']:r for r in old['rows']}
assert len(prior)==14 and {r['input_sha256'] for r in new['rows']}==set(prior)
assert all(len(r['rounds'])==5 for report in (old,new) for r in report['rows'])
rows=[]
for r in new['rows']:
 b=prior[r['input_sha256']]
 assert r['wires']==b['wires'] and r['settings']==b['settings']
 a=statistics.median(x['vort_ns'] for x in b['rounds']);n=statistics.median(x['vort_ns'] for x in r['rounds']);ref=statistics.median(x['reference_ns'] for x in r['rounds'])
 rows.append(dict(case=r['case'],input_sha256=r['input_sha256'],old_median_ns=a,new_median_ns=n,reference_median_ns=ref,version_speedup=a/n,throughput_reference_ratio=ref/n,wires=r['wires']))
profile=json.loads((base/'profile14/samples.json').read_text())
oldprofile=json.loads(Path('/tmp/vort-brotli-q8-profile-20261025/profile14/samples.json').read_text());pprior={r['input_sha256']:r for r in oldprofile['rows']}
assert len(profile['rows'])==len(oldprofile['rows'])==len(pprior)==14
assert {r['input_sha256'] for r in profile['rows']}==set(pprior)
assert all(len(r['rounds'])==5 for report in (profile,oldprofile) for r in report['rows'])
profile_rows=[]
FIELDS=('stage','origin','variant','input_bytes','command_count','wire_bytes','error_name','accepted','gain_bytes','incumbent_bytes','config')
def candidates(p):return [{k:e[k] for k in FIELDS} for e in p['events'] if e['stage'] in ('wire','selection')]
for r in profile['rows']:
 ps=[x['profile'] for x in r['rounds']]; b=pprior[r['input_sha256']]
 for sample,original in zip(r['rounds'],b['rounds']):assert candidates(sample['profile'])==candidates(original['profile'])
 keys=ps[0]['exclusive_ns'];stages={k:statistics.median(p['exclusive_ns'][k] for p in ps) for k in keys}
 shape=None
 for p in ps:
  current=[{k:v for k,v in d.items() if k!='profile'}|{'shape':{k:v for k,v in d['profile'].items() if not k.endswith('_ns')}} for d in p['context_details']]
  if shape is None:shape=current
  else:assert shape==current
 details=[]
 for index in range(len(ps[0]['context_details'])):
  samples=[p['context_details'][index] for p in ps]; stats=[d['profile'] for d in samples]
  row=dict(origin=samples[0]['origin'],variant=samples[0]['variant'],command_count=samples[0]['command_count'],counts={k:v for k,v in stats[0].items() if not k.endswith('_ns')},time_medians_ns={k:statistics.median(s[k] for s in stats) for k in stats[0] if k.endswith('_ns') and k!='mode_ns'},mode_medians_ns=[statistics.median(s['mode_ns'][i] for s in stats) for i in range(4)])
  details.append(row)
 profile_rows.append(dict(path=r['path'],input_sha256=r['input_sha256'],outer_median_ns=statistics.median(p['outer_elapsed_ns'] for p in ps),stage_medians_ns=stages,context_details=details,all_old_wire_candidates_and_decisions_equal=True))
report=dict(public=dict(rows=rows,version_throughput_geomean=math.exp(statistics.mean(math.log(r['version_speedup']) for r in rows)),throughput_reference_geomean=math.exp(statistics.mean(math.log(r['throughput_reference_ratio']) for r in rows)),version_point_wins=sum(r['version_speedup']>1 for r in rows),reference_point_wins=sum(r['throughput_reference_ratio']>1 for r in rows),all_old_wires_and_settings_equal=True),profile=dict(rows=profile_rows,runs=sum(len(r['rounds']) for r in profile['rows']),all_old_wire_candidates_and_decisions_equal=True),scope='Fixed 64KiB q8 generic default-policy, one version process each with five rounds; medians are separate and nonadditive. Profile timings are instrumented, not ordinary competitor throughput.')
(base/'analysis.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:v for k,v in report['public'].items() if k!='rows'}))
for r in rows:print(r['case'],round(r['version_speedup'],6),round(r['new_median_ns']/1e6,4))
