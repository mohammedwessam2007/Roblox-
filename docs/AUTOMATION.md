# Automation: how this project runs with zero owner work

| Workflow | How it's automated | Status |
|---|---|---|
| Format, build, strict typecheck, 40 rule tests, emulated runtime, balance sweep | `.github/workflows/verify.yml` on every push (GitHub Actions free minutes) | ACTIVE after push |
| Real Roblox engine tests (no Studio) | `tools/opencloud/pipeline.py engine-test`: Rojo builds the test place, Open Cloud saves a **private** place version (`versionType=Saved`, never Published), Luau Execution runs `tools/opencloud/engine_task.luau` inside a real Roblox server, and results go to `reports/ENGINE_RUN.json` | Needs a one-time API key + private experience; first live run not yet done |
| Audio upload | `pipeline.py upload-audio` uploads `assets/audio/*.wav` and writes `reports/AUDIO_ASSET_IDS.json` | Needs the same key (Assets read+write scope); not yet run |
| Two-client / network-lag / phone tests | Not automatable without Studio or real devices. The emulated runtime covers script logic only | NOT_RUN |
| Human playtests, publishing, store, DevEx | **Not automated on purpose.** These need real people, account identity, and your explicit approval | Gated |

One-time setup (about 5 minutes, then never again):
1. Creator Hub → Creations → New Experience. Keep it **private**. Copy its Universe ID and Place ID.
2. Creator Hub → Open Cloud → API Keys → Create. Add the **Luau Execution**, **Universe Places (write)** and **Assets (read/write)** scopes, limited to that one experience.
3. Enter the key through the secure form Claude opened, or add it as GitHub secret `ROBLOX_API_KEY`. Add GitHub variables `ROBLOX_UNIVERSE_ID` and `ROBLOX_PLACE_ID`.

Scope names follow the Creator Hub UI as of 2026-11-12. If a label differs, choose the matching capability.
