# NR-001: the first CR-002 isolation test was invalid (2026-11-12)
- Reproducer: the first version of `security.spec` asserted that B's chicken position was unchanged after A's throw. It failed because B's own floating chicken drifts after B's steal (a lift wobble plus drag integration). That drift is legitimate, not leaked state.
- Fix: the test now runs a control scenario with the same inputs minus A's throw and requires B's state to match bit for bit (x, z, vx, vz, bot, phase). It passes.
- Lesson: you can't prove isolation by assuming a "frozen" neighbour. Compare against a counterfactual control (canon #0001 causal / #0011 discriminating experiment).
