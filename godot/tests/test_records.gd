extends SceneTree

const Records = preload("res://scripts/records.gd")
var checks := 0
var failures := 0
var test_dir := ""

func _initialize() -> void:
	test_dir = "user://test-native-records-%d" % Time.get_ticks_usec()
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(test_dir))
	if err != OK:
		push_error("Cannot create isolated test directory: %d" % err)
		quit(1)
		return
	_run()
	_cleanup()
	print("Records: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func path(name: String) -> String:
	return test_dir.path_join(name)

func store(name: String) -> RefCounted:
	return Records.new(path(name))

func run(mode: String, phase: String, seconds: float, kills: int, reason: String, boss: bool = false) -> Dictionary:
	return {"mode": mode, "phase": phase, "time": seconds, "kills": kills,
		"endReason": reason, "bossDefeated": boss}

func write_text(filename: String, contents: String) -> void:
	var file := FileAccess.open(path(filename), FileAccess.WRITE)
	if file:
		file.store_string(contents)
		file.close()

func _run() -> void:
	var records = store("fresh.json")
	records.load_records()
	expect(records.for_mode("quick") == {"time": 0, "kills": 0, "won": false, "bossDefeated": false}, "fresh quick is empty")
	expect(records.for_mode("expedition").time == 0 and records.last_error.is_empty(), "fresh expedition is empty without error")

	write_text("corrupt.json", "{")
	records = store("corrupt.json")
	records.load_records()
	expect(records.for_mode("quick").time == 0 and not records.last_error.is_empty(), "corrupt JSON resets safely with error")
	expect(records.record(run("quick", "won", 30, 3, "survived")), "corrupt file can be replaced by real result")

	write_text("partial.json", '{"version":1,"quick":{"time":12},"expedition":null}')
	records = store("partial.json")
	records.load_records()
	expect(records.for_mode("quick").time == 0 and not records.last_error.is_empty(), "partial record rejected")
	write_text("schema.json", '{"version":2,"quick":null,"expedition":null}')
	records = store("schema.json")
	records.load_records()
	expect(records.for_mode("quick").time == 0 and not records.last_error.is_empty(), "unknown schema rejected")
	write_text("missing.json", '{"version":1,"quick":null}')
	records = store("missing.json")
	records.load_records()
	expect(records.for_mode("quick").time == 0 and not records.last_error.is_empty(), "missing mode field rejected")
	write_text("false-win.json", '{"version":1,"quick":null,"expedition":{"time":120,"kills":1,"won":true,"bossDefeated":false}}')
	records = store("false-win.json")
	records.load_records()
	expect(records.for_mode("expedition").time == 0 and not records.last_error.is_empty(), "inconsistent persisted win rejected")

	records = store("ranking.json")
	records.load_records()
	expect(not records.record(run("quick", "playing", 20, 2, "survived")), "nonterminal result rejected")
	expect(records.record(run("quick", "lost", 40, 2, "death")), "quick loss recorded")
	expect(not records.record(run("quick", "won", 30, 99, "survived")), "quick longer survival ranks first")
	expect(records.record(run("quick", "lost", 40, 3, "death")), "quick tie broken by kills")
	expect(not records.record(run("quick", "lost", 40, 3, "death")), "duplicate result is idempotent")
	expect(records.record(run("expedition", "lost", 590, 8, "timeout")), "expedition loss recorded independently")
	expect(records.record(run("expedition", "won", 500, 2, "boss-defeated", true)), "expedition win beats longer loss")
	expect(records.record(run("expedition", "won", 480, 1, "boss-defeated", true)), "faster expedition win wins")
	expect(records.record(run("expedition", "won", 480, 4, "boss-defeated", true)), "winning time tie broken by kills")
	expect(not records.record(run("expedition", "won", 490, 100, "boss-defeated", true)), "slower expedition win loses")
	expect(records.for_mode("quick").kills == 3 and records.for_mode("expedition").kills == 4, "modes remain independent")
	var losses = store("losses.json")
	losses.load_records()
	expect(losses.record(run("expedition", "lost", 10, 10, "death")), "first expedition loss recorded")
	expect(losses.record(run("expedition", "lost", 20, 1, "death")), "longer expedition loss wins")
	expect(losses.record(run("expedition", "lost", 20, 2, "death")), "expedition loss tie broken by kills")
	var reloaded = store("ranking.json")
	reloaded.load_records()
	expect(reloaded.for_mode("quick").kills == 3 and reloaded.for_mode("expedition").time == 480, "records persist after reload")

	var bad = run("quick", "won", 10, 1, "survived")
	bad.mode = "other"
	expect(not records.record(bad), "unknown mode rejected")
	bad.mode = "quick"
	bad.time = 301
	expect(not records.record(bad), "out of range time rejected")
	bad.time = NAN
	expect(not records.record(bad), "nonfinite time rejected")
	bad.time = 10
	bad.kills = -1
	expect(not records.record(bad), "negative kills rejected")
	bad.kills = 1.5
	expect(not records.record(bad), "fractional kills rejected")
	bad.kills = 1
	bad.bossDefeated = "true"
	expect(not records.record(bad), "nonboolean boss flag rejected")
	bad.bossDefeated = false
	bad.endReason = "boss-defeated"
	expect(not records.record(bad), "inconsistent outcome rejected")

	# A temp-path collision makes writes fail without touching an existing record.
	var blocker := path("ranking.json.tmp")
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(blocker))
	expect(not records.record(run("quick", "won", 50, 5, "survived")) and not records.last_error.is_empty(), "write failure is reported")
	expect(records.for_mode("quick").time == 40, "failed write does not claim saved record")
	expect(not records.record(run("quick", "lost", 40, 3, "death")), "duplicate does not attempt blocked write")
	reloaded.load_records()
	expect(reloaded.for_mode("quick").time == 40, "failed write preserves previous file")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))

func _cleanup() -> void:
	var dir := DirAccess.open(test_dir)
	if dir:
		for filename in dir.get_files():
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path(filename)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_dir))
