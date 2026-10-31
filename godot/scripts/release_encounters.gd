extends RefCounted

const FAMILIES := ["walk", "dash", "shield", "shoot", "split", "swarm", "lure", "support", "delay", "barrier", "absorb", "stealth"]
const ELITE_FAMILY := [0, 1, 5, 3, 2, 6, 8, 9, 10, 1, 3, 7, 11, 2, 5, 8, 9, 10]
const ELITE_WINDOWS := [160.0, 320.0, 490.0, 660.0]
const PHENOMENON_START := {"Z01": 75.0, "Z02": 120.0, "Z03": 150.0, "Z04": 180.0, "Z05": 120.0, "Z06": 180.0}

static func enemy(sim, normal_id: int, elite_id: int = 0, point: Vector2 = Vector2.INF, summon: bool = false) -> Dictionary:
	if sim.state.enemies.size() >= 200: return {}
	var family_index: int = (normal_id - 1) / 2
	if elite_id > 0: family_index = ELITE_FAMILY[elite_id - 1]
	var angle: float = sim.rng.randf() * TAU
	if point == Vector2.INF: point = sim._pos(sim.state.player) + Vector2.from_angle(angle) * (480 + sim.rng.randf() * 150)
	var hp: float = 3.0 * (1 + sim.state.time / 240.0) * (7 if elite_id > 0 else 1)
	var speed := 75.0
	if family_index == 1: speed = 85
	if family_index == 2: hp *= 1.3; speed = 60
	if family_index == 5: hp *= 0.75; speed = 105
	if family_index == 3: speed = 55
	if summon: hp *= 0.4
	var value := {"id": sim.state.nextEnemyId, "x": point.x, "y": point.y, "hp": hp, "maxHp": hp,
		"kind": "elite" if elite_id > 0 else "normal", "contentId": "X%02d" % elite_id if elite_id > 0 else "N%02d" % normal_id,
		"family": FAMILIES[family_index], "variant": normal_id, "eliteVariant": elite_id, "radius": 23 if elite_id > 0 else (10 if family_index == 5 else 15),
		"speed": speed, "damage": 1.0, "slow": 0.0, "orbitHitUntil": 0.0, "statuses": {}, "facing": Vector2.LEFT,
		"castTimer": 2.0 + sim.rng.randf(), "castWarning": 0.0, "castDelayed": false, "castTarget": Vector2.ZERO,
		"dashWarning": 0.0, "dashTime": 0.0, "dashDirection": Vector2.ZERO, "actionUsed": false, "summon": summon,
		"shield": 0.0, "hidden": 0.0, "specialTimer": 3.0, "summoned": 0}
	sim.state.nextEnemyId += 1; sim.state.enemies.append(value)
	return value

static func advance_spawns(sim, dt: float) -> void:
	var s: Dictionary = sim.state
	if s.time >= s.bossAt and not s.bossSpawned: spawn_boss(sim)
	s.spawnTimer -= dt
	if s.spawnTimer <= 0:
		var count: int = mini(7, 1 + int(s.time / 70))
		if sim.Events.has_task(s, "E03"):
			s.spawnSurplus += count * 0.2
			var extra: int = int(floor(s.spawnSurplus))
			s.spawnSurplus -= extra; count += extra
		if not boss_hazards(s).is_empty(): count = mini(count, 2)
		for i in range(count):
			var candidates := [1, 2, 3, 4, 11, 12]
			if s.time >= 180: candidates += [5, 6, 7, 8, 13, 14, 15, 16]
			if s.time >= 420: candidates += [9, 10, 17, 18, 19, 20, 21, 22, 23, 24]
			var id: int = candidates[sim.rng.randi_range(0, candidates.size() - 1)]
			if s.zoneId == "Z06" and s.time >= s.bossAt - 10 and id in [3, 4]: id = 1
			var member := enemy(sim, id)
			if id == 11 and not member.is_empty():
				for offset in [Vector2(25, 15), Vector2(-25, 15)]: enemy(sim, 11, 0, sim._pos(member) + offset)
		s.spawnTimer = maxf(0.4, 1.3 - s.time / 900.0)
	if s.eliteWindow >= ELITE_WINDOWS.size() or s.time >= s.bossAt - 30: return
	s.eliteTimer -= dt
	var preview: float = (2.0 if sim.research("R08") else 0.0) + float(sim.modifiers({"eliteWarning": true}).get("warning_advance", 0.0)) + float(s.get("nextEliteWarningBonus", 0.0))
	# Reserve identically with/without preview perks; rendering never rerolls gameplay.
	if s.eliteTimer <= 4.0 and s.eliteSpawnPlan.is_empty(): reserve_elite(sim)
	if s.eliteTimer <= preview and not s.eliteSpawnPlan.is_empty():
		s.researchHints.elitePreviewPosition = s.eliteSpawnPlan.position
		s.researchHints.elitePreviewId = "X%02d" % int(s.eliteSpawnPlan.eliteId)
		s.researchHints.elitePreviewAt = s.time + maxf(0, s.eliteTimer)
	if s.eliteTimer <= 0:
		var active := false
		for item in s.enemies:
			if item.kind == "elite": active = true
		if active: s.eliteSkipped.append({"window": s.eliteWindow, "reason": "active-elite"})
		else:
			if s.eliteSpawnPlan.is_empty(): reserve_elite(sim)
			var point: Vector2 = s.eliteSpawnPlan.position
			if point.distance_to(sim._pos(s.player)) < 180 or hazard_contains_owner(sim, point, "map"):
				# A player may walk into a reserved warning. Replan with a full warning,
				# instead of spawning a body on top of them or lying about its position.
				s.eliteSpawnPlan.clear(); reserve_elite(sim); s.eliteTimer = maxf(0.8, preview)
				s.researchHints.elitePreviewPosition = s.eliteSpawnPlan.position
				return
			var elite := enemy(sim, 1, s.eliteSpawnPlan.eliteId, point)
			if not elite.is_empty(): elite.chestBonus = s.nextEliteChestBonus; s.nextEliteChestBonus = 0
		s.eliteSpawnPlan.clear(); s.researchHints.erase("elitePreviewPosition"); s.researchHints.erase("elitePreviewAt")
		s.nextEliteWarningBonus = 0.0
		s.eliteWindow += 1
		s.eliteTimer = ELITE_WINDOWS[s.eliteWindow] - s.time if s.eliteWindow < ELITE_WINDOWS.size() else INF

static func reserve_elite(sim) -> void:
	var s: Dictionary = sim.state
	var zone_index: int = int(s.zoneId.substr(1)) - 1
	var elite_id: int = zone_index * 3 + sim.rng.randi_range(1, 3)
	var angle: float = sim.rng.randf() * TAU
	var point: Vector2 = sim._pos(s.player) + Vector2.from_angle(angle) * 310
	for h in s.hazards:
		if point.distance_to(sim._pos(h)) < float(h.radius) + 60: point = sim._pos(s.player) + Vector2.from_angle(angle + PI) * 340
	s.eliteSpawnPlan = {"eliteId": elite_id, "position": point, "window": s.eliteWindow}

static func advance_enemies(sim, dt: float) -> void:
	for item in sim.state.enemies.duplicate():
		if sim._enemy_index(item.id) < 0: continue
		if item.kind == "boss": move_boss(sim, item, dt); continue
		var point: Vector2 = sim._pos(item)
		item.previousPosition = point; item.dashingThisStep = float(item.get("dashTime", 0)) > 0; item.dashCancelledThisStep = false
		var delta: Vector2 = sim._pos(sim.state.player) - point
		var desired: float = delta.angle()
		var current: float = item.get("facing", Vector2.LEFT).angle()
		var turn: float = clampf(wrapf(desired - current, -PI, PI), -1.2 * dt, 1.2 * dt)
		item.facing = Vector2.from_angle(current + turn)
		var factor := 1.0
		if float(item.get("supportSpeedUntil", 0)) > sim.state.time: factor *= 1.15
		if sim.status_time(item, "slow") > 0: factor -= float(item.statuses.slow.strength)
		if sim.status_time(item, "root") > 0: factor = 0
		if item.get("shield", 0) > 0: item.shield = maxf(0, item.shield - dt)
		var movement: Vector2 = delta.normalized() * item.speed * factor * dt
		var variant: int = item.variant
		match item.family:
			"walk":
				if variant == 2 and float(item.get("evadeUntil", 0)) > sim.state.time: movement = movement.orthogonal()
			"dash":
				item.specialTimer -= dt
				if item.dashWarning > 0:
					item.dashWarning -= dt; movement = Vector2.ZERO
					if item.dashWarning <= 0: item.dashTime = 0.5
				elif item.dashTime > 0:
					item.dashTime -= dt
					if variant % 2 == 0 and not item.get("turned", false) and item.dashTime < 0.25:
						item.dashDirection = item.dashDirection.rotated(0.45); item.turned = true
					var dash_factor := 0.5 if float(item.get("glyphDashSlow", 0)) > sim.state.time else 1.0
					movement = item.dashDirection * 300 * dash_factor * dt
					if item.eliteVariant == 2: enemy_hazard(sim, item, "circle", point, 24, 0.8, 0.3)
				elif item.specialTimer <= 0 and boss_hazards(sim.state).is_empty():
					item.dashWarning = 1.0; item.dashDirection = delta.normalized(); item.specialTimer = 5; item.turned = false
					sim._effect("enemy_dash_warning", point.x, point.y, 1, {"toX": point.x + item.dashDirection.x * 150, "toY": point.y + item.dashDirection.y * 150, "radius": 18})
			"shoot", "delay", "barrier":
				if delta.length() < 250: movement *= 0.2
				advance_cast(sim, item, dt)
			"swarm":
				if variant % 2 == 0:
					for other in sim.state.enemies:
						if other.id != item.id and sim._distance(other, item) < 70: movement *= 1.4; break
			"lure":
				if variant % 2 == 0 and delta.length() < 160: movement *= -0.8
				if item.eliteVariant == 6 and int(sim.state.time) % 6 < 2: movement *= -1
			"support":
				item.specialTimer -= dt
				if item.specialTimer <= 0 and not item.actionUsed:
					item.actionUsed = true
					for other in sim.state.enemies:
						if other.kind == "boss" or sim._distance(item, other) > 130: continue
						if variant % 2 == 1: other.shield = 2.0
						else: other.supportSpeedUntil = sim.state.time + 2.0
			"absorb":
				if variant % 2 == 0 and sim.in_field(point, "vortex"): sim.apply_status(item, "vulnerable", 2)
			"stealth":
				item.specialTimer -= dt
				if item.specialTimer <= 0 and item.hidden <= 0:
					item.hidden = 1.2; item.specialTimer = 5
					item.reappearAt = sim._pos(sim.state.player) + delta.normalized().orthogonal() * (140 if variant % 2 == 0 else -140)
					sim._effect("reappear_warning", item.reappearAt.x, item.reappearAt.y, 1.2, {"radius": 25})
				if item.hidden > 0:
					item.hidden -= dt; movement = Vector2.ZERO
					if item.hidden <= 0: item.x = item.reappearAt.x; item.y = item.reappearAt.y
		elite_behavior(sim, item, dt)
		# Existing glyphs intercept a dash segment before contact damage resolves.
		# The later field stage also observes short dashes created by external fixtures.
		if item.dashingThisStep or float(item.get("dashTime", 0)) > 0:
			for ground in sim.state.fields:
				if ground.kind != "glyph" or ground.life <= 0: continue
				var center: Vector2 = sim._pos(ground)
				if Geometry2D.get_closest_point_to_segment(center, point, point + movement).distance_to(center) <= ground.radius + item.radius:
					sim.emit_event("control", {"sourceId": ground.sourceId, "dashInGlyph": true, "targetId": item.id, "targetKind": item.kind, "targetPosition": point})
					if item.dashCancelledThisStep: movement = Vector2.ZERO; break
		item.x += movement.x; item.y += movement.y
		if sim._distance(item, sim.state.player) < item.radius + sim.state.player.radius and item.hidden <= 0:
			sim.hurt_player(item.damage, {"sourceId": item.contentId, "targetKind": item.kind, "attackId": item.id, "depth": 0})

static func advance_cast(sim, item: Dictionary, dt: float) -> void:
	if item.castWarning > 0:
		item.castWarning -= dt
		if item.castWarning <= 0:
			var target: Vector2 = item.castTarget
			if item.family == "shoot":
				var direction: Vector2 = (target - sim._pos(item)).normalized()
				var count := 3 if item.variant % 2 == 0 or item.eliteVariant == 11 else 1
				for i in range(count): bullet(sim, item, direction.rotated((i - (count - 1) / 2.0) * 0.22))
			elif item.family == "delay":
				enemy_hazard(sim, item, "circle", target, 42, 0.8, 0.3)
				if item.variant % 2 == 0 or item.eliteVariant == 7: enemy_hazard(sim, item, "circle", target + Vector2.RIGHT * 70, 42, 1.3, 0.3)
			else:
				if boss_hazards(sim.state).is_empty(): enemy_hazard(sim, item, "ray", target, 15, 1, 0.8, {"angle": 0.0 if item.variant % 2 else PI * 0.5, "length": 120, "width": 15})
			item.castTimer = 3.0; item.castDelayed = false; item.artifactCastExtended = false
	else:
		item.castTimer -= dt
		if item.castTimer <= 0:
			item.castWarning = 1.0; item.castTarget = sim._pos(sim.state.player); item.castDelayed = false
			sim._effect("enemy_cast_warning", item.castTarget.x, item.castTarget.y, 1, {"radius": 30, "ownerId": item.id})

static func elite_behavior(sim, item: Dictionary, dt: float) -> void:
	if item.kind != "elite": return
	var id: int = item.eliteVariant
	item.eliteClock = float(item.get("eliteClock", 0)) + dt
	match id:
		1: item.frontalShield = fmod(item.eliteClock, 5) < 1
		3, 15:
			if not item.actionUsed:
				item.actionUsed = true
				for i in range(4 if id == 3 else 8):
					if item.summoned >= 8: break
					enemy(sim, 11, 0, sim._pos(item) + (Vector2(-70, 0) if i < 4 else Vector2(70, 0)) + Vector2.from_angle(i * TAU / 4) * 25, true); item.summoned += 1
		4:
			if fmod(item.eliteClock, 5) < dt:
				for angle in [-0.25, 0.25]: enemy_hazard(sim, item, "ray", sim._pos(item), 12, 1.1, 0.3, {"angle": item.facing.angle() + angle, "length": 350, "width": 12})
		5, 14:
			item.variant = 5 if int(item.eliteClock / 3) % 2 == 0 else 6
		8, 17:
			if fmod(item.eliteClock, 5) < dt and boss_hazards(sim.state).is_empty(): enemy_hazard(sim, item, "ray", sim._pos(sim.state.player) + Vector2(0, 75), 14, 1.0, 0.5, {"angle": 0.0, "length": 140, "width": 14})
		9: item.absorbed = item.get("absorbed", false)
		10:
			if item.dashTime > 0: item.dashDirection = item.dashDirection.rotated(dt * 0.8)
		12:
			if hazard_contains_owner(sim, sim._pos(item), "map"): item.shield = 0.2
		13:
			if item.hidden > 0: item.reappearAt = Vector2(round(item.x / 100) * 100, round(item.y / 100) * 100)
		16: pass # Its cast already has a complete warning; never clamp a delayed timer away from zero.
		18:
			if sim.in_field(sim._pos(item), "vortex") or sim.in_field(sim._pos(item), "burn"): sim.apply_status(item, "vulnerable", 2)

static func bullet(sim, owner: Dictionary, direction: Vector2) -> void:
	if sim.state.enemyProjectiles.size() >= 300: return
	sim.state.enemyProjectiles.append({"id": sim.new_attack_id(), "ownerId": owner.id, "sourceId": owner.get("contentId", "enemy_projectile"), "ownerKind": owner.kind, "x": owner.x, "y": owner.y,
		"vx": direction.x * 160, "vy": direction.y * 160, "radius": 6.0, "life": 5.0, "damage": 1.0, "beam": false, "deflected": false})

static func on_kill(sim, item: Dictionary) -> void:
	if item.get("summon", false): return
	if item.get("family", "") == "split":
		if item.variant == 9: enemy(sim, 1, 0, sim._pos(item), true)
		else: enemy_hazard(sim, item, "circle", sim._pos(item), 48, 1.1, 0.3)

static func spawn_boss(sim) -> void:
	var s: Dictionary = sim.state
	if s.bossSpawned: return
	for item in s.enemies.duplicate():
		if item.kind == "elite": s.enemies.erase(item)
	while s.enemies.size() >= 200: s.enemies.pop_front()
	s.bossSpawned = true; s.bossId = s.nextEnemyId; s.nextEnemyId += 1
	var point: Vector2 = sim._pos(s.player) + Vector2.RIGHT * 270
	s.enemies.append({"id": s.bossId, "kind": "boss", "contentId": s.bossKind, "x": point.x, "y": point.y,
		"hp": 550.0, "maxHp": 550.0, "radius": 38, "speed": 55.0, "damage": 1, "slow": 0.0,
		"orbitHitUntil": 0.0, "statuses": {}, "facing": Vector2.LEFT})
	s.hazards.clear(); s.bossAttackTimer = 2.0 if s.bossKind == "B02" else 0.5
	s.events.clear(); s.resonanceMarker.clear(); s.bossOrigin = point; s.bossPattern = 0

static func move_boss(sim, item: Dictionary, dt: float) -> void:
	var delta: Vector2 = sim._pos(sim.state.player) - sim._pos(item)
	if sim.state.bossKind != "B03" and delta.length() > 180:
		var speed := 22.0 if sim.state.bossRecovery > 0 else 55.0
		if sim.status_time(item, "slow") > 0: speed *= maxf(0, 1 - float(item.statuses.slow.strength) * 0.5)
		var movement: Vector2 = delta.normalized() * speed * dt; item.x += movement.x; item.y += movement.y
	if float(item.get("dashTime", 0)) > 0:
		item.dashTime -= dt; var velocity: Vector2 = item.get("dashDirection", Vector2.ZERO) * 390 * dt
		item.x += velocity.x; item.y += velocity.y
	if delta.length() < item.radius + sim.state.player.radius: sim.hurt_player(1, {"sourceId": sim.state.bossKind, "attackId": item.id})

static func advance_world(sim, dt: float) -> void:
	var s: Dictionary = sim.state
	for panel in s.get("mapPanels", []).duplicate():
		panel.life -= dt
		if panel.life <= 0: s.mapPanels.erase(panel)
	s.bossRecovery = maxf(0, float(s.get("bossRecoveryEnd", 0)) - s.time) if s.time >= float(s.get("bossRecoveryStart", INF)) else 0.0
	var boss_index: int = sim._enemy_index(s.bossId) if s.bossId != null else -1
	if boss_index >= 0 and not s.bossDefeated:
		s.bossAttackTimer -= dt
		if s.bossAttackTimer <= 0 and boss_hazards(s).is_empty():
			warn_boss(sim, s.enemies[boss_index])
	else: advance_phenomenon(sim, dt)
	update_hazards(sim, dt)
	for item in s.enemyProjectiles.duplicate():
		item.x += item.vx * dt; item.y += item.vy * dt; item.life -= dt
		if sim._distance(item, s.player) < item.radius + s.player.radius:
			sim.hurt_player(item.damage, {"sourceId": item.get("sourceId", "enemy_projectile"), "attackId": item.id, "ownerId": item.ownerId, "targetKind": item.get("ownerKind", "normal"), "projectile": true}); item.life = 0
		if item.life <= 0 or sim._distance(item, s.player) > 700: s.enemyProjectiles.erase(item)
	for stone in s.cleansingStones:
		stone.cooldown = maxf(0, stone.cooldown - dt); stone.blocked = maxf(0, stone.blocked - dt)
		if stone.cooldown > 0 or stone.blocked > 0: continue
		if sim._distance(stone, s.player) < 40:
			stone.progress += dt
			if stone.progress >= 1.5:
				for h in s.hazards.duplicate():
					if h.owner == "map" and sim._distance(h, stone) < 180: s.hazards.erase(h); break
				stone.progress = 0; stone.cooldown = 20
		else: stone.progress = 0

static func hazard(sim, owner: String, shape: String, point: Vector2, radius: float, warning: float, active: float, data: Dictionary = {}) -> Dictionary:
	if sim.state.hazards.size() >= 60: return {}
	var h := {"id": sim.state.nextHazardId, "owner": owner, "shape": shape, "kind": shape, "x": point.x, "y": point.y,
		"radius": radius, "warning": maxf(0.8, warning), "maxWarning": maxf(0.8, warning), "active": active, "maxActive": active,
		"hit": false, "angle": 0.0, "length": radius * 2, "width": radius, "innerRadius": 0.0,
		"sourceId": sim.state.bossKind if owner == "boss" else sim.state.zoneId, "patternId": "%s-P%d" % [sim.state.bossKind, sim.state.bossPattern] if owner == "boss" else "", "phenomenonId": "%s-P%d" % [sim.state.zoneId, sim.state.phenomenonIndex] if owner == "map" else "", "safeGap": {"angle": 0.0, "width": 0.0}, "vx": 0.0, "vy": 0.0, "damage": 1.0}
	h.merge(data, true); sim.state.nextHazardId += 1; sim.state.hazards.append(h)
	return h

static func boss_hazards(s: Dictionary) -> Array:
	var out := []
	for h in s.hazards:
		if h.owner == "boss": out.append(h)
	return out

static func warn_boss(sim, boss: Dictionary) -> void:
	var s: Dictionary = sim.state
	var point: Vector2 = sim._pos(boss); var target: Vector2 = sim._pos(s.player)
	var angle: float = (target - point).angle(); var pattern: int = s.bossPattern
	var threshold := {"B01": 0.5, "B02": 0.55, "B03": 0.5, "B04": 0.6, "B05": 0.5, "B06": 0.45}
	if s.bossStage == 1 and boss.hp / boss.maxHp <= threshold[s.bossKind]: s.bossStage = 2; s.stageTransitioned = true; s.transitionSingle = true
	# Map reservations never stack with a boss's large pattern.
	for h in s.hazards.duplicate():
		if h.owner == "map": s.hazards.erase(h)
	var cycle := 4.0
	var advance := 0.3 if sim.research("R12") and s.firstBossPattern else 0.0
	match s.bossKind:
		"B01":
			if pattern % 2 == 0:
				hazard(sim, "boss", "circle", target, 90, 1.0 + advance, 0.35)
				if s.bossStage == 2: hazard(sim, "boss", "circle", target + Vector2.from_angle(angle + PI * 0.5) * 130, 90, 1.5, 0.35)
				cycle = 2.85 + advance
			else:
				for i in range(8):
					if i in [0, 1]: continue
					hazard(sim, "boss", "ray", point, 18, 1.2 + advance, 0.3, {"angle": angle + i * TAU / 8, "length": 540, "width": 18, "safeGap": {"angle": angle + PI / 8, "width": PI / 4}})
				cycle = 3.5 + advance
		"B02":
			if pattern % 2 == 0:
				hazard(sim, "boss", "ray", point, 25, 1.3 + advance, 0.4, {"angle": angle, "length": 600, "width": 25, "safeGap": {"angle": angle + PI * 0.5, "width": PI * 0.5}, "rotationSpeed": PI * 0.45})
				if s.bossStage == 2 and pattern > 0 and not s.get("transitionSingle", false): hazard(sim, "boss", "ray", point, 25, 1.7, 0.4, {"angle": angle + PI, "length": 600, "width": 25, "safeGap": {"angle": angle + PI * 0.5, "width": PI * 0.5}})
				s.transitionSingle = false
				cycle = 3.7 + advance
			else:
				for radius in [130, 310]: hazard(sim, "boss", "ring", point, radius, 1.4 + advance, 0.45, {"innerRadius": radius - 35, "safeGap": {"angle": angle + PI * 0.5, "width": PI * 0.5}})
				cycle = 3.85 + advance
		"B03":
			if pattern % 2 == 0:
				hazard(sim, "boss", "ray", point, 20, 1.1 + advance, 0.3, {"angle": angle, "length": 550, "width": 20}); cycle = 2.9 + advance
			else:
				for i in range(2): hazard(sim, "boss", "circle", point + Vector2.from_angle(angle + (i * 2 - 1) * 1.2) * 200, 90, 1.4 + advance, 4.0)
				cycle = 7.4 + advance
			if s.bossStage == 2: s.cleansingStones[pattern % 3].blocked = 6.0
		"B04":
			if pattern % 2 == 0:
				hazard(sim, "boss", "wave", target + Vector2(-100, 100), 90, 1.2 + advance, 2.0, {"flow": true, "flowX": -45.0 if pattern % 4 == 0 else 45.0, "flowY": 0.0, "damage": 0.0, "width": 100, "length": 400})
				cycle = 5.2 + advance
				if s.bossStage == 2:
					hazard(sim, "boss", "wave", target + Vector2(100, -100), 90, 6.4 + advance, 2.0, {"flow": true, "flowX": 45.0 if pattern % 4 == 0 else -45.0, "flowY": 0.0, "damage": 0.0, "width": 100, "length": 400})
					cycle = 10.4 + advance
			else:
				hazard(sim, "boss", "ray", point, 24, 1.0 + advance, 0.45, {"angle": angle, "length": 220, "width": 24, "dashBoss": true}); cycle = 3.25 + advance
		"B05":
			hazard(sim, "boss", "ray", point, 16, 1.4 + advance, 0.4, {"angle": angle, "length": 360, "width": 16, "reflection": false})
			var joint := point + Vector2.from_angle(angle) * 240
			hazard(sim, "boss", "ray", joint, 16, 1.4 + advance, 0.4, {"angle": angle + PI * 0.5, "length": 240, "width": 16, "reflection": true})
			if s.bossStage == 2 and pattern % 2 == 1:
				# Moving panel finishes before a complete replacement warning begins.
				for h in boss_hazards(s): h.warning += 1.0; h.maxWarning += 1.0; h.angle += 0.3; h.recalculated = true
			cycle = 4.8 + advance if s.bossStage == 2 and pattern % 2 == 1 else 3.8 + advance
		"B06":
			if pattern % 2 == 0:
				for i in range(3 + (1 if s.bossStage == 2 else 0)):
					var side := -1.0 if i < 3 else 1.0
					hazard(sim, "boss", "wave", target + Vector2(side * 260, 0), 20, 1.5 + i * 0.65 + advance, 2.0, {"vx": -side * 160, "vy": 0.0, "width": 18, "length": 170, "angle": PI * 0.5, "safeGap": {"angle": 0.0, "width": 70.0}, "waveNumber": i + 1}); cycle = 5.5 + advance
			else:
				hazard(sim, "boss", "ray", target + Vector2(-200, 90), 16, 1.2 + advance, 0.3, {"angle": 0.0, "length": 400, "width": 16}); cycle = 3.5 + advance
	s.bossPattern += 1; s.firstBossPattern = false; s.bossAttackTimer = cycle
	s.bossRecovery = 0.0; s.bossRecoveryStart = s.time + cycle - 1.5; s.bossRecoveryEnd = s.time + cycle
	s.bossSafeDirection = angle + PI * 0.5
	if sim.research("R06") and pattern == 0: s.researchHints.bossFirstPreview = {"origin": point, "target": target, "angle": angle, "safeAngle": s.bossSafeDirection, "bossKind": s.bossKind}

static func advance_phenomenon(sim, dt: float) -> void:
	var s: Dictionary = sim.state
	var start: float = PHENOMENON_START[s.zoneId]
	preview_phenomenon(sim)
	if s.zoneId in ["Z01", "Z04"] and s.time >= s.bossAt - 10: return
	if s.time < start:
		if sim.research("R02") and s.time >= start - 5: preview_phenomenon(sim)
		return
	s.phenomenonTimer -= dt
	if s.phenomenonTimer > 0: return
	if s.phenomenonSkip > 0:
		s.phenomenonSkip -= 1; s.phenomenonTimer = 4; return
	var point: Vector2 = phenomenon_anchor(sim)
	var warning_bonus: float = s.nextWarningBonus - s.phenomenonWarningCost
	s.nextWarningBonus = 0; s.phenomenonWarningCost = 0
	match s.zoneId:
		"Z01":
			for i in range(3 if s.time >= 180 else 2):
				var offset := Vector2((i * 2 - 1) * 90, 20 if s.phenomenonIndex % 2 else -20)
				if offset.length() < 60: continue
				hazard(sim, "map", "circle", point + offset, 50, 0.8 + warning_bonus + i * 0.4, 0.35)
			s.phenomenonTimer = 3.15
		"Z02":
			var angle: float = s.phenomenonIndex * PI * 0.5
			hazard(sim, "map", "ring", Vector2.ZERO, 380, 1.2 + warning_bonus, 5, {"innerRadius": 90, "angle": angle, "rotationSpeed": TAU / 8 * (1 if s.time < 360 or s.phenomenonIndex % 2 == 0 else -1), "safeGap": {"angle": angle, "width": PI * 0.5}, "dangerArc": TAU / 3})
			s.phenomenonTimer = 10.2
		"Z03":
			point += garden_offset(sim)
			hazard(sim, "map", "circle", point, 110, 2.0 + warning_bonus, 6, {"grow": true, "growthRadius": 110, "radius": 45})
			s.phenomenonTimer = 5
		"Z04":
			hazard(sim, "map", "wave", point + Vector2(0, 80 if s.phenomenonIndex % 2 == 0 else -80), 90, 1 + warning_bonus, 4, {"flow": true, "flowX": 45.0 if s.phenomenonIndex % 2 == 0 else -45.0, "flowY": 0.0, "damage": 0.0, "width": 100, "length": 400})
			s.phenomenonTimer = 12
		"Z05":
			var grid := Vector2(round(point.x / 100) * 100, round(point.y / 100) * 100)
			s.mapPanels = [{"x": grid.x + 180, "y": grid.y - 90, "life": 5.0}, {"x": grid.x - 180, "y": grid.y + 90, "life": 5.0}]
			hazard(sim, "map", "ray", grid + Vector2(-180, -90), 14, 1.1 + warning_bonus, 0.4, {"angle": 0.0, "length": 360, "width": 14, "reflection": false})
			hazard(sim, "map", "ray", grid + Vector2(180, -90), 14, 1.1 + warning_bonus, 0.4, {"angle": PI * 0.5, "length": 180, "width": 14, "reflection": true})
			s.phenomenonTimer = 15
		"Z06":
			var side := -1.0 if s.phenomenonIndex % 2 == 0 else 1.0
			hazard(sim, "map", "wave", point + Vector2(side * 260, 0), 20, 1.2 + warning_bonus, 3, {"vx": -side * 130, "vy": 0.0, "angle": PI * 0.5, "width": 18, "length": 180, "safeGap": {"angle": 0.0, "width": 70.0}})
			s.phenomenonTimer = 18
	s.phenomenonHistory.append({"index": s.phenomenonIndex, "time": s.time, "zoneId": s.zoneId, "position": point})
	if s.phenomenonHistory.size() > 12: s.phenomenonHistory.pop_front()
	if s.phenomenonReveal > 0: s.phenomenonReveal -= 1; s.researchHints.phenomenonPosition = point
	if s.phenomenonOrderReveal > 0: s.phenomenonOrderReveal -= 1; s.researchHints.phenomenonNextIndex = s.phenomenonIndex + 1
	s.phenomenonIndex += 1

static func hazard_contains_owner(sim, point: Vector2, owner: String) -> bool:
	for h in sim.state.hazards:
		if h.owner == owner and h.warning <= 0 and contains(h, point, sim.state.player.radius): return true
	return false

static func contains(h: Dictionary, point: Vector2, player_radius: float) -> bool:
	var delta := point - Vector2(h.x, h.y)
	match h.shape:
		"circle": return delta.length() <= h.radius + player_radius
		"ray":
			var direction := Vector2.from_angle(h.angle)
			return delta.dot(direction) >= -player_radius and delta.dot(direction) <= h.length + player_radius and absf(delta.cross(direction)) <= h.width + player_radius
		"ring":
			if delta.length() < h.innerRadius - player_radius or delta.length() > h.radius + player_radius: return false
			var gap: Dictionary = h.safeGap
			if gap.width > 0 and absf(wrapf(delta.angle() - gap.angle, -PI, PI)) < gap.width / 2: return false
			if h.has("dangerArc"): return absf(wrapf(delta.angle() - h.angle, -PI, PI)) <= h.dangerArc / 2
			return true
		"wave":
			if h.get("flow", false): return absf(delta.y) < h.width and absf(delta.x) < h.length / 2
			if absf(delta.y) < float(h.safeGap.width) / 2: return false
			return absf(delta.x) < h.width + player_radius and absf(delta.y) < h.length + player_radius
	return false

static func update_hazards(sim, dt: float) -> void:
	for h in sim.state.hazards.duplicate():
		if h.warning > 0:
			h.warning = maxf(0, h.warning - dt)
			if h.get("grow", false): h.radius = lerpf(45, h.growthRadius, 1 - h.warning / h.maxWarning)
			if h.warning <= 0 and h.get("dashBoss", false):
				var index: int = sim._enemy_index(sim.state.bossId)
				if index >= 0: sim.state.enemies[index].dashTime = 0.45; sim.state.enemies[index].dashDirection = Vector2.from_angle(h.angle)
		else:
			h.active -= dt; h.x += h.vx * dt; h.y += h.vy * dt
			if h.has("rotationSpeed"):
				var rotation_factor := 1.0
				if h.owner == "boss" and sim.state.bossKind == "B02":
					var boss_index: int = sim._enemy_index(sim.state.bossId)
					if boss_index >= 0 and sim.status_time(sim.state.enemies[boss_index], "slow") > 0: rotation_factor = maxf(0.8, 1 - float(sim.state.enemies[boss_index].statuses.slow.strength) * 0.5)
				h.angle += h.rotationSpeed * rotation_factor * dt
				# Gap changes only after at least two seconds of stable reading.
				if h.maxActive - h.active > 2: h.safeGap.angle = h.angle + PI
			if h.active > 0 and h.get("flow", false):
				if contains(h, sim._pos(sim.state.player), sim.state.player.radius):
					sim.state.player.x += h.flowX * dt; sim.state.player.y += h.flowY * dt
				for e in sim.state.enemies:
					if e.kind != "boss" and contains(h, sim._pos(e), e.radius): e.x += h.flowX * dt * (0.3 if e.family == "shield" else 1)
			elif h.active > 0 and contains(h, sim._pos(sim.state.player), sim.state.player.radius):
				if not h.hit:
					h.hit = true; sim.hurt_player(h.damage, {"sourceId": h.get("sourceId", sim.state.bossKind if h.owner == "boss" else sim.state.zoneId), "attackId": h.id, "hazardId": h.id, "patternId": h.get("patternId", ""), "phenomenonId": h.get("phenomenonId", ""), "ownerId": h.get("ownerId", -1), "damageKind": "incoming", "hazard": h.shape, "waveNumber": h.get("waveNumber", 0)})
		if h.warning <= 0 and h.active <= 0:
			if not h.hit and not h.get("flow", false): sim.emit_event("control", {"sourceId": h.owner, "dodged": true, "subtype": "hazard_dodged", "attackId": h.id})
			sim.state.hazards.erase(h)

static func phenomenon_anchor(sim) -> Vector2:
	var point: Vector2 = sim._pos(sim.state.player)
	if sim.state.zoneId == "Z01":
		for history in sim.state.positionHistory:
			if sim.state.time - history.time >= 0.6: point = sim._pos(history)
			else: break
	return point

static func garden_offset(sim) -> Vector2:
	var preview_rng := RandomNumberGenerator.new()
	preview_rng.seed = int(sim.state.seed) * 131 + int(sim.state.phenomenonIndex) * 8191
	return Vector2.from_angle(preview_rng.randf() * TAU) * 120

static func preview_phenomenon(sim) -> void:
	var s: Dictionary = sim.state
	if s.bossSpawned: return
	var start: float = PHENOMENON_START[s.zoneId]
	var first_research: bool = sim.research("R02") and s.phenomenonIndex == 0 and s.time >= start - 5
	if not first_research and s.phenomenonReveal <= 0 and s.phenomenonOrderReveal <= 0: return
	var at: float = start if s.time < start else s.time + maxf(0, s.phenomenonTimer)
	var point: Vector2 = phenomenon_anchor(sim)
	var shape := "circle"
	match s.zoneId:
		"Z01": point += Vector2(-90, 20 if s.phenomenonIndex % 2 else -20)
		"Z02": point = Vector2.ZERO; shape = "ring"
		"Z03": point += garden_offset(sim)
		"Z04": point += Vector2(0, 80 if s.phenomenonIndex % 2 == 0 else -80); shape = "wave"
		"Z05": point = Vector2(round(point.x / 100) * 100, round(point.y / 100) * 100) + Vector2(-180, -90); shape = "ray"
		"Z06": point += Vector2(-260 if s.phenomenonIndex % 2 == 0 else 260, 0); shape = "wave"
	# Player-relative forecasts update until the ordinary warning locks its coordinates.
	# The UI identifies this as a forecast; it never renders it as an active collider.
	var forecast := {"time": at, "zoneId": s.zoneId, "index": s.phenomenonIndex, "position": point, "shape": shape, "locked": false}
	s.researchHints.nextPhenomenon = forecast
	if s.phenomenonReveal > 0 or first_research: s.researchHints.phenomenonPosition = point
	if s.phenomenonOrderReveal > 0:
		s.researchHints.phenomenonNextIndex = s.phenomenonIndex
		s.researchHints.phenomenonOrder = [{"index": s.phenomenonIndex, "shape": shape, "time": at}, {"index": s.phenomenonIndex + 1, "shape": shape, "time": at + {"Z01": 3.15, "Z02": 10.2, "Z03": 5.0, "Z04": 12.0, "Z05": 15.0, "Z06": 18.0}[s.zoneId]}]

static func enemy_hazard(sim, item: Dictionary, shape: String, point: Vector2, radius: float, warning: float, active: float, data: Dictionary = {}) -> Dictionary:
	return hazard(sim, "enemy", shape, point, radius, warning, active, data.merged({"sourceId": item.get("contentId", "enemy_hazard"), "ownerId": item.id}, true))
