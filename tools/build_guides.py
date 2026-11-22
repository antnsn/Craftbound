#!/usr/bin/env python3
"""Build Guides.lua from tools/data/profession-guides.json.

    python3 tools/build_guides.py            # from the Craftbound folder

The JSON is the planner export the two v1 guides come from. Item IDs are not in it: ITEM_IDS
below maps material and tool names to item IDs (Classic IDs, which Forever kept). A name without
an ID is still shopped for: the addon finds it by name in the auction house and remembers the ID.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "data", "profession-guides.json")
OUT = os.path.join(HERE, "..", "Guides.lua")

ITEM_IDS = {
    # Enchanting
    "Strange Dust": 10940, "Soul Dust": 11083, "Vision Dust": 11137, "Dream Dust": 11176,
    "Lesser Magic Essence": 10938, "Greater Magic Essence": 10939,
    "Lesser Astral Essence": 10998, "Greater Astral Essence": 11082,
    "Lesser Mystic Essence": 11134, "Greater Mystic Essence": 11135,
    "Lesser Nether Essence": 11174, "Greater Nether Essence": 11175,
    "Small Glimmering Shard": 10978, "Large Glimmering Shard": 11084,
    "Small Radiant Shard": 11177, "Large Radiant Shard": 11178,
    "Copper Rod": 6217, "Silver Rod": 6338, "Golden Rod": 11128, "Truesilver Rod": 11144,
    "Runed Copper Rod": 6218, "Runed Silver Rod": 6339, "Runed Golden Rod": 11130,
    "Runed Truesilver Rod": 11145,
    "Shadowgem": 1210, "Iridescent Pearl": 5500, "Black Pearl": 7971, "Wildvine": 8153,
    # Alchemy
    "Peacebloom": 2447, "Silverleaf": 765, "Earthroot": 2449, "Mageroyal": 785,
    "Briarthorn": 2450, "Swiftthistle": 2452, "Bruiseweed": 2453, "Wild Steelbloom": 3355,
    "Kingsblood": 3356, "Stranglekelp": 3820, "Goldthorn": 3821, "Fadeleaf": 3818,
    "Arthas' Tears": 8836, "Plaguebloom": 13466, "Ghost Mushroom": 8845, "Gromsblood": 8846,
    "Empty Vial": 3371, "Leaded Vial": 3372, "Crystal Vial": 8925,
    "Sharp Claw": 5635, "Murloc Eye": 730,
}

# Notes from the source guide that the JSON keeps elsewhere (or not at all).
EXTRA_NOTES = {
    ("Alchemy", "Major Discolored Healing Potion"):
        "The source's shopping list has Ghost Mushroom and Gromsblood here instead. "
        "Open the recipe once: Craftbound then uses its real reagents.",
}

RANK_CAP = {"Apprentice": 75, "Journeyman": 150, "Expert": 225, "Artisan": 300}


def lua(v, ind=""):
    if v is None:
        return "nil"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(lua(x) for x in v) + " }"
        return "{\n" + "".join(ind + "\t" + lua(x, ind + "\t") + ",\n" for x in v) + ind + "}"
    if isinstance(v, dict):
        parts = [k + " = " + lua(x, ind) for k, x in v.items() if x is not None]
        return "{ " + ", ".join(parts) + " }"
    raise TypeError(type(v))


def mats(m):
    out = []
    for name, qty in (m or {}).items():
        out.append({"name": name, "id": ITEM_IDS.get(name), "qty": qty})
    return out


def source(s):
    if not s:
        return None
    return {
        "kind": s.get("type"), "cost": s.get("cost_raw"), "npc": s.get("npc"),
        "location": s.get("location"), "limited": bool(s.get("limited_stock")) or None,
    }


def colors(t):
    if not t:
        return None
    return [t["orange"], t["yellow"], t["green"], t["gray"]]


def step(prof, s):
    t = s["type"]
    if t == "train_rank":
        return {"kind": "train", "rank": s["rank"], "reqSkill": s["requires_skill"],
                "reqLevel": s.get("requires_character_level"), "before": s["train_before_skill"],
                "cap": RANK_CAP.get(s["rank"])}
    if t == "disenchant":
        return {"kind": "disenchant", "from": s["skill_from"], "to": s["skill_to"],
                "note": s.get("instructions")}
    crafts = s.get("crafts") or {}
    out = {
        "kind": "tool" if t == "craft_tool" else "craft",
        "from": s.get("skill_from"), "to": s.get("skill_to"),
        "recipe": s["recipe"], "colors": colors(s.get("skill_thresholds")),
        "expected": crafts.get("expected"), "safe": crafts.get("safe"),
        "makes": s.get("output_quantity"),
        "tool": s.get("required_tool"),
        "mats": mats(s.get("materials_per_craft")),
        "source": source(s.get("source")),
        "alts": s.get("alternatives") or None,
    }
    if t == "craft_tool":
        out["item"] = ITEM_IDS.get(s["recipe"])
        out["note"] = "Make one and keep it in your bags."
    src = s.get("source") or {}
    if src.get("limited_stock"):
        out["note"] = ("The recipe is sold by %s (%s) in limited stock; it restocks."
                       % (src.get("npc"), src.get("location")))
    extra = EXTRA_NOTES.get((prof, s.get("recipe")))
    if extra:
        out["note"] = extra
        out["check"] = True
    return out


def main():
    data = json.load(open(SRC, encoding="utf-8"))
    lines = [
        "-- Generated by tools/build_guides.py from tools/data/profession-guides.json. Do not edit:",
        "-- change the JSON or the script and run it again.",
        "local _, ns = ...",
        "",
        "ns.Guides = {",
    ]
    for g in data["guides"]:
        key = g["profession"] + ":" + g["guide"]
        est = g.get("source_estimate") or {}
        guide = {
            "key": key, "profession": g["profession"], "name": g["guide"],
            "from": g["skill_from"], "to": g["skill_to"],
            "avgCrafts": est.get("average_crafts"), "p90Crafts": est.get("p90_crafts"),
            "playtested": est.get("playtested_in_forever"),
        }
        head = ", ".join(k + " = " + lua(v) for k, v in guide.items() if v is not None)
        lines.append("\t{ " + head + ",")
        lines.append("\t\tsteps = {")
        for s in g["steps"]:
            lines.append("\t\t\t" + lua(step(g["profession"], s), "\t\t\t") + ",")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    missing = sorted({m for g in data["guides"] for s in g["steps"]
                      for m in (s.get("materials_per_craft") or {}) if m not in ITEM_IDS})
    print("wrote", os.path.normpath(OUT))
    if missing:
        print("no item ID (found by name in the auction house):", ", ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
