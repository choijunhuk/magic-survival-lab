extends "res://scripts/simulation.gd"

# Campaign shares the legacy tick lifecycle, but owns every release combat stage.
const Encounters = preload("res://scripts/release_encounters.gd")
const Events = preload("res://scripts/release_events.gd")
const Combat = preload("res://scripts/release_combat.gd")
var artifact_rules: RefCounted
var options: Dictionary = {}

# Only these resolved-hit decorations may be shed under pressure. Unknown types,
# warning geometry, marks, connecting lines and gameplay pulses are retained.
const COSMETIC_EFFECT_TYPES := ["hit", "death", "heal", "explosion", "bolt", "fireball", "frost", "lightning", "beam", "vortex"]
const VISUAL_EFFECT_TARGET := 100

func _init(seed_value: int = 1, mode: String = "campaign", run_options: Dictionary = {}) -> void:
	options = run_options.duplicate(true)
	var file := FileAccess.open("res://data/release_content.json", FileAccess.READ)
	catalog = JSON.parse_string(file.get_as_text()) if file else {}
	artifact_rules = load("res://scripts/artifact_rules.gd").new()
	reset(mode, seed_value, run_options)

func reset(mode: String = "campaign", seed_value: int = 1, run_options: Dictionary = {}) -> void:
	if not run_options.is_empty(): options = run_options.duplicate(true)
	super.reset("quick", seed_value)
	state.mode = mode if mode in ["campaign", "practice", "seededchallenge"] else "campaign"
	state.duration = 900.0 if state.mode != "practice" else 1.0e12
	state.merge({"zoneId": options.get("zoneId", "Z01"), "classId": options.get("classId", "C01"),
		"runId": options.get("runId", "run-%d-%d" % [seed_value, Time.get_ticks_usec()]), "seed": seed_value,
		"rulesVersion": "1.0", "rewardEligible": state.mode == "campaign", "practice": state.mode == "practice",
		"challenge": state.mode == "seededchallenge", "research": options.get("research", []).duplicate(),
		"bossKind": "B01", "bossAt": (2.0 if mode == "practice" else 810.0), "completedEvents": [], "events": [], "activeEvent": {},
		"eventOutcomes": [], "eventChoices": [], "eventScheduleIndex": 0, "eventUsed": [], "eventTasks": [], "eventConfirm": false,
		"eventBonusChoices": 0, "guaranteedSpell": "", "phenomenonReveal": 0, "phenomenonOrderReveal": 0,
		"phenomenonSkip": 0, "phenomenonWarningCost": 0.0, "phenomenonTimer": 0.0, "phenomenonIndex": 0,
		"phenomenonHistory": [], "nextFieldId": 1, "nextAttackId": 1, "fields": [], "seeds": [],
		"enemyProjectiles": [], "pendingEffects": [], "marks": [], "statuses": {}, "artifactRuntime": {},
		"safeTime": 0.0, "seedTimer": 0.0, "lastHitTime": -100.0, "lastDirection": Vector2.RIGHT,
		"returnReadyAt": 0.0, "returnPosition": Vector2.ZERO, "echoKills": 0, "healBudget": 0.0,
		"eliteSpawnPlan": {}, "eliteWindow": 0, "eliteSkipped": [], "resonances": {}, "resonanceUsed": false,
		"resonanceTarget": "", "resonanceChoices": [], "resonanceMarker": {}, "combatLog": [],
		"upgradeRerolls": 1 if options.get("research", []).has("R01") else 0,
		"artifactRerolls": 1 if options.get("research", []).has("R20") else 0,
		"researchHints": {}, "firstXP": true, "nextWarningBonus": 0.0, "bossPattern": 0,
		"bossStage": 1, "bossRecovery": 0.0, "firstBossPattern": true, "orbitCharges": {},
		"orbitPulseAt": 0.0, "deflectionAt": -1.0, "firstSlow": true, "firstIgnite": true,
		"cleansingStones": [], "positionHistory": [], "attackFirstTargets": {}, "spawnSurplus": 0.0, "nextEliteChestBonus": 0, "lastCastTimes": {}, "eventPracticeTime": 0.0, "practiceHazards": [], "practiceAnswers": [], "practiceCorrect": 0, "pendingHealing": []})
	if not _has_catalog("zones", state.zoneId): state.zoneId = "Z01"
	if not _has_catalog("classes", state.classId): state.classId = "C01"
	for zone in catalog.zones:
		if zone.id == state.zoneId: state.bossKind = zone.bossId
	state.spells = {}; state.cooldowns = {}
	for id in catalog.spellIds:
		state.spells[id] = 0; state.cooldowns[id] = 0.0
	for item in catalog.classes:
		if item.id == state.classId: state.spells[item.spellId] = 1
	state.eliteTimer = 160.0
	state.player.invulnerable = 1.0 if research("R05") else 0.0
	for i in range(3):
		var angle := i * TAU / 3.0
		state.cleansingStones.append({"x": cos(angle) * 180, "y": sin(angle) * 180, "progress": 0.0, "cooldown": 0.0, "blocked": 0.0})
	_refresh_research_hints()

func _has_catalog(section: String, id: String) -> bool:
	for item in catalog.get(section, []):
		if item.id == id: return true
	return false

func research(id: String) -> bool:
	return state.research.has(id)

func _refresh_research_hints() -> void:
	state.researchHints = {"compareFrequency": research("R03"), "codexClues": research("R07"),
		"fusionHint": research("R13"), "chestDirection": research("R14"), "confirmEvents": research("R15"),
		"xpDirection": research("R16"), "detailedDeath": research("R17"), "phenomenonMeter": research("R18"),
		"materialFilter": research("R19"), "eventRewardCategory": research("R21") or state.classId == "C06",
		"eventDirection": research("R22"), "resultConnections": research("R23"), "finalSummary": research("R24"),
		"firstPhenomenonPreview": research("R02"), "bossFirstDirection": research("R06"), "elitePreview": research("R08")}

func _power() -> float:
	return 1.0 + state.stats.power * 0.25

func _haste() -> float:
	return minf(1.8, 1.0 + state.stats.haste * 0.12)

func _advance_player(dt: float, input: Vector2) -> void:
	state.healBudget = minf(state.player.maxHp * 0.05, state.healBudget + state.player.maxHp * 0.05 * dt)
	state.player.invulnerable = maxf(0.0, state.player.invulnerable - dt)
	if state.artifacts.has("worldtreeleaf"): heal(0.06 * dt, "worldtreeleaf")
	if state.artifacts.has("aegis") and state.player.shield <= 0:
		state.shieldTimer -= dt
		if state.shieldTimer <= 0: state.player.shield = 1
	var direction := input.limit_length(1.0)
	state.moving = direction.length() > 0
	if direction.length() > 0: state.lastDirection = direction.normalized()
	var mods: Dictionary = modifiers( {"damageKind": "movement"})
	var speed: float = state.player.speed * float(mods.get("move_speed_mult", 1.0))
	if Events.has_task(state, "E11"): speed *= 0.9
	speed = minf(220.0 * 1.6, speed)
	state.player.x += direction.x * speed * dt; state.player.y += direction.y * speed * dt
	state.positionHistory.append({"time": state.time, "x": state.player.x, "y": state.player.y})
	while state.positionHistory.size() > 90: state.positionHistory.pop_front()
	state.safeTime += dt
	if state.spells.m14 > 0:
		var interval := 8.0 if has_fusion("f28") and in_field(_pos(state.player), "glyph") else 12.0
		if state.safeTime >= interval:
			spawn_seed(_pos(state.player), false)
			state.safeTime = 0.0
	for seed in state.seeds.duplicate():
		seed.life -= dt
		if _distance(seed, state.player) < 24.0: collect_seed(seed)
		elif seed.life <= 0: state.seeds.erase(seed)
	artifact_rules.tick(self, dt)
	Events.advance_tasks(self, dt)
	for recovery in state.pendingHealing.duplicate():
		var restored := heal(recovery.amount, recovery.sourceId)
		recovery.amount -= restored
		if recovery.amount <= 0.001 or state.player.hp >= state.player.maxHp: state.pendingHealing.erase(recovery)

func _advance_effects(dt: float) -> void:
	Combat.advance_effects(self, dt)

func _advance_spawns(dt: float) -> void:
	Encounters.advance_spawns(self, dt)

func _advance_enemies(dt: float) -> void:
	Encounters.advance_enemies(self, dt)

func _advance_world(dt: float) -> void:
	Encounters.advance_world(self, dt)
	Events.place(self)

func _advance_attacks(dt: float) -> void:
	Combat.advance(self, dt)

func _resolve_terminal() -> bool:
	if state.mode == "practice":
		if state.player.hp <= 0: state.player.hp = state.player.maxHp
		if state.bossDefeated:
			state.bossDefeated = false; state.bossSpawned = false; state.bossAt = state.time + 3.0
		return false
	var terminal := super._resolve_terminal()
	if terminal:
		state.pendingEffects.clear(); state.enemyProjectiles.clear(); state.hazards.clear()
		state.eventTasks.clear(); state.events.clear(); state.resonanceMarker.clear()
	return terminal

func _offer_pending_choices() -> void:
	Events.settle_tasks(self)
	if state.phase != "playing": return
	for chest in state.chests:
		if _distance(chest, state.player) <= 50:
			state.chests.erase(chest)
			state.eventBonusChoices = int(chest.get("bonusChoices", 0))
			_offer_artifact()
			break
	if state.phase == "playing" and state.xp >= state.xpNeeded: _offer_upgrade()
	if state.phase == "playing": Events.offer_nearby(self)

func learned_count() -> int:
	var count := 0
	for value in state.spells.values():
		if value > 0: count += 1
	return count

func _eligible_upgrade(item: Dictionary) -> bool:
	if state.spells.has(item.id): return state.spells[item.id] < 5 and (state.spells[item.id] > 0 or learned_count() < 6)
	if item.get("kind", "") == "fusion" or item.has("requires"):
		if state.fusions.size() >= 3 or state.fusions.has(item.id): return false
		for id in item.requires:
			if state.spells.get(id, 0) < 3: return false
		return true
	return state.stats.has(item.id)

func _offer_upgrade() -> void:
	state.level += 1; state.xp -= state.xpNeeded; state.xpNeeded = 6 + (state.level - 1) * 3
	state.choices = []
	var available := []
	for item in catalog.upgrades + catalog.fusions:
		if _eligible_upgrade(item): available.append(item)
	if not state.guaranteedSpell.is_empty():
		for item in available:
			if item.id == state.guaranteedSpell: state.choices.append(item); available.erase(item); break
		state.guaranteedSpell = ""
	while state.choices.size() < 3 and not available.is_empty(): state.choices.append(_pick(available))
	state.phase = "upgrade"

func choose_upgrade(id: String) -> bool:
	if state.phase != "upgrade": return false
	var selected: Dictionary = {}
	for item in state.choices:
		if item.id == id: selected = item
	if selected.is_empty() or not _eligible_upgrade(selected): return false
	if selected.has("requires"): state.fusions.append(id)
	elif state.spells.has(id): state.spells[id] += 1
	else:
		state.stats[id] += 1
		if id == "vitality": state.player.maxHp += 2; state.player.hp = minf(state.player.maxHp, state.player.hp + 2)
	state.choices.clear(); state.phase = "playing"
	if state.xp >= state.xpNeeded: _offer_upgrade()
	return true

func _offer_artifact(count: int = 3) -> void:
	var available := []
	for item in catalog.artifacts:
		if artifact_rules.eligible(state, item.id): available.append(item)
	if available.is_empty(): heal(2.0, "empty-chest"); return
	state.artifactChoices = []
	count += int(state.eventBonusChoices); state.eventBonusChoices = 0
	while state.artifactChoices.size() < count and not available.is_empty(): state.artifactChoices.append(_pick_artifact(available))
	state.phase = "artifact"

func choose_artifact(id: String) -> bool:
	if state.phase != "artifact" or not artifact_rules.eligible(state, id): return false
	var offered := false
	for item in state.artifactChoices:
		if item.id == id: offered = true
	if not offered: return false
	state.artifacts.append(id); artifact_rules.on_acquire(self, id)
	if id == "broom": state.player.speed *= 1.15
	if id == "secondheart": state.player.maxHp += 3; state.player.hp = minf(state.player.maxHp, state.player.hp + 3)
	if id == "aegis": state.player.shield = 1
	state.artifactChoices.clear(); state.phase = "playing"
	if state.xp >= state.xpNeeded: _offer_upgrade()
	return true

func reroll_upgrade(index: int) -> bool:
	if state.phase != "upgrade" or state.upgradeRerolls <= 0 or index < 0 or index >= state.choices.size(): return false
	var pool := []
	for item in catalog.upgrades + catalog.fusions:
		var offered := false
		for old in state.choices:
			if old.id == item.id: offered = true
		if not offered and _eligible_upgrade(item): pool.append(item)
	if pool.is_empty(): return false
	state.choices[index] = _pick(pool); state.upgradeRerolls -= 1; return true

func reroll_artifact(index: int) -> bool:
	if state.phase != "artifact" or state.artifactRerolls <= 0 or index < 0 or index >= state.artifactChoices.size(): return false
	var pool := []
	for item in catalog.artifacts:
		var offered := false
		for old in state.artifactChoices:
			if old.id == item.id: offered = true
		if not offered and artifact_rules.eligible(state, item.id): pool.append(item)
	if pool.is_empty(): return false
	state.artifactChoices[index] = _pick_artifact(pool); state.artifactRerolls -= 1; return true

func has_fusion(id: String) -> bool:
	return state.fusions.has(id)

func resonance(id: String) -> String:
	return state.resonances.get(id, "")

func choose_event(option: String = "accept") -> bool:
	return Events.choose(self, option)

func decline_event() -> bool:
	return Events.choose(self, "decline")

func choose_resonance(branch: String) -> bool:
	return Events.choose_resonance(self, branch)

func decline_resonance() -> bool:
	return Events.choose_resonance(self, "decline")

func tick_practice(dt: float) -> void:
	Events.advance_practice(self, dt)

func context(source: String, kind: String = "direct", depth: int = 0) -> Dictionary:
	var school: String = {"plasma": "비전", "blizzard": "냉기", "supernova": "화염", "hyperion": "비전", "f05": "냉기", "f09": "그림자", "f11": "화염", "f12": "봉인", "f15": "비전", "f24": "비전", "f27": "중력", "f30": "폭풍", "f32": "화염", "f35": "화염", "f36": "폭풍", "ignite": "화염"}.get(source, "비전")
	for item in catalog.upgrades:
		if item.id == source: school = item.get("school", "비전"); break
	return {"sourceId": source, "school": school, "damageKind": kind, "depth": depth, "attackId": new_attack_id(), "origin": _pos(state.player), "moving": state.get("moving", false)}

func new_attack_id() -> int:
	var value: int = state.nextAttackId; state.nextAttackId += 1; return value

func emit_event(kind: String, data: Dictionary = {}) -> void:
	var payload := {"type": kind, "kind": kind, "time": state.time, "depth": 0, "zoneId": state.zoneId}
	payload.merge(data, true)
	state.combatLog.append(payload.duplicate())
	if state.combatLog.size() > 100: state.combatLog.pop_front()
	artifact_rules.on_event(self, payload)

func apply_damage(target: Dictionary, amount: float, ctx: Dictionary = {}) -> float:
	var index := _enemy_index(target.get("id", -1))
	if index < 0 or amount <= 0: return 0.0
	var actual: Dictionary = state.enemies[index]
	ctx = ctx.duplicate(); ctx.damage = amount; ctx.targetKind = actual.kind; ctx.targetId = actual.id
	if not ctx.has("attackId"): ctx.attackId = new_attack_id()
	var attack_key := str(ctx.attackId)
	if not ctx.has("firstTarget"): ctx.firstTarget = not state.attackFirstTargets.has(attack_key)
	state.attackFirstTargets[attack_key] = actual.id
	if state.attackFirstTargets.size() > 1000: state.attackFirstTargets.erase(state.attackFirstTargets.keys()[0])
	ctx.targetPosition = _pos(actual); ctx.summon = actual.get("summon", false)
	ctx.ignited = status_time(actual, "ignite") > 0; ctx.slowed = status_time(actual, "slow") > 0
	ctx.vulnerable = status_time(actual, "vulnerable") > 0; ctx.inVeil = in_field(_pos(actual), "veil")
	ctx.zoneId = state.zoneId
	ctx.firstHit = ctx.get("firstHit", not actual.get("wasHit", false))
	ctx.highHpPriority = ctx.get("targetingPolicy", ctx.get("targetPolicy", "")) == "highest_hp" and actual.id == int(ctx.get("priorityTargetId", -1))
	ctx.shockConsumption = ctx.get("school", "") == "폭풍" and status_time(actual, "shock") > 0
	ctx.pierces = ctx.get("projectilePierces", 0)
	ctx.fusionMaterial = false
	for fusion in catalog.fusions:
		if state.fusions.has(fusion.id) and fusion.requires.has(ctx.get("sourceId", "")): ctx.fusionMaterial = true
	actual.wasHit = true
	actual.evadeUntil = state.time + 0.35
	var mods: Dictionary = modifiers( ctx)
	if mods.get("block", false): return 0.0
	var damage: float = amount
	if not ctx.get("precalculatedDamage", false):
		damage = amount * (1.0 + state.stats.power * 0.25 + float(mods.get("damage_add", 0))) * float(mods.get("damage_mult", 1))
		if ctx.get("damageKind", "direct") == "direct" and ctx.vulnerable: damage *= 1.075 if actual.kind == "boss" else 1.15
		elif ctx.get("damageKind", "") == "dot" and ctx.vulnerable: damage *= 1.0375 if actual.kind == "boss" else 1.075
		if ctx.get("school", "") == "폭풍" and status_time(actual, "shock") > 0:
			damage *= 1.0 + (0.1 if actual.kind == "boss" else 0.2) * float(mods.get("shock_bonus_mult", 1.0)); actual.statuses.erase("shock"); ctx.shockedConsumed = true
		if ctx.get("school", "") == "비전" and status_time(actual, "mark") > 0:
			damage += 0.25 if actual.kind == "boss" else 0.5; actual.statuses.erase("mark")
		if state.classId == "C01" and ctx.get("sourceId", "") == "bolt": damage *= 0.9
		if state.classId == "C04" and ctx.get("sourceId", "") == "orbit": damage *= 0.9
		if state.classId == "C05" and actual.kind == "boss": damage *= 0.9
		if actual.get("shield", 0.0) > 0: damage *= 0.5
		if actual.get("frontalShield", false) and (ctx.get("origin", _pos(state.player)) - _pos(actual)).normalized().dot(actual.get("facing", Vector2.LEFT)) > 0.2: damage *= 0.5
		if actual.get("family", "") == "shield":
			var facing: Vector2 = actual.get("facing", Vector2.LEFT)
			var front: bool = (ctx.get("origin", _pos(state.player)) - _pos(actual)).normalized().dot(facing) > 0.2
			if front != (int(actual.get("variant", 1)) % 2 == 0): damage *= 0.55
		if actual.get("family", "") == "absorb" and not actual.get("absorbed", false) and ctx.get("projectile", false) and amount <= 5:
			actual.absorbed = true; emit_event("control", {"subtype": "enemy_absorb", "targetId": actual.id}); return 0.0
		if actual.kind == "boss" and state.bossKind == "B03" and state.bossRecovery > 0: damage *= 1.5
	damage = maxf(0.05, damage)
	actual.hp -= damage
	ctx.damage = damage
	_effect("hit", actual.x, actual.y, 0.15)
	emit_event("hit", ctx)
	if int(ctx.get("depth", 0)) == 0: Combat.on_hit(self, actual, ctx)
	if actual.hp <= 0 and _enemy_index(actual.id) >= 0:
		state.enemies.remove_at(_enemy_index(actual.id)); state.kills += 1
		if actual.kind == "boss": state.bossDefeated = true
		elif not actual.get("summon", false):
			state.gems.append({"x": actual.x, "y": actual.y, "value": 4 if actual.kind == "elite" else 1, "radius": 6})
		if actual.kind == "elite":
			state.chests.append({"id": state.nextChestId, "x": actual.x, "y": actual.y, "bonusChoices": actual.get("chestBonus", 0)}); state.nextChestId += 1
		emit_event("kill", ctx)
		Combat.on_kill(self, actual, ctx)
		if ctx.get("daggerExecute", false):
			var execution := ctx.duplicate(); execution.subtype = "execute"; execution.daggerExecute = true
			emit_event("control", execution)
		Encounters.on_kill(self, actual)
	return damage

func _hurt_enemy(enemy: Dictionary, damage: float) -> void:
	apply_damage(enemy, damage, context("unknown"))

func apply_status(target: Dictionary, tag: String, duration: float, strength: float = 1.0) -> void:
	if _enemy_index(target.get("id", -1)) < 0: return
	if tag == "root":
		if target.kind == "boss": tag = "slow"; duration = 0.2; strength = 0.125
		elif float(target.get("rootImmuneUntil", 0.0)) > state.time: return
		else: target.rootImmuneUntil = state.time + 4.0
	if not target.has("statuses"): target.statuses = {}
	if tag == "slow":
		if state.classId == "C03" and state.firstSlow: duration += 0.4; state.firstSlow = false
		if has_fusion("blizzard"):
			if resonance("blizzard") == "F02-R1": duration *= 1.4
			if resonance("blizzard") == "F02-R2": duration *= 0.7
	if tag == "ignite" and state.classId == "C02" and state.firstIgnite: duration += 1.0; state.firstIgnite = false
	var status_mods: Dictionary = modifiers({"sourceId": "status", "status": tag, "targetId": target.id})
	duration += float(status_mods.get("duration_add", 0))
	if tag == "vulnerable": duration = minf(4.0, duration)
	var old: Dictionary = target.statuses.get(tag, {})
	target.statuses[tag] = {"remaining": maxf(duration, float(old.get("remaining", 0))), "strength": maxf(strength, float(old.get("strength", 0))), "nextTick": old.get("nextTick", 1.0)}
	emit_event("control", {"subtype": tag, "targetId": target.id, "targetKind": target.kind, "targetPosition": _pos(target), "shockApplied": tag == "shock", "slowApplied": tag == "slow"})

func status_time(target: Dictionary, tag: String) -> float:
	return float(target.get("statuses", {}).get(tag, {}).get("remaining", 0.0))

func extend_status(target_id: int, tag: String, seconds: float, max_duration: float) -> void:
	var index := _enemy_index(target_id)
	if index < 0 or status_time(state.enemies[index], tag) <= 0: return
	var status: Dictionary = state.enemies[index].statuses[tag]
	status.remaining = minf(max_duration, status.remaining + seconds)

func _hurt_player(damage: float) -> void:
	hurt_player(damage, {"sourceId": "contact", "damageKind": "incoming", "depth": 0})

func hurt_player(damage: float, ctx: Dictionary = {}) -> void:
	if state.player.invulnerable > 0 or damage <= 0: return
	ctx = ctx.duplicate(); ctx.damage = damage; ctx.damageKind = "incoming"
	ctx.aegisAvailable = state.player.shield > 0
	ctx.m24Available = state.spells.m24 > 0 and state.time >= state.returnReadyAt
	ctx.direct = not ctx.get("damageOverTime", false)
	ctx.eliteNearby = false
	for enemy in state.enemies:
		if enemy.kind == "elite" and _distance(enemy, state.player) < 180: ctx.eliteNearby = true
	var mods: Dictionary = modifiers( ctx)
	var incoming: float = damage * float(mods.get("incoming_mult", 1.0))
	if ctx.direct: incoming = maxf(1.0, incoming)
	# Fatal return precedes artifact saves; ordinary aegis precedes the final A096 save.
	if incoming >= state.player.hp and state.spells.m24 > 0 and state.time >= state.returnReadyAt:
		var previous := _pos(state.player)
		state.player.x -= state.lastDirection.x * 85; state.player.y -= state.lastDirection.y * 85
		state.player.invulnerable = 0.8; state.returnReadyAt = state.time + 100.0 - state.spells.m24 * 10.0
		emit_event("defense_used", {"sourceId": "m24", "damage": incoming, "targetPosition": previous})
		emit_event("control", {"sourceId": "m24", "dodged": true, "targetPosition": previous})
		if has_fusion("f23"): state.orbitOutUntil = state.time + 1.0
		if has_fusion("f35"): damage_radius(previous, 75, 3.0, context("f35", "derived", 1))
		return
	if mods.get("block", false):
		emit_event("defense_used", {"sourceId": mods.get("defense_source", "artifact"), "damage": incoming}); return
	if state.player.shield > 0:
		state.player.shield = 0; state.shieldTimer = 15.0
		emit_event("defense_used", {"sourceId": "aegis", "damage": incoming})
	else:
		var reduction: float = float(mods.get("incoming_flat_reduction", 0))
		if reduction > 0:
			incoming = maxf(0, incoming - reduction)
			emit_event("defense_used", {"sourceId": mods.get("defense_source", "a096"), "damage": reduction})
		var hp: float = maxf(0.0, state.player.hp - incoming)
		if hp <= 0 and mods.get("save_hp") != null:
			hp = float(mods.save_hp); emit_event("defense_used", {"sourceId": mods.get("defense_source", "artifact"), "damage": incoming})
		state.player.hp = hp
	state.safeTime = 0.0; state.lastHitTime = state.time; state.player.invulnerable = 0.65
	state.nextWarningBonus = 0.15 if research("R11") else 0.0
	ctx.damage = incoming; emit_event("player_hit", ctx)
	state.lastDamageSource = ctx.get("sourceId", "unknown")
	state.deathDetail = {"sourceId": state.lastDamageSource, "attackId": ctx.get("attackId", -1), "kind": ctx.get("hazard", "projectile" if ctx.get("projectile", false) else "contact"), "damage": incoming, "time": state.time, "targetKind": ctx.get("targetKind", ""), "waveNumber": ctx.get("waveNumber", 0), "patternId": ctx.get("patternId", ""), "phenomenonId": ctx.get("phenomenonId", ""), "hazardId": ctx.get("hazardId", -1), "ownerId": ctx.get("ownerId", -1)}
	_effect("hit", state.player.x, state.player.y, 0.3)

func heal(amount: float, source_id: String) -> float:
	if amount <= 0 or state.player.hp <= 0: return 0.0
	var mods: Dictionary = modifiers({"sourceId": source_id, "damageKind": "heal", "healingSchool": "생명", "seedAge": state.get("collectingSeedAge", 0)})
	var actual := minf(amount * float(mods.get("heal_mult", 1.0)), state.player.maxHp - state.player.hp)
	if source_id not in ["empty-chest"]:
		actual = minf(actual, state.healBudget); state.healBudget -= actual
	state.player.hp += actual
	if actual > 0:
		_effect("heal", state.player.x, state.player.y, 0.5)
		emit_event("control", {"sourceId": source_id, "healed": true, "subtype": "heal", "healPosition": _pos(state.player), "damage": actual})
	return actual

func spawn_seed(position: Vector2, extra: bool = false) -> void:
	if state.seeds.size() >= 12: state.seeds.pop_front()
	emit_event("control", {"sourceId": "m14", "seedSpawned": true, "subtype": "seed_spawned", "targetPosition": position, "extra": extra})
	state.seeds.append({"x": position.x, "y": position.y, "life": 12.0, "created": state.time, "extra": extra, "value": 0.4 + state.spells.m14 * 0.2})

func collect_seed(seed: Dictionary) -> void:
	if not state.seeds.has(seed): return
	state.seeds.erase(seed); state.collectingSeedAge = state.time - seed.created; heal(seed.value, "m14"); state.collectingSeedAge = 0
	emit_event("seed_collected", {"sourceId": "m14", "seedAge": state.time - seed.created, "targetPosition": _pos(seed), "extra": seed.extra})

func pull_gems(radius: float) -> void:
	for gem in state.gems:
		if _distance(gem, state.player) <= (420.0 if radius <= 0 else minf(radius, 420)):
			var direction := (_pos(gem) - _pos(state.player)).normalized()
			gem.x = state.player.x + direction.x * 25; gem.y = state.player.y + direction.y * 25

func spawn_heal_field(position: Vector2, duration: float) -> void:
	Combat.field(self, "heal", position, 55, duration, {"sourceId": "heal-field"})

func absorb_projectiles(center: Vector2, radius: float, limit: int) -> int:
	var count := 0
	for projectile in state.enemyProjectiles.duplicate():
		if count >= limit: break
		if projectile.get("beam", false): continue
		if center.distance_to(_pos(projectile)) <= radius:
			state.enemyProjectiles.erase(projectile); count += 1
	return count

func delay_enemy_cast(target_id: int, seconds: float) -> void:
	var index := _enemy_index(target_id)
	if index < 0: return
	var enemy: Dictionary = state.enemies[index]
	if enemy.kind == "boss" or enemy.get("castWarning", 0.0) <= 0: return
	if enemy.get("castDelayed", false):
		if seconds >= 1.0 or enemy.get("artifactCastExtended", false): return
		enemy.artifactCastExtended = true
		enemy.castWarning += seconds
		return
	enemy.castWarning += seconds; enemy.castDelayed = true; enemy.delayedUntil = state.time + seconds + 2.0
	emit_event("control", {"sourceId": "m23", "subtype": "cast_delay", "targetId": enemy.id, "targetKind": enemy.kind, "sealDelayed": true, "eliteCastDelayed": enemy.kind == "elite"})

func cancel_enemy_dash(target_id: int) -> void:
	var index := _enemy_index(target_id)
	if index < 0 or state.enemies[index].kind == "boss": return
	state.enemies[index].dashTime = 0.0; state.enemies[index].dashWarning = 0.0; state.enemies[index].dashCancelledThisStep = true

func damage_radius(center: Vector2, radius: float, amount: float, ctx: Dictionary) -> void:
	for enemy in state.enemies.duplicate():
		if center.distance_to(_pos(enemy)) <= radius + enemy.radius: apply_damage(enemy, amount, ctx)

func schedule_artifact_effect(delay: float, kind: String, data: Dictionary) -> void:
	if state.pendingEffects.size() >= 100: return
	state.pendingEffects.append({"delay": maxf(delay, 0.0), "kind": kind, "data": data.duplicate(true)})
	var point: Vector2 = data.get("position", data.get("center", _pos(state.player)))
	_effect("artifact_warning", point.x, point.y, maxf(0.1, delay), {"radius": data.get("radius", 50)})

func in_field(point: Vector2, kind: String) -> bool:
	for item in state.fields:
		if item.kind == kind and point.distance_to(_pos(item)) <= item.radius: return true
	return false

func _collect_gems(dt: float) -> void:
	var mods: Dictionary = modifiers( {"damageKind": "pickup"})
	var radius: float = (52 + state.stats.magnet * 28 + float(mods.get("pickup_radius_add", 0))) * float(mods.get("pickup_radius_mult", 1))
	if research("R04"): radius *= 1.08
	if state.classId == "C05": radius *= 1.15
	if Events.has_task(state, "E06"): radius *= 0.8
	for gem in state.gems.duplicate():
		var distance := _distance(gem, state.player)
		if distance < 22:
			var xp: float = gem.value * float(mods.get("xp_mult", 1.0)) * (0.9 if state.classId == "C06" else 1.0)
			if state.firstXP and research("R10"): xp *= 1.05
			xp = minf(xp, gem.value * 1.75)
			state.firstXP = false; state.xp += xp; state.gems.erase(gem)
		elif distance < radius:
			var movement := (_pos(state.player) - _pos(gem)).normalized() * minf(distance, 420 * dt)
			gem.x += movement.x; gem.y += movement.y

func orbit_position(index: int) -> Vector2:
	var count: int = mini(state.spells.orbit, 8)
	var extra: int = int(modifiers({"sourceId": "orbit", "projectileCount": count}).get("count_add", 0)) if count > 0 else 0
	count = mini(8, count + extra)
	var angle: float = state.time * 2.4 + index * TAU / maxi(1, count)
	var radius := 105.0 if has_fusion("hyperion") else 72.0
	if state.classId == "C04": radius *= 1.1
	if resonance("hyperion") == "F04-R1": radius *= 1.4
	if resonance("hyperion") == "F04-R2": radius *= 0.75
	if float(state.get("orbitOutUntil", 0)) > state.time: radius += 70
	radius *= float(modifiers({"sourceId": "orbit"}).get("radius_mult", 1))
	return _pos(state.player) + Vector2.from_angle(angle) * radius

func modifiers(ctx: Dictionary) -> Dictionary:
	ctx = ctx.duplicate()
	ctx.moving = state.get("moving", false)
	ctx.projectileNearby = false
	for projectile in state.get("enemyProjectiles", []):
		if not projectile.get("beam", false) and _distance(projectile, state.player) < 100: ctx.projectileNearby = true; break
	ctx.inTelegraph = false
	for hazard in state.get("hazards", []):
		if hazard.warning > 0 and Encounters.contains(hazard, _pos(state.player), state.player.radius): ctx.inTelegraph = true; break
	var out: Dictionary = artifact_rules.modifiers(state, ctx)
	if state.artifacts.has("magicwand"): out.damage_add += 0.2
	if state.artifacts.has("blackcat"): out.cooldown_mult /= 1.12
	if state.artifacts.has("radar"): out.pickup_radius_add += 80
	if state.artifacts.has("battery") and ctx.get("sourceId", "") == "lightning": out.count_add += 1
	if state.artifacts.has("ruby") and ctx.get("sourceId", "") in ["fireball", "meteor"]: out.damage_add += 0.3
	if state.artifacts.has("snowflakecrown") and ctx.get("status", "") == "slow": out.duration_add += 1
	if state.artifacts.has("circularsawblade") and ctx.get("sourceId", "") == "orbit": out.damage_add += 0.25
	if state.artifacts.has("sapphire"): out.xp_mult *= 1.25
	return out

func reroll_artifact_upgrade() -> bool:
	if state.phase != "upgrade" or not state.artifacts.has("a072") or state.artifactRuntime.get("a072Used", false): return false
	var replacements := []
	for old in state.choices:
		var pool := []
		for item in catalog.fusions if old.has("requires") else catalog.upgrades:
			if _eligible_upgrade(item) and item.id != old.id and not replacements.any(func(x): return x.id == item.id): pool.append(item)
		if pool.is_empty(): replacements.append(old)
		else: replacements.append(_pick(pool))
	state.choices = replacements; state.artifactRuntime.a072Used = true; return true

func choose_practice_answer(shape: String) -> bool:
	return Events.choose_practice_answer(self, shape)

func grant_heal(amount: float, source_id: String) -> void:
	var restored := heal(amount, source_id)
	if restored < amount and state.player.hp < state.player.maxHp: state.pendingHealing.append({"amount": amount - restored, "sourceId": source_id})

func presentation_modifiers() -> Dictionary:
	var elite: Dictionary = modifiers({"eliteWarning": true})
	var event_mods: Dictionary = modifiers({"eventIndicator": true})
	var chest: Dictionary = modifiers({"chestIndicator": true})
	return {"veilOutline": elite.get("veil_outline", false), "chestMarkerRange": 360 + float(chest.get("marker_range_add", 0)), "eventMarkerRange": 360 + float(event_mods.get("marker_range_add", 0)), "eventAdvance": float(event_mods.get("event_warning_advance", 0))}

func _effect(kind: String, x: float, y: float, life: float, extra: Dictionary = {}) -> void:
	if COSMETIC_EFFECT_TYPES.has(kind) and state.effects.size() >= VISUAL_EFFECT_TARGET:
		var oldest_cosmetic := _oldest_cosmetic_effect()
		if oldest_cosmetic < 0: return
		state.effects.remove_at(oldest_cosmetic)
	super._effect(kind, x, y, life, extra)
	# Essential signals can exceed the pressure-scene target. They never compete
	# with damage/status/projectile logic, and they never evict one another.
	while state.effects.size() > VISUAL_EFFECT_TARGET:
		var oldest_cosmetic := _oldest_cosmetic_effect()
		if oldest_cosmetic < 0: break
		state.effects.remove_at(oldest_cosmetic)

func _oldest_cosmetic_effect() -> int:
	for i in range(state.effects.size()):
		if COSMETIC_EFFECT_TYPES.has(state.effects[i].get("type", "")): return i
	return -1

func _pick_artifact(available: Array) -> Dictionary:
	var groups := {}
	var weights := {"일반": 70.0, "희귀": 25.0, "전설": 5.0}
	for item in available:
		var rarity: String = item.get("rarity", "일반")
		if not groups.has(rarity): groups[rarity] = []
		groups[rarity].append(item)
	var total := 0.0
	for rarity in groups: total += float(weights.get(rarity, 1))
	var roll := rng.randf() * total
	for rarity in groups:
		roll -= float(weights.get(rarity, 1))
		if roll <= 0:
			var pool: Array = groups[rarity]
			var chosen: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
			available.erase(chosen); return chosen
	return _pick(available)

func cast_interval(spell_id: String) -> float:
	var bases := {"bolt":0.65,"orbit":0.45,"lightning":2.7,"frost":4.0,"fireball":3.0,"vortex":5.0,"meteor":6.0,"pulse":3.3,"m09":4.2,"m10":2.5,"m11":4.5,"m12":5.5,"m13":1.8,"m14":12.0,"m15":4.5,"m16":2.8,"m17":2.7,"m18":5.0,"m19":4.0,"m20":2.5,"m21":5.0,"m23":6.0,"m24":100.0}
	if not bases.has(spell_id): return -1.0
	if spell_id == "m14": return 8.0 if has_fusion("f28") and in_field(_pos(state.player), "glyph") else 12.0
	if spell_id == "m24": return 100.0 - maxi(1, state.spells.m24) * 10.0
	if spell_id == "orbit": return 0.45
	var floor_value: float = {"lightning":0.5,"frost":1.0,"fireball":0.7,"vortex":1.5,"meteor":2.0,"pulse":0.8,"m09":1.2}.get(spell_id, 0.4)
	return Combat.interval(self, spell_id, bases[spell_id], floor_value)

func upgrade_frequency(id: String) -> Dictionary:
	if state.spells.has(id):
		var level_value: int = state.spells[id]
		if id == "m22": return {"currentInterval": -1.0, "nextInterval": -1.0, "unit": "kills", "currentCount": 13 - maxi(1, level_value), "nextCount": 13 - mini(5, level_value + 1), "conditional": true}
		var interval := cast_interval(id)
		var next := 100.0 - mini(5, level_value + 1) * 10 if id == "m24" else interval
		return {"currentInterval": interval if level_value > 0 else -1.0, "nextInterval": next, "unit": "seconds", "conditional": id in ["m14", "m20", "m23", "m24"], "targetRequired": id not in ["m11", "m14", "m16", "m18", "m20", "m24"]}
	for item in catalog.fusions:
		if item.id == id:
			var materials := []
			for spell in item.requires: materials.append({"id": spell, "currentInterval": cast_interval(spell), "nextInterval": cast_interval(spell)})
			return {"unit": "fusion", "materials": materials, "conditional": true}
	return {"unit": "stat", "conditional": false}
