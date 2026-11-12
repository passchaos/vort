#!/usr/bin/env python3
"""Archive a frozen owner-prepare control on CPU0; explicit --finalize required."""
import argparse,gzip,hashlib,io,json,os,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
RAW=Path('/tmp/vort-owner-prepare-20261112.cf478328')
BASE='cf47832821e0dce4261ab9d1cc6d56505bd121a3'
def sha(data):return hashlib.sha256(data).hexdigest()
def require(value,message):
    if not value:raise ValueError(message)
def write(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def reuse(path,member=None):
    r={'path':path,'sha256':sha((ROOT/path).read_bytes())}
    if member:r['member']=member
    return r

def archive(name,files,mode=0o644):
    require(not (OUT/name).exists(),'Refusing archive overwrite: '+name);hashes={};origins={}
    with (OUT/name).open('wb') as target:
        with gzip.GzipFile(filename='',mode='wb',fileobj=target,compresslevel=9,mtime=0) as gz:
            with tarfile.open(fileobj=gz,mode='w|',format=tarfile.GNU_FORMAT) as t:
                for name,value in sorted(files.items()):
                    if isinstance(value,Path):data=value.read_bytes();origins[name]=str(value)
                    else:data=value
                    m=tarfile.TarInfo(name);m.size=len(data);m.uid=m.gid=m.mtime=0;m.uname=m.gname='';m.mode=mode;t.addfile(m,io.BytesIO(data));hashes[name]=sha(data)
    return {'files':hashes,'origins':origins,'mode':mode}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,default=RAW);parser.add_argument('--finalize',action='store_true');a=parser.parse_args();raw=a.input
    require(sorted(os.sched_getaffinity(0))==[0],'Run packing on CPU0');freeze=json.loads((raw/'source-freeze.json').read_bytes())
    require({str(p.relative_to(raw/'control-source')):sha(p.read_bytes()) for p in (raw/'control-source').rglob('*') if p.is_file()}==freeze['source_sha256'],'Control source changed')
    require(len(json.loads((raw/'events.json').read_bytes()))==160 and json.loads((raw/'smoke/validation.json').read_bytes())['events']==72,'Terminal frozen events required')
    if not a.finalize:print('Frozen terminal inputs verified; no archive writes');return
    binding={'schema':'vort.deflate.owner-prepare-archive-bindings.v1','base_revision':BASE,'raw_root':str(raw),'archives':{},'archive_cpu':0,'policy':'sorted GNU tar; regular0644/probes0755; uid/gid/mtime0; empty owners; gzip level9/empty filename/mtime0','reuse':{
        'baseline_source':reuse('docs/performance/br/decode-mozilla-distributions-20261112/shared-dispatch-source.tar.gz'),
        'public_overlay':reuse('docs/performance/deflate/public-linear-contracts-20261112/source-overlay.tar.gz'),
        'wide_overlay':reuse('docs/performance/deflate/wide-copy-contracts-20261112/final-boundary-source-overlay.tar.gz'),
        'holes_overlay':reuse('docs/performance/deflate/distance-secondary-holes-20261112/final-source-overlay.tar.gz'),
        'tools_overlay':reuse('docs/performance/deflate/pmu-batch-profile-20261112/final-tool-source.tar.gz'),
        'reference_libraries':reuse('docs/performance/modern-decode-current-20261111/reference-libraries.tar.gz')}}
    binding['archives']['control-source.tar.gz']=archive('control-source.tar.gz',{str(p.relative_to(raw/'control-source')):p for p in (raw/'control-source').rglob('*') if p.is_file()})
    originals=json.loads((raw/'agent-static-originals.json').read_bytes())
    binding['archives']['agent-static-originals.tar.gz']=archive('agent-static-originals.tar.gz',{str(p.relative_to(raw/'agent-static-originals')):p for p in (raw/'agent-static-originals').rglob('*') if p.is_file()})
    binding['original_agent_sources']=originals['files']
    exes={n:raw/n for n in ['baseline-compare','control-compare','owner-safe','full-safe']}
    binding['archives']['probes-tests.tar.gz']=archive('probes-tests.tar.gz',exes,0o755)
    top={p.name:p for p in raw.iterdir() if p.is_file() and p.name not in exes};binding['archives']['raw-evidence.tar.gz']=archive('raw-evidence.tar.gz',top)
    for directory in ['rows','smoke']:binding['archives'][directory+'.tar.gz']=archive(directory+'.tar.gz',{str(p.relative_to(raw/directory)):p for p in (raw/directory).rglob('*') if p.is_file()})
    imports={}
    for n in ['tools/decode/matrix.py','tools/decode/evidence.py','tools/decode/pmu_evidence.py','tools/decode/fixtures.py']:imports[n]=subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT)
    binding['archives']['runner-imports.tar.gz']=archive('runner-imports.tar.gz',imports)
    old='docs/performance/deflate/distance-secondary-holes-20261112/fixture-replay-bindings.json';(OUT/'fixture-replay-bindings.json').write_bytes((ROOT/old).read_bytes());binding['fixture_descriptor_reuse']=reuse(old)
    for n in ['source-freeze.json','probe-freeze.json','agent-static-originals.json','codegen-audit.json','producer-validation.json','independent-statistics.json']:(OUT/n).write_bytes((raw/n).read_bytes())
    binding['scope']={'baseline_registry_files':2072,'control_registry_files':2075,'control_source_files':6,'ordinary_events':96,'pmu_events':64,'original_agent_raw_artifacts':True,'main_codegen_summary_is_derived':True,'scalar_normalization_mask_scope':'8call_rel32/17rip_disp32 plus4actualjump_tabletargets','helper_bodies_fully_compared':False,'whole_binary_equal_claimed':False,'prototype_adopted':False}
    write(OUT/'archive-bindings.json',binding);print(json.dumps({'archives':len(binding['archives']),'original_agent_artifacts':len(originals['files']),'base_revision':BASE},indent=2))
if __name__=='__main__':main()
