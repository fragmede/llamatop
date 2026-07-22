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

## Expanded hardware dashboard

### Scope

- [x] Show a system-wide utilization bar for every logical CPU core.
- [x] Summarize Apple Silicon performance and efficiency core counts when macOS exposes them.
- [x] Show separate system-wide Apple GPU device, renderer, and tiler utilization bars.
- [x] Show Apple GPU core count and root-free in-use/allocated GPU memory information.
- [x] Add a utilization bar to llama.cpp resident memory without implying dedicated VRAM.
- [x] Keep unavailable or undocumented metrics optional and clearly qualified.

### Verification

- [x] Test CPU tick deltas, counter rollover, core-count changes, and warm-up samples.
- [x] Test richer GPU property parsing with missing and alternate value types.
- [x] Test the expanded dashboard at narrow and wide terminal widths.
- [x] Run the complete suite and warnings-as-errors release build.
- [x] Exercise the dashboard against live llama.cpp and Apple Silicon telemetry.
- [x] Run Standards and Spec reviews and resolve actionable findings.

### Review

- Standards re-review: no remaining violations or actionable code smells.
- Spec re-review: no remaining missing, partial, incorrect, or out-of-scope behavior.
- Verification: 37 tests pass with warnings treated as errors; the optimized 0.2.0 release build succeeds.
- Width verification: every non-ANSI line fits at 60, 80, and 100 columns; live TTY rendering follows terminal width.
- Live telemetry: 16 logical CPU bars and the 12P/4E topology rendered alongside one 40-core GPU device, three pipeline counters, and unified-memory statistics.

## Interactive detail toggle

### Scope

- [x] Start the interactive dashboard in a compact aggregate view.
- [x] Toggle detailed CPU and GPU information immediately when `1` is pressed, matching `top`.
- [x] Show one presence-only inventory symbol for each detected GPU core in detailed mode.
- [x] State in both the dashboard and README that the 40 GPU cores do not have individual utilization telemetry.
- [x] Preserve the complete detailed output for non-interactive and `--once` use.

### Implementation plan

- [x] Add renderer modes and fixture-backed tests for compact and detailed layouts.
- [x] Add a terminal input session that reads `1` without Enter and restores terminal state on exit.
- [x] Document the keyboard control and the meaning of the 40-core GPU inventory.

### Verification

- [x] Run focused renderer tests during implementation.
- [x] Run the full suite and warnings-as-errors release build.
- [x] Exercise the `1` toggle in a live pseudo-terminal and verify terminal cleanup.
- [x] Run Standards and Spec reviews and resolve actionable findings.

### Review

- Standards re-review: no remaining documented-standard violations or actionable code smells.
- Spec re-review: no remaining missing, incorrect, partial, or out-of-scope behavior.
- Verification: 45 tests pass with warnings treated as errors; the optimized 0.3.0 build succeeds.
- Live terminal: `1` toggles CPU/GPU detail immediately, returns to compact mode, and `Ctrl-C` restores canonical input and echo.
- GPU detail: one presence-only symbol renders for each of the 40 detected cores without implying per-core telemetry.

## Memory detail toggle

### Scope

- [x] Toggle a system-wide memory detail panel immediately when `m` is pressed.
- [x] Show wired, active, inactive, compressed, free, other, and swap memory as truthful bars.
- [x] Show physical capacity, memory type/vendor when macOS reports them, page size, and cache-line size.
- [x] Label memory banks/channels unavailable because macOS does not expose their topology or activity.
- [x] Keep the `1` and `m` toggles independent and include memory details in non-interactive output.

### Implementation plan

- [x] Add a root-free Mach VM/swap probe and one-time System Profiler hardware parser behind test seams.
- [x] Add a testable keyboard display state and responsive memory renderer.
- [x] Document memory categories, hardware limitations, and the `m` control.

### Verification

- [x] Test memory counter conversion, hardware parsing, rendering, and key-state transitions.
- [x] Run the full suite and warnings-as-errors release build.
- [x] Exercise `m`, `1`, and `Ctrl-C` in a live pseudo-terminal.
- [x] Run Standards and Spec reviews and resolve actionable findings.

### Review

- Standards re-review: no remaining documented-standard violations or actionable code smells.
- Spec re-review: no remaining findings after correcting speculative-page double counting.
- Verification: all 45 tests and the warnings-as-errors optimized build pass after the review fix.
- Live terminal: `m` and `1` toggle independently; `Ctrl-C` restores canonical input and echo.
- Live memory: Mach VM and swap counters render with 128 GiB LPDDR5/Hynix hardware details; unavailable bank/channel telemetry is explicitly labelled.
