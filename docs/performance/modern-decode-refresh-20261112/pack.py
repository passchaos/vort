#!/usr/bin/env python3
"""Pack completed current-source decode evidence on CPU0, without running codecs."""
import argparse,gzip,hashlib,io,json,os,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
RAW=Path('/tmp/vort-decode-refresh-20261112.21e4a1d0')
BASE='21e4a1d0c0323c7db2317fd6e7cda4c5069e8e1d'
def sha(data):return hashlib.sha256(data).hexdigest()
def require(v,message):
    if not v:raise ValueError(message)
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
def reuse(path,member=None):
    d={'path':path,'sha256':sha((ROOT/path).read_bytes())}
    if member:d['member']=member
    return d

def archive(name,files,mode=0o644):
    require(not (OUT/name).exists(),'Archive already exists: '+name);hashes={};origins={}
    with (OUT/name).open('wb') as f:
        with gzip.GzipFile(filename='',mode='wb',fileobj=f,compresslevel=9,mtime=0) as gz:
            with tarfile.open(fileobj=gz,mode='w|',format=tarfile.GNU_FORMAT) as t:
                for name,value in sorted(files.items()):
                    if isinstance(value,Path):data=value.read_bytes();origins[name]=str(value)
                    else:data=value
                    m=tarfile.TarInfo(name);m.size=len(data);m.uid=m.gid=m.mtime=0;m.uname=m.gname='';m.mode=mode;t.addfile(m,io.BytesIO(data));hashes[name]=sha(data)
    return {'files':hashes,'origins':origins,'mode':mode}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,default=RAW);parser.add_argument('--finalize',action='store_true');a=parser.parse_args();raw=a.input
    require(sorted(os.sched_getaffinity(0))==[0],'Run packing on CPU0');manifest=json.loads((raw/'manifest.json').read_bytes());require(manifest['source']['revision']==BASE and len(list((raw/'rows').glob('*.json')))==360,'Expected terminal current-source rows')
    if not a.finalize:print('Current-source360 rows found; no archive writes');return
    require((raw/'producer-validation.json').exists(),'Wait for final main producer receipt before packaging')
    binding={'schema':'vort.modern-decode-refresh-archive-bindings.v1','base_revision':BASE,'raw_root':str(raw),'archives':{},'archive_cpu':0,'policy':'sorted GNU tar; regular0644/probe0755; uid/gid/mtime0; empty owners; gzip level9/no filename/mtime0','reuse':{
        'baseline_source':reuse('docs/performance/br/decode-mozilla-distributions-20261112/shared-dispatch-source.tar.gz'),
        'public_overlay':reuse('docs/performance/deflate/public-linear-contracts-20261112/source-overlay.tar.gz'),
        'wide_overlay':reuse('docs/performance/deflate/wide-copy-contracts-20261112/final-boundary-source-overlay.tar.gz'),
        'holes_overlay':reuse('docs/performance/deflate/distance-secondary-holes-20261112/final-source-overlay.tar.gz'),
        'tools_overlay':reuse('docs/performance/deflate/pmu-batch-profile-20261112/final-tool-source.tar.gz'),
        'reference_libraries':reuse('docs/performance/modern-decode-current-20261111/reference-libraries.tar.gz')}}
    top={p.name:p for p in raw.iterdir() if p.is_file()};binding['archives']['raw-refresh.tar.gz']=archive('raw-refresh.tar.gz',top)
    binding['archives']['raw-rows.tar.gz']=archive('raw-rows.tar.gz',{str(p.relative_to(raw/'rows')):p for p in (raw/'rows').rglob('*') if p.is_file()})
    probe=Path(manifest['probe']);require(sha(probe.read_bytes())==manifest['probe_sha256']=='a69c106fec63a70490be2dd57a76e233ddbaaaadcb37439d2d6abab52897a91f','Current probe changed')
    binding['archives']['probe.tar.gz']=archive('probe.tar.gz',{'baseline-compare':probe},0o755)
    build=probe.parent/'baseline-build.log';binding['archives']['probe-build.tar.gz']=archive('probe-build.tar.gz',{'baseline-build.log':build})
    helpers={n:subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT) for n in ['tools/decode/matrix.py','tools/decode/evidence.py','tools/decode/pmu_evidence.py','tools/decode/fixtures.py']};binding['archives']['runner-imports.tar.gz']=archive('runner-imports.tar.gz',helpers)
    binding['old_fixture_manifest']=reuse('docs/performance/modern-decode-current-20261111/manifest.json')
    binding['old_runner_seed']=reuse('docs/performance/deflate/mapped-owner-handoff-20261112/screen-raw.tar.gz','baseline.manifest.json')
    fixtures=manifest['fixtures'];files={}
    for f in fixtures:
        for n,h,b in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:files[f[n]]={'sha256':f[h],'bytes':f[b]}
    write(OUT/'fixture-fields.json',{'artifact_kind':'original216 frozen fixture descriptors; ordinary bytes remain external','fixtures':fixtures,'files':files,'encoded_fixtures':216,'plain_files':36,'regenerated':False})
    for name in ['aggregate-summary.json','aggregate-row-order.json','summary.json','producer-validation.json']:(OUT/name).write_bytes((raw/name).read_bytes())
    binding['aggregate_row_order_sha256']=sha((raw/'aggregate-row-order.json').read_bytes())
    write(OUT/'archive-bindings.json',binding);print(json.dumps({'archives':len(binding['archives']),'rows':360,'fixtures':len(fixtures),'external_files':len(files)},indent=2))
if __name__=='__main__':main()
