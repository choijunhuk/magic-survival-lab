extends SceneTree

var checks := 0
var failures := 0

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func by_canonical(entries: Array, canonical: String) -> Dictionary:
	for entry in entries:
		if entry.get("canonicalId", entry.get("id", "")) == canonical:
			return entry
	return {}

func _initialize() -> void:
	var release_file := FileAccess.open("res://data/release_content.json", FileAccess.READ)
	expect(release_file != null, "release catalog readable")
	if release_file == null:
		quit(1)
		return
	var catalog = JSON.parse_string(release_file.get_as_text())
	expect(catalog is Dictionary, "release catalog parses")
	if not catalog is Dictionary:
		quit(1)
		return
	var legacy = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	for key in ["spellIds", "upgrades", "fusions", "artifacts", "zones", "bosses", "enemies", "elites", "classes", "research", "events", "resonances"]:
		var expected := {"spellIds": 24, "upgrades": 28, "fusions": 36, "artifacts": 96, "zones": 6,
			"bosses": 6, "enemies": 24, "elites": 18, "classes": 6, "research": 24, "events": 12, "resonances": 4}
		expect(catalog[key].size() == expected[key], "%s exact release count" % key)
	for i in range(8):
		expect(catalog.spellIds[i] == legacy.spellIds[i], "legacy spell ID %d stable" % i)
		expect(catalog.upgrades[i].id == legacy.upgrades[i].id and catalog.upgrades[i].icon == legacy.upgrades[i].icon, "legacy spell fields %d stable" % i)
	for i in range(4):
		expect(catalog.fusions[i].id == legacy.fusions[i].id and catalog.fusions[i].requires == legacy.fusions[i].requires, "legacy fusion recipe %d stable" % i)
	for i in range(12):
		expect(catalog.artifacts[i].id == legacy.artifacts[i].id and catalog.artifacts[i].icon == legacy.artifacts[i].icon, "legacy artifact fields %d stable" % i)
	for i in range(24):
		expect(catalog.upgrades[i].canonicalId == "M%02d" % (i + 1), "spell canonical sequence %d" % i)
	for i in range(36):
		expect(catalog.fusions[i].canonicalId == "F%02d" % (i + 1), "fusion canonical sequence %d" % i)
	for i in range(96):
		expect(catalog.artifacts[i].canonicalId == "A%03d" % (i + 1), "artifact canonical sequence %d" % i)
	var spells: Dictionary = {}
	for id in catalog.spellIds:
		expect(not spells.has(id), "spell ID unique: %s" % id)
		spells[id] = true
	var recipes: Dictionary = {}
	for fusion in catalog.fusions:
		var ingredients: Array = fusion.requires.keys()
		ingredients.sort()
		expect(ingredients.size() == 2, "%s has two ingredients" % fusion.id)
		for ingredient in ingredients:
			expect(spells.has(ingredient) and fusion.requires[ingredient] == 3, "%s ingredient valid: %s" % [fusion.id, ingredient])
		var key: String = "+".join(ingredients)
		expect(not recipes.has(key), "recipe unique: %s" % fusion.id)
		recipes[key] = true
	# Independent GDD anchors guard against a generator and fixture sharing one mistake.
	expect(by_canonical(catalog.upgrades, "M15").name == "봉인 문양", "GDD M15 name")
	expect(by_canonical(catalog.upgrades, "M15").action.find("주기 피해") >= 0, "GDD M15 periodic damage for C06")
	var f09: Dictionary = by_canonical(catalog.fusions, "F09").requires
	var f35: Dictionary = by_canonical(catalog.fusions, "F35").requires
	expect(f09.size() == 2 and f09.get("orbit") == 3 and f09.get("m13") == 3, "GDD F09 recipe")
	expect(f35.size() == 2 and f35.get("m24") == 3 and f35.get("fireball") == 3, "GDD F35 recipe")
	expect(by_canonical(catalog.artifacts, "A096").name == "마지막 잎", "GDD A096 name")
	expect(catalog.enemies[0].id == "N01" and catalog.enemies[0].family == "보행" and catalog.enemies[0].behavior == "느린 직진", "GDD N01 walking behavior")
	expect(catalog.enemies[9].id == "N10" and catalog.enemies[9].family == "분열" and catalog.enemies[9].behavior == "파열 대신 지연 폭발", "GDD N10 delayed explosion")
	expect(catalog.enemies[23].id == "N24" and catalog.enemies[23].family == "잠행" and catalog.enemies[23].behavior == "측면 재등장", "GDD N24 flank reappearance")
	expect(catalog.elites[6].id == "X07" and catalog.elites[6].family == "지연" and catalog.elites[6].behavior == "두 박자 원형 경고", "GDD X07 two beat warning")
	expect(catalog.elites[17].id == "X18" and catalog.elites[17].family == "흡수" and catalog.elites[17].behavior == "받은 영역 피해 뒤 노출", "GDD X18 exposure")
	var family_counts: Dictionary = {}
	for i in range(24):
		var enemy: Dictionary = catalog.enemies[i]
		expect(enemy.id == "N%02d" % (i + 1) and not enemy.behavior.is_empty(), "normal enemy ID and behavior %d" % i)
		family_counts[enemy.family] = family_counts.get(enemy.family, 0) + 1
	expect(family_counts.size() == 12, "twelve distinct normal families")
	for count in family_counts.values():
		expect(count == 2, "each normal family has two variants")
	for i in range(18):
		var elite: Dictionary = catalog.elites[i]
		expect(elite.id == "X%02d" % (i + 1) and family_counts.has(elite.family) and not elite.behavior.is_empty(), "elite ID, family, behavior %d" % i)
	expect(catalog.classes[5].spellId == "m15", "GDD C06 starts M15")
	expect(catalog.research[22].requires == ["R17", "R18"], "GDD R23 prerequisites")
	expect(catalog.research[23].requires == ["R19", "R23"], "GDD R24 prerequisites")
	expect(catalog.events[9].id == "E10" and catalog.events[9].condition.find("XP") >= 0, "GDD E10 XP cost")
	expect(catalog.modes.keys() == ["campaign"] and catalog.modes.campaign.duration == 900 and catalog.modes.campaign.bossAt == 810, "campaign timing")
	for key in ["upgrades", "fusions", "artifacts", "zones", "bosses", "enemies", "elites", "classes", "research", "events"]:
		for entry in catalog[key]:
			if entry.has("icon"):
				expect(FileAccess.file_exists("res://" + entry.icon), "%s icon exists: %s" % [key, entry.id])
	print("Release catalog: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
