#!/usr/bin/env python3
"""Archive three rejected exact-copy epochs on CPU0; never rerun a codec."""
import argparse,gzip,hashlib,io,json,os,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
BASE='21e4a1d0c0323c7db2317fd6e7cda4c5069e8e1d'
ROOTS={'v1':Path('/tmp/vort-wide-copy-buckets-20261112.21e4a1d0'),'v2':Path('/tmp/vort-wide-copy-interleaved-20261112.21e4a1d0'),'v3':Path('/tmp/vort-wide-copy-interleaved32-20261112.21e4a1d0')}
ARTROOT=Path('/home/passchaos/.trae/cli/sessions/2026/11/12/rollout-2026-11-12T04-50-16-01a1cc60-2a83-7b31-bae5-81011e0abc3e.artifacts/tool-results')
RAW_ASM={'baseline':ARTROOT/'exec_command-code-mode-nested_29_call_V0RYPxrA60FG3366wsrPh1ex_exec-167c4ec0-a57b-40a9-9008-1eaa01d0f99f.txt','v1':ARTROOT/'exec_command-code-mode-nested_29_call_MJbhMERuiFE5h34fHFmPVGkg_exec-3348967c-76a3-42b0-bf8e-98b290facefe.txt','v2':ARTROOT/'exec_command-code-mode-nested_29_call_V0RYPxrA60FG3366wsrPh1ex_exec-39d3d07b-50d0-445e-9b5f-b74dfaf6e0e1.txt','v3':ARTROOT/'exec_command-code-mode-nested_29_call_44p6m2OL32SChe5XY9VcD10a_exec-325b1b5a-a994-4f39-b1d1-13aa2cab1a68.txt'}
def sha(d):return hashlib.sha256(d).hexdigest()
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def require(v,message):
    if not v:raise ValueError(message)
def reuse(path,member=None):
    r={'path':path,'sha256':sha((ROOT/path).read_bytes())}
    if member:r['member']=member
    return r

def archive(name,files,mode=0o644):
    require(not (OUT/name).exists(),'Archive exists: '+name);hashes={};origins={}
    with (OUT/name).open('wb') as target:
        with gzip.GzipFile(filename='',mode='wb',fileobj=target,compresslevel=9,mtime=0) as gz:
            with tarfile.open(fileobj=gz,mode='w|',format=tarfile.GNU_FORMAT) as t:
                for name,value in sorted(files.items()):
                    if isinstance(value,Path):d=value.read_bytes();origins[name]=str(value)
                    else:d=value
                    m=tarfile.TarInfo(name);m.size=len(d);m.uid=m.gid=m.mtime=0;m.uname=m.gname='';m.mode=mode;t.addfile(m,io.BytesIO(d));hashes[name]=sha(d)
    return {'files':hashes,'origins':origins,'mode':mode}

def main():
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--finalize',action='store_true');args=a.parse_args();require(sorted(os.sched_getaffinity(0))==[0],'Run packing on CPU0')
    require(len(json.loads((ROOTS['v3']/'full-cold/events.json').read_bytes()))==576,'Final full-cold data required')
    if not args.finalize:print('Final576 events present; no archive writes');return
    refresh='docs/performance/modern-decode-refresh-20261112';prior=json.loads((ROOT/refresh/'archive-bindings.json').read_bytes())
    binding={'schema':'vort.deflate.exact-copy-archive-bindings.v1','base_revision':BASE,'archive_cpu':0,'archives':{},'reuse':{**prior['reuse'],'baseline_probe':reuse(refresh+'/probe.tar.gz','baseline-compare'),'refresh_raw':reuse(refresh+'/raw-refresh.tar.gz','manifest.json')},'source_snapshots':{},'policy':'sorted GNU tar; regular0644/binaries0755; uid/gid/mtime0; empty owners; gzip level9/empty filename/mtime0'}
    shared=ROOTS['v3']/'source';new_names=['src/wide_copy_kernel_test_root.zig','src/wide_copy_page_test_root.zig','src/deflate/decoder/wide_copy_page_tests.zig'];binding['archives']['shared-test-source.tar.gz']=archive('shared-test-source.tar.gz',{n:shared/n for n in new_names})
    binaries={};test_identities={}
    for version,raw in ROOTS.items():
        directory='source-v1' if version=='v1' else 'source';receipt='source-v1-freeze.json' if version=='v1' else 'source-freeze.json';snap={str(p.relative_to(raw/directory)):str(p) for p in (raw/directory).rglob('*') if p.is_file()}
        if version=='v1':snap.update({str(p.relative_to(raw/'page-source')):str(p) for p in (raw/'page-source').rglob('*') if p.is_file()})
        binding['source_snapshots'][version]={'receipt':receipt,'origins':snap};binding['archives'][version+'-kernel-source.tar.gz']=archive(version+'-kernel-source.tar.gz',{'src/deflate/decoder/shortcopy.zig':raw/directory/'src/deflate/decoder/shortcopy.zig'})
        top={}
        for p in raw.iterdir():
            if not p.is_file():continue
            with p.open('rb') as stream:magic=stream.read(4)
            if magic in [b'\x7fELF',b'\x00asm']:
                if p.name=='control-compare':binaries[version+'/'+p.name]=p
                elif p.name!='baseline-compare':test_identities[version+'/'+p.name]={'sha256':sha(p.read_bytes()),'bytes':p.stat().st_size,'source_epoch':version,'original_file':str(p),'raw_log_member':version+'-raw.tar.gz:'+p.name+'.log','compiler_argv':None,'build_argv_scope':'complete original test build argv was not retained; validation label/source/log do not reconstruct an original command','validation_label':p.name}
            else:top[p.name]=p
        binding['archives'][version+'-raw.tar.gz']=archive(version+'-raw.tar.gz',top)
        for folder in ['rows','smoke']:binding['archives'][version+'-'+folder+'.tar.gz']=archive(version+'-'+folder+'.tar.gz',{str(p.relative_to(raw/folder)):p for p in (raw/folder).rglob('*') if p.is_file()})
    binding['archives']['performance-probes.tar.gz']=archive('performance-probes.tar.gz',binaries,0o755)
    write(OUT/'test-binary-identities.json',{'artifact_kind':'compact archive identity index for original test executables; bytes external, logs/source retained','tests':test_identities})
    full=ROOTS['v3']/'full-cold';binding['archives']['full-cold.tar.gz']=archive('full-cold.tar.gz',{str(p.relative_to(full)):p for p in full.rglob('*') if p.is_file()})
    binding['archives']['original-codegen.tar.gz']=archive('original-codegen.tar.gz',{n+'.txt':p for n,p in RAW_ASM.items()});binding['codegen_original_sources']={n:{'source':str(p),'sha256':sha(p.read_bytes())} for n,p in RAW_ASM.items()}
    write(OUT/'codegen-reported.json',{'authorship':'archive-composed record of Hume/parent reported static audit; original agent tool files retained separately','rows':{'baseline':{'text_bytes':3659,'stack_bytes':296,'instructions':897,'vector_stack_references':2},'v1':{'text_bytes':4171,'stack_bytes':696,'instructions':971,'vector_stack_references':28},'v2':{'text_bytes':4017,'stack_bytes':312,'instructions':963,'vector_stack_references':2},'v3':{'text_bytes':3883,'stack_bytes':312,'instructions':930,'vector_stack_references':2}},'scope':'whole-symbol static counters include cold/tail/padding; vector stack references are not runtime spills'})
    helpers={n:subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT) for n in ['tools/decode/matrix.py','tools/decode/evidence.py','tools/decode/pmu_evidence.py','tools/decode/fixtures.py']};binding['archives']['runner-imports.tar.gz']=archive('runner-imports.tar.gz',helpers)
    old='docs/performance/deflate/distance-secondary-holes-20261112/fixture-replay-bindings.json';(OUT/'fixture-replay-bindings.json').write_bytes((ROOT/old).read_bytes());binding['fixture_descriptor_reuse']=reuse(old)
    (OUT/'full-cold-independent-statistics.json').write_bytes((full/'independent-statistics.json').read_bytes());write(OUT/'archive-bindings.json',binding)
    print(json.dumps({'archives':len(binding['archives']),'performance_candidate_probes':len(binaries),'versions':3,'full_events':576},indent=2))
if __name__=='__main__':main()
