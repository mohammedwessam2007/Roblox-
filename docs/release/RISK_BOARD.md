# Risk Board

STATUS: all risks open, nothing tested.

| # | Risk | Falsifier (what proves it wrong) | Mitigation |
|---|---|---|---|
| 1 | Game does not run/load in Studio | clean Studio test pass | run Studio test; fix before anything else |
| 2 | Not playable on phones (touch, perf) | 2+ phone devices complete a round | mobile test, Survival tier, large buttons |
| 3 | Core loop confusing (STEAL/THROW/PLANT) | pilot: most testers reach second_choice unaided | simplify prompts, shape cues |
| 4 | Nobody finds the game (zero traffic) | any organic sessions in 30 days | accept; no paid spend; iterate on thumbnail concepts |
| 5 | Replay rate low | pilot/server logs show voluntary_replay | tune AGAIN placement, round pacing |
| 6 | Exploits / teleport / remote spam | security counters stay low in logs | server-authoritative rules, rate limits already in Config.Security |
| 7 | Photosensitivity / motion discomfort | analysis tool + reduced motion pass | flash rules in ART_BIBLE, reduced-motion mode |
| 8 | Audio poor or fatiguing | auditioned on phone speaker, sound-off parity | revise synth params, mute option |
| 9 | Policy/eligibility mismatch | Creator Hub check at action date | eligibility matrix verification, owner approval |
| 10 | Revenue is zero | any real sale | costs $0; cosmetic only; no dependency on revenue |
