# AGENTS.md

## Project Mission

`vort` is intended to become a next-generation compression library whose long-term goal is to surpass `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` in both functionality and performance.

Treat this as a product direction and engineering bar, not a one-time checklist. A completed milestone only means the current slice has reached its target; when continuing work, raise the bar with stricter compatibility, better ratios, faster throughput, lower memory use, broader APIs, stronger validation, or wider platform coverage.

## Baselines and References

Use the local and system-available implementations as references and competitors when they are available:

- `zlib`: compatibility, gzip/zlib/raw deflate behavior, API expectations, checksums, streaming semantics, and legacy interoperability.
- `zlib-ng`: modern deflate/inflate performance techniques, CPU dispatch, and benchmark methodology.
- `zlib-rs`: memory-safe implementation tradeoffs, Rust API ergonomics, fuzzing/test strategy, and portability ideas.
- `zstd`: modern compression design, dictionaries, long-distance matching, skippable frames, seekable use cases, training workflows, and high-throughput benchmarking.

Prefer local checkouts under `~/Work` when present before relying on web snippets. Study competitors for behavior, tests, performance envelopes, and edge cases, but design `vort` as a Zig-native library rather than a mechanical port.

## Product Scope

The library should eventually cover and exceed the practical capabilities users expect from the baseline compressors:

- raw deflate, zlib-wrapped deflate, gzip, and zstd-compatible formats where compatibility is a target;
- a native `vort` format that can exceed legacy ratio/speed tradeoffs without being constrained by historical wire formats;
- streaming compression and decompression with bounded memory and explicit caller-owned state;
- one-shot convenience APIs built on top of the streaming core;
- compression levels and strategies with documented speed/ratio/memory tradeoffs;
- dictionaries, dictionary training, preset dictionaries, and stable dictionary IDs;
- checksums and content verification including Adler-32, CRC-32, CRC-32C, XXH-style fast hashes where useful, and strong optional content hashes;
- block, frame, skippable-frame, concatenated-stream, and partial/truncated input handling;
- seeking/splittable/indexed compressed streams for large files and data lakes;
- robust error reporting with byte offsets, format context, and recoverability hints;
- fuzzing, corpus regression, differential testing, and deterministic benchmark suites;
- portable scalar paths first, then architecture-specific accelerators behind identical public behavior;
- CLI tooling only as an exercise and validation surface for the library, not as the owner of core logic.

## Architecture Principles

- Keep the project library-first. The CLI, examples, and benchmarks should call the same public APIs users call.
- Use explicit allocators and explicit ownership. Avoid hidden global state.
- Design streaming state machines as resumable, testable components with clear input/output progress accounting.
- Separate format parsing, entropy coding, match finding, block planning, checksums, CPU feature dispatch, and I/O adapters into small modules.
- Preserve deterministic behavior for identical inputs, settings, dictionaries, and build targets unless a mode explicitly opts into adaptive nondeterminism.
- Keep compatibility modes bit-exact or behavior-exact where that is part of the target. Native modes may innovate freely but must be documented and versioned.
- Prefer simple portable reference implementations before optimized variants. Every optimized path must have reference comparison tests.
- Treat memory limits, decompression bombs, integer overflow, malformed streams, and hostile inputs as core design constraints from the beginning.
- Make performance claims only with reproducible benchmarks and record the competitor version, CPU, build mode, corpus, and command line.
- Avoid copying competitor internals blindly. Translate useful invariants into clear Zig designs.

## Zig and Tooling Expectations

- Prefer Zig for implementation unless a specific external compatibility harness requires another language.
- Assume Zig 0.16.x semantics unless this repository explicitly sets a different version.
- Prefer current Zig standard-library APIs and local `zig env` / standard-library source over older examples.
- Format changed Zig files with `zig fmt`.
- Add or update tests with every new codec behavior, parser rule, checksum implementation, dictionary feature, streaming transition, or optimized kernel.

## Validation Expectations

When the repository has build scripts, use the narrowest relevant commands plus broader smoke checks before finishing code changes. Typical commands should evolve toward:

```sh
zig fmt build.zig build.zig.zon src/**/*.zig examples/**/*.zig
zig build test
zig build check
zig build run -- --help
```

For compression work, add targeted validation such as:

- round-trip tests across empty, tiny, random, repetitive, structured, and large inputs;
- compatibility tests against `zlib`, `zlib-ng`, `zlib-rs`, and/or `zstd` for supported wire formats;
- malformed/truncated/corrupt stream tests with exact error expectations;
- differential tests against reference implementations;
- fuzz or corpus regression entrypoints for parsers and decompressors;
- benchmark entries for one-shot, streaming, dictionary, checksum, match-finder, and decompressor hot paths.

## Benchmark Roadmap

Maintain benchmark evidence as the project grows. Track at least:

- compression throughput, decompression throughput, compression ratio, memory use, and compressed size;
- corpora covering text, JSON, source code, binaries, logs, small payloads, highly repetitive data, already-compressed data, and mixed real-world files;
- cold and warmed runs, build mode, CPU model, thread count, and enabled CPU features;
- comparison against available `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` command-line or library APIs;
- separate results for compatibility formats and native `vort` formats.

Do not trade away decompression safety, compatibility, or output correctness for benchmark wins.

## Collaboration Workflow

- After adding or changing code functionality, run the relevant validation and create a focused git commit that saves the completed change.
- Before committing, inspect the working tree and stage only files changed for the requested work. Do not include unrelated user changes.
- Do not commit if this directory is not a git repository, if the user explicitly asks not to commit, or if committing safely would require including unrelated changes.
- If unrelated changes are present, leave your work uncommitted and explain the safe next step.
- Keep roadmap and documentation current when public behavior, supported formats, benchmark evidence, or priorities change.
- Summaries to the user should be in Chinese unless the user asks otherwise, and should include completed work, validation performed, current system time, and next recommended work items.

## Initial Bootstrap Direction

If this repository is still empty or near-empty, bootstrap in this order:

1. Zig package scaffold with `src/root.zig`, tests, `build.zig`, and a small CLI/example.
2. Core error types, buffer accounting, byte readers/writers, and streaming progress contracts.
3. Checksums: Adler-32 and CRC-32 first for zlib/gzip compatibility, then faster hashes used by native formats.
4. Store/no-compression block format and round-trip tests to validate streaming infrastructure.
5. Deflate inflate/deflate compatibility slices, starting with correctness and interoperability.
6. Benchmarks and differential tests against installed/local zlib-family tools.
7. Native `vort` frame/block design notes before implementing incompatible format features.
