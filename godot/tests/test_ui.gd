extends SceneTree

var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String = "UI expectation failed") -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.begin("quick")
	scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.sim.state.phase == "paused", "Android Back must pause play")
	scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.sim.state.phase == "paused", "Repeated Android Back must not resume")
	var back := InputEventKey.new()
	back.keycode = KEY_BACK
	back.pressed = true
	scene._input(back)
	check(scene.sim.state.phase == "paused", "Back key after notification must not resume")
	scene.pause_run()
	check(scene.sim.state.phase == "playing")
	scene._input(back)
	check(scene.sim.state.phase == "paused", "Back key alone must pause")
	scene.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(scene.sim.state.phase == "paused", "Notification after Back key must not resume")
	check(not scene._hazard_is_active({"warning": 0.4, "active": 0.6}), "Warning remains outline-only")
	check(scene._hazard_is_active({"warning": 0.0, "active": 0.6}), "Active danger is filled")
	check(not scene._hazard_is_active({"warning": 0.0, "active": 0.0}), "Expired danger is inactive")
	scene.begin("quick")
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.pressed = true
	touch.position = root.get_visible_rect().size * Vector2(0.85, 0.30)
	scene._unhandled_input(touch)
	check(scene.touch_id == 7, "Right-thumb combat touch can start outside old lower-left region")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = touch.position + Vector2(80, 0)
	scene._input(drag)
	check(scene._movement().x > 0.9, "Captured right-thumb drag drives movement")
	scene.pause_run()
	check(scene.touch_id == -1 and scene._movement().is_zero_approx(), "Pause clears captured combat touch")
	for asset in ["player-ink", "enemy-ink", "boss-ink", "ground-olive", "zone-forest", "icon-fireball"]:
		var texture = load("res://assets/generated/%s.png" % asset)
		check(texture is Texture2D and texture.get_width() > 0 and texture.get_height() > 0, "Required visual resource loads: " + asset)
	var direction = scene.hud.get("boss_direction")
	check(direction != null, "Offscreen boss retains a navigation cue")
	if direction != null:
		var state: Dictionary = scene.sim.state
		state.bossSpawned = true
		state.bossId = 999
		state.enemies = [{"id": 999, "x": 1200, "y": 0, "hp": 10, "maxHp": 20}]
		scene.hud._update_boss(state)
		check(direction.visible and "→" in direction.text, "Offscreen boss cue points toward the boss")
		state.enemies[0].x = 0
		scene.hud._update_boss(state)
		check(not direction.visible, "Boss cue hides when boss is on screen")
		state.bossDefeated = true
		scene.hud._update_boss(state)
		check(not scene.hud.boss_box.visible, "Defeated boss hides boss HUD")
	print("UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
