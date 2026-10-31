extends SceneTree

const Sim = preload("res://scripts/release_simulation.gd")
const Encounters = preload("res://scripts/release_encounters.gd")
const Profile = preload("res://scripts/progression.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for outcome in ["death", "timeout", "win"]:
		var sim := Sim.new(314, "campaign", {"runId": "actual-kill-" + outcome})
		sim.start()
		sim.state.time = 899.99 if outcome == "timeout" else 810.0
		Encounters.spawn_boss(sim)
		var boss = sim.state.enemies.filter(func(item): return item.kind == "boss")[0]
		sim.apply_damage(boss, 1000000.0, sim.context("bolt"))
		check(sim.state.bossDefeated and sim.state.kills == 1, "Real damage kills boss: " + outcome)
		if outcome == "death": sim._hurt_player(100.0)
		sim.tick(0.05)
		var won: bool = outcome == "win"
		check(sim.state.phase == ("won" if won else "lost"), "Terminal priority: " + outcome)
		check(sim.state.bossDefeated, "Raw kill fact survives terminal priority")
		var path := "user://settlement-integration-%d-%s.json" % [Time.get_ticks_usec(), outcome]
		var profile := Profile.new(path, sim.catalog)
		check(profile.load_profile(), "New isolated profile loads")
		var reward := profile.complete_run(sim.state)
		check(reward.ok and reward.credited, "Actual terminal result settles: " + outcome)
		check(reward.reward == {"death": 30, "timeout": 33, "win": 48}[outcome], "Phase controls payout: " + outcome)
		check(profile.data.clearedZones.has("Z01") == won, "Only final victory records clear")
		check(profile.for_zone("Z01").bossDefeated == won, "Saved boss outcome follows final phase")
		var duplicate := profile.complete_run(sim.state)
		check(duplicate.ok and not duplicate.credited and duplicate.reward == 0, "No double payout")
		var reloaded := Profile.new(path, sim.catalog)
		check(reloaded.load_profile() and reloaded.data.wallet == reward.reward, "Settled result reloads")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Settlement integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
