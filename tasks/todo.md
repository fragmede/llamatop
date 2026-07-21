# LlamaTop MVP

## Goal

Build a dependency-free macOS terminal dashboard that answers: “Is llama.cpp actually doing work on this Apple Silicon Mac?”

## Scope

- [x] Discover current llama.cpp executables without requiring root.
- [x] Show per-process PID, CPU usage, resident memory, elapsed time, and command.
- [x] Show aggregate llama.cpp CPU usage as both percent and approximate cores busy.
- [x] Show system-wide Apple GPU utilization when IOKit exposes it, clearly labelled as system-wide rather than per-process.
- [x] Show a plain-language `BUSY`, `IDLE`, `WARMING UP`, or `NOT FOUND` verdict.
- [x] Refresh in place in an interactive terminal and support a one-shot mode for scripts.
- [x] Work without third-party runtime dependencies or elevated privileges.
- [x] Explain installation, telemetry meaning, limitations, and usage in the README.

## Implementation plan

- [x] Create a Swift package with a small library and `llamatop` executable.
- [x] Write parsing, process matching, argument, status, and rendering tests first.
- [x] Sample real CPU-time deltas with macOS `libproc` and GPU data through the public I/O Registry view.
- [x] Keep OS probes behind a seam so sampling is deterministic in tests.
- [x] Add a compact ANSI terminal renderer with a readable non-interactive fallback.

## Verification

- [x] Run the focused unit tests while implementing.
- [x] Run the full test suite.
- [x] Build an optimized release binary.
- [x] Smoke-test `--help`, `--once`, argument errors, and the interactive refresh loop.
- [x] Run Standards and Spec reviews and resolve actionable findings.

## Review

- Standards re-review: no remaining documented-standard violations or actionable code smells.
- Spec re-review: no remaining missing, partial, incorrect, or out-of-scope behavior.
- Verification: 26 tests pass with warnings treated as errors; optimized release build succeeds.
- Live smoke test: found the running `llama-server`, reported CPU within normal sampling variance of `ps`, showed resident model memory, and read root-free system GPU utilization.
