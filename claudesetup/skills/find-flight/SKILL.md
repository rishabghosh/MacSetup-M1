---
name: find-flight
description: Find and rank the best flight deal for a trip, weighing fare against duration, departure/landing time windows, stops, and checked-baggage allowance. Use when the user asks to find flights, compare fares, pick the best flight, or search a route and date ("cheapest BLR to DEL on the 15th", "flight to Mumbai landing before 6pm", "best deal with 20kg check-in"). Tuned for Indian domestic routes.
---

# Find the best flight deal

Search flights via the `kiwi-flights` MCP server (Kiwi.com's own hosted server at
`https://mcp.kiwi.com`, no API key, no account), then rank the results against the
user's actual constraints instead of just price.

> `fli-flights` is still registered but **dead** — Google soft-blocks it, returning
> HTTP 200 with an empty payload for every query. Don't reach for it.

## 1. Pin down the constraints

Before searching, make sure you have: **route**, **date**, and whichever of these the
user mentioned. Don't interrogate — assume sensible defaults and say what you assumed.

`kiwi-flights` exposes one tool, `search-flight`, with 47 parameters. The ones that
matter here — note **dates are dd/mm/yyyy**, not ISO:

| Constraint | Where it goes |
|---|---|
| Origin / destination | `flyFrom`, `flyTo` (IATA, city or airport name) |
| Date | `departureDate` — `dd/mm/yyyy` |
| "any of Sat/Sun/Mon" | `departureDate` + `departureDateTo` range, plus `fly_days: "6,0,1"` (0=Sun..6=Sat) |
| "leave after 6am" | `dtime_from: 6` |
| "land before 11am" | `atime_from: 4`, `atime_to: 11` — **both**, see the trap below |
| "under 5 hours" | `max_fly_duration: 5` (hours, not minutes) |
| "non-stop only" | `max_sector_stopovers: 0` |
| "prefer IndiGo" | `select_airlines: "6E"` — but only as a separate probe, not the main search |
| Currency | `currency: "INR"` |

**Always pass `max_sector_stopovers: 0` on a route with abundant nonstops.** Kiwi's
default ordering will otherwise float a 6h17m two-stop itinerary above a 2h40m nonstop
because it is a few hundred rupees cheaper.

**The `atime_to` trap:** these are hour-of-day filters, not "arrives before". `atime_to: 11`
alone happily matches a red-eye landing at 01:00. Pair it with `atime_from` to pin an
actual morning, and let `rank.py --land-by` do the precise cut.

## 2. Search

Results cap at ~15 curated itineraries — that is Kiwi's selection, not the whole market.
When the user needs breadth, run two or three narrower searches (per-day, or with
`select_airlines`) rather than one broad one, and say the result set is capped.

The MCP tools only load at session start. If `mcp__kiwi-flights__search-flight` isn't
available, drive the endpoint over plain HTTP instead — it is unauthenticated:

```bash
python3 ~/.claude/skills/find-flight/kiwi.py query.json
```

Convert the response into the shape `rank.py` reads with
`python3 ~/.claude/skills/find-flight/kiwi2fli.py raw.json ranked-input.json`.

## 3. Rank

Pipe the tool's JSON through the ranking script:

```bash
python3 ~/.claude/skills/find-flight/rank.py --file results.json \
  --need-kg 20 --land-by 18:00 --depart-after 06:00 --max-duration 300
```

Hard filters (`--land-by`, `--depart-after`, `--depart-before`, `--max-duration`,
`--max-stops`) drop candidates. Everything surviving is scored on four normalised
axes — effective cost 0.45, duration 0.25, stops 0.15, arrival-time fit 0.15 —
overridable with `--w-cost`, `--w-duration`, `--w-stops`, `--w-arrival`. Lower is
better. Scores are relative to the shortlist, so don't compare them across searches.

`--prefer-arrival 17:00` adds a soft pull toward a landing time without excluding
anything; `--land-by` is the hard version.

## 4. The baggage join

**Ignore Kiwi's `baggage.checkedBag`.** It is a piece *count*, never a weight, and it is
measurably wrong on Indian carriers: verified Aug 2026, Kiwi returns `checkedBag: 0`
for every Air India Express and Air India domestic itinerary even though both include
free checked baggage. Ranking on it silently pushes 6E above IX for a bogus reason.

Use `baggage.json` instead. `rank.py` joins the operating carrier against it
(IndiGo/Akasa/SpiceJet/Air India Express 15 kg, Air India 25 kg on domestic economy)
and converts any shortfall against `--need-kg` into rupees of prepaid excess. That
produces an **effective cost** — fare plus the top-up you'd actually pay.

This matters: a ₹4,800 IndiGo fare needing 5 kg of excess (₹2,500) loses to a ₹6,500
Air India fare that includes 25 kg.

Why no API gives you kilograms: baggage allowance is a filed ATPCO Optional Services /
IATA Resolution 302 record riding alongside the fare, and every metasearch and
consumer-facing layer strips it. Only GDS/NDC/consolidator feeds (TBO, Tripjack,
Travelfusion) carry it, and all of those are KYC-gated behind a travel-agency licence.
A static table is not a workaround here — for Indian domestic it is the better answer,
because the allowances are published, near-constant, and exact.

Two things to be honest about when reporting:

- The allowances in `baggage.json` are standard-fare figures verified Aug 2026. They
  are a lookup, not live data — tell the user to confirm on the airline's page before
  booking, especially for a promo fare.
- The join uses the **first leg's** carrier. On a codeshare or a mixed-carrier
  connection the allowance may differ per leg; flag it rather than assuming.

Use `--drop-insufficient-bags` when the user would rather not see fares that can't
carry their bags at all.

## 5. Report

Lead with the recommendation and the one-line reason it wins, then the ranked table.
Name the tradeoff the runner-up represents (cheaper but lands at 23:40, faster but
₹2,000 more). Include the fare, the effective cost, and what the difference is.

Never present these as bookable prices — they move, and Kiwi's displayed fare is
pre-checkout-fee.

**Search here, book elsewhere.** Kiwi's `bookingUrl` makes Kiwi the merchant of record:
on a domestic Indian hop that means no GST invoice, a foreign merchant on an INR card,
Kiwi's service fees at checkout, and an airport counter where IndiGo cannot help you
with a Kiwi PNR. Send the user to the airline's own site to verify and book.

Reachability for that hand-off, measured Aug 2026: `akasaair.com`, `spicejet.com` and
`cleartrip.com` return 200 to a plain client; `goindigo.in` and `airindiaexpress.com`
refuse the connection entirely. For those two, the user books in the app or you drive
it with `claude-in-chrome`.
