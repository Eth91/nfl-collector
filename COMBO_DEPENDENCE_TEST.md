# WNBA combo test — books UNDER-state dependence, and the tails are the edge

Run 2026-08-13 as a stand-in for the NFL SGP backtest, which is impossible: SGP
prices are computed per-combination at request time and exist in no archive.

WNBA combo markets (`pts_reb`) ARE archived alongside their singles (`points`,
`rebounds`) with full alt-line ladders, so the book's implied dependence can be
backed out of prices alone — the same question the NFL copula result asks.

## Method

`fd_lines`, 3.75M rows, 344 player-events with all three ladders (mean 6.8 points
rungs / 6.3 rebounds / 5.2 combo). For each: build the book's implied marginal
CDF for points and for rebounds, then find the Gaussian-copula ρ whose implied
sum-distribution best fits the book's own combo ladder.

## Result

| | ρ(points, rebounds) |
|---|---|
| **FanDuel implied** | **+0.097** (median +0.064, sd 0.193, n=344, ladder fit RMSE 0.019) |
| **True within-player** | **+0.357** (NBA game logs, 103,943 player-games, 709 players) |

The book prices dependence at roughly **a quarter of reality**. That makes its
combo sum **8.5% too narrow**, so it prices BOTH tails too cheap:

| combo line | book P(over) | true P(over) | book odds → fair |
|---|---|---|---|
| 13.5 | 0.831 | 0.813 | (under is the value) |
| 20.5 (≈median) | 0.470 | 0.473 | 2.13 → 2.11 — nothing |
| 27.5 | 0.133 | **0.153** | **7.49 → 6.55** (~14% overlay) |
| 30.5 | 0.060 | **0.076** | 16.60 → 13.18 |

**The edge is on the rungs away from the median, and it is zero at the median.**

## ⚠️ Caveats, stated plainly

* **The truth reference is NBA, not WNBA.** The mechanism (minutes drives both
  points and rebounds) is identical, but the number could differ. Measuring it on
  WNBA logs is the obvious next step and there are none on this box.
* **Nothing was graded.** This is a pricing comparison, not realised P&L.
* **The book's ρ may be deliberate margin rather than error.** But under-stating
  correlation makes tails CHEAP, and books normally shade tails EXPENSIVE — so an
  error is the more natural reading. Not certain.
* RAW cross-player corr is +0.439 and is NOT the right number — it is contaminated
  by role (bigs rebound, guards score). The within-player deviation correlation
  (+0.357) is what a prop actually prices.

## 🔑 Two estimator traps this test walked into first

1. **`fd_lines` stores DECIMAL odds, not American.** Reading 1.04 as +104 pushed
   every ladder rung to ~0.98 and shifted all distributions right. `fd_collect.py`
   says so in its own docstring: "American -> decimal. Writes fd_lines(...)".
2. **Correlation is NOT identified at the median.** The median of a SUM is very
   nearly the sum of the medians whatever ρ is; ρ moves the VARIANCE, so it is
   identified by the TAILS. Inverting at the rung nearest P=0.5 pinned 339 of 344
   player-events at a bound — a bug in the estimator that looked exactly like a
   dramatic finding about the book. Fitting ρ to the WHOLE ladder fixed it: 344
   usable, 0 pinned.

Both were caught only because the sampler was made to reproduce its own input
ladder first (mean error 0.0023) before anything was inferred from it.

## Why this matters for the NFL SGP program

It is independent evidence for the thesis behind `fd_sgp.py`: **books misprice the
joint, in the direction of under-stating dependence.** The NFL copula result found
independence understates QB→receiver pairs by 33%; this finds a different book, a
different sport and a different market structure under-stating dependence by ~3.7x.
Same direction, same exploitable shape.
