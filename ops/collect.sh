#!/bin/bash
# NFL SGP leg collector — every 30 min via cron (installed 2026-08-13).
# Captures FanDuel prop LEGS (market_id, selection_id, line, price, sgmMarket)
# for events within 96h of kickoff. SGP PRICES are not yet captured: the pricing
# endpoint is undiscovered (see fd_sgp.py docstring) — legs are the prerequisite
# either way and are LIVE-ONLY data that cannot be backfilled.
#
# ⚠️ Cadence matters. 30 min gives the line-movement resolution CLV work needs and
# matches the sibling fbe-market-poller. Pacing is 0.5s between requests.
cd "$HOME/nfl-collector" || exit 1
PY=/Library/Frameworks/Python.framework/Versions/3.11/bin/python3
[ -x "$PY" ] || PY=$(command -v python3)
LOG="$HOME/nfl-collector/collect.log"
# keep the log from growing without bound (it is append-only across a whole season)
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 5000000 ]; then
  tail -c 1000000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
echo "=== run $(date -u +%FT%TZ) ===" >> "$LOG"
"$PY" fd_sgp.py --hours 96 --pace 0.5 >> "$LOG" 2>&1
