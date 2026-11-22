import argparse
import ctypes as c
import hashlib
import json
from pathlib import Path


class Stream(c.Structure):
    _fields_ = [
        ('next_in', c.c_void_p), ('avail_in', c.c_uint), ('total_in', c.c_ulong),
        ('next_out', c.c_void_p), ('avail_out', c.c_uint), ('total_out', c.c_ulong),
        ('msg', c.c_char_p), ('state', c.c_void_p),
        ('zalloc', c.c_void_p), ('zfree', c.c_void_p), ('opaque', c.c_void_p),
        ('data_type', c.c_int), ('adler', c.c_ulong), ('reserved', c.c_ulong),
    ]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    folder = Path('/tmp/vort-codec-differential-reporting-20261120/deep-artifacts')
    manifest = json.loads((folder / 'manifest.json').read_text())
    ng_path = Path('/home/passchaos/Work/zlib-ng/build-vort/libz.so.1.3.2.zlib-ng')
    ld_path = Path('/home/passchaos/Work/libdeflate/build-vort/libdeflate.so.0')
    mode = c.RTLD_LOCAL | getattr(c, 'RTLD_DEEPBIND', 0)
    ng = c.CDLL(str(ng_path), mode=mode)
    ng.zlibVersion.restype = c.c_char_p
    ng.inflateInit2_.argtypes = [c.POINTER(Stream), c.c_int, c.c_char_p, c.c_int]
    ng.inflateInit2_.restype = c.c_int
    ng.inflate.argtypes = [c.POINTER(Stream), c.c_int]
    ng.inflate.restype = c.c_int
    ng.inflateEnd.argtypes = [c.POINTER(Stream)]
    ld = c.CDLL(str(ld_path), mode=mode)
    ld.libdeflate_alloc_decompressor.restype = c.c_void_p
    ld.libdeflate_free_decompressor.argtypes = [c.c_void_p]
    for name in ['libdeflate_deflate_decompress', 'libdeflate_gzip_decompress']:
        fn = getattr(ld, name)
        fn.argtypes = [c.c_void_p, c.c_void_p, c.c_size_t, c.c_void_p, c.c_size_t, c.POINTER(c.c_size_t)]
        fn.restype = c.c_int
    rows = []
    for index in [13, 14]:
        sample = manifest['samples'][index]
        for label in ['original_wire', 'mutated_wire']:
            record = sample[label]
            data = (folder / record['path']).read_bytes()
            assert hashlib.sha256(data).hexdigest() == record['sha256']
            capacity = sample['reference_output_capacity']
            src = c.create_string_buffer(data)
            dst = c.create_string_buffer(capacity)
            stream = Stream()
            init = ng.inflateInit2_(c.byref(stream), -15 if sample['info']['codec'] == 'raw' else 31, ng.zlibVersion(), c.sizeof(Stream))
            assert init == 0, init
            try:
                stream.next_in = c.addressof(src)
                stream.avail_in = len(data)
                stream.next_out = c.addressof(dst)
                stream.avail_out = capacity
                result = ng.inflate(c.byref(stream), 4)
                ng_result = {
                    'result_code': result,
                    'error_message': stream.msg.decode() if stream.msg else None,
                    'input_consumed': stream.total_in,
                    'input_remaining': stream.avail_in,
                    'output_bytes': stream.total_out,
                }
            finally:
                ng.inflateEnd(c.byref(stream))
            decoder = ld.libdeflate_alloc_decompressor()
            assert decoder
            try:
                actual = c.c_size_t()
                fn = ld.libdeflate_deflate_decompress if sample['info']['codec'] == 'raw' else ld.libdeflate_gzip_decompress
                result = fn(decoder, src, len(data), dst, capacity, c.byref(actual))
                ld_result = {'result_code': result, 'output_bytes_on_success': actual.value if result == 0 else None}
            finally:
                ld.libdeflate_free_decompressor(decoder)
            row = {'sample': index, 'codec': sample['info']['codec'], 'wire_kind': label, 'wire_sha256': record['sha256'], 'capacity': capacity, 'zlib_ng': ng_result, 'libdeflate': ld_result}
            if label == 'original_wire':
                assert ng_result['result_code'] == 1 and ld_result['result_code'] == 0
            else:
                assert ng_result['result_code'] == -3 and ld_result['result_code'] == 1
            rows.append(row)
            print(json.dumps(row))
    args.output.write_text(json.dumps({
        'zlib_ng_runtime': ng.zlibVersion().decode(),
        'artifact_sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [ng_path, ld_path]},
        'libdeflate_version_scope': 'Loaded artifact identity; no runtime version API asserted.',
        'capture_manifest_sha256': hashlib.sha256((folder / 'manifest.json').read_bytes()).hexdigest(),
        'samples': rows,
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
