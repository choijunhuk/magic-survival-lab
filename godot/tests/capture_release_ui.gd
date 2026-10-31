extends SceneTree

class CaptureGame extends "res://scripts/game.gd":
	func pause_run() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := CaptureGame.new()
	root.add_child(game)
	game.set_process(false)
	game.profile = load("res://scripts/progression.gd").new("user://release-capture-%d.json" % OS.get_process_id())
	game.profile.load_profile()
	var output := ProjectSettings.globalize_path("res://../.omx/artifacts/release-ui")
	DirAccess.make_dir_recursive_absolute(output)
	for tab in ["map", "class", "research", "codex", "records", "mode"]:
		game.hud._select_tab(tab)
		await snap(game, output, tab)
	game.hud._select_tab("map")
	game.begin("campaign")
	game.set_process(false)
	game.sim.tick(1.0 / 60.0, Vector2.ZERO)
	await snap(game, output, "combat")
	print("Release UI captured with an isolated empty profile: " + output)
	quit(0)

func snap(game: Node, output: String, name_value: String) -> void:
	game._refresh_hud()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(name_value + ".png"))
	if error != OK:
		push_error("Release UI capture failed: " + name_value)
		quit(1)
