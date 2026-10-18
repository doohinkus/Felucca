#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Leo Kuroshita (@kurogedelic), Hügelton Instruments
# The development loop's look: rebuild the browser emulator from the firmware's current sources
# (web/emu/build.sh), check it (emu_test.mjs against the native build), then serve it.
#   source ~/emsdk/emsdk_env.sh        (once per shell, if emcc is not on PATH)
#   sh web/emu/preview.sh [PORT]       (default 8000; ctrl-c stops the server)
# After one ./build.sh (build/gen: the tables, the fonts, the CC0 samples). A change of the
# firmware's sources shows only after a rebuild - run this again (it is quick), then reload the page.
set -e
cd "$(dirname "$0")/../.."
EMUPORT=${1:-8000}
if [ ! -f build/gen/felucca_tables.h ]; then
    echo "preview: run ./build.sh once first (build/gen: the tables, the fonts)"
    exit 1
fi
if ! command -v emcc >/dev/null 2>&1; then
    echo "preview: emcc not on PATH (source ~/emsdk/emsdk_env.sh)"
    exit 1
fi
if ! command -v node >/dev/null 2>&1; then
    echo "preview: node missing (the emulator's check needs it)"
    exit 1
fi
sh web/emu/build.sh
# emu_test.mjs compares the wasm's song against the native build's, so the reference has to exist
if [ ! -x build/host/emu_native ] || [ -n "$(find firmware web/emu -name '*.c' -newer build/host/emu_native -print -quit 2>/dev/null)" ]; then
    cc -O2 -ffp-contract=off -w -Ibuild/gen -Ifirmware/src -o build/host/emu_native web/emu/native_check.c -lm
    build/host/emu_native build/host/emu_native.f32
fi
node web/emu/emu_test.mjs build/emu/felucca.wasm build/host/emu_native.f32
echo "preview: http://localhost:$EMUPORT  (the screen is #screen; the worklet runs the audio mux)"
exec python3 -m http.server "$EMUPORT" --directory build/emu
