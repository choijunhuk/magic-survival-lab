extends RefCounted

const EMPTY_RECORD := {"time": 0, "kills": 0, "won": false, "bossDefeated": false}
const MODES := {"quick": 300.0, "expedition": 600.0}
const MAX_SAFE_KILLS := 9007199254740991

var last_error := ""
var data := {"version": 1, "quick": null, "expedition": null}
var _path: String

func _init(path: String = "user://records.json") -> void:
	_path = path

func load_records() -> void:
	data = {"version": 1, "quick": null, "expedition": null}
	last_error = ""
	if not FileAccess.file_exists(_path):
		return
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		last_error = "기록을 읽을 수 없습니다 (%d)." % FileAccess.get_open_error()
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	var parsed = parser.data if parse_error == OK else null
	if typeof(parsed) != TYPE_DICTIONARY or parsed.get("version") != 1 or not parsed.has("quick") or not parsed.has("expedition"):
		last_error = "기록 파일 형식이 올바르지 않습니다."
		return
	for mode in MODES:
		var entry = parsed.get(mode)
		if entry == null:
			continue
		if not _valid_record(entry, mode):
			last_error = "일부 기록이 손상되어 제외했습니다."
			continue
		data[mode] = entry.duplicate(true)
		data[mode].kills = int(entry.kills)

func for_mode(mode: String) -> Dictionary:
	if not MODES.has(mode) or data[mode] == null:
		return EMPTY_RECORD.duplicate()
	return data[mode].duplicate(true)

func record(state: Dictionary) -> bool:
	var mode = state.get("mode")
	if typeof(mode) != TYPE_STRING or not MODES.has(mode) or not _valid_state(state, mode):
		return false
	var next := {"time": state.time, "kills": state.kills,
		"won": state.phase == "won", "bossDefeated": state.bossDefeated}
	if not _better(next, data[mode], mode):
		return false
	var updated := data.duplicate(true)
	updated[mode] = next
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "기록을 저장할 수 없습니다 (%d)." % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(updated))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "기록을 저장할 수 없습니다 (%d)." % write_error
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	var rename_error := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(_path))
	if rename_error != OK:
		last_error = "기록을 교체할 수 없습니다 (%d)." % rename_error
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return false
	data = updated
	last_error = ""
	return true

func _valid_state(state: Dictionary, mode: String) -> bool:
	if not _valid_number(state.get("time"), MODES[mode]):
		return false
	if typeof(state.get("kills")) != TYPE_INT or state.kills < 0 or state.kills > MAX_SAFE_KILLS:
		return false
	if typeof(state.get("bossDefeated")) != TYPE_BOOL:
		return false
	var phase = state.get("phase")
	var reason = state.get("endReason")
	if mode == "quick":
		return not state.bossDefeated and ((phase == "won" and reason == "survived") or (phase == "lost" and reason == "death"))
	return (phase == "won" and reason == "boss-defeated" and state.bossDefeated) or (phase == "lost" and reason in ["death", "timeout"])

func _valid_record(entry: Variant, mode: String) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	if not _valid_number(entry.get("time"), MODES[mode]):
		return false
	if not _valid_number(entry.get("kills"), float(MAX_SAFE_KILLS)) or floor(float(entry.kills)) != float(entry.kills):
		return false
	if typeof(entry.get("won")) != TYPE_BOOL or typeof(entry.get("bossDefeated")) != TYPE_BOOL:
		return false
	return (mode != "quick" or not entry.bossDefeated) and (mode != "expedition" or not entry.won or entry.bossDefeated)

func _valid_number(value: Variant, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= maximum

func _better(next: Dictionary, previous: Variant, mode: String) -> bool:
	if previous == null:
		return true
	if mode == "expedition":
		if next.won != previous.won:
			return next.won
		if next.won and next.time != previous.time:
			return next.time < previous.time
	return next.time > previous.time or (next.time == previous.time and next.kills > previous.kills)
