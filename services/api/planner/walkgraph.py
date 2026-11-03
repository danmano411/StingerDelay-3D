"""Road-network walking paths from web-sim/data.js (display only; never used for timings)."""
from __future__ import annotations

import heapq
import json
import math
from pathlib import Path

DATA = Path(__file__).resolve().parents[3] / "web-sim" / "data.js"
_G: dict = {}
CELL = 100


def _load():
    if _G:
        return _G
    s = DATA.read_text(encoding="utf-8").strip()
    twin = json.loads(s[s.index("{"):].rstrip(";"))
    lat0, lon0 = twin["meta"]["origin"]
    adj: dict = {}
    for r in twin["roads"]:
        p = r["p"]
        pts = [(round(p[i]), round(p[i + 1])) for i in range(0, len(p) - 1, 2)]
        for a, b in zip(pts, pts[1:]):
            if a != b:
                adj.setdefault(a, set()).add(b)
                adj.setdefault(b, set()).add(a)
    grid: dict = {}
    for n in adj:
        grid.setdefault((n[0] // CELL, n[1] // CELL), []).append(n)
    _G.update(lat0=lat0, lon0=lon0, kx=111320 * math.cos(math.radians(lat0)), ky=110574, adj=adj, grid=grid)
    return _G


def _nearest(g, x, y):
    cx, cy = int(x // CELL), int(y // CELL)
    for ring in range(1, 40):  # widen until a hit, then one more ring for correctness
        c = [n for i in range(cx - ring, cx + ring + 1) for j in range(cy - ring, cy + ring + 1)
             for n in g["grid"].get((i, j), ())]
        if c:
            return min(c, key=lambda n: (n[0] - x) ** 2 + (n[1] - y) ** 2)
    return None


def _astar(adj, s, t):
    h = lambda n: math.hypot(n[0] - t[0], n[1] - t[1])  # noqa: E731
    best, prev, q = {s: 0.0}, {}, [(h(s), s)]
    while q:
        _, n = heapq.heappop(q)
        if n == t:
            out = [n]
            while n in prev:
                n = prev[n]
                out.append(n)
            return out[::-1]
        for m in adj[n]:
            d = best[n] + math.hypot(m[0] - n[0], m[1] - n[1])
            if d < best.get(m, 1e18):
                best[m], prev[m] = d, n
                heapq.heappush(q, (d + h(m), m))
    return None


def walk_path(lat1, lon1, lat2, lon2):
    line = [[lat1, lon1], [lat2, lon2]]
    try:
        g = _load()
        xy = lambda la, lo: ((lo - g["lon0"]) * g["kx"], (la - g["lat0"]) * g["ky"])  # noqa: E731
        s, t = _nearest(g, *xy(lat1, lon1)), _nearest(g, *xy(lat2, lon2))
        path = _astar(g["adj"], s, t) if s and t else None
        if not path:
            return line
        step = max(1, math.ceil(len(path) / 146))
        path = path[::step] + ([path[-1]] if (len(path) - 1) % step else [])
        mid = [[g["lat0"] + y / g["ky"], g["lon0"] + x / g["kx"]] for x, y in path]
        return [line[0], *mid, line[1]]
    except Exception:
        return line
