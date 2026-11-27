# Deferred preferred q8: completed timing rejection evidence

The candidate **missed the preregistered primary ≥1.03× throughput gate**. Controls were not timed, there is no performance acceptance, and this candidate was not adopted. The focused functional results are a separate [evidence package](../deferred-preferred-functional-20261127/README.md).

| Independent comparison | Candidate throughput / other | Paired 95% throughput CI | Candidate elapsed / other | Candidate wire / other |
| --- | ---: | ---: | ---: | ---: |
| Frozen baseline `d5d9d8aa` (primary) | **1.0147036802×** | [1.0099682532, 1.0194976585] | 0.9855093852× | 1.0000000000× |
| Exact historical `0a673757` | 0.3291721029× | [0.3284584023, 0.3298699418] | **3.0379245122×** | 0.9565808634× |
| Pinned libbrotli 1.2.0 | 0.0170116079× | [0.0168111232, 0.0171638563] | **58.7833910501×** | 0.9438865172× |

The raw `owned_encode_free_ns` fields yield **1.0147036801576106** for primary, identical to the original on-disk `summary.json`. The provisional handoff number `1.01467597` is not reproducible from the retained trials and was not used to revise any raw file or summary. The primary interval excludes parity and all row points clear 0.98, but neither condition substitutes for the 1.03 point threshold. Historical and reference results are direct separate experiments, not acceptance gates or numbers to combine across epochs.

## Declared operation and retained evidence

Each phase covers the same twelve 64 KiB Silesia prefixes, q8/generic/explicit-window16, six balanced common AB/BA rounds, **72 pairs / 144 timed calls**, with no weak extras or discarded samples. One owning warmup and free precede each public one-shot encode/length-mix/free measurement. Full-byte identity and pinned external decode validate the initial warm wire; timed output is checked by length/mix. The candidate source is the 2,257-file frozen registry `dd21162bfc7912cbc932781c9ccafd6ea7e2017b5d62037e11cdd7645b629eaf`. The reference uses actual libbrotli 1.2.0 with its three pinned loaded libraries checked per call. Equal q8 does not establish a quality frontier. The recorded quiet snapshots are release-bound observations, not proof of continuous isolation or industry leadership.

- [`originals.tar.gz`](originals.tar.gz) contains byte-identical protocol, actual release, warm preflight, all original measured children/manifests/statistics receipts/summaries and raw-proof sources; fixed inputs, selected actual ELF/harness and runtime library bytes; and the supporting recorded identity and release metadata. No measured controls artifacts are included.
- [`source-closure.tar.gz`](source-closure.tar.gz) retains exact source bytes for the baseline, candidate and historical registries. Identical source bytes are stored once under their SHA-256; preserved registries map all paths back to those bytes. The candidate closure includes its additional WASI runner JS.
- [`capture.json`](capture.json) maps each original path to its package member and SHA. Original absolute paths are archive keys only. The Deflate 540-warm prerequisites are included as release metadata only, not as a new Deflate timing or resource proof.

## Data-only replay

```sh
python3 -B /path/to/deferred-preferred-timing-20261127/verify.py
```

The verifier streams both archives without extracting or running any code from them. It checks every retained child, raw ns and warm/output identity, the recorded phase bindings, all registered source bytes, and independently replays the fixed 20,000-draw stratified whole-round bootstrap. See [`verification-receipt.json`](verification-receipt.json) for the relocated replay and refusal controls. No benchmark, input recompression, library loading, build, codec, RSS measurement, or timing is performed.
