# The last unknown: what `eventId` does quoteChoices actually want?

Everything else about the SGP pricing endpoint is **found and verified**:

    GET https://qib.sportsbook.fanduel.com
        /api/sports/fixedodds/transactional/v1/quoteChoices
        ?hwm=<highWaterMark>&choices=<comma-joined>&eventId=<rampId>&_ak=<key>

    withCredentials: false   -> NO LOGIN NEEDED
    requiresApplicationKey   -> the _ak fd_sgp.py already uses
    Verified live: HTTP 200, well-formed JSON, from a plain curl.

The **only** blocker: FanDuel's own JS feeds that param from `t.rampId`, and the
sbapi's event id is not it. Every call returns `EVENT_NOT_FOUND` — an EVENT-level
failure, identical across all three choice encodings (`mkt-sel`, `mkt.sel`,
`sel`), both QIB hosts and four region spellings. So the choice format is fine;
the event identity is wrong.

## Already ruled out (do not redo)

* sbapi `event-page` payload contains **zero** occurrences of "ramp"; its event
  object exposes only competitionId, countryCode, eventId, eventTypeId, inPlay,
  key, name, openDate, primaryMarketId, timezone, videoAvailable.
* `/api/v1/event-selections`, `/api/v1/selections`, `/api/v1/related-selections`
  on `api.sportsbook.fanduel.com` -> **404** (they live behind some other prefix).
* `/api/event-selections` on the sbapi host -> `{"error":true}`.

## 30-second recipe — paste into the browser console

Open any live NFL game on sportsbook.fanduel.com that has player props, put **two
prop legs in the bet slip** (this stakes NOTHING — do not click Place Bet), then
paste this into DevTools console:

```js
performance.getEntriesByType('resource')
  .map(e => e.name)
  .filter(u => /quoteChoices|combineChoices/.test(u))
  .forEach(u => console.log(decodeURIComponent(u)));
```

Resource timing survives reloads, which a fetch hook does not — this is the same
technique that found the PFF weekly API.

Read the `eventId=` value off the logged URL and compare it to the sbapi event id
for that same game (fd_sgp.py stores it as `sgp_legs.event_id`). Two outcomes:

* **the two match** -> the blocker was the region/`hwm` binding after all, and the
  logged URL shows the correct spelling; copy its full param set verbatim.
* **they differ** -> that value IS the rampId. Note how it relates to the sbapi id
  (offset? different namespace? present in some other payload field?) and put the
  mapping in `price_sgp()`.

Then implement `price_sgp()` and the collector is complete.

⚠️ `placeBet`, `placeChoiceBet`, `cashoutBet`, `voidBetToken` share this path
prefix. `quoteChoices` is a read-only quote and stakes nothing; a typo into a
sibling is a real bet.
