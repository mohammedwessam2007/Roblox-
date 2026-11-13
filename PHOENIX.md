# PHOENIX CHECKPOINT — 2026-11-13

**Objective:** a playable, server-authoritative Roblox build of STEAL REALITY! (Law Sport) and its challenger GRID HEIST, with real verification.
**Authority used:** local/private reversible work at $0. No publish, purchases, outreach, uploads or API keys.
**Lineage:** NEW clean-room (R13 unavailable; see `docs/SOURCE_RECOVERY_RECEIPT.md`).
**Persistence:** committed and pushed to `mohammedwessam2007/Roblox-` on branch `claude/optimistic-shannon-bkv3f3`. Check `git log` for the SHA.

## Reached
`CODE_WRITTEN → LUAU_TYPECHECKED → LUAU_TESTED (40/40) → ROJO_BUILT → G2-EMULATED (31/31, real scripts, not Studio)`. The emulated run found and fixed 4 real defects, 2 of them game-breaking (`docs/negative-results/NR-003`).
Evidence: `docs/ACTUAL_TEST_RECEIPTS.md`, `reports/VERIFY_RUN.txt`.

## Not reached (honest)
Studio single- and two-client runs, the network simulator, a real Android device, human players, asset upload, release, store and revenue. All are NOT_RUN or NOT_STARTED.

## What exists
- **Law Sport:** STEAL (prompt) → THROW (drag-aim slingshot, real misses, bank shots) or PLANT (gravity well with preview and Vault exclusion) → the Rogue Law Bot telegraphs then shoves, and a lawball can stun it → a server GoalWitness certifies the score → IMPOSSIBLE! card → one-tap AGAIN. Also: Elastic Recovery (flag), gravity snap-back, a 90 s clock.
- **Grid Heist:** CUT POWER (blackout, drone vision 34→13) → REROUTE SECURITY *or* OPEN ESCAPE (alarm trade-off) → GRAB CORE → escape. Drone detection uses line of sight; anti-teleport is enforced. Same HUD, AGAIN and polish level.
- **Platform:** zero-CCU solo works with no DataStore, no ghosts and no other players. Adaptive Reality offers 5 tiers plus Auto. Reduced motion and sound toggles. Touch, mouse/keyboard and gamepad paths.
- **Docs:** art bible, sound catalog, 12 original synthesized WAVs with SHA-256 provenance, playtest packet (AB/BA), economics scenarios (illustrative), store matrix (disabled placeholders), publishing, rollback, marketing shot list, risk board, analytics dictionary.

## 2026-11-13 update
A real Studio run was requested, but the session ran in cloud Linux, so it is NOT_RUN (`reports/STUDIO_RUN.md`). Added the one-command Studio test runner `tools/desktop/run_studio_tests.{ps1,command}` and the print-only wrapper `tools/studio/studio_engine_tests.luau`, whose sync with `engine_task.luau` is now gated in `verify.sh`. Gates re-run here: all green.

## Next task
The owner asked to stay out of the loop, so nothing is pending on them for the work Claude can do. Claude-side backlog, in order:
1. DONE: client-side smoothing proxies for the chicken and bot (presentation only; the server copies stay authoritative).
2. DONE: right-stick gamepad aim, ±60° off camera-forward, with no auto-target.
3. A podium and cosmetic preview, behind their existing flags and only after replay evidence exists.

## Gated outside Claude's reach (parked, no action requested)
These need the owner's Roblox account or explicit consent. They are not done and are not claimed:
- A real Studio and device run. This environment has no Studio, so G2/G3/G4 are NOT_RUN.
- Uploading audio (needs account credentials). The game is silent, with visual parity.
- Recruiting human players, publishing, store activation, and DevEx. These need explicit approval and the account, and there is no auto-approval.

## Rollback
Every step is a git commit; `git revert <sha>`. Nothing has been deployed, so nothing needs rolling back live.

## 2026-11-13 UTC — offline reconnect regression fixed (NR-004)
- **Verified original defect:** after scoring, leaving and rejoining a still-running server recycled `scoredEventId`, silently suppressing the next legitimate award. Mode switches also recycled match IDs.
- **RED** `tests/rejoin.spec.luau`: 40 passed, **3 failed**, demonstrated at https://github.com/mohammedwessam2007/Roblox-/actions/runs/43517086416.
- **GREEN** monotonic per-user match IDs in `src/shared/MatchCore.luau`: **43/43** Luau rule tests and **31/31** emulated server/client checks, strict Luau and Rojo PASS at https://github.com/mohammedwessam2007/Roblox-/actions/runs/43517439561.
- **Actual Roblox engine** NOT_RUN; no Studio/device/player evidence. See `docs/negative-results/NR-004_reconnect_certificate_collision.md` for falsifier, repair, receipts and cross-server persistence limitations.
- **Source authority:** this is a private, reversible source/test improvement. Fable remains the primary game engineer. No account, publication, product or secret action performed.
