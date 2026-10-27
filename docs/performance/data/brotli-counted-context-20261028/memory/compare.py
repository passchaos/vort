import json, pathlib, hashlib
out=pathlib.Path(__file__).parent
old=json.loads((out/'baseline-memory.json').read_text())
new=json.loads((out/'candidate-memory.json').read_text())
assert len(old['rows'])==len(new['rows'])==4
rows=[]
for a,b in zip(old['rows'],new['rows']):
    assert a['input_sha256']==b['input_sha256']
    assert a['input_bytes']==b['input_bytes']
    assert len(a['passes'])==len(b['passes'])==6
    for report in [a,b]:
        for i,p in enumerate(report['passes']):
            s=p['summary']
            assert s['memory_profile']['peak_requested_bytes']==s['peak_requested_bytes']
            assert s['memory_profile']['live_requested_bytes']==s['live_after_caller_free']==0
            assert s['allocated_bytes']==s['freed_bytes']
            assert len(p['ledger'])==s['alloc_attempts']+s['resize_attempts']+s['remap_attempts']+s['free_calls']
            assert s['live_after_return']==(s['wire_bytes'] or 0)
            if i<4:
                assert s['error_name'] is None and s['wire_equal']
                assert s['wire_bytes']==report['passes'][0]['summary']['wire_bytes']
                assert s['wire_sha256']==report['passes'][0]['summary']['wire_sha256']
            else:
                assert s['error_name']=='WorkingMemoryLimitExceeded'
            if s['kind']=='profile':
                assert p['linked_emission_count']==len(p['linked_emissions'])
                for e in p['linked_emissions']:
                    if e['wire_bytes'] is not None:
                        assert e['wire_bytes']==e['evaluated_wire_bytes']
        assert report['passes'][0]['ledger']==report['passes'][1]['ledger']==report['passes'][2]['ledger']==report['passes'][3]['ledger']
        assert report['passes'][4]['ledger']==report['passes'][5]['ledger']
    sa=a['passes'][0]['summary'];sb=b['passes'][0]['summary']
    assert sa['wire_bytes']==sb['wire_bytes'] and sa['wire_sha256']==sb['wire_sha256']
    pa=a['passes'][1];pb=b['passes'][1]
    rows.append({'path':a['path'],'input_bytes':a['input_bytes'],'input_sha256':a['input_sha256'],'wire_bytes':sa['wire_bytes'],'wire_sha256':sa['wire_sha256'],'baseline_peak':sa['peak_requested_bytes'],'candidate_peak':sb['peak_requested_bytes'],'peak_change_bytes':sb['peak_requested_bytes']-sa['peak_requested_bytes'],'baseline_alloc_resize_remap':[sa[x] for x in ['alloc_attempts','resize_attempts','remap_attempts']],'candidate_alloc_resize_remap':[sb[x] for x in ['alloc_attempts','resize_attempts','remap_attempts']],'baseline_wire_attempts':pa['candidate_profile']['wire_attempts'],'candidate_wire_attempts':pb['candidate_profile']['wire_attempts'],'baseline_evaluation_attempts':pa['candidate_profile']['evaluation_attempts'],'candidate_evaluation_attempts':pb['candidate_profile']['evaluation_attempts'],'baseline_linked_emissions':pa['linked_emission_count'],'candidate_linked_emissions':pb['linked_emission_count'],'wire_equal':True,'ordinary_profile_and_cap_ledger_checks':True,'all_cleanup_verified':True})
result={'schema':'vort.brotli.q8-candidate-memory-comparison.v1','measurement':'requested_encoder_owned_heap_only','baseline_profile_state_bytes':old['profile_state_bytes'],'candidate_profile_state_bytes':new['profile_state_bytes'],'rows':rows,'artifacts_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in [out/'baseline-probe',out/'candidate-probe',out/'baseline-memory.json',out/'candidate-memory.json']}}
(out/'comparison.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
