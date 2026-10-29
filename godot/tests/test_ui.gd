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
	print("UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
