# NR-002: tooling blockers in this sandbox (2026-11-12)
- `selene generate-roblox-std` exits with code 2 here. It could not fetch the Roblox API dump through the sandbox, so the Selene lint is **NOT_RUN**. Type and nil-safety checking is covered by `luau-lsp analyze` with the Roblox definitions file; that run is green.
- There is no Roblox Studio on Linux, so G2/G3 (engine runtime, two-client, network simulator) are **NOT_RUN**. A place file was built and its structure verified with `@lune/roblox`, but it has never been opened in Studio.
- The original synthesized WAVs have not been heard by a human and are not uploaded, so in-game `SOUND_IDS` are empty. Every cue has a visual equivalent.
