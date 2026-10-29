extends SceneTree

const Simulation = preload("res://scripts/simulation.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	_run()
	print("Simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func enemy(id: int, x: float, y: float, hp: float = 10.0, kind: String = "normal") -> Dictionary:
	return {"id": id, "x": x, "y": y, "hp": hp, "maxHp": hp, "radius": 15, "kind": kind, "speed": 0, "damage": 1, "slow": 0, "orbitHitUntil": 0}

func fresh(mode: String = "quick") -> RefCounted:
	var sim = Simulation.new(42, mode)
	sim.start()
	sim.state.spawnTimer = 999.0
	sim.state.eliteTimer = 999.0
	return sim

func _run() -> void:
	var sim = fresh()
	expect(sim.state.phase == "playing" and sim.state.duration == 300, "quick starts")
	expect(sim.catalog.spellIds.size() == 8 and sim.catalog.fusions.size() == 4 and sim.catalog.artifacts.size() == 12, "catalog complete")
	sim.tick(0.05, Vector2(1, 1))
	expect(absf(sim.state.player.x - sim.state.player.y) < 0.001 and sim.state.player.x < 11, "diagonal movement normalized")
	sim.toggle_pause()
	var frozen: float = sim.state.time
	sim.tick(1, Vector2.RIGHT)
	expect(sim.state.time == frozen, "pause freezes time")
	sim.toggle_pause()

	sim = fresh()
	sim.state.xp = 6
	sim.tick(0.01)
	expect(sim.state.phase == "upgrade" and sim.state.choices.size() == 3 and sim.state.level == 2, "level offers three choices")
	var choice: String = sim.state.choices[0].id
	expect(sim.choose_upgrade(choice), "valid choice accepted")
	expect(not sim.choose_upgrade(choice), "choice cannot repeat")

	sim = fresh()
	sim.state.enemies = [enemy(1, 60, 0, 1, "elite")]
	sim.tick(0.05)
	sim.tick(0.05)
	expect(sim.state.kills == 1 and sim.state.chests.size() == 1, "elite drops one chest")
	sim.state.player.x = 60.0
	sim.tick(0.05)
	expect(sim.state.phase == "artifact" and sim.state.artifactChoices.size() == 3, "chest offers artifacts")
	var artifact_id: String = sim.state.artifactChoices[0].id
	expect(sim.choose_artifact(artifact_id) and sim.state.artifacts.has(artifact_id), "artifact acquired once")

	sim = fresh("expedition")
	sim.state.time = 509.99
	sim.tick(0.05)
	expect(sim.state.bossSpawned and sim.state.hazards.size() == 5, "boss and warnings spawn")
	sim.tick(0.05)
	expect(sim.state.hazards[0].warning > 0 and not sim.state.hazards[0].hit, "warning is not active damage")

	sim = fresh("expedition")
	sim.state.time = 599.99
	sim.state.player.hp = 0.0
	sim.state.bossDefeated = true
	sim.tick(0.05)
	expect(sim.state.phase == "lost" and sim.state.endReason == "death", "death precedes timeout and boss kill")

	sim = fresh("expedition")
	sim.state.time = 599.99
	sim.state.bossDefeated = true
	sim.tick(0.05)
	expect(sim.state.endReason == "timeout", "deadline precedes boss kill")

	sim = fresh()
	for i in range(200):
		sim.state.enemies.append(enemy(i + 1, 600, 0, 100))
	sim.state.spawnTimer = 0.0
	sim.tick(0.05)
	expect(sim.state.enemies.size() <= 200, "enemy cap")

	# Exercise each magic path with stable enemies and disabled unrelated casts.
	for spell_id in ["bolt", "orbit", "lightning", "frost", "fireball", "vortex", "meteor", "pulse"]:
		sim = fresh()
		sim.state.cooldowns.bolt = 999.0
		sim.state.spells[spell_id] = 1
		var distance := 72.0 if spell_id == "orbit" else (100.0 if spell_id == "pulse" else 70.0)
		sim.state.enemies = [enemy(1, distance, 0, 100)]
		if spell_id == "bolt": sim.state.cooldowns.bolt = 0.0
		for i in range(30): sim.tick(0.05)
		expect(sim.state.enemies[0].hp < 100, "%s damages an enemy" % spell_id)

	sim = fresh()
	sim.state.fusions.append("plasma")
	sim.state.enemies = [enemy(1, 80, 0, 20), enemy(2, 120, 0, 20)]
	sim.tick(0.05)
	expect(sim.state.enemies[0].hp < 20 and sim.state.enemies[1].hp < 20 and sim.state.projectiles.is_empty(), "plasma beam pierces")

	sim = fresh()
	sim.state.spells.bolt = 3
	sim.state.spells.lightning = 3
	sim.state.spells.frost = 3
	sim.state.spells.vortex = 3
	sim.state.xp = 6
	sim.tick(0.05)
	var offered := []
	for item in sim.state.choices: offered.append(item.id)
	expect(offered.has("plasma") and offered.has("blizzard"), "eligible fusions offered")
	sim.state.spells.lightning = 2
	expect(not sim.choose_upgrade("plasma"), "fusion rechecks requirements")
	sim.state.spells.lightning = 3
	expect(sim.choose_upgrade("plasma"), "valid fusion selected")

	sim = fresh()
	sim.state.spells.fireball = 3
	sim.state.spells.meteor = 3
	sim.state.spells.orbit = 3
	sim.state.spells.pulse = 3
	sim.state.xp = 6
	sim.tick(0.05)
	offered = []
	for item in sim.state.choices: offered.append(item.id)
	expect(offered.has("supernova") and offered.has("hyperion"), "remaining fusion recipes offered")

	sim = fresh()
	sim.state.artifacts = ["aegis", "worldtreeleaf", "sapphire"]
	sim.state.player.shield = 1
	sim.state.player.hp = 4.0
	sim.state.enemies = [enemy(1, 0, 0, 100)]
	sim.tick(0.05)
	expect(sim.state.player.shield == 0 and sim.state.player.hp > 4, "shield absorbs contact and leaf regenerates")
	sim.state.gems = [{"x": 0.0, "y": 0.0, "value": 4, "radius": 6}]
	sim.tick(0.05)
	expect(sim.state.xp == 5.0, "sapphire boosts XP")

	sim = fresh("expedition")
	sim.state.bossSpawned = true
	sim.state.bossId = 1
	sim.state.bossAttackTimer = 10.0
	sim.state.enemies = [enemy(1, 0, 0, 1, "boss")]
	sim.state.enemies[0].damage = 0
	sim.state.player.hp = 1.0
	sim.state.hazards = [{"id": 1, "kind": "circle", "x": 0.0, "y": 0.0, "radius": 70, "warning": 0.0, "active": 0.5, "hit": false}]
	sim.state.effects = [{"type": "pulse", "x": 0.0, "y": 0.0, "life": 0.5, "maxLife": 0.6, "radius": 0.0, "maxRadius": 120.0, "damage": 2.0, "hitIds": []}]
	sim.state.cooldowns.bolt = 999.0
	sim.tick(0.05)
	expect(sim.state.bossDefeated and sim.state.endReason == "death", "active hazard death outranks earlier pulse kill")

	sim = fresh()
	sim.state.enemies = [enemy(1, 1000, 0, 100)]
	sim.state.cooldowns.bolt = 999.0
	sim.tick(0.05)
	expect(sim.state.enemies.is_empty(), "distant enemies culled")

	sim = fresh()
	sim.state.xp = 15.0
	sim.tick(0.05)
	expect(sim.state.phase == "upgrade", "first overflow level queued")
	choice = sim.state.choices[0].id
	expect(sim.choose_upgrade(choice) and sim.state.phase == "upgrade" and sim.state.level == 3, "overflow queues next choice")

	sim = fresh()
	for item in sim.catalog.artifacts:
		sim.state.phase = "artifact"
		sim.state.artifactChoices = [item]
		expect(sim.choose_artifact(item.id), "%s can be acquired" % item.id)
	expect(sim.state.artifacts.size() == 12 and sim.state.player.maxHp == 9 and sim.state.player.speed > 220, "unique artifact state effects")
	sim.state.phase = "playing"
	sim.state.chests = [{"id": 1, "x": 0.0, "y": 0.0}]
	sim.state.player.hp = 1.0
	sim.state.cooldowns.bolt = 999.0
	sim.tick(0.05)
	expect(sim.state.phase == "playing" and sim.state.player.hp > 3, "exhausted artifact chest heals")

	sim = fresh("expedition")
	for i in range(200): sim.state.enemies.append(enemy(i + 1, 600, 0, 100))
	sim.state.nextEnemyId = 201
	sim.state.time = 509.99
	sim.tick(0.05)
	var boss_count := 0
	for member in sim.state.enemies:
		if member.kind == "boss": boss_count += 1
	expect(sim.state.enemies.size() == 200 and boss_count == 1, "boss reserves space at cap")
	sim.tick(0.05)
	boss_count = 0
	for member in sim.state.enemies:
		if member.kind == "boss": boss_count += 1
	expect(boss_count == 1, "boss only spawns once")

	sim = fresh()
	sim.state.spells.meteor = 1
	sim.state.cooldowns.bolt = 999.0
	sim.state.enemies = [enemy(1, 100, 0, 100)]
	sim.tick(0.05)
	expect(sim.state.strikes.size() == 1 and sim.state.enemies[0].hp == 100, "meteor warns before impact")
	for i in range(15): sim.tick(0.05)
	expect(sim.state.enemies[0].hp < 100, "meteor strikes after delay")
