extends SceneTree
const Sim = preload("res://scripts/release_simulation.gd")
const Enc = preload("res://scripts/release_encounters.gd")
var checks := 0
var failures := 0

# The former release behavior below its600 cap is the gameplay reference. It
# intentionally stores all decorations so only presentation arrays can differ.
class UnboundedRelease:
	extends "res://scripts/release_simulation.gd"
	func _effect(kind: String, x: float, y: float, life: float, extra: Dictionary = {}) -> void:
		var value := {"type": kind, "x": x, "y": y, "life": life, "maxLife": life}
		value.merge(extra, true)
		state.effects.append(value)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)

func configure(sim) -> void:
	sim.start(); var s: Dictionary = sim.state; s.time = 600
	for id in ["bolt", "lightning", "frost", "vortex", "fireball", "meteor"]: s.spells[id] = 5
	s.fusions = ["plasma", "blizzard", "supernova"]
	s.artifacts = ["magicwand", "blackcat", "battery", "ruby", "snowflakecrown", "sapphire"]
	for id in s.artifacts: sim.artifact_rules.on_acquire(sim, id)
	s.spawnTimer = INF; s.eliteTimer = INF; s.eliteWindow = 4; s.bossAt = INF
	s.eventScheduleIndex = 3; s.resonanceUsed = true; s.player.invulnerable = INF
	for i in range(200):
		var enemy: Dictionary = Enc.enemy(sim, 1 + i % 24, 0, Vector2.from_angle(i * TAU / 200.0) * (210 + (i % 5) * 55))
		enemy.hp = 1e9; enemy.maxHp = 1e9

func gameplay_snapshot(sim) -> Dictionary:
	var value: Dictionary = sim.state.duplicate(true)
	value.erase("effects")
	return value

func _initialize() -> void:
	var sim := Sim.new(99, "campaign", {"runId": "budget"})
	var rng_before: int = sim.rng.state
	for i in range(2000): sim._effect("hit", i, 0, 10, {"serial": i})
	check(sim.state.effects.size() == 100 and sim.state.effects[0].serial == 1900 and sim.state.effects[-1].serial == 1999, "cosmetic stress retains latest100 decorations")
	check(sim.rng.state == rng_before, "cosmetic trimming consumes no combat RNG")
	sim.state.effects.clear()
	var protected := ["enemy_cast_warning", "enemy_dash_warning", "reappear_warning", "artifact_warning", "pulse", "mark", "sword_line", "future_semantic_fx", "meteor"]
	for kind in protected: sim._effect(kind, 1, 2, 50, {"damage": 7.0, "hitIds": [42], "maxRadius": 123.0})
	for i in range(2000): sim._effect(Sim.COSMETIC_EFFECT_TYPES[i % Sim.COSMETIC_EFFECT_TYPES.size()], i, 0, 10)
	for kind in protected:
		var retained: Array = sim.state.effects.filter(func(e): return e.type == kind)
		check(retained.size() == 1 and retained[0].damage == 7 and retained[0].hitIds == [42], "essential signal and semantic payload survive: " + kind)
	check(sim.state.effects.size() == 100, "protected signals displace cosmetics within100 target")
	sim.state.effects.clear()
	for i in range(120): sim._effect("artifact_warning", i, 0, 50, {"serial": i})
	for i in range(400): sim._effect("explosion", i, 0, 10)
	check(sim.state.effects.size() == 120 and sim.state.effects.all(func(e): return e.type == "artifact_warning"), "essential-only overflow never hides a warning to enforce a cosmetic target")

	var bounded := Sim.new(481516, "campaign", {"runId": "same-pressure"})
	var reference := UnboundedRelease.new(481516, "campaign", {"runId": "same-pressure"})
	configure(bounded); configure(reference)
	var bounded_peak := 0; var reference_peak := 0
	for i in range(180):
		var input := Vector2.from_angle(i * 0.01) * 0.2
		bounded.tick(1.0 / 60.0, input); reference.tick(1.0 / 60.0, input)
		bounded_peak = maxi(bounded_peak, bounded.state.effects.size()); reference_peak = maxi(reference_peak, reference.state.effects.size())
	check(reference_peak > 100 and bounded_peak <= 100, "real200-enemy combat reduces cosmetic pressure to100")
	check(gameplay_snapshot(bounded) == gameplay_snapshot(reference), "all gameplay state is identical to unbounded visual reference")
	check(bounded.rng.state == reference.rng.state, "pressure replay combat RNG is identical")
	for item in [bounded, reference]:
		item.state.player.hp = 0; item.state.bossDefeated = true; item.state.time = 899.99; item.tick(0.05)
	check(bounded.state.phase == "lost" and bounded.state.endReason == "death" and gameplay_snapshot(bounded) == gameplay_snapshot(reference), "terminal ordering and final gameplay state are unchanged")
	print("Release effect budget: %d checks, %d failures; real pressure FX peak%d -> %d" % [checks, failures, reference_peak, bounded_peak])
	quit(1 if failures else 0)
