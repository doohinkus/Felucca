# AGENTS.md

Guidance for AI agents (and humans) working in this repo. It's developed with AI assistance, so the quality bar is the same for every PR: keep it focused, and test it.

## What this is

C firmware for the M-VAVE FM-1 synthesizer (JieLi AC79 / pi32v2 toolchain), plus Python build tooling (`tools/`), host tests (`tests/`), and web assets (`web/`: editor protocol docs, mock-device tests, browser emulator). The web editor and installer UI live in a separate repo: Felucca-WebApp.

## Build and test (macOS)

- `./build.sh` — needs Docker Desktop running (the Linux-only JieLi toolchain runs in per-tool `linux/amd64` containers), Python 3 + Pillow + fontTools, the toolchain (`tools/get_toolchain.sh` → `~/.jieli/toolchain`), and the AC79 SDK (`~/fw-AC79_AIoT_SDK`, commit `AC79NN_SDK_V1.2.1_2023-12-13`). `JIELI_TOOLCHAIN` / `AC79_SDK` override these.
- `tests/run_tests.sh` — run from the repo root **after** `./build.sh` (it compiles against `build/gen/` artifacts and needs `AC79_SDK` set). Order matters: build → test.
- Node is optional for the web tests (`node web/test_web.mjs`); Emscripten (`emcc`) for the browser emulator.
- Run the full suite after every change. There is no CI: the host tests are the only gate, so PRs must show `tests/run_tests.sh` passing.
- Features must be verified on a real FM-1 by whoever can; ask the maintainer if you can't.

## Browser emulator

- `sh web/emu/build.sh` → `build/emu/{index.html, worklet.js, felucca.wasm, fonts/}` after one `./build.sh` (it needs `build/gen/`). `emcc` is installed but not on PATH — `source ~/emsdk/emsdk_env.sh` first.
- The emulator compiles the firmware's actual sources (`web/emu/felucca_web.c` includes `ui_graph.c`, `ui_draw.c`, …), so firmware UI changes appear only after a rebuild — a stale `build/emu/felucca.wasm` shows old screens. No web-side work is needed: its `lcd_blit` writes the same framebuffer the worklet copies whole to the page every frame (`web/emu/worklet.js`).
- Check it with `node web/emu/emu_test.mjs` (all ok), then serve and look: `python3 -m http.server 8000 --directory build/emu` → http://localhost:8000 (AudioWorklet needs http(s); `file://` won't run). Screenshots via Playwright on the `#screen` element; take two a moment apart — the animated bits (LED idle animation, sway etc.) change per frame phase, so compare within one phase.

## Commands an agent would guess wrong

- Single test: tests compile individually — `cc -O1 -w -Ibuild/gen -Ifirmware/src -o /tmp/t tests/foo_test.c -lm && /tmp/t` (see the corresponding compile line in `tests/run_tests.sh` for the right `-D` flags).
- After an **intended** sound change: `GOLDEN_UPDATE=1 sh tests/run_tests.sh` rewrites `tests/golden.txt` (`BUDGET_UPDATE=1` for `cpu_baseline.txt` / `target_budget.txt`). Only update baseline entries for reviewed, intentional differences; keep every unaffected entry.
- `./build.sh --release X.Y` makes the release package identity `FM-1_910`; dev builds are `FM-1_900`.
- Build toggles via env flags (`FELUCCA_SLICE`, `FELUCCA_FM4`, `FELUCCA_CDC`, `FELUCCA_UAC`, … — defaults in `firmware/src/felucca.c`, `core.h`, `icons.c`; full table in BUILDING.md). The DIGITAL (FM4) engine is retired and off by default (`FELUCCA_FM4=0`) but its tests build with `-DFELUCCA_FM4=1`.
- Default builds without `assets/samples-cc0/` still work, but SAMPLE/SLICE lose the instrument sets — `python3 tools/fetch_cc0.py` fetches them.

## Regression-suite gates that fail for good reasons

- Golden renders: an output change to sound intent fails unless you update `tests/golden.txt` on purpose; silent sound changes will fail, which is the point.
- CPU / target budget (+25 % / +10 % thresholds): performance regressions in the render loops fail. The "target" numbers come from static analysis of the pi32v2 disassembly (`build/felucca.dis`).
- "Bit for bit" invariants: identical input must give identical output for OFF/default states (mod slots, reverb models, USB audio, etc.).
- UI layout lint / 1px alignment: text and drawings offscreen / overlapping / misaligned fail the render check; PNGs land in `build/ui_new/`.

## Conventions

- All new files carry the `SPDX-License-Identifier: GPL-3.0-only` header (see CONTRIBUTING.md).
- `CONTRIBUTING.md` is the PR bar: keep it small and focused, be able to explain the change, run tests, test on a real FM-1.
- The firmware sources live under `firmware/src/` (flat C files: `eng_*.c` per engine, `ui_*.c`, `editor_*.c`); code generation is Python in `tools/gen_*.py` and its outputs go to `build/gen/` (e.g. `felucca_tables.h`, `ui_fonts.h`).
