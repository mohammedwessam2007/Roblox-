#!/usr/bin/env python3
"""Generate REVENUE_SCENARIOS.csv. stdlib only.
ALL VALUES ARE NOMINAL, ILLUSTRATIVE ARITHMETIC. NOT A FORECAST. No real data."""
import csv, os
DAU = [500, 5000, 25000, 50000, 100000]
CONV = [0.001, 0.005, 0.01, 0.02, 0.04]
PRICE = [29, 99, 199]
SHARE = 0.70      # assumed creator share (verify)
USD_PER_ROBUX = 0.0038  # assumed DevEx-style rate (verify at action date)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "REVENUE_SCENARIOS.csv")
with open(OUT, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["label", "dau", "payer_conversion", "avg_price_robux", "assumed_share",
                "usd_per_robux", "sales_per_day", "gross_robux_per_day",
                "net_robux_per_day", "usd_per_day", "usd_per_30_days"])
    for d in DAU:
        for c in CONV:
            for p in PRICE:
                sales = d * c
                gross = sales * p
                net = gross * SHARE
                usd = net * USD_PER_ROBUX
                w.writerow(["NOMINAL_ILLUSTRATIVE_NOT_FORECAST", d, f"{c:.3%}", p, SHARE,
                            USD_PER_ROBUX, f"{sales:.2f}", f"{gross:.2f}", f"{net:.2f}",
                            f"{usd:.2f}", f"{usd*30:.2f}"])
print(f"wrote {OUT} rows={len(DAU)*len(CONV)*len(PRICE)}")
