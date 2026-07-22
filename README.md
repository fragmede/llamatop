# LlamaTop

LlamaTop is a small, native macOS terminal dashboard for answering a deceptively simple question: **is llama.cpp actually doing anything?**

It finds running llama.cpp tools, measures their real CPU-time deltas and resident memory, shows every logical CPU core, and reads the Apple GPU activity that macOS exposes on Apple Silicon. It needs no daemon, kernel extension, third-party package, or root access.

```text
LLAMATOP  Apple M4 Max
BUSY  1 llama.cpp process

Llama workload (llama.cpp-only)
CPU        [██████░░░░░░░░░░░░░░░░░░░░]  420.0%  ≈ 4.2 / 16 cores
RAM        [███░░░░░░░░░░░░░░░░░░░░░░]  8.0 GiB / 64.0 GiB physical

CPU logical cores (system-wide · 12P + 4E)
C00 [███████] 100%  C01 [██████░]  86%  C02 [██░░░░░]  31%
C03 [░░░░░░░]   4%  …

Apple GPU (40 cores · system-wide)
Device     [█████████████████████░░░░░]  75.0% system-wide
Renderer   [██████░░░░░░░░░░░░░░░░░░]  20.0% system-wide
Tiler      [███░░░░░░░░░░░░░░░░░░░░░]  11.0% system-wide
GPU Memory [███░░░░░░░░░░░░░░░░░░░░░]  8.0 GiB in use · 12.0 GiB allocated

   PID    CPU       RAM       TIME  COMMAND
 12345  420.0%   8.0 GiB      02:04  llama-cli -m model.gguf
```

## Requirements

- An Apple Silicon Mac
- macOS 13 or newer
- Xcode Command Line Tools (for building from source)

## Build and run

```bash
swift build -c release
.build/release/llamatop
```

To put it on your path:

```bash
install .build/release/llamatop /usr/local/bin/llamatop
llamatop
```

Press `Ctrl-C` to leave the live dashboard.

## Options

```text
-i, --interval SECONDS  Refresh interval (0.2–60; default: 1)
    --once              Print one warmed-up sample and exit
    --match TEXT        Also watch commands containing TEXT (repeatable)
    --no-color          Disable ANSI colors
-h, --help              Show help
-v, --version           Show the version
```

LlamaTop automatically recognizes current `llama-*` tools, legacy `main` and `server` binaries under a `llama.cpp` path, and `python -m llama_cpp`. Use `--match` for a renamed binary or wrapper:

```bash
llamatop --match my-inference-worker
```

## Reading the display

- **Llama CPU** is sampled from each matching process using macOS `libproc`. Like `top`, 100% means one fully occupied core, so a multithreaded process can exceed 100%. The bar is normalized against all CPU cores; the number remains the raw top-style percentage.
- **Llama RAM** is resident memory for matching processes. This includes resident pages of memory-mapped model files, which makes it more useful than private-memory figures for llama.cpp.
- **CPU logical cores** are system-wide bars sampled from macOS processor tick counters. The topology summary shows performance and efficiency core counts when available, but macOS does not reliably map those types onto the numbered bars.
- **Apple GPU Device, Renderer, and Tiler** are independent system-wide pipeline counters read directly from IOKit. They are not separate GPUs and must not be added together. An LLM compute workload can drive Device utilization while Renderer and Tiler remain low.
- **GPU Memory** is undocumented, system-wide driver accounting for Apple unified memory. It is neither dedicated VRAM nor llama.cpp-only memory.
- macOS does not provide dependable, root-free per-process or per-GPU-core Metal utilization here. Other Metal apps can contribute to every GPU number, so LlamaTop never uses GPU activity alone to call a llama.cpp process busy.
- **BUSY** means a matching process is consuming at least 1% of one core. **IDLE** means the process exists but is below that noise floor. **WARMING UP** means a newly found process needs one more sample before its activity is known. **NOT FOUND** means no command matched.

GPU registry keys are undocumented by Apple and can vary across hardware or macOS releases. LlamaTop shows `unavailable` instead of guessing when the metric is absent.

## Development

```bash
swift test
swift build -c release
```

The core sampler and renderer are separated from the CLI. Per-process and per-core CPU math, matching, redaction, GPU parsing, classification, option parsing, and responsive rendering have fixture-backed tests; native process, processor, and GPU probes also have macOS smoke tests.
