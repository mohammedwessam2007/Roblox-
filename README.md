# STEAL REALITY! — The Impossible Relay (+ Grid Heist challenger)

An original Roblox physics-heist sport. Steal gravity from a Giant Golden Chicken. Then THROW your lawball to redirect it, or PLANT a gravity well, and get it past the Rogue Law Bot into the Vault. Scoring is server-certified. The challenger game, **The City Blinks: Grid Heist**, ships in the same place file.

**Status (honest):** source written, strictly type-checked, Rojo-built and passing 37 headless Luau tests. **Not yet run in Roblox Studio, on a phone, or with players.** See `PHOENIX.md` and `docs/ACTUAL_TEST_RECEIPTS.md`.

## Play it (owner, $0)
```bash
rojo build default.project.json -o StealReality.rbxl   # Rojo 7.6.1
# open StealReality.rbxl in Roblox Studio -> Play  (or Test -> Server & 2 Clients)
```
Controls:
- **Touch:** walk to the chicken and tap **STEAL GRAVITY**. Press and drag **THROW**: sideways sets the angle, up sets the power, release fires, drag down cancels. **PLANT** works the same way to place the well. **RECOVER** appears after a miss.
- **Keyboard/mouse:** E steal, hold F throw toward the cursor, hold R plant, Q recover, Enter again.
- **Gamepad:** X steal, hold R2 throw, hold L2 plant, B recover, A again.
- After a round, the outcome card offers **AGAIN** or **OTHER GAME** (Grid Heist).

## Verify
```bash
TOOLS=/path/to/bins tools/verify.sh   # stylua, rojo build, luau-lsp strict analyze, place inspection, lune tests, balance sweep
```

## Layout
- `src/shared/`: pure-Luau, server-authoritative rules (`LawSim`, `HeistSim`, `GoalWitness`, `MatchCore`, `Protocol`, `ElasticRecovery`, `AdaptiveQuality`, `Config`)
- `src/server/`: Roblox glue and the procedural original world (`WorldBuilder`)
- `src/client/`: HUD, aim preview, FX, settings
- `tests/`: Lune test runner, specs, and the vulnerable red-reproduction fixture
- `docs/`: ADRs, receipts, art and sound, playtest, economics, release, analytics
- `assets/audio/`: original synthesized cues (not uploaded)
