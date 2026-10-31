extends RefCounted

const MAX_SAFE := 9007199254740991
const ZONES := ["Z01", "Z02", "Z03", "Z04", "Z05", "Z06"]
const BOSSES := ["B01", "B02", "B03", "B04", "B05", "B06"]
const RESEARCH_PREREQUISITES := {
	"R01": [], "R02": ["R01"], "R03": ["R01"], "R04": ["R01"],
	"R05": ["R02"], "R06": ["R02"], "R07": ["R03"], "R08": ["R03"],
	"R09": ["R04"], "R10": ["R04"], "R11": ["R05"], "R12": ["R06"],
	"R13": ["R07"], "R14": ["R08"], "R15": ["R09"], "R16": ["R10"],
	"R17": ["R11"], "R18": ["R12"], "R19": ["R13"], "R20": ["R14"],
	"R21": ["R15"], "R22": ["R16"], "R23": ["R17", "R18"], "R24": ["R19", "R23"]
}

var data: Dictionary = _empty_profile()
var last_error := ""
var _path: String
var _catalog: Dictionary
var _in_run := false
var _writable := true
var _has_loaded := false

func _init(path: String = "user://campaign-profile.json", catalog: Dictionary = {}) -> void:
	_path = path
	_catalog = catalog

func _empty_profile() -> Dictionary:
	var best := {}
	for zone in ZONES:
		best[zone] = null
	return {"version": 1, "wallet": 0, "purchased": [], "equipped": [],
		"clearedZones": [], "encounteredBosses": [], "settledRuns": [],
		"best": best, "discovered": {"zones": [], "bosses": [], "events": []}}

func load_profile() -> bool:
	last_error = ""
	if not FileAccess.file_exists(_path):
		if _has_loaded:
			return _fail("프로필 파일이 없어 다시 읽을 수 없습니다.", true)
		data = _empty_profile()
		_writable = true
		_has_loaded = true
		return true
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return _fail("프로필을 읽을 수 없습니다 (%d)." % FileAccess.get_open_error(), true)
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return _fail("프로필 형식이나 값이 손상되었습니다. 원본은 보존했습니다.", true)
	var candidate: Dictionary = parser.data.duplicate(true)
	# Unknown research IDs are ignored on load; known entries and wallet are untouched.
	for key in ["purchased", "equipped"]:
		if typeof(candidate.get(key)) != TYPE_ARRAY:
			return _fail("프로필 형식이나 값이 손상되었습니다. 원본은 보존했습니다.", true)
		var known := []
		for id in candidate[key]:
			if typeof(id) != TYPE_STRING:
				return _fail("프로필 형식이나 값이 손상되었습니다. 원본은 보존했습니다.", true)
			if RESEARCH_PREREQUISITES.has(id): known.append(id)
		candidate[key] = known
	if not _valid_profile(candidate):
		return _fail("프로필 형식이나 값이 손상되었습니다. 원본은 보존했습니다.", true)
	candidate.wallet = int(candidate.wallet)
	data = candidate
	_writable = true
	_has_loaded = true
	return true

func set_in_run(value: bool) -> void:
	_in_run = value

func purchase_research(id: String) -> bool:
	if not _can_change() or not RESEARCH_PREREQUISITES.has(id):
		return _fail("연구 구매를 할 수 없습니다.")
	if data.purchased.has(id):
		return _fail("이미 구매한 연구입니다.")
	for prerequisite in RESEARCH_PREREQUISITES[id]:
		if not data.purchased.has(prerequisite):
			return _fail("선행 연구를 먼저 구매해야 합니다.")
	var cost := _research_cost(id)
	if data.wallet < cost:
		return _fail("연구 잔재가 부족합니다.")
	var next := data.duplicate(true)
	next.wallet -= cost
	next.purchased.append(id)
	return _save(next)

func set_equipped(ids: Array) -> bool:
	if not _can_change():
		return _fail("원정 중에는 연구 구성을 바꿀 수 없습니다.")
	if ids.size() > 6 or not _valid_unique_ids(ids, RESEARCH_PREREQUISITES.keys()):
		return _fail("연구는 중복 없이 최대 6개 장착할 수 있습니다.")
	for id in ids:
		if not data.purchased.has(id):
			return _fail("구매하지 않은 연구는 장착할 수 없습니다.")
	var next := data.duplicate(true)
	next.equipped = ids.duplicate()
	return _save(next)

func for_zone(zone_id: String) -> Dictionary:
	if not ZONES.has(zone_id) or not _valid_profile(data):
		return {}
	var record = data.best[zone_id]
	return {} if record == null else record.duplicate(true)

func complete_run(state: Dictionary) -> Dictionary:
	if not _writable or not _valid_profile(data):
		last_error = "프로필이 손상되어 정산할 수 없습니다."
		return _result(false, false, 0)
	if not _valid_run(state):
		last_error = "원정 결과가 유효하지 않아 정산하지 않았습니다."
		return _result(false, false, 0)
	if data.settledRuns.has(state.runId):
		last_error = ""
		return _result(true, false, 0)
	var next := data.duplicate(true)
	var reward: int = mini(30, int(floor(float(state.time) / 30.0))) + state.completedEvents.size()
	var boss_id: String = state.bossKind
	if state.phase == "won":
		reward += 10
		if not next.clearedZones.has(state.zoneId):
			reward += 8
			next.clearedZones.append(state.zoneId)
	if state.bossSpawned and not next.encounteredBosses.has(boss_id):
		reward += 3
		next.encounteredBosses.append(boss_id)
	if next.wallet > MAX_SAFE - reward:
		last_error = "연구 잔재 한도를 초과하여 정산할 수 없습니다."
		return _result(false, false, 0)
	next.wallet += reward
	next.settledRuns.append(state.runId)
	if not next.discovered.zones.has(state.zoneId):
		next.discovered.zones.append(state.zoneId)
	if state.bossSpawned and not next.discovered.bosses.has(boss_id):
		next.discovered.bosses.append(boss_id)
	for event_id in state.completedEvents:
		if not next.discovered.events.has(event_id):
			next.discovered.events.append(event_id)
	var record := {"time": state.time, "kills": state.get("kills", 0),
		"won": state.phase == "won", "bossDefeated": state.phase == "won"}
	var previous = next.best[state.zoneId]
	if previous == null or _better(record, previous):
		next.best[state.zoneId] = record
	if not _save(next):
		return _result(false, false, 0)
	return _result(true, true, reward)

func _result(ok: bool, credited: bool, reward: int) -> Dictionary:
	return {"ok": ok, "credited": credited, "reward": reward, "error": last_error}

func _can_change() -> bool:
	if _in_run:
		last_error = "원정 중에는 연구를 변경할 수 없습니다."
		return false
	if not _writable or not _valid_profile(data):
		last_error = "프로필이 손상되어 변경할 수 없습니다."
		return false
	return true

func _research_cost(id: String) -> int:
	var number := int(id.substr(1))
	if number <= 4: return 10
	if number <= 12: return 18
	if number <= 20: return 28
	return 40

func _valid_run(state: Dictionary) -> bool:
	if state.get("mode") != "campaign" or not _valid_run_id(state.get("runId")):
		return false
	var zone = state.get("zoneId")
	var boss = state.get("bossKind")
	if typeof(zone) != TYPE_STRING or not ZONES.has(zone) or typeof(boss) != TYPE_STRING or not BOSSES.has(boss):
		return false
	if BOSSES[ZONES.find(zone)] != boss or not _known_catalog_id("zones", zone) or not _known_catalog_id("bosses", boss):
		return false
	if not _valid_number(state.get("time"), 900):
		return false
	if typeof(state.get("bossSpawned")) != TYPE_BOOL or typeof(state.get("bossDefeated")) != TYPE_BOOL:
		return false
	if state.bossDefeated and not state.bossSpawned:
		return false
	if state.bossSpawned != (state.time >= 810):
		return false
	if typeof(state.get("completedEvents")) != TYPE_ARRAY:
		return false
	var opportunities := 0
	for scheduled_time in [90, 270, 450]:
		if state.time >= scheduled_time: opportunities += 1
	if state.completedEvents.size() > opportunities:
		return false
	var events := []
	for number in range(1, 13):
		events.append("E%02d" % number)
	if not _valid_unique_ids(state.completedEvents, events):
		return false
	for event_id in state.completedEvents:
		if not _known_catalog_id("events", event_id):
			return false
	var kills = state.get("kills", 0)
	if not _valid_whole(kills, MAX_SAFE):
		return false
	if state.get("phase") == "won":
		return state.get("endReason") == "boss-defeated" and state.bossDefeated and state.time < 900
	if state.get("phase") == "lost":
		if state.get("endReason") == "death": return true
		return state.get("endReason") == "timeout" and state.time == 900
	return false

func _known_catalog_id(kind: String, id: String) -> bool:
	if _catalog.is_empty():
		return true
	var entries = _catalog.get(kind, [])
	if typeof(entries) == TYPE_DICTIONARY:
		return entries.has(id)
	if typeof(entries) == TYPE_ARRAY:
		for entry in entries:
			if typeof(entry) == TYPE_STRING and entry == id:
				return true
			if typeof(entry) == TYPE_DICTIONARY and entry.get("id") == id:
				return true
	return false

func _valid_profile(profile: Variant) -> bool:
	if typeof(profile) != TYPE_DICTIONARY or profile.get("version") != 1 or not _valid_whole(profile.get("wallet"), MAX_SAFE):
		return false
	for key in ["purchased", "equipped", "clearedZones", "encounteredBosses", "settledRuns"]:
		if typeof(profile.get(key)) != TYPE_ARRAY:
			return false
	if not _valid_unique_ids(profile.purchased, RESEARCH_PREREQUISITES.keys()) or profile.equipped.size() > 6 or not _valid_unique_ids(profile.equipped, RESEARCH_PREREQUISITES.keys()):
		return false
	for id in profile.equipped:
		if not profile.purchased.has(id): return false
	for id in profile.purchased:
		for prerequisite in RESEARCH_PREREQUISITES[id]:
			if not profile.purchased.has(prerequisite): return false
	if not _valid_unique_ids(profile.clearedZones, ZONES) or not _valid_unique_ids(profile.encounteredBosses, BOSSES):
		return false
	var run_ids := {}
	for id in profile.settledRuns:
		if not _valid_run_id(id) or run_ids.has(id): return false
		run_ids[id] = true
	if typeof(profile.get("best")) != TYPE_DICTIONARY or profile.best.size() != 6:
		return false
	for zone in ZONES:
		if not profile.best.has(zone): return false
		var record = profile.best[zone]
		if record != null and not _valid_record(record): return false
	var discovered = profile.get("discovered")
	if typeof(discovered) != TYPE_DICTIONARY:
		return false
	for kind in ["zones", "bosses", "events"]:
		if typeof(discovered.get(kind)) != TYPE_ARRAY: return false
	var events := []
	for number in range(1, 13): events.append("E%02d" % number)
	if not _valid_unique_ids(discovered.zones, ZONES) or not _valid_unique_ids(discovered.bosses, BOSSES) or not _valid_unique_ids(discovered.events, events):
		return false
	for zone in ZONES:
		var boss: String = BOSSES[ZONES.find(zone)]
		var record = profile.best[zone]
		var cleared: bool = profile.clearedZones.has(zone)
		var encountered: bool = profile.encounteredBosses.has(boss)
		if encountered != discovered.bosses.has(boss): return false
		if encountered and (record == null or not discovered.zones.has(zone)): return false
		if cleared and (not encountered or not discovered.zones.has(zone)): return false
		if record != null:
			if not discovered.zones.has(zone) or record.won != cleared: return false
			if record.time >= 810 and not encountered: return false
		elif cleared:
			return false
	return true

func _valid_record(record: Variant) -> bool:
	return typeof(record) == TYPE_DICTIONARY and _valid_number(record.get("time"), 900) and _valid_whole(record.get("kills"), MAX_SAFE) and typeof(record.get("won")) == TYPE_BOOL and typeof(record.get("bossDefeated")) == TYPE_BOOL and ((record.won and record.bossDefeated and record.time >= 810 and record.time < 900) or (not record.won and not record.bossDefeated))

func _valid_unique_ids(ids: Array, allowed: Array) -> bool:
	var seen := {}
	for id in ids:
		if typeof(id) != TYPE_STRING or not allowed.has(id) or seen.has(id): return false
		seen[id] = true
	return true

func _valid_run_id(id: Variant) -> bool:
	return typeof(id) == TYPE_STRING and id.length() > 0 and id.length() <= 128 and id.strip_edges() == id and not id.contains("\n")

func _valid_number(value: Variant, maximum: float) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and value >= 0 and value <= maximum

func _valid_whole(value: Variant, maximum: int) -> bool:
	return _valid_number(value, float(maximum)) and floor(float(value)) == float(value)

func _better(next: Dictionary, previous: Dictionary) -> bool:
	if next.won != previous.won: return next.won
	if next.won and next.time != previous.time: return next.time < previous.time
	return next.time > previous.time or (next.time == previous.time and next.kills > previous.kills)

func _save(next: Dictionary) -> bool:
	if not _valid_profile(next):
		return _fail("프로필 변경 값이 올바르지 않습니다.")
	var temporary := _path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("프로필을 저장할 수 없습니다 (%d)." % FileAccess.get_open_error())
	file.store_string(JSON.stringify(next))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("프로필을 저장할 수 없습니다 (%d)." % error)
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(_path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("프로필을 교체할 수 없습니다 (%d)." % error)
	data = next
	_has_loaded = true
	last_error = ""
	return true

func _fail(message: String, block_writes: bool = false) -> bool:
	last_error = message
	if block_writes:
		_writable = false
		_has_loaded = true
	return false
