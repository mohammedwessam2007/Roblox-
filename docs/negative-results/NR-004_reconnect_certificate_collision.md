# NR-004 — Reconnecting after a win recycled the goal certificate ID

**Date:** 2026-11-13 UTC. **Scope:** STEAL REALITY! / Law Sport, MatchCore per-player match lifecycle.

## Actual defect
`MatchCore.join` initialized `nextMatchNo = 1` on each player join, while `core.certified` is retained for the lifetime of the server. A player who scored a legitimate goal, disconnected and rejoined the SAME server was given a recycled `u<userId>-m1:r1:<ruleset>` certificate. The second goal reached `Won` but was ignored by the server award ledger as already certified.

Mode switches made this worse by reusing match sequence IDs after reconnect. Previous tests only exercised replay inside one uninterrupted connection.

## Fair falsifier / red receipt
Created `tests/rejoin.spec.luau` with three independent regressions using the project's actual `MatchCore`, `LawSim`, and scripted skilled-player route:
1. The same user must receive a distinct match ID after leaving.
2. Two **legitimate** consecutive wins separated by disconnect must mint distinct score certificates and raise `core.awards[userId]` from 1 to 2.
3. Mode switches before disconnect must not recycle a previously used match identity after reconnect.

On original code, CI **failed as expected**: `RESULT: 40 passed, 3 failed` for the three new cases.
RED: https://github.com/mohammedwessam2007/Roblox-/actions/runs/43517086416

## Repair
Added a server-owned per-user monotonic `nextMatchNoByUser` register to `Core`. On each new simulation, reserve the next number before creating the match, including each mode switch. On rejoin, restore the last reserved number instead of resetting to 1. All certificates remain server-generated; no client identity, event ID or score is trusted.

This preserves previous replay, session-slot recycling, isolation, and CR-001/CR-002 behavior.

## Green receipt
GREEN: https://github.com/mohammedwessam2007/Roblox-/actions/runs/43517439561
- G1 Luau suite: **43 passed, 0 failed**, including all 3 reconnect tests.
- Emulated real server/client scripts: **31 passed, 0 failed**, 0 errors.
- StyLua, strict type analysis, Rojo build, place structure, wrapper sync and balance sweep: PASS.
- Real Roblox engine and actual Studio/Android gameplay: **NOT_RUN**. This is an offline algorithmic bug fix, not a claim of engine/device validation.

## Limitations and future challenge
This server-session sequence register and awards ledger are NOT a cross-server persistence mechanism. Durable progression would need a separately scoped, correctly idempotent DataStore design, verified on an authorized private experience. Long-running server memory policies for awarded IDs have not yet been load-tested; no fabricated scaling claims.

**Release authority:** local/private reversible code and CI only. No publication, monetization, assets, accounts, credentials or spending.
