#!/usr/bin/env python3
"""Small Zstd CLI window/history controls and whole-encoder budget verification."""
import argparse
import ctypes
import json
from pathlib import Path
import subprocess
import tempfile
from hq_controls_cli_gate import Reference


def memory_profile(log):
    line=next(v for v in log.decode().splitlines() if v.startswith('zstd_memory_profile '));fields=dict(v.split('=',1) for v in line.split()[1:])
    return {k:(v=='true' if v in ('true','false') else None if v=='unlimited' else int(v)) for k,v in fields.items()}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--cli',required=True,type=Path);a=p.parse_args();cli=a.cli.resolve();reference=Reference();plain=b'0123456789abcdef--repeat--0123456789abcdef!!'
    counts={'reference_round_trips':0,'memory_profile_wire_checks':0,'window_descriptor_checks':0,'exact_total_cap_checks':0,'below_total_cap_checks':0,'rejected_output_preserved':0,'same_path_checks':0,'known_content_single_segment_checks':0,'wide_header_checks':0,'wide_memory_profile_checks':0,'reference_window_limit_rejections':0}
    rows=[]
    with tempfile.TemporaryDirectory(prefix='vort-zstd-window-memory-') as name:
        folder=Path(name);source=folder/'input.raw';target=folder/'output.zst';source.write_bytes(plain)
        def run(command,flags,input=source,output=target):return subprocess.run([str(cli),command,str(input),str(output),*flags],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        def okay(command,flags):
            r=run(command,flags);assert r.returncode==0,(command,flags,r.stderr.decode(errors='replace'));data=target.read_bytes();reference.decode(data,plain);counts['reference_round_trips']+=1;return data,r.stdout
        def fail(command,flags,input=source,output=target,error=None):
            sentinel=plain if input==output else b'preserve destination on rejected options';output.write_bytes(sentinel);r=run(command,flags,input,output);assert r.returncode!=0 and output.read_bytes()==sentinel
            if error:assert error.encode() in r.stderr,r.stderr
            counts['rejected_output_preserved']+=1
        for command in ('encode-zstd-native-file','encode-zstd-level-file','encode-zstd-native-stream-file'):
            for flags in ([],['--window-log=10','--max-match-history-len=1024'],['auto','true','false','--window-log=25','--max-match-history-len=67108865'],['--window-log=41','--max-match-history-len=1024'],['--strategy=fast','--window-log=20','--max-match-history-len=65536']):
                first,_=okay(command,flags);second,log=okay(command,flags+['--memory-profile']);assert first==second;info=memory_profile(log);assert info['available'] and info['peak_requested_bytes']>0 and info['live_requested_bytes']==0
                counts['memory_profile_wire_checks']+=1
                if '--window-log=25' in flags:
                    assert second[4]&0x20==0 and second[5]>>3==15;counts['window_descriptor_checks']+=1
                if '--window-log=41' in flags:
                    assert second[4]&0x20 and second[5]==len(plain);counts['known_content_single_segment_checks']+=1
                if flags==['--window-log=10','--max-match-history-len=1024']:
                    B=info['peak_requested_bytes'];exact,_=okay(command,flags+[f'--max-total-memory={B}']);assert exact==first;counts['exact_total_cap_checks']+=1
                    fail(command,flags+[f'--max-total-memory={B-1}'],error='WorkingMemoryLimitExceeded');counts['below_total_cap_checks']+=1
                rows.append({'command':command,'options':flags,'peak_requested_bytes':info['peak_requested_bytes']})
            # With no content size, Window_Log41 is explicit metadata. The
            # installed reference decoder rejects its advertised window before
            # decoding; this is distinct from the local 1024-byte match cap.
            wide_flags=['auto','true','false','--window-log=41','--max-match-history-len=1024','--memory-profile']
            wide=run(command,wide_flags);assert wide.returncode==0,wide.stderr
            frame=target.read_bytes();assert frame[4]&0x20==0 and frame[5]>>3==31
            counts['wide_header_checks']+=1
            wide_memory=memory_profile(wide.stdout);assert wide_memory['available'] and wide_memory['peak_requested_bytes']>0 and wide_memory['live_requested_bytes']==0
            counts['wide_memory_profile_checks']+=1
            reference.library.ZSTD_getErrorName.argtypes=(ctypes.c_size_t,)
            reference.library.ZSTD_getErrorName.restype=ctypes.c_char_p
            src=ctypes.create_string_buffer(frame);dst=ctypes.create_string_buffer(len(plain))
            result=reference.library.ZSTD_decompress(dst,len(plain),src,len(frame))
            assert reference.library.ZSTD_isError(result)
            assert reference.library.ZSTD_getErrorName(result).decode()=='Frame requires too much memory for decoding'
            counts['reference_window_limit_rejections']+=1
            for flags in (['--window-log=9'],['--window-log=42'],['--max-match-history-len=1024'],['--window-log=10','--max-match-history-len=1023'],['--window-log=41','--max-match-history-len=4294836223'],['--memory-profile','--memory-profile'],['--max-total-memory=1','--max-total-memory=2']):fail(command,flags)
            fail(command,['--window-log=42'],folder/'absent.raw',error='InvalidBlockPlan');fail(command,['--max-total-memory=0'],error='WorkingMemoryLimitExceeded')
            fail(command,['--window-log=42'],source,source,error='InvalidBlockPlan');counts['same_path_checks']+=1;source.write_bytes(plain)
            r=run(command,['--window-log=10','--max-match-history-len=1024'],source,source);assert r.returncode==0;reference.decode(source.read_bytes(),plain);counts['reference_round_trips']+=1;counts['same_path_checks']+=1;source.write_bytes(plain)
    print(json.dumps({**counts,'rows':rows,'reference_zstd':reference.version}))
if __name__=='__main__':main()
