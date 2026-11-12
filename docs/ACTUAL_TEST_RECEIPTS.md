# ACTUAL TEST RECEIPTS — 2026-11-12 (cloud Linux sandbox)

Full raw log: `reports/VERIFY_RUN.txt`, produced by `TOOLS=<bins> tools/verify.sh`.

| Gate | State | Evidence |
|---|---|---|
| CODE_WRITTEN | DONE | `src/` (8 shared modules, server, client) |
| G0 format | PASS | `stylua 2.6.0 --check src` |
| G0 lint (Selene) | **NOT_RUN** | blocked; see `docs/negative-results/NR-002` |
| LUAU strict typecheck | PASS | `luau-lsp 1.70.1 analyze` with the Roblox `globalTypes.d.luau` and a Rojo sourcemap: 0 diagnostics over all server, client and shared scripts |
| ROJO_BUILT | PASS | `rojo 7.6.1 build` → `build/StealReality.rbxl` (git-ignored; rebuild with the command). Structure verified by `tools/inspect_place.luau` → `PLACE_STRUCTURE_OK` |
| LUAU_TESTED (G1 headless) | PASS 40/40 | `lune 0.10.4 run tests/run.luau`. The tests execute the same ModuleScripts the server runs |
| Balance sweep | RUN | `reports/BALANCE_SWEEP.csv`. 2,356 simulated single throws. After the bot-counter fix (NR-003), a precise (<5°) full-power shot from spawn scores 46% on its own; otherwise the player must stun the bot or use a well; shots >10° off score ~0% unless they bank off geometry. Simulation only, **not player data** |
| G2-EMULATED runtime | PASS 31/31, 0 script errors | `tests/engine/emulated_runtime.luau` runs the **built** Server Script + Client LocalScript against Lune's reflection-validated Roblox instance model with emulated services: join, HUD build, client smoothing proxies, prompt STEAL, client F-key aim THROW, bot counter, bot stun, server-certified goal, AGAIN, forged remotes, 2nd player isolation/cleanup, OTHER GAME, Heist blackout/lamps/color grade, REROUTE, teleport rejection, analytics names. Found 4 real defects (NR-003). **Not Studio**: no physics, rendering, replication or real networking |
| STUDIO_SINGLE_CLIENT (G2) | **NOT_RUN** | no Studio in this environment |
| STUDIO_2_CLIENT / 150 ms RTT (G3) | **NOT_RUN** | — |
| REAL_ANDROID (G4) | **NOT_RUN** | — |
| REAL_FIRST_TIME_PLAYERS (G5) | **NOT_RUN** | requires owner approval; packet ready in `docs/playtest/` |
| Release / store / revenue | **NOT_STARTED** | no publish, no product ids, no purchases |

## Required regressions covered by G1 tests
- Forged SCORE/Goal/Win remotes → `unknown_action`, zero awards. Forged `score`, `userId`, `position`, `matchId`, `win` and `price` fields → `unknown_field`.
- Red→green: the vulnerable `NaiveServer` fixture accepts a forged SCORE and leaks cargo across players; `MatchCore` does neither.
- Cargo in the Vault without a cause, with only a steal, or with an expired cause → no score. Interrupted dwell resets. NaN is rejected. The witness is idempotent, and the award ledger grants exactly 1 over 1,000+ extra ticks.
- A's throw leaves B identical to a counterfactual control run. Standing in B's arena cannot steal B's chicken. Slots are freed and reused cleanly.
- Replayed seq, NaN/inf, wrong types, metatables, oversize payloads, missing fields, unknown modes and bursts above the rate limit are all rejected.
- Elastic Recovery: one use per real miss, only inside the 2.5 s window, and it never moves cargo or scores. Flag off → denied.
- Heist: teleporting to the exit is rejected (speed bound), there is no win without the core, line of sight is blocked by buildings, the blackout shrinks drone vision, the REROUTE/OPEN ESCAPE choice is exclusive, and escape mints its id exactly once.
- Adaptive Reality: stepwise hysteresis (no oscillation), respects the user's own cap and manual override, and no FX key collides with a gameplay constant.
- Fuzz: 20,000 random intents and steps (including NaN dt) keep the sim finite, bounded and within the event cap.
