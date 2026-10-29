extends RefCounted

var state: Dictionary
var catalog: Dictionary
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 1, mode: String = "quick") -> void:
	var file := FileAccess.open("res://data/content.json", FileAccess.READ)
	catalog = JSON.parse_string(file.get_as_text()) if file else {}
	reset(mode, seed_value)

func reset(mode: String = "quick", seed_value: int = 1) -> void:
	rng.seed = seed_value
	var selected: Dictionary = catalog.get("modes", {}).get(mode, catalog.get("modes", {}).get("quick", {"id": "quick", "duration": 300}))
	state = {
		"phase": "ready", "mode": selected.id, "duration": selected.duration, "endReason": null,
		"time": 0.0, "kills": 0, "level": 1, "xp": 0.0, "xpNeeded": 6.0,
		"player": {"x": 0.0, "y": 0.0, "hp": 6.0, "maxHp": 6.0, "speed": 220.0, "radius": 15.0, "invulnerable": 0.0, "shield": 0},
		"spells": {"bolt": 1, "orbit": 0, "lightning": 0, "frost": 0, "fireball": 0, "vortex": 0, "meteor": 0, "pulse": 0},
		"stats": {"power": 0, "haste": 0, "vitality": 0, "magnet": 0},
		"fusions": [], "artifacts": [], "enemies": [], "projectiles": [], "gems": [], "effects": [], "choices": [],
		"chests": [], "artifactChoices": [], "zones": [], "strikes": [], "hazards": [],
		"bossId": null, "bossSpawned": false, "bossDefeated": false, "bossAttackTimer": 0.0, "nextHazardId": 1,
		"cooldowns": {"bolt": 0.0, "lightning": 0.0, "frost": 0.0, "fireball": 0.0, "vortex": 0.0, "meteor": 0.0, "pulse": 0.0},
		"spawnTimer": 0.8, "eliteTimer": 30.0, "nextEnemyId": 1, "nextChestId": 1, "shieldTimer": 0.0
	}

func start() -> void:
	if state.phase == "ready": state.phase = "playing"

func toggle_pause() -> void:
	if state.phase == "playing": state.phase = "paused"
	elif state.phase == "paused": state.phase = "playing"

func orbit_position(index: int) -> Vector2:
	var count: int = mini(state.spells.orbit, 8)
	var angle: float = state.time * 2.4 + index * PI * 2.0 / maxi(1, count)
	var radius := 105.0 if state.fusions.has("hyperion") else 72.0
	return _pos(state.player) + Vector2(cos(angle), sin(angle)) * radius

func _pos(entity: Dictionary) -> Vector2:
	return Vector2(entity.x, entity.y)

func _distance(a: Dictionary, b: Dictionary) -> float:
	return _pos(a).distance_to(_pos(b))

func _power() -> float:
	return (1.0 + state.stats.power * 0.25) * (1.2 if state.artifacts.has("magicwand") else 1.0)

func _haste() -> float:
	return (1.0 + state.stats.haste * 0.12) * (1.12 if state.artifacts.has("blackcat") else 1.0)

func _effect(kind: String, x: float, y: float, life: float, extra: Dictionary = {}) -> void:
	var visual := {"type": kind, "x": x, "y": y, "life": life, "maxLife": life}
	visual.merge(extra, true)
	state.effects.append(visual)

func _enemy_index(id: int) -> int:
	for i in range(state.enemies.size()):
		if state.enemies[i].id == id: return i
	return -1

func _hurt_enemy(enemy: Dictionary, damage: float) -> void:
	var index := _enemy_index(enemy.id)
	if index < 0: return
	var actual: Dictionary = state.enemies[index]
	actual.hp -= damage
	_effect("hit", actual.x, actual.y, 0.18)
	if actual.hp > 0: return
	state.enemies.remove_at(index)
	if actual.kind == "boss": state.bossDefeated = true
	state.kills += 1
	if actual.kind != "boss":
		state.gems.append({"x": actual.x, "y": actual.y, "value": 4 if actual.kind == "elite" else 1, "radius": 6})
	if actual.kind == "elite":
		state.chests.append({"id": state.nextChestId, "x": actual.x, "y": actual.y})
		state.nextChestId += 1
	_effect("death", actual.x, actual.y, 0.35)

func _nearest(point: Dictionary, distance_limit: float, excluded: Array = []) -> Dictionary:
	var target: Dictionary = {}
	var best := distance_limit
	for enemy in state.enemies:
		if excluded.has(enemy.id): continue
		var distance := _distance(point, enemy)
		if distance < best:
			target = enemy
			best = distance
	return target

func _spawn_enemy(elite: bool = false) -> void:
	if state.enemies.size() >= 200: return
	var angle := rng.randf() * TAU
	var radius := 500.0 + rng.randf() * 200.0
	var swift := not elite and rng.randf() < minf(0.35, state.time / 750.0)
	var kind := "elite" if elite else ("swift" if swift else "normal")
	var hp: float = (30.0 if elite else (4.0 if swift else 3.0)) * (1.0 + state.time / 180.0)
	state.enemies.append({"id": state.nextEnemyId, "x": state.player.x + cos(angle) * radius,
		"y": state.player.y + sin(angle) * radius, "hp": hp, "maxHp": hp,
		"radius": 24 if elite else (11 if swift else 15), "kind": kind,
		"speed": (52.0 if elite else (110.0 if swift else 66.0)) * (1.0 + state.time / 600.0),
		"damage": 2 if elite else 1, "slow": 0.0, "orbitHitUntil": 0.0})
	state.nextEnemyId += 1

func _spawn_boss() -> void:
	if state.bossSpawned: return
	state.bossSpawned = true
	if state.enemies.size() >= 200:
		for i in range(state.enemies.size()):
			if state.enemies[i].kind != "boss":
				state.enemies.remove_at(i)
				break
	state.bossId = state.nextEnemyId
	state.enemies.append({"id": state.nextEnemyId, "kind": "boss", "x": state.player.x + 300.0,
		"y": state.player.y, "hp": 550.0, "maxHp": 550.0, "radius": 38,
		"speed": 245.0, "damage": 2, "slow": 0.0, "orbitHitUntil": 0.0})
	state.nextEnemyId += 1
	state.bossAttackTimer = 0.0

func _warn_boss(boss: Dictionary) -> void:
	if not state.hazards.is_empty(): return
	var targets: Array = [{"kind": "circle", "x": state.player.x, "y": state.player.y, "radius": 70}]
	for i in range(4):
		var angle := i * PI / 2.0
		targets.append({"kind": "ray", "x": boss.x + cos(angle) * 130.0, "y": boss.y + sin(angle) * 130.0, "radius": 52})
	for target in targets:
		target.merge({"id": state.nextHazardId, "warning": 1.0, "active": 0.6, "hit": false})
		state.nextHazardId += 1
		state.hazards.append(target)

func _hurt_player(damage: float) -> void:
	var player: Dictionary = state.player
	if player.invulnerable > 0: return
	if player.shield:
		player.shield = 0
		state.shieldTimer = 15.0
	else: player.hp = maxf(0.0, player.hp - damage)
	player.invulnerable = 0.65
	_effect("hit", player.x, player.y, 0.3)

func _update_hazards(dt: float) -> void:
	var remaining := []
	for hazard in state.hazards:
		if hazard.warning > 0:
			hazard.warning = maxf(0, hazard.warning - dt)
		else:
			hazard.active -= dt
			if not hazard.hit and hazard.active > 0 and _distance(hazard, state.player) < hazard.radius + state.player.radius:
				hazard.hit = true
				_hurt_player(1)
		if hazard.warning > 0 or hazard.active > 0: remaining.append(hazard)
	state.hazards = remaining

func _pick(items: Array) -> Dictionary:
	return items.pop_at(rng.randi_range(0, items.size() - 1))

func _offer_upgrade() -> void:
	state.level += 1
	state.xp -= state.xpNeeded
	state.xpNeeded = 6 + (state.level - 1) * 3
	var available := []
	var unlearned := []
	for item in catalog.upgrades:
		if catalog.spellIds.has(item.id) and state.spells[item.id] >= 5: continue
		available.append(item)
		if catalog.spellIds.has(item.id) and state.spells[item.id] == 0: unlearned.append(item)
	var fusions := []
	for item in catalog.fusions:
		if state.fusions.has(item.id): continue
		var eligible := true
		for spell in item.requires:
			if state.spells[spell] < item.requires[spell]: eligible = false
		if eligible: fusions.append(item)
	state.choices = []
	while not fusions.is_empty() and state.choices.size() < 3 - (1 if not unlearned.is_empty() else 0):
		state.choices.append(_pick(fusions))
	if not unlearned.is_empty():
		var choice := _pick(unlearned)
		state.choices.append(choice)
		available.erase(choice)
	while state.choices.size() < 3 and not available.is_empty(): state.choices.append(_pick(available))
	state.phase = "upgrade"

func choose_upgrade(id: String) -> bool:
	if state.phase != "upgrade": return false
	var offered := false
	for item in state.choices:
		if item.id == id: offered = true
	if not offered: return false
	var fusion: Dictionary = {}
	for item in catalog.fusions:
		if item.id == id: fusion = item
	if not fusion.is_empty():
		if state.fusions.has(id): return false
		for spell in fusion.requires:
			if state.spells[spell] < fusion.requires[spell]: return false
		state.fusions.append(id)
	elif state.spells.has(id):
		if state.spells[id] >= 5: return false
		state.spells[id] += 1
	elif state.stats.has(id):
		state.stats[id] += 1
		if id == "vitality":
			state.player.maxHp += 2
			state.player.hp = minf(state.player.maxHp, state.player.hp + 2)
			_effect("heal", state.player.x, state.player.y, 0.5)
	else: return false
	state.choices = []
	state.phase = "playing"
	if state.xp >= state.xpNeeded: _offer_upgrade()
	return true

func _offer_artifact() -> void:
	var available := []
	for item in catalog.artifacts:
		if not state.artifacts.has(item.id): available.append(item)
	if available.is_empty():
		state.player.hp = minf(state.player.maxHp, state.player.hp + 2)
		_effect("heal", state.player.x, state.player.y, 0.5)
		return
	state.artifactChoices = []
	while state.artifactChoices.size() < 3 and not available.is_empty(): state.artifactChoices.append(_pick(available))
	state.phase = "artifact"

func choose_artifact(id: String) -> bool:
	if state.phase != "artifact" or state.artifacts.has(id): return false
	var offered := false
	for item in state.artifactChoices:
		if item.id == id: offered = true
	if not offered: return false
	state.artifacts.append(id)
	if id == "broom": state.player.speed *= 1.15
	if id == "secondheart":
		state.player.maxHp += 3
		state.player.hp = minf(state.player.maxHp, state.player.hp + 3)
		_effect("heal", state.player.x, state.player.y, 0.5)
	if id == "aegis": state.player.shield = 1
	state.artifactChoices = []
	state.phase = "playing"
	if state.xp >= state.xpNeeded: _offer_upgrade()
	return true

func _blast(x: float, y: float, radius: float, damage: float) -> void:
	_effect("explosion", x, y, 0.35, {"radius": radius})
	for enemy in state.enemies.duplicate():
		if Vector2(x, y).distance_to(_pos(enemy)) <= radius + enemy.radius: _hurt_enemy(enemy, damage)

func tick(dt: float, input: Vector2 = Vector2.ZERO) -> void:
	if state.phase != "playing" or not is_finite(dt) or dt <= 0: return
	dt = minf(dt, 0.05)
	state.time = minf(state.duration, state.time + dt)
	var player: Dictionary = state.player
	var direction := input.limit_length(1.0)
	player.x += direction.x * player.speed * dt
	player.y += direction.y * player.speed * dt
	player.invulnerable = maxf(0, player.invulnerable - dt)
	if state.artifacts.has("worldtreeleaf"): player.hp = minf(player.maxHp, player.hp + 0.06 * dt)
	if state.artifacts.has("aegis") and not player.shield:
		state.shieldTimer -= dt
		if state.shieldTimer <= 0: player.shield = 1
	for visual in state.effects:
		visual.life -= dt
		if visual.type == "pulse":
			visual.radius = visual.maxRadius * minf(1, 1 - visual.life / visual.maxLife)
			for enemy in state.enemies.duplicate():
				if not visual.hitIds.has(enemy.id) and _distance(visual, enemy) <= visual.radius + enemy.radius:
					visual.hitIds.append(enemy.id)
					_hurt_enemy(enemy, visual.damage)
	var kept := []
	for visual in state.effects:
		if visual.life > 0: kept.append(visual)
	state.effects = kept
	kept = []
	for enemy in state.enemies:
		if enemy.kind == "boss" or _distance(enemy, player) < 950: kept.append(enemy)
	state.enemies = kept
	kept = []
	for chest in state.chests:
		if _distance(chest, player) < 950: kept.append(chest)
	state.chests = kept
	kept = []
	for gem in state.gems:
		if _distance(gem, player) < 950: kept.append(gem)
	state.gems = kept
	if state.mode == "expedition" and state.time >= 510: _spawn_boss()
	state.spawnTimer -= dt
	if state.spawnTimer <= 0:
		for i in range(mini(7, 1 + int(floor(state.time / 50.0)))): _spawn_enemy()
		state.spawnTimer = maxf(0.35, 1.25 - state.time / 360.0)
	state.eliteTimer -= dt
	if state.eliteTimer <= 0:
		_spawn_enemy(true)
		state.eliteTimer = maxf(16, 30 - state.time / 25.0)
	for enemy in state.enemies:
		var delta := _pos(player) - _pos(enemy)
		if delta.length() > 0:
			var factor := 1.0 if enemy.slow <= 0 else (0.9 if enemy.kind == "boss" else 0.45)
			var step: float = enemy.speed * factor * dt
			var movement := delta.normalized() * minf(step, delta.length())
			enemy.x += movement.x
			enemy.y += movement.y
		enemy.slow = maxf(0, enemy.slow - dt)
		if _distance(enemy, player) < enemy.radius + player.radius: _hurt_player(enemy.damage)
	if state.mode == "expedition":
		var boss_index := _enemy_index(state.bossId) if state.bossId != null else -1
		if boss_index >= 0 and not state.bossDefeated:
			state.bossAttackTimer -= dt
			if state.bossAttackTimer <= 0:
				_warn_boss(state.enemies[boss_index])
				state.bossAttackTimer = 3.0
		_update_hazards(dt)
	_cast_bolt(dt)
	_update_projectiles(dt)
	_cast_orbit()
	_cast_lightning(dt)
	_cast_frost(dt)
	_cast_fireball(dt)
	_cast_vortex(dt)
	_update_zones(dt)
	_cast_meteor(dt)
	_update_strikes(dt)
	_cast_pulse(dt)
	_collect_gems(dt)
	if state.bossDefeated: state.hazards = []
	if player.hp <= 0:
		state.phase = "lost"
		state.endReason = "death"
	elif state.time >= state.duration:
		state.phase = "won" if state.mode == "quick" else "lost"
		state.endReason = "survived" if state.mode == "quick" else "timeout"
	elif state.bossDefeated:
		state.phase = "won"
		state.endReason = "boss-defeated"
	else:
		for chest in state.chests:
			if _distance(chest, player) <= 50:
				state.chests.erase(chest)
				_offer_artifact()
				break
		if state.phase == "playing" and state.xp >= state.xpNeeded: _offer_upgrade()

func _cast_bolt(dt: float) -> void:
	state.cooldowns.bolt -= dt
	if state.cooldowns.bolt > 0: return
	var target := _nearest(state.player, 540)
	if target.is_empty(): return
	var delta := (_pos(target) - _pos(state.player)).normalized()
	if state.fusions.has("plasma"):
		_effect("beam", state.player.x + delta.x * 540, state.player.y + delta.y * 540, 0.2, {"fromX": state.player.x, "fromY": state.player.y, "radius": 14})
		for enemy in state.enemies.duplicate():
			var relative := _pos(enemy) - _pos(state.player)
			var along := relative.dot(delta)
			var across := absf(relative.cross(delta))
			if along >= 0 and along <= 540 and across <= enemy.radius + 14: _hurt_enemy(enemy, (2 + state.spells.bolt) * 1.3 * _power())
	else:
		state.projectiles.append({"x": state.player.x, "y": state.player.y, "vx": delta.x * 460, "vy": delta.y * 460, "radius": 6, "damage": (2 + state.spells.bolt) * _power(), "life": 1.4})
		_effect("bolt", state.player.x, state.player.y, 0.12)
	state.cooldowns.bolt = maxf(0.15, 0.65 / _haste())

func _update_projectiles(dt: float) -> void:
	for projectile in state.projectiles:
		projectile.x += projectile.vx * dt
		projectile.y += projectile.vy * dt
		projectile.life -= dt
		var target: Dictionary = {}
		for enemy in state.enemies:
			if _distance(projectile, enemy) <= projectile.radius + enemy.radius:
				target = enemy
				break
		if not target.is_empty():
			if projectile.get("kind", "") == "fireball": _blast(projectile.x, projectile.y, projectile.explosionRadius, projectile.damage)
			else: _hurt_enemy(target, projectile.damage)
			projectile.life = 0
		elif projectile.life <= 0 and projectile.get("kind", "") == "fireball": _blast(projectile.x, projectile.y, projectile.explosionRadius, projectile.damage)
	var kept := []
	for projectile in state.projectiles:
		if projectile.life > 0: kept.append(projectile)
	state.projectiles = kept

func _cast_orbit() -> void:
	for i in range(mini(state.spells.orbit, 8)):
		var pos := orbit_position(i)
		for enemy in state.enemies.duplicate():
			if pos.distance_to(_pos(enemy)) < enemy.radius + 12 and enemy.orbitHitUntil <= state.time:
				enemy.orbitHitUntil = state.time + 0.45
				_hurt_enemy(enemy, (1.5 + state.spells.orbit * 0.5) * _power() * (1.5 if state.fusions.has("hyperion") else 1.0) * (1.25 if state.artifacts.has("circularsawblade") else 1.0))

func _cast_lightning(dt: float) -> void:
	state.cooldowns.lightning -= dt
	if state.spells.lightning == 0 or state.cooldowns.lightning > 0: return
	var from: Dictionary = state.player
	var used := []
	for i in range(mini(8, state.spells.lightning + 1 + (1 if state.artifacts.has("battery") else 0))):
		var target := _nearest(from, 160 if i else 360, used)
		if target.is_empty(): break
		used.append(target.id)
		_effect("lightning", target.x, target.y, 0.24, {"fromX": from.x, "fromY": from.y})
		_hurt_enemy(target, (3 + state.spells.lightning) * _power())
		from = target
	state.cooldowns.lightning = maxf(0.5, 2.7 / _haste())

func _cast_frost(dt: float) -> void:
	state.cooldowns.frost -= dt
	if state.spells.frost == 0 or state.cooldowns.frost > 0: return
	var radius: float = 120 + (state.spells.frost - 1) * 18 + (45 if state.fusions.has("blizzard") else 0)
	_effect("frost", state.player.x, state.player.y, 0.45, {"radius": radius})
	for enemy in state.enemies.duplicate():
		if _distance(state.player, enemy) < radius + enemy.radius:
			enemy.slow = 2 + (1 if state.fusions.has("blizzard") else 0) + (1 if state.artifacts.has("snowflakecrown") else 0)
			_hurt_enemy(enemy, (1.5 + state.spells.frost * 0.5) * _power())
	state.cooldowns.frost = maxf(1, 4.0 / _haste())

func _cast_fireball(dt: float) -> void:
	state.cooldowns.fireball -= dt
	if state.spells.fireball == 0 or state.cooldowns.fireball > 0: return
	var target := _nearest(state.player, 480)
	if target.is_empty(): return
	var direction := (_pos(target) - _pos(state.player)).normalized()
	var fused: bool = state.fusions.has("supernova")
	state.projectiles.append({"kind": "fireball", "x": state.player.x, "y": state.player.y,
		"vx": direction.x * 340, "vy": direction.y * 340, "radius": 10, "life": 1.5,
		"explosionRadius": 65 + state.spells.fireball * 8 + (45 if fused else 0),
		"damage": (3 + state.spells.fireball) * _power() * (1.5 if fused else 1.0) * (1.3 if state.artifacts.has("ruby") else 1.0)})
	_effect("fireball", state.player.x, state.player.y, 0.2, {"radius": 14})
	state.cooldowns.fireball = maxf(0.7, 3.0 / _haste())

func _cast_vortex(dt: float) -> void:
	state.cooldowns.vortex -= dt
	if state.spells.vortex == 0 or state.cooldowns.vortex > 0: return
	var target := _nearest(state.player, 400)
	if target.is_empty(): return
	state.zones.append({"x": target.x, "y": target.y, "radius": 70 + state.spells.vortex * 12 + (35 if state.fusions.has("blizzard") else 0), "life": 3.0, "maxLife": 3.0, "nextTick": 0.0})
	state.cooldowns.vortex = maxf(1.5, 5.0 / _haste())

func _update_zones(dt: float) -> void:
	for zone in state.zones:
		zone.life -= dt
		zone.nextTick -= dt
		if zone.nextTick <= 0:
			_effect("vortex", zone.x, zone.y, 0.45, {"radius": zone.radius})
			for enemy in state.enemies.duplicate():
				if _distance(zone, enemy) <= zone.radius + enemy.radius:
					enemy.slow = maxf(enemy.slow, 1 + (1 if state.fusions.has("blizzard") else 0) + (1 if state.artifacts.has("snowflakecrown") else 0))
					_hurt_enemy(enemy, (1 + state.spells.vortex * 0.5) * _power() * (1.3 if state.fusions.has("blizzard") else 1.0))
			zone.nextTick = 0.5
	var kept := []
	for zone in state.zones:
		if zone.life > 0 and _distance(zone, state.player) < 950: kept.append(zone)
	state.zones = kept

func _cast_meteor(dt: float) -> void:
	state.cooldowns.meteor -= dt
	if state.spells.meteor == 0 or state.cooldowns.meteor > 0: return
	var target := _nearest(state.player, 550)
	if target.is_empty(): return
	var radius: float = 95 + state.spells.meteor * 12 + (50 if state.fusions.has("supernova") else 0)
	state.strikes.append({"x": target.x, "y": target.y, "radius": radius, "life": 0.7, "maxLife": 0.7})
	_effect("meteor", target.x, target.y, 0.7, {"radius": radius})
	state.cooldowns.meteor = maxf(2, 6.0 / _haste())

func _update_strikes(dt: float) -> void:
	for strike in state.strikes:
		strike.life -= dt
		if strike.life <= 0:
			_blast(strike.x, strike.y, strike.radius, (5 + state.spells.meteor * 2) * _power() * (1.5 if state.fusions.has("supernova") else 1.0) * (1.3 if state.artifacts.has("ruby") else 1.0))
	var kept := []
	for strike in state.strikes:
		if strike.life > 0 and _distance(strike, state.player) < 950: kept.append(strike)
	state.strikes = kept

func _cast_pulse(dt: float) -> void:
	state.cooldowns.pulse -= dt
	if state.spells.pulse == 0 or state.cooldowns.pulse > 0: return
	_effect("pulse", state.player.x, state.player.y, 0.6, {"radius": 0.0,
		"maxRadius": 120 + state.spells.pulse * 22 + (50 if state.fusions.has("hyperion") else 0),
		"damage": (2 + state.spells.pulse) * _power() * (1.4 if state.fusions.has("hyperion") else 1.0), "hitIds": []})
	state.cooldowns.pulse = maxf(0.8, 3.3 / _haste())

func _collect_gems(dt: float) -> void:
	var kept := []
	for gem in state.gems:
		var delta := _pos(state.player) - _pos(gem)
		var distance := delta.length()
		if distance < 175 + state.stats.magnet * 50 + (80 if state.artifacts.has("radar") else 0) and distance > 0:
			var step := minf(distance, (320 + state.stats.magnet * 60) * dt)
			gem.x += delta.x / distance * step
			gem.y += delta.y / distance * step
		if _distance(gem, state.player) < 42 + state.stats.magnet * 30 + gem.get("radius", 0):
			state.xp += gem.value * (1.25 if state.artifacts.has("sapphire") else 1.0)
		else: kept.append(gem)
	state.gems = kept
