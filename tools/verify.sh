#!/usr/bin/env bash
# One-command gate runner. Usage: TOOLS=/path/to/bins tools/verify.sh
# Needs: rojo 7.6.1, lune 0.10.4, stylua 2.6.0, luau-lsp 1.70.1 (pinned versions used for receipts).
set -uo pipefail
cd "$(dirname "$0")/.."
T="${TOOLS:-}"; b(){ if [ -n "$T" ]; then echo "$T/$1"; else echo "$1"; fi; }
mkdir -p build reports
status=0
echo "== versions"; $(b rojo) --version; $(b lune) --version; $(b stylua) --version; $(b luau-lsp) --version
echo "== G0 format check (stylua --check)"; $(b stylua) --check src || status=1
echo "== G0 rojo build"; $(b rojo) build default.project.json -o build/StealReality.rbxl || status=1
echo "== G0 strict type analysis (luau-lsp + Roblox definitions)"
$(b rojo) sourcemap default.project.json -o sourcemap.json >/dev/null
$(b luau-lsp) analyze --definitions=tools/globalTypes.d.luau --sourcemap=sourcemap.json --flag:LuauSolverV2=false src 2>&1 | grep -v -e '^\[INFO\]' -e '^\[WARN\]'
[ "${PIPESTATUS[0]}" -eq 0 ] && echo "ANALYZE_OK" || status=1
echo "== G0 place structure"; $(b lune) run tools/inspect_place.luau build/StealReality.rbxl || status=1
echo "== G1 headless Luau tests"; $(b lune) run tests/run.luau || status=1
echo "== G2-emulated: real server+client scripts in emulated Roblox runtime (NOT Studio)"; $(b lune) run tests/engine/emulated_runtime.luau build/StealReality.rbxl | grep -v "^\[SR\] t=" || status=1
echo "== Studio wrapper matches engine_task (minus final return)"
if diff <(sed '1,/^-- BEGIN engine_task/d' tools/studio/studio_engine_tests.luau) <(sed '$d' tools/opencloud/engine_task.luau) >/dev/null; then echo "WRAPPER_SYNC_OK"; else echo "WRAPPER_SYNC_FAIL"; status=1; fi
echo "== balance sweep"; $(b lune) run tools/balance_sweep.luau > reports/BALANCE_SWEEP.csv && head -1 reports/BALANCE_SWEEP.csv
echo "== sha256 of built place"; sha256sum build/StealReality.rbxl
echo "OVERALL_STATUS=$status"; exit $status
