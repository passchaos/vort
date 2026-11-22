# Record-skip paired acceptance — stopped, not accepted

No clean complete 15-sweep performance epoch was produced. The owner stopped
current performance work; the record patch remains isolated and unadopted.
No partial timing ratios are summarized as codec success or failure, no fast
samples/epochs were selected, and partial epochs are never combined.

The latest source includes the Huffman functional repair on both sides. Only
the candidate applies `production.patch`. Both use the same newly built
ReleaseFast/native/single-threaded record object and clean codec sources.

The frozen 60-row matrix consists of ten synthetic complete fixed-record q11
targets (4/8/16/32/64 KiB, one-shot cold and caller-owned reusable warmed),
ten q10 same-record controls, 24 original Silesia64KiB q11 controls, eight
related dictionary/HQ/chunked/incremental controls, and eight q0--q3 controls.
Original Silesia prefixes are real controls; generated records are not called
real data. q10/q11 explicitly use command-state8; q0--q3 use unsupported-feature
default sentinel255. The initial 52-row manifest is retained separately.

Preparation completed 60 input/wire/decode identity rows. The current-production
95-row functional/resource matrix passes exact successful wire/decode, both
exact caps and cap-minus-one refusals, allocation balance, and bounded backing
OOM retries. These are functional/resource results, not performance acceptance.

Observed timing data retained:

- CPU2/HT10 epoch1: 52 paired observations; guard-stopped/not accepted.
- CPU2/HT10 epoch2: 133 paired observations; guard-stopped/not accepted.
  The specific GDM GUI activity has zero actual sample-clock intersections;
  this explains the conservative stop but does not rescue the partial epoch.
- CPU6/HT14 epoch3: 25 calibration rows, zero official pairs; calibration guard
  stopped and the owner then stopped all performance work. Its captured runtime
  configuration is CPU6/full-epoch2% guard; it is not adopted regardless.

The CPU2 clock-only proposal was never started and has no observed samples.
The desktop process is UID128/GDM and was never modified or stopped. No
noninteractive sudo privilege was available. The two user1000 tool broker
affinity reservations were restored after stop. All current TIDs, including
new threads, are verified against the original process main masks; PID
starttimes were checked and no benchmark children remain. See the restoration
receipt rather than only the initial saved thread list.

Artifact paths:

- Preparation/source/matrix/functional logs are in this directory.
- First raw pairs: `samples/pairs.jsonl`.
- Second raw pairs and explanation:
  `/tmp/vort-br-record-skip-epoch2-pPahLw/samples/pairs.jsonl`,
  `/tmp/vort-br-record-skip-epoch2-pPahLw/clock-intersections.json`.
- Final stop/restoration:
  `/tmp/vort-br-record-skip-epoch3-AH8ty9/STOPPED.json`,
  `/tmp/vort-br-record-skip-epoch3-AH8ty9/runtime-affinity-restoration.json`.

Binary provenance records .text increase96 bytes and unchanged largest visible
constant stack subtraction; this is not a measured runtime stack bound.
The target>=1.03/CI excluding1 and all-controls>=0.98 bars remain unassessed
because no complete clean epoch exists. No q8 architectural milestone is
applied to this q11 slice and no industry-leadership claim is made.

Mainline can resume the latest functional full gate. Future performance work
requires another explicitly requested independent stable epoch.
