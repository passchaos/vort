#!/usr/bin/env python3
"""Small general Brotli Large Window, metadata and total-budget CLI contracts."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
from large_window_cli_gate import LargeWindowReference, assert_extension_prefix
from hq_cli_gate import Reference
from total_memory_cli_gate import memory_profile


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cli',required=True,type=Path);a=p.parse_args();cli=a.cli.resolve()
    standard=Reference();large=LargeWindowReference();plain=b'window metadata repeated text repeated text!!'
    counts={'reference_round_trips':0,'extension_header_checks':0,'non_hq_policy_checks':0,'profile_wire_checks':0,'metadata_checks':0,'standard_default_wire_checks':0,'stored_positional_wire_checks':0,'exact_total_cap_checks':0,'below_total_cap_checks':0,'rejected_output_preserved':0,'same_path_checks':0}
    rows=[]
    with tempfile.TemporaryDirectory(prefix='vort-br-general-cli-') as name:
        folder=Path(name);source=folder/'input.raw';target=folder/'output.br';source.write_bytes(plain)
        def run(command,flags,input=source,output=target):return subprocess.run([str(cli),command,str(input),str(output),*flags],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        def okay(command,flags,width,large_window=True):
            r=run(command,flags);assert r.returncode==0,(command,flags,r.stderr.decode(errors='replace'))
            data=target.read_bytes()
            if large_window:
                assert_extension_prefix(data,width);large.decode(data,plain,True);large.decode(data,plain,False);counts['extension_header_checks']+=1
            else: standard.decode(data,plain)
            assert b'caller-meta' in data, 'metadata was ignored'
            assert b'br_hq_profile ' not in r.stdout
            counts['reference_round_trips']+=1;counts['metadata_checks']+=1
            return data,r.stdout
        def fail(command,flags,input=source,output=target,error=None):
            sentinel=plain if input==output else b'existing bytes must survive'
            output.write_bytes(sentinel);r=run(command,flags,input,output);assert r.returncode!=0 and output.read_bytes()==sentinel
            if error:assert error.encode() in r.stderr,r.stderr
            counts['rejected_output_preserved']+=1
        for command in ('encode-br-file','encode-br-stream-file'):
            default,_=okay(command,['--metadata=caller-meta'],16,False);profiled,_=okay(command,['--metadata=caller-meta','--memory-profile'],16,False);assert default==profiled;counts['standard_default_wire_checks']+=1
            for quality,width in ((None,25),(0,16),(1,25),(5,30),(11,25)):
                flags=['--large-window',f'--window-bits={width}','--metadata=caller-meta']+([] if quality is None else [f'--quality={quality}'])
                untracked,_=okay(command,flags,width);tracked,log=okay(command,list(reversed(flags))+['--memory-profile'],width)
                assert untracked==tracked;info=memory_profile(log);assert info['available'] and info['live_requested_bytes']==0
                counts['profile_wire_checks']+=1;counts['non_hq_policy_checks']+=1
                if quality==5:
                    peak=info['peak_requested_bytes'];exact,_=okay(command,flags+[f'--max-total-memory={peak}'],width);assert exact==tracked
                    counts['exact_total_cap_checks']+=1;fail(command,flags+[f'--max-total-memory={peak-1}'],error='WorkingMemoryLimitExceeded');counts['below_total_cap_checks']+=1
                rows.append({'command':command,'quality':quality,'window_bits':width,'bytes':len(tracked),'peak_requested_bytes':info['peak_requested_bytes']})
            for flags in (['--large-window','--window-bits=31'],['--window-bits=25'],['--large-window','--large-window'],['--quality=12','--large-window']):fail(command,flags)
            fail(command,['--large-window','--window-bits=31'],folder/'missing.raw',error='InvalidBlockPlan')
            fail(command,['--large-window','--max-total-memory=0'],error='WorkingMemoryLimitExceeded')
            fail(command,['--large-window','--window-bits=31'],source,source,error='InvalidBlockPlan');counts['same_path_checks']+=1;source.write_bytes(plain)
            r=run(command,['--quality=0','--large-window','--window-bits=25'],source,source);assert r.returncode==0;large.decode(source.read_bytes(),plain,True);counts['reference_round_trips']+=1;counts['same_path_checks']+=1;source.write_bytes(plain)
        for width in (16,25,30):
            okay('encode-br-stored-file',[str(width),'caller-meta','--large-window'],width)
        old,_=okay('encode-br-stored-file',['16','caller-meta'],16,False);named,_=okay('encode-br-stored-file',['--window-bits=16','--metadata=caller-meta'],16,False);assert old==named;counts['stored_positional_wire_checks']+=1
        fail('encode-br-stored-file',['--large-window','--max-total-memory=0'],error='UnsupportedBrotliStoredOption')
        fail('encode-br-stored-file',['--large-window','--window-bits=31'],error='InvalidBlockPlan')
        # Existing legal HQ configurations remain explicit and independent.
        for command in ('encode-br-file','encode-br-stream-file'):
            flags=['--quality=10','--hq','--hq-depth=2','--hq-beam-width=1','--hq-iterations=1','--large-window','--window-bits=25','--metadata=caller-meta']
            okay(command,flags,25)
    print(json.dumps({**counts,'rows':rows,'reference_brotli_version':standard.version}))
if __name__=='__main__':main()
