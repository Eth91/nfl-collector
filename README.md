# nfl-collector

Live data collection for the NFL player-prop / same-game-parlay work.
Analysis and the simulator live separately in `cfl-engine` (branch `q2-canonical`).

⚠️ **Deliberately a fresh repo.** This is not part of `tennis-odds-collector`: that
repo's local history and its `Eth91` remote had diverged by 25,659 / 2,895 commits
with 27 dirty working-tree files from live systems, so pushing NFL work through it
risked the "blocked push silently reverts code" failure class.

⚠️ **Kept out of `~/Desktop/Projects` on purpose.** Desktop is iCloud-synced and a
full disk evicts files to a dataless state that mimics corruption — not something a
live collector should sit on top of.

## Why this exists

The prop simulator LOSES to the closing line on marginals (+0.00383 Brier, z +6.57)
and the whole allocation programme is now closed on both halves — shares and team
volume are each large under *foresight* and small under *forecast*.

But its **joint** distribution is accurate: mean |correlation error| **0.041** over
832 team-games. With the market's marginals held fixed and only the dependence
varied, the sim's copula beats independence at pricing P(both legs over):

| | n | realised | independence | sim copula | dBrier | z |
|---|---|---|---|---|---|---|
| POOLED | 4,052 | 0.2648 | 0.2497 | 0.2769 | **−0.003010** | **−3.17** |
| 2023 | 2,090 | | | | −0.002743 | −2.18 |
| 2024 | 1,962 | | | | −0.003294 | −2.30 |

Negative in **both seasons independently**. Independence mis-prices the joint by
**+6.1%**, and by **+33%** on QB→receiver pairs — mechanically obvious, since a QB's
passing yards and his receivers' yards are the same events counted twice.

⚠️ **That is measured against independence, not against FanDuel.** Real books apply
their own SGP correlation adjustment. +6.1% is an upper bound on the real edge, and
the point of this repo is to replace it with a number.

## `fd_sgp.py`

Captures prop **legs** (market_id, selection_id, line, price, `sgmMarket` eligibility)
and, once the pricing endpoint is known, **SGP prices** — so the book's *implied*
correlation can be backed out and compared to the sim's.

    python3 fd_sgp.py --limit 5     # smoke: 5 soonest events
    python3 fd_sgp.py               # full pull
    python3 fd_sgp.py --status      # what is stored

### The one open item

`price_sgp()` **raises `NotImplementedError` by design.** As of 2026-08-13 the
earliest NFL game is 2026-09-11 and no player props are posted, so there are no legs
to combine and the pricing request cannot be observed. The discovery recipe is in the
module docstring. **Do not guess the endpoint** — `fd_betslip.py` in the other repo
records a guessed share-link param that cost a device test and failed, and a wrong
price here would silently poison the correlation estimate instead of failing loudly.

### ⏰ Time-critical

SGP prices are **live only**. They appear in no historical archive and cannot be
backfilled. Props typically post ~10 days out, so the endpoint has to be discovered
in early September or Week 1 is lost permanently.
