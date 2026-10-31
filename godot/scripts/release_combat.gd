extends RefCounted

# Numeric coefficients are balance hypotheses. Geometry, ownership and limits are contracts.
static func field(sim, kind: String, point: Vector2, radius: float, duration: float, data: Dictionary = {}) -> int:
	if sim.state.fields.size() >= 60: sim.state.fields.pop_front()
	var value := {"id": sim.state.nextFieldId, "kind": kind, "x": point.x, "y": point.y, "radius": radius,
		"life": duration, "maxLife": duration, "nextTick": 0.0, "hitIds": [], "hits": {}, "sourceId": ""}
	value.merge(data, true); sim.state.nextFieldId += 1; sim.state.fields.append(value)
	return value.id

static func mods(sim, source: String, kind: String = "direct") -> Dictionary:
	return sim.modifiers( sim.context(source, kind))

static func ready(sim, source: String, dt: float) -> bool:
	sim.state.cooldowns[source] -= dt
	return sim.state.spells[source] > 0 and sim.state.cooldowns[source] <= 0 and sim.state.time - float(sim.state.lastCastTimes.get(source, -100)) >= 0.4

static func interval(sim, source: String, base: float, floor_value: float = 0.3) -> float:
	var school := "비전"
	for item in sim.catalog.upgrades:
		if item.id == source: school = item.get("school", school); break
	var m: Dictionary = sim.modifiers({"sourceId": source, "school": school, "damageKind": "direct"})
	var value: float = base / sim._haste() * float(m.get("cooldown_mult", 1.0))
	if sim.Events.has_task(sim.state, "E09"): value *= 1.1
	if source in ["fireball", "meteor"] and sim.resonance("supernova") == "F03-R3": value *= 0.8
	if source == "pulse" and sim.resonance("hyperion") == "F04-R3": value *= 1.25
	if source == "bolt": value *= float(sim.state.get("plasmaStored", 1))
	return maxf(maxf(0.4, floor_value), maxf(base / 1.8, value))

static func cooldown(sim, source: String, base: float, floor_value: float = 0.3) -> void:
	sim.state.cooldowns[source] = interval(sim, source, base, floor_value)
	if source == "bolt": sim.state.plasmaStored = 1.0
	sim.state.lastCastTimes[source] = sim.state.time

static func cast_event(sim, source: String, data: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = sim.context(source)
	ctx.merge(data, true); return ctx

static func projectile(sim, source: String, point: Vector2, direction: Vector2, damage: float, data: Dictionary = {}) -> void:
	if sim.state.projectiles.size() >= 300: return
	var m := mods(sim, source)
	var speed: float = float(data.get("speed", 420)) * float(m.get("projectile_speed_mult", 1))
	if sim.state.classId == "C02": speed *= 0.9
	var value := {"x": point.x, "y": point.y, "vx": direction.x * speed, "vy": direction.y * speed,
		"radius": 6.0, "damage": damage, "life": 1.4, "sourceId": source, "hitIds": [],
		"pierce": int(m.get("pierce_add", 0)), "context": sim.context(source), "depth": 0}
	value.merge(data, true)
	# Speed modifiers change travel time, preserving each source's original range.
	value.life /= maxf(0.01, float(m.get("projectile_speed_mult", 1)))
	value.context.projectile = true; value.context.projectilePierces = 0; value.context.origin = point; value.penetrations = 0
	sim.state.projectiles.append(value)

static func advance(sim, dt: float) -> void:
	var s: Dictionary = sim.state
	for source in s.spells:
		if source in ["orbit", "m14", "m22", "m24"]: continue
		if not ready(sim, source, dt): continue
		var target: Dictionary = choose_target(sim, source)
		# Path fields and passive protection are allowed without targets; attacks retain cooldown.
		if target.is_empty() and source not in ["m11", "m16", "m18", "m20"]: continue
		var level: int = s.spells[source]
		var m := mods(sim, source)
		if source in ["fireball", "meteor"]: m = sim.modifiers(sim.context(source).merged({"fireExplosion": true}))
		var point: Vector2 = sim._pos(s.player)
		var aim: Vector2 = (sim._pos(target) - point).normalized() if not target.is_empty() else s.lastDirection
		var radius_mult: float = float(m.get("radius_mult", 1))
		var duration_mult: float = float(m.get("duration_mult", 1))
		var ctx := cast_event(sim, source, {"targetId": target.get("id", -1), "targetPosition": sim._pos(target) if not target.is_empty() else point})
		if source == "meteor": ctx.targetingPolicy = "highest_hp"; ctx.targetPolicy = "highest_hp"; ctx.priorityTargetId = target.get("id", -1)
		match source:
			"bolt":
				if sim.has_fusion("plasma"): plasma(sim, aim, level, ctx)
				else: projectile(sim, source, point, aim, 2 + level, {"pierce": 1 + int(m.get("pierce_add", 0)) if s.classId == "C01" else int(m.get("pierce_add", 0))})
				cooldown(sim, source, 0.65, 0.15)
			"lightning":
				lightning(sim, target, level, ctx)
				cooldown(sim, source, 2.7, 0.5)
			"frost":
				var radius: float = (120 + (level - 1) * 18 + (45 if sim.has_fusion("blizzard") else 0)) * radius_mult
				if s.classId == "C03": radius *= 0.9
				if sim.resonance("blizzard") == "F02-R1": radius *= 0.8
				sim._effect("frost", point.x, point.y, 0.45, {"radius": radius})
				for enemy in sim.state.enemies.duplicate():
					if point.distance_to(sim._pos(enemy)) <= radius + enemy.radius:
						sim.apply_status(enemy, "slow", 2.0 + (1 if sim.has_fusion("blizzard") else 0), 0.25)
						sim.apply_damage(enemy, 1.5 + level * 0.5, ctx)
						if sim.has_fusion("f19") and sim.in_field(sim._pos(enemy), "veil"): sim.extend_status(enemy.id, "vulnerable", 1.0, 4.0)
				cooldown(sim, source, 4.0, 1.0)
			"fireball":
				projectile(sim, source, point, aim, 3 + level, {"speed": 340, "radius": 10.0, "explosionRadius": (65 + level * 8 + (45 if sim.has_fusion("supernova") else 0)) * radius_mult})
				cooldown(sim, source, 3.0, 0.7)
			"vortex":
				var radius: float = (70 + level * 12 + (35 if sim.has_fusion("blizzard") else 0)) * radius_mult
				if sim.resonance("blizzard") == "F02-R1": radius *= 0.8
				field(sim, "vortex", sim._pos(target), radius, (3 + float(m.get("duration_add", 0))) * duration_mult, {"sourceId": source, "damage": 1 + level * 0.5, "context": ctx})
				cooldown(sim, source, 5.0, 1.5)
			"meteor":
				var radius: float = (95 + level * 12 + (50 if sim.has_fusion("supernova") else 0)) * radius_mult
				if sim.resonance("supernova") == "F03-R1": radius *= 0.75
				var damage_radius := radius
				radius *= float(sim.modifiers({"sourceId": source, "telegraph": true}).get("radius_mult", 1))
				var delay := 1.0 if sim.has_fusion("supernova") else 0.7
				field(sim, "meteor_warning", sim._pos(target), radius, delay, {"sourceId": source, "damage": 5 + level * 2, "damageRadius": damage_radius, "context": ctx})
				cooldown(sim, source, 6.0, 2.0)
			"pulse":
				var radius: float = (120 + level * 22 + (50 if sim.has_fusion("hyperion") else 0)) * radius_mult
				if sim.resonance("hyperion") == "F04-R3": radius *= 1.3
				var damage: float = 2 + level
				if sim.has_fusion("hyperion"): damage *= 1.4
				if sim.resonance("hyperion") == "F04-R3": damage *= 1.2
				field(sim, "pulse", point, radius, 0.6, {"sourceId": source, "damage": damage, "context": ctx, "currentRadius": 0.0, "glyphCount": 0})
				cooldown(sim, source, 3.3, 0.8)
			"m09":
				ash_rain(sim, sim._pos(target), level, ctx)
				cooldown(sim, source, 4.2, 1.2)
			"m10":
				var spread: float = 0.38 - level * 0.035
				for i in range(3 + int(m.get("count_add", 0))):
					projectile(sim, source, point + aim * 30, aim.rotated((i - 1) * spread), 1.8 + level * 0.7, {"pierce": 5 + int(m.get("pierce_add", 0)), "life": 0.9, "slow": true, "radius": 4.0 * radius_mult})
				cooldown(sim, source, 2.5)
			"m11":
				field(sim, "electric_ring", point - s.lastDirection * 60, 65 * radius_mult, (2 + level * 0.6 + float(m.get("duration_add", 0))) * duration_mult, {"sourceId": source, "damage": 1.5 + level * 0.3, "context": ctx})
				cooldown(sim, source, 4.5)
			"m12":
				field(sim, "well_warning", sim._pos(target), (65 + level * 14) * radius_mult, 0.8, {"sourceId": source, "context": ctx, "duration": (2.5 + float(m.get("duration_add", 0))) * duration_mult})
				cooldown(sim, source, 5.5)
			"m13":
				var damage: float = 2.2 + level
				if sim.has_fusion("f26") and sim.status_time(target, "slow") > 0 and s.time >= float(target.get("winterDaggerAt", 0)):
					damage *= 1.3; target.winterDaggerAt = s.time + 2.0
				if sim.has_fusion("f33") and target.kind == "normal" and target.get("delayedUntil", 0) > s.time: sim.apply_status(target, "mark", 3)
				projectile(sim, source, point, aim, damage, {"speed": 600, "radius": 5.0})
				cooldown(sim, source, 1.8)
			"m15":
				var glyph_radius: float = (70 + level * 12) * radius_mult
				field(sim, "glyph", sim._pos(target) - aim * 30, glyph_radius, (3 + float(m.get("duration_add", 0))) * duration_mult, {"sourceId": source, "damage": 0.5 + level * 0.2, "context": ctx})
				cooldown(sim, source, 4.5)
			"m16":
				field(sim, "mine", point - s.lastDirection * 35, 18 * radius_mult, 12 + float(m.get("duration_add", 0)), {"sourceId": source, "damage": 3 + level, "context": ctx})
				var mines := []
				for item in s.fields:
					if item.kind == "mine": mines.append(item)
				while mines.size() > 2 + level: s.fields.erase(mines.pop_front())
				cooldown(sim, source, 2.8)
			"m17":
				var arc: bool = sim.has_fusion("f25") and sim.in_field(point, "electric_ring")
				line_damage(sim, point, aim, 230, (18 + level * 5) * radius_mult, 2 + level, ctx, arc)
				cooldown(sim, source, 2.7)
			"m18":
				var wall_length: float = (140 + level * 24) * float(m.get("wall_length_mult", 1))
				field(sim, "wall", point + aim * 65, wall_length * 0.5, 2.5 * duration_mult, {"sourceId": source, "direction": aim.orthogonal(), "width": 22.0 * radius_mult, "context": ctx, "deflected": 0})
				cooldown(sim, source, 5.0)
			"m19":
				mark(sim, target.id, ctx, level - 1)
				cooldown(sim, source, 4.0)
			"m20":
				var count: int = deflect(sim, point, (110 + level * 12) * radius_mult, 0.4 + level * 0.17)
				if count == 0: continue
				cooldown(sim, source, 2.5)
			"m21":
				field(sim, "veil", point, (125 + level * 15) * radius_mult, 2.5 * duration_mult, {"sourceId": source, "context": ctx})
				cooldown(sim, source, 5.0)
			"m23":
				var count := 0
				for enemy in s.enemies:
					if count >= level + int(m.get("count_add", 0)): break
					if enemy.kind != "boss" and enemy.get("castWarning", 0) > 0 and not enemy.get("castDelayed", false):
						sim.delay_enemy_cast(enemy.id, 1.0); count += 1
						sim.emit_event("control", {"sourceId": source, "sealDelayed": true, "eliteCastDelayed": enemy.kind == "elite", "subtype": "seal_delay", "targetId": enemy.id})
				if count == 0: continue
				cooldown(sim, source, 6.0)
		sim.emit_event("cast", ctx)
	update_projectiles(sim, dt)
	orbit(sim)
	update_marks(sim, dt)
	update_fields(sim, dt)

static func choose_target(sim, source: String) -> Dictionary:
	var pool: Array = sim.state.enemies.duplicate()
	if pool.is_empty(): return {}
	var best: Dictionary = {}; var score := INF
	for enemy in pool:
		var distance: float = sim._distance(enemy, sim.state.player)
		var search: Dictionary = sim.modifiers({"sourceId": source, "targetSearch": true, "rangedSearch": true})
		if distance > (550 + float(search.get("range_add", 0))) * float(search.get("range_mult", 1)): continue
		var value: float = distance
		match source:
			"m09":
				var count := 0
				for other in pool:
					if sim._distance(other, enemy) < 100: count += 1
				value = -count * 1000 + distance
			"m13": value = enemy.hp / enemy.maxHp * 1000 + distance * 0.01
			"m15": value = distance - (1000 if enemy.kind == "elite" else 0)
			"m19":
				value = -float(enemy.speed)
				if sim.has_fusion("f22") and enemy.get("delayedUntil", 0) > sim.state.time: value -= 1000
			"meteor":
				value = -float(enemy.hp)
				if sim.has_fusion("f29") and sim.status_time(enemy, "vulnerable") > 0: value -= 1000000
		if value < score: best = enemy; score = value
	return best

static func plasma(sim, aim: Vector2, level: int, ctx: Dictionary) -> void:
	var point: Vector2 = sim._pos(sim.state.player)
	var width := 14.0; var damage: float = (2 + level) * 1.3
	match sim.resonance("plasma"):
		"F01-R1": width *= 0.7; damage *= 1.45
		"F01-R2": damage *= 0.75
		"F01-R3": damage *= 0.85
	sim._effect("beam", point.x + aim.x * 540, point.y + aim.y * 540, 0.25, {"fromX": point.x, "fromY": point.y, "radius": width})
	for enemy in sim.state.enemies.duplicate():
		var relative: Vector2 = sim._pos(enemy) - point
		if relative.dot(aim) >= 0 and relative.dot(aim) <= 540 and absf(relative.cross(aim)) <= width + enemy.radius:
			var shocked: bool = sim.status_time(enemy, "shock") > 0
			ctx.shockApplied = true
			sim.apply_damage(enemy, damage, ctx); sim.apply_status(enemy, "shock", 2)
			if shocked and sim.resonance("plasma") == "F01-R3": sim.state.plasmaStored = maxf(0.76, float(sim.state.get("plasmaStored", 1.0)) - 0.08)
	if sim.resonance("plasma") == "F01-R2":
		for angle in [-0.35, 0.35]: projectile(sim, "plasma", point + aim * 500, aim.rotated(angle), damage * 0.35, {"depth": 1, "context": sim.context("plasma", "derived", 1), "life": 0.5})

static func lightning(sim, initial: Dictionary, level: int, ctx: Dictionary) -> void:
	var maximum: int = mini(8, level + 1 + int(mods(sim, "lightning").get("count_add", 0)))
	var from: Dictionary = sim.state.player
	var target: Dictionary = initial
	var chain := []
	var used := []
	var wall_extra := false
	while not target.is_empty() and chain.size() < maximum + (1 if wall_extra else 0):
		if sim.has_fusion("f10") and not wall_extra and segment_in_wall(sim, sim._pos(from), sim._pos(target)):
			wall_extra = true
		chain.append(target); used.append(target.id)
		from = target
		var search_range: float = 160 * float(mods(sim, "lightning").get("first_jump_mult", 1)) if chain.size() == 1 else 160
		target = sim._nearest(from, search_range, used)
		if sim.has_fusion("f13"):
			for enemy in sim.state.enemies:
				if not used.has(enemy.id) and sim.status_time(enemy, "ignite") > 0 and sim._distance(enemy, from) < search_range: target = enemy; break
	from = sim.state.player
	for i in range(chain.size()):
		target = chain[i]
		if sim._enemy_index(target.id) < 0: continue
		var has_next := false
		for j in range(i + 1, chain.size()):
			if sim._enemy_index(chain[j].id) >= 0: has_next = true; break
		ctx.firstTarget = i == 0; ctx.firstHit = i == 0
		ctx.chainOrigin = sim._pos(initial); ctx.chainOriginTargetId = initial.id
		ctx.maximumChain = not has_next and chain.size() >= maximum + (1 if wall_extra else 0)
		ctx.chainComplete = not has_next; ctx.artifactEffectDamage = 0.3
		sim._effect("lightning", target.x, target.y, 0.24, {"fromX": from.x, "fromY": from.y})
		sim.apply_damage(target, 3 + level, ctx)
		if sim.has_fusion("f13") and sim.status_time(target, "ignite") > 0: sim.state.cooldowns.m17 = maxf(0, sim.state.cooldowns.m17 - 0.2)
		from = target
	sim.emit_event("control", {"sourceId": "lightning", "chainComplete": true, "chainOrigin": sim._pos(initial), "maximumChain": chain.size() >= maximum})

static func line_damage(sim, point: Vector2, aim: Vector2, length_value: float, width: float, damage: float, ctx: Dictionary, arc: bool = false) -> void:
	sim._effect("beam", point.x + aim.x * length_value, point.y + aim.y * length_value, 0.3, {"fromX": point.x, "fromY": point.y, "radius": width})
	for enemy in sim.state.enemies.duplicate():
		var relative: Vector2 = sim._pos(enemy) - point
		var hit: bool = relative.dot(aim) >= 0 and relative.dot(aim) <= length_value and absf(relative.cross(aim)) <= width + enemy.radius
		if arc: hit = relative.length() < length_value and relative.normalized().dot(aim) > 0.35
		if hit:
			var bonus := 1.3 if sim.status_time(enemy, "ignite") > 0 else 1.0
			sim.apply_damage(enemy, damage * bonus, ctx)

static func ash_rain(sim, point: Vector2, level: int, ctx: Dictionary) -> void:
	for i in range(level + 1):
		var offset := Vector2.from_angle(i * TAU / (level + 1)) * (18 + i * 9)
		field(sim, "ash_warning", point + offset, 28, 0.35 + i * 0.08, {"sourceId": "m09", "context": ctx, "damage": 1.2})

static func mark(sim, id: int, ctx: Dictionary, retargets: int = 0) -> void:
	if sim.state.marks.size() >= 30: return
	sim.state.marks.append({"targetId": id, "delay": 0.9, "context": ctx.duplicate(), "retargets": retargets, "retargeted": false})
	var index: int = sim._enemy_index(id)
	if index >= 0:
		var enemy: Dictionary = sim.state.enemies[index]
		sim._effect("mark", enemy.x, enemy.y, 0.9, {"radius": 24})

static func update_marks(sim, dt: float) -> void:
	for item in sim.state.marks.duplicate():
		item.delay -= dt
		var index: int = sim._enemy_index(item.targetId)
		if index < 0: sim.state.marks.erase(item); continue
		var enemy: Dictionary = sim.state.enemies[index]
		if sim.has_fusion("f18") and not item.retargeted:
			for other in sim.state.enemies:
				if other.id != enemy.id and sim.in_field(sim._pos(other), "glyph"):
					item.targetId = other.id; item.retargeted = true; enemy = other; break
		if item.delay <= 0:
			sim.apply_damage(enemy, 3 + sim.state.spells.m19, item.context)
			sim.apply_status(enemy, "shock", 2.0)
			sim.state.marks.erase(item)
			if item.retargets > 0:
				var other: Dictionary = sim._nearest(enemy, 140, [enemy.id])
				if not other.is_empty(): mark(sim, other.id, sim.context("m19", "derived", 1), item.retargets - 1)

static func deflect(sim, center: Vector2, radius: float, angle: float) -> int:
	var count := 0
	for item in sim.state.enemyProjectiles:
		if item.get("beam", false) or item.get("deflected", false) or center.distance_to(sim._pos(item)) > radius: continue
		var velocity := Vector2(item.vx, item.vy).rotated(angle if item.id % 2 == 0 else -angle)
		item.vx = velocity.x; item.vy = velocity.y; item.deflected = true; count += 1
		sim.emit_event("control", {"sourceId": "m20", "deflected": true, "subtype": "deflect", "targetId": item.get("ownerId", -1), "targetPosition": sim._pos(item)})
		if sim.has_fusion("f27"): line_damage(sim, center, velocity.normalized(), 180, 20, 1.3, sim.context("f27", "derived", 1), true)
		if sim.has_fusion("f36") and sim._enemy_index(item.get("ownerId", -1)) >= 0: mark(sim, item.ownerId, sim.context("f36", "derived", 1))
	return count

static func update_projectiles(sim, dt: float) -> void:
	for item in sim.state.projectiles.duplicate():
		var travel_dt: float = minf(dt, maxf(0, item.life))
		item.x += item.vx * travel_dt; item.y += item.vy * travel_dt; item.life -= dt
		if sim.has_fusion("f14") and item.sourceId == "bolt" and not item.get("wallCharged", false) and sim.in_field(sim._pos(item), "wall"):
			item.wallCharged = true; item.slow = true
		for enemy in sim.state.enemies.duplicate():
			if item.hitIds.has(enemy.id) or sim._distance(item, enemy) > item.radius + enemy.radius: continue
			item.hitIds.append(enemy.id)
			if item.has("explosionRadius"):
				explode(sim, sim._pos(item), item.explosionRadius, item.damage, item.context, "fireball"); item.life = 0; break
			item.context.projectilePierces = item.penetrations
			item.context.daggerExecute = false
			var hit_damage: float = item.damage
			if item.sourceId in ["m13", "f09"] and enemy.kind == "normal" and enemy.hp <= enemy.maxHp * 0.1:
				hit_damage = enemy.hp + 1; item.context.daggerExecute = true
			sim.apply_damage(enemy, hit_damage, item.context)
			if item.get("slow", false): sim.apply_status(enemy, "slow", 2.0, 0.25)
			if item.pierce <= 0: item.life = 0; break
			item.pierce -= 1; item.penetrations += 1
		if item.life <= 0:
			if item.has("explosionRadius") and item.hitIds.is_empty(): explode(sim, sim._pos(item), item.explosionRadius, item.damage, item.context, "fireball")
			sim.state.projectiles.erase(item)

static func explode(sim, center: Vector2, radius: float, damage: float, ctx: Dictionary, source: String) -> void:
	if sim.has_fusion("supernova"): damage *= 1.5
	if source == "meteor" and sim.resonance("supernova") == "F03-R1": damage *= 1.4
	if sim.resonance("supernova") == "F03-R2": damage *= 0.75
	if sim.resonance("supernova") == "F03-R3": damage *= 0.8
	ctx = ctx.duplicate(); ctx.explosionId = sim.new_attack_id(); ctx.artifactEffectRadius = radius * 0.4; ctx.artifactEffectDamage = damage * 0.25
	ctx.fragmentPositions = [center + Vector2(35, 0), center + Vector2(-18, 30), center + Vector2(-18, -30)]
	ctx.secondaryPositions = [center + Vector2(45, 0), center + Vector2(-45, 0)]
	ctx.fireExplosion = true; ctx.explosionRadius = radius; ctx.meteorImpact = source == "meteor"
	sim._effect("explosion", center.x, center.y, 0.35, {"radius": radius})
	var first_actual_damage := -1.0
	for enemy in sim.state.enemies.duplicate():
		var distance: float = center.distance_to(sim._pos(enemy))
		if distance > radius + enemy.radius: continue
		ctx.centerHit = distance <= radius * 0.5
		var actual_damage: float = sim.apply_damage(enemy, damage, ctx)
		if first_actual_damage < 0 and actual_damage > 0: first_actual_damage = actual_damage
		if sim.has_fusion("f07") and source == "fireball":
			if distance <= radius * 0.5: sim.apply_status(enemy, "ignite", 3)
			else: sim.apply_status(enemy, "slow", 2, 0.25)
		else: sim.apply_status(enemy, "ignite", 3)
	var explosion_mods: Dictionary = sim.modifiers(ctx)
	var source_damage: float = damage * (1 + sim.state.stats.power * 0.25 + float(explosion_mods.get("damage_add", 0))) * float(explosion_mods.get("damage_mult", 1))
	var impact_event: Dictionary = ctx.duplicate()
	impact_event.targetPosition = center
	impact_event.originalDamage = first_actual_damage if first_actual_damage > 0 else source_damage
	impact_event.damage = impact_event.originalDamage
	sim.emit_event("explosion", impact_event)
	if sim.resonance("supernova") == "F03-R2": field(sim, "burn", center, radius, 3.0, {"sourceId": "supernova", "context": sim.context("supernova", "derived", 1), "damage": 0.25})
	if source == "meteor":
		if sim.has_fusion("f11"): field(sim, "ash", center, radius, 2.0, {"sourceId": "f11", "context": sim.context("f11", "derived", 1), "damage": 0.5})
		if sim.has_fusion("f24"):
			for mine in sim.state.fields.duplicate():
				if mine.kind == "mine" and center.distance_to(sim._pos(mine)) <= radius:
					sim.state.fields.erase(mine)
					for i in range(4): projectile(sim, "f24", sim._pos(mine), Vector2.from_angle(i * TAU / 4), 1.5, {"depth": 1, "context": sim.context("f24", "derived", 1)})

static func orbit(sim) -> void:
	var query: Dictionary = sim.modifiers({"sourceId": "orbit", "projectileCount": sim.state.spells.orbit})
	var count: int = mini(8, sim.state.spells.orbit + int(query.get("count_add", 0))) if sim.state.spells.orbit > 0 else 0
	for i in range(count):
		var point: Vector2 = sim.orbit_position(i)
		if sim.has_fusion("f06") and sim.in_field(point, "electric_ring") and sim.state.time >= float(sim.state.orbitCharges.get(str(i), {}).get("next", 0)):
			sim.state.orbitCharges[str(i)] = {"charged": true, "next": sim.state.time + 2}
		for enemy in sim.state.enemies.duplicate():
			var contact_radius: float = 12 * float(sim.modifiers({"sourceId": "orbit", "swordContact": true}).get("radius_mult", 1))
			if point.distance_to(sim._pos(enemy)) > enemy.radius + contact_radius or enemy.orbitHitUntil > sim.state.time: continue
			enemy.orbitHitUntil = sim.state.time + maxf(0.2, 0.45 + float(mods(sim, "orbit").get("hit_interval_add", 0)))
			var damage: float = 1.5 + sim.state.spells.orbit * 0.5
			if sim.has_fusion("hyperion"): damage *= 1.5
			if sim.resonance("hyperion") == "F04-R1": damage *= 0.85
			if sim.resonance("hyperion") == "F04-R2": damage *= 0.8
			sim.apply_damage(enemy, damage, sim.context("orbit"))
			if sim.state.orbitCharges.get(str(i), {}).get("charged", false):
				sim.apply_status(enemy, "shock", 2); sim.state.orbitCharges[str(i)].charged = false
			if sim.has_fusion("f09"):
				var target: Dictionary = choose_target(sim, "m13")
				if not target.is_empty(): projectile(sim, "f09", point, (sim._pos(target) - point).normalized(), 2, {"depth": 1, "context": sim.context("f09", "derived", 1), "speed": 600})
			if sim.resonance("hyperion") == "F04-R2" and sim.state.time >= sim.state.orbitPulseAt:
				sim.state.orbitPulseAt = sim.state.time + 1; sim.damage_radius(point, 55, 0.3, sim.context("hyperion", "derived", 1))

	if count >= 4 and sim.state.artifacts.has("a093"):
		var center: Vector2 = sim._pos(sim.state.player)
		for i in range(count / 2):
			var endpoint: Vector2 = center + (sim.orbit_position(i) - center) * 0.65
			var startpoint: Vector2 = center - (endpoint - center)
			var targets := []
			for enemy in sim.state.enemies:
				if Geometry2D.get_closest_point_to_segment(sim._pos(enemy), startpoint, endpoint).distance_to(sim._pos(enemy)) <= enemy.radius + 4: targets.append(enemy.id)
			sim._effect("sword_line", endpoint.x, endpoint.y, 0.08, {"fromX": startpoint.x, "fromY": startpoint.y, "radius": 4})
			sim.emit_event("control", {"sourceId": "orbit", "swordLine": true, "lineTargetIds": targets, "lineId": "orbit-axis-%d" % i, "artifactEffectDamage": 0.3})

static func segment_in_wall(sim, from: Vector2, to: Vector2) -> bool:
	for item in sim.state.fields:
		if item.kind == "wall" and Geometry2D.get_closest_point_to_segment(sim._pos(item), from, to).distance_to(sim._pos(item)) < item.radius: return true
	return false

static func update_fields(sim, dt: float) -> void:
	for item in sim.state.fields.duplicate():
		if not sim.state.fields.has(item): continue
		item.life -= dt; item.nextTick -= dt
		var center: Vector2 = sim._pos(item)
		var tick_interval: float = maxf(0.4, 0.5 + float(sim.modifiers({"sourceId": item.sourceId, "groundEffect": true}).get("hit_interval_add", 0)))
		if item.kind in ["vortex", "well", "glyph", "veil", "burn", "ash", "electric_ring"]: track_ground_occupancy(sim, item)
		if item.kind == "glyph":
			for enemy in sim.state.enemies.duplicate():
				if not (float(enemy.get("dashTime", 0)) > 0 or enemy.get("dashingThisStep", false)): continue
				var previous: Vector2 = enemy.get("previousPosition", sim._pos(enemy))
				if Geometry2D.get_closest_point_to_segment(center, previous, sim._pos(enemy)).distance_to(center) <= item.radius + enemy.radius:
					sim.emit_event("control", {"sourceId": item.sourceId, "dashInGlyph": true, "targetId": enemy.id, "targetKind": enemy.kind, "targetPosition": sim._pos(enemy)})
		if item.kind == "meteor_warning" and sim.has_fusion("f08"): pull(sim, item, dt, 35)
		if item.kind == "well_warning" and item.life <= 0:
			var id := field(sim, "well", center, item.radius, item.duration, {"sourceId": "m12", "context": item.context, "ringHits": {}})
			sim.emit_event("cast", {"sourceId": "m12", "gravityWell": true, "targetPosition": center, "radius": item.radius, "wellId": id})
		if item.kind == "meteor_warning" and item.life <= 0: explode(sim, center, item.get("damageRadius", item.radius), item.damage, item.context, "meteor")
		if item.kind == "ash_warning" and item.life <= 0:
			sim.damage_radius(center, item.radius, item.damage, item.context)
			for enemy in sim.state.enemies:
				if center.distance_to(sim._pos(enemy)) <= item.radius + enemy.radius: sim.apply_status(enemy, "ignite", 3)
		if item.kind == "pulse":
			item.currentRadius = item.radius * clampf(1 - item.life / item.maxLife, 0, 1)
			for enemy in sim.state.enemies.duplicate():
				if item.hitIds.has(enemy.id) or center.distance_to(sim._pos(enemy)) > item.currentRadius + enemy.radius: continue
				item.hitIds.append(enemy.id); sim.apply_damage(enemy, item.damage, item.context)
				if sim.has_fusion("f12") and item.glyphCount < 3:
					field(sim, "glyph", sim._pos(enemy), 45, 1.2, {"sourceId": "f12", "context": sim.context("f12", "derived", 1), "damage": 0.0}); item.glyphCount += 1
			if sim.has_fusion("f15"):
				for mine in sim.state.fields.duplicate():
					if mine.kind == "mine" and center.distance_to(sim._pos(mine)) <= item.currentRadius:
						sim.state.fields.erase(mine); sim.damage_radius(sim._pos(mine), 55, mine.damage, sim.context("f15", "derived", 1))
			if sim.has_fusion("f20"):
				for seed in sim.state.seeds.duplicate():
					if center.distance_to(sim._pos(seed)) <= item.currentRadius: sim.collect_seed(seed)
		elif item.kind == "well":
			pull(sim, item, dt, 90)
			sim.emit_event("cast", {"sourceId": "m12", "gravityWell": true, "targetPosition": center, "radius": item.radius, "wellId": item.id})
			for enemy in sim.state.enemies:
				if center.distance_to(sim._pos(enemy)) <= 20 and not item.hitIds.has(enemy.id):
					item.hitIds.append(enemy.id)
					sim.emit_event("control", {"sourceId": "m12", "centerHit": true, "wellId": item.id, "targetId": enemy.id, "targetKind": enemy.kind, "targetPosition": sim._pos(enemy)})
			if sim.has_fusion("f30") and item.nextTick <= 0:
				for ring in sim.state.fields:
					if ring.kind != "electric_ring" or center.distance_to(sim._pos(ring)) > item.radius + ring.radius: continue
					ring.x = move_toward(ring.x, item.x, 60 * dt); ring.y = move_toward(ring.y, item.y, 60 * dt)
					for enemy in sim.state.enemies.duplicate():
						if center.distance_to(sim._pos(enemy)) <= item.radius and int(item.ringHits.get(str(enemy.id), 0)) < 2:
							item.ringHits[str(enemy.id)] = int(item.ringHits.get(str(enemy.id), 0)) + 1; sim.apply_damage(enemy, 1.5, sim.context("f30", "derived", 1))
				item.nextTick = 0.5
		elif item.kind == "mine":
			for enemy in sim.state.enemies:
				if center.distance_to(sim._pos(enemy)) <= item.radius + enemy.radius:
					sim.damage_radius(center, 60, item.damage, item.context); item.life = 0; break
		elif item.kind == "wall":
			for enemy in sim.state.enemies:
				if in_wall(sim, enemy, item): sim.apply_status(enemy, "slow", 0.5, 0.25)
			if sim.has_fusion("f31") and item.deflected < 8:
				for bullet in sim.state.enemyProjectiles:
					if item.deflected >= 8: break
					if not bullet.get("deflected", false) and not bullet.get("beam", false) and in_wall(sim, bullet, item):
						var velocity := Vector2(bullet.vx, bullet.vy).rotated(PI * 0.5); bullet.vx = velocity.x; bullet.vy = velocity.y; bullet.deflected = true; item.deflected += 1
		elif item.nextTick <= 0 and item.kind in ["vortex", "electric_ring", "glyph", "veil", "burn", "ash", "heal"]:
			if item.kind == "heal":
				if center.distance_to(sim._pos(sim.state.player)) <= item.radius: sim.heal(0.1, "heal-field")
			for enemy in sim.state.enemies.duplicate():
				if center.distance_to(sim._pos(enemy)) > item.radius + enemy.radius: continue
				match item.kind:
					"vortex":
						sim.apply_status(enemy, "slow", 1 + (1 if sim.has_fusion("blizzard") else 0), 0.25)
						var damage: float = item.damage * (1.3 if sim.has_fusion("blizzard") else 1.0)
						if sim.resonance("blizzard") == "F02-R3": damage *= 0.8
						var tick_key := "vortexTickAt"
						if sim.state.time + 0.000001 >= float(enemy.get(tick_key, -1)):
							enemy[tick_key] = sim.state.time + tick_interval
							sim.apply_damage(enemy, damage, item.context)
						if sim.has_fusion("f16"):
							var key := str(enemy.id); item.hits[key] = float(item.hits.get(key, 0.0)) + 0.5
							if item.hits[key] >= 1.5 and sim.state.time >= float(enemy.get("abyssAt", 0)):
								sim.apply_status(enemy, "vulnerable", 3); enemy.abyssAt = sim.state.time + 3
					"electric_ring":
						# A ring's one-second interval persists across re-entry.
						if sim.state.time >= float(item.hits.get(str(enemy.id), 0)):
							item.hits[str(enemy.id)] = sim.state.time + 1; sim.apply_damage(enemy, item.damage, item.context)
					"glyph":
						sim.apply_status(enemy, "slow", 0.7, 0.25)
						if enemy.kind != "boss" and item.damage > 0: sim.apply_damage(enemy, item.damage, item.context)
						if sim.has_fusion("f34") and sim.in_field(sim._pos(enemy), "vortex"): enemy.glyphDashSlow = sim.state.time + 0.7
					"veil": sim.apply_status(enemy, "vulnerable", 3)
					"burn", "ash": sim.apply_status(enemy, "ignite", 3); sim.apply_damage(enemy, item.damage, item.context)
			item.nextTick = tick_interval
		if item.kind == "vortex" and sim.resonance("blizzard") == "F02-R3":
			var movement: Vector2 = (sim._pos(sim.state.player) - center).limit_length(sim.state.player.speed * 0.5 * dt); item.x += movement.x; item.y += movement.y
		if item.life <= 0 or center.distance_to(sim._pos(sim.state.player)) > 950: sim.state.fields.erase(item)

static func in_wall(sim, entity: Dictionary, wall: Dictionary) -> bool:
	var delta: Vector2 = sim._pos(entity) - sim._pos(wall)
	return absf(delta.dot(wall.direction)) <= wall.radius and absf(delta.cross(wall.direction)) <= wall.width + float(entity.get("radius", 0))

static func pull(sim, item: Dictionary, dt: float, speed: float) -> void:
	for enemy in sim.state.enemies:
		if enemy.kind == "boss" or sim._distance(enemy, item) > item.radius: continue
		var movement: Vector2 = (sim._pos(item) - sim._pos(enemy)).limit_length(speed * dt * (0.5 if enemy.kind == "elite" else 1.0))
		enemy.x += movement.x; enemy.y += movement.y

static func on_hit(sim, target: Dictionary, ctx: Dictionary) -> void:
	var source: String = ctx.get("sourceId", "")
	if source == "bolt" and sim.has_fusion("f05"):
		var aim: Vector2 = (sim._pos(target) - sim._pos(sim.state.player)).normalized()
		for angle in [-0.2, 0.2]: projectile(sim, "f05", sim._pos(target), aim.rotated(angle), 1.5, {"depth": 1, "context": sim.context("f05", "derived", 1), "slow": true, "pierce": 1})
	if source == "m13" and sim.has_fusion("f17") and ctx.get("ignited", false):
		var other: Dictionary = sim._nearest(target, 100, [target.id])
		if not other.is_empty(): sim.apply_status(other, "ignite", 3)

static func on_kill(sim, target: Dictionary, _ctx: Dictionary) -> void:
	if target.get("summon", false) or target.kind == "boss" or sim.state.spells.m22 <= 0: return
	sim.state.echoKills += 1
	if sim.has_fusion("f21") and target.kind == "normal" and sim.in_field(sim._pos(target), "well"): sim.state.echoKills += 1
	if sim.state.echoKills >= 13 - sim.state.spells.m22:
		sim.state.echoKills = 0
		if sim.has_fusion("f32") and sim.state.player.hp > sim.state.player.maxHp * 0.5: ash_rain(sim, sim._pos(target), sim.state.spells.m09, sim.context("f32", "derived", 1))
		else: sim.heal(0.5, "m22"); sim._effect("heal", sim.state.player.x, sim.state.player.y, 0.5, {"radius": 70})

static func advance_effects(sim, dt: float) -> void:
	for visual in sim.state.effects.duplicate():
		visual.life -= dt
		if visual.life <= 0: sim.state.effects.erase(visual)
	for enemy in sim.state.enemies.duplicate():
		if not enemy.has("statuses"): enemy.statuses = {}
		for tag in enemy.statuses.keys():
			var status: Dictionary = enemy.statuses[tag]
			status.remaining -= dt
			if tag == "ignite":
				status.nextTick -= dt
				if status.nextTick <= 0: sim.apply_damage(enemy, 0.25, sim.context("ignite", "dot", 1)); status.nextTick = 1.0
			if status.remaining <= 0:
				enemy.statuses.erase(tag)
				if tag == "slow":
					sim.emit_event("control", {"sourceId": "frost", "slowExpired": true, "subtype": "slow_expired", "targetId": enemy.id, "targetPosition": sim._pos(enemy)})
					if sim.resonance("blizzard") == "F02-R2" and sim.state.time >= float(enemy.get("shatterAt", 0)):
						enemy.shatterAt = sim.state.time + 3; sim.apply_damage(enemy, 0.3, sim.context("blizzard", "derived", 1))
	for effect in sim.state.pendingEffects.duplicate():
		effect.delay -= dt
		if effect.delay > 0: continue
		sim.state.pendingEffects.erase(effect)
		var data: Dictionary = effect.data
		if effect.kind == "damage_radius":
			var ctx: Dictionary = data.get("context", sim.context("artifact", "derived", 1)).duplicate(); ctx.depth = 1; ctx.damageKind = "derived"
			sim.damage_radius(data.get("position", sim._pos(sim.state.player)), data.get("radius", 50), data.get("damage", 1), ctx)

static func track_ground_occupancy(sim, item: Dictionary) -> void:
	var old: Array = item.get("occupants", [])
	var current := []
	for enemy in sim.state.enemies.duplicate():
		if sim._distance(item, enemy) <= item.radius + enemy.radius: current.append(enemy.id)
		elif old.has(enemy.id):
			sim.emit_event("control", {"sourceId": item.sourceId, "exitedGround": true, "slowStrength": 0.25, "targetId": enemy.id, "targetKind": enemy.kind, "targetPosition": sim._pos(enemy)})
	item.occupants = current
