from pathlib import Path
import json,math,statistics
base=Path('/tmp/vort-br-tree-cost-20261025');old=json.loads(base.joinpath('baseline14/samples.json').read_text());new=json.loads(base.joinpath('public14/samples.json').read_text());prior={r['input_sha256']:r for r in old['rows']};assert len(prior)==len(new['rows'])==14 and {r['input_sha256'] for r in new['rows']}==set(prior)
rows=[]
for r in new['rows']:
 a=prior[r['input_sha256']];assert len(a['rounds'])==len(r['rounds'])==5;assert a['settings']==r['settings'] and a['wires']==r['wires']
 om=statistics.median(x['vort_ns'] for x in a['rounds']);nm=statistics.median(x['vort_ns'] for x in r['rounds']);rm=statistics.median(x['reference_ns'] for x in r['rounds']);rows.append(dict(case=r['case'],input_sha256=r['input_sha256'],old_median_ns=om,new_median_ns=nm,reference_median_ns=rm,version_speedup=om/nm,throughput_reference_ratio=rm/nm,wires=r['wires']))
report=dict(public=dict(rows=rows,version_geomean=math.exp(statistics.mean(math.log(r['version_speedup']) for r in rows)),reference_geomean=math.exp(statistics.mean(math.log(r['throughput_reference_ratio']) for r in rows)),version_point_wins=sum(r['version_speedup']>1 for r in rows),reference_point_wins=sum(r['throughput_reference_ratio']>1 for r in rows),all_old_settings_wires_equal=True),scope='f642d0d8 vs dense Huffman candidate, fixed64KiB q8/generic ordinary public interface, five alternating reference rounds each; no all-quality/platform/statistical significance claim.')
if base.joinpath('profile14/samples.json').exists():
 profile=json.loads(base.joinpath('profile14/samples.json').read_text());original=json.loads(Path('/tmp/vort-brotli-context-cache-20261025/restored-profile14/samples.json').read_text());prior={r['input_sha256']:r for r in original['rows']};assert len(profile['rows'])==len(prior)==14 and {r['input_sha256'] for r in profile['rows']}==set(prior)
 fields=['stage','origin','variant','input_bytes','command_count','wire_bytes','error_name','accepted','gain_bytes','incumbent_bytes','config'];sem=lambda p:[{k:e[k] for k in fields} for e in p['events'] if e['stage'] in ('wire','selection')]
 preserve_fields=['suffix_tree_count','suffix_mode','suffix_savings_bits','up_to_16_tree_count','up_to_16_mode','up_to_16_savings_bits','full_tree_count','full_mode','full_savings_bits','suffix_payload_scores','suffix_payload_reuses','cluster_trials','cluster_rounds','assignment_contexts','assignment_comparisons','score_cache_hits','score_cache_misses','tree_score_cache_hits','tree_score_cache_misses','tree_score_calls','tree_score_uncached_calls','tree_score_uncached_scope_calls','tree_score_uncached_mode_calls','tree_active_entries','tree_active_buckets']
 prows=[]
 for r in profile['rows']:
  oldr=prior[r['input_sha256']];assert len(r['rounds'])==len(oldr['rounds'])==5
  for a,b in zip(r['rounds'],oldr['rounds']):
   assert sem(a['profile'])==sem(b['profile']);newd=a['profile']['context_details'];oldd=b['profile']['context_details'];assert len(newd)==len(oldd)
   for nd,od in zip(newd,oldd):
    ns=nd['profile'];os=od['profile'];assert all(ns[f]==os[f] for f in preserve_fields)
    assert ns['small_huffman_calls']==sum(ns['tree_active_buckets'][1:]) and ns['package_merge_calls']==ns['small_huffman_failures']
  p=[x['profile'] for x in r['rounds']];details=[]
  for i,d in enumerate(p[0]['context_details']):
   ds=[x['context_details'][i]['profile'] for x in p];details.append(dict(origin=d['origin'],command_count=d['command_count'],small_calls=ds[0]['small_huffman_calls'],fallback_calls=ds[0]['package_merge_calls'],active_buckets=ds[0]['tree_active_buckets'],tree_lengths_median_ns=statistics.median(x['tree_lengths_ns'] for x in ds),tree_lengths_old_median_ns=statistics.median(x['profile']['context_details'][i]['profile']['tree_lengths_ns'] for x in oldr['rounds'])))
  prows.append(dict(path=r['path'],stage_medians_ns={k:statistics.median(x['exclusive_ns'][k] for x in p) for k in p[0]['exclusive_ns']},outer_median_ns=statistics.median(x['outer_elapsed_ns'] for x in p),context_details=details))
 report['profile']=dict(rows=prows,all_old_candidates_and_decisions_equal=True,actual_tree_and_search_work_unchanged=True,new_dispatch_counters_valid=True,runs=70,scope='Instrumented same search/scorer requests, only Huffman construction changes. Nested separate stage medians are nonadditive; profiler clocks cannot prove ordinary speed.')
base.joinpath('analysis.json').write_text(json.dumps(report,indent=2)+'\n');print({k:v for k,v in report['public'].items() if k!='rows'})
for r in rows:print(r['case'],round(r['version_speedup'],6),round(r['new_median_ns']/1e6,3))
