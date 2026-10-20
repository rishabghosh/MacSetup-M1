#!/usr/bin/env python3
"""Adapt Kiwi MCP search-flight output into the fli schema rank.py consumes."""
import json, sys

def conv(path):
    d = json.load(open(path))
    its = d["result"]["structuredContent"]["itineraries"]
    out = []
    for it in its:
        ob = it["outbound"]
        legs = []
        for s in ob["segments"]:
            legs.append({
                "departure_airport": {"code": s["from"], "name": s.get("fromName", s["from"])},
                "arrival_airport": {"code": s["to"], "name": s.get("toName", s["to"])},
                "departure_time": s["departureTime"],
                "arrival_time": s["arrivalTime"],
                "duration": s["durationSeconds"] // 60,
                "airline": {"code": s["carrier"], "name": s.get("carrierName", s["carrier"])},
                "flight_number": s["flightNumber"].replace(s["carrier"], "", 1),
                "aircraft": "", "legroom": "",
            })
        layovers = []
        for a, b in zip(ob["segments"], ob["segments"][1:]):
            from datetime import datetime
            gap = (datetime.fromisoformat(b["departureTime"]) -
                   datetime.fromisoformat(a["arrivalTime"])).total_seconds() // 60
            layovers.append({"airport": {"code": a["to"], "name": a["to"]}, "duration": int(gap)})
        out.append({
            "duration": it["totalDurationSeconds"] // 60,
            "stops": ob["stops"],
            "price": it["price"],
            "currency": it["priceFormatted"].split()[-1],
            "layovers": layovers,
            "legs": legs,
            # Kiwi-only extras, carried through for reporting
            "_checked_bag": it["baggage"]["checkedBag"],
            "_cabin_bag": it["baggage"]["cabinBag"],
            "_booking_url": it["bookingUrl"],
        })
    return {"success": True, "data_source": "kiwi.com", "search_type": "flights",
            "trip_type": "ONE_WAY",
            "query": {"origin": its[0]["outbound"]["from"], "destination": its[0]["outbound"]["to"],
                      "departure_date": "08-10 Aug 2026"},
            "count": len(out), "flights": out}

if __name__ == "__main__":
    json.dump(conv(sys.argv[1]), open(sys.argv[2], "w"), indent=1)
    print("converted", sys.argv[1], "->", sys.argv[2])
