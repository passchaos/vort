#!/usr/bin/env python3
"""Verify frozen Reymont profile bytes offline; run with taskset -c 0."""
import argparse
import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import re
import statistics
import subprocess
import tarfile

BASE = "8adfb3bae74409bae146fed2ed9b6594a1d3cdb8"


def require(value, message):
    if not value:
        raise ValueError(message)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def unpack(path, links=False):
    data = path.read_bytes(); require(data[:4] == b"\x1f\x8b\x08\x00" and data[4:8] == bytes(4), "Gzip header differs")
    files, symlinks = {}, {}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)), mode="r:") as archive:
        members = archive.getmembers(); require([m.name for m in members] == sorted({m.name for m in members}), "Archive order differs")
        for member in members:
            require(not member.name.startswith("/") and ".." not in Path(member.name).parts and member.uid == member.gid == member.mtime == 0 and member.uname == member.gname == "", "Archive metadata differs")
            if links and member.issym():
                require('/' not in member.linkname and member.linkname != '..', "Unsafe SONAME link"); symlinks[member.name] = member.linkname
            else:
                require(member.isfile(), "Unexpected archive member"); files[member.name] = archive.extractfile(member).read()
    require(all(str(Path(name).parent / target) in files for name, target in symlinks.items()), "Dangling SONAME link")
    return files


def verify(root, baseline_package, reference_archive, originals=False, git_repo=None):
    checksum = root / "SHA256SUMS"
    if checksum.exists():
        hashes = {name: digest for digest, name in (line.split('  ', 1) for line in checksum.read_text().splitlines())}
        require(set(hashes) == {p.name for p in root.iterdir() if p.is_file() and p != checksum} and all(sha((root / name).read_bytes()) == digest for name, digest in hashes.items()), "Final checksum inventory differs")
    binding = json.loads((root / "archive-bindings.json").read_text()); require(binding["base_revision"] == BASE, "Profile rebound after tests")
    archives, original_count = {}, 0
    for name, record in binding["archives"].items():
        files = unpack(root / name); require({name: sha(data) for name, data in files.items()} == record["files"], "Archived byte identity differs"); archives[name] = files
        if originals:
            for member, origin in record["origins"].items():
                require(Path(origin).read_bytes() == files[member], "Original retained bytes differ"); original_count += 1
    raw, fixtures, deps = [archives[name] for name in ("raw-profile.tar.gz", "fixture-bytes.tar.gz", "runner-dependencies.tar.gz")]
    document = json.loads(raw["manifest.json"]); manifest, task = document["manifest"], document["task"]
    source = manifest["source"]; require(source["revision"] == BASE and len(source["sha256"]) == 2062 and sha(json.dumps(source["sha256"], sort_keys=True).encode()) == source["digest"], "Profile source registry differs")
    reuse = binding["reuse"]; sp = baseline_package / 'shared-dispatch-source.tar.gz'; bp = baseline_package / 'probe-binaries.tar.gz'
    require(sha(sp.read_bytes()) == reuse["source_archive_sha256"] and sha(bp.read_bytes()) == reuse["binary_archive_sha256"] and sha(reference_archive.read_bytes()) == reuse["reference_archive_sha256"], "Reused containers differ")
    base = {name.removeprefix(reuse["source_prefix"]): data for name, data in unpack(sp).items()}
    require({name: sha(data) for name, data in base.items()} == source["sha256"], "Reused 2062 source bytes differ")
    binary = unpack(bp)[reuse["binary_member"]]; require(sha(binary) == reuse["binary_sha256"] == manifest["probe_sha256"], "Byte-equivalent profile probe differs")
    refs = unpack(reference_archive, links=True); require(sha(refs[reuse["reference_member"]]) == reuse["reference_sha256"], "Reference shared library differs")
    for name in ('evidence.py', 'fixtures.py'): require(deps[name] == base['tools/decode/' + name], "Imported capture dependency differs")
    require(json.loads(deps['seed-manifest.json'])['manifest']['source']['sha256'] == source['sha256'], "Original seed dependency differs")
    capture = json.loads(raw['capture-validation.json']); require((root/'capture-validation.json').read_bytes() == raw['capture-validation.json'] and capture['returncode'] == 0 and capture['raw_json_valid'] is True, "Capture validation differs")
    for member, key in [('reymont-64k-L6.data','profile_sha256'),('stdout.raw','stdout_sha256'),('stderr.raw','stderr_sha256'),('capture.py','capture_script_sha256')]: require(sha(raw[member]) == capture[key], "Capture artifact hash differs")
    require(capture['probe_sha256'] == sha(binary) and capture['source_files'] == 2062, "Capture source/probe binding differs")
    execution = json.loads(raw['execution.json']); require(execution['argv'] == json.loads(raw['command.json']) == document['argv'] and execution['returncode'] == 0 and not execution['before']['compilers'] and not execution['after']['compilers'], "Recorded command/exit differs")
    require('199' in execution['argv'] and 'cycles:u' in execution['argv'] and 'dwarf,65528' in execution['argv'], "Sampling policy differs")
    fixture = task['fixture']; require(fixture['key'] == 'deflate/reymont/65536/6' and task['iterations'] == 30000 and task['lifecycle'] == 'cold', "Profile workload differs")
    for path_key, hash_key in [('input_path','input_sha256'),('encoded_input_path','encoded_sha256')]:
        require(sha(fixtures[Path(fixture[path_key]).name]) == fixture[hash_key], "Small retained fixture differs")
    probe = json.loads(raw['stdout.raw']); require(probe['schema'] == 'vort.decode-compare.v1' and probe['codec'] == 'deflate' and probe['lifecycle_match'] == 'matched-cold', "Public probe schema differs")
    require(probe['vort_api'] == 'decodeRawDeflate' and probe['reference_api'] == 'libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor', "Cold API lifecycle differs")
    for key in ['input_path','encoded_input_path','input_bytes','encoded_bytes','input_sha256','encoded_sha256']: require(probe[key] == fixture[key], "Reported fixture differs")
    reference = manifest['references']['deflate']; require(probe['reference_version'] == reference['version'] == '1.26' and probe['reference_version_origin'] == 'declared-pinned-header', "Reference version differs")
    require(probe['reference_paths'] == [reference['path']] and {p for p in probe['loaded_shared_library_paths'] if Path(p).name.startswith('libdeflate.so')} == {reference['path']}, "Mapped reference closure differs")
    require(probe['exact_consumption'] == {'vort':True,'reference':True} and all(probe['validation'][key] is True for key in ['every_iteration_count','full_output_per_batch','guards_per_batch','input_unchanged_per_batch','exact_consumption_per_batch']), "Validation/consumption coverage missing")
    require(probe['alignment'] == {'guard_bytes':64,'input_mod64':0,'encoded_mod64':0,'vort_output_mod64':0,'reference_output_mod64':0}, "Alignment differs")
    provenance = probe['provenance']; require(provenance['executable_sha256'] == sha(binary) and provenance['optimize'] == 'ReleaseFast' and provenance['zig_version'] == '0.16.0' and provenance['target_cpu'] == 'skylake+pku+sgx' and provenance['cpu_affinity'] == '15' and provenance['benchmark_threads'] == provenance['affinity_cpu_count'] == 1, "Recorded target/thread provenance differs")
    require(probe['iterations'] == 30000 and probe['rounds'] == probe['warmup'] == 2, "Raw pair counts differ")
    for field, start in [('warmup_pairs',0),('pairs',2)]:
        require(len(probe[field]) == 2, "Missing pair")
        for index,pair in enumerate(probe[field]):
            require(pair['pair_id'] == start+index and pair['first'] == ('vort' if index==0 else 'reference') and pair['vort_mix'] == pair['reference_mix'] == 30000*(fixture['input_bytes']+fixture['input_first_byte']), "Order/output count differs")
    for side in ['vort','reference']: require(probe['summary'][side+'_median_ns'] == statistics.median(p[side+'_ns'] for p in probe['pairs']), "Raw median differs")
    require(raw['reymont-64k-L6.data'][:8] == b'PERFILE2' and b'(2681 samples)' in raw['stderr.raw'] and raw['symbols-physical.stderr'] == b'', "Perf recording/report differs")
    physical = raw['symbols-physical.txt']; require(b'Event count (approx.): 65407305645' in physical and b'Total Lost Samples: 0' in physical, "Whole-process report totals differ")
    require(re.search(rb'58\.02%.*deflate\.semantic\.linear_entry\.aligned',physical) and re.search(rb'36\.53%.*deflate_decompress_bmi2',physical), "Physical symbol percentages differ")
    git_count = 0
    if git_repo:
        names=list(base); r=subprocess.run(['git','cat-file','--batch'],cwd=git_repo,input=''.join(BASE+':'+n+'\n' for n in names).encode(),capture_output=True,check=True);offset=0
        for name in names:
            end=r.stdout.index(b'\n',offset);header=r.stdout[offset:end].split();require(len(header)==3 and header[1]==b'blob','Missing frozen Git blob');size=int(header[2]);offset=end+1
            require(r.stdout[offset:offset+size]==base[name],'Profile Git source blob differs');offset+=size+1;git_count+=1
    if originals: require(Path(binding['baseline_binary_original']).read_bytes()==binary,'Original profile binary differs')
    return {'schema':'vort.deflate.reymont-profile-archive-validation.v1','valid':True,'scope':'independent raw-byte/source/probe/reference/recorded-statistics verification; no compiler, codec or sampling rerun','cpu_affinity':sorted(os.sched_getaffinity(0)),'profile_revision':BASE,'source_files':2062,'baseline_git_blobs_verified':git_count,'original_files_verified':original_count,'fixture_bytes':sum(len(v) for v in fixtures.values()),'iterations':30000,'warmup_pairs':2,'measured_pairs':2,'perf_samples':2681,'whole_process_period':65407305645,'whole_process_physical_percentages':{'vort_kernel':58.02,'reference_kernel':36.53},'public_root_denominator_complete':False,'codec_heap_measured':False,'profile_clocks_are_acceptance_samples':False,'profile_frozen_before_test_overlay':True}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--baseline-package',type=Path);parser.add_argument('--reference-archive',type=Path);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);args=parser.parse_args();root=Path(__file__).resolve().parent
    baseline=args.baseline_package or root.parents[1]/'br/decode-mozilla-distributions-20261112';reference=args.reference_archive or root.parents[1]/'modern-decode-current-20261111/reference-libraries.tar.gz'
    print(json.dumps(verify(root,baseline,reference,args.originals,args.git_repo),indent=2))


if __name__=='__main__': main()
