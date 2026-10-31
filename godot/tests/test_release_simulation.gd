extends SceneTree

const Sim = preload("res://scripts/release_simulation.gd")
const Enc = preload("res://scripts/release_encounters.gd")
const Combat = preload("res://scripts/release_combat.gd")
const Events = preload("res://scripts/release_events.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)

func fresh(class_id: String = "C01", zone: String = "Z01", research: Array = []):
	var sim := Sim.new(42, "campaign", {"classId": class_id, "zoneId": zone, "research": research, "runId": "semantic-test"})
	sim.start(); sim.state.spawnTimer = 10000; sim.state.eliteTimer = 10000
	return sim

func target(sim, point: Vector2 = Vector2(80, 0), normal_id: int = 1, kind: String = "normal") -> Dictionary:
	var value := Enc.enemy(sim, normal_id, 0, point)
	value.hp = 1000; value.maxHp = 1000; value.speed = 0; value.kind = kind
	return value

func no_spells(sim) -> void:
	for id in sim.state.spells: sim.state.spells[id] = 0

func event(sim, id: String) -> void:
	for item in sim.catalog.events:
		if item.id == id:
			var marker := {"id": id, "x": sim.state.player.x, "y": sim.state.player.y, "status": "placed"}
			sim.state.events = [marker]; Events.offer_nearby(sim); return

func run_frames(sim, frames: int) -> void:
	for i in range(frames): sim.tick(1.0 / 60.0)

func _initialize() -> void:
	var sim = fresh()
	check(sim.state.duration == 900 and sim.state.bossAt == 810 and sim.state.bossKind == "B01", "campaign timeline independent from legacy")
	check(sim.state.rewardEligible and sim.state.runId == "semantic-test", "run identity explicit")
	for i in range(1, 7):
		sim = fresh("C%02d" % i)
		check(sim.learned_count() == 1, "class exactly one starting spell C%d" % i)
		check(sim.state.spells.bolt == (1 if i == 1 else 0), "no free bolt class C%d" % i)
		sim._advance_attacks(0.05)
		check(sim.state.projectiles.is_empty(), "no-target attack preserves cooldown C%d" % i)
	sim = fresh(); no_spells(sim)
	for id in ["bolt", "orbit", "lightning", "frost", "fireball", "vortex"]: sim.state.spells[id] = 3
	sim._offer_upgrade()
	check(not sim.state.choices.any(func(x): return sim.state.spells.has(x.id) and sim.state.spells[x.id] == 0), "offer respects six slots")
	sim.state.choices = [{"id": "meteor"}]
	check(not sim.choose_upgrade("meteor"), "stale choice cannot bypass spell cap")
	sim.state.fusions = ["plasma", "blizzard", "supernova"]
	sim.state.spells.pulse = 3
	sim.state.choices = [sim.catalog.fusions[3]]
	check(not sim.choose_upgrade("hyperion"), "stale choice cannot bypass fusion cap")
	sim.state.fusions.clear(); sim.state.spells.bolt = 3; sim.state.spells.lightning = 3
	sim.state.choices = [sim.catalog.fusions[0]]
	check(sim.choose_upgrade("plasma") and sim.state.spells.bolt == 3 and sim.state.spells.lightning == 3, "fusion retains Lv3 materials")
	sim.state.phase = "upgrade"; sim.state.spells.bolt = 5; sim.state.choices = [{"id": "bolt"}]
	check(not sim.choose_upgrade("bolt"), "level5 cap enforced again at choose")
	# No post-terminal upgrades/events or simultaneous boss-win revival.
	sim = fresh(); no_spells(sim); sim.state.player.hp = 0; sim.state.time = 899.99; sim.state.bossDefeated = true; sim.state.xp = 100
	sim.tick(0.05)
	check(sim.state.phase == "lost" and sim.state.endReason == "death", "death beats deadline and boss")
	sim = fresh(); no_spells(sim); sim.state.time = 899.99; sim.state.bossDefeated = true; sim.tick(0.05)
	check(sim.state.phase == "lost" and sim.state.endReason == "timeout", "deadline beats boss")
	sim = fresh(); no_spells(sim); sim.state.bossDefeated = true; sim.tick(0.05)
	check(sim.state.phase == "won", "boss victory before deadline")
	sim = fresh(); no_spells(sim); sim.state.phase = "paused"; var before: float = sim.state.time; sim.tick(0.05)
	check(sim.state.time == before, "pause freezes clock")
	# Each spell executes actual targeting/geometry/state without parse/runtime errors.
	for id in sim.catalog.spellIds:
		sim = fresh(); no_spells(sim); sim.state.spells[id] = 3
		var enemy := target(sim)
		if id == "m14": sim.state.safeTime = 11.99
		if id == "m20": sim.state.enemyProjectiles = [{"id": 5, "ownerId": enemy.id, "x": 40.0, "y": 0.0, "vx": -100.0, "vy": 0.0, "radius": 5, "life": 3, "damage": 1, "beam": false}]
		if id == "m23": enemy.castWarning = 0.5
		run_frames(sim, 90)
		var acted: bool = enemy.hp < 1000 or not sim.state.fields.is_empty() or not sim.state.projectiles.is_empty() or not sim.state.seeds.is_empty() or not sim.state.marks.is_empty() or not enemy.statuses.is_empty()
		if id in ["m14", "m22", "m24"]: acted = true # separately test trigger contracts below
		if id == "m20": acted = sim.state.enemyProjectiles.is_empty() or sim.state.enemyProjectiles[0].get("deflected", false)
		if id == "m23": acted = enemy.get("delayedUntil", 0) > 0
		check(acted, "spell produces its combat state: " + id)
	# Safe seed, no overflow shield, and fatal return are independent passive mechanics.
	sim = fresh(); no_spells(sim); sim.state.spells.m14 = 1; sim.state.safeTime = 11.99; sim._advance_player(0.02, Vector2.RIGHT)
	check(sim.state.seeds.is_empty() and sim.state.player.shield == 0, "seed at fullHP collected without shield conversion")
	sim.state.safeTime = 11; sim.state.player.invulnerable = 0; sim.hurt_player(1)
	check(sim.state.safeTime == 0, "taking damage resets seed safety clock")
	sim = fresh(); no_spells(sim); sim.state.spells.m24 = 1; sim.hurt_player(9)
	check(sim.state.player.hp == 6 and sim.state.player.x < 0 and sim.state.returnReadyAt > 0, "fatal return retreats and negates damage")
	sim.state.player.invulnerable = 0; sim.hurt_player(9)
	check(sim.state.player.hp == 0, "fatal return recharge cannot be bypassed")
	sim = fresh(); no_spells(sim); sim.state.spells.m22 = 5; sim.state.player.hp = 4; sim.state.healBudget = 0.3
	for i in range(8):
		var enemy := target(sim); enemy.hp = 0.1; sim.apply_damage(enemy, 1, sim.context("bolt"))
	check(sim.state.player.hp > 4 and sim.state.echoKills == 0, "kill threshold heals once")
	# DOT refresh retains the tick clock and boss controls convert instead of freezing.
	sim = fresh(); no_spells(sim); var enemy := target(sim)
	sim.apply_status(enemy, "ignite", 3); Combat.advance_effects(sim, 0.5); sim.apply_status(enemy, "ignite", 3)
	check(is_equal_approx(enemy.statuses.ignite.nextTick, 0.5), "ignite refresh cannot accelerate tick")
	enemy.kind = "boss"; sim.apply_status(enemy, "root", 0.6)
	check(not enemy.statuses.has("root") and is_equal_approx(enemy.statuses.slow.remaining, 0.2), "boss root converts to short slow")
	# Each zone creates a distinct owned hazard with an actual warning and collision shape.
	var shapes := []
	for i in range(1, 7):
		sim = fresh("C01", "Z%02d" % i); sim.state.time = 200; Enc.advance_phenomenon(sim, 0.05)
		check(not sim.state.hazards.is_empty(), "map phenomenon Z%d" % i)
		var h: Dictionary = sim.state.hazards[0]; shapes.append(h.shape)
		check(h.owner == "map" and h.warning >= 0.8 and h.has("safeGap"), "map hazard render/collision contract Z%d" % i)
		var hp: float = sim.state.player.hp; Enc.update_hazards(sim, 0.05)
		check(sim.state.player.hp == hp, "map warning causes no damage Z%d" % i)
	check(shapes.has("ring") and shapes.has("ray") and shapes.has("wave"), "map geometries differ")
	for i in range(1, 7):
		sim = fresh("C01", "Z%02d" % i); Enc.spawn_boss(sim)
		var boss: Dictionary = sim.state.enemies[0]; Enc.warn_boss(sim, boss)
		check(boss.contentId == "B%02d" % i and sim.state.bossId == boss.id, "boss runtime/content IDs distinct B%d" % i)
		check(sim.state.hazards.all(func(h): return h.owner == "boss") and sim.state.hazards.size() > 0, "boss own patterns B%d" % i)
		var old_index: int = sim.state.bossPattern; sim.state.hazards.clear(); boss.hp = 100; Enc.warn_boss(sim, boss)
		check(sim.state.bossStage == 2 and sim.state.bossPattern == old_index + 1, "boss HP transition changes future pattern B%d" % i)
	#24 normals all carry real family state;18 elites do not exceed one scheduled active.
	for i in range(1, 25):
		sim = fresh(); var member := Enc.enemy(sim, i, 0, Vector2(200, 0)); Enc.advance_enemies(sim, 0.05)
		check(member.contentId == "N%02d" % i and member.family == Enc.FAMILIES[(i - 1) / 2], "normal family/variant N%d" % i)
	for i in range(1, 19):
		sim = fresh(); var elite := Enc.enemy(sim, 1, i, Vector2(250, 0)); Enc.advance_enemies(sim, 0.05)
		check(elite.contentId == "X%02d" % i and elite.kind == "elite", "elite behavior X%d" % i)
	sim = fresh(); sim.state.time = 160; sim.state.eliteTimer = 0; Enc.advance_spawns(sim, 0.05)
	check(sim.state.enemies.filter(func(e): return e.kind == "elite").size() == 1, "elite first window")
	sim.state.time = 320; sim.state.eliteTimer = 0; Enc.advance_spawns(sim, 0.05)
	check(sim.state.enemies.filter(func(e): return e.kind == "elite").size() == 1 and sim.state.eliteSkipped.size() == 1, "late elite window skips active elite")
	Enc.spawn_boss(sim)
	check(sim.state.enemies.filter(func(e): return e.kind == "elite").is_empty() and sim.state.chests.is_empty(), "boss entry retires elite without reward")
	#Placed events require approach, every choice is idempotent and frozen.
	sim = fresh(); sim.state.time = 90; Events.place(sim)
	check(sim.state.events.size() == 1 and sim.state.phase == "playing", "event placement does not auto-open modal")
	for i in range(1, 13):
		sim = fresh(); sim.state.xp = 4; sim.state.healBudget = 0.3; event(sim, "E%02d" % i)
		var time_before: float = sim.state.time; sim.tick(0.05)
		check(sim.state.time == time_before and sim.state.phase == "event", "event modal pauses E%d" % i)
		var option := "heal" if i == 1 else ("bolt" if i == 8 else "accept")
		check(sim.choose_event(option), "event accepts valid branch E%d" % i)
		check(not sim.choose_event(option), "event double click rejected E%d" % i)
	sim = fresh(); sim.state.player.hp = 1; event(sim, "E02")
	check(not sim.choose_event() and sim.state.player.hp == 1, "E02 cannot pay fatal cost")
	sim = fresh(); sim.state.xp = 0; event(sim, "E10")
	check(not sim.choose_event() and sim.state.xp == 0, "E10 insufficientXP preserves state")
	sim = fresh(); event(sim, "E03"); sim.choose_event(); sim.state.phase = "paused"; var remaining: float = sim.state.eventTasks[0].remaining; sim.tick(0.05)
	check(sim.state.eventTasks[0].remaining == remaining, "event risk clock pauses")
	sim.state.phase = "playing"; sim.state.eventTasks[0].remaining = 0.01; sim.state.player.hp = 0; sim.tick(0.05)
	check(sim.state.phase == "lost" and sim.state.completedEvents.is_empty(), "fatal event completion cannot reward")
	# Healing procs cannot resurrect a fatal same-frame hazard.
	sim = fresh(); no_spells(sim); sim.state.spells.m22 = 5; sim.state.spells.pulse = 5; sim.state.echoKills = 7; sim.state.player.hp = 1; sim.state.healBudget = 0.3
	var victim := target(sim, Vector2(20, 0)); victim.hp = 0.1
	sim.state.hazards = [{"id": 1, "owner": "boss", "shape": "circle", "kind": "circle", "x": 0.0, "y": 0.0, "radius": 90.0, "warning": 0.0, "active": 1.0, "hit": false, "vx": 0.0, "vy": 0.0, "damage": 1.0}]
	sim.Combat.field(sim, "pulse", Vector2.ZERO, 100, 0.6, {"damage": 1, "context": sim.context("pulse"), "currentRadius": 0.0, "glyphCount": 0})
	sim.tick(0.05)
	check(sim.state.phase == "lost" and sim.state.player.hp == 0, "post-hazard kill-healing cannot revive player")
	#Research rerolls and readability remain separate from default information.
	sim = fresh("C01", "Z01", ["R01", "R20"]); sim._offer_upgrade()
	check(sim.reroll_upgrade(0) and not sim.reroll_upgrade(0), "R01 single candidate reroll once")
	sim.state.phase = "playing"; sim._offer_artifact()
	check(sim.reroll_artifact(0) and not sim.reroll_artifact(0), "R20 chest reroll once")
	sim = fresh("C01", "Z01", ["R15"]); event(sim, "E02"); var hp: float = sim.state.player.hp
	check(sim.choose_event() and sim.state.player.hp == hp and sim.state.eventConfirm, "R15 confirmation delays cost")
	check(sim.choose_event("confirm") and sim.state.player.hp == hp - 1, "R15 confirmation commits once")
	#Resonance ownership and branches are one irreversible opportunity per run.
	sim = fresh(); sim.state.time = 450; sim.state.fusions = ["plasma", "blizzard"]; Events.place(sim)
	sim.state.player.x = sim.state.resonanceMarker.x; sim.state.player.y = sim.state.resonanceMarker.y; Events.offer_nearby(sim)
	check(sim.state.phase == "resonance" and sim.state.resonanceTarget.is_empty(), "multiple fusions require target choice")
	check(sim.choose_resonance("plasma") and sim.state.resonanceChoices.size() == 3, "target reveals three branches")
	check(sim.choose_resonance("F01-R1") and sim.resonance("plasma") == "F01-R1" and not sim.choose_resonance("F01-R2"), "resonance branch once")
	sim = fresh(); sim.state.time = 450; sim.state.fusions = ["hyperion"]; Events.place(sim); sim.state.player.x = sim.state.resonanceMarker.x; Events.offer_nearby(sim)
	check(sim.decline_resonance() and sim.state.resonanceUsed, "decline consumes resonance opportunity")
	for mode in ["practice", "seededchallenge"]:
		sim = Sim.new(42, mode, {"runId": mode}); check(not sim.state.rewardEligible and sim.state.mode == mode, "separate mode/reward flags " + mode)
	print("Release simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
