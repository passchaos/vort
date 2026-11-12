#!/usr/bin/env python3
"""Pack a terminal mapped-owner screen; only --finalize writes archives."""
import argparse,gzip,hashlib,io,json,os,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
RAW=Path('/tmp/vort-mapped-owner-candidate-20261112.7aaa9361')
BASE='7aaa936142aafdebe8351962e8c49059571d42c5'
def sha(b):return hashlib.sha256(b).hexdigest()
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def require(value,message):
    if not value:raise ValueError(message)
def reuse(path,member=None):
    r={'path':path,'sha256':sha((ROOT/path).read_bytes())}
    if member:r['member']=member
    return r

def check_inputs(raw):
    require(sorted(os.sched_getaffinity(0))==[0],'Run packing on CPU0')
    epochs=[('timing-source','timing-freeze.json'),('handoff-v1-source','handoff-v1-freeze.json'),('handoff-v2-source','handoff-v2-source.json'),('owner-only-source','owner-only-source.json')]
    for directory,receipt in epochs:
        expected=json.loads((raw/receipt).read_bytes())['source_sha256']
        actual={str(p.relative_to(raw/directory)):sha(p.read_bytes()) for p in (raw/directory).rglob('*') if p.is_file()}
        require(actual==expected,'Frozen source changed: '+directory)
    require(sha((raw/'candidate-compare').read_bytes())==json.loads((raw/'timing-freeze.json').read_bytes())['probe_sha256'],'Original timing probe changed')
    require(len(json.loads((raw/'screen/events.json').read_bytes()))==192,'Screen is not terminal')
    require(len(json.loads((raw/'screen/protocol.json').read_bytes())['tasks'])==12 and set(json.loads((raw/'screen/summary.json').read_bytes()))=={'owner-word','owner-only'},'Final protocol/summary missing')
    require(json.loads((raw/'smoke/validation.json').read_bytes())['events']==144,'Both72-wire smoke receipts required')
    return epochs

def pack(name,files,mode=0o644):
    require(not (OUT/name).exists(),'Refusing to overwrite existing archive: '+name)
    hashes={};origins={}
    with (OUT/name).open('wb') as target:
        with gzip.GzipFile(filename='',mode='wb',fileobj=target,compresslevel=9,mtime=0) as gz:
            with tarfile.open(fileobj=gz,mode='w|',format=tarfile.GNU_FORMAT) as tar:
                for name,origin in sorted(files.items()):
                    if isinstance(origin,Path):data=origin.read_bytes();origins[name]=str(origin)
                    else:data=origin
                    m=tarfile.TarInfo(name);m.size=len(data);m.uid=m.gid=m.mtime=0;m.uname=m.gname='';m.mode=mode
                    tar.addfile(m,io.BytesIO(data));hashes[name]=sha(data)
    return {'files':hashes,'origins':origins,'mode':mode}

def finalize(raw):
    epochs=check_inputs(raw)
    previous='docs/performance/deflate/distance-secondary-holes-20261112'
    binding={'schema':'vort.deflate.mapped-owner-archive-bindings.v1','base_revision':BASE,'raw_root':str(raw),'archives':{},'archive_cpu':0,'policy':'Sorted GNU tar, regular0644/binaries0755, uid/gid/mtime0, empty owners; gzip level9/no filename/mtime0; all packing CPU0','reuse':{
        'baseline_source':reuse('docs/performance/br/decode-mozilla-distributions-20261112/shared-dispatch-source.tar.gz'),
        'public_linear_overlay':reuse('docs/performance/deflate/public-linear-contracts-20261112/source-overlay.tar.gz'),
        'wide_boundary_overlay':reuse('docs/performance/deflate/wide-copy-contracts-20261112/final-boundary-source-overlay.tar.gz'),
        'distance_holes_overlay':reuse(previous+'/final-source-overlay.tar.gz'),
        'baseline_binary':reuse(previous+'/retained-executables.tar.gz','after-compare'),
        'reference_library':reuse('docs/performance/modern-decode-current-20261111/reference-libraries.tar.gz','deflate/libdeflate.so.0'),
        'small_fixtures':reuse(previous+'/small-fixtures-oracle.tar.gz')}}
    for directory,receipt in epochs:
        name=directory+'-overlay.tar.gz';binding['archives'][name]=pack(name,{str(p.relative_to(raw/directory)):p for p in (raw/directory).rglob('*') if p.is_file()})
    top={p.name:p for p in raw.iterdir() if p.is_file() and (p.suffix=='.json' or p.suffix=='.log')}
    binding['archives']['raw-validation.tar.gz']=pack('raw-validation.tar.gz',top)
    static={n:raw/n for n in ['baseline-aligned.objdump.txt','candidate-mapped.objdump.txt','candidate.nm.txt','codegen-audit.json']}
    binding['archives']['raw-static-audit.tar.gz']=pack('raw-static-audit.tar.gz',static)
    exes={}
    for p in raw.iterdir():
        if p.is_file():
            with p.open('rb') as stream:magic=stream.read(4)
            if magic in [b'\x7fELF',b'\x00asm']:exes[p.name]=p
    binding['archives']['retained-probes-tests.tar.gz']=pack('retained-probes-tests.tar.gz',exes,0o755)
    for directory in ['screen','smoke']:
        files={str(p.relative_to(raw/directory)):p for p in (raw/directory).rglob('*') if p.is_file()}
        files[directory+'.py']=raw/(directory+'.py');files[directory+'.log']=raw/(directory+'.log')
        binding['archives'][directory+'-raw.tar.gz']=pack(directory+'-raw.tar.gz',files)
    imports={};git_origins={}
    for n in ['matrix.py','evidence.py','fixtures.py']:
        path='tools/decode/'+n;imports[path]=subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT);git_origins[path]=BASE+':'+path
    binding['archives']['runner-imports.tar.gz']=pack('runner-imports.tar.gz',imports);binding['archives']['runner-imports.tar.gz']['git_origins']=git_origins
    prior='docs/performance/deflate/distance-secondary-holes-20261112/nonregression-raw.tar.gz'
    binding['prior_fixture_manifest']={'archive':reuse(prior),'member':'candidate.manifest.json','sha256':json.loads((raw/'screen/protocol.json').read_bytes())['prior_fixture_manifest_sha256']}
    descriptor=ROOT/previous/'fixture-replay-bindings.json';(OUT/'fixture-replay-bindings.json').write_bytes(descriptor.read_bytes());binding['fixture_descriptor_reuse']=reuse(previous+'/fixture-replay-bindings.json')
    for n in ['timing-freeze.json','handoff-v1-freeze.json','handoff-v2-source.json','owner-only-source.json','producer-validation.json','codegen-audit.json','independent-statistics.json']:(OUT/n).write_bytes((raw/n).read_bytes())
    summary=json.loads((raw/'screen/summary.json').read_bytes())
    write(OUT/'decision.json',{'artifact_kind':'archive-derived decision from terminal protocol gates and original frozen screen summary','adoption':{'owner-word':False,'owner-only':False},'variants':summary,'scope':'both experiments rejected; isolated prototype code remains outside mainline; no performance leadership or complete matrix claim'})
    binding['scope']={'baseline_registry_files':2069,'owner_word_capture_registry_files':2075,'owner_only_capture_registry_files':2071,'prototype_code_adopted':False,'full_deflate_test_root_has_shim_tests':False,'wasm_runtime_tested':False,'raw_static_capture_authorship':'new main CPU0 capture; derived counters trace earlier read-only audit, not recovered agent raw output','large_ordinary_fixture_bytes_archived':False}
    write(OUT/'archive-bindings.json',binding)
    print(json.dumps({'packed':True,'archives':len(binding['archives']),'binaries':len(exes),'source_epochs':len(epochs),'base_revision':BASE},indent=2))

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,default=RAW);parser.add_argument('--finalize',action='store_true');args=parser.parse_args()
    if args.finalize:finalize(args.input)
    else:print(json.dumps({'inputs_valid':True,'source_epochs':len(check_inputs(args.input)),'archives_written':False},indent=2))
if __name__=='__main__':main()
