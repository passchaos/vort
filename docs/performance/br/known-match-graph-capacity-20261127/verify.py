#!/usr/bin/env python3
"""Independent conservation and provenance checks, without running producer."""
import json,math
from pathlib import Path
from package_io import load,read_packages,read_tar,require,sha


def verify_data(evidence,sources):
    freeze=load(evidence,'source-freeze.json');policy=load(evidence,'policy.json')
    require(freeze['head']==policy['source_head']=='92204434b194bd4e87cf6349cbd6bfaac64ea5da' and
            freeze['source_tar_sha256']==sha(sources['source.tar']) and
            freeze['source_manifest_sha256']==sha(evidence['source-files.json']),'Frozen source identity differs')
    tree=read_tar(sources['source.tar'],'r:',directories=True);registry=load(evidence,'source-files.json')
    require(len(tree)==len(registry)==freeze['source_file_count']==2220 and {r['path'] for r in registry}==set(tree),'Complete source inventory differs')
    for r in registry:require(len(tree[r['path']])==r['bytes'] and sha(tree[r['path']])==r['sha256'],'Source member differs')
    for r in load(evidence,'artifact-manifest.json'):
        require(len(evidence[r['path']])==r['bytes'] and sha(evidence[r['path']])==r['sha256'],'Original artifact fingerprint differs')
    require(policy['max_chain']==128 and policy['window']==32768 and policy['minimum_match']==4 and
            policy['maximum_match']==258 and policy['valid_candidate_budget']==64 and policy['nice_length']==192 and
            policy['no_price_pruning'] is True and policy['unknown_lengths']==0 and
            policy['retain_equal_and_shorter_matches_at_distinct_distances'] is True,'Original edge-admission policy differs')
    fixtures=load(evidence,'fixtures.json');raw=[json.loads(line) for line in evidence['runtime.stderr'].splitlines()]
    summary=load(evidence,'summary.json');require(len(fixtures)==len(raw)==len(summary['rows'])==12,'Complete12-row raw matrix differs')
    original='/tmp/vort-q8-known-lz-edge-count._17xaqey/'
    for r,f,s in zip(raw,fixtures,summary['rows'],strict=True):
        require(f['path'].startswith(original),'Captured fixture outside frozen root')
        data=evidence[f['path'].removeprefix(original)]
        require(len(data)==f['bytes']==r['input_bytes']==65536 and sha(data)==f['sha256']==s['input_sha256'] and r['case']==f['case']==s['case'],'Input/raw identity differs')
        require(all(type(v) is int and v>=0 for k,v in r.items() if k not in ['case','run_operations_by_count']),'Invalid raw count')
        h=r['run_operations_by_count'];require(len(h)==65 and all(type(n) is int and n>=0 for n in h),'Invalid complete run histogram')
        require(r['empty_rows']+r['nonempty_rows']==r['input_bytes'] and r['max_edges_per_row']<=64,'Row/candidate budget differs')
        require(sum(h)==r['run_operations'] and r['raw_operations']+sum(i*n for i,n in enumerate(h))==r['actual_edges'],'Edge/run count conservation differs')
        require(r['raw_edge_bytes']==4*r['actual_edges'] and r['run_payload_bytes']==4*r['raw_operations']+8*r['run_operations'] and
                r['run_payload_bytes']<=r['raw_edge_bytes'],'Raw/run payload geometry differs')
        require(r['u32_offsets_bytes']==4*(r['input_bytes']+1) and r['raw_graph_bytes']==r['raw_edge_bytes']+r['u32_offsets_bytes'] and
                r['run_graph_bytes']==r['run_payload_bytes']+r['u32_offsets_bytes'],'Offset/graph estimate conservation differs')
        require(all(s[k]==v for k,v in r.items()),'Summary raw fields differ')
        for field,expected in [('graph_raw_bytes_per_input_byte',r['raw_graph_bytes']/r['input_bytes']),
                               ('graph_run_bytes_per_input_byte',r['run_graph_bytes']/r['input_bytes']),
                               ('run_fraction_of_raw_graph',r['run_graph_bytes']/r['raw_graph_bytes'])]:
            require(math.isclose(s[field],expected,rel_tol=1e-12,abs_tol=1e-12),'Summary derived fraction differs')
    aggregate={field:sum(r[field] for r in raw) for field in summary['aggregate']}
    require(aggregate==summary['aggregate'] and aggregate['actual_edges']==15261027 and
            aggregate['raw_graph_bytes']==64189884 and aggregate['run_graph_bytes']==52750076,'Independent aggregate capacity sums differ')
    require(load(evidence,'build.exit.json')['exit_code']==load(evidence,'runtime.exit.json')['exit_code']==0,'Original build/count terminal differs')
    require(evidence['build.stderr']==evidence['build.stdout']==evidence['runtime.stdout']==b'' and
            load(evidence,'compiler-host.json')['timing_measured'] is False and policy['timing_or_throughput']=='not measured','Untimed scope differs')
    return {'rows':12,'source_files':2220,'edges':aggregate['actual_edges'],'raw_graph_estimate_sum_bytes':aggregate['raw_graph_bytes'],
            'run_graph_estimate_sum_bytes':aggregate['run_graph_bytes'],'original_build_exit':0,'original_count_exit':0,
            'capacity_scope':'Sum of12 independent input estimates; excludes owner/index/bookkeeping/remap overhead, not simultaneous peak',
            'complete_graph_allocated':False,'codec_or_timing_executed_by_verifier':False,'throughput_measured':False,
            'implementation':'Direct full graph rejected before implementation because of memory growth risk; run representation remains an abstract opportunity',
            'historical_q8_elapsed_regression_repaired':False}


def verify(root):
    p,binding=read_packages(root);result=verify_data(p['evidence.tar.gz'],p['sources.tar.gz'])
    return {'schema':'vort.brotli.known-match-graph-capacity.offline-verification.v1','verified':True,'data':result,
            'archive_members':{name:len(v) for name,v in binding['members'].items()},
            'scope':'Package bytes only; no producer import, helper/binary execution, codec, build, foreign library or timing'}


if __name__=='__main__':print(json.dumps(verify(Path(__file__).resolve().parent),indent=2,sort_keys=True))
