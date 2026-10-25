from pathlib import Path
import json,statistics,hashlib,math
base=Path('/tmp/vort-brotli-q8-profile-20261025')
data=json.loads((base/'profile14/samples.json').read_text())
normal=json.loads((base/'public14/samples.json').read_text())
old=json.loads((base/'baseline14/samples.json').read_text())
oldrows={r['input_sha256']:r for r in old['rows']}
labels={p['input_sha256']:p['label'] for p in json.loads(Path('/tmp/vort-current-encode-baseline-20261025/preparation.json').read_text())['selected_inputs']}
rows=[]
for row in data['rows']:
 profiles=[r['profile'] for r in row['rounds']]
 assert all(p['timing_complete'] and not p['events_truncated'] for p in profiles)
 stages={key:int(statistics.median(p['exclusive_ns'][key] for p in profiles)) for key in profiles[0]['exclusive_ns']}
 outer=int(statistics.median(p['outer_elapsed_ns'] for p in profiles))
 origins={}
 for origin in ('lazy','optimal','other'):
  origins[origin]={'wire_attempts':[sum(e['stage']=='wire' and e['origin']==origin for e in p['events']) for p in profiles],
                   'wire_median_ns':int(statistics.median(sum(e['exclusive_ns'] for e in p['events'] if e['stage']=='wire' and e['origin']==origin) for p in profiles))}
 preferred_fraction=statistics.median(p['exclusive_ns']['preferred_context']/p['outer_elapsed_ns'] for p in profiles)
 # Stage medians are descriptive across independent rounds: their sum need
 # not equal the median total. Raw-round gate validates each exact partition.
 rows.append({'input':labels[row['input_sha256']],'input_sha256':row['input_sha256'],'wire_sha256':row['wire_sha256'],'wire_bytes':row['wire_bytes'],
              'outer_median_ns':outer,'normal_in_profile_tool_median_ns':int(statistics.median(r['normal_ns'] for r in row['rounds'])),
              'stage_medians_ns':stages,'wire_attempts_per_round':[p['wire_attempts'] for p in profiles],
              'origin_wire':origins,'preferred_context_fraction_median':preferred_fraction,
              'classified_fraction_by_round':[(sum(p['exclusive_ns'].values())-p['exclusive_ns']['other'])/p['outer_elapsed_ns'] for p in profiles],
              'scope':'Instrumented q8 stages; classified non-other fraction excludes unaccounted. No independent stage-median sum claim.'})
ordinary=[]
for row in normal['rows']:
 prior=oldrows[row['input_sha256']]
 assert row['wires']==prior['wires'] and row['settings']==prior['settings']
 ordinary.append({'input':labels[row['input_sha256']],'old_ns':prior['summary']['vort_median_ns'],'new_ns':row['summary']['vort_median_ns'],
                  'version_ratio':prior['summary']['vort_median_ns']/row['summary']['vort_median_ns'],
                  'new_over_reference_throughput':row['summary']['reference_median_ns']/row['summary']['vort_median_ns'],
                  'output_equal':True,'wires':row['wires']})
report={'profile_rows':rows,'ordinary_rows':ordinary,
        'ordinary_version_ratio_geomean':math.exp(sum(math.log(r['version_ratio']) for r in ordinary)/len(ordinary)),
        'ordinary_over_reference_geomean':math.exp(sum(math.log(r['new_over_reference_throughput']) for r in ordinary)/len(ordinary)),
        'scope':'Instrumented stages are separated from ordinary public Vort/reference timing. Raw-round event gate proves nonoverlap; stage medians are descriptive, not additive. Same-process-five-round controls are not a repeated-process significance or all-platform ranking.'}
(base/'analysis.json').write_text(json.dumps(report,indent=2)+'\n')
for row in rows:
 if row['input'] in ('silesia-mozilla','brotli-source'):
  print(json.dumps(row,indent=2))
print(json.dumps({k:v for k,v in report.items() if k not in ('profile_rows','ordinary_rows')}))
