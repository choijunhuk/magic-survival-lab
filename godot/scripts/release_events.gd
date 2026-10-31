extends RefCounted

static func has_task(state: Dictionary, id: String) -> bool:
	for task in state.eventTasks:
		if task.id == id: return true
	return false

static func place(sim) -> void:
	var s: Dictionary = sim.state
	if s.bossSpawned: return
	var times := [90.0, 270.0, 450.0]
	if s.eventScheduleIndex < times.size():
		var advance: float = float(sim.presentation_modifiers().eventAdvance)
		if advance > 0 and s.time >= times[s.eventScheduleIndex] - advance: s.researchHints.eventPreviewTime = times[s.eventScheduleIndex]
	if s.eventScheduleIndex < times.size() and s.time >= times[s.eventScheduleIndex]:
		var pool := []
		for item in sim.catalog.events:
			if s.eventUsed.has(item.id): continue
			if item.id == "E05" and s.eliteWindow >= 4: continue
			if item.id == "E08" and learned_below_cap(sim).is_empty(): continue
			pool.append(item)
		if not pool.is_empty():
			var item: Dictionary = pool[sim.rng.randi_range(0, pool.size() - 1)]
			var angle: float = sim.rng.randf() * TAU
			s.events.append({"id": item.id, "x": s.player.x + cos(angle) * 220, "y": s.player.y + sin(angle) * 220, "status": "placed"})
			s.eventUsed.append(item.id)
		s.eventScheduleIndex += 1
	if s.time >= 450 and not s.resonanceUsed and s.resonanceMarker.is_empty():
		for id in s.fusions:
			if id in ["plasma", "blizzard", "supernova", "hyperion"]:
				s.resonanceMarker = {"x": s.player.x + 170, "y": s.player.y, "id": id}; break

static func offer_nearby(sim) -> void:
	var s: Dictionary = sim.state
	var radius := 50.0 * (1.1 if sim.research("R09") else 1.0)
	for marker in s.events:
		if marker.status != "placed" or sim._distance(marker, s.player) > radius: continue
		for item in sim.catalog.events:
			if item.id == marker.id:
				s.activeEvent = item.duplicate(true); s.activeEvent.marker = marker
				s.eventChoices = event_choices(sim, item.id); s.eventConfirm = false
				marker.status = "opened"; s.phase = "event"; return
	if not s.resonanceMarker.is_empty() and sim._distance(s.resonanceMarker, s.player) <= radius:
		var supported := []
		for id in s.fusions:
			if id in ["plasma", "blizzard", "supernova", "hyperion"]: supported.append(id)
		s.resonanceTarget = supported[0] if supported.size() == 1 else ""
		s.resonanceChoices = []
		if supported.size() > 1:
			for id in supported: s.resonanceChoices.append({"id": id, "name": id, "description": "공명 대상 선택"})
		else: set_branches(sim, s.resonanceTarget)
		s.phase = "resonance"

static func event_choices(sim, id: String) -> Array:
	var choices := []
	if id == "E01": return [{"id": "heal", "name": "체력 1 회복"}, {"id": "xp", "name": "레벨 XP 20%"}, {"id": "decline", "name": "거절"}]
	if id == "E08":
		for spell in learned_below_cap(sim): choices.append({"id": spell, "name": spell + " 다음 레벨 보장"})
	else:
		var enabled := true
		if id == "E02": enabled = sim.state.player.hp >= 2
		if id == "E10": enabled = sim.state.xp >= sim.state.xpNeeded * 0.2
		choices.append({"id": "accept", "name": "수락", "enabled": enabled})
	choices.append({"id": "decline", "name": "거절", "enabled": true})
	return choices

static func learned_below_cap(sim) -> Array:
	var result := []
	for id in sim.state.spells:
		if sim.state.spells[id] > 0 and sim.state.spells[id] < 5: result.append(id)
	return result

static func choose(sim, option: String) -> bool:
	var s: Dictionary = sim.state
	if s.phase != "event" or s.activeEvent.is_empty() or s.activeEvent.get("resolving", false): return false
	var id: String = s.activeEvent.id
	if option == "decline":
		s.activeEvent.marker.status = "declined"; s.activeEvent = {}; s.eventChoices.clear(); s.phase = "playing"; return true
	if sim.research("R15") and not s.eventConfirm:
		var valid := false
		for choice in s.eventChoices:
			if choice.id == option and choice.get("enabled", true): valid = true
		if not valid: return false
		s.eventConfirm = true; s.activeEvent.pendingOption = option
		s.eventChoices = [{"id": "confirm", "name": "비용과 보상 확인"}, {"id": "decline", "name": "거절"}]; return true
	if option == "confirm" and s.eventConfirm: option = s.activeEvent.pendingOption
	var allowed := option == "accept"
	if id == "E01": allowed = option in ["heal", "xp"]
	if id == "E08": allowed = learned_below_cap(sim).has(option)
	if not allowed: return false
	if id == "E02" and s.player.hp < 2: return false
	if id == "E10" and s.xp < s.xpNeeded * 0.2: return false
	if id == "E05" and s.eliteWindow >= 4: return false
	if id == "E11" and s.bossSpawned: return false
	s.eventOutcomes.append({"id": id, "choice": option, "completed": false, "reward": s.activeEvent.get("reward", ""), "condition": s.activeEvent.get("condition", ""), "acceptedAt": s.time, "hpBefore": s.player.hp, "xpBefore": s.xp})
	s.activeEvent.resolving = true; s.activeEvent.marker.status = "accepted"
	s.activeEvent = {}; s.eventChoices.clear(); s.phase = "playing"
	match id:
		"E01":
			if option == "heal": sim.grant_heal(1, "E01")
			else: s.xp += s.xpNeeded * 0.2
		"E02": s.player.hp -= 1; sim._offer_artifact(2)
		"E03": s.eventTasks.append({"id": id, "remaining": 45.0})
		"E04": s.phenomenonReveal += 3
		"E05": s.eliteTimer = maxf(0, s.eliteTimer - 20); s.nextEliteChestBonus += 1
		"E06": s.eventTasks.append({"id": id, "remaining": 60.0})
		"E07": s.phenomenonSkip += 1; s.phenomenonWarningCost = 0.2
		"E08": s.guaranteedSpell = option
		"E09": s.eventTasks.append({"id": id, "remaining": 30.0})
		"E10": s.xp -= s.xpNeeded * 0.2; s.phenomenonOrderReveal += 2
		"E11": s.eventTasks.append({"id": id, "remaining": 20.0})
		"E12":
			s.phase = "event_practice"; s.eventPracticeTime = 15.0; s.eventPracticeId = id; s.practiceCorrect = 0
			practice_round(sim)
	sim.Encounters.preview_phenomenon(sim)
	if id not in ["E03", "E06", "E09", "E11", "E12"]: complete(sim, id)
	return true

static func complete(sim, id: String) -> void:
	if not sim.state.completedEvents.has(id): sim.state.completedEvents.append(id)
	for outcome in sim.state.eventOutcomes:
		if outcome.id == id and not outcome.completed:
			outcome.completed = true; outcome.completedAt = sim.state.time; outcome.hpAfter = sim.state.player.hp; outcome.xpAfter = sim.state.xp
			break

static func advance_tasks(sim, dt: float) -> void:
	for task in sim.state.eventTasks.duplicate():
		task.remaining -= dt
		if task.remaining > 0 or sim.state.player.hp <= 0: continue
		# Rewards are presented after terminal resolution, never before a fatal frame.
		task.ready = true

static func settle_tasks(sim) -> void:
	for task in sim.state.eventTasks.duplicate():
		if not task.get("ready", false): continue
		sim.state.eventTasks.erase(task)
		match task.id:
			"E03": sim._offer_artifact(1)
			"E06": sim.state.xp += sim.state.xpNeeded * 0.25
			"E09": sim.grant_heal(1, "E09")
			"E11": sim.state.nextEliteWarningBonus = 1.0
		complete(sim, task.id)
		if sim.state.phase != "playing": return

static func advance_practice(sim, dt: float) -> void:
	if sim.state.phase != "event_practice" or not is_finite(dt) or dt <= 0: return
	for h in sim.state.practiceHazards:
		h.warning = maxf(0, h.warning - minf(dt, 0.05))
	sim.state.eventPracticeTime = maxf(0, sim.state.eventPracticeTime - minf(dt, 0.05))
	if sim.state.eventPracticeTime <= 0:
		complete(sim, "E12"); sim.state.practiceClue = true; sim.state.practiceHazards.clear(); sim.state.practiceAnswers.clear(); sim.state.phase = "playing"

static func set_branches(sim, id: String) -> void:
	for item in sim.catalog.resonances:
		if item.fusionId == id: sim.state.resonanceChoices = item.choices.duplicate(true)

static func choose_resonance(sim, id: String) -> bool:
	var s: Dictionary = sim.state
	if s.phase != "resonance" or s.resonanceUsed: return false
	if id == "decline":
		s.resonanceUsed = true; s.resonanceMarker.clear(); s.resonanceChoices.clear(); s.phase = "playing"; return true
	if s.resonanceTarget.is_empty():
		for item in s.resonanceChoices:
			if item.id == id and s.fusions.has(id): s.resonanceTarget = id; set_branches(sim, id); return true
		return false
	var offered := false
	for item in s.resonanceChoices:
		if item.id == id: offered = true
	if not offered: return false
	s.resonances[s.resonanceTarget] = id; s.resonanceUsed = true; s.resonanceMarker.clear(); s.resonanceChoices.clear(); s.phase = "playing"; return true

static func practice_round(sim) -> void:
	var shapes := ["circle", "ray", "ring", "wave"]
	var shape: String = shapes[sim.state.practiceCorrect % shapes.size()]
	sim.state.practiceHazards = [{"shape": shape, "kind": shape, "x": sim.state.player.x, "y": sim.state.player.y + 80, "owner": "practice", "radius": 65.0, "innerRadius": 35.0, "warning": 1.2, "active": 0.0, "angle": 0.0, "length": 140.0, "width": 16.0, "safeGap": {"angle": PI * 0.5, "width": PI / 2}}]
	sim.state.practiceAnswers = [{"id": "circle", "name": "원형: 바깥으로 이동"}, {"id": "ray", "name": "직선: 옆으로 이동"}, {"id": "ring", "name": "고리: 열린 각도로 이동"}, {"id": "wave", "name": "파형: 중앙 틈으로 이동"}]

static func choose_practice_answer(sim, shape: String) -> bool:
	if sim.state.phase != "event_practice" or sim.state.practiceHazards.is_empty(): return false
	var correct: bool = sim.state.practiceHazards[0].shape == shape
	sim.state.practiceFeedback = "안전 경로 확인" if correct else "경고 모양과 안전 경로를 다시 확인하세요"
	if correct:
		sim.state.practiceCorrect += 1
		practice_round(sim)
	return correct
