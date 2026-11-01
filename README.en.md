# Running a 27B LLM on 8GB VRAM — Measured, Not Guessed

> **One RTX 4070 Laptop (8GB VRAM) + 24GB RAM on Windows: a ternary-quantized 27B model, 256K context, 28 tok/s in Chinese creative writing.**
> This repo is not a tutorial collection — it is a **set of measured configurations and numbers**: which models fit, how long context can actually go, exactly where throughput collapses, and why three inference backends can't coexist.

[中文说明](README.md) · English

## Why this repo exists

8GB VRAM is "hard mode" for local AI. Running a large model demands 4-bit quantization plus partial layer offloading. Long context runs headlong into a KV-cache explosion. Loading an image model (ComfyUI) silently eats another 1.9GB.

Most 8GB write-ups online either post parameters with no data, or post numbers taken on a 16GB card. Every claim here ships with measured numbers and the method used to measure them, so you can reproduce it.

## Hardware baseline

| Item | Spec |
|---|---|
| GPU | NVIDIA RTX 4070 Laptop, **8GB VRAM** |
| RAM | 24GB DDR (roughly 20GB usable) |
| OS | Windows 11 |
| Disk | Model weights on a data drive; system drive reserved for programs |

> On an 8GB card the binding question is not "how large a model fits" but "only one model at a time fits." See [VRAM exclusivity](docs/显存互斥与上下文预算.md) (Chinese).

## Measured results (same machine, same day, same methodology)

### 27B ternary-quantized model (PTQ1, 5.94GB weights)

| Scenario | Throughput |
|---|---|
| Chinese long-form creative writing | **28 tok/s** |
| Highly repetitive text | **82 tok/s** (MTP acceptance 96%) |
| Greedy decoding | 38 tok/s |
| Prefill (13.7K chars) | **834 tok/s** |
| Prefill (232K tokens ingested) | 418 tok/s |
| Context window | 262,144 (verified with a 3-probe needle test, 3/3) |

### Context length vs. prefill throughput — the critical curve

| Context setting | Prefill | Verdict |
|---|---|---|
| 80K | 2,370 tok/s (llama.cpp, fully resident) | **Safe ceiling** |
| 96K | begins to degrade | Usable but strained |
| 128K | **63 tok/s** (40× collapse) | Broken: KV no longer fits, prefill thrashes between VRAM and RAM |
| 192K | 13.6 tok/s | Unusable |

**Root cause:** `q4_0` KV cache costs 18 KiB/token; `f16` costs 64 KiB/token. Long context on 8GB **requires** 4-bit KV.

### Two ways to run the vision tower

| Approach | VRAM cost | Result |
|---|---|---|
| `--vision` (GPU) | needs a further 1.4GB runtime reservation — doesn't fit in 8GB | Fails: `requested Engine runtime reservation requires ... but only ... available` |
| `--vision-cpu` | **0** | A few extra seconds per image encode, fully functional |

## Quick start

```bash
# 1. Clone
git clone https://github.com/liangqilong123-cmd/8gb-ai-stack.git && cd 8gb-ai-stack

# 2. Set your paths: replace every <LLAMA_DIR> / <MODELS_DIR> under configs/
grep -rn "<LLAMA_DIR>\|<MODELS_DIR>" configs/

# 3. Start a backend (pick one)
#    A. llama-swap — multi-model routing with automatic load/unload
llama-swap.exe -config configs/llama-swap.config.yaml -watch-config
#    B. NInfer — single model, huge context, includes vision
powershell -ExecutionPolicy Bypass -File configs/ninfer-start.ps1

# 4. Verify
curl http://127.0.0.1:8080/v1/models
```

Where to download the weights, how big they are, and their licenses: see [MODELS.md](MODELS.md). **No weights are distributed in this repository.**

## Layout

| Path | Contents |
|---|---|
| `configs/llama-swap.config.yaml` | Multi-model routing (5 tiers, annotated with VRAM and context notes) |
| `configs/ninfer-start.ps1` | 27B single-model launcher (256K context + CPU vision + MTP) |
| `configs/start-engine.bat` | Pure-ASCII double-click launcher (guards against double start) |
| `docs/显存互斥与上下文预算.md` | **Three-backend exclusivity rules** + context ceiling measurements + KV accounting |
| `docs/实测数据.md` | Methodology and methodology caveats for every throughput number |
| `docs/故障排查.md` | OOM, throughput drops, context collapse, reaped processes, driver TDR |
| `scripts/bench_stream.py` | Streaming throughput measurement for any OpenAI-compatible endpoint |
| `scripts/vram_watch.ps1` | VRAM watchdog (alarms below a threshold; catches the "no error, just slow" case) |

> Documentation files are in Chinese. Numbers, tables, and commands are language-neutral — if you want an English translation of a specific doc, open an issue.

## Known limitations (stated up front)

1. **Only one backend at a time.** llama-swap / long-context engine / NInfer are mutually exclusive; switching costs 10+ seconds of load time.
2. **ComfyUI resident costs ~1.9GB.** Don't run it alongside a large model, or throughput falls from 30 to 5–10 tok/s.
3. **Any model ≥4.8GB must have exclusive use of VRAM.** Only two small models coexist (1.8B translation + 0.6B embedding).
4. **These numbers come from a single laptop.** Memory bandwidth, cooling, and power limits vary by model — treat them as **order-of-magnitude references**, not benchmarks.
5. Ternary quantization (PTQ1) is an extreme space-for-quality trade at 8GB. Long-form quality degrades; accept that before adopting it.

## License

Code: MIT. Documentation: CC BY-NC-SA 4.0 (redistribute freely, no commercial use). Model weights carry their own licenses — see [MODELS.md](MODELS.md). This repository does not distribute weights.
