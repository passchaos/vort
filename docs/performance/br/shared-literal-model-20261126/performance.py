"""Verify complete fixed-lifecycle performance captures and recompute every CI."""
import json
from package_io import load,member,require,sha
from paired_statistics import close,geometric,mean,stratified,matrix_ci

ORIGIN='/tmp/vort-br-shared-literal-model-ab.p9wbbc7q'


def check_process(files,path,name,fixture,iterations,build,wire,control=None):
    key=member(path);raw=load(files,key);side=load(files,key.removesuffix('.json')+'.command.json')
    argv=side.get('argv',side.get('command'));opts=dict(zip(argv[4::2],argv[5::2]))
    require(side['exit_code']==0 and argv[:4]==['taskset','-c','2',build['executable_path']] and
            opts['--output']==path and opts['--input']==fixture['path'] and opts['--iterations']==str(iterations) and
            opts['--source-revision']==raw['source_revision'] and opts['--window']=='16','Process argv/exit differs')
    require(raw['input_path']==fixture['path'] and raw['input_sha256']==fixture['sha256'] and raw['input_bytes']==fixture['bytes'] and
            raw['allocator']=='std.process.Init.gpa' and raw['warmup_owned_encode_free_calls']==1 and
            raw['iterations']==iterations and len(raw['samples'])==iterations,'Input/allocating lifecycle differs')
    p=raw['provenance']
    require((p['optimize'],p['target_arch'],p['target_os'],p['target_abi'],p['target_cpu'],p['cpu_affinity'],p['affinity_cpu_count'],p['benchmark_threads'],p['codec_thread_policy'])==
            ('ReleaseFast','x86_64','linux','gnu','skylake+pku+sgx','2',1,1,'single') and p['executable_sha256']==build['executable_sha256'],
            'ELF/target/thread identity differs')
    require(raw['warm_wire_bytes']==wire['wire_bytes'] and raw['warm_wire_sha256']==wire['wire_sha256'],'Initial wire binding differs')
    if control:
        options=raw['actual_options'];require(options['mode']=='generic' and options['window_bits']==16 and opts['--control']==control,'Public control options differ')
        if control=='q4':require(options['quality']==4,'q4 policy differs')
        elif control=='q11':require(options['quality']==11 and options['command_state_max_input_kib']==8 and raw['command_state_limit_explicit'] is True,'q11 explicit8KiB cap differs')
        else:require(options['quality'] is None and options['level']=='ratio','Ratio strategy differs')
    else:require((raw['quality'],raw['mode'],raw['requested_window_bits'])==(8,'generic',16),'q8 field policy differs')
    for i,sample in enumerate(raw['samples']):
        require(type(sample['owned_encode_free_ns']) is int and sample['owned_encode_free_ns']>0 and sample['index']==i and
                sample['wire_bytes']==wire['wire_bytes'] and sample['mix']==(i+1)*wire['wire_bytes'],'Timed length/mix/raw differs')
    require(files[key.removesuffix('.json')+'.stdout']==files[key.removesuffix('.json')+'.stderr']==b'','Process stream output differs')
    if '--wire-output' in opts:
        actual=files[member(opts['--wire-output'])]
        require(len(actual)==wire['wire_bytes'] and sha(actual)==wire['wire_sha256'],'Saved complete initial wire differs')
    return raw,mean(s['owned_encode_free_ns'] for s in raw['samples'])


def full(files,settings,fixtures,builds,wires):
    saved=load(files,'summary.json');manifest=load(files,'run-manifest.json')
    require(manifest['phase']=='full' and 'completed' in manifest and manifest['settings']==settings,'Full terminal/settings differ')
    schedule=[(r,f['case']) for r in range(12) for f in fixtures if r<6 or f['case'] in ['dickens','mozilla','nci']]
    require([(p['round'],p['case']) for p in manifest['pairs']]==schedule and len(schedule)==90,'Full90 schedule differs')
    inputs={f['case']:f for f in fixtures};pairs=[];expected_files=set()
    for pair in manifest['pairs']:
        order=['old_exact','current'] if pair['round']%2==0 else ['current','old_exact']
        require(pair['order']==order and pair['lane']=='explicit16','Full order differs')
        times={}
        for name in order:
            path=pair['processes'][name]['path'];key=member(path)
            require(key==f"runs/explicit16-{pair['round']:02d}-{pair['case']}-{name}.json",'Full raw path differs')
            raw,elapsed=check_process(files,path,name,inputs[pair['case']],1,builds[name],wires[pair['case'],name])
            require(raw['source_revision']==settings['variants'][name] and pair['processes'][name]['raw_ns']==[elapsed],'Full source/ns binding differs')
            expected_files.update(key.removesuffix('.json')+'.'+extension for extension in ['json','command.json','stdout','stderr']);times[name]=elapsed
        pairs.append({'case':pair['case'],'round':pair['round'],'order':order,'ratio':times['current']/times['old_exact']})
    require({name for name in files if name.startswith('runs/')}==expected_files,'Full raw sidecar inventory differs')
    reports={r['case']:r for r in saved['rows']};rows=[]
    for case in inputs:
        selected=[p for p in pairs if p['case']==case];ratio=geometric(p['ratio'] for p in selected);ci=stratified(selected,case+'explicit16')
        primary=geometric(p['ratio'] for p in selected if p['round']<6);report=reports[case]
        close(ratio,report['paired_geomean_ns_current_over_old'],'full rowGM');close(primary,report['primary_six_round_paired_geomean'],'primary rowGM')
        for a,b in zip(ci,report['paired_ratio_bootstrap_95pct_ci'],strict=True):close(a,b,'full rowCI')
        rows.append({'case':case,'pairs':len(selected),'primary_speedup':1/primary,'all_pair_speedup':1/ratio,'all_pair_time_CI':ci,'floor_pass':1/ratio>=.98})
    ratio=geometric(p['ratio'] for p in pairs if p['round']<6);ci=matrix_ci(pairs);report=saved['matrix'][0]
    close(ratio,report['paired_geomean_ns_current_over_old'],'full primaryGM')
    for a,b in zip(ci,report['paired_round_block_bootstrap_95pct_ci'],strict=True):close(a,b,'full round-blockCI')
    speedup=1/ratio;speedci=[1/ci[1],1/ci[0]];gate=load(files,'gate-summary.json')
    close(speedup,gate['target_speedup_geomean'],'full gateGM')
    for a,b in zip(speedci,gate['target_paired_95CI'],strict=True):close(a,b,'full gateCI')
    passed=speedup>=1.03 and speedci[0]>1 and all(r['floor_pass'] for r in rows)
    require(gate['accepted']==passed,'Primary gate predicate differs')
    return {'pairs':90,'processes':180,'timed_calls':180,'independent_primary_speedup_GM':speedup,
            'independent_roundblock_95CI':speedci,'all12_row_floors':all(r['floor_pass'] for r in rows),'primary_gate_pass':passed,
            'rows':rows,'pilot_records_not_used':True}


def auxiliary(files,family,settings,fixtures,builds,wires,seeds,iterations):
    prefix='control' if family=='controls' else 'small';manifest=load(files,prefix+'-manifest.json');saved=load(files,prefix+'-summary.json')
    folder=prefix+'-runs';inputs={f['case']:f for f in fixtures};items=list(iterations) if family=='controls' else list(inputs)
    require('completed_unix' in manifest,'Auxiliary campaign not terminal')
    expected=[(r,item) for r in range(6) for item in items]
    require([(p['round'],p.get('control',p.get('case'))) for p in manifest['pairs']]==expected,'Auxiliary pair schedule differs')
    pairs=[];calls=0;expected_files=set()
    for pair in manifest['pairs']:
        item=pair.get('control',pair.get('case'));order=['old_exact','current'] if pair['round']%2==0 else ['current','old_exact']
        require(pair['order']==order,'Auxiliary AB/BA order differs');times={};actual_wires=[]
        for name in order:
            path=pair['processes'][name]['report'];key=member(path);require(key==f'{folder}/{pair["round"]:02d}-{item}-{name}.json','Auxiliary raw path differs')
            fixture=fixtures[0] if family=='controls' else inputs[item];count=iterations[item] if family=='controls' else iterations
            raw,elapsed=check_process(files,path,name,fixture,count,builds[name],wires[item,name],item if family=='controls' else None)
            require(raw['source_revision']==settings['variants'][name],'Auxiliary source revision differs');close(elapsed,pair['processes'][name]['per_call_mean_ns'],'all-call arithmetic mean')
            actual=files[member(pair['processes'][name]['wire'])];actual_wires.append(actual);times[name]=elapsed;calls+=count
            expected_files.update(key.removesuffix('.json')+'.'+extension for extension in ['json','command.json','stdout','stderr','br'])
        require(actual_wires[0]==actual_wires[1],'Auxiliary peer wire bytes differ');ratio=times['current']/times['old_exact'];close(ratio,pair['time_ratio'],'Auxiliary paired ratio')
        pairs.append({'item':item,'round':pair['round'],'order':order,'ratio':ratio})
    require({name for name in files if name.startswith(folder+'/')}==expected_files,'Auxiliary sidecar inventory differs')
    reported={r.get('control',r.get('case')):r for r in saved['rows']};rows=[]
    for item in items:
        selected=[p for p in pairs if p['item']==item];ratio=geometric(p['ratio'] for p in selected);ci=stratified(selected,seeds[item]);r=reported[item]
        close(ratio,r['candidate_over_baseline_time'],'Auxiliary GM')
        for a,b in zip(ci,r['time_95pct_ci'],strict=True):close(a,b,'Auxiliary CI')
        close(1/ratio,r['throughput_ratio'],'Auxiliary speedup')
        for a,b in zip([1/ci[1],1/ci[0]],r['throughput_95pct_ci'],strict=True):close(a,b,'Auxiliary speedupCI')
        require(r['passes_control_floor']==(1/ratio>=.98),'Reported auxiliary point floor differs')
        rows.append({'item':item,'speedup':1/ratio,'speedup_CI':[1/ci[1],1/ci[0]],'floor_pass':1/ratio>=.98})
    require(saved['all_controls_pass']==all(r['floor_pass'] for r in rows),'Auxiliary point-floor predicate differs')
    return {'pairs':len(pairs),'processes':2*len(pairs),'timed_calls':calls,'all_row_floors_pass':all(r['floor_pass'] for r in rows),'rows':rows}


def verify_performance(files):
    settings=load(files,'settings.json');fixtures=load(files,'fixtures.json');primary=load(files,'build-results.json')
    builds={name:{'executable_path':ORIGIN+'/bin/'+name,'executable_sha256':b['executable_sha256']} for name,b in primary.items()}
    pre=load(files,'preflight-summary.json');wires={(r['case'],r['variant']):r for r in pre['rows']}
    aux=load(files,'auxiliary-preflight-summary.json');cw={};sw={}
    for row in aux['rows']:
        for name,wire in row['sources'].items():(cw if row['family']=='controls' else sw)[(row['control'] if row['family']=='controls' else row['case'],name)]=wire
    aux_builds=load(files,'auxiliary-build-results.json')
    result={'full90':full(files,settings,fixtures,builds,wires),
            'public_controls':auxiliary(files,'controls',settings,[next(f for f in fixtures if f['case']=='mozilla')],{b['variant']:b for b in aux_builds if b['family']=='controls'},cw,{c:'control-'+c for c in ['q4','q11','ratio']},{'q4':100,'q11':1,'ratio':1}),
            'small4KiB_controls':auxiliary(files,'small-controls',settings,load(files,'small-controls/fixtures.json'),{b['variant']:b for b in aux_builds if b['family']=='small-controls'},sw,load(files,'small-plan.json')['seeds'],100)}
    independent=load(files,'full-controls-independent-verification.json')
    for family,actual in result.items():
        saved=independent[family]
        require(actual['pairs']==saved['pairs'] and actual['timed_calls']==saved['timed_calls'],'Independent family totals differ')
        for key,value in actual.items():
            if key!='rows' and isinstance(value,bool):require(saved[key]==value,'Independent family flags differ')
            elif key!='rows' and isinstance(value,float):close(value,saved[key],'Independent family estimate/CI')
            elif key!='rows' and isinstance(value,list):
                for a,b in zip(value,saved[key],strict=True):close(a,b,'Independent family confidence bounds')
        require(len(actual['rows'])==len(saved['rows']),'Independent row inventory differs')
        for a,b in zip(actual['rows'],saved['rows'],strict=True):
            for key,value in a.items():
                if isinstance(value,float):close(value,b[key],'Independent row estimate')
                elif isinstance(value,list):
                    for observed,recorded in zip(value,b[key],strict=True):close(observed,recorded,'Independent row confidence bounds')
                else:require(value==b[key],'Independent row fields differ')
    for path,digest in independent['raw_file_hashes'].items():require(sha(files[member(path)])==digest,'Independent raw digest differs')
    nci=next(r for r in result['small4KiB_controls']['rows'] if r['item']=='nci')
    require(nci['floor_pass'] and nci['speedup_CI'][0]<.98,'NCI small CI caveat was lost')
    result['small_NCI_CI_lower_below_floor']=True
    return result
