# NR-002: tooling blockers in this sandbox (2026-11-12)
- `selene generate-roblox-std` exits with code 2 here. It could not fetch the Roblox API dump through the sandbox, so the Selene lint is **NOT_RUN**. Type and nil-safety checking is covered by `luau-lsp analyze` with the Roblox definitions file; that run is green.
- There is no Roblox Studio on Linux, so G2/G3 (engine runtime, two-client, network simulator) are **NOT_RUN**. A place file was built and its structure verified with `@lune/roblox`, but it has never been opened in Studio.
- The original synthesized WAVs have not been heard by a human and are not uploaded, so in-game `SOUND_IDS` are empty. Every cue has a visual equivalent.

## 2026-11-13: Studio run requested, but the session ran in the cloud
- **Expected:** a session on the owner's computer with Roblox Studio.
- **Observed:** a cloud Linux container. `list_computer_folders` returned no folders, so there was no Studio and no Windows/macOS.
- **Effect:** G2 and G3 stay NOT_RUN. No real-engine output was observed, so no NR-004 (real-engine bug) exists yet.
- **Mitigation:** `tools/desktop/run_studio_tests.{ps1,command}` reduces the real run to one command, and its output goes to `reports/STUDIO_TEST_OUTPUT.txt`. To run it, start Claude Code locally on that computer, or share the repo folder through Remote Control.
