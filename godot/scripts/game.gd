extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const ReleaseSimulation = preload("res://scripts/release_simulation.gd")
const Progression = preload("res://scripts/progression.gd")
const Records = preload("res://scripts/records.gd")
const Hud = preload("res://scripts/hud.gd")
const INK = Color("#0b1016")
const ZONE_BASES = {
	"Z01": Color("#7d8065"), "Z02": Color("#747774"), "Z03": Color("#6e806c"),
	"Z04": Color("#a29b88"), "Z05": Color("#777584"), "Z06": Color("#917466"),
}
const PLAYER_SPRITE = "res://assets/generated/player-ink.png"
const ENEMY_SPRITE = "res://assets/generated/enemy-ink.png"
const BOSS_SPRITE = "res://assets/generated/boss-ink.png"
const BOSS_SPRITES = {
	"B01": BOSS_SPRITE,
	"B02": "res://assets/generated/release-bosses/b02.png",
	"B03": "res://assets/generated/release-bosses/b03.png",
	"B04": "res://assets/generated/release-bosses/b04.png",
	"B05": "res://assets/generated/release-bosses/b05.png",
	"B06": "res://assets/generated/release-bosses/b06.png",
}
const BOSS_SIZES = {
	"B01": Vector2(63, 70), "B02": Vector2(70, 70), "B03": Vector2(92, 52),
	"B04": Vector2(60, 82), "B05": Vector2(70, 80), "B06": Vector2(62, 90),
}
const GROUND_TEXTURE = "res://assets/generated/ground-olive.png"
const ZONE_GROUNDS = {
	"Z01": preload("res://assets/generated/ground-olive.png"),
	"Z02": preload("res://assets/generated/release-maps/z02-ground.png"),
	"Z03": preload("res://assets/generated/release-maps/z03-ground.png"),
	"Z04": preload("res://assets/generated/release-maps/z04-ground.png"),
	"Z05": preload("res://assets/generated/release-maps/z05-ground.png"),
	"Z06": preload("res://assets/generated/release-maps/z06-ground.png"),
}
const REQUIRED_TEXTURES = {
	PLAYER_SPRITE: preload("res://assets/generated/player-ink.png"),
	ENEMY_SPRITE: preload("res://assets/generated/enemy-ink.png"),
	BOSS_SPRITE: preload("res://assets/generated/boss-ink.png"),
	"res://assets/generated/release-bosses/b02.png": preload("res://assets/generated/release-bosses/b02.png"),
	"res://assets/generated/release-bosses/b03.png": preload("res://assets/generated/release-bosses/b03.png"),
	"res://assets/generated/release-bosses/b04.png": preload("res://assets/generated/release-bosses/b04.png"),
	"res://assets/generated/release-bosses/b05.png": preload("res://assets/generated/release-bosses/b05.png"),
	"res://assets/generated/release-bosses/b06.png": preload("res://assets/generated/release-bosses/b06.png"),
	GROUND_TEXTURE: preload("res://assets/generated/ground-olive.png"),
}

var sim: RefCounted
var records: RefCounted
var profile: RefCounted
var selected_zone := "Z01"
var selected_class := "C01"
var challenge_seed := 1
var practice_suspended := false
var settlement: Dictionary = {}
var hud: CanvasLayer
var selected_mode := "campaign"
var save_done := false
var record_error := ""
var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var fixed_step := 0.0
var _textures := {}
var _sprite_regions := {}
var _presentation: Dictionary = {}

func _ready() -> void:
	DisplayServer.window_set_title("Magic Survival Lab")
	get_viewport().gui_release_focus()
	sim = Simulation.new(1, "quick")
	records = Records.new()
	records.load_records()
	profile = Progression.new()
	profile.load_profile()
	record_error = profile.last_error if profile.last_error != "" else records.last_error
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_refresh_hud()

func begin(mode: String) -> void:
	selected_mode = mode if mode in ["quick", "expedition", "campaign", "practice", "seededchallenge"] else "campaign"
	var seed_value := challenge_seed if selected_mode == "seededchallenge" else Time.get_ticks_usec()
	if selected_mode in ["quick", "expedition"]:
		sim = Simulation.new(seed_value, selected_mode)
	else:
		sim = ReleaseSimulation.new(seed_value, selected_mode, {"zoneId": selected_zone, "classId": selected_class, "research": profile.data.equipped.duplicate(), "runId": "run-%d-%d" % [seed_value, randi()]})
	profile.set_in_run(true)
	sim.start()
	save_done = false
	settlement = {}
	practice_suspended = false
	record_error = ""
	fixed_step = 0.0
	_clear_touch()
	_refresh_hud()
	queue_redraw()

func pause_run() -> void:
	if sim.state.get("phase") in ["playing", "paused"]:
		sim.toggle_pause()
		_clear_touch()
		fixed_step = 0.0
		_refresh_hud()

func choose(id: String) -> void:
	var phase: String = sim.state.get("phase", "")
	if phase == "upgrade":
		sim.choose_upgrade(id)
	elif phase == "artifact":
		sim.choose_artifact(id)
	_clear_touch()
	_refresh_hud()

func go_home() -> void:
	practice_suspended = false
	profile.set_in_run(false)
	_clear_touch()
	fixed_step = 0.0
	sim = Simulation.new(1, "quick")
	_refresh_hud()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if sim != null and sim.state.get("phase") == "playing":
			pause_run()
		elif sim != null and sim.state.get("phase") == "event_practice":
			practice_suspended = true
			_clear_touch()
			_refresh_hud()

func _input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		_clear_touch()
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_position = event.position
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.keycode == KEY_BACK or key == KEY_BACK:
			if sim.state.get("phase") == "playing":
				pause_run()
			elif sim.state.get("phase") == "event_practice":
				practice_suspended = true
				_refresh_hud()
			get_viewport().set_input_as_handled()
		elif key in [KEY_P, KEY_ESCAPE]:
			if sim.state.get("phase") in ["playing", "paused"]:
				pause_run()
				get_viewport().set_input_as_handled()
		elif key in [KEY_1, KEY_2, KEY_3]:
			var options: Array = sim.state.get("choices", []) if sim.state.get("phase") == "upgrade" else sim.state.get("artifactChoices", [])
			var index: int = key - KEY_1
			if sim.state.get("phase") in ["upgrade", "artifact"] and index < options.size():
				choose(str(options[index].get("id", "")))
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if sim == null or sim.state.get("phase") != "playing":
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			touch_origin = event.position
			touch_position = event.position
		elif not event.pressed and event.index == touch_id:
			_clear_touch()
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_position = event.position

func _process(delta: float) -> void:
	if sim == null:
		return
	if sim.state.get("phase") == "event_practice" and sim.has_method("tick_practice"):
		if not practice_suspended: sim.tick_practice(delta)
		_refresh_hud()
		queue_redraw()
	elif sim.state.get("phase") == "playing":
		fixed_step = minf(fixed_step + delta, 0.15)
		while fixed_step >= 1.0 / 60.0 and sim.state.get("phase") == "playing":
			sim.tick(1.0 / 60.0, _movement())
			fixed_step -= 1.0 / 60.0
		if sim.state.get("phase") != "playing":
			_clear_touch()
			fixed_step = 0.0
		if sim.state.get("phase") in ["won", "lost"] and not save_done:
			save_done = true
			if selected_mode in ["quick", "expedition"]:
				if not records.record(sim.state):
					record_error = records.last_error
			elif selected_mode == "campaign":
				settlement = profile.complete_run(sim.state)
				if not settlement.get("ok", false): record_error = str(settlement.get("error", ""))
			profile.set_in_run(false)
		_refresh_hud()
		queue_redraw()

func _movement() -> Vector2:
	var x := float(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var y := float(Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	var move := Vector2(x, y)
	if touch_id != -1:
		move += (touch_position - touch_origin).limit_length(72.0) / 72.0
	return move.limit_length(1.0)

func _clear_touch() -> void:
	touch_id = -1
	touch_origin = Vector2.ZERO
	touch_position = Vector2.ZERO

func _refresh_hud() -> void:
	if hud != null:
		hud.refresh(sim.state, sim.catalog, records.for_mode(selected_mode) if selected_mode in ["quick", "expedition"] else profile.for_zone(selected_zone), record_error)

func _world(point: Dictionary) -> Vector2:
	var p: Dictionary = sim.state.get("player", {})
	return get_viewport_rect().size * 0.5 + Vector2(float(point.get("x", 0)) - float(p.get("x", 0)), float(point.get("y", 0)) - float(p.get("y", 0)))

func _draw() -> void:
	var size := get_viewport_rect().size
	var phase: String = sim.state.get("phase", "ready") if sim != null else "ready"
	if phase == "ready":
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		return
	var p: Dictionary = sim.state.get("player", {})
	var center := size * 0.5
	_presentation = sim.presentation_modifiers() if sim.has_method("presentation_modifiers") else {}
	_draw_ground(size, Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
	for zone in sim.state.get("zones", []):
		var at := _world(zone)
		var radius := float(zone.get("radius", 50))
		draw_circle(at, radius, Color(0.16, 0.18, 0.12, 0.13))
		draw_arc(at, radius, 0, TAU, 48, Color(0.45, 0.62, 0.35, 0.5), 2.0)
	for strike in sim.state.get("strikes", []):
		var at := _world(strike)
		var radius := float(strike.get("radius", 75))
		draw_arc(at, radius, 0, TAU, 48, Color("#f3e3a1"), 2.0)
		draw_line(at + Vector2(-radius * .55, 0), at + Vector2(radius * .55, 0), Color("#fff2c7"), 2)
	for hazard in sim.state.get("hazards", []) + sim.state.get("practiceHazards", []):
		_draw_hazard(hazard)
	for field in sim.state.get("fields", []):
		var at := _world(field)
		var radius := float(field.get("radius", 24))
		var warning: bool = str(field.get("kind", "")).contains("warning")
		draw_arc(at, radius, 0, TAU, 40, Color("#e5d49e") if warning else Color("#b9adf4"), 2)
		if not warning: draw_circle(at, radius, Color(0.35, 0.25, 0.6, 0.12))
	for marker in sim.state.get("events", []):
		if marker.get("status", "") == "placed":
			var at := _world(marker)
			if sim.has_method("presentation_modifiers"):
				var mods: Dictionary = _presentation
				var delta := Vector2(float(marker.x) - float(p.x), float(marker.y) - float(p.y))
				if delta.length() <= float(mods.eventMarkerRange) and (absf(at.x - center.x) > size.x * .45 or absf(at.y - center.y) > size.y * .45):
					var edge := center + delta.normalized() * minf(size.x, size.y) * .4
					draw_circle(edge, 5, Color("#70e0da"))
			draw_arc(at, 15, 0, TAU, 24, Color("#70e0da"), 2)
			draw_line(at + Vector2(0, -9), at + Vector2(0, 5), Color.WHITE, 2)
			draw_circle(at + Vector2(0, 9), 2, Color.WHITE)
	var resonance: Dictionary = sim.state.get("resonanceMarker", {})
	if not resonance.is_empty():
		var at := _world(resonance)
		draw_arc(at, 18, 0, TAU, 24, Color("#e9d7ff"), 2)
		draw_line(at + Vector2(-10, 0), at + Vector2(10, 0), Color.WHITE, 2)
		draw_line(at + Vector2(0, -10), at + Vector2(0, 10), Color.WHITE, 2)
	for seed in sim.state.get("seeds", []):
		var at := _world(seed)
		draw_circle(at, 6, Color("#c7ed8b")); draw_line(at, at + Vector2(0, -8), Color("#efffcd"), 2)
	for projectile in sim.state.get("enemyProjectiles", []):
		var at := _world(projectile)
		draw_circle(at, float(projectile.get("radius", 5)) + 3, Color(0.9, 0.25, 0.2, 0.24))
		draw_circle(at, float(projectile.get("radius", 5)), Color("#ffa878"))
	var hints: Dictionary = sim.state.get("researchHints", {})
	if hints.get("bossFirstDirection", false) and hints.has("bossFirstPreview") and int(sim.state.get("bossPattern", 0)) == 1:
		var showing_warning := false
		for hazard in sim.state.get("hazards", []):
			if hazard.get("owner") == "boss" and float(hazard.get("warning", 0)) > 0: showing_warning = true
		if showing_warning:
			var first: Dictionary = hints.bossFirstPreview
			var origin: Vector2 = first.origin
			var at := _world({"x": origin.x, "y": origin.y})
			var forward := Vector2.from_angle(float(first.angle))
			draw_line(at, at + forward * 70, Color("#fff0ae"), 4)
			var side := Vector2(-forward.y, forward.x)
			draw_colored_polygon(PackedVector2Array([at + forward * 80, at + forward * 62 + side * 7, at + forward * 62 - side * 7]), Color("#fff0ae"))
	if hints.get("firstPhenomenonPreview", false) and hints.has("nextPhenomenon"):
		var preview: Dictionary = hints.nextPhenomenon
		if preview.has("position") and float(sim.state.get("time", 0)) < float(preview.get("time", 0)):
			var point: Vector2 = preview.position
			var at := _world({"x": point.x, "y": point.y})
			draw_arc(at, 24, 0, TAU, 24, Color("#e8dca6"), 2)
			draw_string(Hud.BODY_FONT, at + Vector2(-12, -30), "예상", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#f8edc8"))
	if hints.get("elitePreview", false) and hints.has("elitePreviewPosition"):
		var preview: Vector2 = hints.elitePreviewPosition
		var at := _world({"x": preview.x, "y": preview.y})
		draw_arc(at, 22, 0, TAU, 24, Color("#f4d491"), 2)
	if hints.get("chestDirection", false):
		var chest := _nearest_target(sim.state.get("chests", []), p)
		if not chest.is_empty(): _draw_direction(chest, Color("#fff4bd"))
	if hints.get("xpDirection", false):
		var gem := _nearest_target(sim.state.get("gems", []), p)
		if not gem.is_empty(): _draw_direction(gem, Color("#50b9ff"))
	if hints.get("eventDirection", false):
		var placed := []
		for event in sim.state.get("events", []):
			if event.get("status") == "placed": placed.append(event)
		var marker := _nearest_target(placed, p)
		if not marker.is_empty(): _draw_direction(marker, Color("#70e0da"))
	if hints.get("eventRewardCategory", false):
		for marker in sim.state.get("events", []):
			if marker.get("status") != "placed": continue
			var category := _event_reward_category(str(marker.id))
			draw_string(Hud.BODY_FONT, Vector2(clampf(_world(marker).x, 40, size.x - 65), clampf(_world(marker).y - 22, 90, size.y - 40)), category, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e8fff4"))
	for gem in sim.state.get("gems", []):
		var at := _world(gem)
		draw_circle(at, 5.0, Color(0.12, 0.53, 1.0, 0.24))
		draw_circle(at, 2.8, Color("#18a6ff"))
		draw_circle(at, 1.2, Color.WHITE)
	for chest in sim.state.get("chests", []):
		var at := _world(chest)
		if sim.has_method("presentation_modifiers"):
			var mods: Dictionary = _presentation
			var delta := Vector2(float(chest.x) - float(p.x), float(chest.y) - float(p.y))
			if delta.length() <= float(mods.chestMarkerRange) and (absf(at.x - center.x) > size.x * .45 or absf(at.y - center.y) > size.y * .45):
				var edge := center + delta.normalized() * minf(size.x, size.y) * .4
				draw_circle(edge, 5, Color("#f2eee2"))
		draw_circle(at, 15, Color(0.08, 0.08, 0.06, 0.25))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -10), at + Vector2(8, 0), at + Vector2(0, 10), at + Vector2(-8, 0)]), Color("#f2eee2"))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -7), at + Vector2(5, 0), at + Vector2(0, 7), at + Vector2(-5, 0)]), Color("#161611"))
	for enemy in sim.state.get("enemies", []):
		_draw_enemy(enemy)
	for projectile in sim.state.get("projectiles", []):
		_draw_projectile(projectile)
	for effect in sim.state.get("effects", []):
		_draw_effect(effect)
	var orbit_count := mini(8, int(sim.state.get("spells", {}).get("orbit", 0)))
	for i in range(orbit_count):
		var orbit_pos: Vector2 = sim.orbit_position(i)
		var at := center + orbit_pos - Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		draw_circle(at, 12, Color(0.64, 0.55, 1, 0.12))
		draw_circle(at, 6, Color("#ece0ff"))
		draw_circle(at, 3, Color.WHITE)
	if int(p.get("shield", 0)) > 0:
		draw_arc(center, 22, 0, TAU, 40, Color("#d6e5ed"), 2)
	if float(p.get("invulnerable", 0)) <= 0 or fmod(float(sim.state.get("time", 0)) * 12, 2) < 1:
		_draw_shadow(center + Vector2(0, 15), 12)
		_draw_sprite(PLAYER_SPRITE, center + Vector2(0, -2), Vector2(28, 32))
	var health := clampf(float(p.get("hp", 0)) / maxf(1, float(p.get("maxHp", 1))), 0, 1)
	draw_rect(Rect2(center + Vector2(-12, 18), Vector2(24, 3)), Color("#25261a"))
	draw_rect(Rect2(center + Vector2(-12, 18), Vector2(24 * health, 3)), Color("#5ae321"))
	if touch_id != -1:
		draw_arc(touch_origin, 54, 0, TAU, 40, Color(1, 1, 1, 0.19), 1)
		draw_circle(touch_origin + (touch_position - touch_origin).limit_length(54), 13, Color(1, 1, 1, 0.23))

func _nearest_target(items: Array, player: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INF
	var origin := Vector2(float(player.get("x", 0)), float(player.get("y", 0)))
	for item in items:
		var distance := origin.distance_squared_to(Vector2(float(item.get("x", 0)), float(item.get("y", 0))))
		if distance < best_distance: best_distance = distance; best = item
	return best

func _draw_direction(target: Dictionary, color: Color) -> void:
	var size := get_viewport_rect().size
	var center := size * .5
	var at := _world(target)
	if absf(at.x - center.x) <= size.x * .43 and absf(at.y - center.y) <= size.y * .43: return
	var direction := (at - center).normalized()
	var edge := center + direction * minf(size.x, size.y) * .4
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([edge + direction * 8, edge - direction * 6 + side * 5, edge - direction * 6 - side * 5]), color)

func _event_reward_category(id: String) -> String:
	if id == "E01": return "회복/경험치"
	if id == "E09": return "회복"
	if id in ["E02", "E03", "E05"]: return "유물"
	if id == "E06": return "경험치"
	if id == "E08": return "마법"
	return "정보"

func _draw_hazard(hazard: Dictionary) -> void:
	var at := _world(hazard)
	var radius := float(hazard.get("radius", 70))
	var active := _hazard_is_active(hazard)
	var color := Color(0.8, 0.19, 0.11, 0.42) if active else Color("#e8b993")
	var shape := str(hazard.get("shape", "circle"))
	if shape == "circle":
		if active: draw_circle(at, radius, color)
		draw_arc(at, radius, 0, TAU, 48, Color("#ffdd9c"), 3)
	elif shape == "ray":
		var direction := Vector2.from_angle(float(hazard.get("angle", 0)))
		var side := Vector2(-direction.y, direction.x) * float(hazard.get("width", radius))
		var end := at + direction * float(hazard.get("length", radius * 2))
		var points := PackedVector2Array([at + side, end + side, end - side, at - side])
		if active: draw_colored_polygon(points, color)
		points.append(points[0]); draw_polyline(points, Color("#ffdd9c"), 2)
	elif shape == "ring":
		var inner := float(hazard.get("innerRadius", 0))
		var gap: Dictionary = hazard.get("safeGap", {})
		var gap_angle := float(gap.get("angle", 0)); var gap_width := float(gap.get("width", 0))
		var danger_arc := float(hazard.get("dangerArc", TAU)); var direction := float(hazard.get("angle", 0))
		for i in range(96):
			var angle := TAU * (float(i) + .5) / 96.0
			if gap_width > 0 and absf(wrapf(angle - gap_angle, -PI, PI)) < gap_width / 2: continue
			if danger_arc < TAU and absf(wrapf(angle - direction, -PI, PI)) > danger_arc / 2: continue
			var v := Vector2.from_angle(angle)
			if active: draw_line(at + v * inner, at + v * radius, color, maxf(2, radius * TAU / 96.0))
			else:
				draw_circle(at + v * radius, 1.3, Color("#e8b993"))
				draw_circle(at + v * inner, 1.3, Color("#e8b993"))
	elif shape == "wave":
		var width := float(hazard.get("width", radius)); var length := float(hazard.get("length", radius * 2))
		var boxes: Array[Rect2] = []
		if hazard.get("flow", false): boxes.append(Rect2(at - Vector2(length / 2, width), Vector2(length, width * 2)))
		else:
			var gap := float(hazard.get("safeGap", {}).get("width", 0)) / 2
			boxes.append(Rect2(at + Vector2(-width, -length), Vector2(width * 2, maxf(0, length - gap))))
			boxes.append(Rect2(at + Vector2(-width, gap), Vector2(width * 2, maxf(0, length - gap))))
		for box in boxes:
			if active: draw_rect(box, color)
			draw_rect(box, Color("#ffdd9c"), false, 2)

func _texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path]
	var texture: Texture2D = REQUIRED_TEXTURES[path]
	_textures[path] = texture
	_sprite_regions[path] = texture.get_image().get_used_rect()
	return texture

func _draw_sprite(path: String, at: Vector2, dimensions: Vector2, rotation := 0.0, flip := false, tint := Color.WHITE) -> void:
	var texture := _texture(path)
	if texture == null:
		return
	var region: Rect2i = _sprite_regions[path]
	if region.size.x <= 0 or region.size.y <= 0:
		return
	draw_set_transform(at, rotation, Vector2(-1 if flip else 1, 1))
	draw_texture_rect_region(texture, Rect2(-dimensions * 0.5, dimensions), Rect2(region), tint)
	draw_set_transform(Vector2.ZERO)

func _draw_ground(size: Vector2, player_position: Vector2) -> void:
	var zone: String = sim.state.get("zoneId", "Z01")
	draw_rect(Rect2(Vector2.ZERO, size), ZONE_BASES[zone])
	var texture: Texture2D = ZONE_GROUNDS[zone]
	if texture == null:
		return
	var tile := Vector2(512, 512)
	var offset := Vector2(fposmod(size.x * 0.5 - player_position.x, tile.x), fposmod(size.y * 0.5 - player_position.y, tile.y))
	var columns := ceili(size.x / tile.x) + 2
	var rows := ceili(size.y / tile.y) + 2
	for ix in range(-1, columns):
		for iy in range(-1, rows):
			var at := offset + Vector2(ix * tile.x, iy * tile.y)
			draw_texture_rect(texture, Rect2(at, tile), false, Color(1, 1, 1, 0.8))

func _draw_shadow(at: Vector2, radius: float, opacity: float = 1.0) -> void:
	draw_set_transform(at, 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, radius, Color(0.07, 0.08, 0.05, 0.14 * opacity))
	draw_set_transform(Vector2.ZERO)

func _should_outline_enemy(enemy: Dictionary) -> bool:
	if not _presentation.get("veilOutline", false): return false
	var point := Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0)))
	for field in sim.state.get("fields", []):
		if field.get("kind") == "veil" and point.distance_to(Vector2(float(field.get("x", 0)), float(field.get("y", 0)))) <= float(field.get("radius", 0)):
			return true
	return false

func _boss_sprite_path() -> String:
	return BOSS_SPRITES[str(sim.state.get("bossKind", "B01"))]

func _boss_size() -> Vector2:
	return BOSS_SIZES[str(sim.state.get("bossKind", "B01"))]

func _enemy_visibility(enemy: Dictionary) -> float:
	return 0.06 if enemy.get("kind", "normal") != "boss" and float(enemy.get("hidden", 0)) > 0 else 1.0

func _draw_enemy(enemy: Dictionary) -> void:
	var at := _world(enemy)
	var kind: String = enemy.get("kind", "normal")
	var id := int(enemy.get("id", 0))
	var radius := float(enemy.get("radius", 15))
	var height := 70.0 if kind == "boss" else 48.0 if kind == "elite" else 25.0 if kind == "swift" else 32.0
	if kind != "boss":
		height *= 0.8 + float(posmod(id * 17, 11)) * 0.04
	var width := height * (0.62 if kind == "swift" else 0.9)
	if kind != "boss":
		width *= 0.8 + float(posmod(id * 29, 11)) * 0.04
	else:
		var dimensions := _boss_size()
		width = dimensions.x
		height = dimensions.y
	var visibility := _enemy_visibility(enemy)
	_draw_shadow(at + Vector2(0, radius * 0.6), width * 0.48, visibility)
	var statuses: Dictionary = enemy.get("statuses", {})
	var slowed: bool = float(enemy.get("slow", 0)) > 0 or statuses.has("slow")
	var tint := Color("#bfcde0") if slowed else Color.WHITE
	tint.a = visibility
	var angle := 0.0 if kind == "boss" else (get_viewport_rect().size * 0.5 - at).angle() + PI * 0.5 if kind == "swift" else fposmod(float(id) * 2.399963, TAU)
	if visibility >= 1.0 and _should_outline_enemy(enemy): draw_arc(at, maxf(width, height) * .6, 0, TAU, 24, Color("#e5f6df"), 2)
	_draw_sprite(_boss_sprite_path() if kind == "boss" else ENEMY_SPRITE, at + Vector2(0, -height * 0.24), Vector2(width, height), angle, id % 2 == 0, tint)
	if visibility < 1.0: return
	if enemy.get("family", "") == "shield" or enemy.get("frontalShield", false):
		var facing: Vector2 = enemy.get("facing", Vector2.LEFT)
		var blocked_angle := facing.angle()
		if enemy.get("family", "") == "shield" and int(enemy.get("variant", 1)) % 2 == 0: blocked_angle += PI
		draw_arc(at, radius + 6, blocked_angle - 1.2, blocked_angle + 1.2, 16, Color("#e6e0ba"), 3)
		var weak := Vector2.from_angle(blocked_angle + PI)
		draw_circle(at + weak * (radius + 7), 2.5, Color("#e9a190"))
	if slowed: draw_arc(at, radius + 2, 0, TAU, 24, Color(0.68, 0.88, 1, 0.58), 2)
	if statuses.has("ignite"):
		draw_line(at + Vector2(-5, -height * .55), at + Vector2(0, -height * .8), Color("#ffb76c"), 2)
		draw_line(at + Vector2(0, -height * .8), at + Vector2(5, -height * .55), Color("#ffb76c"), 2)
	if statuses.has("shock"): draw_arc(at, radius + 5, 0, TAU, 16, Color("#fff6ad"), 1)
	if statuses.has("mark") or statuses.has("vulnerable"):
		draw_line(at + Vector2(-5, -height * .7), at + Vector2(5, -height * .7), Color("#ec9eea"), 2)

func _draw_projectile(projectile: Dictionary) -> void:
	var at := _world(projectile)
	var fire: bool = projectile.get("kind", "") == "fireball"
	var velocity := Vector2(float(projectile.get("vx", 0)), float(projectile.get("vy", 0))).normalized()
	var radius := float(projectile.get("radius", 6))
	draw_line(at - velocity * 19, at, Color(1, 0.32, 0.03, 0.3) if fire else Color(0.58, 0.61, 1, 0.4), 7)
	draw_line(at - velocity * 9, at, Color("#ffb236") if fire else Color("#d9deff"), 3)
	draw_circle(at, radius + 6, Color(1, 0.36, 0.03, 0.18) if fire else Color(0.45, 0.53, 1, 0.17))
	draw_circle(at, radius, Color("#ff9d1f") if fire else Color("#afbbff"))
	draw_circle(at, maxf(2, radius * 0.48), Color("#fff8d8") if fire else Color.WHITE)

func _hazard_is_active(hazard: Dictionary) -> bool:
	return float(hazard.get("warning", 0)) <= 0 and float(hazard.get("active", 0)) > 0

func _warning_geometry(effect: Dictionary) -> Dictionary:
	var kind := str(effect.get("type", ""))
	var origin := Vector2(float(effect.get("x", 0)), float(effect.get("y", 0)))
	var radius := maxf(0.0, float(effect.get("radius", 20)))
	var result := {"kind": kind, "origin": origin, "radius": radius}
	if kind == "enemy_dash_warning" and effect.has("toX") and effect.has("toY"):
		result["end"] = Vector2(float(effect.toX), float(effect.toY))
	return result

func _draw_warning(effect: Dictionary, progress: float) -> void:
	var geometry := _warning_geometry(effect)
	var origin: Vector2 = geometry.origin
	var at := _world({"x": origin.x, "y": origin.y})
	var radius: float = geometry.radius
	var color := Color("#ffe2a6")
	match str(geometry.kind):
		"enemy_dash_warning":
			if geometry.has("end") and geometry.end != origin:
				var target: Vector2 = geometry.end
				var end := _world({"x": target.x, "y": target.y})
				var forward := (end - at).normalized()
				var side := Vector2(-forward.y, forward.x)
				draw_line(at + side * radius, end + side * radius, color, 2)
				draw_line(at - side * radius, end - side * radius, color, 2)
				draw_line(end - forward * 16 + side * 8, end, color, 2)
				draw_line(end - forward * 16 - side * 8, end, color, 2)
			else:
				draw_arc(at, radius, 0, TAU, 32, color, 2)
		"enemy_cast_warning":
			draw_arc(at, radius, 0, TAU, 40, color, 2)
			for index in range(4):
				var direction := Vector2.from_angle(index * PI / 2)
				draw_line(at + direction * (radius * 0.65), at + direction * (radius + 6), color, 2)
		"reappear_warning":
			for index in range(4):
				var start := index * PI / 2 + 0.12
				draw_arc(at, radius, start, start + PI / 2 - 0.24, 12, color, 2)
			draw_arc(at, radius * (0.25 + 0.65 * progress), 0, TAU, 28, Color("#ecbaf3"), 2)
		"artifact_warning":
			draw_arc(at, radius, 0, TAU, 40, Color("#b9e6f3"), 2)
			draw_line(at + Vector2(-5, 0), at + Vector2(5, 0), Color("#b9e6f3"), 2)
			draw_line(at + Vector2(0, -5), at + Vector2(0, 5), Color("#b9e6f3"), 2)

func _draw_effect(effect: Dictionary) -> void:
	var at := _world(effect)
	var kind: String = effect.get("type", "")
	var progress := clampf(1.0 - float(effect.get("life", 0)) / maxf(.001, float(effect.get("maxLife", 1))), 0, 1)
	var radius := float(effect.get("radius", 20))
	match kind:
		"enemy_dash_warning", "enemy_cast_warning", "reappear_warning", "artifact_warning":
			_draw_warning(effect, progress)
		"beam", "lightning":
			var from := _world({"x": effect.get("fromX", 0), "y": effect.get("fromY", 0)})
			var points := PackedVector2Array()
			for i in range(9):
				var t := float(i) / 8.0
				var side := Vector2(-(at.y - from.y), at.x - from.x).normalized()
				var jitter := sin(float(i * 37) + float(sim.state.get("time", 0)) * 11.0) * (5.0 if kind == "lightning" else 2.0)
				points.append(from.lerp(at, t) + side * jitter if i > 0 and i < 8 else from.lerp(at, t))
			draw_polyline(points, Color(0.46, 0.35, 1, 0.32), 10)
			draw_polyline(points, Color("#fff9e9") if kind == "lightning" else Color("#b9ecff"), 3)
		"frost":
			draw_circle(at, radius, Color(0.54, 0.81, 1, 0.12))
			for i in range(12):
				var v := Vector2.from_angle(TAU * float(i) / 12.0)
				draw_line(at + v * radius * 0.55, at + v * radius * (0.88 + 0.1 * progress), Color("#d9f2ff"), 3)
			draw_arc(at, radius, 0, TAU, 48, Color("#8bd9ff"), 3)
		"vortex":
			draw_circle(at, radius * 0.8, Color(0.12, 0.05, 0.2, 0.3))
			for i in range(3):
				draw_arc(at, radius * (0.45 + i * 0.23), progress * TAU + i, progress * TAU + i + PI * 1.3, 24, Color(0.68, 0.53, 0.98, 0.8 - i * 0.15), 3)
		"pulse", "explosion", "meteor":
			if kind == "pulse":
				radius = float(effect.get("maxRadius", 120)) * progress
			var color := Color("#fff2b3") if kind in ["explosion", "meteor"] else Color("#dad0ff")
			draw_circle(at, radius * 0.6, Color(color.r, color.g, color.b, 0.12 * (1 - progress)))
			draw_arc(at, radius, 0, TAU, 48, color, 4)
			for i in range(10):
				var angle := TAU * float(i) / 10.0 + progress * 0.5
				var v := Vector2.from_angle(angle)
				draw_line(at + v * radius * 0.65, at + v * radius * (1.05 + 0.2 * progress), color, 2)
		"hit", "death", "heal":
			var color := Color("#ffe3bb") if kind == "hit" else Color("#8df052") if kind == "heal" else Color("#17170e")
			for i in range(6):
				var v := Vector2.from_angle(TAU * float(i) / 6.0 + float(effect.get("x", 0)) * 0.1)
				draw_circle(at + v * (4 + progress * 18), 2.5 * (1 - progress) + 0.5, color)
		_:
			var fire := kind == "fireball"
			draw_circle(at, 12 + progress * 12, Color(1, 0.38, 0.04, 0.22) if fire else Color(0.54, 0.55, 1, 0.2))
			draw_circle(at, 5 * (1 - progress) + 1, Color("#fff4cf") if fire else Color("#faf5ff"))
