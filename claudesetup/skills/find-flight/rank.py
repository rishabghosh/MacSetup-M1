#!/usr/bin/env python3
"""Rank fli (Google Flights) JSON results against travel constraints.

Reads the JSON emitted by `fli flights ... --format json` (or the MCP
search_flights tool) on stdin or via --file, applies hard filters, then
scores what survives.

Scoring model
-------------
Baggage is the awkward one: fli returns no allowance data, so we join the
operating carrier of the first leg against baggage.json and turn any
shortfall against --need-kg into rupees of prepaid excess. That gives an
"effective cost" which is what actually leaves your wallet, and it makes a
cheap 15 kg IndiGo fare comparable to a pricier 25 kg Air India one.

Everything else is min-max normalised across the surviving candidates and
combined with the weights, so scores are relative to the shortlist, not
absolute. Lower score = better.
"""

import argparse
import json
import sys
from datetime import datetime, time

DEFAULT_WEIGHTS = {"cost": 0.45, "duration": 0.25, "stops": 0.15, "arrival": 0.15}


def parse_hhmm(s):
    h, m = s.split(":")
    return time(int(h), int(m))


def load_baggage(path):
    with open(path) as fh:
        return json.load(fh)


def carrier_of(flight):
    """Marketing carrier for the itinerary - first leg's airline."""
    legs = flight.get("legs") or []
    if not legs:
        return None, None
    a = legs[0].get("airline") or {}
    return a.get("code"), a.get("name")


def baggage_for(code, bag):
    entry = (bag.get("airlines") or {}).get(code or "")
    if not entry:
        d = bag["default_domestic"]
        return d["checked_kg"], None
    return entry["domestic"]["checked_kg"], entry.get("excess_inr_per_kg", {}).get(
        "prepaid_online"
    )


def excess_cost(included_kg, need_kg, rate):
    if need_kg is None or need_kg <= included_kg:
        return 0.0, 0
    shortfall = need_kg - included_kg
    # Airlines sell excess in whole kg; no rate known -> flag rather than guess.
    if rate is None:
        return 0.0, shortfall
    return shortfall * rate, shortfall


def dep_dt(f):
    return datetime.fromisoformat(f["legs"][0]["departure_time"])


def arr_dt(f):
    return datetime.fromisoformat(f["legs"][-1]["arrival_time"])


def normalise(values):
    lo, hi = min(values), max(values)
    if hi == lo:
        return [0.0] * len(values)
    return [(v - lo) / (hi - lo) for v in values]


def build(args):
    raw = json.load(open(args.file)) if args.file else json.load(sys.stdin)
    flights = raw.get("flights") or []
    if not flights:
        print("No flights in input (fli returned 0 results - see SKILL.md on "
              "Google Flights throttling).", file=sys.stderr)
        return [], raw

    bag = load_baggage(args.baggage)
    land_by = parse_hhmm(args.land_by) if args.land_by else None
    depart_after = parse_hhmm(args.depart_after) if args.depart_after else None
    depart_before = parse_hhmm(args.depart_before) if args.depart_before else None

    rows = []
    for f in flights:
        if not f.get("legs"):
            continue
        d, a = dep_dt(f), arr_dt(f)

        if depart_after and d.time() < depart_after:
            continue
        if depart_before and d.time() > depart_before:
            continue
        if land_by and a.time() > land_by and a.date() == d.date():
            continue
        if land_by and a.date() > d.date():
            continue  # overnight arrival can't satisfy a same-day land-by
        if args.max_duration and f["duration"] > args.max_duration:
            continue
        if args.max_stops is not None and f["stops"] > args.max_stops:
            continue

        code, name = carrier_of(f)
        included, rate = baggage_for(code, bag)
        bag_cost, shortfall = excess_cost(included, args.need_kg, rate)
        if args.need_kg and shortfall and args.drop_insufficient_bags:
            continue

        rows.append(
            {
                "airline": name or code or "?",
                "code": code,
                "flights": " + ".join(
                    f"{l['airline']['code']}{l['flight_number']}" for l in f["legs"]
                ),
                "dep": d,
                "arr": a,
                "duration": f["duration"],
                "stops": f["stops"],
                "via": ", ".join(l["airport"]["code"] for l in f.get("layovers") or []),
                "fare": f["price"],
                "currency": f.get("currency", "?"),
                "included_kg": included,
                "bag_shortfall": shortfall,
                "bag_cost": bag_cost,
                "effective": f["price"] + bag_cost,
                "rate_unknown": shortfall > 0 and rate is None,
            }
        )

    if not rows:
        return [], raw

    n_cost = normalise([r["effective"] for r in rows])
    n_dur = normalise([r["duration"] for r in rows])
    n_stop = normalise([r["stops"] for r in rows])
    # Arrival preference: distance in minutes from the ideal landing time, if given.
    if args.prefer_arrival:
        ideal = parse_hhmm(args.prefer_arrival)
        gaps = [
            abs((r["arr"].hour * 60 + r["arr"].minute) - (ideal.hour * 60 + ideal.minute))
            for r in rows
        ]
    else:
        gaps = [0] * len(rows)
    n_arr = normalise(gaps)

    w = dict(DEFAULT_WEIGHTS)
    for k in w:
        v = getattr(args, f"w_{k}")
        if v is not None:
            w[k] = v
    total_w = sum(w.values()) or 1.0

    for r, c, du, st, ar in zip(rows, n_cost, n_dur, n_stop, n_arr):
        r["score"] = (
            w["cost"] * c + w["duration"] * du + w["stops"] * st + w["arrival"] * ar
        ) / total_w

    rows.sort(key=lambda r: r["score"])
    return rows, raw


def render(rows, raw, args):
    q = raw.get("query", {})
    cur = rows[0]["currency"]
    print(
        f"\n**{q.get('origin')} to {q.get('destination')}** on {q.get('departure_date')}"
        f"  -  {len(rows)} of {raw.get('count', 0)} options meet the constraints\n"
    )
    hdr = "| # | Airline | Flight | Depart | Land | Duration | Stops | Fare | Bag top-up | Effective | Score |"
    print(hdr)
    print("|---" * 11 + "|")
    for i, r in enumerate(rows[: args.top], 1):
        h, m = divmod(r["duration"], 60)
        via = f" via {r['via']}" if r["via"] else ""
        bagtxt = "included" if not r["bag_shortfall"] else (
            f"+{r['bag_shortfall']}kg = ?" if r["rate_unknown"]
            else f"+{r['bag_shortfall']}kg = {r['bag_cost']:,.0f}"
        )
        print(
            f"| {i} | {r['airline']} | {r['flights']}{via} | {r['dep']:%H:%M} | "
            f"{r['arr']:%H:%M} | {h}h{m:02d} | {r['stops']} | {r['fare']:,.0f} | "
            f"{bagtxt} | {r['effective']:,.0f} | {r['score']:.3f} |"
        )
    print(f"\nPrices in {cur}. Effective = fare + prepaid excess baggage needed to "
          f"reach {args.need_kg} kg." if args.need_kg else f"\nPrices in {cur}.")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--file", help="fli JSON file (default: stdin)")
    p.add_argument(
        "--baggage",
        default=str(__import__("pathlib").Path(__file__).parent / "baggage.json"),
    )
    p.add_argument("--need-kg", type=int, help="Checked baggage you must carry, in kg")
    p.add_argument("--land-by", help="Latest acceptable arrival, HH:MM")
    p.add_argument("--depart-after", help="Earliest acceptable departure, HH:MM")
    p.add_argument("--depart-before", help="Latest acceptable departure, HH:MM")
    p.add_argument("--prefer-arrival", help="Ideal landing time, HH:MM (soft preference)")
    p.add_argument("--max-duration", type=int, help="Max total trip time, minutes")
    p.add_argument("--max-stops", type=int)
    p.add_argument(
        "--drop-insufficient-bags",
        action="store_true",
        help="Exclude fares that can't reach --need-kg instead of pricing the top-up",
    )
    p.add_argument("--top", type=int, default=10)
    for k, v in DEFAULT_WEIGHTS.items():
        p.add_argument(f"--w-{k}", type=float, default=None, help=f"weight (default {v})")
    args = p.parse_args()

    rows, raw = build(args)
    if not rows:
        print("Nothing matched. Loosen a constraint - land-by and max-duration are "
              "usually the binding ones.", file=sys.stderr)
        sys.exit(1)
    render(rows, raw, args)


if __name__ == "__main__":
    main()
