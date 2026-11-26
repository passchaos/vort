"""Verify frozen global source, recovered combined results and resource scope."""
import json,re
from package_io import load, require, sha


def resource_rows(text):
    records=[]
    for line in text.splitlines():
        start=line.find('final_entropy_bound_resource ')
        if start<0:continue
        # WASI runner may append the first debug record to its test-name line.
        row={key:value for key,value in (token.split('=',1) for token in line[start:].split()[1:])}
        for key,value in list(row.items()):
            if value.isdigit():row[key]=int(value)
            elif value=='null':row[key]=None
        records.append(row)
    return records


def verify_provenance(sources,bench,validation):
    inventory=load(sources,'source-inventory.json')
    trees={label:{name.removeprefix(label+'/'):data for name,data in sources.items() if name.startswith(label+'/')}
           for label in ['baseline','current']}
    require(len(trees['baseline'])==2992 and len(trees['current'])==3127,'Global full compile closure counts differ')
    for label,tree in trees.items():
        require({name:{'bytes':len(data),'sha256':sha(data)} for name,data in tree.items()}==inventory[label],
                'Frozen compile source bytes differ')
    for label,filename,count in [('baseline','baseline-source-files.json',2200),('current','candidate-source-files.json',2211)]:
        actual={name:sha(data) for name,data in trees[label].items() if name.startswith('src/')}
        require(len(actual)==count and actual==load(bench,filename),'Frozen src registry differs')
    freeze=load(validation,'SOURCEFREEZE');root_source=load(validation,'final-source.json')
    require(root_source==load(bench,'candidate-source-files.json') and len(root_source)==2211 and
            sha(validation['final-source.json'])==freeze['source_manifest_sha256']==
            load(bench,'candidate-source-binding.json')['root_manifest_sha256'] and
            bench['SOURCEFREEZE']==validation['SOURCEFREEZE'],'Authoritative global source/marker differs')
    require(freeze['source_manifest_sha256']=='4cd88fda7a97f8e9b9bbc81fc93ef18711965f31b80dd1136334b1374286c78f',
            'Local or later source epoch entered global package')
    independent=load(bench,'pilot-independent-verification.json')
    for label,name in [('baseline','old_exact'),('current','current')]:
        actual={path:sha(data) for path,data in trees[label].items() if path.startswith('src/')}
        content_sha=sha(json.dumps(actual,sort_keys=True,separators=(',',':')).encode())
        report=independent['source_bindings'][name]
        require(report['before_content_manifest_sha256']==report['after_content_manifest_sha256']==content_sha,
                'Original independent source before/after content proof differs')
    for name,record in load(bench,'artifact-bindings.json')['files'].items():
        if name.startswith('sources/old_exact/'):data=trees['baseline'][name.removeprefix('sources/old_exact/')]
        elif name.startswith('sources/current/'):data=trees['current'][name.removeprefix('sources/current/')]
        else:data=bench[name]
        require(len(data)==record['bytes'] and sha(data)==record['sha256'],'Global artifact identity differs: '+name)
    for name,record in load(bench,'harness-bindings.json')['files'].items():
        require(len(bench[name])==record['bytes'] and sha(bench[name])==record['sha256'],'Frozen global harness differs')
    settings=load(bench,'settings.json');policy=load(bench,'policy-frozen.json')
    require({key:value for key,value in settings.items() if key!='variants'}==policy['settings_without_variants'] and
            settings['variants']['old_exact']==policy['baseline_source_commit']=='cf442dee0144f4c0cc1823474f77c7e8b1685f2e' and
            settings['variants']['current']=='cf-global-entropy-bound:'+freeze['source_manifest_sha256'],'Global source roles/policy differ')
    builds=load(bench,'build-results.json')
    for label,build in builds.items():
        require(build['success'] is True and build['revision']==settings['variants'][label] and
                build['executable_sha256']==sha(bench['bin/'+label]) and build['stages']==load(bench,'build/'+label+'.json') and
                all(stage['exit_code']==0 for stage in build['stages']),'Global build/ELF terminal differs')
    reused=load(bench,'build/baseline-reuse.json')
    require(reused['actual_build_receipt_sha256']==sha(bench['build/old_exact.json']) and
            reused['copied_baseline_ELF_sha256']==sha(bench['bin/old_exact']) and
            reused['copied_own_record_sha256']==sha(bench['build/old_exact-record.o']) and
            reused['actual_object_source_sha256']==sha(trees['baseline']['src/br/encoder/record_optimal_object.zig']),
            'Reused CF source/object/ELF provenance differs')
    br=trees['current']['src/br.zig'].decode()
    eligibility=br[br.index('const disabled_bound ='):br.index('optimal_wire_options.final_entropy_bound =')]
    require('schedule.quality == .q8' in eligibility and 'command_state_ceiling == 0' in eligibility and
            'hasSerializedStatic' in eligibility and 'use_static_dictionary' not in eligibility and
            'command.hq_encoding != null or command.isCompound()' in br and
            "q8's input-dependent RFC dictionary matches are part of the fixed" in br,'Frozen RFC-static eligibility correction missing')
    stash=load(validation,'stash-verification.json');before=load(validation,'live-before-stash-verification.json')
    require(stash['stash']=='5e431ffff10d57fc576c97f49d1fbb5ea330cf58' and stash['saved_git_files']==2210 and
            stash['frozen_files']==2211 and stash['git_stash_plus_ignored_assets_matches_frozen'] is True and
            stash['restored_tracked_and_untracked_production_matches_head'] is True and stash['head_src_files']==2200 and
            before['all_equal'] is True and before['final_source_sha256']==freeze['source_manifest_sha256'],
            'Recorded stash/frozen source reconciliation differs')
    require(len(stash['ignored_assets'])==1 and 'ignored pyc' in stash['original_verification_failure'],'Original stash verification failure was lost')
    for asset in stash['ignored_assets']:
        name='ignored-source-assets/'+asset['path'];data=validation[name]
        require(data==trees['current'][asset['path']] and sha(data)==asset['sha256']==root_source[asset['path']],
                'Separately saved ignored source pyc differs')
    mapping=load(validation,'validation-epoch-map.json')
    require(mapping['authoritative_source_files']==2211 and mapping['native']['original_combined_result_bytes_available'] is True,
            'Global validation epoch mapping differs')
    for original,record in mapping['global_wasi_original_path_mapping'].items():
        require('global-' in original or original.endswith('/record-optimal-wasi.o'),'Local unrelated module mapped as global')
        data=validation[record['global_member']]
        require(len(data)==record['bytes'] and sha(data)==record['sha256'],'Original global WASI path mapping differs')
    native=load(validation,'native-original-tool-result.json');initial=load(validation,'initial-activation-original-tool-result.json')
    require(native['chunk_id']==freeze['native']['source_tool_chunk']=='d82912' and native['exit_code']==0 and
            '36/36 tests passed' in native['output'],'Recovered Native36 actual terminal differs')
    require(initial['chunk_id']=='8a090a' and initial['exit_code']==1 and '34/35 tests passed (1 failed)' in initial['output'] and
            initial['output'].count('bound_entries=1 global_rejections=0')==5,'Original activation failure changed')
    recovery=load(validation,'session-recovery-provenance.json')
    require(recovery['results']['native-original-tool-result.json']['line']==31829 and
            recovery['results']['initial-activation-original-tool-result.json']['session_id']==17382,
            'Original bounded session recovery mapping differs')
    wasi=load(validation,'validation/global-wasi.stdout');wasi_exit=load(validation,'validation/global-wasi-exit.json')
    result=wasi['results'][0];wasm=validation['validation/global-entropy-bound.wasm']
    require(wasi['status']=='ok' and wasi['pointer_bits']==32 and wasi_exit['exit_code']==0 and result['exit_code']==0 and
            result['wasm_sha256']==wasi_exit['wasm_sha256']==sha(wasm) and result['wasm_bytes']==len(wasm),'Actual global WASI/wasm identity differs')
    wasi_text=validation['validation/global-wasi.stderr'].decode()
    require('All 36 tests passed.' in wasi_text and len(re.findall(r'^\d+/36 ',wasi_text,re.MULTILINE))==36,'Actual WASI36 test output differs')
    resource={}
    for label,text,oom in [('Native',native['output'],550),('WASI',wasi_text,583)]:
        rows=resource_rows(text);sweep=next(r for r in rows if r['gold']=='mozilla-64k' and 'observed_OOMs' in r)
        require(sweep['sweep_allocations']==sweep['observed_OOMs']==sweep['active_retries']==oom and
                sweep['owned_release_retries']==0,'Recorded allocation-failure sweep differs')
        for gold in ['mozilla-64k','xray-64k']:
            scoped=[r for r in rows if r['gold']==gold and 'stage' in r]
            require([r['stage'] for r in scoped]==['unlimited-probe','exact-D','D-minus-one-refused','quota-unlimited-retry'] and
                    all(r['live']==0 and r['bound_entries']==1 and r['global_rejections']>0 and r['owned_releases']==0 for r in scoped),
                    'Resource success/quota/retry or ownership coverage differs')
            require(scoped[1]['limit']==scoped[0]['peak']==scoped[1]['peak'] and
                    scoped[2]['limit']==scoped[0]['peak']-1 and scoped[3]['limit'] is None,'Exact-D/D-minus-one quota scope differs')
        resource[label]={'observed_OOMs':oom,'active_retries':oom,'owned_release_retries':0,'records':rows}
    require('owned_releases0 for Mozilla/Xray' in freeze['coverage_boundary'],'Gold ownership coverage boundary was lost')
    return {'global_source_files':2211,'baseline_compile_files':2992,'current_compile_files':3127,
            'generated_current_pyc_files':sum(name.endswith('.pyc') for name in trees['current']),
            'authoritative_global_freeze_verified':True,'native_tests':36,'actual_WASI_tests':36,'resource':resource,
            'initial_activation_failure_actual_exit':1,'initial_activation_failure_tests':{'passed':34,'failed':1},
            'original_combined_results_recovered':True,'RFC_static_eligibility_correction_preserved':True,
            'owned_release_positive_coverage':False,'stash_and_ignored_asset_receipts_verified':True,
            'scope':'Global frozen source and actual captured prerequisites only; no execution, no local29-source substitution, no nonzero owned-discard coverage claim'}
