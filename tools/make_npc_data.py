#!/usr/bin/env python3
"""Writes NpcData.lua (where Craftbound's trainers and vendors stand) from an installed QuestieDB.

Run from the addon folder:  python3 tools/make_npc_data.py [path/to/QuestieDB]
(default: ../QuestieDB, next to Craftbound in Interface/AddOns). Re-run when QuestieDB or the
guides change (the recipe vendors come from tools/data/profession-guides.json).

The NPC facts (names, where they stand, which side they serve, trainer titles, who sells which
item) come from QuestieDB, a part of Questie (https://github.com/Questie/Questie), used under the
GPLv3 terms the Questie team allows; Craftbound is GPL-3.0-or-later. The reader is Packbound's
(tools/make_vendor_data.py). QuestieDB stores entities in its TOC as base64 CBOR rows
("## X-<Kind>-<id>-S" for scalars, "-<field>" for table fields; "~N~" splits a value in N parts).
"""
import base64
import json
import os
import re
import struct
import sys

ITEM_VENDORS = 14                                   # itemMeta: vendors
NPC_NAME, NPC_SPAWNS, NPC_SIDE, NPC_SUB, NPC_FLAGS = 1, 7, 13, 14, 15
TRAINER = 16                                        # npcFlags

# a trainer's title -> its profession (specialisation masters are left out: they teach one line)
PROFESSIONS = [
    ("Alchem", "Alchemy"), ("Blacksmith", "Blacksmithing"), ("Enchant", "Enchanting"),
    ("Engineer", "Engineering"), ("Leatherwork", "Leatherworking"), ("Tailor", "Tailoring"),
    ("Cook", "Cooking"), ("Chef", "Cooking"), ("First Aid", "First Aid"), ("Physician", "First Aid"),
    ("Surgeon", "First Aid"),
]
SPECIALIST = re.compile(r"Gnome|Goblin|Dragonscale|Elemental|Tribal|Shadoweave|Mooncloth|Spellfire|"
                        r"Weaponsmith|Armorsmith|Hammersmith|Swordsmith|Axesmith", re.I)


def tier(title):
    """How far a trainer teaches: 1 to Journeyman, 2 to Expert, 3 to Artisan (from its title)."""
    t = title.lower()
    if "artisan" in t or t.startswith("master") or "surgeon" in t or "physician" in t:
        return 3
    if "expert" in t or "superior" in t:
        return 2
    return 1


def cbor(b, i=0):
    """Decodes one CBOR item at b[i:]; returns (value, next index)."""
    head = b[i]
    major, info = head >> 5, head & 31
    i += 1
    if major == 7:
        simple = {20: False, 21: True, 22: None, 23: None}
        if info in simple:
            return simple[info], i
        size, fmt = {25: (2, ">e"), 26: (4, ">f"), 27: (8, ">d")}[info]
        return struct.unpack(fmt, b[i:i + size])[0], i + size
    if info < 24:
        n = info
    else:
        size = {24: 1, 25: 2, 26: 4, 27: 8}[info]
        n, i = int.from_bytes(b[i:i + size], "big"), i + size
    if major == 0:
        return n, i
    if major == 1:
        return -1 - n, i
    if major in (2, 3):
        raw = b[i:i + n]
        return raw.decode("utf-8") if major == 3 else raw, i + n
    if major == 4:
        out = []
        for _ in range(n):
            v, i = cbor(b, i)
            out.append(v)
        return out, i
    if major == 5:
        out = {}
        for _ in range(n):
            k, i = cbor(b, i)
            v, i = cbor(b, i)
            out[k.decode("utf-8") if isinstance(k, bytes) else k] = v
        return out, i
    if major == 6:
        return cbor(b, i)
    raise ValueError("CBOR major type %d" % major)


def text(v):
    return v.decode("utf-8") if isinstance(v, bytes) else v


class QuestieDB:
    def __init__(self, folder):
        toc = os.path.join(folder, "QuestieDB_Forever.toc")
        self.store = {}
        with open(toc, encoding="utf-8") as f:
            for line in f:
                if line.startswith("## X-"):
                    key, _, value = line[3:].partition(":")
                    self.store[key.strip()] = value.strip()
        self.zones = {}
        with open(os.path.join(folder, "support", "Forever", "Zones", "areaIdToUiMapId.lua"),
                  encoding="utf-8") as f:
            src = f.read()
        base = src.split("ZoneDB.private.areaIdToUiMapId =", 1)[1]
        override = src.split("ZoneDB.private.areaIdToUiMapIdOverride =", 1)[1].split("]]", 1)[0]
        for block in (base.split("]]", 1)[0], override):  # the override wins
            for area, ui in re.findall(r"\[(\d+)\]\s*=\s*(\d+)", block):
                self.zones[int(area)] = int(ui)

    def get(self, key):
        v = self.store.get(key)
        if v is None:
            return None
        if v.startswith("~"):
            parts = int(v.strip("~"))
            v = "".join(self.store["%s-%d" % (key, n)] for n in range(1, parts + 1))
        return cbor(base64.b64decode(v))[0]

    def field(self, kind, id_, index):
        if index == 1 or kind == "Npc" and index == NPC_SIDE:
            row = self.get("X-%s-%d-S" % (kind, id_)) or {}
            return row.get(index)
        return self.get("X-%s-%d-%d" % (kind, id_, index))




def row(db, npc):
    r = db.get("X-Npc-%d-S" % npc)
    if isinstance(r, list):
        r = {n + 1: v for n, v in enumerate(r)}
    return r or {}


def place(db, npc):
    """The first spawn of an NPC in a zone with a map: (uiMapID, x, y) or None."""
    spawns = db.field("Npc", npc, NPC_SPAWNS) or {}
    if isinstance(spawns, list):  # a Lua table keyed 1..n comes out as a list
        spawns = {n + 1: v for n, v in enumerate(spawns) if v}
    for area in sorted(spawns):
        ui = db.zones.get(area)
        points = [p for p in spawns[area] if p and 0 < p[0] < 100 and 0 < p[1] < 100]
        if ui and points:
            return ui, points[0][0] / 100, points[0][1] / 100
    return None


def npc_entry(db, npc):
    r = row(db, npc)
    name, side = text(r.get(NPC_NAME)), text(r.get(NPC_SIDE))
    where = place(db, npc)
    if not name or not where:
        return None
    return {"npc": npc, "name": name, "map": where[0], "x": where[1], "y": where[2],
            "side": side if side in ("A", "H", "AH") else "AH"}


def lua_string(s):
    return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')


def lua_npc(v, extra=""):
    return "{ npc = %d, name = %s, map = %d, x = %.4f, y = %.4f, side = \"%s\"%s }" % (
        v["npc"], lua_string(v["name"]), v["map"], v["x"], v["y"], v["side"], extra)


HEADER = '''-- Where Craftbound's trainers and vendors stand, for waypoints (Waypoint.lua).
--   ns.NPC.trainers[profession] = { { npc, name, map = uiMapID, x, y (0..1), side, tier }, ... }
--     tier: how far the trainer teaches, 1 Journeyman, 2 Expert, 3 Artisan (from its title)
--   ns.NPC.npcs[npc id]         = { npc, name, map, x, y, side } (recipe and supply vendors)
--   ns.NPC.sells[item id]       = { npc ids of vendors selling it } (vendor-only reagents)
--
-- GENERATED by tools/make_npc_data.py from QuestieDB; do not edit by hand, re-run it.
-- The NPC facts come from QuestieDB, a part of Questie (https://github.com/Questie/Questie),
-- by Muehe, Logon, TheCrux/BreakBB, Drejjmit, Cheeq, TechnoHunter, Yttrium and the Questie
-- contributors, used under the GNU GPL v3 as the Questie team allows (Craftbound is GPL-3.0-or-later).
local _, ns = ...

ns.NPC = { trainers = {}, npcs = {}, sells = {} }
local T, N, S = ns.NPC.trainers, ns.NPC.npcs, ns.NPC.sells
'''


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join("..", "QuestieDB")
    db = QuestieDB(folder)
    guides = json.load(open(os.path.join("tools", "data", "profession-guides.json"), encoding="utf-8"))

    # trainers
    trainers = {}
    ids = sorted({int(k.split("-")[2]) for k in db.store if re.match(r"X-Npc-\d+-S$", k)})
    for npc in ids:
        r = row(db, npc)
        flags, title = r.get(NPC_FLAGS), text(r.get(NPC_SUB))
        if not (isinstance(flags, int) and flags & TRAINER and title) or SPECIALIST.search(title):
            continue
        prof = next((p for key, p in PROFESSIONS if key.lower() in title.lower()), None)
        if not prof:
            continue
        v = npc_entry(db, npc)
        if v:
            v["tier"] = tier(title)
            trainers.setdefault(prof, []).append(v)

    # recipe vendors named in the guides, and vendors of vendor-only reagents
    wanted = set()
    for g in guides["guides"]:
        for s in g["steps"]:
            src = s.get("source") or {}
            if src.get("npc_id"):
                wanted.add(src["npc_id"])
            for v in src.get("vendors") or []:
                if v.get("id"):
                    wanted.add(v["id"])
    items = sorted(int(i) for i in (guides.get("vendor_prices") or {}))
    sells = {}
    for item in items:
        for npc in db.field("Item", item, ITEM_VENDORS) or []:
            sells.setdefault(item, []).append(npc)
            wanted.add(npc)
    npcs, missing = {}, []
    for npc in sorted(wanted):
        v = npc_entry(db, npc)
        if v:
            npcs[npc] = v
        else:
            missing.append(npc)

    lines = [HEADER]
    for prof in sorted(trainers):
        lines.append("T[%s] = {\n" % lua_string(prof))
        for v in sorted(trainers[prof], key=lambda v: (v["map"], v["name"])):
            lines.append("\t%s,\n" % lua_npc(v, ", tier = %d" % v["tier"]))
        lines.append("}\n")
    for npc in sorted(npcs):
        lines.append("N[%d] = %s\n" % (npc, lua_npc(npcs[npc])))
    for item in sorted(sells):
        known = [n for n in sells[item] if n in npcs]
        if known:
            lines.append("S[%d] = { %s }\n" % (item, ", ".join(map(str, known))))
    with open("NpcData.lua", "w", encoding="utf-8", newline="\n") as f:
        f.write("".join(lines))
    print("NpcData.lua: %d trainers in %d professions, %d vendors, %d reagents sold."
          % (sum(len(t) for t in trainers.values()), len(trainers), len(npcs), len(sells)))
    if missing:
        print("  no place in QuestieDB for NPC", ", ".join(map(str, missing)))


if __name__ == "__main__":
    main()
