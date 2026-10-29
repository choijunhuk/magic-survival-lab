extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const Records = preload("res://scripts/records.gd")
const Hud = preload("res://scripts/hud.gd")
const INK = Color("#0b1016")
const GROUND = Color("#7d8065")
const PLAYER_SPRITE = "res://assets/generated/player-ink.png"
const ENEMY_SPRITE = "res://assets/generated/enemy-ink.png"
const BOSS_SPRITE = "res://assets/generated/boss-ink.png"
const GROUND_TEXTURE = "res://assets/generated/ground-olive.png"
const REQUIRED_TEXTURES = {
	PLAYER_SPRITE: preload("res://assets/generated/player-ink.png"),
	ENEMY_SPRITE: preload("res://assets/generated/enemy-ink.png"),
	BOSS_SPRITE: preload("res://assets/generated/boss-ink.png"),
	GROUND_TEXTURE: preload("res://assets/generated/ground-olive.png"),
}

var sim: RefCounted
var records: RefCounted
var hud: CanvasLayer
var selected_mode := "quick"
var save_done := false
var record_error := ""
var touch_id := -1
var touch_origin := Vector2.ZERO
var touch_position := Vector2.ZERO
var fixed_step := 0.0
var _textures := {}
var _sprite_regions := {}

func _ready() -> void:
	DisplayServer.window_set_title("Magic Survival Lab")
	get_viewport().gui_release_focus()
	sim = Simulation.new(1, selected_mode)
	records = Records.new()
	records.load_records()
	record_error = records.last_error
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	_refresh_hud()

func begin(mode: String) -> void:
	selected_mode = mode if mode == "expedition" else "quick"
	sim.reset(selected_mode, Time.get_ticks_usec())
	sim.start()
	save_done = false
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
	_clear_touch()
	fixed_step = 0.0
	sim.reset(selected_mode, 1)
	_refresh_hud()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if sim != null and sim.state.get("phase") == "playing":
			pause_run()

func _input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventScreenTouch and not event.pressed and event.index == touch_id:
		_clear_touch()
	elif event is InputEventScreenDrag and event.index == touch_id:
		touch_position = event.position
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_BACK:
			if sim.state.get("phase") == "playing":
				pause_run()
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
	if sim.state.get("phase") == "playing":
		fixed_step = minf(fixed_step + delta, 0.15)
		while fixed_step >= 1.0 / 60.0 and sim.state.get("phase") == "playing":
			sim.tick(1.0 / 60.0, _movement())
			fixed_step -= 1.0 / 60.0
		if sim.state.get("phase") != "playing":
			_clear_touch()
			fixed_step = 0.0
		if sim.state.get("phase") in ["won", "lost"] and not save_done:
			save_done = true
			if not records.record(sim.state):
				record_error = records.last_error
		_refresh_hud()
		queue_redraw()

func _movement() -> Vector2:
	var x := float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	var y := float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
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
		hud.refresh(sim.state, sim.catalog, records.for_mode(selected_mode), record_error)

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
	for hazard in sim.state.get("hazards", []):
		var at := _world(hazard)
		var radius := float(hazard.get("radius", 70))
		if _hazard_is_active(hazard):
			draw_circle(at, radius, Color(0.8, 0.19, 0.11, 0.42))
			draw_arc(at, radius, 0, TAU, 48, Color("#ffdd9c"), 3)
		else:
			draw_arc(at, radius, 0, TAU, 48, Color("#e8b993"), 3)
			for j in range(8):
				var angle := TAU * j / 8.0
				draw_line(at + Vector2.from_angle(angle) * radius * .72, at + Vector2.from_angle(angle) * radius, Color("#f5caa1"), 2)
	for gem in sim.state.get("gems", []):
		var at := _world(gem)
		draw_circle(at, 5.0, Color(0.12, 0.53, 1.0, 0.24))
		draw_circle(at, 2.8, Color("#18a6ff"))
		draw_circle(at, 1.2, Color.WHITE)
	for chest in sim.state.get("chests", []):
		var at := _world(chest)
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
	draw_rect(Rect2(Vector2.ZERO, size), GROUND)
	var texture := _texture(GROUND_TEXTURE)
	if texture == null:
		return
	var tile := Vector2(512, 512)
	var offset := Vector2(fposmod(size.x * 0.5 - player_position.x, tile.x), fposmod(size.y * 0.5 - player_position.y, tile.y))
	var columns := ceili(size.x / tile.x) + 2
	var rows := ceili(size.y / tile.y) + 2
	for ix in range(-1, columns):
		for iy in range(-1, rows):
			var at := offset + Vector2(ix * tile.x, iy * tile.y)
			draw_texture_rect(texture, Rect2(at, tile), false, Color(1, 1, 1, 0.55))

func _draw_shadow(at: Vector2, radius: float) -> void:
	draw_set_transform(at, 0, Vector2(1, 0.38))
	draw_circle(Vector2.ZERO, radius, Color(0.07, 0.08, 0.05, 0.14))
	draw_set_transform(Vector2.ZERO)

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
	_draw_shadow(at + Vector2(0, radius * 0.6), width * 0.48)
	var tint := Color("#bfcde0") if float(enemy.get("slow", 0)) > 0 else Color.WHITE
	var angle := 0.0 if kind == "boss" else (get_viewport_rect().size * 0.5 - at).angle() + PI * 0.5 if kind == "swift" else fposmod(float(id) * 2.399963, TAU)
	_draw_sprite(BOSS_SPRITE if kind == "boss" else ENEMY_SPRITE, at + Vector2(0, -height * 0.24), Vector2(width, height), angle, id % 2 == 0, tint)
	if float(enemy.get("slow", 0)) > 0:
		draw_arc(at, radius + 2, 0, TAU, 24, Color(0.68, 0.88, 1, 0.58), 2)

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

func _draw_effect(effect: Dictionary) -> void:
	var at := _world(effect)
	var kind: String = effect.get("type", "")
	var progress := clampf(1.0 - float(effect.get("life", 0)) / maxf(.001, float(effect.get("maxLife", 1))), 0, 1)
	var radius := float(effect.get("radius", 20))
	match kind:
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
