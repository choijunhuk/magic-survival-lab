extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func fresh():
 var script = load("res://scripts/release_simulation.gd")
 return script.new(42, "campaign", {"classId":"C01"})
func target() -> Dictionary:
 return {"id":7,"x":20.0,"y":0.0,"hp":200.0,"maxHp":200.0,"kind":"normal","radius":12,"family":"basic","statuses":{},"shield":0.0}
func _initialize() -> void:
 var sim = fresh()
 sim.start()
 sim.state.phase = "artifact"
 sim.state.spells.m13 = 1
 sim.state.artifactChoices = [{"id":"a016"}]
 check(sim.choose_artifact("a016"), "shadow artifact selected")
 check(not sim.choose_artifact("a016"), "duplicate selection rejected")
 var enemy := target()
 sim.state.enemies = [enemy]
 var direct: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1})
 var dot: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"dot","depth":0,"attackId":2})
 check(direct > dot, "obsidian ring boosts direct shadow but not dot")
 sim = fresh()
 sim.start()
 var projectile_combat = load("res://scripts/release_combat.gd")
 projectile_combat.projectile(sim,"bolt",Vector2.ZERO,Vector2.RIGHT,1.0,{"speed":200.0,"life":2.0})
 var plain_projectile: Dictionary = sim.state.projectiles[0]
 var plain_range: float = Vector2(plain_projectile.vx,plain_projectile.vy).length() * plain_projectile.life
 sim.state.projectiles.clear()
 sim.state.artifacts = ["a017"]
 projectile_combat.projectile(sim,"bolt",Vector2.ZERO,Vector2.RIGHT,1.0,{"speed":200.0,"life":2.0})
 var silver_projectile: Dictionary = sim.state.projectiles[0]
 check(is_equal_approx(Vector2(silver_projectile.vx,silver_projectile.vy).length(),236.0), "silver gloves increase arcane projectile speed by 18 percent")
 check(is_equal_approx(Vector2(silver_projectile.vx,silver_projectile.vy).length() * silver_projectile.life,plain_range), "silver gloves preserve projectile range")
 sim = fresh()
 sim.start()
 sim.state.spells.bolt = 0
 sim.state.spells.m10 = 1
 sim.state.spells.m18 = 1
 enemy = target()
 enemy.x = 400.0
 sim.state.enemies = [enemy]
 projectile_combat.advance(sim,0.01)
 var plain_cold_radius: float = sim.state.projectiles[0].radius
 var plain_wall: Dictionary = sim.state.fields.filter(func(e): return e.kind == "wall")[0]
 sim = fresh()
 sim.start()
 sim.state.spells.bolt = 0
 sim.state.spells.m10 = 1
 sim.state.spells.m18 = 1
 sim.state.artifacts = ["a020"]
 enemy = target()
 enemy.x = 400.0
 sim.state.enemies = [enemy]
 projectile_combat.advance(sim,0.01)
 var enhanced_wall: Dictionary = sim.state.fields.filter(func(e): return e.kind == "wall")[0]
 check(is_equal_approx(sim.state.projectiles[0].radius,plain_cold_radius * 1.1), "frost pin enlarges cold projectile contact radius")
 check(is_equal_approx(enhanced_wall.width,plain_wall.width * 1.1) and is_equal_approx(enhanced_wall.radius,plain_wall.radius), "frost pin enlarges cold wall width without changing length")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a067","a090"]
 projectile_combat.explode(sim,Vector2.ZERO,80.0,10.0,sim.context("meteor"),"meteor")
 check(sim.state.pendingEffects.size() == 4, "meteor aftershock and fragments trigger on empty impact")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a081"]
 enemy = target()
 enemy.x = 66.0
 enemy.y = 0.0
 sim.state.enemies = [enemy]
 projectile_combat.explode(sim,Vector2.ZERO,50.0,10.0,sim.context("fireball"),"fireball")
 check(enemy.hp < 200.0 and sim.state.combatLog.any(func(e): return e.get("sourceId", "") == "a081" and e.get("depth",0) == 1), "split sun reaches a secondary target outside the original blast")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a087"]
 enemy = target()
 enemy.x = 0.0
 enemy.dashTime = 0.0
 sim.state.enemies = [enemy]
 projectile_combat.field(sim,"glyph",Vector2.ZERO,50.0,2.0,{"sourceId":"m15","context":sim.context("m15"),"damage":0.0})
 projectile_combat.update_fields(sim,0.01)
 enemy.dashTime = 0.1
 projectile_combat.update_fields(sim,0.01)
 check(is_zero_approx(enemy.dashTime), "seal gate cancels short dash between glyph damage ticks")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a087"]
 enemy = target()
 enemy.kind = "elite"
 enemy.x = 0.0
 enemy.dashTime = 0.0
 sim.state.enemies = [enemy]
 projectile_combat.field(sim,"glyph",Vector2.ZERO,50.0,2.0,{"sourceId":"m15","context":sim.context("m15"),"damage":0.0})
 projectile_combat.update_fields(sim,0.01)
 enemy.dashTime = 0.1
 projectile_combat.update_fields(sim,0.01)
 check(is_equal_approx(enemy.dashTime,0.1), "seal gate does not cancel elite dash")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a038"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"shock",3.0,1.0)
 var shock_hit: float = sim.apply_damage(enemy,10.0,{"sourceId":"lightning","school":"폭풍","damageKind":"direct","depth":0,"attackId":91})
 check(is_equal_approx(shock_hit,12.2), "clear crystal amplifies only shock-consumption bonus by 10 percent")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a049"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"shock",2.0,1.0)
 sim.apply_damage(enemy,10.0,{"sourceId":"lightning","school":"폭풍","damageKind":"direct","depth":0,"attackId":3})
 check(sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a049" and e.get("depth", 0) == 1).size() == 1, "shock consumption produces one derived coil hit")
 sim.apply_status(enemy,"shock",2.0,1.0)
 sim.apply_damage(enemy,10.0,{"sourceId":"lightning","school":"폭풍","damageKind":"derived","depth":1,"attackId":4})
 check(sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a049").size() == 1, "derived hit never triggers coil")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a091", "a096"]
 sim.state.spells.m24 = 1
 sim.hurt_player(6.0,{"sourceId":"test"})
 check(sim.state.player.hp == 6.0 and not sim.state.artifactRuntime.get("a091Used",false), "return amulet precedes fatal clock")
 sim.state.player.invulnerable = 0.0
 sim.state.returnReadyAt = 999.0
 sim.hurt_player(6.0,{"sourceId":"test"})
 check(sim.state.player.hp == 1.0 and sim.state.artifactRuntime.get("a091Used",false), "clock saves fatal damage once")
 sim.state.player.invulnerable = 0.0
 sim.state.player.hp = sim.state.player.maxHp
 sim.state.player.shield = 1
 sim.hurt_player(2.0,{"sourceId":"test"})
 check(sim.state.player.hp == sim.state.player.maxHp and float(sim.state.artifactRuntime.get("a096",0.0)) == 0.0, "aegis precedes leaf")
 sim.state.player.invulnerable = 0.0
 sim.hurt_player(2.0,{"sourceId":"test"})
 check(is_equal_approx(sim.state.player.hp,sim.state.player.maxHp - 1.0) and float(sim.state.artifactRuntime.get("a096",0.0)) > 0.0, "leaf removes one damage and recharges")
 sim = fresh()
 sim.start()
 sim.state.player.hp = 5.0
 sim.state.healBudget = 1.0
 sim.state.artifacts = ["a014"]
 for i in range(29):
  enemy = target()
  enemy.id = 100 + i
  enemy.hp = 1.0
  sim.state.enemies.append(enemy)
  sim.apply_damage(enemy,10.0,{"sourceId":"bolt","school":"비전","damageKind":"direct","depth":0,"attackId":100+i})
 check(is_equal_approx(sim.state.player.hp,5.0), "mending thread does not heal before thirty kills")
 enemy = target()
 enemy.id = 129
 enemy.hp = 1.0
 sim.state.enemies.append(enemy)
 sim.apply_damage(enemy,10.0,{"sourceId":"bolt","school":"비전","damageKind":"direct","depth":0,"attackId":129})
 check(is_equal_approx(sim.state.player.hp,5.2), "mending thread heals on thirtieth nonboss kill")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a029"]
 sim.hurt_player(1.0,{"sourceId":"test"})
 var move: Dictionary = sim.artifact_rules.modifiers(sim.state,{"damageKind":"movement"})
 check(is_equal_approx(move.move_speed_mult,1.15), "light boots activate after hit")
 sim.artifact_rules.tick(sim,2.0)
 move = sim.artifact_rules.modifiers(sim.state,{"damageKind":"movement"})
 check(is_equal_approx(move.move_speed_mult,1.0), "light boots expire at two seconds")
 sim = fresh()
 sim.start()
 sim.state.stats.haste = 20
 var cap_combat = load("res://scripts/release_combat.gd")
 cap_combat.cooldown(sim,"bolt",0.5)
 check(sim.state.cooldowns.bolt >= 0.4, "spell cooldown has 0.4 second minimum")
 cap_combat.cooldown(sim,"bolt",4.0)
 check(sim.state.cooldowns.bolt >= 4.0/1.8 - 0.0001, "combined haste does not exceed 80 percent")
 sim = fresh()
 sim.start()
 sim.state.player.speed = 253.0
 sim.state.artifacts = ["broom","a029","a040","a063"]
 sim.state.artifactRuntime.a029 = 2.0
 sim.state.artifactRuntime.a063 = 2.0
 sim.state.enemyProjectiles = [{"x":20.0,"y":0.0,"beam":false}]
 sim._advance_player(0.1,Vector2.RIGHT)
 check(sim.state.player.x <= 35.2001, "combined movement bonuses respect 1.6x base speed cap")
 sim = fresh()
 sim.start()
 sim.state.spells.orbit = 1
 var baseline_orbit: Vector2 = sim.orbit_position(0)
 sim.state.artifacts = ["a043"]
 check(sim.orbit_position(0).is_equal_approx(baseline_orbit), "iron filings leave the orbital path unchanged")
 enemy = target()
 enemy.x = baseline_orbit.x + 24.5
 enemy.y = baseline_orbit.y
 enemy.orbitHitUntil = 0.0
 sim.state.enemies = [enemy]
 cap_combat.orbit(sim)
 check(enemy.hp < 200.0, "iron filings increase sword contact radius")
 sim = fresh()
 sim.start()
 sim.state.spells.orbit = 4
 sim.state.artifacts = ["a093"]
 enemy = target()
 enemy.x = 0.0
 enemy.y = 0.0
 enemy.orbitHitUntil = 0.0
 var away := target()
 away.id = 8
 away.x = 130.0
 away.y = 130.0
 away.orbitHitUntil = 0.0
 sim.state.enemies = [enemy,away]
 cap_combat.orbit(sim)
 var line_hits: int = sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a093").size()
 check(line_hits > 0 and is_equal_approx(away.hp,200.0), "sword constellation hits its central line rather than distant enemies")
 cap_combat.orbit(sim)
 check(sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a093").size() == line_hits, "constellation line observes per-target per-line interval")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a058"]
 enemy = target()
 enemy.kind = "elite"
 enemy.x = 175.0
 sim.state.enemies = [enemy]
 sim.hurt_player(2.0,{"sourceId":"test","projectile":true})
 check(is_equal_approx(sim.state.player.hp,4.3), "sentinel armor protects when elite is within 180 units")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a023"]
 sim.hurt_player(2.0,{"sourceId":"test","projectile":true})
 check(is_equal_approx(sim.state.player.hp,4.16), "small shield reduces direct projectile damage")
 sim.state.player.invulnerable = 0.0
 sim.state.player.hp = 6.0
 sim.hurt_player(1.0,{"sourceId":"test","projectile":true})
 check(is_equal_approx(sim.state.player.hp,5.0), "small shield preserves minimum one direct damage")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a072"]
 sim.state.phase = "upgrade"
 sim.state.choices = [sim.catalog.upgrades[0]]
 var original = sim.state.choices[0]
 check(sim.reroll_artifact_upgrade(), "memory shard rerolls an upgrade once")
 check(sim.state.choices.size() == 1 and sim.state.choices[0].has("requires") == original.has("requires"), "memory shard keeps the same selection tier")
 check(not sim.reroll_artifact_upgrade(), "memory shard reroll cannot repeat")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a034"]
 for i in range(40): sim.spawn_seed(Vector2(i,0),false)
 var seed_events: Array = sim.state.combatLog.filter(func(e): return e.get("seedSpawned",false))
 var extra_events: Array = seed_events.filter(func(e): return e.get("extra",false))
 check(not extra_events.is_empty() and extra_events.size() <= 40 and seed_events.size() == 40 + extra_events.size(), "empty bottle creates bounded nonrecursive bonus seeds")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a081"]
 enemy = target()
 var other := target()
 other.id = 8
 other.x = -20.0
 sim.state.enemies = [enemy,other]
 var combat_split = load("res://scripts/release_combat.gd")
 combat_split.explode(sim,Vector2.ZERO,80.0,10.0,sim.context("fireball"),"fireball")
 check(sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a081").size() == 2, "split sun creates two secondary explosions once per original attack")
 sim = fresh()
 sim.start()
 sim.state.stats.power = 2
 sim.state.artifacts = ["a081"]
 enemy = target()
 sim.state.enemies = [enemy]
 combat_split.explode(sim,Vector2.ZERO,80.0,10.0,sim.context("fireball"),"fireball")
 var split_hits: Array = sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a081")
 check(split_hits.size() == 1 and is_equal_approx(float(split_hits[0].damage),6.0), "split explosion deals 40 percent of actual original damage without double scaling")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a067","a090"]
 enemy = target()
 other = target()
 other.id = 8
 other.x = -20.0
 sim.state.enemies = [enemy,other]
 combat_split.explode(sim,Vector2.ZERO,80.0,10.0,sim.context("meteor"),"meteor")
 check(sim.state.pendingEffects.size() == 4, "meteor schedules one aftershock and three fragments once per attack")
 combat_split.advance_effects(sim,0.49)
 check(sim.state.pendingEffects.size() == 4, "meteor follow-ups preserve warning before half second")
 combat_split.advance_effects(sim,0.02)
 check(sim.state.pendingEffects.is_empty(), "meteor follow-ups resolve without new fragments")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a015"]
 sim.state.player.hp = 2.0
 sim.state.healBudget = 0.3
 sim.artifact_rules.on_acquire(sim,"a015")
 sim.artifact_rules.tick(sim,0.1)
 check(is_equal_approx(sim.state.player.hp,2.3), "emergency water respects healing budget")
 for i in range(3):
  sim.state.healBudget = 0.3
  sim.artifact_rules.tick(sim,1.0)
 check(is_equal_approx(sim.state.player.hp,3.0), "emergency water delivers one HP through the cap")
 sim.state.player.hp = 2.0
 sim.state.healBudget = 1.0
 sim.artifact_rules.tick(sim,1.0)
 check(is_equal_approx(sim.state.player.hp,2.0), "emergency water remains once per run")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a037"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"ignite",10.0,1.0)
 var fire_ctx := {"sourceId":"fireball","school":"화염","damageKind":"direct","depth":0,"attackId":1}
 var ash_first: float = sim.apply_damage(enemy,10.0,fire_ctx)
 sim.artifact_rules.tick(sim,2.0)
 var ash_middle: float = sim.apply_damage(enemy,10.0,fire_ctx)
 sim.artifact_rules.tick(sim,1.0)
 var ash_next: float = sim.apply_damage(enemy,10.0,fire_ctx)
 check(is_equal_approx(ash_first,11.0) and is_equal_approx(ash_middle,10.0) and is_equal_approx(ash_next,11.0), "ash pouch cooldown does not refresh on unboosted hits")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a039"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"vulnerable",3.0,1.0)
 check(is_equal_approx(sim.status_time(enemy,"vulnerable"),3.5), "black cloth adds half a second vulnerability")
 sim.apply_status(enemy,"vulnerable",4.0,1.0)
 check(is_equal_approx(sim.status_time(enemy,"vulnerable"),4.0), "vulnerability remains capped at four seconds")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a056"]
 enemy = target()
 enemy.x = 1.0
 var second := target()
 second.id = 8
 second.x = 2.0
 var third := target()
 third.id = 9
 third.x = 3.0
 sim.state.enemies = [enemy,second,third]
 var pierce_combat = load("res://scripts/release_combat.gd")
 pierce_combat.projectile(sim,"bolt",Vector2.ZERO,Vector2.RIGHT,10.0,{"speed":0.0,"pierce":3})
 pierce_combat.update_projectiles(sim,0.01)
 check(is_equal_approx(200.0-enemy.hp,9.0) and is_equal_approx(200.0-second.hp,10.08) and is_equal_approx(200.0-third.hp,11.16), "afterglow awl counts completed penetrations, not available pierces")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a088"]
 enemy = target()
 second = target()
 second.id = 8
 sim.state.enemies = [enemy,second]
 var arcane_ctx := {"sourceId":"pulse","school":"비전","damageKind":"direct","depth":0,"attackId":777}
 sim.apply_damage(enemy,1.0,arcane_ctx)
 sim.apply_damage(second,1.0,arcane_ctx)
 check(sim.status_time(enemy,"mark") > 0.0 and sim.status_time(second,"mark") == 0.0, "origin crystal marks only first target of arcane attack")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a083"]
 enemy = target()
 sim.state.enemies = [enemy]
 pierce_combat.lightning(sim,enemy,1,sim.context("lightning"))
 check(sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a083" and e.get("depth",0) == 1).size() == 1, "lightning crown returns once even when chain ends early")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a060"]
 enemy = target()
 enemy.x = 0.0
 sim.state.enemies = [enemy]
 pierce_combat.field(sim,"glyph",Vector2.ZERO,50.0,2.0,{"sourceId":"m15","context":sim.context("m15"),"damage":0.0})
 pierce_combat.update_fields(sim,0.01)
 enemy.statuses.erase("slow")
 enemy.x = 100.0
 pierce_combat.update_fields(sim,0.01)
 check(is_equal_approx(sim.status_time(enemy,"slow"),1.0), "vacuum jar applies residual slow immediately upon field exit")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a069"]
 enemy = target()
 enemy.hp = 10.0
 enemy.x = 300.0
 sim.state.enemies = [enemy]
 pierce_combat.projectile(sim,"m13",Vector2.ZERO,Vector2.RIGHT,1.0,{"speed":0.0})
 pierce_combat.update_projectiles(sim,0.01)
 check(not sim.state.artifactRuntime.get("a069",false), "black knot does not activate on a missed dagger")
 enemy.x = 1.0
 pierce_combat.update_projectiles(sim,0.01)
 check(sim.state.artifactRuntime.get("a069",false), "black knot activates on successful dagger execution")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a059"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.emit_event("control",{"dodged":true})
 sim.apply_damage(enemy,1.0,{"sourceId":"ignite","school":"화염","damageKind":"dot","depth":0,"attackId":20})
 var dodge_hit: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1})
 var dodge_same_attack: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1})
 var normal_hit: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":2})
 check(is_equal_approx(dodge_hit,12.0) and is_equal_approx(dodge_same_attack,12.0) and is_equal_approx(normal_hit,10.0), "dodge buff affects the complete next direct attack")
 sim.emit_event("control",{"dodged":true})
 sim.artifact_rules.tick(sim,2.0)
 check(is_equal_approx(sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":3}),10.0), "dodge buff expires after two seconds")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a092"]
 enemy = target()
 sim.state.enemies = [enemy]
 for school in ["화염", "냉기", "그림자"]:
  sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":school,"damageKind":"direct","depth":0,"attackId":2})
 var prism_hit: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":3})
 var prism_second_target: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":3})
 var next_hit: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":4})
 check(is_equal_approx(prism_hit,14.0) and is_equal_approx(prism_second_target,14.0) and is_equal_approx(next_hit,10.0), "aurora prism boosts the whole next attack once")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a092"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"화염","damageKind":"direct","depth":0,"attackId":1})
 sim.artifact_rules.tick(sim,6.0)
 for school in ["냉기", "그림자"]:
  sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":school,"damageKind":"direct","depth":0,"attackId":2})
 check(not sim.state.artifactRuntime.get("a092Ready",false), "prism expires its six-second school window")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a082"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_damage(enemy,1.0,{"sourceId":"frost","school":"냉기","damageKind":"direct","depth":0,"attackId":1})
 check(is_equal_approx(sim.status_time(enemy,"root"),0.6), "absolute zero binds normal enemies on cold hit")
 sim.apply_status(enemy,"root",0.1,1.0)
 check(is_equal_approx(sim.status_time(enemy,"root"),0.6), "root immunity prevents immediate refresh")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a082"]
 enemy = target()
 enemy.kind = "boss"
 sim.state.enemies = [enemy]
 sim.apply_damage(enemy,1.0,{"sourceId":"frost","school":"냉기","damageKind":"direct","depth":0,"attackId":1})
 check(sim.status_time(enemy,"root") == 0.0 and sim.status_time(enemy,"slow") > 0, "absolute zero substitutes slow for boss root")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a055"]
 sim.state.spells.m15 = 1
 sim.state.artifactRuntime.a055 = true
 sim.state.enemies = [target()]
 var combat_tablet = load("res://scripts/release_combat.gd")
 combat_tablet.advance(sim,0.05)
 check(is_equal_approx(sim.state.cooldowns.m15,3.6), "closed tablet reduces next glyph cooldown by 20 percent")
 check(not sim.state.artifactRuntime.get("a055",false), "closed tablet charge consumed after cooldown calculation")
 sim = fresh()
 sim.start()
 sim.state.spells.meteor = 1
 sim.state.artifacts = ["a074"]
 enemy = target()
 enemy.hp = 100.0
 var high_hp := target()
 high_hp.id = 8
 high_hp.hp = 180.0
 high_hp.x = 25.0
 sim.state.enemies = [enemy,high_hp]
 var target_combat = load("res://scripts/release_combat.gd")
 check(target_combat.choose_target(sim,"meteor").id == 8, "refined lens makes campaign meteor prioritize highest HP")
 var meteor_ctx := {"sourceId":"meteor","school":"화염","damageKind":"direct","depth":0,"attackId":111,"targetingPolicy":"highest_hp","priorityTargetId":8}
 var low_damage: float = sim.apply_damage(enemy,10.0,meteor_ctx)
 var high_damage: float = sim.apply_damage(high_hp,10.0,meteor_ctx)
 check(is_equal_approx(low_damage,10.0) and is_equal_approx(high_damage,11.5), "refined lens buffs only prioritized first-hit target")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a094"]
 enemy = target()
 enemy.kind = "elite"
 enemy.castWarning = 2.0
 sim.state.enemies = [enemy]
 sim.delay_enemy_cast(7,1.0)
 check(is_equal_approx(enemy.castWarning,3.8), "stopped bell adds 0.8 seconds to delayed elite cast")
 sim.delay_enemy_cast(7,1.0)
 check(is_equal_approx(enemy.castWarning,3.8), "stopped bell does not repeatedly extend cast")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a052"]
 enemy = target()
 sim.state.enemies = [enemy]
 var center_event := {"sourceId":"m12","targetId":7,"targetKind":"normal","wellId":3,"centerHit":true}
 sim.emit_event("control",center_event)
 check(is_equal_approx(enemy.hp,199.4), "collapse lens deals 60D at well center")
 sim.emit_event("control",center_event)
 check(is_equal_approx(enemy.hp,199.4), "collapse lens strikes each target once per well")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a052"]
 enemy = target()
 sim.state.enemies = [enemy]
 var combat = load("res://scripts/release_combat.gd")
 combat.field(sim,"well",Vector2(20,0),80.0,2.0,{"sourceId":"m12","context":sim.context("m12"),"ringHits":{}})
 combat.update_fields(sim,0.05)
 check(is_equal_approx(enemy.hp,199.4), "live gravity well emits center event")
 combat.update_fields(sim,0.05)
 check(is_equal_approx(enemy.hp,199.4), "live gravity well center hit is not repeated")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a084"]
 for i in range(10): sim.state.enemyProjectiles.append({"x":0.0,"y":0.0,"beam":false})
 sim.state.enemyProjectiles.append({"x":0.0,"y":0.0,"beam":true})
 sim.emit_event("cast",{"sourceId":"m12","gravityWell":true,"wellId":1,"radius":100.0,"targetPosition":Vector2.ZERO})
 check(sim.state.enemyProjectiles.size() == 3, "abyss compass absorbs eight and excludes beams")
 sim.emit_event("cast",{"sourceId":"m12","gravityWell":true,"wellId":1,"radius":100.0,"targetPosition":Vector2.ZERO})
 check(sim.state.enemyProjectiles.size() == 3, "well projectile cap persists across ticks")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a084"]
 combat.field(sim,"well",Vector2.ZERO,80.0,2.0,{"sourceId":"m12","context":sim.context("m12"),"ringHits":{}})
 sim.state.enemyProjectiles = [{"x":0.0,"y":0.0,"beam":false}]
 combat.update_fields(sim,0.05)
 check(sim.state.enemyProjectiles.is_empty(), "live well emits absorption on active tick")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a071"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"ignite",3.0,1.0)
 sim.apply_status(enemy,"shock",3.0,1.0)
 check(is_equal_approx(enemy.hp,199.7), "conductive bone deals 30D when shock is applied to burning enemy")
 sim.apply_status(enemy,"shock",3.0,1.0)
 check(is_equal_approx(enemy.hp,199.7), "conductive bone target cooldown prevents repetition")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a050"]
 enemy = target()
 enemy.hp = 1.0
 var nearby := target()
 nearby.id = 8
 nearby.x = 40.0
 sim.state.enemies = [enemy, nearby]
 sim.apply_status(enemy,"ignite",3.0,1.0)
 sim.apply_damage(enemy,10.0,{"sourceId":"fireball","school":"화염","damageKind":"direct","depth":0,"attackId":1000})
 check(is_equal_approx(nearby.hp,199.6), "volcanic glass deals 40D derived explosion on ignited kill")
 check(sim.state.combatLog.filter(func(e): return e.get("kind", "") == "hit" and e.get("sourceId", "") == "a050").size() == 1, "explosion triggers once without recursion")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["sapphire"]
 sim.state.gems = [{"x":0.0,"y":0.0,"value":4.0,"radius":6.0}]
 sim._collect_gems(0.1)
 check(is_equal_approx(sim.state.xp,5.0), "sapphire increases collected XP by 25 percent")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["radar"]
 sim.state.gems = [{"x":125.0,"y":0.0,"value":1.0,"radius":6.0}]
 sim._collect_gems(0.1)
 check(sim.state.gems[0].x < 125.0, "radar adds 80 units of gem attraction")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["ruby"]
 enemy = target()
 sim.state.enemies = [enemy]
 var ruby_hit: float = sim.apply_damage(enemy,10.0,{"sourceId":"fireball","school":"화염","damageKind":"direct","depth":0,"attackId":1})
 check(is_equal_approx(ruby_hit,13.0), "ruby boosts fireball damage by 30 percent")
 # Legacy artifact acquisition and effects.
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["magicwand"]
 enemy = target()
 sim.state.enemies = [enemy]
 check(is_equal_approx(sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1}),12.0), "magic wand increases magic damage by 20 percent")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["blackcat"]
 cap_combat.cooldown(sim,"frost",4.0)
 check(is_equal_approx(sim.state.cooldowns.frost,4.0/1.12), "black cat grants 12 percent cast speed")
 sim = fresh()
 sim.start()
 sim.state.phase = "artifact"
 sim.state.artifactChoices = [{"id":"broom"}]
 check(sim.choose_artifact("broom") and is_equal_approx(sim.state.player.speed,253.0), "broom immediately increases speed 15 percent")
 sim = fresh()
 sim.start()
 sim.state.player.hp = 2.0
 sim.state.phase = "artifact"
 sim.state.artifactChoices = [{"id":"secondheart"}]
 check(sim.choose_artifact("secondheart") and sim.state.player.hp == 5.0 and sim.state.player.maxHp == 9.0, "second heart immediately grants three current and maximum health")
 sim = fresh()
 sim.start()
 sim.state.player.hp = 5.0
 sim.state.artifacts = ["worldtreeleaf"]
 sim._advance_player(1.0,Vector2.ZERO)
 check(is_equal_approx(sim.state.player.hp,5.06), "world tree leaf regenerates 0.06 health per second")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["battery"]
 enemy = target()
 enemy.x = 10.0
 second = target()
 second.id = 8
 second.x = 30.0
 third = target()
 third.id = 9
 third.x = 50.0
 sim.state.enemies = [enemy,second,third]
 cap_combat.lightning(sim,enemy,1,sim.context("lightning"))
 check(enemy.hp < 200.0 and second.hp < 200.0 and third.hp < 200.0, "battery adds one distinct lightning chain target")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["snowflakecrown"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"slow",2.0,0.25)
 check(is_equal_approx(sim.status_time(enemy,"slow"),3.0), "snowflake crown extends slow duration")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["circularsawblade"]
 enemy = target()
 sim.state.enemies = [enemy]
 check(is_equal_approx(sim.apply_damage(enemy,10.0,{"sourceId":"orbit","school":"비전","damageKind":"direct","depth":0,"attackId":1}),12.5), "circular saw raises orbit sword damage by 25 percent")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["aegis"]
 sim.state.player.shield = 1
 sim.hurt_player(1.0,{"sourceId":"test"})
 sim._advance_player(14.9,Vector2.ZERO)
 check(sim.state.player.hp == 6.0 and sim.state.player.shield == 0, "aegis blocks a hit and remains unavailable before recharge")
 sim._advance_player(0.2,Vector2.ZERO)
 check(sim.state.player.shield == 1, "aegis recharges after fifteen seconds")
 # Event and timer artifacts, with visible state or damage consequences.
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a046"]
 sim.state.player.hp = 3.0
 sim.state.healBudget = 2.0
 check(is_equal_approx(sim.heal(1.0,"m14"),1.12), "suture needle boosts healing at half health")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a054"]
 sim.state.player.hp = 5.0
 sim.state.healBudget = 1.0
 enemy = target()
 enemy.x = 0.0
 sim.state.enemies = [enemy]
 sim.heal(0.2,"m14")
 var after_wave: float = enemy.hp
 sim.heal(0.2,"m14")
 check(is_equal_approx(after_wave,199.7) and is_equal_approx(enemy.hp,after_wave), "life ring produces 30D healing wave at most once per second")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a057"]
 sim.state.gems = [{"x":300.0,"y":0.0,"value":1.0,"radius":6.0}]
 sim.artifact_rules.tick(sim,19.9)
 check(is_equal_approx(sim.state.gems[0].x,300.0), "return magnet waits twenty seconds")
 sim.artifact_rules.tick(sim,0.2)
 check(sim.state.gems[0].x < 300.0, "return magnet moves an eligible distant gem closer")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a061"]
 sim.state.player.hp = 2.0
 check(is_equal_approx(float(sim.modifiers({}).cooldown_mult),0.9), "broken hourglass shortens cooldown at two health")
 sim.state.player.hp = 3.0
 check(is_equal_approx(float(sim.modifiers({}).cooldown_mult),1.0), "broken hourglass turns off after healing")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a062"]
 sim.hurt_player(1.0,{"sourceId":"contact"})
 check(is_equal_approx(float(sim.modifiers({"damageKind":"incoming","projectile":true}).incoming_mult),0.65), "silver thread armor reduces projectiles after hit")
 sim.artifact_rules.tick(sim,1.0)
 check(is_equal_approx(float(sim.modifiers({"damageKind":"incoming","projectile":true}).incoming_mult),1.0), "silver thread armor expires after one second")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a063"]
 sim.state.spells.m24 = 1
 sim.hurt_player(6.0,{"sourceId":"test"})
 check(is_equal_approx(float(sim.modifiers({"damageKind":"movement"}).move_speed_mult),1.25), "return sign grants movement speed after return amulet")
 sim.artifact_rules.tick(sim,2.0)
 check(is_equal_approx(float(sim.modifiers({"damageKind":"movement"}).move_speed_mult),1.0), "return sign expires after two seconds")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a064"]
 sim.state.player.hp = 5.0
 sim.state.healBudget = 1.0
 sim.heal(0.2,"m14")
 check(is_equal_approx(float(sim.modifiers({"damageKind":"incoming"}).incoming_mult),0.9), "hemostatic seal reduces damage after healing")
 sim.artifact_rules.tick(sim,2.0)
 check(is_equal_approx(float(sim.modifiers({"damageKind":"incoming"}).incoming_mult),1.0), "hemostatic seal expires after two seconds")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a065"]
 enemy = target()
 enemy.x = 10.0
 second = target()
 second.id = 8
 second.x = 30.0
 sim.state.enemies = [enemy,second]
 cap_combat.lightning(sim,enemy,1,sim.context("lightning"))
 check(sim.state.combatLog.any(func(e): return e.get("sourceId", "") == "a065" and e.get("targetId", -1) == 8 and is_equal_approx(float(e.get("damage",0.0)),0.5)), "overcharge orb adds 50D to final maximum-chain target")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a070"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"slow",0.1,0.25)
 cap_combat.advance_effects(sim,0.11)
 check(is_equal_approx(enemy.hp,199.8), "lingering snow deals 20D when slow expires")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a075"]
 sim.state.fusions = ["plasma","blizzard"]
 enemy = target()
 sim.state.enemies = [enemy]
 var bound_two: float = sim.apply_damage(enemy,10.0,{"sourceId":"bolt","school":"비전","damageKind":"direct","depth":0,"attackId":1})
 sim.state.fusions.append("supernova")
 var bound_three: float = sim.apply_damage(enemy,10.0,{"sourceId":"bolt","school":"비전","damageKind":"direct","depth":0,"attackId":2})
 check(is_equal_approx(bound_two,9.72) and is_equal_approx(bound_three,9.72), "binding ring adds eight percent once with two or three fusions")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a076"]
 enemy = target()
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"vulnerable",3.0,1.0)
 sim.apply_damage(enemy,1.0,{"sourceId":"bolt","school":"비전","damageKind":"direct","depth":0,"attackId":1})
 check(is_equal_approx(sim.status_time(enemy,"vulnerable"),3.3), "vulnerability whip extends arcane-hit vulnerability by 0.3 seconds")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a078"]
 sim.state.player.hp = 5.0
 sim.state.healBudget = 1.0
 cap_combat.field(sim,"veil",Vector2.ZERO,100.0,2.0,{"sourceId":"m21","context":sim.context("m21")})
 enemy = target()
 enemy.hp = 1.0
 sim.state.enemies = [enemy]
 sim.apply_damage(enemy,5.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1})
 check(is_equal_approx(sim.state.player.hp,5.1), "shadow vial heals after a non-summon kill in veil")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a079"]
 sim.state.enemyProjectiles = [{"id":1,"x":5.0,"y":0.0,"vx":10.0,"vy":0.0,"beam":false,"deflected":false}]
 check(cap_combat.deflect(sim,Vector2.ZERO,100.0,0.2) == 1, "grounding gloves receive a real projectile deflection")
 enemy = target()
 sim.state.enemies = [enemy]
 var storm_buff: float = sim.apply_damage(enemy,10.0,{"sourceId":"m11","school":"폭풍","damageKind":"direct","depth":0,"attackId":1})
 var storm_next: float = sim.apply_damage(enemy,10.0,{"sourceId":"m11","school":"폭풍","damageKind":"direct","depth":0,"attackId":2})
 check(is_equal_approx(storm_buff,11.8) and is_equal_approx(storm_next,10.0), "grounding gloves buff only the next storm damage")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a085"]
 sim.state.player.hp = 3.0
 enemy = target()
 sim.state.enemies = [enemy]
 var low_shadow: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1})
 sim.state.player.hp = 4.0
 var healed_shadow: float = sim.apply_damage(enemy,10.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":2})
 check(is_equal_approx(low_shadow,13.5) and is_equal_approx(healed_shadow,10.0), "shadow contract toggles at three health")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a086"]
 sim.state.spells.m14 = 1
 sim.state.player.hp = 5.0
 sim.state.healBudget = 1.0
 sim.spawn_seed(Vector2.ZERO,false)
 sim.collect_seed(sim.state.seeds[0])
 check(sim.state.fields.any(func(e): return e.kind == "heal" and is_equal_approx(e.life,1.0)), "life bloom creates a one-second healing field after seed collection")
 sim = fresh()
 sim.start()
 sim.state.artifacts = ["a095"]
 enemy = target()
 enemy.hp = 1.0
 sim.state.enemies = [enemy]
 sim.apply_status(enemy,"vulnerable",3.0,1.0)
 sim.apply_damage(enemy,5.0,{"sourceId":"m13","school":"그림자","damageKind":"direct","depth":0,"attackId":1})
 check(is_equal_approx(float(sim.modifiers({"sourceId":"m21"}).radius_mult),1.25), "night heart expands veil after vulnerable kill")
 sim.artifact_rules.tick(sim,3.0)
 check(is_equal_approx(float(sim.modifiers({"sourceId":"m21"}).radius_mult),1.0), "night heart veil bonus expires after three seconds")
 # Each advertised artifact must pass the real offer/selection path once and reject duplicates.
 var acquisition_catalog = fresh().catalog.artifacts
 # Independent GDD prerequisite fixtures: only the named spell and starting bolt are learned.
 var acquisition_spell := {
  "battery":"lightning", "ruby":"fireball", "circularsawblade":"orbit",
  "a016":"m13", "a017":"bolt", "a018":"vortex", "a019":"fireball", "a020":"frost", "a021":"m15", "a022":"m14",
  "a025":"frost", "a027":"fireball", "a033":"m15", "a035":"meteor", "a037":"fireball", "a038":"lightning", "a039":"m13",
  "a042":"m16", "a043":"orbit", "a044":"lightning", "a045":"m18", "a047":"m13", "a048":"pulse", "a049":"lightning",
  "a050":"fireball", "a051":"frost", "a052":"m12", "a053":"m13", "a055":"m15", "a056":"bolt", "a060":"vortex",
  "a063":"m24", "a065":"lightning", "a066":"m14", "a067":"meteor", "a068":"orbit", "a069":"m13", "a070":"frost",
  "a071":"lightning", "a074":"meteor", "a076":"bolt", "a077":"fireball", "a078":"m21", "a079":"m20", "a081":"fireball",
  "a082":"frost", "a083":"lightning", "a084":"m12", "a085":"m13", "a086":"m14", "a087":"m15", "a088":"bolt",
  "a090":"meteor", "a093":"orbit", "a095":"m21"
 }
 for catalog_item in acquisition_catalog:
  var acquisition_sim = fresh()
  acquisition_sim.start()
  if acquisition_spell.has(catalog_item.id): acquisition_sim.state.spells[acquisition_spell[catalog_item.id]] = 1
  if catalog_item.id == "a075":
   for material in ["bolt", "lightning", "frost", "vortex"]: acquisition_sim.state.spells[material] = 3
   acquisition_sim.state.fusions = ["plasma", "blizzard"]
  # Controlled pool exhaustion forces this candidate through actual offer generation.
  for other_item in acquisition_catalog:
   if other_item.id != catalog_item.id: acquisition_sim.state.artifacts.append(other_item.id)
  acquisition_sim._offer_artifact()
  var was_offered: bool = acquisition_sim.state.artifactChoices.size() == 1 and acquisition_sim.state.artifactChoices[0].id == catalog_item.id
  var acquired: bool = acquisition_sim.choose_artifact(catalog_item.id)
  acquisition_sim.state.phase = "artifact"
  acquisition_sim.state.artifactChoices = [catalog_item]
  var repeated: bool = acquisition_sim.choose_artifact(catalog_item.id)
  check(was_offered and acquired and not repeated and acquisition_sim.state.artifacts.count(catalog_item.id) == 1, "real unique acquisition " + str(catalog_item.canonicalId))
 # Controlled eligibility search: trim a maximal C01 spell fixture down to a valid six-slot kit.
 var maximum_witness_spells := 0
 var largest_witness := ""
 for catalog_item in acquisition_catalog:
  var witness = fresh()
  witness.start()
  for spell_id in witness.state.spells: witness.state.spells[spell_id] = 5
  var retained_materials := ["bolt"]
  if catalog_item.id == "a075":
   witness.state.fusions = ["plasma", "blizzard"]
   retained_materials = ["bolt", "lightning", "frost", "vortex"]
  var starts_eligible: bool = witness.artifact_rules.eligible(witness.state,catalog_item.id)
  for spell_id in witness.state.spells:
   if retained_materials.has(spell_id): continue
   var old_level: int = witness.state.spells[spell_id]
   witness.state.spells[spell_id] = 0
   if not witness.artifact_rules.eligible(witness.state,catalog_item.id): witness.state.spells[spell_id] = old_level
  var positive_count := 0
  var legal_levels := true
  for spell_id in witness.state.spells:
   var level: int = witness.state.spells[spell_id]
   if level > 0: positive_count += 1
   if not witness.catalog.spellIds.has(spell_id) or level < 0 or level > 5: legal_levels = false
  if positive_count > maximum_witness_spells:
   maximum_witness_spells = positive_count
   largest_witness = catalog_item.canonicalId
  check(starts_eligible and witness.artifact_rules.eligible(witness.state,catalog_item.id) and positive_count <= 6 and legal_levels and witness.state.spells.bolt > 0, "six-slot eligibility witness " + str(catalog_item.canonicalId))
 print("Artifact witness: max %d learned spells (%s); controlled eligibility search" % [maximum_witness_spells, largest_witness])
 print("Artifact integration: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
