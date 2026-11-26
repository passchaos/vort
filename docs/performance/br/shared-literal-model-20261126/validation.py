"""Check recorded focused outcomes and preserved failed campaigns as data."""
import re
from package_io import load,require,sha


def terminal(files,prefix,code):
    record=load(files,prefix+'-exit.json');require(record['actual_exit']==code,'Recorded terminal differs: '+prefix)
    for stream in ['stdout','stderr']:require(sha(files[prefix+'-'+stream])==record[stream+'_sha256'],'Recorded stream SHA differs')
    return files[prefix+'-stderr'].decode()


def resource_rows(text):
    rows=[]
    for line in text.splitlines():
        start=line.find('literal_model_resource ')
        if start<0:continue
        row=dict(token.split('=',1) for token in line[start:].split()[1:])
        for key,value in list(row.items()):
            if value.isdigit():row[key]=int(value)
            elif value=='null':row[key]=None
        rows.append(row)
    return rows


def verify_validation(files):
    owner_native=files['owner-native/validation-hq.stderr'].decode()
    require(load(files,'owner-native/validation-hq.exit.json')['exit_code']==0 and 'All 15 tests passed.' in owner_native,'Owner final Native15 differs')
    link=load(files,'owner-native/source-link-provenance.json');require(link['source_not_followed'] is True and link['original_gate_source_was_symlink'] is True,'Worker live-source boundary hidden')
    old=files['owner-native/validation.stderr'].decode()
    require('All 14 tests passed.' in old and load(files,'owner-native/validation.exit.json')['exit_code']==0,'Original Owner14 outcome differs')
    recovered=load(files,'owner14-recovered/receipt.json');require(recovered['status']=='reverse-recovered','Owner14 recovery mislabeled')
    for record in recovered['files']:
        name=record['path'].rsplit('/',1)[-1];data=files['owner14-recovered/'+name]
        require(sha(data)==record['sha256'] and len(data)==record['bytes'],'Exact original Owner14 module SHA differs')
    owner_wasi=terminal(files,'owner-wasi-run',0);require('All 15 tests passed.' in owner_wasi,'Owner actual WASI15 differs')
    smoke=terminal(files,'native-smoke',0);require('All 25 tests passed.' in smoke,'Native writer smoke25 differs')
    for prefix in ['native-writer-history-3','wasi-writer-history-3-run']:
        text=terminal(files,prefix,0)
        require('All 25 tests passed.' in text and 'variant_wire_oracles=162 fresh_frame_decodes=126 seeded_history_oracles=36' in text and
                'uncached_first_difference=0 cached_first_difference=0 decoded_equal=true' in text,'Fixed writer/history actual diagnostics differ')
    compile_fail=terminal(files,'native-contracts',1)
    require(compile_fail.count('unable to resolve comptime value')==2,'Two original Native comptime failures lost')
    for prefix in ['native-contracts-2','wasi-contracts-run']:
        text=terminal(files,prefix,1)
        require('37 passed; 0 skipped; 1 failed.' in text and 'FAIL (TestExpectedEqual)' in text and
                'br shared literal model public gold and scope' in text and
                all('literal_model_public corpus='+name in text for name in ['mozilla','xray','nci','xml']),
                'Original37/38 failure or named public cases hidden')
    fmt=load(files,'first-fmt-tool-result.json');require(fmt['actual_exit']==1 and "expected statement, found ';'" in fmt['original_combined_output'],'Original formatting failure lost')
    for name in ['before-first-fmt-fix.zig','before-native-comptime-fix.zig','before-public-comptime-fix.zig','before-history-oracle-fix-br.zig','before-history-oracle-fix-writer.zig']:
        require(files[name],'Original pre-fix source missing')
    for stdout,module in [('owner-wasi-run-stdout','owner-tests.wasm'),('wasi-writer-history-3-run-stdout','writer-history-3.wasm'),('wasi-resources-run-stdout','resources.wasm')]:
        report=load(files,stdout);result=report['results'][0]
        require(report['status']=='ok' and result['exit_code']==0 and result['wasm_sha256']==sha(files[module]) and result['wasm_bytes']==len(files[module]),'Compiled successful WASM identity differs')
    resource={}
    for label,prefix,oom in [('Native','native-resources',625),('WASI','wasi-resources-run',658)]:
        text=terminal(files,prefix,0);require('All 35 tests passed.' in text,'Resource35 terminal differs')
        rows=resource_rows(text);sweep=next(r for r in rows if r['stage']=='sweep')
        require(sweep['allocation_ordinals']==sweep['observed_OOMs']==sweep['retries']==oom and
                sweep['allocated_bytes']==sweep['freed_bytes'] and sweep['retry_hits']>0,'Complete OOM/retry cleanup or active hits differs')
        for corpus,hits in [('mozilla',24),('xray',28)]:
            scoped={r['stage']:r for r in rows if r['corpus']==corpus and r['stage']!='sweep'}
            off,on=scoped['disabled-probe'],scoped['enabled-probe']
            require(off['peak']==on['peak'] and on['allocations']>off['allocations'] and on['allocated_bytes']>off['allocated_bytes'] and on['hits']==hits,
                    'Peak/no-increase versus allocation increase tradeoff lost')
            require(scoped['exact-D']['limit']==on['peak'] and scoped['D-minus-one-refused']['limit']==on['peak']-1 and
                    all(r['live']==0 and r['allocated_bytes']==r['freed_bytes'] for r in scoped.values()),'Quota/live cleanup scope differs')
        resource[label]={'OOMs':oom,'retries':oom,'peak_no_increase':True,'allocation_count_and_bytes_increase':True,'positive_model_hits':{'mozilla':24,'xray':28},'rows':rows}
    gate=load(files,'full-library-gate-status.json')
    require(gate['status']=='passed' and gate['actual_exit']==0 and gate['mergeAllowed'] is True,'Authoritative completed Root gate differs')
    whole=load(files,'full-library-gate-exit.json');capsule=load(files,'full-library-gate-capsule.json')
    require(whole['actual_exit']==capsule['actual_exit']==0 and whole['completed_utc']==capsule['completed_utc'] and
            capsule['source_files']==2218 and capsule['source_manifest_sha256']=='a3cc7ac8e424db04added9be220465f3428adc563b57f4b1de474a3ca6577153',
            'Whole-gate terminal/source identity differs')
    for name,record in capsule['files'].items():
        require(len(files[name])==record['bytes'] and sha(files[name])==record['sha256'],'Whole-gate raw receipt bytes differ')
    require(b'Build Summary: 414/414 steps succeeded; 6068/6070 tests passed (2 skipped)' in files['full-library-gate-stderr'] and
            capsule['diagnostic_hints_are_not_authoritative_nonzero_exits'] is True and
            any('source_reverse_wasm_gate.js' in line for line in capsule['diagnostic_command_hints']),
            'Completed all-step success or diagnostic attribution differs')
    exact=load(files,'zstd-source-reverse-exact-rerun-exit.json');command=load(files,'zstd-source-reverse-exact-rerun-command.json')
    require(exact['actual_exit']==0 and exact['wasm_before_after_equal'] is True and
            sha(files['zstd-source-reverse-exact-rerun.wasm'])==command['wasm_sha256'] and
            sha(files['zstd-source-reverse-exact-rerun-stdout'])==exact['stdout_sha256'] and
            sha(files['zstd-source-reverse-exact-rerun-stderr'])==exact['stderr_sha256'] and
            b'All 84 tests passed.' in files['zstd-source-reverse-exact-rerun-stderr'], 'Exact Zstd rerun84 identity differs')
    return {'Owner_Native':15,'Owner_WASI':15,'Owner14_modules_reverse_recovered':True,'initial_Owner14_full_tree_snapshot_retained':False,'smoke_Native':25,'writer_Native_WASI':25,'writer_wire_oracles':162,
            'fresh_decodes':126,'seeded_history_oracles':36,'original_campaigns':{'Native':{'pass':37,'fail':1},'WASI':{'pass':37,'fail':1}},
            'named_public_gold_scope_cases':4,'public_namedcase_success_not_overall37_38_pass':True,'resource':resource,
            'history_uncached_cached_diagnostic_preserved':True,'full_library_gate':gate,
            'scope':'Recorded outcomes, frozen pre-fix source and authoritative completed whole gate; original37/38 campaigns remain failed, diagnostic command hints are not actual nonzero exits'}
