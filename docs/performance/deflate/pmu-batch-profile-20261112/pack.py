#!/usr/bin/env python3
"""Archive terminal PMU diagnostics on CPU0; never run a codec or perf tool."""
import argparse,gzip,hashlib,io,json,os,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
RAW=Path('/tmp/vort-deflate-pmu-20261112.485ca30f')
BASE='485ca30f2c61dd57673dd04e996a69171081e194'
def sha(data):return hashlib.sha256(data).hexdigest()
def write(path,value):path.write_text(json.dumps(value,indent=2)+'\n')
def require(value,message):
    if not value:raise ValueError(message)
def reused(path,member=None):
    d={'path':path,'sha256':sha((ROOT/path).read_bytes())}
    if member:d['member']=member
    return d

def archive(name,files,mode=0o644):
    require(not (OUT/name).exists(),'Archive already exists: '+name);hashes={};origins={}
    with (OUT/name).open('wb') as target:
        with gzip.GzipFile(filename='',mode='wb',fileobj=target,compresslevel=9,mtime=0) as gz:
            with tarfile.open(fileobj=gz,mode='w|',format=tarfile.GNU_FORMAT) as tar:
                for name,value in sorted(files.items()):
                    if isinstance(value,Path):data=value.read_bytes();origins[name]=str(value)
                    else:data=value
                    member=tarfile.TarInfo(name);member.size=len(data);member.uid=member.gid=member.mtime=0;member.uname=member.gname='';member.mode=mode;tar.addfile(member,io.BytesIO(data));hashes[name]=sha(data)
    return {'files':hashes,'origins':origins,'mode':mode}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--input',type=Path,default=RAW);parser.add_argument('--finalize',action='store_true');args=parser.parse_args();raw=args.input
    require(sorted(os.sched_getaffinity(0))==[0],'Run packing on CPU0')
    source=json.loads((raw/'source-freeze.json').read_bytes());final=json.loads((raw/'final-tool-source.json').read_bytes())
    for directory,expected in [('common-source',source['common_source_sha256']),('final-tool-source',final['sha256'])]:
        require({str(p.relative_to(raw/directory)):sha(p.read_bytes()) for p in (raw/directory).rglob('*') if p.is_file()}==expected,'Frozen source changed: '+directory)
    require(len(json.loads((raw/'events.json').read_bytes()))==144 and json.loads((raw/'producer-validation.json').read_bytes())['physical_sampling']['total_samples']==9512,'Terminal producer data required')
    if not args.finalize:print('Frozen terminal inputs valid; no archive writes');return
    binding={'schema':'vort.deflate.pmu-archive-bindings.v1','base_revision':BASE,'raw_root':str(raw),'archives':{},'archive_cpu':0,'policy':'sorted GNU tar; regular0644/probes0755; uid/gid/mtime0; empty owners; gzip level9/empty name/mtime0','reuse':{
        'baseline_source':reused('docs/performance/br/decode-mozilla-distributions-20261112/shared-dispatch-source.tar.gz'),
        'public_overlay':reused('docs/performance/deflate/public-linear-contracts-20261112/source-overlay.tar.gz'),
        'wide_overlay':reused('docs/performance/deflate/wide-copy-contracts-20261112/final-boundary-source-overlay.tar.gz'),
        'holes_overlay':reused('docs/performance/deflate/distance-secondary-holes-20261112/final-source-overlay.tar.gz'),
        'owner_word_overlay':reused('docs/performance/deflate/mapped-owner-handoff-20261112/timing-source-overlay.tar.gz'),
        'owner_only_overlay':reused('docs/performance/deflate/mapped-owner-handoff-20261112/owner-only-source-overlay.tar.gz'),
        'reference_libraries':reused('docs/performance/modern-decode-current-20261111/reference-libraries.tar.gz')}}
    for directory in ['common-source','final-tool-source']:
        binding['archives'][directory+'.tar.gz']=archive(directory+'.tar.gz',{str(p.relative_to(raw/directory)):p for p in (raw/directory).rglob('*') if p.is_file()})
    top={p.name:p for p in raw.iterdir() if p.is_file() and p.name not in ['baseline-compare','owner-word-compare','owner-only-compare']}
    binding['archives']['raw-diagnostics.tar.gz']=archive('raw-diagnostics.tar.gz',top)
    binding['archives']['probes.tar.gz']=archive('probes.tar.gz',{n:raw/n for n in ['baseline-compare','owner-word-compare','owner-only-compare']},0o755)
    binding['archives']['rows.tar.gz']=archive('rows.tar.gz',{str(p.relative_to(raw/'rows')):p for p in (raw/'rows').rglob('*') if p.is_file()})
    binding['archives']['branch-sampling.tar.gz']=archive('branch-sampling.tar.gz',{str(p.relative_to(raw/'branch-sampling')):p for p in (raw/'branch-sampling').rglob('*') if p.is_file()})
    base_blobs={'tools/decode/fixtures.py':subprocess.check_output(['git','show',BASE+':tools/decode/fixtures.py'],cwd=ROOT)}
    # Import support lives outside the common10 measurement overlay. Preserve
    # the exact existing source bytes, including the fixtures helper, explicitly.
    names=['tools/decode/fixtures.py','tools/decode/evidence.py','tools/decode/matrix.py','tools/decode/pmu_evidence.py']
    helpers={n:(raw/'common-source'/n if n in source['common_source_sha256'] else base_blobs[n]) for n in names}
    binding['archives']['runner-imports.tar.gz']=archive('runner-imports.tar.gz',helpers)
    for n in ['source-freeze.json','probe-freeze.json','final-tool-source.json','producer-validation.json','paired-summary.json','copy-loop-analysis.json']:(OUT/n).write_bytes((raw/n).read_bytes())
    commit=subprocess.check_output(['git','rev-parse','07523cb9'],cwd=ROOT,text=True).strip()
    for n,h in final['sha256'].items():require(sha(subprocess.check_output(['git','show',commit+':'+n],cwd=ROOT))==h,'Saved final-tool Git source differs')
    write(OUT/'saved-tool-commit.json',{'artifact_kind':'later final-tool Git identity; original measured common10 remains a separate earlier source epoch','commit':commit,'sha256':final['sha256'],'post_measurement_changes':final['changed_since_measured_common_source']})
    binding['final_tool_commit']=commit;binding['scope']={'original_common_files':10,'final_tool_files':10,'measurement_source_not_rebound':True,'counter_event_count':96,'wall_event_count':48,'physical_records':4,'physical_sample_count':9512,'no_codec_prototype_adopted':True,'ordinary_fixtures_not_duplicated':True}
    # Capture only the four diagnostic fixtures and other-codec smoke fields.
    protocol=json.loads((raw/'protocol.json').read_bytes());fixtures={t['fixture']['key']:t['fixture'] for t in protocol['tasks']}
    for e in json.loads((raw/'codec-pmu-smoke.json').read_bytes())['events']:fixtures[e['task']['fixture']['key']]=e['task']['fixture']
    files={}
    for fixture in fixtures.values():
        for n,h,bn in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:files[fixture[n]]={'sha256':fixture[h],'bytes':fixture[bn]}
    write(OUT/'fixture-fields.json',{'artifact_kind':'original task fixture field registry; ordinary bytes external, no regeneration','four_deflate_cases':len(protocol['tasks']),'fixtures':list(fixtures.values()),'files':files,'scope':'only these four diagnostic cases and other-codec smoke inputs; no complete corpus fixture sweep'})
    write(OUT/'archive-bindings.json',binding)
    print(json.dumps({'archives':len(binding['archives']),'fixture_tasks':len(fixtures),'external_files':len(files),'final_tool_commit':commit},indent=2))
if __name__=='__main__':main()
