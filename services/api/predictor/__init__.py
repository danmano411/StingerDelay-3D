"""Delay spread from ETA-bucket lookup (eta_decile_summary_v0)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
_L = json.loads((ROOT / "data/normalized/delay_lookup.json").read_text())
MODEL_ID = _L["model_id"]


def mae_for_eta(eta_s: float) -> float:
    eta_s = max(0.0, eta_s)
    for b in _L["buckets"]:
        if eta_s < b["max_eta_s"]:
            return float(b["mae_s"])
    last = _L["buckets"][-1]
    return last["mae_s"] + _L["beyond"]["slope_s_per_s"] * (eta_s - last["max_eta_s"])


def quantiles(route_id, eta_s, horizon_s=0.0, social_factor=None):
    """p10/p50/p90 of arrival offset (s). Social factor widens spread only."""
    sd = mae_for_eta(eta_s) * 1.25 * (1 + horizon_s / 3600.0)
    if social_factor is not None:
        sd *= getattr(social_factor, "spread_multiplier", 1.0)
    return {"p10": eta_s - 1.2816 * sd, "p50": float(eta_s), "p90": eta_s + 1.2816 * sd}
