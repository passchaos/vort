# Deflate missing long-distance secondary codes

This packet records a **public malformed-stream acceptance fix**. The semantic
builder now clears every allocated long-distance suffix range to the defined
zero-width invalid sentinel. The shared ordinary/window/non-overlap consumer,
rolling consumer and sink consumer reject that zero width before constructing
or using distance metadata. Existing supported incomplete distance alphabets
and their real 9/10-bit codes continue to decode successfully.

The original captures use baseline
`c19f5cddea3f5806ac48ebc7578f9ff8bc665b05`. Nine final frozen files were later
saved byte-identically in `d31dc3895d6a42e10205aff377731abecf4f27bd`
(`fix(deflate): reject missing long-distance secondary codes`).
`saved-source-commit.json` preserves that additional identity; earlier test and
performance observations keep their original capture epoch.

## Public witness and before-mode behavior

The malformed public witness is an ordinary **305-byte two-block raw stream**,
bare SHA-256
`e21b04b1f406dca371ddf196b9a28cb24428e4321649a0928a595e44e4c02bf4`.
The first block uses a complete comb distance tree to write a defined
symbol-ten/width-ten value into secondary slot 3. The next block initializes
an incomplete 9/10-bit alphabet whose canonical slot 3 is absent. Reusing that
uninitialized hole allowed the public decoder to manufacture a distance.
There is **no private slot poisoning**. The public test's independent bitwriter,
parsed canonical trees and selector/headroom assertions keep the same input
shape across before and final source epochs.

| Original observation | Outcome |
| --- | --- |
| Initial Debug/ReleaseSafe/ReleaseFast compilation | Test-only `comptime_int` runtime-if error; excluded from execution validation. |
| Corrected-test before Debug | Public malformed success returned input_read 305, output_written 143; expected InvalidHuffmanCode, so test driver exit 1. |
| Corrected-test before ReleaseFast | Public malformed success returned 305/131; expected InvalidHuffmanCode, so test driver exit 1. |
| Corrected-test before ReleaseSafe | This seed/build correctly rejected the malformed input and passed 8/8. |

The initial source differs from corrected before-v2 only by the explicit
`@as(usize, if (seed_block) history_len else 0)` test cast. Debug/Fast execute
four supported incomplete-tree positive controls before exposing malformed
acceptance. ReleaseSafe's result demonstrates the old uninitialized behavior
varies across modes/seeds; the evidence does not claim every old mode fails.
The extra `before-debug` binary has no matching frozen execution/source receipt
and is retained but excluded from claims. Only `before-*-v2` binaries/logs bind
the corrected before-v2 observations.

## Final contracts and completed checks

The public aggregate has **six scenarios**: four existing 9/10-bit incomplete
code controls across one/two blocks, the two-block stale-slot rejection, and
a single-block missing code with no history. Root calls repeat those same six
public scenarios through its facade. They are six duplicate root calls rather
than another six independent behaviors.

Final direct mode coverage has **18 scenarios**: ordinary, non-overlap,
linear-window and sink variants each consume three real two-block fixtures;
two nonzero rolling bases consume the same three fixtures. One rolling base
crosses the physical ring boundary. Invalid first-token invocations retain the
reader at bit **2402**. Valid controls check output count/content, complete
reader progress, guarded unchanged input and guards outside the full supplied
output capacity. Unused output capacity has no untouched-tail/error rollback
requirement; the tests preserve that existing contract.

| Final completed configuration | Actual log count/classification |
| --- | --- |
| Deflate Debug/ReleaseSafe/ReleaseFast/x86 ReleaseSafe/WASI ReleaseSafe | Each 10/10: two behavioral aggregates and eight anonymous imports. |
| Root Debug/ReleaseSafe/ReleaseFast/WASI ReleaseSafe | Each 92/92: three behavioral aggregates and 89 anonymous imports. |
| Full Deflate ReleaseSafe | 738/738 existing and added tests; exact named/import classification appears in the verification receipt. |

Those 92 log entries are not 92 new scenarios. The old `modes-v1-source`
module covered **15** direct scenarios: three linear variants plus two rolling
bases, each with three fixtures. Its original binaries/logs remain a separate
intermediate epoch. Earlier after logs with 8/90 counts and old mode logs with
10/92 counts are also preserved; they do not replace the final 18-scenario
source/10/92/738 validation binding. No unsaved build argv is invented.

## Independent oracle and small fixture scope

`small-fixtures-oracle.tar.gz` durably retains the six original worker padded
fixtures and worker `oracle.json`, all three exact repository testdata inputs,
and explicitly derived bare slices. The derived slices are exact prefixes of
the saved padded bytes; they are not claimed as recovered original bare files.
Every fixture includes sixteen zero padding bytes inside the input span;
guards in the tests sit outside that full span.

The worker JSON hashes **bare wire bytes**. Its original script was not saved.
The later main `oracle_replay.py`/stdout/JSON hashes **padded bytes** and is an
independent canonical bit decoder that has no secondary lookup. Four supported
subsets decode to 131 `a` bytes; two missing codes reject at bits 1262/2422.
Accepted cases consume 159 bytes for one block or 304 bytes for two blocks.
All six zlib 1.2.11 calls instead reject eagerly with `invalid distances set`.
That earlier header-rejection policy differs from Vort's existing supported
incomplete-subset contract and does not establish the same missing-code error.

The independent oracle's single-block missing fixture contains a **128-byte
literal prefix**. The public Zig aggregate's single-block missing fixture has
**no history**. Those inputs and outcomes are not merged. The worker JSON also
retains a no-history metadata row and a complete-tree positive-control row;
neither has saved fixture bytes or an original script in this packet, so those
two extra rows are outside the durable six-fixture replay evidence.
Archive verification checks the saved methods, bytes and receipts; it does not
execute the oracle or independently decode any input.

## Final-source nonregression pilot and all-wire smoke

The completed pilot compares baseline probe SHA-256
`e8377941221a13c0a0030b10ae083bb73cf17bc58f81ea8d55ad98c5eb66cb5c`
against final probe
`65b75eeec00bf7933d0baa3886e6097fc7275a813d72190f601be286944cce96`.
There are 96 child events across 12 selected cold rows, with four alternating
baseline/candidate process pairs per row. Each child has two warmup and two
measured Vort/reference pairs; iterations are 500 at 64 KiB and 100 at 1 MiB.
Vort calls `decodeRawDeflate`; reference libdeflate allocates, decodes through
`libdeflate_deflate_decompress_ex`, then frees its decompressor.

The recorded target is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU,
`skylake+pku+sgx`, on CPU 15 of an Intel Core i7-10700K, one codec/benchmark
thread. Libdeflate 1.26 is pinned at
`92e6a0db9fa848d742f9eb286c92afc60f2c3dda`, GCC 11.4.0,
`-O3 -DNDEBUG -march=skylake`, exact shared-library SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
Original host/environment observations, raw events, compressed/input sizes,
wire hashes and reference mappings are retained. Process tick snapshots do not
locate timed-batch overlap. Compiler build RSS is not codec heap measurement.

| Selected row | Geometric mean baseline/candidate speed ratio |
| --- | ---: |
| `deflate_reymont_65536_6_cold` | 0.997461548x |
| `deflate_reymont_65536_9_cold` | 1.000228519x |
| `deflate_nci_65536_6_cold` | 0.999339814x |
| `deflate_nci_65536_9_cold` | 1.017476665x |
| `deflate_xml_65536_6_cold` | 0.995362236x |
| `deflate_xml_65536_9_cold` | 1.007211929x |
| `deflate_reymont_1048576_6_cold` | 1.009383415x |
| `deflate_reymont_1048576_9_cold` | 1.002243013x |
| `deflate_nci_1048576_6_cold` | 1.002351884x |
| `deflate_nci_1048576_9_cold` | 1.008623492x |
| `deflate_xml_1048576_6_cold` | 1.005297358x |
| `deflate_xml_1048576_9_cold` | 1.011852677x |

Independent raw measured Vort-pair recomputation yields selected geometric
mean **1.0047170721097083x**; the weakest row is XML 64 KiB/L6 at
**0.9953622357568752x**. All selected row geometric means pass 0.98. This is a
functional correction nonregression pilot, not the full corpus performance
matrix, a dedicated-host gain or industry ranking result. Original individual
pair values are retained. No performance gain is claimed.

The separate 72-wire smoke covers frozen Deflate wires at levels 6/9 and
64 KiB/1 MiB/full sizes, with one call per batch, two rounds and no warmups.
All exits, full-output/count/consumption/unchanged-input/guard validations and
source/probe bindings pass. These smoke clocks are excluded from performance
claims. The 108 distinct ordinary plain/wire files total **371,820,359 bytes**;
large bytes remain external, with exact path/hash/size/generator descriptors
and `--originals` checks. All small malformed/reference-subset inputs described
above are durable in this packet.

## Artifact identity and offline verification

| File | Contents |
| --- | --- |
| `before-v2-source-overlay.tar.gz` | Five frozen corrected-test before files, with unchanged baseline semantic production. |
| `initial-test-source.tar.gz` | Exact initially uncompilable test source, separately attributed. |
| `modes-v1-source.tar.gz` | Exact intermediate 15-case mode module. |
| `final-source-overlay.tar.gz` | Nine frozen final files: four production/root files, two test modules and three tiny testdata inputs. |
| `raw-validation.tar.gz` | Every original top-level retained log, hash/freeze/validation/stats receipt, WASI runner and independent oracle source/outputs. |
| `retained-executables.tar.gz` | All 25 retained ELF/WASI binaries, including separately classified intermediate/excluded binaries. |
| `nonregression-raw.tar.gz`, `smoke-raw.tar.gz` | Complete original event/stdout/stderr/manifests/statistics and screen/smoke runners/logs. |
| `screen-runner-dependencies.tar.gz` | Exact pilot/matrix/evidence/fixtures modules and both original seed manifests. |
| `small-fixtures-oracle.tar.gz` | Six original padded fixtures, worker JSON, three repo inputs and separately described bare slices. |
| `fixture-replay-bindings.json` | Exact ordinary large-input descriptors and explicit external-byte scope. |
| `validation.json`, `independent-stats.json`, `oracle-replay.json` | Exact readable original receipt copies. |
| `saved-source-commit.json`, `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Later saved commit identity, member/container/origin hashes, offline verification, successful receipt and complete checksum inventory. |

The original baseline registry contains **2064** files; the final source
registry contains **2069**, exactly as their captured manifests report. The
verifier reconstructs baseline source from existing shared-dispatch source,
public-linear overlay and final wide-copy overlay archives, then applies each
frozen source overlay. This is the recorded replay inventory, not a complete
compiler-input claim. Live modified production files are never used as before
source. Existing baseline binary, source and reference containers are hash-bound
and reused without adding duplicate large copies.

Archives use sorted GNU tar regular files with uid/gid/mtime zero, empty owner
names and gzip level 9, empty filename/mtime zero. Original whitespace, EOF and
binary bytes stay unchanged. Packing and every archive check use **CPU 0**,
separately from recorded performance work on CPU 15.

From this directory:

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks archive/container identity, before/final
source and saved-commit bindings, the excluded initial compilation errors,
public malformed-success receipts, actual test/import classifications,
small fixture bare/padded scopes and oracle method attribution. It independently
recomputes the 96-event ratios/medians and verifies all 72 smoke source/fixture/
command/count/content/consumption/guard report bindings. Optional checks compare
all saved originals, external ordinary fixtures, immutable baseline Git blobs
and saved final source blobs. It invokes no compiler, codec, test, oracle or
benchmark. Later reproduction must use a derived runner in a separate checkout
and preserve its own capture epoch, commands, outputs and provenance.
