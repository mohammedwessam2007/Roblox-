# Economics and Ledger

ALL NUMBERS ARE NOMINAL, ILLUSTRATIVE ARITHMETIC, NOT A FORECAST. Zero sales, zero products, zero revenue exist. Rate and share are assumptions to verify at the action date.

## Ledger states
gross Robux (buyer pays) -> platform share removed -> net Robux earned (assumed 70% to creator) -> pending/held (if any) -> Earned Robux balance -> DevEx eligible (threshold) -> DevEx request submitted -> approved -> USD payout initiated -> bank cleared.
Each sale is tracked in `ROBLOX_REVENUE_LEDGER.csv` with its state; nothing counts as revenue before "bank cleared".

## Arithmetic (assumptions: 70% share, $0.0038 per Robux)
99 Robux x 0.70 x $0.0038 = $0.26334 per sale (net).
Illustration: $200 / $0.26334 = 759.5, so about 760 sales of a 99-Robux item (about 760 per day for one day, or spread over any period).
Sweep: `scenarios.py` -> `REVENUE_SCENARIOS.csv` (75 rows; DAU x conversion x price).

## DevEx
Threshold: 30,000 Earned Robux (per brief; verify current requirements, eligibility, and rates in Roblox documentation at the action date).
Reaching it at 99 Robux/sale at 70% = 30,000 / 69.3 = about 433 sales. Illustrative only.

## No-sales downside
If nothing sells: revenue $0. Costs are also $0 by design (no ads, no paid tools). Real cost is owner time. A zero outcome is a plausible, reportable result; the plan must not depend on revenue.

## Rules
No purchases, publishing or outreach without owner approval. All products DISABLED/NOT_CREATED. Cosmetic-only items.
