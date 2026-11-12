# assets/audio

Original SFX synthesized by `tools/synth_audio.py` (numpy + stdlib `wave`). Deterministic: re-running yields byte-identical files (seed 1337).

Format: mono, 44.1 kHz, 16-bit PCM, peak normalized to -3 dBFS, 4 ms edge fades (except `gravity_well_hum`, which is DC-free with all components at multiples of 0.5 Hz so the 2.0 s loop is seamless).

Regenerate: `python3 tools/synth_audio.py`

| File | Length |
|---|---|
| steal_suction | 0.70 s |
| lawball_throw_whoosh | 0.45 s |
| gravity_well_hum (loop) | 2.00 s |
| bank_boing | 0.55 s |
| bot_telegraph_alert | 1.10 s |
| rubberband_recover | 0.60 s |
| vault_swallow_victory | 0.80 s |
| miss_squeak | 0.30 s |
| ui_press | 0.09 s |
| blackout_powerdown | 1.40 s |
| drone_alarm | 1.00 s |
| heist_escape_sting | 1.00 s |

Status: NOT_UPLOADED to Roblox. NOT auditioned in Studio or on phone speakers. These are first-pass placeholders; quality is unvalidated. Roblox audio upload moderation/ID assignment is an owner action. Hashes: `docs/art/ASSET_PROVENANCE.csv`. Mapping to triggers: `docs/art/SOUND_CUE_CATALOG.md`.
