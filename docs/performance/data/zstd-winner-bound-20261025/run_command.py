from pathlib import Path
import datetime, hashlib, json, re, subprocess, sys, time

root = Path('/home/passchaos/project-z/vort-zstd-cost-bound')
base = Path('/tmp/vort-zstd-cost-bound-20261025')
name, *command = sys.argv[1:]
out = base / name
out.mkdir(parents=True, exist_ok=True)

def snapshot():
    paths = [p for p in (root / 'src').rglob('*') if p.is_file()]
    paths += [root / 'build.zig', root / 'build.zig.zon']
    paths += list((root / 'tools/zstd').glob('*.zig'))
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}

before = snapshot()
started = datetime.datetime.now(datetime.timezone.utc).isoformat()
start = time.monotonic()
with (out / 'run.log').open('wb') as log:
    result = subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT)
after = snapshot()
log = (out / 'run.log').read_bytes()
data = {'command': command, 'cwd': str(root), 'start_utc': started,
        'end_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'wall_seconds': time.monotonic()-start, 'exit_code': result.returncode,
        'source_before': before, 'source_after': after, 'source_stable': before==after,
        'passed_test_counts': re.findall(rb'All (\d+) tests passed\.', log),
        'build_summary': re.findall(rb'Build Summary: ([^\n]+)', log),
        'log_sha256': hashlib.sha256(log).hexdigest()}
data['passed_test_counts'] = [int(n) for n in data['passed_test_counts']]
data['build_summary'] = [s.decode() for s in data['build_summary']]
(out / 'result.json').write_text(json.dumps(data, indent=2)+'\n')
print(json.dumps({k:v for k,v in data.items() if not k.startswith('source_')}), flush=True)
if result.returncode:
    print(log.decode(errors='replace')[-10000:], flush=True)
    raise SystemExit(result.returncode)
if before != after:
    raise SystemExit('sources changed during command')
