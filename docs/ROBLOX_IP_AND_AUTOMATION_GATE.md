# Roblox Open Cloud automation: IP, secrets, and real-engine gate

## Verified context (2026-11-13)

The main Roblox repository already builds its private .rbxl and passes the headless suite. The original verify.yml injected ROBLOX_API_KEY into the entire test job, and silently skipped the real engine when the secret was absent. This proposed workflow makes the skip explicit and only injects the secret into the private-engine step. It also uses pipefail so a failing test command cannot appear successful just because tee exited successfully.

## Roblox rejects IP during API key setup

- The Roblox Open Cloud API key IP restriction toggle is optional. For changing egress IPs (GitHub-hosted runner or hosted Claude/Work), leave Restrict IP addresses OFF instead of trying to enter your phone's or home IP. This is officially supported; it increases risk if the key is stolen.
- Prefer a trusted static outbound IP and IP restrictions when available at $0. Do not create a VPN, pay for cloud machines, or bypass a Roblox account restriction.
- Bind the key to one PRIVATE test experience and minimal access: Luau execution task read/write, and universe-places write only where the existing pipeline must save a private place version. Give assets upload a separate key only if explicitly authorized.
- Store the key only in GitHub Actions secret ROBLOX_API_KEY or a trusted secret form. Never in code, chat, CI logs, or artifacts. Do not grant product, moderation, ban, monetization, or unrelated experience access.
- GitHub repository variables ROBLOX_UNIVERSE_ID and ROBLOX_PLACE_ID are NON-SECRET IDs for the private test place.
- A key given to Claude's secure credential form is NOT automatically copied into GitHub Actions secrets.
- GitHub Actions cannot create the first Roblox key or override account identity checks. An authorized Roblox account holder must make the first account credential/experience available. The owner can delegate authorized GUI work to Work when a real supported environment is available.

## Automatic on each push / PR

1. Validate preflight unit tests and run existing game-format, strict type, Rojo, Luau, emulation, and balance-sweep tests.
2. Fail honestly on actual source test failures and upload available receipts even when the run fails.
3. On trusted development branch push ONLY, check the existence (without reading key bytes) of the GitHub secret and the two IDs. Emit reports/OPEN_CLOUD_PREFLIGHT.json and an Actions job summary.
4. When ready, the existing Open Cloud pipeline saves a NONPUBLISHED private test-place version and executes Luau inside a real Roblox server; any Roblox 401/403 is a failure, not a PASS.
5. Without configuration, report BLOCKED_MISSING_CONFIG. Source CI can PASS while the real-engine status remains NOT_RUN.

## Still separate approval / actual environment required

Roblox Studio visual QA, physical phone/device tests, human playtests, audio upload, public publishing, store activation, and DevEx are not completed by this patch. A browser seeing Roblox's website is not a Studio gameplay session. The GitHub-hosted Windows runner starting a Studio process is not evidence of pressing Play or running an interactive game test.

## Verification and rollback

- Local unit tests: python3 -m unittest discover -s tests/python -v (5 cases).
- Example preflight: OPEN_CLOUD_ALLOWED_EVENT=true python3 tools/automation/opencloud_preflight.py
- Proposed in a draft PR, leaving the default branch unchanged until an authorized engineering review and merge.
- Nothing runs on Roblox unless the private testing secret and IDs are intentionally configured.

Official references:
- https://create.roblox.com/docs/cloud/auth/api-keys
- https://create.roblox.com/docs/cloud/reference/scopes
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
