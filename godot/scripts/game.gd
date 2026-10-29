extends Node2D

const Simulation = preload("res://scripts/simulation.gd")
const Records = preload("res://scripts/records.gd")
const Hud = preload("res://scripts/hud.gd")
const INK = Color("#0b1016")
const TEAL = Color("#80d4d1")
const GOLD = Color("#d9b66f")

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

func _ready() -> void:
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
		if event.pressed and touch_id == -1 and event.position.y > get_viewport_rect().size.y * 0.48 and event.position.x < get_viewport_rect().size.x * 0.65:
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
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	var phase: String = sim.state.get("phase", "ready") if sim != null else "ready"
	if phase == "ready":
		_draw_sigil(size * Vector2(0.77, 0.42), minf(size.x * 0.23, 160), 0.3)
		return
	var p: Dictionary = sim.state.get("player", {})
	var center := size * 0.5
	var base := Vector2(floorf(float(p.get("x", 0)) / 80.0) * 80.0, floorf(float(p.get("y", 0)) / 80.0) * 80.0)
	for ix in range(-5, 6):
		for iy in range(-8, 9):
			var at := center + base + Vector2(ix * 80, iy * 80) - Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
			if at.x >= 0 and at.x < size.x and at.y >= 0 and at.y < size.y:
				draw_circle(at, 1.0, Color("#20313a"))
	for zone in sim.state.get("zones", []):
		var at := _world(zone)
		var radius := float(zone.get("radius", 50))
		draw_circle(at, radius, Color(0.3, 0.7, 0.8, 0.1))
		draw_arc(at, radius, 0, TAU, 48, TEAL.darkened(0.25), 2.0)
	for strike in sim.state.get("strikes", []):
		var at := _world(strike)
		var radius := float(strike.get("radius", 75))
		draw_arc(at, radius, 0, TAU, 48, GOLD, 3.0)
		draw_line(at + Vector2(-radius * .55, 0), at + Vector2(radius * .55, 0), GOLD, 2)
	for hazard in sim.state.get("hazards", []):
		var at := _world(hazard)
		var radius := float(hazard.get("radius", 70))
		if _hazard_is_active(hazard):
			draw_circle(at, radius, Color(0.91, 0.28, 0.23, 0.35))
			draw_arc(at, radius, 0, TAU, 48, Color("#ff927e"), 4)
		else:
			draw_arc(at, radius, 0, TAU, 48, Color("#ffb78f"), 3)
			for j in range(8):
				var angle := TAU * j / 8.0
				draw_line(at + Vector2.from_angle(angle) * radius * .65, at + Vector2.from_angle(angle) * radius * .9, GOLD, 2)
	for gem in sim.state.get("gems", []):
		var at := _world(gem)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(5, 0), at + Vector2(0, 6), at + Vector2(-5, 0)]), TEAL)
	for chest in sim.state.get("chests", []):
		var at := _world(chest)
		draw_rect(Rect2(at - Vector2(10, 8), Vector2(20, 16)), GOLD)
		draw_rect(Rect2(at - Vector2(7, 5), Vector2(14, 10)), Color("#513e27"))
	for enemy in sim.state.get("enemies", []):
		var at := _world(enemy)
		var radius := float(enemy.get("radius", 12))
		var kind: String = enemy.get("kind", "normal")
		if kind == "boss":
			var crown := PackedVector2Array([at + Vector2(-radius, radius), at + Vector2(-radius*.8, -radius*.8), at + Vector2(-radius*.3, -radius*.3), at + Vector2(0, -radius*1.35), at + Vector2(radius*.3, -radius*.3), at + Vector2(radius*.8, -radius*.8), at + Vector2(radius, radius)])
			draw_colored_polygon(crown, Color("#75454b"))
			draw_arc(at, radius * 1.1, 0, TAU, 48, GOLD, 3)
		elif kind == "elite":
			draw_circle(at, radius, Color("#b1796e"))
			draw_arc(at, radius + 3, 0, TAU, 24, GOLD, 2)
		else:
			draw_circle(at, radius, Color("#6b858a") if float(enemy.get("slow", 0)) <= 0 else Color("#96d9e7"))
		if kind != "normal":
			var health := float(enemy.get("hp", 0)) / maxf(1, float(enemy.get("maxHp", 1)))
			draw_rect(Rect2(at + Vector2(-radius, radius+6), Vector2(radius*2, 3)), Color("#3a3033"))
			draw_rect(Rect2(at + Vector2(-radius, radius+6), Vector2(radius*2*health, 3)), GOLD)
	for projectile in sim.state.get("projectiles", []):
		var at := _world(projectile)
		var fire: bool = projectile.get("kind", "") == "fireball"
		draw_circle(at, float(projectile.get("radius", 6)) + 4, Color(1.0, .48, .24, .2) if fire else Color(.5, .9, 1, .18))
		draw_circle(at, float(projectile.get("radius", 6)), Color("#ffab6e") if fire else TEAL)
	for effect in sim.state.get("effects", []):
		_draw_effect(effect)
	var orbit_count := mini(8, int(sim.state.get("spells", {}).get("orbit", 0)))
	for i in range(orbit_count):
		var orbit_pos: Vector2 = sim.orbit_position(i)
		var at := center + orbit_pos - Vector2(float(p.get("x", 0)), float(p.get("y", 0)))
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -13), at + Vector2(7, 4), at + Vector2(0, 11), at + Vector2(-7, 4)]), GOLD)
	if int(p.get("shield", 0)) > 0:
		draw_arc(center, 24, 0, TAU, 40, GOLD, 2)
	if float(p.get("invulnerable", 0)) <= 0 or fmod(float(sim.state.get("time", 0)) * 12, 2) < 1:
		draw_circle(center, 18, Color(.45, .83, .82, .14))
		draw_colored_polygon(PackedVector2Array([center + Vector2(0,-17), center + Vector2(13,14), center + Vector2(0,8), center + Vector2(-13,14)]), Color("#bedbd9"))
		draw_circle(center + Vector2(7,-7), 3, TEAL)
	if touch_id != -1:
		draw_circle(touch_origin, 54, Color(0.5, .83, .82, .14))
		draw_arc(touch_origin, 54, 0, TAU, 40, TEAL, 2)
		draw_circle(touch_origin + (touch_position - touch_origin).limit_length(54), 23, Color(.5, .83, .82, .42))

func _hazard_is_active(hazard: Dictionary) -> bool:
	return float(hazard.get("warning", 0)) <= 0 and float(hazard.get("active", 0)) > 0

func _draw_effect(effect: Dictionary) -> void:
	var at := _world(effect)
	var kind: String = effect.get("type", "")
	var progress := 1.0 - float(effect.get("life", 0)) / maxf(.001, float(effect.get("maxLife", 1)))
	var radius := float(effect.get("radius", 20))
	match kind:
		"beam", "lightning":
			var from := _world({"x": effect.get("fromX", 0), "y": effect.get("fromY", 0)})
			draw_line(from, at, TEAL if kind == "beam" else Color("#b5bdff"), 8 if kind == "beam" else 4)
		"frost", "vortex", "pulse", "explosion", "meteor":
			if kind == "pulse":
				radius = float(effect.get("maxRadius", 120)) * progress
			draw_arc(at, radius, 0, TAU, 48, Color("#ffab6e") if kind in ["explosion", "meteor"] else Color("#a2d9f4") if kind == "frost" else TEAL, 4)
		"hit", "death", "heal":
			draw_circle(at, 10 + progress * 18, Color(.98, .41, .4, .25) if kind == "hit" else Color(.5, .86, .62, .25) if kind == "heal" else Color(.8, .7, .55, .16))
		_:
			draw_circle(at, 12 + progress * 10, Color(.96, .58, .38, .3) if kind == "fireball" else Color(.5, .86, .82, .25))

func _draw_sigil(at: Vector2, radius: float, opacity: float) -> void:
	draw_arc(at, radius, 0, TAU, 64, Color(.5, .83, .82, opacity * .4), 2)
	for i in range(8):
		var v := Vector2.from_angle(TAU * i / 8.0)
		draw_circle(at + v * radius, 2, Color(.7, .85, .8, opacity))
	draw_colored_polygon(PackedVector2Array([at+Vector2(0,-16), at+Vector2(10,0), at+Vector2(0,16), at+Vector2(-10,0)]), Color(.85,.7,.43,opacity))
