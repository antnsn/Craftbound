#!/usr/bin/env python3
"""Build Guides.lua from tools/data/profession-guides.json.

    python3 tools/build_guides.py            # from the Craftbound folder

The JSON is the planner export the guides come from. Item IDs are not in it: ITEM_IDS
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
    # Tools, stations' reagents and trade goods (Blacksmithing, Engineering, Leatherworking)
    "Blacksmith Hammer": 5956, "Arclight Spanner": 6219, "Gyromatic Micro-Adjustor": 10498,
    "Copper Bar": 2840, "Bronze Bar": 2841, "Silver Bar": 2842, "Iron Bar": 3575,
    "Gold Bar": 3577, "Steel Bar": 3859, "Mithril Bar": 3860, "Truesilver Bar": 6037,
    "Thorium Bar": 12359, "Arcanite Bar": 12360, "Enchanted Thorium Bar": 12655,
    "Rough Stone": 2835, "Coarse Stone": 2836, "Heavy Stone": 2838, "Solid Stone": 7912,
    "Dense Stone": 12365, "Solid Grinding Stone": 7966, "Dense Grinding Stone": 12644,
    "Weak Flux": 2880, "Strong Flux": 3466, "Elemental Flux": 18567,
    "Gold Power Core": 10558, "Bolt of Linen Cloth": 2996, "Wool Cloth": 2592,
    "Mageweave Cloth": 4338, "Runecloth": 14047, "Ironweb Spider Silk": 14227,
    "Star Ruby": 7910, "Large Opal": 12799, "Righteous Orb": 12811,
    "Essence of Air": 7082, "Essence of Fire": 7078, "Elemental Earth": 7067,
    "Elemental Water": 7070, "Living Essence": 12803, "Powerful Mojo": 12804,
    "Light Leather": 2318, "Medium Leather": 2319, "Heavy Leather": 4234, "Thick Leather": 4304,
    "Rugged Leather": 8170, "Enchanted Leather": 12810, "Light Hide": 783, "Medium Hide": 4232,
    "Heavy Hide": 4235, "Rugged Hide": 8171, "Cured Rugged Hide": 15407,
    "Heavy Scorpid Scale": 15408, "Refined Deeprock Salt": 15409, "Salt": 4289,
    "Coarse Thread": 2320, "Fine Thread": 2321, "Silken Thread": 4291,
    "Heavy Silken Thread": 8343, "Rune Thread": 14341,
    "Green Dye": 2605, "Gray Dye": 4340, "Black Dye": 2325, "Elixir of Minor Agility": 2457,
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


IDS = dict(ITEM_IDS)  # plus each guide's own "item_ids" (imported guides carry them)


def mats(m):
    out = []
    for name, qty in (m or {}).items():
        out.append({"name": name, "id": IDS.get(name), "qty": qty})
    return out


def source(s):
    if not s:
        return None
    vendors = None
    if s.get("vendors"):
        vendors = [{"npc": v["npc"], "location": v.get("location"), "side": v.get("side"),
                    "cost": v.get("cost_raw"), "limited": bool(v.get("limited_stock")) or None}
                   for v in s["vendors"]]
    return {
        "kind": s.get("type"), "cost": s.get("cost_raw"), "npc": s.get("npc"),
        "location": s.get("location"), "limited": bool(s.get("limited_stock")) or None,
        "rep": s.get("requires_reputation"), "vendors": vendors,
    }


def colors(t):
    if not t:
        return None
    return [t["orange"], t["yellow"], t["green"], t["gray"]]


def tools(s):
    t = s.get("required_tools") or ([s["required_tool"]] if s.get("required_tool") else [])
    return t or None


def step(prof, s):
    t = s["type"]
    if t == "buy_tool":
        return {"kind": "tool", "buy": True, "recipe": s["item"], "item": IDS.get(s["item"]),
                "safe": 1, "expected": 1,
                "mats": [{"name": s["item"], "id": IDS.get(s["item"]), "qty": 1}],
                "source": source(s.get("source")), "note": s.get("instructions")}
    if t == "train_rank":
        return {"kind": "train", "rank": s["rank"], "reqSkill": s["requires_skill"],
                "reqLevel": s.get("requires_character_level"), "before": s["train_before_skill"],
                "cap": RANK_CAP.get(s["rank"]), "how": s.get("instructions")}
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
        "tools": tools(s), "station": s.get("station"),
        "mats": mats(s.get("materials_per_craft")),
        "source": source(s.get("source")),
        "alts": s.get("alternatives") or None,
    }
    if t == "craft_tool":
        out["item"] = IDS.get(s["recipe"])
        out["note"] = "Make one and keep it in your bags."
    src = s.get("source") or {}
    if src.get("limited_stock"):
        out["note"] = ("The recipe is sold by %s (%s) in limited stock; it restocks."
                       % (src.get("npc"), src.get("location")))
    if src.get("requires_reputation"):
        rep = "Needs %s to learn this recipe." % src["requires_reputation"]
        out["note"] = (out["note"] + " " + rep) if out.get("note") else rep
    if s.get("instructions") and t == "craft":
        out["note"] = (out["note"] + " " + s["instructions"]) if out.get("note") else s["instructions"]
    if s.get("low_odds"):
        out["note"] = (out["note"] + " " + s["low_odds"]) if out.get("note") else s["low_odds"]
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
    vendor_items = set()
    for g in data["guides"]:
        IDS.clear()
        IDS.update(ITEM_IDS)
        IDS.update(g.get("item_ids") or {})
        vendor_items.update(g.get("vendor_items") or [])
        key = g["profession"] + ":" + g["guide"]
        est = g.get("source_estimate") or {}
        guide = {
            "key": key, "profession": g["profession"], "name": g["guide"],
            "from": g["skill_from"], "to": g["skill_to"],
            "avgCrafts": est.get("average_crafts"), "p90Crafts": est.get("p90_crafts"),
            "playtested": est.get("playtested_in_forever"),
            "note": g.get("starts_note"),
        }
        head = ", ".join(k + " = " + lua(v) for k, v in guide.items() if v is not None)
        lines.append("\t{ " + head + ",")
        if g.get("parts"):
            lines.append("\t\tparts = {")
            for name, p in g["parts"].items():
                part = {"recipe": p["recipe"], "id": IDS.get(name), "makes": p.get("makes", 1),
                        "mats": mats(p["materials_per_craft"])}
                lines.append("\t\t\t[" + lua(name) + "] = " + lua(part) + ",")
            lines.append("\t\t},")
        lines.append("\t\tsteps = {")
        for s in g["steps"]:
            lines.append("\t\t\t" + lua(step(g["profession"], s), "\t\t\t") + ",")
        lines.append("\t\t},")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    lines.append("-- Reagents sold by vendors, from the imported catalogs: never bought at the auction house.")
    lines.append("ns.GuideVendorItems = { " + ", ".join("[%d] = true" % i for i in sorted(vendor_items)) + " }")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    known = lambda g, m: m in ITEM_IDS or m in (g.get("item_ids") or {})
    missing = sorted({m for g in data["guides"] for s in g["steps"]
                      for m in (s.get("materials_per_craft") or {}) if not known(g, m)}
                     | {m for g in data["guides"] for p in (g.get("parts") or {}).values()
                        for m in p["materials_per_craft"] if not known(g, m)})
    print("wrote", os.path.normpath(OUT))
    if missing:
        print("no item ID (found by name in the auction house):", ", ".join(missing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
