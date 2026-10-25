from pathlib import Path
import json,hashlib,subprocess,sys
root=Path(__file__).resolve().parent
kind=sys.argv[1]
setup=json.loads((root/'setup.json').read_text())
tree=Path(setup['worktrees'][kind])
source_expected=setup['source_expected']
paths=sorted((tree/'src').rglob('*.zig'))
before={str(p.relative_to(tree)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
assert before['src/zstd.zig']==source_expected[kind]
(root/(kind+'-source-before.json')).write_text(json.dumps(before,indent=2)+'\n')
zig='/home/passchaos/Temp/zig-x86_64-linux-0.16.0/zig'
object_path=root/(kind+'-x2.o')
obj=['taskset','-c','13-15',zig,'build-obj',str(tree/'src/zstd_huffman_x2_object.zig'),'-O','ReleaseFast','-mcpu=native','-femit-bin='+str(object_path)]
exe=['taskset','-c','13-15',zig,'build-exe',str(object_path),'-O','ReleaseFast','-mcpu=native','--dep','vort_zstd','-Mroot='+str(root/'probe.zig'),'-O','ReleaseFast','-mcpu=native','-Mvort_zstd='+str(tree/'src/zstd.zig'),'-femit-bin='+str(root/('probe-'+kind))]
commands=[]
for command in [obj,exe]:
 p=subprocess.run(command,cwd=tree,capture_output=True,text=True)
 commands.append({'command':command,'exit':p.returncode,'output':p.stdout+p.stderr})
 if p.returncode:break
after={str(p.relative_to(tree)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
result={'kind':kind,'commands':commands,'source_stable':before==after,'source_sha256':before['src/zstd.zig'],'object_source_sha256':before['src/zstd_huffman_x2_object.zig']}
(root/(kind+'-build.json')).write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
