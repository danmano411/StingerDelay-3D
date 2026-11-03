"""Per-conversation accumulated constraints (in memory)."""
CONVS: dict[str, dict] = {}


def get(cid: str) -> dict:
    return CONVS.setdefault(cid, {"dest": None, "origin": None, "arrive_by": None,
                                  "avoid_stairs": False, "trace": None})
