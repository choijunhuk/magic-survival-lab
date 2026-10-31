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
	game.profile = load("res://scripts/progression.gd").new("user://campaign-capture-%d.json" % OS.get_process_id())
	game.profile.load_profile()
	var output := ProjectSettings.globalize_path("res://../.omx/artifacts/campaign-ui")
	DirAccess.make_dir_recursive_absolute(output)
	for index in range(6):
		game.hud.zone_index = index
		game.selected_zone = "Z%02d" % (index + 1)
		game.hud._select_tab("map")
		await snap(game, output, "map-%d" % (index + 1))
		game.begin("campaign")
		game.set_process(false)
		await snap(game, output, "ground-%d" % (index + 1))
		game.go_home()
	game.begin("campaign")
	game.set_process(false)
	game.sim.state.phase = "paused"
	await snap(game, output, "paused-default")
	game.sim.state.phase = "playing"
	for shape in ["circle", "ray", "ring", "wave"]:
		var state: Dictionary = game.sim.state
		state.hazards.clear()
		state.hazards.append({"shape":shape, "x":0, "y":80, "radius":80, "innerRadius":45, "angle":0, "width":18, "length":140, "safeGap":{"angle":PI / 2, "width":PI / 3 if shape == "ring" else 70}, "warning":1.0, "active":0.0})
		await snap(game, output, "warning-" + shape)
		state.hazards[0].warning = 0.0
		state.hazards[0].active = 1.0
		await snap(game, output, "active-" + shape)
	var state: Dictionary = game.sim.state
	state.hazards.clear()
	state.phase = "upgrade"
	state.researchHints.compareFrequency = true
	state.choices = []
	for id in ["m09", "m10", "f05"]:
		for item in game.sim.catalog.upgrades + game.sim.catalog.fusions:
			if item.id == id: state.choices.append(item)
	await snap(game, output, "new-magic-choice")
	state.upgradeRerolls = 1
	game.hud.phase_key = ""
	await snap(game, output, "new-magic-reroll")
	state.phase = "artifact"
	state.artifactChoices = []
	for id in ["a013", "a014", "a015"]:
		for item in game.sim.catalog.artifacts:
			if item.id == id: state.artifactChoices.append(item)
	await snap(game, output, "new-artifact-choice")
	state.phase = "event"
	state.activeEvent = {"id":"E12", "name":"실습", "marker":{"status":"opened"}}
	state.eventChoices = [{"id":"accept", "name":"수락"}]
	game.sim.choose_event("accept")
	await snap(game, output, "practice")
	game.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	await snap(game, output, "practice-paused")
	game.practice_suspended = false
	state.phase = "lost"; state.endReason = "death"; state.time = 120.0
	state.completedEvents = []; state.bossSpawned = false; state.bossDefeated = false
	game.settlement = game.profile.complete_run(state)
	await snap(game, output, "campaign-result")
	state.phase = "playing"; state.time = 72.0
	state.researchHints.firstPhenomenonPreview = true
	state.researchHints.nextPhenomenon = {"time":75.0}
	state.researchHints.phenomenonMeter = true
	await snap(game, output, "research-hints")
	state.enemies.clear()
	var enemy_a: Dictionary = game.sim.Encounters.enemy(game.sim, 5, 0, Vector2(-50, -100))
	var enemy_b: Dictionary = game.sim.Encounters.enemy(game.sim, 6, 0, Vector2(50, -100))
	enemy_a.facing = Vector2.RIGHT; enemy_b.facing = Vector2.RIGHT
	await snap(game, output, "directional-shields")
	state.enemies.clear(); state.fields.clear(); state.artifacts.clear()
	state.researchHints = {}
	game.sim.Encounters.enemy(game.sim, 1, 0, Vector2(0, -100))
	game.sim.Combat.field(game.sim, "veil", Vector2(0, -100), 90.0, 10.0, {"sourceId": "m21"})
	await snap(game, output, "veil-base")
	state.artifacts.append("a041")
	await snap(game, output, "veil-outline")
	for index in range(6):
		game.go_home()
		game.selected_zone = "Z%02d" % (index + 1)
		game.begin("campaign")
		game.set_process(false)
		game.sim.state.time = 810.0
		game.sim.Encounters.spawn_boss(game.sim)
		var boss: Dictionary = game.sim.state.enemies.back()
		boss.x = 0.0
		boss.y = -120.0
		await snap(game, output, "boss-%d" % (index + 1))
	game.go_home()
	game.selected_zone = "Z01"
	game.begin("campaign")
	game.set_process(false)
	var stealth: Dictionary = game.sim.Encounters.enemy(game.sim, 23, 0, Vector2(-80, -100))
	await snap(game, output, "stealth-visible")
	stealth.specialTimer = 0.0
	game.sim.Encounters.advance_enemies(game.sim, 0.01)
	await snap(game, output, "stealth-hidden")
	game.sim.state.enemies.clear(); game.sim.state.effects.clear()
	var dash: Dictionary = game.sim.Encounters.enemy(game.sim, 3, 0, Vector2(-140, -100))
	dash.specialTimer = 0.0
	game.sim.Encounters.advance_enemies(game.sim, 0.01)
	await snap(game, output, "warning-dash")
	game.sim.state.enemies.clear(); game.sim.state.effects.clear()
	var caster: Dictionary = game.sim.Encounters.enemy(game.sim, 7, 0, Vector2(140, -80))
	caster.castTimer = 0.0
	game.sim.Encounters.advance_enemies(game.sim, 0.01)
	game.sim.state.player.x = 80.0
	await snap(game, output, "warning-cast")
	game.sim.state.enemies.clear(); game.sim.state.effects.clear()
	game.sim.state.player.x = 0.0
	var returning: Dictionary = game.sim.Encounters.enemy(game.sim, 23, 0, Vector2(-80, -100))
	returning.specialTimer = 0.0
	game.sim.Encounters.advance_enemies(game.sim, 0.01)
	await snap(game, output, "warning-reappear")
	game.sim.state.enemies.clear(); game.sim.state.effects.clear()
	game.sim.schedule_artifact_effect(0.8, "damage_radius", {"position": Vector2(110, -110), "radius": 50.0})
	await snap(game, output, "warning-artifact")
	print("Controlled campaign captures: " + output)
	quit(0)

func snap(game: Node, output: String, label: String) -> void:
	game._refresh_hud()
	game.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		push_error("Capture failed: " + label)
		quit(1)
