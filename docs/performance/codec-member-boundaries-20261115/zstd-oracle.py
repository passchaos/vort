import ctypes
import json
z = ctypes.CDLL("libzstd.so.1")
z.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
z.ZSTD_decompress.restype = ctypes.c_size_t
z.ZSTD_isError.argtypes = [ctypes.c_size_t]
z.ZSTD_isError.restype = ctypes.c_uint
z.ZSTD_getErrorName.argtypes = [ctypes.c_size_t]
z.ZSTD_getErrorName.restype = ctypes.c_char_p
z.ZSTD_versionString.restype = ctypes.c_char_p
wires = []
for kind, block in (("raw", "010000"), ("rle", "0300007a"),
                    ("compressed", "1d0000040000")):
    for known in (False, True):
        for checksum in (False, True):
            if known and kind == "compressed":
                # Independent window plus four-byte content size zero.
                header = "840000000000" if checksum else "800000000000"
            else:
                descriptor = (0x20 if known else 0) | (4 if checksum else 0)
                header = f"{descriptor:02x}00"
            wire = "28b52ffd" + header + block + ("99e9d851" if checksum else "")
            wires.append((f"{kind} known_fcs={known} checksum={checksum}", wire))
rows = []
for name, wire in wires:
    source = bytes.fromhex(wire)
    destination = ctypes.create_string_buffer(1)
    result = z.ZSTD_decompress(destination, 0, source, len(source))
    is_error = bool(z.ZSTD_isError(result))
    rows.append({"name": name, "wire_hex": wire, "is_error": is_error,
                 "result": z.ZSTD_getErrorName(result).decode() if is_error else result})
report = {"library": "libzstd.so.1", "version": z.ZSTD_versionString().decode(), "rows": rows}
print(json.dumps(report, indent=2))
assert all(not r["is_error"] and r["result"] == 0 for r in rows)
