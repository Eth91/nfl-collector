# ❌ THE rampId DOES NOT EXIST — this file's original premise was wrong

**Superseded 2026-08-13 by live observation on a real FanDuel SGP slip.**
Kept only so nobody repeats the hunt.

## What the old version claimed

That SGP pricing was `quoteChoices` on `qib.sportsbook.fanduel.com?eventId=<rampId>`,
that every event id returned `EVENT_NOT_FOUND`, and that the last unknown was how
FanDuel's `t.rampId` maps to the sbapi event id.

## What is actually true

**QIB / `quoteChoices` is the WRONG SERVICE.** SGP lives on a different host:

    fcq.nj.sportsbook.fanduel.com        <- "Fixed Combination Quotes"

Confirmed live, two legs in a real slip pricing at $10 -> $10.35:

    GET https://fcq.nj.sportsbook.fanduel.com/api/v0.1/validateMarketsEligibility
        ?marketIds=734.180919113
    GET https://fcq.nj.sportsbook.fanduel.com/api/v0.1/validateMarketsEligibility
        ?marketIds=734.180919113%2C734.180919149     <- both legs, comma-joined

🔑 **IT TAKES A PLAIN COMMA-JOINED `marketIds` LIST AND NO EVENT ID AT ALL.**
That is why `quoteChoices?eventId=` could never work and why the rampId was
unfindable: fcq addresses legs by MARKET ID, so no event identity is ever needed.
There was nothing to map.

## Also ruled out on the same observation

* `smp.nj.sportsbook.fanduel.com/api/sports/fixedodds/readonly/v1/getMarketPrices`
  (38 of 79 page requests, called 10x) is a RED HERRING — body is just
  `{"marketIds":[...]}`, a per-market price refresher with no combination logic.
* `performance.getEntriesByType('resource')` shows the fcq + smp calls, so the
  recipe in the old file worked; it was looking for the wrong endpoint name.

## ID FORMAT — the collector already speaks it

    collector sgp_legs:  market_id 736.180695020   selection_id 92797968
    fcq in the wild:               734.180919113

Same `NNN.NNNNNNNNN` shape. The `736.` vs `734.` prefix is a MARKET-TYPE namespace
(different market types), not a host/region difference — 0 of 33,367 stored rows
carry `734.` because the collector has not captured those market types. So
`price_sgp()` can pass stored market_ids straight through: no translation needed.

## ⚠️ THE ONE REMAINING UNKNOWN

**Which fcq endpoint returns the COMBINED PRICE.** `validateMarketsEligibility` only
answers "can these legs be combined". A broad fetch/XHR capture (all non-static
requests) did NOT catch a pricing call, which leaves two candidates:

1. another `fcq` path (try `/api/v0.1/` + calculate / quote / combine / price), or
2. **the WebSocket** — the page CSP lists `wss://*.sportsbook.fanduel.com`, and a
   live-updating parlay price is exactly what a book streams. A script hook CANNOT
   catch this after the fact: the socket opens on page load, before any hook exists.

## HOW TO FINISH IT (no scripting)

DevTools -> **Network** -> filter **WS** -> click the connection -> **Messages**,
then remove and re-add a leg. Look for a frame containing a `734.` market id.
If the price is streamed, that frame shows the request shape. If nothing appears on
WS, re-filter Network to **Fetch/XHR**, clear it, toggle a leg, and read whatever
fires — the list will be short.

⚠️ `placeBet`, `placeChoiceBet`, `cashoutBet`, `voidBetToken` share the sportsbook
API surface. Everything above is read-only; never click Place Bet.

---

# PROBE RESULTS 2026-08-13 (no browser, plain script, no login)

✅ **fcq is reachable from the collector and OUR OWN STORED IDS WORK.**

    GET https://fcq.nj.sportsbook.fanduel.com/api/v0.1/validateMarketsEligibility
        ?marketIds=736.180695014,736.180695020
    -> 200 {"736.180695014":{"hasCashout":false,...},"736.180695020":{...}}

Those are `sgp_legs.market_id` values straight out of fd_sgp.sqlite. No auth, no
event id, no translation. That settles the addressing question for good.

❌ **The combined price is NOT on fcq under any guessed name.** All 404 with
`{"faultcode":"Client","faultstring":"DSC-0021"}`:

    getCombinedPrices calculate quote combine price combinations marketCombinations
    getPrices combinedPrice getSGMPrice sgm calculateSGM sgmPrice getSgmOdds
    sgmQuote eligibility getMarketCombinations        (also /api/v1/sgm)

POST to /api/v0.1/{calculate,quote,price,sgm,combine} with bodies
{marketIds:[...]}, {selectionIds:[...]}, {legs:[{marketId,selectionId}]} -> all
404/405. Note FanDuel's internal name is **SGM** (Same Game Multi) per the
`sgmMarket` flag the collector already stores as `sgm_eligible` — SGM-based names
were tried and none exist either.

## WHERE IT MUST BE — 2 candidates, both need ONE browser observation

Hosts seen on a live SGP page, with request counts, that were never probed:

    smp.nj.sportsbook.fanduel.com   38   getMarketPrices = per-market refresher (ruled out)
    api.sportsbook.fanduel.com      17   sbapi event-page (known)
    fdx-api.sportsbook.fanduel.com   6   ** NEVER PROBED **
    scan.nj.sportsbook.fanduel.com   5   ** NEVER PROBED **
    sib.nj.sportsbook.fanduel.com    3   ** NEVER PROBED ** (bet slip service?)
    boapi.sportsbook.fanduel.com     2   ** NEVER PROBED **
    fcq.nj.sportsbook.fanduel.com    3   eligibility only

1. one of fdx-api / scan / sib / boapi, or
2. the **WebSocket** (CSP lists `wss://*.sportsbook.fanduel.com`; a live-updating
   parlay price is exactly what a book streams, and a JS hook cannot catch a socket
   opened at page load).

## THE 60-SECOND FINISH

DevTools -> Network -> **Fetch/XHR** -> clear -> remove and re-add one betslip leg.
Under ten requests will list. The one carrying both `734.`/`736.` ids IS the pricing
call — read its host and path. If none appears, switch the filter to **WS**, reload,
click the connection, open **Messages**, toggle a leg, and find the frame with the
market ids.

Then `price_sgp()` is a direct port: same session, same headers, ids passed through.
