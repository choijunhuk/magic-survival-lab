extends CanvasLayer

const FONT = preload("res://assets/fonts/NotoSansKR.ttf")
var body_font: FontVariation
var title_font: FontVariation
const INK = Color("#0b1016")
const PANEL = Color("#111b25")
const SILVER = Color("#e2e8e5")
const MUTED = Color("#a8b9bd")
const TEAL = Color("#80d4d1")
const GOLD = Color("#d9b66f")
const RED = Color("#d7979c")

var game: Node
var root: Control
var phase_box: Control
var top_box: PanelContainer
var play_box: VBoxContainer
var hp_label: Label
var time_label: Label
var kills_label: Label
var xp_label: Label
var xp_bar: ProgressBar
var hp_bar: ProgressBar
var loadout_label: Label
var boss_box: VBoxContainer
var boss_label: Label
var boss_bar: ProgressBar
var phase_key := ""
var choice_key := ""
var loadout_key := ""
var mode_choice := "quick"
var texture_cache: Dictionary = {}
var style_cache: Dictionary = {}
var last_size := Vector2.ZERO

func setup(owner_game: Node) -> void:
	game = owner_game
	body_font = FontVariation.new()
	body_font.base_font = FONT
	body_font.variation_opentype = {"wght": 400}
	body_font.variation_embolden = 0.15
	title_font = FontVariation.new()
	title_font.base_font = FONT
	title_font.variation_opentype = {"wght": 700}
	title_font.variation_embolden = 0.8
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
	var options: Array = state.get("choices", []) if phase == "upgrade" else state.get("artifactChoices", [])
	var new_choice_key := JSON.stringify(options)
	if phase_key != phase or (phase in ["upgrade", "artifact"] and choice_key != new_choice_key):
		phase_key = phase
		choice_key = new_choice_key
		_build_phase(state, catalog, record, error)
	play_box.visible = phase != "ready"
	if phase != "ready":
		var player: Dictionary = state.get("player", {})
		var hp := float(player.get("hp", 0))
		var max_hp := maxf(1, float(player.get("maxHp", 1)))
		hp_label.text = "생명력  %d / %d" % [ceili(hp), ceili(max_hp)]
		hp_bar.value = 100.0 * hp / max_hp
		var seconds := int(state.get("time", 0))
		time_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
		kills_label.text = "처치  %d" % int(state.get("kills", 0))
		xp_label.text = "Lv. %d     %d / %d" % [int(state.get("level", 1)), int(state.get("xp", 0)), int(state.get("xpNeeded", 6))]
		xp_bar.value = 100.0 * float(state.get("xp", 0)) / maxf(1, float(state.get("xpNeeded", 1)))
		var current_loadout := JSON.stringify([state.get("spells", {}), state.get("fusions", []), state.get("artifacts", [])])
		if current_loadout != loadout_key:
			loadout_key = current_loadout
			loadout_label.text = _loadout_short(state, catalog)
		_update_boss(state)
	if last_size != root.size:
		_on_resized()

func _build_play_hud() -> void:
	top_box = PanelContainer.new()
	top_box.add_theme_stylebox_override("panel", _style("panel"))
	top_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_box.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top_box)
	play_box = VBoxContainer.new()
	play_box.add_theme_constant_override("separation", 9)
	top_box.add_child(play_box)
	var row := HBoxContainer.new()
	play_box.add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	hp_label = _label("", 16, MUTED)
	left.add_child(hp_label)
	hp_bar = _bar(RED)
	left.add_child(hp_bar)
	time_label = _label("00:00", 24, SILVER)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(time_label)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	kills_label = _label("", 16, MUTED)
	kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(kills_label)
	var pause := _button("Ⅱ  일시정지", false)
	pause.pressed.connect(func() -> void: game.pause_run())
	right.add_child(pause)
	boss_box = VBoxContainer.new()
	boss_label = _label("", 17, GOLD)
	boss_box.add_child(boss_label)
	boss_bar = _bar(GOLD)
	boss_box.add_child(boss_bar)
	play_box.add_child(boss_box)
	boss_box.visible = false
	loadout_label = _label("", 15, MUTED)
	loadout_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	play_box.add_child(loadout_label)
	var xp_row := HBoxContainer.new()
	play_box.add_child(xp_row)
	xp_label = _label("", 15, GOLD)
	xp_row.add_child(xp_label)
	xp_bar = _bar(TEAL)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_row.add_child(xp_bar)

func _build_phase(state: Dictionary, catalog: Dictionary, record: Dictionary, error: String) -> void:
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
	var shade := ColorRect.new()
	shade.color = Color(.035, .06, .09, .93 if phase == "ready" else .88)
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
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 0
	panel.add_theme_stylebox_override("panel", _style("overlay"))
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	match phase:
		"ready": _welcome(content, state, catalog, record)
		"paused": _pause(content, state, catalog)
		"upgrade", "artifact": _choices(content, state, catalog)
		"won", "lost": _result(content, state)
	if error != "":
		var message := _label("기록 저장에 실패했습니다: " + error, 15, RED)
		message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(message)
	_apply_safe_margin(margin)
	_fit_panel(panel)

func _welcome(content: VBoxContainer, state: Dictionary, catalog: Dictionary, record: Dictionary) -> void:
	content.add_child(_label("◇  황혼의 폐허", 17, GOLD))
	var title := _label("마력이\n다할 때까지.", 38, SILVER)
	content.add_child(title)
	var intro := _label("몰려오는 어둠을 밀어내고\n당신만의 마법을 완성하세요.", 19, MUTED)
	content.add_child(intro)
	content.add_child(_label("탐사 방식", 16, GOLD))
	var modes: Dictionary = catalog.get("modes", {})
	for id in ["quick", "expedition"]:
		var mode: Dictionary = modes.get(id, {})
		var name: String = mode.get("label", "퀵 모드" if id == "quick" else "균열 원정")
		var detail := "5분 생존" if id == "quick" else "10분 안에 우두머리 처치"
		var button := _button(("선택 · " if mode_choice == id else "") + name + "\n" + detail, false)
		if mode_choice == id:
			button.add_theme_stylebox_override("normal", _style("selected"))
			button.add_theme_stylebox_override("hover", _style("selected_hover"))
			button.add_theme_stylebox_override("pressed", _style("selected_hover"))
			button.add_theme_color_override("font_color", GOLD)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_mode.bind(id))
		content.add_child(button)
	var best := float(record.get("time", 0))
	if best <= 0:
		content.add_child(_label("최고 기록 · 아직 기록이 없습니다", 16, SILVER))
	else:
		content.add_child(_label("최고 기록 · %02d:%02d" % [int(best) / 60, int(best) % 60], 16, SILVER))
	var start := _button("생존 시작     ↗", true)
	start.pressed.connect(func() -> void: game.begin(mode_choice))
	content.add_child(start)
	content.add_child(_label("화면 왼쪽 아래 드래그 또는 방향키로 이동\n공격은 자동으로 발동합니다", 15, Color("#c3d0d1")))

func _select_mode(id: String) -> void:
	mode_choice = id
	game.selected_mode = id
	refresh(game.sim.state, game.sim.catalog, game.records.for_mode(id), game.record_error)
	_build_phase(game.sim.state, game.sim.catalog, game.records.for_mode(id), game.record_error)

func _pause(content: VBoxContainer, state: Dictionary, catalog: Dictionary) -> void:
	content.add_child(_label("일시정지", 32, SILVER))
	content.add_child(_label("숨을 고르고 마법을 살펴보세요.", 17, MUTED))
	var resume := _button("계속하기", true)
	resume.pressed.connect(func() -> void: game.pause_run())
	content.add_child(resume)
	content.add_child(_label("마도서", 20, GOLD))
	content.add_child(_label(_loadout_full(state, catalog), 17, SILVER))
	content.add_child(_label("조합식", 20, GOLD))
	for fusion in catalog.get("fusions", []):
		var requires: Dictionary = fusion.get("requires", {})
		var names: Array[String] = []
		for key in requires:
			names.append(_find_name(catalog.get("upgrades", []), str(key)) + " Lv.%d" % int(requires[key]))
		content.add_child(_label("◇ %s · %s" % [fusion.get("name", ""), " + ".join(names)], 16, MUTED))
	var home := _button("처음으로", false)
	home.pressed.connect(func() -> void: game.go_home())
	content.add_child(home)
	content.add_child(_label("Godot Engine · MIT  |  Noto Sans KR · SIL Open Font License", 12, MUTED))

func _choices(content: VBoxContainer, state: Dictionary, catalog: Dictionary) -> void:
	var artifact: bool = state.get("phase") == "artifact"
	content.add_child(_label("유물 선택" if artifact else "마법 강화", 30, GOLD))
	content.add_child(_label("하나를 선택하면 탐사가 계속됩니다.", 16, MUTED))
	var options: Array = state.get("artifactChoices", []) if artifact else state.get("choices", [])
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var id: String = option.get("id", "")
		var card := Button.new()
		card.custom_minimum_size.y = 82
		card.focus_mode = Control.FOCUS_ALL
		card.add_theme_stylebox_override("normal", _style("card"))
		card.add_theme_stylebox_override("hover", _style("card_hover"))
		card.add_theme_stylebox_override("focus", _style("focus"))
		card.add_theme_stylebox_override("pressed", _style("card_hover"))
		card.pressed.connect(func() -> void: game.choose(id))
		content.add_child(card)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var texture := _icon(str(option.get("icon", "")))
		if texture != null:
			var image := TextureRect.new()
			image.texture = texture
			image.custom_minimum_size = Vector2(52, 52)
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(image)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(column)
		column.add_child(_label("%d  %s" % [i + 1, option.get("name", id)], 18, GOLD))
		var desc := _label(str(option.get("description", "")), 15, SILVER)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(desc)

func _result(content: VBoxContainer, state: Dictionary) -> void:
	var won: bool = state.get("phase") == "won"
	content.add_child(_label("탐사 성공" if won else "탐사 종료", 34, GOLD if won else RED))
	var reason: String = str(state.get("endReason", ""))
	var reason_text: String = {"death": "생명력이 다했습니다", "timeout": "제한 시간이 끝났습니다", "survived": "5분을 버텼습니다", "boss-defeated": "우두머리를 물리쳤습니다"}.get(reason, "탐사가 끝났습니다")
	content.add_child(_label(reason_text, 20, SILVER))
	var seconds := int(state.get("time", 0))
	content.add_child(_label("%02d:%02d" % [seconds / 60, seconds % 60], 36, SILVER))
	content.add_child(_label("처치 %d    ·    Lv. %d" % [int(state.get("kills", 0)), int(state.get("level", 1))], 18, MUTED))
	var retry := _button("다시 탐사", true)
	retry.pressed.connect(func() -> void: game.begin(game.selected_mode))
	content.add_child(retry)
	var home := _button("처음으로", false)
	home.pressed.connect(func() -> void: game.go_home())
	content.add_child(home)

func _update_boss(state: Dictionary) -> void:
	boss_box.visible = false
	if not state.get("bossSpawned", false) or state.get("bossDefeated", false):
		return
	for enemy in state.get("enemies", []):
		if int(enemy.get("id", -1)) == int(state.get("bossId", -2)):
			boss_box.visible = true
			var player: Dictionary = state.get("player", {})
			var direction := Vector2(float(enemy.get("x", 0)) - float(player.get("x", 0)), float(enemy.get("y", 0)) - float(player.get("y", 0)))
			var arrow := "↑" if absf(direction.y) > absf(direction.x) and direction.y < 0 else "↓" if absf(direction.y) > absf(direction.x) else "←" if direction.x < 0 else "→"
			boss_label.text = "우두머리  %s" % arrow
			boss_bar.value = 100.0 * float(enemy.get("hp", 0)) / maxf(1, float(enemy.get("maxHp", 1)))
			return

func _loadout_short(state: Dictionary, catalog: Dictionary) -> String:
	var bits: Array[String] = []
	for id in state.get("spells", {}):
		var level := int(state.spells[id])
		if level > 0:
			bits.append("%s %d" % [_find_name(catalog.get("upgrades", []), str(id)), level])
	for id in state.get("fusions", []):
		bits.append(_find_name(catalog.get("fusions", []), str(id)))
	return "  ·  ".join(bits)

func _loadout_full(state: Dictionary, catalog: Dictionary) -> String:
	var lines: Array[String] = []
	for id in state.get("spells", {}):
		var level := int(state.spells[id])
		if level > 0:
			lines.append("• %s  Lv.%d" % [_find_name(catalog.get("upgrades", []), str(id)), level])
	for id in state.get("fusions", []):
		lines.append("◇ " + _find_name(catalog.get("fusions", []), str(id)))
	for id in state.get("artifacts", []):
		lines.append("◇ " + _find_name(catalog.get("artifacts", []), str(id)))
	return "\n".join(lines)

func _find_name(items: Array, id: String) -> String:
	for item in items:
		if item.get("id", "") == id:
			return str(item.get("name", id))
	return id

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", title_font if font_size >= 24 else body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 54
	button.add_theme_font_override("font", body_font)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", INK if primary else SILVER)
	button.add_theme_stylebox_override("normal", _style("gold" if primary else "card"))
	button.add_theme_stylebox_override("hover", _style("gold_hover" if primary else "card_hover"))
	button.add_theme_stylebox_override("pressed", _style("gold_hover" if primary else "card_hover"))
	button.add_theme_stylebox_override("focus", _style("focus"))
	button.focus_mode = Control.FOCUS_ALL
	return button

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 5
	bar.show_percentage = false
	bar.max_value = 100
	bar.add_theme_stylebox_override("background", _style("bar_back"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _style(key: String) -> StyleBoxFlat:
	if style_cache.has(key):
		return style_cache[key]
	var box := StyleBoxFlat.new()
	match key:
		"panel":
			box.bg_color = Color("#111b25")
			box.content_margin_left = 16; box.content_margin_right = 16
			box.content_margin_top = 10; box.content_margin_bottom = 10
			box.border_color = Color("#34424b")
			box.set_border_width_all(1)
		"overlay":
			box.bg_color = PANEL
			box.content_margin_left = 22; box.content_margin_right = 22
			box.content_margin_top = 22; box.content_margin_bottom = 22
			box.border_color = Color("#3b4b50")
			box.set_border_width_all(1)
		"selected", "selected_hover":
			box.bg_color = Color("#202b2e") if key == "selected_hover" else Color("#18242a")
			box.content_margin_left = 12; box.content_margin_right = 12
			box.content_margin_top = 10; box.content_margin_bottom = 10
			box.border_color = GOLD
			box.set_border_width_all(2)
		"card", "card_hover":
			box.bg_color = Color("#24333d") if key == "card_hover" else Color("#182630")
			box.content_margin_left = 12; box.content_margin_right = 12
			box.content_margin_top = 10; box.content_margin_bottom = 10
			box.border_color = TEAL if key == "card_hover" else Color("#45606b")
			box.set_border_width_all(1)
		"gold", "gold_hover":
			box.bg_color = Color("#e9ca84") if key == "gold_hover" else GOLD
			box.content_margin_left = 12; box.content_margin_right = 12
			box.content_margin_top = 8; box.content_margin_bottom = 8
		"focus":
			box.bg_color = Color.TRANSPARENT
			box.border_color = TEAL
			box.set_border_width_all(2)
		"bar_back":
			box.bg_color = Color("#34434a")
	style_cache[key] = box
	return box

func _icon(path: String) -> Texture2D:
	if path == "":
		return null
	if not texture_cache.has(path):
		texture_cache[path] = load("res://" + path)
	return texture_cache[path]

func _on_resized() -> void:
	if root == null:
		return
	last_size = root.size
	var safe := _safe_insets()
	top_box.offset_left = safe.x
	top_box.offset_right = -safe.z
	top_box.offset_top = safe.y
	if phase_box != null:
		for child in phase_box.get_children():
			if child is MarginContainer:
				_apply_safe_margin(child)
				var scroll: ScrollContainer = child.get_child(0)
				var center: CenterContainer = scroll.get_child(0)
				if center.get_child_count() > 0:
					_fit_panel(center.get_child(0))

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

func _fit_panel(panel: PanelContainer) -> void:
	panel.custom_minimum_size.x = minf(460.0, maxf(280.0, root.size.x - 28.0 - _safe_insets().x - _safe_insets().z))
