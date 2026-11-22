#!/usr/bin/env python3
"""Turn Wowhead's Forever "Tried & Tested" routes into guides in profession-guides.json.

    python3 tools/import_wowhead.py tailoring cooking firstaid   # from the Craftbound folder
    python3 tools/build_guides.py

Input, per profession, in tools/data/ (fetched by hand, not committed: Wowhead's data):
    wh_<name>.json          .../forever/profession-leveling-guides/guides?skill=<id>
    wh_catalog_<name>.json  .../forever/profession-leveling-guides/catalog?skill=<id>

The route gives the steps (skill range and recipe spell ID). The catalog gives the rest:
skill-up colours, reagents with item IDs, what the recipe makes, where it is learned (trainer
cost, vendors with zone and faction, reputation), the station and tools.

Crafts per step use the planner's skill-up model: below yellow every craft gives a point, from
yellow on the chance is (gray - skill) / (gray - yellow). "expected" is the mean rounded down,
"safe" the mean plus 1.28 standard deviations (about the 90th percentile). Checked against the
planner's numbers for the other guides and Wowhead's Tailoring table: 95 of 107 steps exact,
the rest one craft off.
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data")
GUIDES = os.path.join(DATA, "profession-guides.json")

NAMES = {197: "Tailoring", 185: "Cooking", 129: "First Aid", 164: "Blacksmithing"}
SECONDARY = {185, 129}

# Ranks a trainer teaches (primary professions), and how secondary skills get past 150 and 225.
RANKS = [("Journeyman", 50, 10, 75), ("Expert", 125, 20, 150), ("Artisan", 200, 35, 225)]
RANK_HOW = {
    185: {"Expert": "Buy and read the Expert Cookbook to learn Expert.",
          "Artisan": "Artisan Cooking is a quest: Clamlette Surprise (Dirge Quikcleave in Tanaris)."},
    129: {"Expert": "Buy and read Expert First Aid - Under Wraps (Deneb Walker in Arathi Highlands "
                    "or Balai Lok'Wein in Dustwallow Marsh) to learn Expert.",
          "Artisan": "Artisan First Aid is the Triage quest (Doctor Gustaf VanHowzen in Theramore "
                     "or Doctor Gregory Victor in Hammerfall)."},
}
# Secondary skills: the Artisan quest (Clamlette Surprise, Triage) needs skill 225, not 200.
RANK_SKILL = {185: {"Artisan": 225}, 129: {"Artisan": 225}}
SIDE = {"A": "Alliance", "H": "Horde", "N": None}


def crafts(colors, a, b, ups=1):
    _, yellow, _, gray = colors
    mean = var = 0.0
    for s in range(a, b, ups or 1):
        p = 1.0 if s < yellow else (gray - s) / (gray - yellow)
        if p <= 0:
            raise ValueError("step %d-%d runs past gray (%d)" % (a, b, gray))
        mean += 1 / p
        var += (1 - p) / p ** 2
    expected = max(1, math.floor(mean))
    return expected, max(expected, round(mean + 1.28 * math.sqrt(var)))


def source(r, cat):
    if r["vendor"]:
        vendors = []
        for v in r["vendor"]:
            npc = cat["vendors"].get(str(v["npc"])) or {}
            vendors.append({"npc": npc.get("name", "NPC %d" % v["npc"]), "location": npc.get("zone"),
                            "side": SIDE.get(npc.get("side")), "cost_raw": v.get("price"),
                            "limited_stock": bool(v.get("limited"))})
        first = vendors[0]
        out = {"type": "vendor", "npc": first["npc"], "location": first["location"],
               "cost_raw": first["cost_raw"],
               # one vendor: the step note says limited stock; several: the hint picks per faction
               "limited_stock": (first["limited_stock"] or None) if len(vendors) == 1 else None,
               "vendors": vendors if len(vendors) > 1 or first["side"] else None}
        rep = r.get("reputation")
        if rep:
            out["requires_reputation"] = "%s with %s" % (rep["standing"], rep["faction"])
        return out
    if r["starter"]:
        return {"type": "known"}
    if r["trainer"]:
        return {"type": "trainer", "cost_raw": r["cost"] or None}
    if r["quest"]:
        return {"type": "quest"}
    if r["drop"]:
        return {"type": "drop"}
    return {"type": "trainer"}


def build(name):
    route = json.load(open(os.path.join(DATA, "wh_%s.json" % name), encoding="utf-8"))["guides"][0]
    cat = json.load(open(os.path.join(DATA, "wh_catalog_%s.json" % name), encoding="utf-8"))["catalog"]
    skill = cat["skill"]
    prof = NAMES[skill]
    recipes = {r["id"]: r for r in cat["recipes"]}
    items = cat["items"]
    item_name = lambda i: items[str(i)]["name"]
    makers = {r["creates"][0]: r for r in cat["recipes"] if r.get("creates")}

    ids, vendor_items, parts, steps = {}, [], {}, []
    bought = set()  # tools already given a buy step
    ranks = list(RANKS)
    total_e = total_s = 0
    for st in route["steps"]:
        r = recipes[st["recipe"]]
        a, b = st["from"], st["to"]
        while ranks and b > ranks[0][1]:
            rank, req, lvl, before = ranks.pop(0)
            req = RANK_SKILL.get(skill, {}).get(rank, req)
            if a >= before:
                continue
            t = {"type": "train_rank", "rank": rank, "requires_skill": req,
                 "requires_character_level": lvl, "train_before_skill": before}
            how = RANK_HOW.get(skill, {}).get(rank)
            if how:
                t["instructions"] = how
            steps.append(t)
        # a tool the profession can't make (the Blacksmith Hammer): buy it before the first step
        # that needs it; any of the tool's items will do (Forever has better hammers)
        for t in r.get("tools") or []:
            tool = cat["tools"].get(str(t)) or {}
            first = (tool.get("items") or [None])[0]
            if not first or t in bought or first in makers:
                continue
            bought.add(t)
            info = items.get(str(first)) or {}
            ids[tool["name"]] = first
            steps.append({"type": "buy_tool", "item": tool["name"], "item_ids": tool.get("items"),
                          "source": {"type": "vendor", "npc": "a %s supplies vendor" % prof.lower(),
                                     "cost_raw": info.get("price")},
                          "instructions": "Buy a %s and keep it in your bags (a better one, such as %s, works too)."
                          % (tool["name"], ", ".join(items[str(i)]["name"] for i in tool["items"][1:]
                                                     if str(i) in items)) if len(tool.get("items") or []) > 1
                          else "Buy a %s and keep it in your bags." % tool["name"]})
        e, s = crafts(r["colors"], a, b, r.get("skillUps"))
        total_e, total_s = total_e + e, total_s + s
        mats = {}
        for item, qty in r["reagents"]:
            n = item_name(item)
            mats[n] = qty
            ids[n] = item
            info = items[str(item)]
            if info.get("type") == "vendor" and item not in vendor_items:
                vendor_items.append(item)
            # reagents a vendor sells in the catalog: their buy price, for the cost estimates
            # made by an earlier recipe of this profession from plain reagents: a part
            m = makers.get(item)
            if m and m["learn"] <= a and m["id"] != r["id"] and \
                    all(items[str(i)].get("type") != "craft" for i, _ in m["reagents"]):
                pm = {item_name(i): q for i, q in m["reagents"]}
                for i, _ in m["reagents"]:
                    ids[item_name(i)] = i
                parts[n] = {"recipe": m["name"], "makes": m["creates"][1], "materials_per_craft": pm}
        made = r["creates"]
        step = {"type": "craft", "skill_from": a, "skill_to": b, "recipe": r["name"],
                "skill_thresholds": dict(zip(("orange", "yellow", "green", "gray"), r["colors"])),
                "crafts": {"expected": e, "safe": s}, "materials_per_craft": mats,
                "source": source(r, cat), "alternatives": []}
        if made and (made[1] + made[2]) / 2 > 1:
            step["output_quantity"] = (made[1] + made[2]) // 2
        if r.get("focus"):
            step["station"] = r["focus"]
        if r.get("tools"):
            step["required_tools"] = [cat["tools"].get(str(t), {}).get("name", str(t)) for t in r["tools"]]
        if st.get("note"):
            step["instructions"] = st["note"]
        if r.get("forever"):
            step["forever"] = True
        steps.append({k: v for k, v in step.items() if v is not None})
    for p in parts.values():
        ids.setdefault(p["recipe"], None)
    return {
        "profession": prof, "guide": "Tried & Tested",
        "skill_from": route["steps"][0]["from"], "skill_to": route["steps"][-1]["to"],
        "source_estimate": {"average_crafts": total_e, "p90_crafts": total_s,
                            "playtested_in_forever": True, "source": "Wowhead: %s, version %d"
                            % (route["name"], route["version"])},
        "item_ids": {k: v for k, v in sorted(ids.items()) if v},
        "vendor_items": sorted(vendor_items),
        "parts": parts or None,
        "steps": steps,
    }


def vendor_prices(name):
    cat = json.load(open(os.path.join(DATA, "wh_catalog_%s.json" % name), encoding="utf-8"))["catalog"]
    return {str(i): v["price"] for i, v in cat["items"].items()
            if v.get("type") == "vendor" and isinstance(v.get("price"), int) and v["price"] > 0}


def main(names):
    data = json.load(open(GUIDES, encoding="utf-8"))
    prices = data.get("vendor_prices") or {}
    for name in names:
        prices.update(vendor_prices(name))
        g = build(name)
        g = {k: v for k, v in g.items() if v is not None}
        data["guides"] = [x for x in data["guides"]
                          if (x["profession"], x["guide"]) != (g["profession"], g["guide"])] + [g]
        print("%s: %d steps, ~%d crafts (safe %d)" % (g["profession"], len(g["steps"]),
              g["source_estimate"]["average_crafts"], g["source_estimate"]["p90_crafts"]))
    data["vendor_prices"] = dict(sorted(prices.items(), key=lambda kv: int(kv[0])))
    with open(GUIDES, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or ["tailoring", "cooking", "firstaid"]))
