"""Verify the frozen source/build/protocol/preflight and pilot record identities."""
import json
from package_io import load,member,require,sha
from paired_statistics import geometric,close
from performance import check_process


def verify_provenance(sources,files,validation):
    inventory=load(sources,'source-inventory.json');settings=load(files,'settings.json');trees={}
    for name,count in [('old_exact',2200),('current',2218)]:
        tree={key.removeprefix(name+'/'):data for key,data in sources.items() if key.startswith(name+'/')};trees[name]=tree
        require({key:{'bytes':len(data),'sha256':sha(data)} for key,data in tree.items()}==inventory[name],'Frozen full source closure differs')
        src={key:sha(data) for key,data in tree.items() if key.startswith('src/')}
        require(len(src)==count and src==load(files,'baseline-source-files.json' if name=='old_exact' else 'candidate-source-files.json'),'Frozen src registry differs')
    freeze=load(validation,'SOURCEFREEZE')
    require(sha(validation['source-files.json'])==freeze['manifest_sha256']=='a3cc7ac8e424db04added9be220465f3428adc563b57f4b1de474a3ca6577153' and
            load(validation,'source-files.json')==load(files,'candidate-source-files.json') and files['SOURCEFREEZE']==validation['SOURCEFREEZE'],
            'Authoritative shared-model2218 source freeze differs')
    binding=load(files,'candidate-source-binding.json')
    require(binding['root_manifest_sha256']==freeze['manifest_sha256'] and binding['src_files']==2218 and
            settings['variants']['current']=='cf-shared-literal:'+freeze['manifest_sha256'],'Shared-model source role differs')
    require(settings['variants']['old_exact']=='cf442dee0144f4c0cc1823474f77c7e8b1685f2e' and
            {key:value for key,value in settings.items() if key!='variants'}==load(files,'policy-frozen.json')['settings_without_variants'],
            'Frozen CF policy differs')
    for name,record in load(files,'harness-bindings.json')['files'].items():
        require(sha(files[name])==record['sha256'] and len(files[name])==record['bytes'],'Harness/protocol identity differs: '+name)
    for plan,protocol,sampler in [('control-plan.json','controls/protocol.json','control_sampling.py'),('small-plan.json','small-controls/protocol.json','small_sampling.py')]:
        record=load(files,plan);require(record['protocol_sha256']==sha(files[protocol]) and record['script_sha256']==sha(files[sampler]),'Predeclared auxiliary protocol/script changed')
    builds=load(files,'build-results.json')
    for name,b in builds.items():
        require(b['success'] is True and b['revision']==settings['variants'][name] and b['executable_sha256']==sha(files['bin/'+name]) and
                all(stage['exit_code']==0 for stage in b['stages']),'Primary source/build/ELF differs')
    aux=load(files,'auxiliary-build-results.json')
    for b in aux:
        require(b['exit_code']==0 and b['source_revision']==settings['variants'][b['variant']] and
                b['executable_sha256']==sha(files[member(b['executable_path'])]) and
                b['record_object_sha256']==sha(files[member(b['record_object_path'])]),'Auxiliary own-build/ELF/object differs')
    verification=load(files,'build-preflight-verification.json')
    require(verification['total_fresh_wires']==54 and verification['primary_fresh_wires']==24 and
            verification['public_control_fresh_wires']==6 and verification['small4KiB_fresh_wires']==24 and
            verification['all_source_peer_fullbyte_equal'] is True and verification['all_pinned_decoder_status1'] is True,'All54 preflight scope differs')
    fixtures=load(files,'fixtures.json');fixture_index={f['case']:f for f in fixtures};pre=load(files,'preflight-summary.json')
    require(len(pre['rows'])==24 and pre['all_CF_candidate_fullwire_equal'] is True,'Primary preflight differs')
    wires={(r['case'],r['variant']):r for r in pre['rows']}
    for f in fixtures:
        require(sha(files[member(f['path'])])==f['sha256'] and len(files[member(f['path'])])==f['bytes'],'Input identity differs')
        gold=files[member(f['golden_path'])]
        for name in ['old_exact','current']:
            row=wires[f['case'],name];actual=files[member(row['wire_path'])]
            require(actual==gold and sha(actual)==row['wire_sha256'] and len(actual)==row['wire_bytes'] and row['pinned_decode_verified'] is True,'Primary CF/C2 completewire differs')
    auxiliary=load(files,'auxiliary-preflight-summary.json')
    require(auxiliary['fresh_initial_wires']==30 and auxiliary['all_fullbyte_equal'] is True,'Auxiliary54 wire inventory differs')
    for row in auxiliary['rows']:
        blobs=[]
        for name,record in row['sources'].items():
            data=files[member(record['wire_path'])];blobs.append(data)
            require(sha(data)==record['wire_sha256'] and len(data)==record['wire_bytes'] and record['decode_status']==1 and
                    record['source_revision']==settings['variants'][name] and record['encode_exit']==0 and record['iterations']==0,'Auxiliary complete wire/decode receipt differs')
        require(blobs[0]==blobs[1],'Auxiliary source-peer wire bytes differ')
    for name in ['decoder-binding.json','auxiliary-decoder-binding.json']:
        decoder=load(files,name);require(decoder['version']=='1.2.0' and decoder['version_number']==0x1002000,'Pinned decoder version differs')
        for record in decoder['files']:
            data=files[member(record['path'])]
            require(sha(data)==record['sha256'] and ('bytes' not in record or len(data)==record['bytes']),'Pinned decoder binary identity differs')
    pilot=load(files,'pilot/run-manifest.json');reported=load(files,'pilot-summary.json');independent=load(files,'pilot-independent-verification.json')
    require(len(pilot['pairs'])==24 and independent['all48_samples_retained_no_filter'] is True and independent['CI'] is None,'Pilot complete/anomaly scope differs')
    raw_pairs=[];bycase={f['case']:[] for f in fixtures}
    primary_builds={name:{'executable_path':'/tmp/vort-br-shared-literal-model-ab.p9wbbc7q/bin/'+name,'executable_sha256':b['executable_sha256']} for name,b in builds.items()}
    for pair in pilot['pairs']:
        times={}
        for name in pair['order']:
            path=pair['processes'][name]['path'];raw,elapsed=check_process(files,path,name,fixture_index[pair['case']],1,primary_builds[name],wires[pair['case'],name])
            require(pair['processes'][name]['raw_ns']==[elapsed],'Pilot raw/manifest binding differs');times[name]=elapsed
        ratio=times['old_exact']/times['current'];raw_pairs.append(ratio);bycase[pair['case']].append(ratio)
    gm=geometric(raw_pairs);close(gm,reported['target_speedup_geomean'],'Pilot GM');close(gm,independent['independent_target_speedup_GM'],'Independent pilot GM')
    mozilla=bycase['mozilla'];require(len(mozilla)==2 and mozilla[0]>1.2 and mozilla[1]<1.01,'Mozilla pilot anomaly samples lost/filtered')
    approved=load(files,'FULL_APPROVED');require(approved['independent_receipt_sha256']==sha(files['pilot-independent-verification.json']),'Full sampling approval receipt differs')
    for path,digest in independent['raw_file_sha256'].items():require(sha(files[member(path)])==digest,'Pilot independent raw hash differs')
    note=load(files,'control-precheck-reader-note.json')
    require(note['public_campaign_started_after_failed_combined_precheck'] is True and note['no_source_or_protocol_change'] is True and
            note['no_control_retry_or_outlier_filter'] is True and 'KeyError' in note['original_error'],'Original failed precheck/started-sampling sequence hidden')
    for receipt,stdout,stderr in [('full-exit.json','full-stdout','full-stderr'),('control-exit.json','control.stdout','control.stderr'),
                                   ('small-exit.json','small.stdout','small.stderr'),('full-independent-exit.json','full-independent.stdout','full-independent.stderr')]:
        record=load(files,receipt);require(record['actual_exit']==0 and sha(files[stdout])==record['stdout_sha256'] and sha(files[stderr])==record['stderr_sha256'],'Actual matrix terminal/log identity differs')
    for name in ['full-analysis-exit.json','full-gate-exit.json']:require(load(files,name)['actual_exit']==0,'Full analysis/gate actual terminal differs')
    return {'source_files':{'CF':2200,'shared_model':2218},'frozen_full_closure_files':{name:len(tree) for name,tree in trees.items()},
            'preflight_complete_wires':54,'pinned_decoder':'1.2.0','pilot_pairs':24,'pilot_processes':48,'pilot_GM':gm,
            'mozilla_pilot_two_raw_speedups':mozilla,'pilot_anomaly_preserved':True,'precheck_error_then_sampling_started_preserved':True,
            'full_sampling_approved_not_merge_approval':True,'scope':'Frozen source/harness/protocol/ELF/wire/exit identities; no producer or codec execution'}
