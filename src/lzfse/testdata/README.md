# LZFSE fixtures

`apple-zero-100k-v2.lzfse.hex` was generated from 100,000 zero bytes with the
upstream Apple/lzfse command-line encoder. It exercises a compressed `bvx2`
block, compressed frequency tables, four interleaved literal states, and L/M/D
FSE decoding. The expected decoded output is exactly 100,000 zero bytes.

`apple-zero-100k-v1.lzfse.hex` contains the same payload and FSE bitstreams with
the public V2 fields/frequencies expanded into a `bvx1` header. Both Vort and
the upstream Apple decoder reproduce the same 100,000 zero bytes from it.
