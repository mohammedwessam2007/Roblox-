#!/bin/bash
# macOS one-click: build the latest game and open it in Roblox Studio.
set -euo pipefail
cd "$(dirname "$0")/../.."
BIN="$HOME/.stealreality-tools"; mkdir -p "$BIN"
if [ ! -x "$BIN/rojo" ]; then
  curl -sSL -o "$BIN/rojo.zip" https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-macos-aarch64.zip || \
  curl -sSL -o "$BIN/rojo.zip" https://github.com/rojo-rbx/rojo/releases/download/v7.6.1/rojo-7.6.1-macos-x86_64.zip
  unzip -q -o "$BIN/rojo.zip" -d "$BIN" && chmod +x "$BIN/rojo"
fi
git pull --ff-only || true
mkdir -p build && "$BIN/rojo" build default.project.json -o build/StealReality.rbxl
shasum -a 256 build/StealReality.rbxl
open build/StealReality.rbxl
echo "In Studio: press Play. Private test experience: File > Publish to Roblox As > Create new experience."
