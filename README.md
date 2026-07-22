# LlamaTop

LlamaTop is a small, native macOS terminal dashboard for answering a deceptively simple question: **is llama.cpp actually doing anything?**

It finds running llama.cpp tools, measures their real CPU-time deltas and resident memory, shows every logical CPU core, reads the Apple GPU activity that macOS exposes, and breaks down system memory on Apple Silicon. It needs no daemon, kernel extension, third-party package, or root access.

The live dashboard starts with aggregate bars. Press `1`, just like in `top`, for detailed CPU/GPU information and `m` for the memory panel. The fully expanded view looks like this:

```text
LLAMATOP  Apple M4 Max
BUSY  1 llama.cpp process

Llama workload (llama.cpp-only)
CPU        [██████░░░░░░░░░░░░░░░░░░░░]  420.0%  ≈ 4.2 / 16 cores
RAM        [██░░░░░░░░░░░░░░░░░░░░░░░]  8.0 GiB / 128.0 GiB physical

Memory layout (system-wide · unified · LPDDR5)
Wired      [██████████░░░░░░░░░░░░░░░]  49.2 GiB
Active     [██████░░░░░░░░░░░░░░░░░░░]  28.1 GiB
Inactive   [██████░░░░░░░░░░░░░░░░░░░]  28.0 GiB
Compressed [████░░░░░░░░░░░░░░░░░░░░░]  20.5 GiB
Free       [░░░░░░░░░░░░░░░░░░░░░░░░░]  0.3 GiB
Other      [░░░░░░░░░░░░░░░░░░░░░░░░░]  1.9 GiB
Swap       [██████████████████████░░░░░]  7.1 GiB / 8.0 GiB
Hardware   128.0 GiB LPDDR5 unified · Hynix
Geometry   16.0 KiB pages · 128 B cache line
Banks/channels unavailable through macOS

CPU logical cores (system-wide · 12P + 4E)
C00 [███████] 100%  C01 [██████░]  86%  C02 [██░░░░░]  31%
C03 [░░░░░░░]   4%  …

Apple GPU (40 cores · system-wide)
Device     [█████████████████████░░░░░]  75.0% system-wide
Renderer   [██████░░░░░░░░░░░░░░░░░░]  20.0% system-wide
Tiler      [███░░░░░░░░░░░░░░░░░░░░░]  11.0% system-wide
GPU Memory [███░░░░░░░░░░░░░░░░░░░░░]  8.0 GiB in use · 12.0 GiB allocated

GPU cores (presence only; no per-core telemetry)
Cores ◆◆◆◆◆◆◆◆◆◆ ◆◆◆◆◆◆◆◆◆◆ ◆◆◆◆◆◆◆◆◆◆ ◆◆◆◆◆◆◆◆◆◆
40 detected · activity is aggregate

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

Press `1` to toggle detailed CPU/GPU information, `m` to toggle memory details, and `Ctrl-C` to leave the live dashboard. Both keys take effect immediately; you do not need to press Enter. The two detail modes are independent.

In non-interactive output, including `--once`, LlamaTop prints the complete detailed view because there is no keyboard session in which to toggle it.

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
- **Memory layout** is system-wide Mach VM accounting. Wired pages cannot be paged out; active pages are in current use; inactive pages are on the kernel's inactive queue and may be reclaimable; compressed is the physical footprint of the compressor; free includes speculative pages; and other is the remainder of physical capacity not represented by those counters. Swap comes from `vm.swapusage`.
- **Memory hardware** is read once from macOS System Profiler. Apple Silicon uses one unified CPU/GPU memory pool. macOS reports capacity, memory type, vendor, page size, and cache-line size here, but it does not expose trustworthy bank/channel topology or per-bank activity, so LlamaTop says that information is unavailable.
- **CPU logical cores** are system-wide bars sampled from macOS processor tick counters. The topology summary shows performance and efficiency core counts when available, but macOS does not reliably map those types onto the numbered bars.
- **Apple GPU Device, Renderer, and Tiler** are independent system-wide pipeline counters read directly from IOKit. They are not separate GPUs and must not be added together. An LLM compute workload can drive Device utilization while Renderer and Tiler remain low.
- **GPU core inventory** appears in the detailed view when macOS reports a hardware core count. On a 40-core GPU it shows exactly 40 `◆` symbols, one for each detected hardware core. The symbols show presence only: they do not light up, change with load, or claim that macOS exposes each core's activity.
- **GPU Memory** is undocumented, system-wide driver accounting for Apple unified memory. It is neither dedicated VRAM nor llama.cpp-only memory.
- macOS does not provide dependable, root-free per-process or per-GPU-core Metal utilization here. Other Metal apps can contribute to every GPU number, so LlamaTop never uses GPU activity alone to call a llama.cpp process busy.
- **BUSY** means a matching process is consuming at least 1% of one core. **IDLE** means the process exists but is below that noise floor. **WARMING UP** means a newly found process needs one more sample before its activity is known. **NOT FOUND** means no command matched.

GPU registry keys are undocumented by Apple and can vary across hardware or macOS releases. LlamaTop shows `unavailable` instead of guessing when the metric is absent.

## Development

```bash
swift test
swift build -c release
```

The core sampler and renderer are separated from the CLI. Per-process and per-core CPU math, memory conversion and hardware parsing, matching, redaction, GPU parsing, classification, option parsing, and responsive rendering have fixture-backed tests; native process, processor, memory, and GPU probes also have macOS smoke tests.
