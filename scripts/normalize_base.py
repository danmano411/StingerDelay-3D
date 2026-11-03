#!/usr/bin/env python3
"""Normalize data/base/routes.json into compact routes/stops/places JSON."""

from __future__ import annotations

import json
import math
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "data" / "base" / "routes.json"
OUT = ROOT / "data" / "normalized"

# ~8 m at Atlanta latitude; keep first/last vertices.
DOWNSAMPLE_EPSILON_DEG = 0.00007

# Place label -> preferred stop-name needles (first match wins; exact preferred).
PLACE_SEEDS = [
    ("Klaus", ["klaus building wb", "klaus building", "klaus"]),
    ("Kendeda", ["kendeda building", "kendeda"]),
    ("Student Center", ["student center"]),
    ("MARTA Midtown", ["marta midtown station", "marta midtown", "marta"]),
    ("West Village", ["west village"]),
    ("Clough", ["clough commons", "clough"]),
    ("CRC", ["crc & stamps health", "crc"]),
]


def _clean_name(name: str) -> str:
    return re.sub(r"\s+", " ", name.replace("\xa0", " ")).strip()


def _perp_dist(p, a, b) -> float:
    """Perpendicular distance from point p to segment a-b (degrees, Euclidean)."""
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    if dx == 0 and dy == 0:
        return math.hypot(px - ax, py - ay)
    t = ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)
    t = max(0.0, min(1.0, t))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def douglas_peucker(points: list[list[float]], epsilon: float) -> list[list[float]]:
    if len(points) < 3:
        return [list(p) for p in points]
    stack = [(0, len(points) - 1)]
    keep = {0, len(points) - 1}
    while stack:
        i, j = stack.pop()
        a, b = points[i], points[j]
        max_d, max_k = 0.0, None
        for k in range(i + 1, j):
            d = _perp_dist(points[k], a, b)
            if d > max_d:
                max_d, max_k = d, k
        if max_k is not None and max_d > epsilon:
            keep.add(max_k)
            stack.append((i, max_k))
            stack.append((max_k, j))
    return [list(points[i]) for i in sorted(keep)]


def _dedupe_consecutive(points: list[list[float]]) -> list[list[float]]:
    out: list[list[float]] = []
    for p in points:
        if not out or p[0] != out[-1][0] or p[1] != out[-1][1]:
            out.append(list(p))
    return out


def _slug(label: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", label.lower()).strip("-")


def _pick_stop(stops_by_id: dict, needles: list[str]) -> dict | None:
    """Prefer exact (casefold) name match on first needle; else substring."""
    items = list(stops_by_id.values())
    for needle in needles:
        exact = [s for s in items if s["name"].casefold() == needle]
        if exact:
            return exact[0]
    for needle in needles:
        hits = [s for s in items if needle in s["name"].casefold()]
        if not hits:
            continue
        # Prefer shorter names (exact-ish) then lower id for stability.
        hits.sort(key=lambda s: (len(s["name"]), s["id"]))
        return hits[0]
    return None


def normalize() -> dict:
    raw = json.loads(BASE.read_text(encoding="utf-8"))
    if not isinstance(raw, list):
        raise SystemExit(f"expected list of routes in {BASE}")

    stops_by_id: dict[int, dict] = {}
    routes_out: list[dict] = []
    line_stats: list[tuple[str, int, int]] = []

    for route in raw:
        rid = int(route["id"])
        name = str(route["name"])
        color = str(route.get("color", "#888888"))
        synthetic = rid == 21 or name.casefold() == "blue"

        line_raw = _dedupe_consecutive(route.get("line") or [])
        line = douglas_peucker(line_raw, DOWNSAMPLE_EPSILON_DEG)
        line_stats.append((name, len(line_raw), len(line)))

        stop_refs: list[dict] = []
        for stop in route.get("stops") or []:
            sid = int(stop["id"])
            cleaned = _clean_name(str(stop["name"]))
            if sid not in stops_by_id:
                stops_by_id[sid] = {
                    "id": sid,
                    "name": cleaned,
                    "lat": float(stop["lat"]),
                    "lon": float(stop["lon"]),
                    "route_ids": [],
                }
            entry = stops_by_id[sid]
            if rid not in entry["route_ids"]:
                entry["route_ids"].append(rid)
            stop_refs.append(
                {
                    "id": sid,
                    "dwell": int(stop.get("dwell") or 0),
                    "to_next": int(stop.get("to_next") or 0),
                }
            )

        routes_out.append(
            {
                "id": rid,
                "name": name,
                "color": color,
                "synthetic": synthetic,
                "line": line,
                "stops": stop_refs,
            }
        )

    stops_out = sorted(stops_by_id.values(), key=lambda s: s["id"])
    for s in stops_out:
        s["route_ids"].sort()

    places_out: list[dict] = []
    for label, needles in PLACE_SEEDS:
        hit = _pick_stop(stops_by_id, needles)
        if hit is None:
            raise SystemExit(f"place seed unmatched: {label!r} needles={needles}")
        places_out.append(
            {
                "id": _slug(label),
                "name": label,
                "lat": hit["lat"],
                "lon": hit["lon"],
                "stop_id": hit["id"],
                "stop_name": hit["name"],
            }
        )

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "routes.json").write_text(
        json.dumps(routes_out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (OUT / "stops.json").write_text(
        json.dumps(stops_out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (OUT / "places.json").write_text(
        json.dumps(places_out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )

    blue = next(r for r in routes_out if r["synthetic"])
    return {
        "n_routes": len(routes_out),
        "n_stops": len(stops_out),
        "n_places": len(places_out),
        "blue_id": blue["id"],
        "blue_name": blue["name"],
        "blue_synthetic": blue["synthetic"],
        "line_stats": line_stats,
        "place_rows": places_out,
    }


def main() -> None:
    stats = normalize()
    print(f"routes={stats['n_routes']} stops={stats['n_stops']} places={stats['n_places']}")
    print(f"blue id={stats['blue_id']} name={stats['blue_name']} synthetic={stats['blue_synthetic']}")
    for name, before, after in stats["line_stats"]:
        print(f"  polyline {name}: {before} -> {after}")
    for p in stats["place_rows"]:
        print(f"  place {p['name']}: stop_id={p['stop_id']} ({p['stop_name']})")


if __name__ == "__main__":
    main()
