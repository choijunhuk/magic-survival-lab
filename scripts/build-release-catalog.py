#!/usr/bin/env python3
"""Extract the release 1.0 catalog from the structured GDD tables."""

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "godot/data"
SYSTEMS = json.loads((ROOT / "docs/gdd/parts/02-systems.json").read_text())
WORLDS = json.loads((ROOT / "docs/gdd/parts/03-worlds.json").read_text())
LEGACY = json.loads((DATA / "content.json").read_text())
OUTPUT = DATA / "release_content.json"


def page(source, number):
    return next(p for p in source["pages"] if p["id"] == f"p{number:03}")


def rows(source, numbers, heading):
    for number in numbers:
        block = next(b for b in page(source, number)["blocks"] if b.get("heading", "").startswith(heading))
        yield from block["rows"]


def paragraphs(source, number):
    return {b["heading"]: b["text"] for b in page(source, number)["blocks"] if b["kind"] == "p"}


def id_and_name(cell):
    match = re.fullmatch(r"([A-Z]\d{2,3})\s+(.+)", cell)
    if not match:
        raise ValueError(f"Invalid ID/name cell: {cell}")
    return match.groups()


def build():
    catalog = {"spellIds": list(LEGACY["spellIds"]), "upgrades": [], "fusions": [], "artifacts": [],
               "zones": [], "bosses": [], "enemies": [], "elites": [], "classes": [], "research": [], "events": [],
               "resonances": [], "modes": {"campaign": {"id": "campaign", "duration": 900, "bossAt": 810}}}
    legacy_upgrades = {x["id"]: x for x in LEGACY["upgrades"]}
    legacy_fusions = {x["id"]: x for x in LEGACY["fusions"]}
    legacy_artifacts = {x["id"]: x for x in LEGACY["artifacts"]}
    spell_map = {f"M{i:02}": slug for i, slug in enumerate(LEGACY["spellIds"], 1)}
    for canonical, name, school, action, growth in rows(SYSTEMS, range(18, 24), "1.0 기초 마법 설계"):
        index = int(canonical[1:])
        slug = spell_map.get(canonical, canonical.lower())
        spell_map[canonical] = slug
        entry = dict(legacy_upgrades[slug]) if index <= 8 else {"id": slug, "name": name}
        entry.update({"canonicalId": canonical, "school": school, "action": action, "growth": growth})
        if index > 8:
            entry["description"] = f"{action} {growth}"
        catalog["upgrades"].append(entry)
        if index > 8:
            catalog["spellIds"].append(slug)
    catalog["upgrades"].extend(x for x in LEGACY["upgrades"] if x["id"] not in LEGACY["spellIds"])

    fusion_map = {f"F{i:02}": x["id"] for i, x in enumerate(LEGACY["fusions"], 1)}
    for canonical, name, ingredients, effect, limit in rows(SYSTEMS, range(25, 31), "융합 카드"):
        index = int(canonical[1:])
        slug = fusion_map.get(canonical, canonical.lower())
        recipe = {spell_map[part]: 3 for part in ingredients.split("+")}
        entry = dict(legacy_fusions[slug]) if index <= 4 else {"id": slug, "name": name, "kind": "fusion"}
        entry.update({"canonicalId": canonical, "requires": recipe, "effect": effect, "limit": limit})
        if index > 4:
            entry["description"] = f"{effect} {limit}"
        catalog["fusions"].append(entry)

    for canonical, name, rarity, effect, limit in rows(SYSTEMS, range(33, 39), "유물 설계"):
        index = int(canonical[1:])
        slug = list(legacy_artifacts)[index - 1] if index <= 12 else canonical.lower()
        entry = dict(legacy_artifacts[slug]) if index <= 12 else {"id": slug, "name": name}
        entry.update({"canonicalId": canonical, "rarity": rarity, "effect": effect, "limit": limit})
        if index > 12:
            entry["description"] = f"{effect} {limit}"
        catalog["artifacts"].append(entry)

    for index in range(1, 7):
        zone_id, zone_name = id_and_name(page(WORLDS, 39 + index)["title"])
        boss_id, boss_name = id_and_name(page(WORLDS, 48 + index)["title"])
        zone_p = paragraphs(WORLDS, 39 + index)
        boss_p = paragraphs(WORLDS, 48 + index)
        terrain = next(v for k, v in zone_p.items() if k.startswith("지형과 읽기"))
        phenomenon = next(v for k, v in zone_p.items() if k.startswith("현상 일정"))
        encounter = next(v for k, v in zone_p.items() if k.startswith("조우 생태"))
        catalog["zones"].append({"id": zone_id, "name": zone_name, "bossId": boss_id,
                                 "description": terrain, "phenomenon": phenomenon, "encounter": encounter})
        catalog["bosses"].append({"id": boss_id, "name": boss_name, "zoneId": zone_id,
                                  "description": " ".join(boss_p.values())})

    for family, first, second, role in rows(WORLDS, [56], "가족별 변형과 읽기"):
        for variant in (first, second):
            match = re.fullmatch(r"(N\d{2})\s+([^:]+):\s*(.+)", variant)
            if not match:
                raise ValueError(f"Invalid normal enemy variant: {variant}")
            enemy_id, name, behavior = match.groups()
            catalog["enemies"].append({"id": enemy_id, "name": name, "family": family,
                                       "behavior": behavior, "counterplay": role,
                                       "description": f"{behavior}; {role}"})
    for cell, family, threat in rows(WORLDS, [57], "1.0 정예 목록"):
        elite_id, name = id_and_name(cell)
        catalog["elites"].append({"id": elite_id, "name": name, "family": family,
                                  "behavior": threat, "description": threat})

    for cell, kit, tradeoff in list(rows(WORLDS, [59], "계열 제안"))[:6]:
        canonical, name = id_and_name(cell)
        spell_name = kit.split(" Lv1")[0]
        spell_id = next(x["id"] for x in catalog["upgrades"][:24]
                        if x["name"] == spell_name or spell_name.startswith(x["canonicalId"] + " "))
        benefit, cost = [x.strip() for x in tradeoff.split(",", 1)]
        catalog["classes"].append({"id": canonical, "name": name, "spellId": spell_id,
                                   "description": f"{kit}; {tradeoff}", "benefit": benefit, "cost": cost})

    for cell, prerequisites, points, effect in rows(WORLDS, [61], "1.0 연구 그래프"):
        canonical, name = id_and_name(cell)
        index = int(canonical[1:])
        cost = 10 if index <= 4 else 18 if index <= 12 else 28 if index <= 20 else 40
        catalog["research"].append({"id": canonical, "name": name, "cost": cost,
                                    "requires": [] if prerequisites == "선행 없음" else prerequisites.split("+"),
                                    "points": int(points), "description": effect})

    for cell, reward, requirement, failure in rows(WORLDS, [58], "사건 결정표"):
        canonical, name = id_and_name(cell)
        catalog["events"].append({"id": canonical, "name": name,
                                  "description": f"{reward}; {requirement}; {failure}",
                                  "reward": reward, "condition": requirement, "declineOrFailure": failure})

    resonance_page = page(SYSTEMS, 31)
    plasma = next(b for b in resonance_page["blocks"] if b.get("heading") == "플라즈마 시험 분기")["rows"]
    others = next(b for b in resonance_page["blocks"] if b.get("heading", "").startswith("출시의 나머지"))["rows"]
    for i in range(1, 5):
        canonical = f"F{i:02}"
        source_rows = plasma if i == 1 else [r for r in others if r[0].startswith(canonical + " ")]
        choices = []
        for index, row in enumerate(source_rows, 1):
            label = row[0] if i == 1 else row[0].split(" ", 1)[1]
            benefit, cost = row[1:3]
            choices.append({"id": f"{canonical}-R{index}", "name": label, "benefit": benefit,
                            "cost": cost, "description": f"{benefit}; {cost}"})
        catalog["resonances"].append({"fusionId": fusion_map[canonical], "canonicalFusionId": canonical,
                                      "choices": choices})
    return catalog


def validate(catalog):
    lengths = {"spellIds": 24, "upgrades": 28, "fusions": 36, "artifacts": 96,
               "zones": 6, "bosses": 6, "enemies": 24, "elites": 18,
               "classes": 6, "research": 24, "events": 12, "resonances": 4}
    for key, length in lengths.items():
        assert len(catalog[key]) == length, (key, len(catalog[key]))
    assert len(set(catalog["spellIds"])) == 24
    for key, prefix, count, width in [("upgrades", "M", 24, 2), ("fusions", "F", 36, 2),
                                      ("artifacts", "A", 96, 3)]:
        entries = catalog[key][:count]
        assert [x["canonicalId"] for x in entries] == [f"{prefix}{i:0{width}}" for i in range(1, count + 1)]
        assert len({x["id"] for x in catalog[key]}) == len(catalog[key])
    for key, prefix, count in [("zones", "Z", 6), ("bosses", "B", 6),
                               ("enemies", "N", 24), ("elites", "X", 18),
                               ("classes", "C", 6), ("research", "R", 24), ("events", "E", 12)]:
        assert [x["id"] for x in catalog[key]] == [f"{prefix}{i:02}" for i in range(1, count + 1)]
    families = {x["family"] for x in catalog["enemies"]}
    assert len(families) == 12
    assert all(sum(x["family"] == family for x in catalog["enemies"]) == 2 for family in families)
    assert all(x["family"] in families for x in catalog["elites"])
    spell_ids = set(catalog["spellIds"])
    recipes = set()
    for fusion in catalog["fusions"]:
        assert len(fusion["requires"]) == 2 and set(fusion["requires"]) <= spell_ids
        assert set(fusion["requires"].values()) == {3}
        recipe = frozenset(fusion["requires"])
        assert recipe not in recipes, fusion["canonicalId"]
        recipes.add(recipe)
    assert all(x["spellId"] in spell_ids for x in catalog["classes"])
    assert all(x["bossId"] == catalog["bosses"][i]["id"] for i, x in enumerate(catalog["zones"]))
    assert all(x["zoneId"] == catalog["zones"][i]["id"] for i, x in enumerate(catalog["bosses"]))
    graph = {x["id"]: x["requires"] for x in catalog["research"]}
    visited = set()
    visiting = set()
    def visit(node):
        assert node in graph and node not in visiting, node
        if node in visited:
            return
        visiting.add(node)
        for predecessor in graph[node]:
            visit(predecessor)
        visiting.remove(node)
        visited.add(node)
    for node in graph:
        visit(node)
    assert all(node == "R01" or graph[node] for node in graph)
    assert all(len(x["choices"]) == 3 for x in catalog["resonances"])
    assert {x["fusionId"] for x in catalog["resonances"]} <= {x["id"] for x in catalog["fusions"]}
    for key in ("upgrades", "fusions", "artifacts"):
        for entry in catalog[key]:
            if "icon" in entry:
                assert (ROOT / "godot" / entry["icon"]).is_file(), entry["icon"]


if __name__ == "__main__":
    data = build()
    validate(data)
    encoded = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if sys.argv[1:] == ["--check"]:
        assert OUTPUT.read_text() == encoded, "Release catalog is stale; regenerate it"
    elif not sys.argv[1:]:
        OUTPUT.write_text(encoded)
    else:
        raise SystemExit("Usage: build-release-catalog.py [--check]")
    print(f"Validated {OUTPUT.relative_to(ROOT)} ({len(encoded.encode())} bytes)")
