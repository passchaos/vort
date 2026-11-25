import argparse
import ctypes as c
import ctypes.util
import hashlib
import json
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def load_library(mode):
    if mode == 'modern':
        folder = Path('/home/passchaos/Work/brotli/build-vort')
        common = c.CDLL(str(folder / 'libbrotlicommon.so.1.2.0'), mode=c.RTLD_GLOBAL)
        lib = c.CDLL(str(folder / 'libbrotlidec.so.1.2.0'))
    else:
        common = c.CDLL(ctypes.util.find_library('brotlicommon'), mode=c.RTLD_GLOBAL)
        lib = c.CDLL(ctypes.util.find_library('brotlidec'))
    lib.BrotliDecoderVersion.restype = c.c_uint32
    lib.BrotliDecoderCreateInstance.argtypes = [c.c_void_p, c.c_void_p, c.c_void_p]
    lib.BrotliDecoderCreateInstance.restype = c.c_void_p
    lib.BrotliDecoderDestroyInstance.argtypes = [c.c_void_p]
    lib.BrotliDecoderSetParameter.argtypes = [c.c_void_p, c.c_int, c.c_uint32]
    lib.BrotliDecoderSetParameter.restype = c.c_int
    pbyte = c.POINTER(c.c_uint8)
    lib.BrotliDecoderDecompressStream.argtypes = [
        c.c_void_p, c.POINTER(c.c_size_t), c.POINTER(pbyte),
        c.POINTER(c.c_size_t), c.POINTER(pbyte), c.POINTER(c.c_size_t),
    ]
    lib.BrotliDecoderDecompressStream.restype = c.c_int
    lib.BrotliDecoderGetErrorCode.argtypes = [c.c_void_p]
    lib.BrotliDecoderGetErrorCode.restype = c.c_int
    lib.BrotliDecoderErrorString.argtypes = [c.c_int]
    lib.BrotliDecoderErrorString.restype = c.c_char_p
    attach = getattr(lib, 'BrotliDecoderAttachDictionary', None)
    if attach:
        attach.argtypes = [c.c_void_p, c.c_int, c.c_size_t, pbyte]
        attach.restype = c.c_int
    paths = sorted({
        line.split()[-1] for line in Path('/proc/self/maps').read_text().splitlines()
        if '/libbrotlidec.so' in line or '/libbrotlicommon.so' in line
    })
    return lib, attach, common, {
        'version_encoded': lib.BrotliDecoderVersion(),
        'libraries': {p: digest(Path(p).read_bytes()) for p in paths},
        'attach_dictionary_available': attach is not None,
    }


def read_blob(folder, record):
    if record is None:
        return None
    path = (folder / record['path']).resolve()
    if not path.is_relative_to(folder.resolve()):
        raise ValueError('Artifact path leaves capture directory')
    data = path.read_bytes()
    assert len(data) == record['bytes'] and digest(data) == record['sha256']
    return data


def decode(lib, attach, sample, folder, wire, capacity):
    dictionaries = []
    for field, type_id in [('dictionary_raw', 0), ('dictionary_brotli_serialized', 1)]:
        if sample.get(field):
            dictionaries.append((type_id, read_blob(folder, sample[field])))
    if dictionaries and attach is None:
        return {'status': 'unsupported_dictionary_attachment', 'capacity': capacity}
    state = lib.BrotliDecoderCreateInstance(None, None, None)
    if not state:
        raise MemoryError('Reference decoder allocation failed')
    keepalive = []
    try:
        if sample['flags']['brotli_large_window']:
            assert lib.BrotliDecoderSetParameter(state, 1, 1)
        for type_id, data in dictionaries:
            buf = (c.c_uint8 * len(data)).from_buffer_copy(data)
            keepalive.append(buf)
            if not attach(state, type_id, len(data), buf):
                return {'status': 'dictionary_attachment_rejected', 'capacity': capacity}
        inp = (c.c_uint8 * len(wire)).from_buffer_copy(wire)
        dst = (c.c_uint8 * capacity)()
        available_in = c.c_size_t(len(wire))
        available_out = c.c_size_t(capacity)
        next_in = c.cast(inp, c.POINTER(c.c_uint8))
        next_out = c.cast(dst, c.POINTER(c.c_uint8))
        total_out = c.c_size_t()
        result = None
        calls = 0
        for _ in range(1024):
            before = (available_in.value, available_out.value)
            result = lib.BrotliDecoderDecompressStream(
                state, c.byref(available_in), c.byref(next_in),
                c.byref(available_out), c.byref(next_out), c.byref(total_out),
            )
            calls += 1
            if result in (0, 1):
                break
            if result == 2 and available_in.value == 0:
                break
            if result == 3 and available_out.value == 0:
                break
            if before == (available_in.value, available_out.value):
                break
        else:
            raise RuntimeError('Reference replay progress limit reached')
        output = bytes(dst[:capacity - available_out.value])
        error_code = lib.BrotliDecoderGetErrorCode(state) if result == 0 else None
        error_text = lib.BrotliDecoderErrorString(error_code) if error_code is not None else None
        return {
            'status': {0: 'error', 1: 'success', 2: 'needs_input', 3: 'needs_output'}[result],
            'result_code': result, 'capacity': capacity, 'calls': calls,
            'consumed_bytes': len(wire) - available_in.value,
            'remaining_bytes': available_in.value,
            'unused_suffix_hex': wire[len(wire) - available_in.value:].hex(),
            'output_bytes': len(output), 'output_sha256': digest(output),
            'strict_full_input_accepts': result == 1 and available_in.value == 0,
            'error_code': error_code,
            'error_text': error_text.decode(errors='replace') if error_text else None,
        }
    finally:
        lib.BrotliDecoderDestroyInstance(state)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--captures', type=Path, required=True)
    parser.add_argument('--library', choices=['system', 'modern'], required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads((args.captures / 'manifest.json').read_text())
    lib, attach, common, identity = load_library(args.library)
    rows = []
    for index, sample in enumerate(manifest['samples']):
        assert sample['info']['codec'] == 'br'
        original = read_blob(args.captures, sample['original_wire'])
        mutated = read_blob(args.captures, sample['mutated_wire'])
        source = read_blob(args.captures, sample['source'])
        vort_output = read_blob(args.captures, sample.get('vort_output'))
        capacity = sample.get('reference_output_capacity') or min(max(len(source) * 4, 4096), 1 << 20) + 1
        runs = {
            'original': decode(lib, attach, sample, args.captures, original, capacity),
            'mutated': decode(lib, attach, sample, args.captures, mutated, capacity),
        }
        if vort_output is not None and len(vort_output) >= capacity:
            generous = max(capacity, len(vort_output) + 1)
            assert generous <= (1 << 20) + 1
            runs['mutated_with_complete_output_capacity'] = decode(
                lib, attach, sample, args.captures, mutated, generous,
            )
        for label, result in runs.items():
            if result.get('status') == 'success':
                expected = source if label == 'original' else vort_output
                result['matches_captured_output'] = digest(expected) == result['output_sha256'] if expected is not None else None
        rows.append({
            'index': index, 'info': sample['info'], 'captured_direction': sample['direction'],
            'source_bytes': len(source), 'wire_hex': mutated.hex(),
            'captured_vort_output_bytes': len(vort_output) if vort_output is not None else None,
            'runs': runs,
        })
    report = {'library': args.library, 'identity': identity, 'capture_manifest_sha256': digest((args.captures / 'manifest.json').read_bytes()), 'samples': rows}
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    for row in rows:
        print(json.dumps({'library': args.library, 'index': row['index'], 'direction': row['captured_direction'], 'runs': row['runs']}))


if __name__ == '__main__':
    main()
