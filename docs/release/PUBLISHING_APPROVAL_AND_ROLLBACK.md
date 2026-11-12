# Publishing Approval and Rollback

STATUS: no publishing has occurred. Every step needs explicit owner approval.

## Approval checklist (all must be checked by owner)
- [ ] Studio build tested (NOT_RUN) and phone tested (NOT_RUN)
- [ ] Pilot results reviewed (NOT_RUN)
- [ ] Assets uploaded, moderated, IDs recorded in ASSET_PROVENANCE.csv
- [ ] Eligibility matrix verified at action date
- [ ] Product matrix: passes created, prices confirmed, still cosmetic-only
- [ ] Analytics/privacy review (no PII, no external sink approved)
- [ ] Owner sign-off: name/date

## Publish steps (owner or owner-approved)
1. Publish to private/unlisted first. 2. Smoke test with owner. 3. Enable products one at a time. 4. Go public only on owner's word.

## Rollback
- Set game to private / unpublish via Creator Hub.
- Disable passes (state DISABLED); revert to previous place version via Version History.
- Flip feature flags (Config.Flags) to safe defaults in a new version.
- Log incident, cause, and fix in RISK_BOARD.md. Refund/support handled per Roblox process.
