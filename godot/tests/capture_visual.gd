extends SceneTree

const Records = preload("res://scripts/records.gd")

class CaptureGame extends "res://scripts/game.gd":
	# Godot delivers inherited notifications too. Disable their pause callback only
	# in this controlled capture; production lifecycle tests exercise the real game.
	func pause_run() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = CaptureGame.new()
	root.add_child(scene)
	scene.set_process(false)
	scene.records = Records.new("user://visual-capture-%d.json" % OS.get_process_id())
	scene.records.load_records()
	var out := ProjectSettings.globalize_path("res://../.omx/artifacts/magic-survival-correction")
	DirAccess.make_dir_recursive_absolute(out)
	await snap(scene, out, "menu")
	scene.begin("quick")
	scene.set_process(false)
	var s: Dictionary = scene.sim.state
	s.time = 205.0
	s.level = 5
	s.player.hp = 5.0
	s.spells.fireball = 1
	s.xp = 1.0
	s.xpNeeded = 12
	var random := RandomNumberGenerator.new()
	random.seed = 20261029
	for i in range(200):
		scene.sim._spawn_enemy(i % 23 == 0)
		var enemy: Dictionary = s.enemies.back()
		if i < 190:
			if i < 130:
				enemy.x = random.randfn(-175.0, 72.0)
				enemy.y = random.randfn(330.0, 100.0)
			else:
				enemy.x = random.randfn(-145.0, 65.0)
				enemy.y = random.randfn(210.0, 80.0)
		else:
			var angle := random.randf_range(0.0, TAU)
			var distance := random.randf_range(230.0, 510.0)
			enemy.x = cos(angle) * distance
			enemy.y = sin(angle) * distance
	for at in [Vector2(-220, -210), Vector2(180, -310), Vector2(140, 380)]:
		s.gems.append({"x": at.x, "y": at.y, "value": 1, "radius": 6})
	s.projectiles.append({"x": -100, "y": 100, "vx": -240, "vy": 180, "radius": 10, "kind": "fireball"})
	await snap(scene, out, "combat")
	s.time = 85.0
	s.phase = "upgrade"
	s.choices = []
	for id in ["fireball", "frost", "power"]:
		for choice in scene.sim.catalog.upgrades:
			if choice.id == id:
				s.choices.append(choice)
	await snap(scene, out, "magic-choice")
	s.phase = "paused"
	await snap(scene, out, "paused")
	s.phase = "lost"
	s.endReason = "death"
	await snap(scene, out, "result")
	print("Controlled presentation captures saved without writing live best records: " + out)
	quit(0)

func snap(scene: Node, out: String, label: String) -> void:
	scene._refresh_hud()
	scene.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(out.path_join(label + ".png"))
	if result != OK:
		push_error("Capture failed: " + label)
		quit(1)
