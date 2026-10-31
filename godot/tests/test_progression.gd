extends SceneTree

const Progression = preload("res://scripts/progression.gd")
const ReleaseSimulation = preload("res://scripts/release_simulation.gd")
var checks := 0
var failures := 0
var test_dir := ""

func _initialize() -> void:
	test_dir = "user://test-progression-%d" % Time.get_ticks_usec()
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir)) != OK:
		quit(1)
		return
	_run()
	_cleanup()
	print("Progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func path(name: String) -> String:
	return test_dir.path_join(name)

func profile(name: String) -> RefCounted:
	return Progression.new(path(name), {"zones": ["Z01", "Z02", "Z03", "Z04", "Z05", "Z06"],
		"bosses": ["B01", "B02", "B03", "B04", "B05", "B06"],
		"events": ["E01", "E02", "E03"]})

func run(id: String, seconds: float, phase: String = "lost", reason: String = "death", boss_spawned: bool = false, defeated: bool = false, events: Array = []) -> Dictionary:
	return {"mode": "campaign", "runId": id, "zoneId": "Z01", "bossKind": "B01",
		"time": seconds, "phase": phase, "endReason": reason, "bossSpawned": boss_spawned,
		"bossDefeated": defeated, "completedEvents": events, "kills": 2}

func write_text(name: String, contents: String) -> void:
	var file := FileAccess.open(path(name), FileAccess.WRITE)
	if file:
		file.store_string(contents)
		file.close()

func _run() -> void:
	var p = profile("progress.json")
	expect(p.load_profile() and p.data.wallet == 0, "fresh profile has zero wallet")
	expect(not p.purchase_research("R01") and p.data.wallet == 0, "cannot buy without residue")
	expect(p.complete_run(run("r59", 59)).reward == 1, "59 seconds floors to one")
	expect(p.complete_run(run("r60", 60)).reward == 2, "60 seconds floors to two")
	expect(p.complete_run(run("r810", 810, "lost", "death", true, false, ["E01", "E02"])).reward == 32, "first boss encounter grants three")
	expect(p.complete_run(run("r840", 840, "won", "boss-defeated", true, true, ["E01", "E02", "E03"])).reward == 49, "first zone clear grants eight")
	expect(p.data.wallet == 84, "reward arithmetic accumulates")
	expect(p.complete_run(run("r840", 840, "won", "boss-defeated", true, true, ["E01", "E02", "E03"])).reward == 0, "duplicate run ID is idempotent")
	expect(p.complete_run(run("r900", 900, "lost", "timeout", true, false, ["E01", "E02", "E03"])).reward == 33, "timeout caps time at 30")
	expect(p.for_zone("Z01").won and p.for_zone("Z01").time == 840, "winning best survives a timeout")
	var reloaded = profile("progress.json")
	expect(reloaded.load_profile() and reloaded.data.wallet == 117 and reloaded.data.settledRuns.size() == 5, "wallet and ledger persist")
	expect(reloaded.complete_run(run("r840", 840)).reward == 0, "idempotency persists after reload")

	expect(not p.purchase_research("R02"), "purchase prerequisites enforced")
	expect(p.purchase_research("R01") and p.data.wallet == 107, "R01 costs ten")
	expect(p.purchase_research("R02") and p.purchase_research("R03") and p.purchase_research("R04"), "first tier purchases")
	expect(p.purchase_research("R05") and p.data.wallet == 59, "second tier costs eighteen")
	expect(not p.set_equipped(["R06"]), "unpurchased node cannot equip")
	expect(p.set_equipped(["R05"]), "prerequisite does not need equipping")
	expect(not p.purchase_research("R01"), "research is one time")
	p.set_in_run(true)
	expect(not p.purchase_research("R06") and not p.set_equipped([]), "combat changes rejected")
	p.set_in_run(false)
	expect(p.set_equipped([]) and p.data.equipped.is_empty(), "free hub reset")

	var invalid = run("invalid", 100)
	for bad in ["quick", "expedition", "practice"]:
		invalid.mode = bad
		expect(not p.complete_run(invalid).ok, "%s never credits" % bad)
	invalid.mode = "campaign"
	for seconds in [NAN, INF, -1.0, 901.0]:
		invalid.time = seconds
		expect(not p.complete_run(invalid).ok, "invalid time rejected")
	invalid.time = 100
	invalid.runId = ""
	expect(not p.complete_run(invalid).ok, "empty run ID rejected")
	invalid.runId = "invalid"
	invalid.zoneId = "Z99"
	expect(not p.complete_run(invalid).ok, "unknown zone rejected")
	invalid.zoneId = "Z01"
	invalid.bossKind = "B02"
	expect(not p.complete_run(invalid).ok, "mismatched boss rejected")
	invalid.bossKind = "B01"
	for events in [["E01", "E01"], ["E99"], ["E01", "E02", "E03", "E04"]]:
		invalid.completedEvents = events
		expect(not p.complete_run(invalid).ok, "invalid event list rejected")
	invalid.completedEvents = []
	invalid.endReason = "abandoned"
	expect(not p.complete_run(invalid).ok, "abandon rejected")
	invalid.endReason = "timeout"
	expect(not p.complete_run(invalid).ok, "early timeout rejected")
	invalid.endReason = "death"
	invalid.bossDefeated = true
	expect(not p.complete_run(invalid).ok, "defeat without spawn rejected")
	invalid.bossSpawned = true
	expect(not p.complete_run(invalid).ok, "boss defeat before spawn time rejected")
	invalid.bossDefeated = false
	expect(not p.complete_run(invalid).ok, "boss cannot spawn before 810 seconds")
	invalid.erase("phase")
	expect(not p.complete_run(invalid).ok, "missing terminal phase rejected without runtime error")
	expect(p.data.wallet == 59, "invalid states cannot mint")

	var p2 = profile("equip.json")
	p2.load_profile()
	for index in range(7):
		p2.complete_run(run("fund-%d" % index, 900, "lost", "timeout", true))
	for id in ["R01", "R02", "R03", "R04", "R05", "R06", "R07"]:
		expect(p2.purchase_research(id), "purchased %s in graph" % id)
	expect(p2.set_equipped(["R01", "R02", "R03", "R04", "R05", "R06"]), "six equips allowed")
	expect(not p2.set_equipped(["R01", "R02", "R03", "R04", "R05", "R06", "R07"]), "seventh equip rejected")
	expect(not p2.set_equipped(["R01", "R01"]), "duplicate equip rejected")
	expect(p2.data.equipped.size() == 6, "rejected equip keeps accepted state")
	var full = profile("full-graph.json")
	full.load_profile()
	for index in range(20):
		full.complete_run(run("full-fund-%d" % index, 900, "lost", "timeout", true))
	for number in range(1, 25):
		expect(full.purchase_research("R%02d" % number), "all 24 research nodes form a purchasable graph")
	expect(full.data.wallet == 603 - 568, "24 research costs sum to 568")
	expect(full.set_equipped(["R19", "R20", "R21", "R22", "R23", "R24"]), "late nodes equip without their prerequisites equipped")

	write_text("corrupt.json", "{")
	var corrupt = profile("corrupt.json")
	expect(not corrupt.load_profile() and not corrupt.last_error.is_empty(), "corrupt file reports error")
	expect(not corrupt.complete_run(run("corrupt-run", 900, "lost", "timeout")).ok, "corrupt file blocks new credit")
	expect(not corrupt.purchase_research("R01"), "corrupt file blocks purchase")
	for body in ['{"version":2}', '{"version":1,"wallet":-1}', '{"version":1,"wallet":NaN}', '{"version":1,"wallet":0,"purchased":["R99"]}']:
		write_text("bad-values.json", body)
		var bad_saved = profile("bad-values.json")
		expect(not bad_saved.load_profile() and not bad_saved.complete_run(run("bad-saved", 900, "lost", "timeout", true)).ok, "invalid saved schema or values block credit")
	var poisoned = profile("poisoned.json")
	poisoned.load_profile()
	poisoned.data.wallet = -1
	expect(not poisoned.complete_run(run("poisoned", 900, "lost", "timeout")).ok, "negative in-memory wallet blocks credit")
	poisoned.data.wallet = NAN
	expect(not poisoned.complete_run(run("poisoned", 900, "lost", "timeout")).ok, "NaN wallet blocks credit")
	poisoned.data.wallet = 0
	poisoned.data.purchased = ["R99"]
	expect(not poisoned.complete_run(run("poisoned", 900, "lost", "timeout")).ok, "unknown purchased ID blocks credit")

	var blocked = profile("blocked.json")
	blocked.load_profile()
	var blocker := path("blocked.json.tmp")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocker))
	expect(not blocked.complete_run(run("blocked", 840, "won", "boss-defeated", true, true)).ok, "save failure reports no credit")
	expect(blocked.data.wallet == 0 and blocked.data.settledRuns.is_empty() and blocked.data.clearedZones.is_empty(), "save failure rolls back memory")
	expect(not FileAccess.file_exists(path("blocked.json")), "save failure does not create accepted file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	expect(blocked.complete_run(run("blocked", 840, "won", "boss-defeated", true, true)).reward == 49, "retry after save failure credits once")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocker))
	expect(not blocked.purchase_research("R01") and blocked.data.wallet == 49, "failed purchase preserves wallet")
	expect(blocked.data.purchased.is_empty(), "failed purchase preserves research")
	expect(not blocked.set_equipped([]) and blocked.data.equipped.is_empty(), "failed equip preserves accepted state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))


	var simulation = ReleaseSimulation.new(7, "campaign", {"runId": "real-catalog"})
	var actual_catalog = Progression.new(path("real-catalog.json"), simulation.catalog)
	expect(actual_catalog.load_profile(), "real release catalog profile loads")
	expect(actual_catalog.complete_run(run("real-catalog", 90, "lost", "death", false, false, ["E01"])).reward == 4, "real dictionary catalog accepts known zone, boss, and event")
	expect(actual_catalog.complete_run(run("real-catalog-later", 450, "lost", "death", false, false, ["E03"])).reward == 16, "real catalog scans past earlier dictionary events")
	var unknown_catalog = Progression.new(path("unknown-catalog.json"), simulation.catalog)
	unknown_catalog.load_profile()
	var invalid_catalog_run = run("unknown", 90, "lost", "death", false, false, ["E01"])
	invalid_catalog_run.zoneId = "Z02"
	invalid_catalog_run.bossKind = "B01"
	expect(not unknown_catalog.complete_run(invalid_catalog_run).ok, "real catalog still rejects mismatched zone and boss")


	# Terminal priority is resolved by the real simulation; raw simultaneous boss
	# death remains visible in state, but only a final win earns victory rewards.
	for terminal in ["death", "timeout", "win"]:
		var sim = ReleaseSimulation.new(91, "campaign", {"runId": "terminal-" + terminal})
		sim.start()
		for spell in sim.state.spells: sim.state.spells[spell] = 0
		sim.state.spawnTimer = 10000
		sim.state.eliteTimer = 10000
		sim.state.bossSpawned = true
		sim.state.bossDefeated = true
		sim.state.time = 899.99 if terminal == "timeout" else 810.0
		if terminal == "death": sim.state.player.hp = 0
		sim.tick(0.05)
		var terminal_profile = Progression.new(path("terminal-%s.json" % terminal), sim.catalog)
		expect(terminal_profile.load_profile(), "%s terminal profile starts" % terminal)
		expect(sim.state.bossDefeated and sim.state.phase == ("won" if terminal == "win" else "lost"), "%s simulation retains raw kill and resolves phase" % terminal)
		var settled: Dictionary = terminal_profile.complete_run(sim.state)
		var expected_reward: int = 48 if terminal == "win" else (33 if terminal == "timeout" else 30)
		expect(settled.ok and settled.reward == expected_reward, "%s terminal receives correct reward" % terminal)
		expect(terminal_profile.data.clearedZones.has("Z01") == (terminal == "win") and terminal_profile.data.encounteredBosses.has("B01"), "%s terminal sets correct flags" % terminal)
		expect(terminal_profile.data.best.Z01.bossDefeated == (terminal == "win"), "%s stored record follows final phase" % terminal)
		expect(terminal_profile.complete_run(sim.state).ok and not terminal_profile.complete_run(sim.state).credited, "%s terminal duplicate is idempotent" % terminal)
		var loaded_terminal = Progression.new(path("terminal-%s.json" % terminal), sim.catalog)
		expect(loaded_terminal.load_profile() and loaded_terminal.data.wallet == expected_reward and loaded_terminal.data.clearedZones == terminal_profile.data.clearedZones and loaded_terminal.data.encounteredBosses == ["B01"] and loaded_terminal.data.best.Z01.bossDefeated == (terminal == "win"), "%s terminal reload preserves consistent flags" % terminal)

	# Each scheduled opportunity permits one completion, including at the boundary.
	for boundary in [90, 270, 450]:
		var count: int = [90, 270, 450].find(boundary) + 1
		var event_ids := ["E01", "E02", "E03"].slice(0, count)
		var before = profile("event-before-%d.json" % boundary)
		before.load_profile()
		expect(not before.complete_run(run("before", boundary - 0.01, "lost", "death", false, false, event_ids)).ok and before.data.wallet == 0, "event count rejected before %d" % boundary)
		var at = profile("event-at-%d.json" % boundary)
		at.load_profile()
		expect(at.complete_run(run("at", boundary, "lost", "death", false, false, event_ids)).ok, "event count accepted at %d" % boundary)
	var zero = profile("event-zero.json")
	zero.load_profile()
	expect(not zero.complete_run(run("zero", 0, "lost", "death", false, false, ["E01", "E02", "E03"])).ok and zero.data.wallet == 0, "zero time cannot mint event rewards")

	var fixture = profile("fixture.json")
	fixture.load_profile()
	expect(fixture.complete_run(run("fixture", 840, "won", "boss-defeated", true, true)).ok, "legitimate win fixture settled")
	var valid_win: Dictionary = fixture.data.duplicate(true)
	for field in ["clear", "encounter", "boss_discovery", "zone_discovery", "win_time_early", "win_time_late", "win_defeat", "loss_defeat"]:
		var damaged: Dictionary = valid_win.duplicate(true)
		match field:
			"clear": damaged.clearedZones = []
			"encounter": damaged.encounteredBosses = []
			"boss_discovery": damaged.discovered.bosses = []
			"zone_discovery": damaged.discovered.zones = []
			"win_time_early": damaged.best.Z01.time = 809
			"win_time_late": damaged.best.Z01.time = 900
			"win_defeat": damaged.best.Z01.bossDefeated = false
			"loss_defeat": damaged.best.Z01.won = false
		write_text("damaged.json", JSON.stringify(damaged))
		var damaged_profile = profile("damaged.json")
		expect(not damaged_profile.load_profile() and not damaged_profile.complete_run(run("again", 840, "won", "boss-defeated", true, true)).ok, "reject damaged win %s" % field)

	var future: Dictionary = valid_win.duplicate(true)
	future.wallet = 123
	future.purchased = ["R01", "R99"]
	future.equipped = ["R01", "R99"]
	write_text("future.json", JSON.stringify(future))
	var future_profile = profile("future.json")
	expect(future_profile.load_profile() and future_profile.data.wallet == 123 and future_profile.data.purchased == ["R01"] and future_profile.data.equipped == ["R01"], "unknown research IDs filtered without changing wallet or known entries")
	future.purchased = ["R02", "R99"]
	write_text("future-bad.json", JSON.stringify(future))
	expect(not profile("future-bad.json").load_profile(), "filtering does not repair missing known prerequisite")
	future.purchased = ["R01", 123]
	write_text("future-bad.json", JSON.stringify(future))
	expect(not profile("future-bad.json").load_profile(), "non-string research ID rejected")

	write_text("reload.json", JSON.stringify(valid_win))
	var reload = profile("reload.json")
	expect(reload.load_profile(), "valid reload fixture loaded")
	var accepted: Dictionary = reload.data.duplicate(true)
	write_text("reload.json", "{")
	expect(not reload.load_profile() and reload.data == accepted and not reload.last_error.is_empty(), "malformed reload preserves accepted state")
	expect(not reload.complete_run(run("reload-again", 840, "won", "boss-defeated", true, true)).ok and not reload.purchase_research("R01"), "malformed reload blocks writes")
	write_text("reload.json", JSON.stringify(valid_win))
	expect(reload.load_profile(), "successful reload restores write eligibility")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path("reload.json")))
	expect(not reload.load_profile() and reload.data == accepted and not reload.last_error.is_empty(), "missing reload preserves accepted state")
	expect(not reload.complete_run(run("reload-missing", 840, "won", "boss-defeated", true, true)).ok, "missing reload blocks writes")

	var limit = profile("limit.json")
	limit.load_profile()
	limit.data.wallet = 9007199254740991
	expect(not limit.complete_run(run("overflow", 30)).ok and limit.data.wallet == 9007199254740991 and limit.data.settledRuns.is_empty(), "wallet overflow rejects entire settlement")
	var rename_failure = profile("rename-target")
	rename_failure.load_profile()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path("rename-target")))
	expect(not rename_failure.complete_run(run("rename", 30)).ok and rename_failure.data.wallet == 0 and rename_failure.data.settledRuns.is_empty(), "rename failure preserves accepted memory")
	expect(not FileAccess.file_exists(path("rename-target.tmp")), "rename failure removes temporary file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path("rename-target")))

func _cleanup() -> void:
	var dir := DirAccess.open(test_dir)
	if dir:
		for filename in dir.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))
