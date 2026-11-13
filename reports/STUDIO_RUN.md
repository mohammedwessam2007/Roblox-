# STUDIO RUN — 2026-11-13

## Verdict: real Roblox Studio was **NOT_RUN** in this session

The task was written for a session on the owner's own computer. The session actually ran in a
**cloud Linux container** (`Linux 6.18 x86_64`). It had no Roblox Studio, no Windows/macOS, no
display, and no access to the owner's computer: `list_computer_folders` returned no shared folders.
Roblox Studio does not run on Linux. Every Studio row below is therefore **NOT_RUN**. Nothing here
was observed in Studio, and no Studio output is claimed.

| Step | State | Notes |
|---|---|---|
| 1. Studio installed? | **NOT_RUN** | Not checkable from this container |
| 2. Build `StealReality.rbxl` + `StealRealityTest.rbxl` | PASS (Linux) | Rojo 7.6.1, see hashes below |
| 3. Engine tests in real Studio (run-in-roblox / Command Bar) | **NOT_RUN** | Runner prepared: `tools/desktop/run_studio_tests.{ps1,command}` |
| 4. Play test (Law Sport, Grid Heist), Output window | **NOT_RUN** | Needs a person in Studio |
| 4b. Server & 2 Clients, 150 ms Network Simulator (G3) | **NOT_RUN** | — |
| 5. Fix real-engine errors | N/A | No real-engine output was observed, so no real-engine bug was found or fixed |
| 7. Private test experience IDs | **NOT_RUN** | Not asked: it needs the owner in Studio |

## What did run here (cloud Linux, 2026-11-13)
Command: `TOOLS=~/srbin tools/verify.sh` (full log in `reports/VERIFY_RUN.txt`).
Tools: rojo 7.6.1, lune 0.10.4, stylua 2.6.0, luau-lsp 1.70.1, all from their official GitHub releases.

```
ANALYZE_OK
PLACE_STRUCTURE_OK
RESULT: 40 passed, 0 failed
EMULATED_RUNTIME: 31 passed, 0 failed, 0 script errors
WRAPPER_SYNC_OK
OVERALL_STATUS=0
```

- `rojo build default.project.json` → `build/StealReality.rbxl`, sha256 `90da2b8ad36cc8b9918f3a53122a9b9f4e48e8e86112b9b89dc339b74ce6ba35`
- `rojo build test.project.json` → `build/StealRealityTest.rbxl`, sha256 `66e8d488a83b68d08201723afdb1640dd8218b511a4140b9c60dd085722654a5`

The emulated runtime is **not** the Roblox engine. It has no physics, rendering, replication or
real networking. See `docs/ACTUAL_TEST_RECEIPTS.md`.

## Prepared so the real run takes one command on the owner's computer
- `tools/studio/studio_engine_tests.luau`: a copy of `tools/opencloud/engine_task.luau` that only
  prints its result (run-in-roblox needs printed output). It prints `ENGINE_TESTS: N passed, M failed`
  and every `FAIL` line. `tools/verify.sh` now fails if it drifts from `engine_task.luau` (`WRAPPER_SYNC_OK`).
- `tools/desktop/run_studio_tests.ps1` (Windows) and `run_studio_tests.command` (macOS):
  1. Check that Studio is installed; if not, print the installer link and stop.
  2. Install hash-pinned Rojo 7.6.1 and run-in-roblox 0.3.0. Both are free; no other tools are installed.
  3. Build `build/StealRealityTest.rbxl`.
  4. Run `run-in-roblox --place build/StealRealityTest.rbxl --script tools/studio/studio_engine_tests.luau`.
  5. Write the date, OS, Studio version, place hash, command and full output to `reports/STUDIO_TEST_OUTPUT.txt`.

  Pinned run-in-roblox v0.3.0 hashes (computed here): win64 `590738bf…2440f`, macos `8c5326b7…093f8`.
  Caveat (UNKNOWN until tried): run-in-roblox 0.3.0 dates from 2020 and may not work with current
  Studio. The macOS build is x86_64 and needs Rosetta on Apple Silicon. The script prints the
  Command Bar fallback if no `ENGINE_TESTS` line appears.

## To finish this report (owner, about 5 minutes)
Windows, from the repo folder:

```
powershell -ExecutionPolicy Bypass -File tools\desktop\run_studio_tests.ps1
```

macOS: double-click `tools/desktop/run_studio_tests.command`.

Then press **Play** in Studio for one round of each game. Afterwards, ask Claude Code **on that
computer** to read `reports/STUDIO_TEST_OUTPUT.txt` and the Output window, fix anything, and fill
this file in.
