extends SceneTree

var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and needle in node.text: return true
	for child in node.get_children():
		if contains_text(child, needle): return true
	return false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene)
	var path := "user://test-campaign-ui-%d.json" % Time.get_ticks_usec()
	scene.profile = load("res://scripts/progression.gd").new(path, scene.hud.campaign_catalog)
	check(scene.profile.load_profile(), "isolated profile loads")
	check(scene.hud.release_icons.size() == 132, "all new choice icons are mapped")
	for section in ["upgrades", "fusions", "artifacts"]:
		for item in scene.hud.campaign_catalog[section]:
			if not item.get("icon", ""):
				var asset: String = str(scene.hud.release_icons.get(item.id, ""))
				check(asset != "" and ResourceLoader.exists("res://" + asset), "mapped choice icon loads: " + str(item.id))
	for index in range(6):
		if index > 0:
			for kind in ["ground", "preview"]:
				var asset := "res://assets/generated/release-maps/z%02d-%s.png" % [index + 1, kind]
				check(ResourceLoader.exists(asset) and load(asset) is Texture2D, "required zone image loads: " + asset)
		scene.hud.zone_index = index
		scene.hud._change_zone(1)
		check(scene.selected_zone == "Z%02d" % ((index + 1) % 6 + 1), "zone arrow selects each zone")
		if scene.selected_zone != "Z01":
			check(scene.hud.forest_art.texture.resource_path.ends_with("%s-preview.png" % scene.selected_zone.to_lower()), "zone menu shows its own preview")
	for item in scene.hud.campaign_catalog.classes:
		scene.hud._select_class(item.id)
		check(scene.selected_class == item.id, "each class selectable")
	scene.hud._research_action("R01")
	check(not scene.profile.data.purchased.has("R01") and scene.hud.hub_error != "", "insufficient funds shown")
	scene.profile.data.wallet = 100
	scene.hud._research_action("R01")
	check(scene.profile.data.purchased.has("R01") and scene.profile.data.wallet == 90, "purchase deducts actual research price")
	scene.hud._research_action("R01")
	check(scene.profile.data.equipped.has("R01"), "purchased research can be equipped")
	scene.hud.mode_choice = "campaign"
	check("15분" in scene.hud._mode_summary() and "13분 30초" in scene.hud._mode_summary() and "처치 시 승리" in scene.hud._mode_summary() and scene.hud._find_name(scene.hud.campaign_catalog.classes, scene.selected_class) in scene.hud._mode_summary(), "campaign start summary contains actual timing and class")
	var map_content := VBoxContainer.new()
	scene.hud._hub_map(map_content, {})
	var zone_row: HBoxContainer = map_content.get_child(0)
	for index in [0, 2]:
		var arrow: Button = zone_row.get_child(index)
		var primary_font: Font = arrow.get_theme_font("font")
		check(primary_font is FontVariation and primary_font.base_font == scene.hud.BODY_FONT and primary_font.base_font.has_char(arrow.text.unicode_at(0)), "zone arrow uses bundled primary font containing its glyph: " + arrow.text)
	for character in "0123456789:. -":
		check(scene.hud.MAGIC_FONT.has_char(character.unicode_at(0)), "magic font includes used numeric/punctuation glyph: " + character)
	check(contains_text(map_content, "75초부터") and not contains_text(map_content, "장식 잔해"), "map describes actual phenomenon")
	map_content.free()
	for index in range(6):
		scene.hud.zone_index = index
		var zone_content := VBoxContainer.new()
		scene.hud._hub_map(zone_content, {})
		var actual_text: String = str(scene.hud.campaign_catalog.zones[index].phenomenon).split(". ", false, 1)[0]
		check(contains_text(zone_content, actual_text), "zone description uses catalog phenomenon")
		zone_content.free()
	scene.hud.zone_index = 0
	scene.hud.mode_choice = "quick"
	check("5분" in scene.hud._mode_summary() and "기본 전장/마나 창" in scene.hud._mode_summary(), "quick summary reflects legacy rules")
	var quick_map := VBoxContainer.new()
	scene.hud._hub_map(quick_map, {})
	check(contains_text(quick_map, "현상은 이 모드에 적용되지 않습니다"), "legacy menu does not imply campaign zone effects")
	quick_map.free()
	scene.hud.mode_choice = "expedition"
	check("10분" in scene.hud._mode_summary() and "8분 30초" in scene.hud._mode_summary(), "expedition summary reflects legacy boss timing")
	scene.hud.mode_choice = "campaign"
	scene.begin("campaign")
	check(scene.sim.state.mode == "campaign" and scene.sim.state.zoneId == scene.selected_zone and scene.sim.state.classId == scene.selected_class, "campaign selection reaches simulation")
	check(not scene.profile.set_equipped([]) and scene.profile.data.equipped.has("R01"), "research locked while running")
	var state: Dictionary = scene.sim.state
	var stealth: Dictionary = scene.sim.Encounters.enemy(scene.sim, 23, 0, Vector2(-80, -100))
	check(scene._enemy_visibility(stealth) == 1.0, "N23 is visible before stealth")
	stealth.specialTimer = 0.0
	scene.sim.Encounters.advance_enemies(scene.sim, 0.01)
	check(float(stealth.hidden) > 0 and is_equal_approx(scene._enemy_visibility(stealth), 0.06), "actual N23 stealth state fades its rendered body and shadow")
	var has_reappear_warning := false
	for effect in state.effects:
		if effect.get("type", "") == "reappear_warning" and float(effect.get("life", 0)) > 0: has_reappear_warning = true
	check(has_reappear_warning, "actual stealth activation retains its reappearance warning effect")
	for effect in state.effects:
		if effect.get("type", "") == "reappear_warning":
			var reappear_geometry: Dictionary = scene._warning_geometry(effect)
			check(reappear_geometry.origin == stealth.reappearAt and reappear_geometry.radius == 25.0, "reappearance warning uses actual future position and radius")
	check(scene._enemy_visibility({"kind": "elite", "hidden": 1.0}) == 0.06, "hidden elite uses the same visibility")
	check(scene._enemy_visibility({"kind": "boss", "hidden": 1.0}) == 1.0, "boss visibility remains unchanged")
	stealth.hidden = 0.0
	check(scene._enemy_visibility(stealth) == 1.0, "enemy returns to normal opacity after stealth")
	state.enemies.clear()
	state.effects.clear()
	var dasher: Dictionary = scene.sim.Encounters.enemy(scene.sim, 3, 0, Vector2(-140, -100))
	dasher.specialTimer = 0.0
	scene.sim.Encounters.advance_enemies(scene.sim, 0.01)
	var dash_effect: Dictionary = state.effects.back()
	var dash_geometry: Dictionary = scene._warning_geometry(dash_effect)
	check(dash_geometry.kind == "enemy_dash_warning" and dash_geometry.origin == Vector2(dash_effect.x, dash_effect.y) and dash_geometry.end == Vector2(dash_effect.toX, dash_effect.toY) and dash_geometry.radius == 18.0, "dash warning uses emitted world endpoints and width")
	var incomplete_dash: Dictionary = scene._warning_geometry({"type": "enemy_dash_warning", "x": 3.0, "y": 4.0, "radius": 18.0})
	check(not incomplete_dash.has("end"), "dash warning does not invent an absent direction")
	state.enemies.clear(); state.effects.clear()
	var caster: Dictionary = scene.sim.Encounters.enemy(scene.sim, 7, 0, Vector2(140, -80))
	caster.castTimer = 0.0
	scene.sim.Encounters.advance_enemies(scene.sim, 0.01)
	var cast_effect: Dictionary = state.effects.back()
	var cast_geometry: Dictionary = scene._warning_geometry(cast_effect)
	check(cast_geometry.kind == "enemy_cast_warning" and cast_geometry.origin == caster.castTarget and cast_geometry.radius == 30.0 and not cast_geometry.has("end"), "cast reticle uses locked actual target without invented direction")
	state.enemies.clear(); state.effects.clear()
	scene.sim.schedule_artifact_effect(0.8, "damage_radius", {"position": Vector2(110, -110), "radius": 50.0})
	var artifact_geometry: Dictionary = scene._warning_geometry(state.effects.back())
	check(artifact_geometry.kind == "artifact_warning" and artifact_geometry.origin == Vector2(110, -110) and artifact_geometry.radius == 50.0, "artifact warning uses scheduled effect position and radius")
	state.effects.clear(); state.pendingEffects.clear()
	var initial_boss_kind: String = state.bossKind
	var expected_sizes := [Vector2(63, 70), Vector2(70, 70), Vector2(92, 52), Vector2(60, 82), Vector2(70, 80), Vector2(62, 90)]
	var seen_boss_paths := []
	for i in range(6):
		state.bossKind = "B%02d" % (i + 1)
		state.bossId = 500
		var path_value: String = scene._boss_sprite_path()
		check(ResourceLoader.exists(path_value) and not seen_boss_paths.has(path_value), "each boss uses a distinct required texture: " + state.bossKind)
		check(scene._boss_size() == expected_sizes[i], "boss aspect matches its intended silhouette: " + state.bossKind)
		state.bossId = 700
		check(scene._boss_sprite_path() == path_value, "runtime enemy id cannot change boss art")
		seen_boss_paths.append(path_value)
	state.bossKind = initial_boss_kind
	state.bossId = null
	var veil_enemy := {"x": 10.0, "y": 0.0}
	scene.sim.Combat.field(scene.sim, "veil", Vector2.ZERO, 80.0, 10.0, {"sourceId": "m21"})
	scene._presentation = scene.sim.presentation_modifiers()
	check(not scene._should_outline_enemy(veil_enemy), "veil outline absent without A041")
	state.artifacts.append("a041")
	scene._presentation = scene.sim.presentation_modifiers()
	check(scene._presentation.veilOutline and scene._should_outline_enemy(veil_enemy), "A041 outlines enemy inside actual veil")
	check(not scene._should_outline_enemy({"x": 200.0, "y": 0.0}), "A041 does not outline enemy outside veil")
	state.artifacts.erase("a041")
	state.fields.clear()
	var zero_choices := VBoxContainer.new()
	var choice_fixture := {"phase": "upgrade", "level": 1, "choices": [scene.hud.campaign_catalog.upgrades[0]], "upgradeRerolls": 0, "artifacts": []}
	scene.hud._choices(zero_choices, choice_fixture)
	check(not contains_text(zero_choices, "재추첨"), "zero rerolls are hidden")
	zero_choices.free()
	var charged_choices := VBoxContainer.new()
	choice_fixture.upgradeRerolls = 1
	scene.hud._choices(charged_choices, choice_fixture)
	check(contains_text(charged_choices, "재추첨 1회") and contains_text(charged_choices, "1"), "available reroll is offered with its remaining count")
	charged_choices.free()
	var special_choices := VBoxContainer.new()
	choice_fixture.upgradeRerolls = 0
	choice_fixture.artifacts = ["a072"]
	choice_fixture.artifactRuntime = {"a072Used": false}
	scene.hud._choices(special_choices, choice_fixture)
	check(contains_text(special_choices, "후보 모두 재추첨"), "unused A072 action remains available")
	special_choices.free()
	var used_choices := VBoxContainer.new()
	choice_fixture.artifactRuntime.a072Used = true
	scene.hud._choices(used_choices, choice_fixture)
	check(not contains_text(used_choices, "재추첨"), "used A072 action is hidden")
	used_choices.free()
	var artifact_choices := VBoxContainer.new()
	var artifact_fixture := {"phase": "artifact", "level": 1, "artifactChoices": [scene.hud.campaign_catalog.artifacts[0]], "artifactRerolls": 1}
	scene.hud._choices(artifact_choices, artifact_fixture)
	check(contains_text(artifact_choices, "재추첨 1회"), "artifact reroll uses the compact count control")
	artifact_choices.free()
	state.phase = "upgrade"
	state.choices = [scene.hud.campaign_catalog.upgrades[0]]
	state.upgradeRerolls = 1
	scene._refresh_hud()
	check(contains_text(scene.hud.phase_box, "재추첨 1회"), "available reroll is visible in active phase")
	state.upgradeRerolls = 0
	scene._refresh_hud()
	check(not contains_text(scene.hud.phase_box, "재추첨"), "consumed reroll immediately disappears even when choices do not change")
	state.phase = "playing"
	state.choices = []
	state.phase = "event"
	state.activeEvent = {"id": "E01", "name": "샘", "marker": {"status": "opened"}}
	state.eventChoices = [{"id": "xp", "name": "XP"}, {"id": "decline", "name": "거절"}]
	var old_xp: float = state.xp
	scene.hud._event_action("xp")
	check(state.phase == "playing" and state.xp > old_xp, "event choice grants actual effect")
	state.phase = "event"
	state.activeEvent = {"id": "E01", "name": "샘", "marker": {"status": "opened"}}
	state.eventChoices = [{"id": "decline", "name": "거절"}]
	scene.hud._event_decline()
	check(state.phase == "playing" and state.activeEvent.is_empty(), "event decline closes encounter")
	state.research.append("R15")
	state.phase = "event"
	state.activeEvent = {"id": "E10", "name": "관측", "condition": "XP 20% 지불", "marker": {"status": "opened"}}
	state.xp = state.xpNeeded
	state.eventChoices = [{"id": "accept", "name": "수락"}, {"id": "decline", "name": "거절"}]
	var before_confirm: float = state.xp
	scene.hud._event_action("accept")
	check(state.phase == "event" and state.eventConfirm and state.xp == before_confirm and state.activeEvent.condition == "XP 20% 지불", "R15 requires separate confirmation while retaining cost")
	scene.hud._event_action("confirm")
	check(state.phase == "playing" and state.xp < before_confirm, "confirmed event pays its actual cost")
	state.phase = "lost"; state.time = 300.0; state.endReason = "death"
	var payout: Dictionary = scene.profile.complete_run(state)
	check(payout.ok and payout.credited and payout.reward > 0, "campaign result credits actual reward")
	var wallet: int = scene.profile.data.wallet
	var duplicate: Dictionary = scene.profile.complete_run(state)
	check(duplicate.ok and not duplicate.credited and scene.profile.data.wallet == wallet, "campaign result cannot pay twice")
	state.researchHints.resultConnections = true
	state.researchHints.finalSummary = true
	var details := VBoxContainer.new()
	scene.hud._result(details, state)
	check(contains_text(details, "깨진 마나 샘") and contains_text(details, "경험치 선택"), "result connection uses the completed actual choice")
	check(contains_text(details, "관측 장치") == false, "unrelated outcome is not invented")
	check(contains_text(details, "우두머리 미조우"), "result summary reflects actual boss state")
	details.free()
	state.researchHints.detailedDeath = true
	state.deathDetail = {"kind": "ray", "damage": 2.0, "sourceId": "N01"}
	var death_details := VBoxContainer.new()
	scene.hud._result(death_details, state)
	check(contains_text(death_details, "직선 위험") and contains_text(death_details, "부스러기"), "detailed death uses actual recorded source and damage kind")
	death_details.free()
	var frequency: Dictionary = scene.sim.upgrade_frequency("bolt")
	var rendered: String = scene.hud._frequency_text(frequency, scene.sim.catalog)
	check(("%.1f초" % float(frequency.nextInterval)) in rendered, "frequency display uses core cooldown API")
	scene.hud._update_research_hint({"time": 100.0, "zoneId": "Z06", "researchHints": {"phenomenonMeter": true}})
	check("80.0" in scene.hud.hint_label.text and scene.hud.hint_label.visible, "phenomenon meter uses selected zone schedule")
	scene.hud._update_research_hint({"time": 100.0, "zoneId": "Z06", "researchHints": {}})
	check(not scene.hud.hint_label.visible, "empty forecast has no visible background")
	scene.go_home()
	check(scene.profile.set_equipped([]), "research unlocked at home")
	scene.begin("campaign")
	state = scene.sim.state
	state.phase = "event"
	state.activeEvent = {"id": "E12", "name": "실습", "marker": {"status": "opened"}}
	state.eventChoices = [{"id": "accept", "name": "수락"}]
	scene.hud._event_action("accept")
	check(state.phase == "event_practice" and not state.practiceHazards.is_empty(), "practice opens real warning")
	scene.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	var before: float = state.eventPracticeTime
	scene._process(0.05)
	check(scene.practice_suspended and state.eventPracticeTime == before, "background freezes practice")
	scene.hud._resume_practice()
	scene._process(0.05)
	check(not scene.practice_suspended and state.eventPracticeTime < before, "practice resumes only after user action")
	var answer: String = state.practiceHazards[0].shape
	scene.hud._practice_answer(answer)
	check(state.practiceCorrect == 1, "practice answer is checked against actual warning")
	scene.go_home()
	for legacy_mode in ["quick", "expedition"]:
		scene.begin(legacy_mode)
		check(scene._boss_sprite_path() == scene.BOSS_SPRITE, "legacy mode retains original boss art")
		check(not scene.profile.purchase_research("R02"), "research purchase blocked during " + legacy_mode)
		check(not scene.profile.set_equipped(["R01"]), "research equipment blocked during " + legacy_mode)
		scene.go_home()
	check(scene.profile.set_equipped(["R01"]), "research equipment unlocked after legacy mode")
	scene.begin("practice")
	check(not scene.sim.state.rewardEligible, "practice has no payout")
	scene.go_home()
	scene.hud._set_challenge_seed("-1")
	check(not scene.hud.seed_valid, "invalid seed is rejected")
	scene.hud._set_challenge_seed("12345")
	check(scene.hud.seed_valid, "valid seed is accepted")
	scene.begin("seededchallenge")
	check(not scene.sim.state.rewardEligible and scene.sim.state.seed == 12345, "seeded challenge uses input and has no payout")
	scene.go_home()
	scene.profile.data.purchased.append("R19")
	scene.profile.data.equipped = ["R19"]
	scene.hud.codex_section = "fusions"
	scene.hud.codex_material = "번개"
	var codex := VBoxContainer.new()
	scene.hud._hub_codex(codex)
	check(contains_text(codex, "플라즈마"), "material filter includes a fusion requiring that spell")
	check(not contains_text(codex, "초신성"), "material filter excludes unrelated fusion")
	codex.free()
	check(scene._event_reward_category("E01") == "회복/경험치", "event category reflects both possible rewards")
	var nearest: Dictionary = scene._nearest_target([{"x": 200, "y": 0}, {"x": 40, "y": 0}], {"x": 0, "y": 0})
	check(nearest.x == 40, "direction points to nearest actual target")
	scene.hud.codex_section = "upgrades"
	scene.hud.codex_material = ""
	scene.hud.codex_search = ""
	var old_size := root.size
	var old_scale_size := root.content_scale_size
	for viewport_size in [Vector2i(540, 960), Vector2i(390, 844), Vector2i(320, 740)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await process_frame
		await process_frame
		var initial_header := Rect2()
		var initial_footer := Rect2()
		var initial_play := Rect2()
		for tab in ["map", "class", "research", "codex", "records", "mode"]:
			scene.hud._select_tab(tab)
			await process_frame
			await process_frame
			var header: Rect2 = scene.hud.hub_header.get_global_rect()
			var footer: Rect2 = scene.hud.hub_footer.get_global_rect()
			var play: Rect2 = scene.hud.hub_footer.get_child(1).get_global_rect()
			if tab == "map":
				initial_header = header
				initial_footer = footer
				initial_play = play
			else:
				check(header.is_equal_approx(initial_header) and footer.is_equal_approx(initial_footer) and play.is_equal_approx(initial_play), "header/footer stay fixed across tabs at %s: %s" % [viewport_size, tab])
			var bounds := Rect2(Vector2.ZERO, Vector2(viewport_size))
			check(bounds.encloses(header) and bounds.encloses(footer) and bounds.encloses(play) and play.size.y >= 44, "header/footer stay inside viewport at %s: %s" % [viewport_size, tab])
			check(scene.hud.hub_content.get_global_rect().position.x >= scene.hud.hub_scroll.get_global_rect().position.x - 0.5 and scene.hud.hub_content.get_global_rect().end.x <= scene.hud.hub_scroll.get_global_rect().end.x + 0.5, "body fits horizontal viewport at %s: %s" % [viewport_size, tab])
			if tab in ["research", "codex"]:
				var scroll: ScrollContainer = scene.hud.hub_scroll
				var scrollbar := scroll.get_v_scroll_bar()
				check(scrollbar.max_value > scrollbar.page, "long tab actually scrolls at %s: %s" % [viewport_size, tab])
				scroll.scroll_vertical = int(scrollbar.max_value - scrollbar.page)
				await process_frame
				check(scene.hud.hub_footer.get_global_rect().is_equal_approx(initial_footer), "PLAY stays fixed after body scroll at %s: %s" % [viewport_size, tab])
	root.content_scale_size = old_scale_size
	root.size = old_size
	await process_frame
	await process_frame
	scene.begin("campaign")
	scene.pause_run()
	await process_frame
	await process_frame
	check(scene.sim.state.phase == "paused" and not scene.hud.pause_recipe_list.visible, "pause starts with recipes collapsed")
	check(scene.hud.pause_recipe_list.get_child_count() == 36 and "36" in scene.hud.pause_recipe_toggle.text, "all 36 recipes remain available")
	var pause_scroll: ScrollContainer = scene.hud.pause_home.get_parent().get_parent().get_parent()
	check(pause_scroll.get_global_rect().encloses(scene.hud.pause_home.get_global_rect()), "pause home action is immediately visible")
	check("보상 없이 포기" in scene.hud.pause_home.text, "home action states abandonment has no reward")
	var paused_time: float = scene.sim.state.time
	scene.hud.pause_recipe_toggle.pressed.emit()
	check(scene.hud.pause_recipe_list.visible, "recipe toggle opens complete list")
	scene._process(0.5)
	check(scene.sim.state.phase == "paused" and scene.sim.state.time == paused_time, "opening recipes keeps combat frozen")
	scene.hud.pause_recipe_toggle.pressed.emit()
	check(not scene.hud.pause_recipe_list.visible, "recipe toggle collapses complete list")
	var before_home_wallet: int = scene.profile.data.wallet
	scene.hud.pause_home.pressed.emit()
	check(scene.sim.state.phase == "ready" and scene.profile.data.wallet == before_home_wallet, "pause home abandons without payout")
	if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("Campaign UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
