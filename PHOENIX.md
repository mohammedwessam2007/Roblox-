# PHOENIX CHECKPOINT — 2026-11-12

**Objective:** a playable, server-authoritative Roblox build of STEAL REALITY! (Law Sport) and its challenger GRID HEIST, with real verification.
**Authority used:** local/private reversible work at $0. No publish, purchases, outreach, uploads or API keys.
**Lineage:** NEW clean-room (R13 unavailable; see `docs/SOURCE_RECOVERY_RECEIPT.md`).
**Persistence:** committed and pushed to `mohammedwessam2007/Roblox-` on branch `claude/optimistic-shannon-bkv3f3`. Check `git log` for the SHA.

## Reached
`CODE_WRITTEN → LUAU_COMPILED/TYPECHECKED → LUAU_TESTED (37/37) → ROJO_BUILT`.
Evidence: `docs/ACTUAL_TEST_RECEIPTS.md`, `reports/VERIFY_RUN.txt`.

## Not reached (honest)
Studio single- and two-client runs, the network simulator, a real Android device, human players, asset upload, release, store and revenue. All are NOT_RUN or NOT_STARTED.

## What exists
- **Law Sport:** STEAL (prompt) → THROW (drag-aim slingshot, real misses, bank shots) or PLANT (gravity well with preview and Vault exclusion) → the Rogue Law Bot telegraphs then shoves, and a lawball can stun it → a server GoalWitness certifies the score → IMPOSSIBLE! card → one-tap AGAIN. Also: Elastic Recovery (flag), gravity snap-back, a 90 s clock.
- **Grid Heist:** CUT POWER (blackout, drone vision 34→13) → REROUTE SECURITY *or* OPEN ESCAPE (alarm trade-off) → GRAB CORE → escape. Drone detection uses line of sight; anti-teleport is enforced. Same HUD, AGAIN and polish level.
- **Platform:** zero-CCU solo works with no DataStore, no ghosts and no other players. Adaptive Reality offers 5 tiers plus Auto. Reduced motion and sound toggles. Touch, mouse/keyboard and gamepad paths.
- **Docs:** art bible, sound catalog, 12 original synthesized WAVs with SHA-256 provenance, playtest packet (AB/BA), economics scenarios (illustrative), store matrix (disabled placeholders), publishing, rollback, marketing shot list, risk board, analytics dictionary.

## Next authorized task
Owner opens `build/StealReality.rbxl` in Studio (rebuild with `rojo build`) and plays single-client, then **Test → Server & 2 Clients** with the network simulator at 150 ms. Report the Output log. I fix whatever breaks.

## Owner-only blockers (max 3)
1. **Studio run.** Install Rojo 7.6.1, run `rojo build default.project.json -o StealReality.rbxl`, open the file in Studio and press Play. Cost: $0, about 10 minutes. Safe default: nothing is published.
2. **Audio upload.** Upload `assets/audio/*.wav` via Creator Hub → Audio (free quota permitting) and paste the ids into `SOUND_IDS` in `src/client/init.client.luau`. Safe default: silent, with visual parity.
3. **Pilot approval.** Approve (or don't) recruiting 10–20 consenting first-time players per `docs/playtest/PRE_REGISTERED_PILOT.md`. Safe default: no outreach.

## Rollback
Every step is a git commit; `git revert <sha>`. Nothing has been deployed, so nothing needs rolling back live.
