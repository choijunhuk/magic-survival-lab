extends CanvasLayer

const BODY_FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const MAGIC_FONT = preload("res://assets/fonts/MagicSurvival.ttf")
const FOREST_TEXTURE = preload("res://assets/generated/zone-forest.png")
const ZONE_PREVIEWS = {
	"Z01": FOREST_TEXTURE,
	"Z02": preload("res://assets/generated/release-maps/z02-preview.png"),
	"Z03": preload("res://assets/generated/release-maps/z03-preview.png"),
	"Z04": preload("res://assets/generated/release-maps/z04-preview.png"),
	"Z05": preload("res://assets/generated/release-maps/z05-preview.png"),
	"Z06": preload("res://assets/generated/release-maps/z06-preview.png"),
}
const FIREBALL_TEXTURE = preload("res://assets/generated/icon-fireball.png")
const ICON_SHADER = preload("res://shaders/mono_icon.gdshader")
const ENCOUNTERS = preload("res://scripts/release_encounters.gd")
const OCCULT_MEDALLION = preload("res://scripts/occult_medallion.gd")
const WHITE = Color("#f2f3eb")
const CYAN = Color("#60eadb")
const YELLOW = Color("#ffdf56")
const GREEN = Color("#8afa31")
const DIM = Color("#a6a9a1")
const BLUE = Color("#50b9ff")
const BLACK = Color("#020302")

var game: Node
var body_font: FontVariation
var root: Control
var phase_box: Control
var hub_header: HBoxContainer
var hub_scroll: ScrollContainer
var hub_footer: VBoxContainer
var hub_content: VBoxContainer
var pause_home: Button
var pause_recipe_list: VBoxContainer
var pause_recipe_toggle: Button
var top_box: Control
var xp_bar: ProgressBar
var time_label: Label
var pause_button: Button
var boss_box: Control
var boss_bar: ProgressBar
var boss_direction: Label
var forest_art: TextureRect
var medallion: Control
var phase_key := ""
var choice_key := ""
var mode_choice := "campaign"
var hub_tab := "map"
var zone_index := 0
var class_index := 0
var campaign_catalog: Dictionary = {}
var release_icons: Dictionary = {}
var hub_error := ""
var seed_valid := true
var codex_section := "upgrades"
var codex_search := ""
var codex_detail := ""
var codex_material := ""
var hint_label: Label
var practice_label: Label
var texture_cache: Dictionary = {}
var style_cache: Dictionary = {}
var icon_material: ShaderMaterial
var passive_icon_material: ShaderMaterial
var forest_material: ShaderMaterial
var last_size := Vector2.ZERO

func setup(owner_game: Node) -> void:
	game = owner_game
	var file := FileAccess.open("res://data/release_content.json", FileAccess.READ)
	if file: campaign_catalog = JSON.parse_string(file.get_as_text())
	var icon_file := FileAccess.open("res://data/release_icons.json", FileAccess.READ)
	if icon_file:
		var parsed = JSON.parse_string(icon_file.get_as_text())
		if parsed is Dictionary: release_icons = parsed.get("icons", {})
	if release_icons.size() != 132: push_error("Release icon map is incomplete")
	body_font = FontVariation.new()
	body_font.base_font = BODY_FONT
	body_font.variation_opentype = {"wght": 500}
	body_font.variation_embolden = 0.45
	icon_material = ShaderMaterial.new()
	icon_material.shader = ICON_SHADER
	passive_icon_material = ShaderMaterial.new()
	passive_icon_material.shader = ICON_SHADER
	passive_icon_material.set_shader_parameter("ink_color", Color("#a4cf8f"))
	passive_icon_material.set_shader_parameter("line_art", 1.0)
	forest_material = ShaderMaterial.new()
	var edge_shader := Shader.new()
	edge_shader.code = "shader_type canvas_item;\nvoid fragment() {\n vec4 pixel = texture(TEXTURE, UV);\n float edge_x = 0.003 + 0.005 * abs(sin(UV.y * 307.0) + 0.35 * sin(UV.y * 917.0));\n float edge_y = 0.003 + 0.005 * abs(sin(UV.x * 283.0) + 0.35 * sin(UV.x * 839.0));\n float inside = step(edge_x, UV.x) * step(UV.x, 1.0 - edge_x) * step(edge_y, UV.y) * step(UV.y, 1.0 - edge_y);\n COLOR = vec4(pixel.rgb, pixel.a * inside);\n}"
	forest_material.shader = edge_shader
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.resized.connect(_on_resized)
	_build_play_hud()

func refresh(state: Dictionary, catalog: Dictionary, record: Dictionary, error: String = "") -> void:
	if root == null:
		return
	var phase: String = state.get("phase", "ready")
	if phase == "event_practice" and is_instance_valid(practice_label):
		practice_label.text = "남은 시간 %.1f  ·  정답 %d\n%s" % [float(state.get("eventPracticeTime", 0)), int(state.get("practiceCorrect", 0)), str(state.get("practiceFeedback", ""))]
	var options: Array = state.get("choices", []) if phase == "upgrade" else state.get("artifactChoices", [])
	var next_choice_key := JSON.stringify([options, state.get("eventChoices", []), state.get("resonanceChoices", []), state.get("activeEvent", {}), game.practice_suspended, state.get("upgradeRerolls", 0), state.get("artifactRerolls", 0), state.get("artifactRuntime", {}).get("a072Used", false)])
	if phase_key != phase or (phase in ["upgrade", "artifact", "event", "resonance", "event_practice"] and choice_key != next_choice_key):
		phase_key = phase
		choice_key = next_choice_key
		_build_phase(state, catalog, record, error)
	top_box.visible = phase != "ready"
	top_box.modulate.a = 1.0 if phase == "playing" else 0.5
	pause_button.mouse_filter = Control.MOUSE_FILTER_STOP if phase == "playing" else Control.MOUSE_FILTER_IGNORE
	if phase != "ready":
		var seconds := int(state.get("time", 0))
		time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		xp_bar.value = 100.0 * float(state.get("xp", 0)) / maxf(1.0, float(state.get("xpNeeded", 1)))
		_update_boss(state)
		_update_research_hint(state)
	if last_size != root.size:
		_on_resized()

func _build_play_hud() -> void:
	top_box = Control.new()
	top_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_box.offset_bottom = 66
	top_box.z_index = 1
	top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_box)
	xp_bar = _bar(BLUE, 3)
	xp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	xp_bar.offset_bottom = 3
	top_box.add_child(xp_bar)
	var strip := ColorRect.new()
	strip.color = Color(0.02, 0.02, 0.015, 0.53)
	strip.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 3
	strip.offset_bottom = 53
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(strip)
	time_label = _label("00:00", 50, WHITE, true)
	time_label.position = Vector2(18, 7)
	time_label.custom_minimum_size = Vector2(150, 44)
	top_box.add_child(time_label)
	pause_button = _button("II", false, true)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -64
	pause_button.offset_right = -8
	pause_button.offset_top = 4
	pause_button.offset_bottom = 52
	pause_button.add_theme_font_size_override("font_size", 48)
	pause_button.pressed.connect(func() -> void: game.pause_run())
	top_box.add_child(pause_button)
	hint_label = _label("", 18, WHITE)
	hint_label.position = Vector2(12, 68)
	hint_label.add_theme_stylebox_override("normal", _style("hint_back"))
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	top_box.add_child(hint_label)
	boss_box = Control.new()
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_box.offset_top = 54
	boss_box.offset_bottom = 64
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_box.add_child(boss_box)
	boss_bar = _bar(Color("#d66b5f"), 5)
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boss_bar.offset_left = 36
	boss_bar.offset_right = -36
	boss_bar.offset_top = 2
	boss_bar.offset_bottom = 7
	boss_box.add_child(boss_bar)
	boss_direction = _label("", 16, WHITE)
	boss_direction.position = Vector2(36, 12)
	boss_direction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.add_child(boss_direction)

func _update_research_hint(state: Dictionary) -> void:
	var hints: Dictionary = state.get("researchHints", {})
	var lines: Array[String] = []
	if hints.get("firstPhenomenonPreview", false) and hints.has("nextPhenomenon") and float(state.get("time", 0)) < float(hints.nextPhenomenon.get("time", 0)):
		lines.append("첫 현상까지 %.1f초" % maxf(0, float(hints.nextPhenomenon.get("time", 0)) - float(state.get("time", 0))))
	if hints.get("phenomenonMeter", false) and lines.is_empty():
		var start := float(ENCOUNTERS.PHENOMENON_START.get(state.get("zoneId", "Z01"), 75.0))
		var remaining := maxf(0, start - float(state.get("time", 0))) if float(state.get("time", 0)) < start else maxf(0, float(state.get("phenomenonTimer", 0)))
		lines.append("현상까지 %.1f초" % remaining)
	hint_label.text = "  ·  ".join(lines)
	hint_label.visible = not lines.is_empty()

func _build_phase(state: Dictionary, catalog: Dictionary, record: Dictionary, error: String) -> void:
	hub_header = null
	hub_scroll = null
	hub_footer = null
	hub_content = null
	if phase_box != null:
		phase_box.queue_free()
	phase_box = Control.new()
	phase_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	phase_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(phase_box)
	var phase: String = state.get("phase", "ready")
	if phase == "playing":
		phase_box.visible = false
		return
	if phase == "event_practice":
		_practice_screen(state)
		return
	if phase == "ready":
		_build_hub(record, error)
		return
	var shade := ColorRect.new()
	shade.color = BLACK if phase == "ready" else Color(0.015, 0.017, 0.012, 0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	phase_box.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	phase_box.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	center.add_child(content)
	match phase:
		"paused": _pause(content, state, catalog)
		"upgrade", "artifact": _choices(content, state)
		"event": _event_choice(content, state)
		"resonance": _resonance_choice(content, state)
		"won", "lost": _result(content, state)
	if phase in ["upgrade", "artifact"]:
		medallion = OCCULT_MEDALLION.new()
		medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
		phase_box.add_child(medallion)
		_position_medallion()
	if error != "":
		var message := _label("기록 저장 실패: " + error, 14, Color("#e9a19e"))
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(message)
	_apply_safe_margin(margin)
	_fit_content(content)

func _build_hub(record: Dictionary, error: String) -> void:
	var shade := ColorRect.new()
	shade.color = BLACK
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	phase_box.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	phase_box.add_child(margin)
	_apply_safe_margin(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)
	hub_header = HBoxContainer.new()
	layout.add_child(hub_header)
	for tab in ["map", "class", "research", "codex", "records", "mode"]:
		var button := _button({"map":"지역", "class":"직업", "research":"연구", "codex":"도감", "records":"기록", "mode":"모드"}[tab], false)
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_color_override("font_color", CYAN if hub_tab == tab else WHITE)
		button.add_theme_stylebox_override("normal", _style("selected" if hub_tab == tab else "quiet"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_tab.bind(tab))
		hub_header.add_child(button)
	hub_scroll = ScrollContainer.new()
	hub_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hub_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(hub_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hub_scroll.add_child(center)
	hub_content = VBoxContainer.new()
	hub_content.add_theme_constant_override("separation", 12)
	center.add_child(hub_content)
	_fit_content(hub_content)
	if hub_error != "":
		var err := _label(hub_error, 15, Color("#e9a19e")); err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hub_content.add_child(err)
	match hub_tab:
		"map": _hub_map(hub_content, record)
		"class": _hub_class(hub_content)
		"research": _hub_research(hub_content)
		"codex": _hub_codex(hub_content)
		"records": _hub_records(hub_content)
		"mode": _hub_mode(hub_content)
	if error != "":
		var message := _label("기록 저장 실패: " + error, 14, Color("#e9a19e"))
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; hub_content.add_child(message)
	hub_footer = VBoxContainer.new()
	hub_footer.add_theme_constant_override("separation", 2)
	layout.add_child(hub_footer)
	var summary := _label(_mode_summary(), 16, CYAN)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hub_footer.add_child(summary)
	var start := _button("PLAY", true, true)
	start.add_theme_font_size_override("font_size", 46)
	start.pressed.connect(_start_selected)
	hub_footer.add_child(start)

func _mode_summary() -> String:
	var selected_class := _find_name(campaign_catalog.get("classes", []), game.selected_class)
	match mode_choice:
		"quick": return "빠른 전투 · 5분 생존 · 기본 전장/마나 창"
		"expedition": return "원정 · 10분 · 8분 30초 보스 · 처치 시 승리
기본 전장/마나 창"
		"practice": return "연습 · 2초 후 보스 · 보상 없음\n계열: " + selected_class
		"seededchallenge": return "시드 도전 · 15분 · 13분 30초 보스 · 처치 시 승리\n보상 없음 · 계열: " + selected_class
		_: return "캠페인 · 15분 · 13분 30초 보스 · 처치 시 승리\n계열: " + selected_class

func _start_selected() -> void:
	if mode_choice == "seededchallenge" and not seed_valid:
		hub_error = "시드는 0부터 2147483647까지의 숫자여야 합니다."
		_rebuild_hub()
		return
	game.begin(mode_choice)

func _select_tab(tab: String) -> void:
	hub_tab = tab
	hub_error = ""
	_rebuild_hub()

func _rebuild_hub() -> void:
	_build_phase(game.sim.state, game.sim.catalog, game.records.for_mode(mode_choice) if mode_choice in ["quick", "expedition"] else game.profile.for_zone(game.selected_zone), game.record_error)

func _change_zone(step: int) -> void:
	zone_index = posmod(zone_index + step, campaign_catalog.get("zones", []).size())
	game.selected_zone = campaign_catalog.zones[zone_index].id
	_rebuild_hub()

func _hub_map(content: VBoxContainer, record: Dictionary) -> void:
	var zones: Array = campaign_catalog.get("zones", [])
	if zones.is_empty(): return
	var item: Dictionary = zones[zone_index]
	var row := HBoxContainer.new(); content.add_child(row)
	var left := _button("<", false); left.pressed.connect(_change_zone.bind(-1)); row.add_child(left)
	var title := _label("%s  %d / %d" % [item.name, zone_index + 1, zones.size()], 24, WHITE); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(title)
	var right := _button(">", false); right.pressed.connect(_change_zone.bind(1)); row.add_child(right)
	var center := CenterContainer.new(); content.add_child(center)
	forest_art = TextureRect.new(); forest_art.texture = ZONE_PREVIEWS[item.id]
	forest_art.material = forest_material
	forest_art.custom_minimum_size = _forest_size()
	forest_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; forest_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; center.add_child(forest_art)
	var zone_text := "선택한 지역 현상은 이 모드에 적용되지 않습니다." if mode_choice in ["quick", "expedition"] else str(item.get("phenomenon", "")).split(". ", false, 1)[0] + "."
	var desc := _label(zone_text, 18, WHITE); desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(desc)
	var best := int(record.get("time", 0)); var best_text := "BEST TIME  --:--" if best <= 0 else "BEST TIME  %02d:%02d" % [best / 60, best % 60]
	var label := _label(best_text, 27, GREEN, true); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; content.add_child(label)

func _hub_class(content: VBoxContainer) -> void:
	_heading(content, "CLASS")
	for item in campaign_catalog.get("classes", []):
		var button := _button("%s  %s\n%s" % ["●" if game.selected_class == item.id else "○", item.name, _display_text(str(item.description))], false)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_select_class.bind(str(item.id))); content.add_child(button)

func _select_class(id: String) -> void:
	game.selected_class = id
	_rebuild_hub()

func _hub_research(content: VBoxContainer) -> void:
	_heading(content, "RESEARCH")
	content.add_child(_label("연구 잔재 %d  ·  장착 %d / 6" % [game.profile.data.wallet, game.profile.data.equipped.size()], 17, GREEN))
	for item in campaign_catalog.get("research", []):
		var purchased: bool = game.profile.data.purchased.has(item.id)
		var equipped: bool = game.profile.data.equipped.has(item.id)
		var prerequisite_names: Array[String] = []
		for id in item.get("requires", []): prerequisite_names.append(_find_name(campaign_catalog.research, str(id)))
		var text_value := "%s  ·  %s\n%s\n선행: %s" % [item.name, ("장착 중" if equipped else "장착" if purchased else "구매 %d" % int(item.cost)), _display_text(str(item.description)), ", ".join(prerequisite_names) if not prerequisite_names.is_empty() else "없음"]
		var button := _button(text_value, false); button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_research_action.bind(str(item.id))); content.add_child(button)

func _research_action(id: String) -> void:
	var ok: bool
	if game.profile.data.purchased.has(id):
		var equipped: Array = game.profile.data.equipped.duplicate()
		if equipped.has(id): equipped.erase(id)
		else: equipped.append(id)
		ok = game.profile.set_equipped(equipped)
	else: ok = game.profile.purchase_research(id)
	hub_error = "" if ok else game.profile.last_error
	_rebuild_hub()

func _hub_codex(content: VBoxContainer) -> void:
	_heading(content, "CODEX")
	var row := HBoxContainer.new(); content.add_child(row)
	for section in ["upgrades", "fusions", "artifacts"]:
		var button := _button({"upgrades":"마법", "fusions":"융합", "artifacts":"유물"}[section], false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", CYAN if section == codex_section else WHITE)
		button.pressed.connect(_set_codex_section.bind(section)); row.add_child(button)
	if game.profile.data.equipped.has("R07"):
		var discoveries: Dictionary = game.profile.data.discovered
		var names: Array[String] = []
		for id in discoveries.get("bosses", []): names.append(_find_name(campaign_catalog.get("bosses", []), str(id)))
		for id in discoveries.get("events", []): names.append(_find_name(campaign_catalog.get("events", []), str(id)))
		var clue := _label("발견 단서: " + (", ".join(names) if not names.is_empty() else "아직 발견한 단서가 없습니다"), 15, DIM)
		clue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(clue)
	if codex_section == "fusions" and game.profile.data.equipped.has("R19"):
		var material := LineEdit.new(); material.placeholder_text = "재료 마법 이름으로 필터"; material.text = codex_material; material.custom_minimum_size.y = 48
		material.text_submitted.connect(_set_codex_material); content.add_child(material)
		var filter_button := _button("재료 필터 적용", false)
		filter_button.pressed.connect(func() -> void: _set_codex_material(material.text)); content.add_child(filter_button)
	var search := LineEdit.new(); search.placeholder_text = "이름 검색"; search.text = codex_search; search.custom_minimum_size.y = 48
	search.text_submitted.connect(_search_codex); content.add_child(search)
	var find := _button("검색", false); find.pressed.connect(func() -> void: _search_codex(search.text)); content.add_child(find)
	for item in campaign_catalog.get(codex_section, []):
		if codex_section == "upgrades" and not campaign_catalog.spellIds.has(item.id): continue
		if codex_section == "fusions" and game.profile.data.equipped.has("R19") and codex_material != "":
			var matched := false
			for id in item.get("requires", {}):
				if _find_name(campaign_catalog.upgrades, str(id)).to_lower().contains(codex_material.to_lower()): matched = true
			if not matched: continue
		if codex_search != "" and not str(item.name).to_lower().contains(codex_search.to_lower()): continue
		var button := _button(str(item.name), false)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_show_codex_detail.bind(str(item.id))); content.add_child(button)
		if codex_detail == item.id:
			var details := _display_text(str(item.get("effect", item.get("description", ""))))
			if item.has("requires"):
				var recipe: Array[String] = []
				for id in item.requires: recipe.append("%s Lv.%d" % [_find_name(campaign_catalog.upgrades, str(id)), int(item.requires[id])])
				details += "\n조합: " + " + ".join(recipe)
			var label := _label(details, 17, DIM); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(label)

func _display_text(value: String) -> String:
	var regex := RegEx.new(); regex.compile("\\b[MCFRZAEB][0-9]{2,3}\\b")
	var parts := value.split(";"); var readable: Array[String] = []
	for part in parts:
		if regex.search(part) == null: readable.append(part.strip_edges())
	return "; ".join(readable)

func _set_codex_material(value: String) -> void:
	codex_material = value.strip_edges(); codex_detail = ""; _rebuild_hub()
func _set_codex_section(section: String) -> void:
	codex_section = section; codex_detail = ""; _rebuild_hub()
func _search_codex(value: String) -> void:
	codex_search = value.strip_edges(); codex_detail = ""; _rebuild_hub()
func _show_codex_detail(id: String) -> void:
	codex_detail = "" if codex_detail == id else id; _rebuild_hub()

func _hub_records(content: VBoxContainer) -> void:
	_heading(content, "RECORDS")
	for zone in campaign_catalog.get("zones", []):
		var best: Dictionary = game.profile.for_zone(zone.id); var seconds := int(best.get("time", 0))
		content.add_child(_label("%s  ·  %s" % [zone.name, ("%02d:%02d" % [seconds / 60, seconds % 60]) if seconds > 0 else "기록 없음"], 18, WHITE))

func _hub_mode(content: VBoxContainer) -> void:
	_heading(content, "MODE")
	for id in ["campaign", "quick", "expedition", "practice", "seededchallenge"]:
		var names := {"campaign":"캠페인 · 15분", "quick":"빠른 전투 · 5분", "expedition":"원정 · 10분", "practice":"연습 · 보상 없음", "seededchallenge":"시드 도전 · 보상 없음"}
		var button := _button(("● " if mode_choice == id else "○ ") + names[id], false)
		button.pressed.connect(_select_mode.bind(id)); content.add_child(button)
	if mode_choice == "seededchallenge":
		content.add_child(_label("시드 (0–2147483647)", 17, WHITE))
		var seed_entry := LineEdit.new()
		seed_entry.text = str(game.challenge_seed)
		seed_entry.custom_minimum_size.y = 48
		seed_entry.text_changed.connect(_set_challenge_seed)
		content.add_child(seed_entry)

func _set_challenge_seed(value: String) -> void:
	if value.is_valid_int() and int(value) >= 0 and int(value) <= 2147483647:
		game.challenge_seed = int(value)
		seed_valid = true
		hub_error = ""
	else:
		seed_valid = false
		hub_error = "시드는 0부터 2147483647까지의 숫자여야 합니다."


func _select_mode(id: String) -> void:
	mode_choice = id
	game.selected_mode = id
	_rebuild_hub()

func _event_choice(content: VBoxContainer, state: Dictionary) -> void:
	var event: Dictionary = state.get("activeEvent", {})
	_heading(content, str(event.get("name", "EVENT")))
	for key in ["description", "reward", "condition", "declineOrFailure"]:
		var label := _label(str(event.get(key, "")), 18, WHITE); label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(label)
	for option in state.get("eventChoices", []):
		var button := _button(str(option.get("name", option.get("id", ""))), false)
		button.disabled = not option.get("enabled", true)
		button.pressed.connect(_event_action.bind(str(option.get("id", "accept")))); content.add_child(button)
	var decline := _button("거절", false); decline.pressed.connect(_event_decline); content.add_child(decline)

func _event_action(id: String) -> void:
	game.sim.choose_event(id); game._refresh_hud()
func _event_decline() -> void:
	game.sim.decline_event(); game._refresh_hud()
func _practice_screen(state: Dictionary) -> void:
	if game.practice_suspended:
		var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.75)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); phase_box.add_child(shade)
		var center := CenterContainer.new(); center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); phase_box.add_child(center)
		var resume := _button("RESUME", true, true); resume.add_theme_font_size_override("font_size", 46)
		resume.pressed.connect(_resume_practice); center.add_child(resume)
		return
	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16; top.offset_right = -16; top.offset_top = _safe_insets().y + 70
	phase_box.add_child(top)
	_heading(top, "PRACTICE")
	practice_label = _label("남은 시간 %.1f  ·  정답 %d" % [float(state.get("eventPracticeTime", 0)), int(state.get("practiceCorrect", 0))], 20, WHITE)
	practice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; top.add_child(practice_label)
	var instruction := _label("경고를 보고 안전한 이동 방향을 고르세요", 16, WHITE)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; top.add_child(instruction)
	var answers := VBoxContainer.new()
	answers.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	answers.offset_left = 16; answers.offset_right = -16
	answers.offset_top = -220 - _safe_insets().w; answers.offset_bottom = -12 - _safe_insets().w
	answers.add_theme_constant_override("separation", 2)
	phase_box.add_child(answers)
	for option in state.get("practiceAnswers", []):
		var button := _button(str(option.name), false)
		button.add_theme_stylebox_override("normal", _style("ink_card"))
		button.pressed.connect(_practice_answer.bind(str(option.id))); answers.add_child(button)
func _resume_practice() -> void:
	game.practice_suspended = false
	game._refresh_hud()
func _practice_answer(id: String) -> void:
	game.sim.choose_practice_answer(id); game.queue_redraw(); game._refresh_hud()
func _resonance_choice(content: VBoxContainer, state: Dictionary) -> void:
	_heading(content, "RESONANCE")
	content.add_child(_label("대상: " + str(state.get("resonanceTarget", "")), 18, WHITE))
	for option in state.get("resonanceChoices", []):
		var button := _button("%s\n%s\n%s" % [option.get("name", ""), option.get("benefit", option.get("description", "")), option.get("cost", "")], false)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; button.pressed.connect(_resonance_action.bind(str(option.get("id", "")))); content.add_child(button)
	var decline := _button("거절", false); decline.pressed.connect(_resonance_decline); content.add_child(decline)
func _resonance_action(id: String) -> void:
	game.sim.choose_resonance(id); game._refresh_hud()
func _resonance_decline() -> void:
	game.sim.decline_resonance(); game._refresh_hud()

func _pause(content: VBoxContainer, state: Dictionary, catalog: Dictionary) -> void:
	_heading(content, "PAUSED")
	var seconds := int(state.get("time", 0))
	content.add_child(_label("%02d:%02d   ·   Lv.%d   ·   처치 %d" % [seconds / 60, seconds % 60, int(state.get("level", 1)), int(state.get("kills", 0))], 16, WHITE))
	var resume := _button("RESUME", true, true)
	resume.add_theme_font_size_override("font_size", 46)
	resume.custom_minimum_size.y = 62
	resume.pressed.connect(func() -> void: game.pause_run())
	content.add_child(resume)
	var home := _button("거점 · 보상 없이 포기", false)
	home.custom_minimum_size.y = 56
	home.pressed.connect(func() -> void: game.go_home())
	pause_home = home
	content.add_child(home)
	_spacer(content, 12)
	content.add_child(_label("GRIMOIRE", 23, CYAN, true))
	var loadout := _label(_loadout_full(state, catalog), 17, WHITE)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(loadout)
	_spacer(content, 9)
	pause_recipe_toggle = _button("전체 조합식 보기 (%d)" % catalog.get("fusions", []).size(), false)
	pause_recipe_toggle.pressed.connect(_toggle_pause_recipes)
	content.add_child(pause_recipe_toggle)
	pause_recipe_list = VBoxContainer.new()
	pause_recipe_list.visible = false
	content.add_child(pause_recipe_list)
	for fusion in catalog.get("fusions", []):
		var requires: Dictionary = fusion.get("requires", {})
		var names: Array[String] = []
		for key in requires:
			names.append(_find_name(catalog.get("upgrades", []), str(key)) + " Lv.%d" % int(requires[key]))
		var recipe := _label("%s  ·  %s" % [fusion.get("name", ""), " + ".join(names)], 14, DIM)
		recipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pause_recipe_list.add_child(recipe)

func _toggle_pause_recipes() -> void:
	pause_recipe_list.visible = not pause_recipe_list.visible
	pause_recipe_toggle.text = "조합식 접기" if pause_recipe_list.visible else "전체 조합식 보기 (%d)" % pause_recipe_list.get_child_count()


func _choices(content: VBoxContainer, state: Dictionary) -> void:
	var artifact: bool = state.get("phase") == "artifact"
	_spacer(content, 22)
	var current := _label("Current Level : %d" % int(state.get("level", 1)), 30, YELLOW, true)
	current.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(current)
	_spacer(content, 13)
	var title := _label("Select Artifact" if artifact else "Select Magic", 64, CYAN, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	_spacer(content, 27)
	var options: Array = state.get("artifactChoices", []) if artifact else state.get("choices", [])
	if not artifact and state.get("researchHints", {}).get("fusionHint", false):
		for fusion in game.sim.catalog.get("fusions", []):
			var learned := false
			for id in fusion.get("requires", {}):
				if int(state.get("spells", {}).get(id, 0)) > 0: learned = true
			if learned and not state.get("fusions", []).has(fusion.id):
				var recipe: Array[String] = []
				for id in fusion.requires: recipe.append("%s Lv.%d" % [_find_name(game.sim.catalog.upgrades, str(id)), int(fusion.requires[id])])
				var hint := _label("조합 단서: " + " + ".join(recipe), 15, CYAN); hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(hint)
				break
	for option in options:
		var id: String = option.get("id", "")
		var card := Button.new()
		card.custom_minimum_size.y = 190 if not artifact and state.get("researchHints", {}).get("compareFrequency", false) else 151
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_stylebox_override("normal", _style("ink_card"))
		card.add_theme_stylebox_override("hover", _style("ink_card_hover"))
		card.add_theme_stylebox_override("pressed", _style("ink_card_hover"))
		card.add_theme_stylebox_override("focus", _style("focus"))
		card.pressed.connect(func() -> void: game.choose(id))
		content.add_child(card)
		var row := HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 18
		row.offset_right = -18
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		var icon := TextureRect.new()
		var icon_path := str(release_icons.get(id, option.get("icon", "")))
		if id == "fireball":
			icon_path = "assets/generated/icon-fireball.png"
		icon.texture = _icon(icon_path)
		icon.material = icon_material
		icon.custom_minimum_size = Vector2(104, 104)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		if icon.texture == null:
			push_error("Missing choice icon for " + id)
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var name := _label(str(option.get("name", id)), 20, WHITE)
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(name)
		var desc := _label(str(option.get("description", "")), 17, GREEN if state.get("stats", {}).has(id) else WHITE)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(desc)
		if not artifact and state.get("researchHints", {}).get("compareFrequency", false) and game.sim.has_method("upgrade_frequency"):
			var frequency := _frequency_text(game.sim.upgrade_frequency(id), game.sim.catalog)
			if frequency != "":
				var frequency_label := _label(frequency, 14, CYAN)
				frequency_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(frequency_label)
		var spells: Dictionary = state.get("spells", {})
		var stats: Dictionary = state.get("stats", {})
		var is_fusion: bool = option.get("kind", "") == "fusion"
		var is_passive: bool = stats.has(id)
		var level := int(spells.get(id, stats.get(id, 0))) + 1
		var level_text := "FUSION" if is_fusion else "Lv %d" % level if not artifact else "ARTIFACT"
		var level_label := _label(str(option.get("rarity", "유물")) if artifact else level_text, 16 if artifact else 34, YELLOW, not artifact)
		level_label.custom_minimum_size.x = 74
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(level_label)
		if is_passive:
			icon.material = passive_icon_material
	if not artifact and state.get("artifacts", []).has("a072") and not state.get("artifactRuntime", {}).get("a072Used", false):
		var special := _button("유물 효과 · 후보 모두 재추첨", false)
		special.pressed.connect(_artifact_reroll); content.add_child(special)
	if game.sim.has_method("reroll_upgrade"):
		var count := int(state.get("artifactRerolls", 0) if artifact else state.get("upgradeRerolls", 0))
		if count > 0 and not options.is_empty():
			var controls := HBoxContainer.new()
			controls.add_theme_constant_override("separation", 6)
			content.add_child(controls)
			var remaining := _label("재추첨 %d회" % count, 16, CYAN)
			remaining.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			controls.add_child(remaining)
			for i in range(options.size()):
				var reroll := _button("%d번" % (i + 1), false)
				reroll.add_theme_stylebox_override("normal", _style("reroll"))
				reroll.custom_minimum_size.x = 64
				reroll.pressed.connect(_reroll.bind(i, artifact)); controls.add_child(reroll)
	_spacer(content, 40)

func _frequency_text(data: Dictionary, catalog: Dictionary) -> String:
	var unit := str(data.get("unit", ""))
	var condition := " · 조건부" if data.get("conditional", false) else ""
	if data.get("targetRequired", false): condition += " · 대상 필요"
	if unit == "seconds":
		var current := float(data.get("currentInterval", -1))
		var next := float(data.get("nextInterval", -1))
		if next < 0: return ""
		return ("현재 %.1f초 → 다음 %.1f초" % [current, next] if current >= 0 else "획득 시 %.1f초" % next) + condition
	if unit == "kills":
		return "현재 %d처치 → 다음 %d처치%s" % [int(data.get("currentCount", 0)), int(data.get("nextCount", 0)), condition]
	if unit == "fusion":
		var parts: Array[String] = []
		for material in data.get("materials", []):
			var interval := float(material.get("currentInterval", -1))
			if interval >= 0: parts.append("%s %.1f초" % [_find_name(catalog.get("upgrades", []), str(material.id)), interval])
		return ("재료 발동 간격: " + ", ".join(parts) + condition) if not parts.is_empty() else ""
	return ""

func _artifact_reroll() -> void:
	game.sim.reroll_artifact_upgrade(); game._refresh_hud()

func _reroll(index: int, artifact: bool) -> void:
	if artifact: game.sim.reroll_artifact(index)
	else: game.sim.reroll_upgrade(index)
	game._refresh_hud()

func _result(content: VBoxContainer, state: Dictionary) -> void:
	_heading(content, "SURVIVED" if state.get("phase") == "won" else "GAME OVER")
	var reason: String = str(state.get("endReason", ""))
	var reason_text: String = {"death": "생명력이 다했습니다", "timeout": "제한 시간이 끝났습니다", "survived": "5분을 버텼습니다", "boss-defeated": "우두머리를 물리쳤습니다"}.get(reason, "탐사가 끝났습니다")
	content.add_child(_label(reason_text, 19, WHITE))
	if reason == "death" and state.get("researchHints", {}).get("detailedDeath", false) and state.has("deathDetail"):
		var detail: Dictionary = state.deathDetail
		var kinds := {"circle":"원형 위험", "ray":"직선 위험", "ring":"고리 위험", "wave":"파형 위험", "projectile":"투사체", "contact":"접촉"}
		var cause: String = kinds.get(str(detail.get("kind", "")), "피격")
		var source_id := str(detail.get("sourceId", ""))
		var source := ""
		for section in ["zones", "bosses", "enemies", "elites"]:
			for item in campaign_catalog.get(section, []):
				if item.id == source_id: source = str(item.name)
		content.add_child(_label("마지막 피해: %s%s  ·  %.1f" % [(source + " · ") if source != "" else "", cause, float(detail.get("damage", 0))], 15, DIM))
	if state.has("zoneId"):
		content.add_child(_label("지역 %s  ·  직업 %s" % [_find_name(campaign_catalog.zones, str(state.zoneId)), _find_name(campaign_catalog.classes, str(state.classId))], 17, WHITE))
		if state.get("challenge", false): content.add_child(_label("시드 %d" % int(state.get("seed", 0)), 16, DIM))
		if state.get("rewardEligible", false):
			content.add_child(_label("획득 잔재 %d" % int(game.settlement.get("reward", 0)) if game.settlement.get("ok", false) else "보상 저장 실패", 17, GREEN))
		else: content.add_child(_label("보상 없음", 17, DIM))
	if state.get("researchHints", {}).get("resultConnections", false):
		var connections: Array[String] = []
		for outcome in state.get("eventOutcomes", []):
			if not outcome.get("completed", false): continue
			var selection := "수락"
			if outcome.choice == "heal": selection = "회복 선택"
			elif outcome.choice == "xp": selection = "경험치 선택"
			elif outcome.id == "E08": selection = _find_name(campaign_catalog.upgrades, str(outcome.choice)) + " 선택"
			connections.append(_find_name(campaign_catalog.events, str(outcome.id)) + " · " + selection + " · 완료")
		var label := _label("완료한 사건: " + (", ".join(connections) if not connections.is_empty() else "없음"), 15, DIM)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; content.add_child(label)
	if state.get("researchHints", {}).get("finalSummary", false):
		var actual := "우두머리 조우" if state.get("bossSpawned", false) else "우두머리 미조우"
		if state.get("bossDefeated", false): actual = "우두머리 처치"
		content.add_child(_label("%s  ·  완료 사건 %d" % [actual, state.get("completedEvents", []).size()], 15, DIM))
	var seconds := int(state.get("time", 0))
	content.add_child(_label("%02d:%02d" % [seconds / 60, seconds % 60], 38, CYAN, true))
	content.add_child(_label("처치 %d    ·    Lv.%d" % [int(state.get("kills", 0)), int(state.get("level", 1))], 17, DIM))
	_spacer(content, 20)
	var retry := _button("RETRY", true, true)
	retry.add_theme_font_size_override("font_size", 46)
	retry.custom_minimum_size.y = 62
	retry.pressed.connect(func() -> void: game.begin(game.selected_mode))
	content.add_child(retry)
	var home := _button("HOME", false, true)
	home.add_theme_font_size_override("font_size", 38)
	home.custom_minimum_size.y = 56
	home.pressed.connect(func() -> void: game.go_home())
	content.add_child(home)

func _heading(content: VBoxContainer, text_value: String) -> void:
	var heading := _label(text_value, 37, CYAN, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	_spacer(content, 12)

func _update_boss(state: Dictionary) -> void:
	boss_box.visible = false
	boss_direction.visible = false
	if not state.get("bossSpawned", false) or state.get("bossDefeated", false):
		return
	for enemy in state.get("enemies", []):
		if int(enemy.get("id", -1)) == int(state.get("bossId", -2)):
			boss_box.visible = true
			boss_bar.value = 100.0 * float(enemy.get("hp", 0)) / maxf(1.0, float(enemy.get("maxHp", 1)))
			var player: Dictionary = state.get("player", {})
			var delta := Vector2(float(enemy.get("x", 0)) - float(player.get("x", 0)), float(enemy.get("y", 0)) - float(player.get("y", 0)))
			if absf(delta.x) > root.size.x * 0.5 or absf(delta.y) > root.size.y * 0.5:
				var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
				boss_direction.text = "우두머리 " + arrows[posmod(roundi(delta.angle() / (PI / 4.0)), 8)]
				boss_direction.visible = true
			return

func _loadout_full(state: Dictionary, catalog: Dictionary) -> String:
	var lines: Array[String] = []
	for id in state.get("spells", {}):
		var level := int(state.spells[id])
		if level > 0:
			lines.append("%s  Lv.%d" % [_find_name(catalog.get("upgrades", []), str(id)), level])
	for id in state.get("fusions", []):
		lines.append(_find_name(catalog.get("fusions", []), str(id)))
	for id in state.get("artifacts", []):
		lines.append(_find_name(catalog.get("artifacts", []), str(id)))
	return "\n".join(lines) if not lines.is_empty() else "아직 획득한 마법이 없습니다"

func _find_name(items: Array, id: String) -> String:
	for item in items:
		if item.get("id", "") == id:
			return str(item.get("name", id))
	return id

func _label(value: String, font_size: int, color: Color, magic: bool = false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", MAGIC_FONT if magic else body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, primary: bool, magic: bool = false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.add_theme_font_override("font", MAGIC_FONT if magic else body_font)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", CYAN if not primary else WHITE)
	button.add_theme_stylebox_override("normal", _style("quiet"))
	button.add_theme_stylebox_override("hover", _style("quiet_hover"))
	button.add_theme_stylebox_override("pressed", _style("quiet_hover"))
	button.add_theme_stylebox_override("focus", _style("focus"))
	button.focus_mode = Control.FOCUS_ALL
	return button

func _bar(color: Color, height: int) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.max_value = 100
	bar.add_theme_stylebox_override("background", _style("bar_back"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _style(key: String) -> StyleBox:
	if style_cache.has(key):
		return style_cache[key]
	if key in ["ink_card", "ink_card_hover"]:
		var ink := StyleBoxTexture.new()
		ink.texture = _ink_texture()
		ink.texture_margin_left = 12
		ink.texture_margin_right = 12
		ink.texture_margin_top = 12
		ink.texture_margin_bottom = 12
		ink.modulate_color = Color("#1b211d") if key == "ink_card_hover" else BLACK
		style_cache[key] = ink
		return ink
	var box := StyleBoxFlat.new()
	match key:
		"selected":
			box.bg_color = Color("#101511")
			box.border_color = WHITE
			box.border_width_bottom = 1
		"quiet_hover":
			box.bg_color = Color("#121713")
		"reroll":
			box.bg_color = Color("#101511")
			box.border_color = Color("#9cb7aa")
			box.set_border_width_all(1)
		"hint_back":
			box.bg_color = Color(0.01, 0.02, 0.015, 0.82)
			box.content_margin_left = 6
			box.content_margin_right = 6
			box.content_margin_top = 2
			box.content_margin_bottom = 2
		"focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = CYAN
			box.set_border_width_all(2)
		"bar_back":
			box.bg_color = Color("#111818")
		_:
			box.bg_color = Color.TRANSPARENT
	style_cache[key] = box
	return box

func _ink_texture() -> Texture2D:
	if texture_cache.has("ink_card_background"):
		return texture_cache["ink_card_background"]
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var left := 4 + int(absf(sin(float(y) * 2.17) * 4.0 + sin(float(y) * 0.41) * 3.0))
			var right := 91 - int(absf(sin(float(y) * 1.73) * 4.0 + cos(float(y) * 0.36) * 3.0))
			var top := 4 + int(absf(cos(float(x) * 1.91) * 4.0 + sin(float(x) * 0.52) * 3.0))
			var bottom := 91 - int(absf(sin(float(x) * 2.09) * 4.0 + cos(float(x) * 0.44) * 3.0))
			image.set_pixel(x, y, Color.WHITE if x >= left and x <= right and y >= top and y <= bottom else Color.TRANSPARENT)
	var texture := ImageTexture.create_from_image(image)
	texture_cache["ink_card_background"] = texture
	return texture

func _icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not texture_cache.has(path):
		var resource_path := "res://" + path
		texture_cache[path] = FIREBALL_TEXTURE if path == "assets/generated/icon-fireball.png" else load(resource_path)
	return texture_cache[path]

func _spacer(content: VBoxContainer, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)

func _on_resized() -> void:
	if root == null:
		return
	last_size = root.size
	if forest_art != null and is_instance_valid(forest_art):
		forest_art.custom_minimum_size = _forest_size()
	_position_medallion()
	var safe := _safe_insets()
	top_box.offset_left = safe.x
	top_box.offset_right = -safe.z
	top_box.offset_top = safe.y
	top_box.offset_bottom = safe.y + 66
	if phase_box != null:
		for child in phase_box.get_children():
			if child is MarginContainer:
				_apply_safe_margin(child)
				if hub_content != null and is_instance_valid(hub_content):
					_fit_content(hub_content)
				else:
					var scroll: ScrollContainer = child.get_child(0)
					var center: CenterContainer = scroll.get_child(0)
					if center.get_child_count() > 0:
						_fit_content(center.get_child(0))

func _forest_size() -> Vector2:
	var available := maxf(1.0, root.size.x - 24.0 - _safe_insets().x - _safe_insets().z)
	return Vector2(minf(available * 0.74, 400.0), minf(available * 0.90, 440.0))

func _position_medallion() -> void:
	if medallion == null or not is_instance_valid(medallion) or medallion.is_queued_for_deletion():
		return
	var diameter := minf(80.0, root.size.x * 0.15)
	medallion.size = Vector2.ONE * diameter
	medallion.position = Vector2(root.size.x - _safe_insets().z - diameter - 44.0, _safe_insets().y + root.size.y * 0.145)

func _safe_insets() -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var physical := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if physical.x <= 0 or physical.y <= 0 or safe.size.x <= 0:
		return Vector4.ZERO
	var scale := root.size / physical
	return Vector4(safe.position.x * scale.x, safe.position.y * scale.y, maxf(0, physical.x - safe.end.x) * scale.x, maxf(0, physical.y - safe.end.y) * scale.y)

func _apply_safe_margin(margin: MarginContainer) -> void:
	var safe := _safe_insets()
	margin.add_theme_constant_override("margin_left", maxi(12, ceili(safe.x) + 12))
	margin.add_theme_constant_override("margin_top", maxi(12, ceili(safe.y) + 12))
	margin.add_theme_constant_override("margin_right", maxi(12, ceili(safe.z) + 12))
	margin.add_theme_constant_override("margin_bottom", maxi(12, ceili(safe.w) + 12))

func _fit_content(content: VBoxContainer) -> void:
	var scrollbar_allowance := 16.0 if hub_content != null and content == hub_content else 0.0
	content.custom_minimum_size.x = minf(500.0, maxf(1.0, root.size.x - 24.0 - _safe_insets().x - _safe_insets().z - scrollbar_allowance))
