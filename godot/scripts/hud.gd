extends CanvasLayer

const BODY_FONT = preload("res://assets/fonts/NotoSansKR.ttf")
const MAGIC_FONT = preload("res://assets/fonts/MagicSurvival.ttf")
const FOREST_TEXTURE = preload("res://assets/generated/zone-forest.png")
const FIREBALL_TEXTURE = preload("res://assets/generated/icon-fireball.png")
const ICON_SHADER = preload("res://shaders/mono_icon.gdshader")
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
var mode_choice := "quick"
var texture_cache: Dictionary = {}
var style_cache: Dictionary = {}
var icon_material: ShaderMaterial
var passive_icon_material: ShaderMaterial
var forest_material: ShaderMaterial
var last_size := Vector2.ZERO

func setup(owner_game: Node) -> void:
	game = owner_game
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
	var options: Array = state.get("choices", []) if phase == "upgrade" else state.get("artifactChoices", [])
	var next_choice_key := JSON.stringify(options)
	if phase_key != phase or (phase in ["upgrade", "artifact"] and choice_key != next_choice_key):
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
		"ready": _welcome(content, catalog, record)
		"paused": _pause(content, state, catalog)
		"upgrade", "artifact": _choices(content, state)
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

func _welcome(content: VBoxContainer, catalog: Dictionary, record: Dictionary) -> void:
	_spacer(content, 24)
	var zone_row := HBoxContainer.new()
	zone_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(zone_row)
	var left_zone := _label("◀", 20, Color("#596569"))
	left_zone.custom_minimum_size.x = 56
	left_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_row.add_child(left_zone)
	var zone := _label("FOREST ZONE", 48, WHITE, true)
	zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_row.add_child(zone)
	var right_zone := VBoxContainer.new()
	right_zone.custom_minimum_size.x = 56
	right_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_row.add_child(right_zone)
	var arrow := _label("▶", 20, Color("#596569"))
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_zone.add_child(arrow)
	var zone_count := _label("1 / 1", 11, DIM, true)
	zone_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_zone.add_child(zone_count)
	_spacer(content, 10)
	var art_center := CenterContainer.new()
	art_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(art_center)
	forest_art = TextureRect.new()
	forest_art.texture = FOREST_TEXTURE
	forest_art.material = forest_material
	forest_art.custom_minimum_size = Vector2(minf(maxf(root.size.x, 420.0) * 0.74, 400.0), minf(maxf(root.size.x, 420.0) * 0.90, 440.0))
	forest_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	forest_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	forest_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_center.add_child(forest_art)
	_spacer(content, 18)
	var progress := _bar(GREEN, 2)
	progress.value = 100.0 * minf(1.0, float(record.get("time", 0)) / (300.0 if mode_choice == "quick" else 600.0))
	progress.custom_minimum_size.y = 2
	content.add_child(progress)
	var best := int(record.get("time", 0))
	var best_text := "BEST TIME  --:--" if best <= 0 else "BEST TIME  %02d:%02d" % [best / 60, best % 60]
	var best_label := _label(best_text, 27, GREEN, true)
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(best_label)
	_spacer(content, 4)
	var modes: Dictionary = catalog.get("modes", {})
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	content.add_child(mode_row)
	for id in ["quick", "expedition"]:
		var mode: Dictionary = modes.get(id, {})
		var text_value := "%s  %s" % [str(mode.get("label", id)), "5 MIN" if id == "quick" else "10 MIN"]
		var button := _button(text_value, false)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", WHITE if mode_choice == id else DIM)
		button.add_theme_stylebox_override("normal", _style("selected" if mode_choice == id else "quiet"))
		button.pressed.connect(_select_mode.bind(id))
		mode_row.add_child(button)
	_spacer(content, 46)
	var start := _button("PLAY", true, true)
	start.add_theme_font_size_override("font_size", 50)
	start.pressed.connect(func() -> void: game.begin(mode_choice))
	content.add_child(start)

func _select_mode(id: String) -> void:
	mode_choice = id
	game.selected_mode = id
	_build_phase(game.sim.state, game.sim.catalog, game.records.for_mode(id), game.record_error)

func _pause(content: VBoxContainer, state: Dictionary, catalog: Dictionary) -> void:
	_heading(content, "PAUSED")
	var seconds := int(state.get("time", 0))
	content.add_child(_label("%02d:%02d   ·   Lv.%d   ·   처치 %d" % [seconds / 60, seconds % 60, int(state.get("level", 1)), int(state.get("kills", 0))], 16, WHITE))
	var resume := _button("RESUME", true, true)
	resume.add_theme_font_size_override("font_size", 46)
	resume.custom_minimum_size.y = 62
	resume.pressed.connect(func() -> void: game.pause_run())
	content.add_child(resume)
	_spacer(content, 12)
	content.add_child(_label("GRIMOIRE", 23, CYAN, true))
	var loadout := _label(_loadout_full(state, catalog), 17, WHITE)
	loadout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(loadout)
	_spacer(content, 9)
	content.add_child(_label("FUSIONS", 23, CYAN, true))
	for fusion in catalog.get("fusions", []):
		var requires: Dictionary = fusion.get("requires", {})
		var names: Array[String] = []
		for key in requires:
			names.append(_find_name(catalog.get("upgrades", []), str(key)) + " Lv.%d" % int(requires[key]))
		content.add_child(_label("%s  ·  %s" % [fusion.get("name", ""), " + ".join(names)], 14, DIM))
	_spacer(content, 10)
	var home := _button("HOME", false, true)
	home.add_theme_font_size_override("font_size", 38)
	home.custom_minimum_size.y = 56
	home.pressed.connect(func() -> void: game.go_home())
	content.add_child(home)
	content.add_child(_label("Godot Engine · MIT  |  Noto Sans KR · SIL Open Font License", 11, DIM))

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
	for option in options:
		var id: String = option.get("id", "")
		var card := Button.new()
		card.custom_minimum_size.y = 151
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
		var icon_path := str(option.get("icon", ""))
		if id == "fireball":
			icon_path = "assets/generated/icon-fireball.png"
		icon.texture = _icon(icon_path)
		icon.material = icon_material
		icon.custom_minimum_size = Vector2(104, 104)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
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
		var spells: Dictionary = state.get("spells", {})
		var stats: Dictionary = state.get("stats", {})
		var is_fusion: bool = option.get("kind", "") == "fusion"
		var is_passive: bool = stats.has(id)
		var level := int(spells.get(id, stats.get(id, 0))) + 1
		var level_text := "FUSION" if is_fusion else "Lv %d" % level if not artifact else "ARTIFACT"
		var level_label := _label(level_text, 34, YELLOW, true)
		level_label.custom_minimum_size.x = 74
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(level_label)
		if is_passive:
			icon.material = passive_icon_material
	_spacer(content, 140)

func _result(content: VBoxContainer, state: Dictionary) -> void:
	_heading(content, "SURVIVED" if state.get("phase") == "won" else "GAME OVER")
	var reason: String = str(state.get("endReason", ""))
	var reason_text: String = {"death": "생명력이 다했습니다", "timeout": "제한 시간이 끝났습니다", "survived": "5분을 버텼습니다", "boss-defeated": "우두머리를 물리쳤습니다"}.get(reason, "탐사가 끝났습니다")
	content.add_child(_label(reason_text, 19, WHITE))
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
		forest_art.custom_minimum_size = Vector2(minf(maxf(root.size.x, 420.0) * 0.74, 400.0), minf(maxf(root.size.x, 420.0) * 0.90, 440.0))
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
				var scroll: ScrollContainer = child.get_child(0)
				var center: CenterContainer = scroll.get_child(0)
				if center.get_child_count() > 0:
					_fit_content(center.get_child(0))

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
	content.custom_minimum_size.x = minf(500.0, maxf(280.0, root.size.x - 24.0 - _safe_insets().x - _safe_insets().z))
