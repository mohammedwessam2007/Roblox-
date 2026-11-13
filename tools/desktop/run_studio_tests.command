#!/bin/bash
# macOS one-click: run the engine test suite inside REAL Roblox Studio and save the output.
# Free tools only (hash-pinned): Rojo 7.6.1 and run-in-roblox 0.3.0 (x86_64; needs Rosetta on Apple Silicon).
# Nothing is published or uploaded. Output: reports/STUDIO_TEST_OUTPUT.txt
set -uo pipefail
cd "$(dirname "$0")/../.."
STUDIO=/Applications/RobloxStudio.app
if [ ! -d "$STUDIO" ]; then echo "Roblox Studio not found. Install it (free): https://create.roblox.com/docs/studio/setup"; exit 2; fi
BIN="$HOME/.stealreality-tools"; mkdir -p "$BIN"
if [ ! -x "$BIN/rojo" ]; then
  curl -fsSL -o "$BIN/rojo.zip" https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-macos-aarch64.zip || \
  curl -fsSL -o "$BIN/rojo.zip" https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-macos-x86_64.zip
  unzip -q -o "$BIN/rojo.zip" -d "$BIN" && chmod +x "$BIN/rojo"
fi
if [ ! -x "$BIN/run-in-roblox" ]; then
  curl -fsSL -o "$BIN/rir.zip" https://github.com/rojo-rbx/run-in-roblox/releases/download/v0.3.0/run-in-roblox-0.3.0-macos.zip
  echo "8c5326b7d18b9b9dc93f21fc5a02b7ba25b133bc1344d7878cb6ea072ab093f8  $BIN/rir.zip" | shasum -a 256 -c - || exit 3
  unzip -q -o "$BIN/rir.zip" -d "$BIN" && chmod +x "$BIN/run-in-roblox"
fi
git pull --ff-only || true
mkdir -p build reports && "$BIN/rojo" build test.project.json -o build/StealRealityTest.rbxl || exit 4
OUT=reports/STUDIO_TEST_OUTPUT.txt
{
  echo "date_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "os: macOS $(sw_vers -productVersion) $(uname -m)"
  echo "studio: $(defaults read "$STUDIO/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
  echo "place_sha256: $(shasum -a 256 build/StealRealityTest.rbxl | cut -d' ' -f1)"
  echo "command: run-in-roblox --place build/StealRealityTest.rbxl --script tools/studio/studio_engine_tests.luau"
  echo "---"
} > "$OUT"
echo "Launching Studio via run-in-roblox (Studio must be signed in)..."
"$BIN/run-in-roblox" --place build/StealRealityTest.rbxl --script tools/studio/studio_engine_tests.luau 2>&1 | tee -a "$OUT"
echo "exit_code: ${PIPESTATUS[0]}" >> "$OUT"
echo "Saved $OUT"; grep -E '^ENGINE_TESTS:|^FAIL ' "$OUT" || true
echo "If no ENGINE_TESTS line appeared: open build/StealRealityTest.rbxl in Studio, Test > Run, then paste"
echo "tools/studio/studio_engine_tests.luau into the server Command Bar and copy the Output into $OUT."
