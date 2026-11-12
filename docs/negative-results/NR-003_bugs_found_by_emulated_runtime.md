# NR-003: real defects found by the emulated Roblox runtime (2026-11-12)

`tests/engine/emulated_runtime.luau` runs the actual built Server Script and Client LocalScript. Instance properties are checked against Roblox's reflection database (via Lune). Engine services are emulated. In that runtime it surfaced four defects, all of which would have shown up in Studio:

1. **Players.MaxPlayers write.** The server set `Players.MaxPlayers`, which scripts cannot write in Roblox. Removed.
2. **Prompt/sequence collision (game-breaking).** A ProximityPrompt STEAL advanced the client's sequence counter, so the player's next THROW (seq 1) was rejected as `replayed_seq`. Law Sport became unplayable after the first tap. Fix: `MatchCore.serverIntent` gives server triggers their own path, and it is allowlisted to prompt actions. A regression test was added.
3. **Anti-teleport lockout (game-breaking for Heist).** Server-initiated moves (spawn, respawn, fall recovery) were judged as teleports, so the speed-bounded track never updated and the player could never act again. Fix: `MatchCore.resetTrack` is called after every server PivotTo. A regression test was added.
4. **The bot assisted goals (design).** The bot's counter shoved the chicken "away from the bot". Once the chicken had passed the bot, that pushed it toward the Vault. Fix: the counter now always pushes away from the Vault, with a regression test over 4 geometries. As a result, a single straight throw from spawn no longer scores reliably. Players must stun the bot, time it, or use a well. The balance sweep was re-run.

Harness quirk (not a game bug): Lune's `CFrame.lookAt(...).LookVector` points away from the target. The harness builds the camera ray from the intended target instead.
