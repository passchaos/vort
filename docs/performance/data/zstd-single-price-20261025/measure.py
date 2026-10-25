from pathlib import Path
import datetime, hashlib, json, os, subprocess, sys, time

base = Path('/tmp/vort-zstd-single-price-20261025')
root = Path('/home/passchaos/project-z/vort-zstd-single-price')
name, executable, mode = sys.argv[1:4]
out = base / name
out.mkdir(parents=True, exist_ok=True)
prep = json.loads(Path('/tmp/vort-current-encode-baseline-20261025/preparation.json').read_text())
inputs = prep['selected_inputs']
if mode != 'wire14':
    labels = ('silesia-xml', 'silesia-mr') if mode == 'profile' else ('silesia-xml', 'brotli-source')
    inputs = [p for p in inputs if p['label'] in labels]
reference = Path('/home/passchaos/Work/zstd/lib/obj/conf_5c583a1f84006a106cd7292ce5d65f11/dynamic/libzstd.so.1.6.0')
def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def source():
    source_root = Path('/home/passchaos/project-z/vort-zstd-wide-reduction') if 'vort-zstd-wide-reduction/.zig-cache/' in executable else root
    paths = list((source_root/'src').rglob('*.zig'))+[source_root/'build.zig']+list((source_root/'tools/zstd').glob('*.zig'))
    return {str(p.relative_to(source_root)):sha(p) for p in paths}
before = source()
for p in inputs:
    assert sha(p['frozen_path']) == p['input_sha256']
command = ['taskset', '-c', '8', executable]
if mode == 'profile':
    command += [p['frozen_path'] for p in inputs]
else:
    command += ['--level','3','--iterations','1','--rounds','5',
                '--limit','65536','--libzstd',str(reference),'--samples-json',str(out/'samples.json'),
                '--csv',str(out/'samples.csv')]
    for p in inputs: command += ['--path',p['frozen_path']]
metadata = {'command': command, 'mode': mode, 'source_before': before, 'inputs': inputs,
            'reference_sha256': sha(reference), 'executable_sha256': sha(executable),
            'start_utc': datetime.datetime.now(datetime.timezone.utc).isoformat()}
(out/'running.json').write_text(json.dumps(metadata,indent=2)+'\n')
monitors = []
start = time.monotonic()
with (out/'run.log').open('wb') as log:
    process = subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
    while True:
        compiler = subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()
        monitors.append({'monotonic_ns':time.monotonic_ns(),'compilers':compiler})
        try:
            code = process.wait(timeout=0.2)
            break
        except subprocess.TimeoutExpired:
            pass
after = source()
metadata.update(exit_code=code, wall_seconds=time.monotonic()-start,
                end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(), source_after=after,
                source_stable=before==after, reference_stable=sha(reference)==metadata['reference_sha256'],
                executable_stable=sha(executable)==metadata['executable_sha256'],
                compiler_observations=len(monitors), compiler_observations_with_process=sum(bool(x['compilers']) for x in monitors))
(out/'compiler-monitor.json').write_text(json.dumps(monitors)+'\n')
(out/'result.json').write_text(json.dumps(metadata,indent=2)+'\n')
print(json.dumps({k:v for k,v in metadata.items() if not k.startswith('source_') and k!='inputs'}),flush=True)
if code or before!=after or not metadata['reference_stable'] or not metadata['executable_stable'] or metadata['compiler_observations_with_process']:
    raise SystemExit(1)
