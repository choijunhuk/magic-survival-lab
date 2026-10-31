extends SceneTree
const Rules = preload("res://scripts/artifact_rules.gd")
var checks := 0
var failures := 0
class Stub:
 var state := {"artifacts":[], "spells":{}, "fusions":[], "player":{"hp":6.0,"maxHp":6.0}, "artifactRuntime":{}, "enemies":[{"id":7,"hp":100.0}]}
 var damage_calls: Array = []
 var heal_calls: Array = []
 var scheduled: Array = []
 func schedule_artifact_effect(delay: float, kind: String, data: Dictionary) -> void:
  scheduled.append({"delay":delay,"kind":kind,"data":data})
 func _enemy_index(id: int) -> int:
  return 0 if id == 7 else -1
 func apply_damage(target: Dictionary, amount: float, context: Dictionary) -> void:
  damage_calls.append({"target":target,"amount":amount,"context":context})
 func heal(amount: float, source: String) -> float:
  heal_calls.append({"amount":amount,"source":source})
  return amount
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 var sim := Stub.new()
 check(not Rules.eligible(sim.state, "a999") and not Rules.eligible(sim.state, "bogus"), "invalid artifacts rejected")
 check(not Rules.eligible(sim.state, "ruby"), "ruby requires fireball or meteor")
 sim.state.spells.fireball = 1
 check(Rules.eligible(sim.state, "A008"), "ruby canonical ID resolves to learned fire spell")
 check(not Rules.eligible(sim.state, "a016"), "shadow item requires shadow spell")
 sim.state.spells.m13 = 1
 check(Rules.eligible(sim.state, "a016"), "shadow item available when learned")
 sim.state.artifacts = ["a016", "a025", "a051", "a091", "a096"]
 check(not Rules.eligible(sim.state, "a016"), "owned item excluded")
 check(is_equal_approx(Rules.modifiers(sim.state,{"school":"shadow","damageKind":"direct"}).damage_add,0.12), "shadow direct bonus")
 check(is_zero_approx(Rules.modifiers(sim.state,{"school":"shadow","damageKind":"dot"}).damage_add), "shadow dot excluded")
 check(is_equal_approx(Rules.modifiers(sim.state,{"school":"cold","damageKind":"direct","moving":true,"slowed":true,"targetKind":"boss"}).damage_add,0.17), "cold conditional boss adjustment")
 var defense := Rules.modifiers(sim.state,{"damageKind":"incoming","damage":6.0})
 check(defense.save_hp == 1.0 and defense.defense_source == "a091", "fatal save precedes leaf")
 check(sim.state.artifactRuntime.is_empty(), "modifier is pure")
 check(Rules.modifiers(sim.state,{"damageKind":"incoming","damage":6.0,"m24Available":true}).defense_source == "a096", "m24 precedes fatal save")
 Rules.on_event(sim,{"kind":"defense_used","sourceId":"a091"})
 check(Rules.modifiers(sim.state,{"damageKind":"incoming","damage":1.0,"aegisAvailable":true}).defense_source == "", "aegis precedes leaf")
 check(Rules.modifiers(sim.state,{"damageKind":"incoming","damage":1.0}).incoming_flat_reduction == 1.0, "leaf negates one point at full health")
 Rules.on_event(sim,{"kind":"defense_used","sourceId":"a096"})
 check(Rules.modifiers(sim.state,{"damageKind":"incoming","damage":1.0}).incoming_flat_reduction == 0.0, "leaf recharge")
 Rules.tick(sim,20.0)
 check(Rules.modifiers(sim.state,{"damageKind":"incoming","damage":1.0}).incoming_flat_reduction == 1.0, "leaf recharges")
 sim.state.artifacts = ["a053", "a092"]
 Rules.on_event(sim,{"kind":"kill","vulnerable":true,"depth":1})
 check(not sim.state.artifactRuntime.get("a053",false), "derived kill cannot proc")
 Rules.on_event(sim,{"kind":"kill","vulnerable":true,"depth":0})
 check(Rules.modifiers(sim.state,{"sourceId":"m13","damageKind":"direct"}).damage_add == 0.2, "vulnerable kill arms dagger")
 Rules.on_event(sim,{"kind":"hit","sourceId":"m13","depth":0})
 check(not sim.state.artifactRuntime.a053, "dagger consumes charge")
 sim.state.artifacts = ["a018", "a020", "a024", "a080"]
 sim.state.moving = true
 Rules.tick(sim,3.0)
 var cold := Rules.modifiers(sim.state,{"school":"cold","sourceId":"m12","groundEffect":true})
 check(is_equal_approx(cold.duration_add,0.5) and is_equal_approx(cold.radius_mult,1.1) and is_equal_approx(cold.hit_interval_add,-0.05), "spell-specific flat and radius effects")
 check(is_equal_approx(cold.cooldown_mult,1.0/1.1), "three seconds moving enables haste")
 sim.state.moving = false
 Rules.tick(sim,0.1)
 check(is_equal_approx(Rules.modifiers(sim.state,{}).cooldown_mult,1.0), "stopping clears moving haste")
 check(not Rules.eligible(sim.state,"a074"), "refined lens requires meteor")
 sim.state.spells.meteor = 1
 check(Rules.eligible(sim.state,"a074"), "refined lens eligible with meteor")
 sim.state.artifacts = ["a074"]
 check(is_zero_approx(Rules.modifiers(sim.state,{"damageKind":"direct","firstHit":true,"highHpPriority":true}).damage_add), "lens does not infer highest HP policy")
 check(is_equal_approx(Rules.modifiers(sim.state,{"damageKind":"direct","firstHit":true,"highHpPriority":true,"targetingPolicy":"highest_hp"}).damage_add,0.15), "lens boosts prioritized first hit")
 sim.state.artifacts = []
 sim.state.fusions = ["f01"]
 check(not Rules.eligible(sim.state,"a075"), "fusion bond requires two fusions")
 sim.state.fusions.append("f02")
 check(Rules.eligible(sim.state,"a075"), "fusion bond becomes eligible with two fusions")
 sim.state.player.hp = 2.0
 sim.state.artifacts = ["a015"]
 Rules.on_acquire(sim,"a015")
 Rules.on_acquire(sim,"a015")
 Rules.tick(sim,0.1)
 check(sim.heal_calls.size() == 1 and sim.state.artifactRuntime.a015Used, "emergency water triggers once on acquisition")
 Rules.tick(sim,0.1)
 check(sim.heal_calls.size() == 1, "emergency water cannot trigger twice")
 sim.state.player.hp = 6.0
 sim.state.artifacts = ["a068"]
 check(Rules.modifiers(sim.state,{"sourceId":"orbit","projectileCount":7}).count_add == 1, "orbit gains a sword below cap")
 check(Rules.modifiers(sim.state,{"sourceId":"orbit","projectileCount":8}).count_add == 0, "orbit cannot exceed eight")
 sim.heal_calls.clear()
 sim.state.artifacts = ["a049", "a014"]
 Rules.on_event(sim,{"kind":"hit","targetId":7,"shockedConsumed":true,"depth":0})
 check(sim.damage_calls.size() == 1 and sim.damage_calls[0].amount == 0.3 and sim.damage_calls[0].context.depth == 1, "shock consumption deals derived damage")
 Rules.on_event(sim,{"kind":"hit","targetId":7,"shockedConsumed":true,"depth":1})
 check(sim.damage_calls.size() == 1, "derived hit cannot trigger coil")
 for i in range(29): Rules.on_event(sim,{"kind":"kill","targetKind":"normal","depth":0})
 Rules.on_event(sim,{"kind":"kill","targetKind":"normal","depth":1})
 check(sim.heal_calls.size() == 1 and sim.heal_calls[0].amount == 0.2, "derived kill counts toward thirty nonboss kills without damage proc")
 sim.state.artifacts = ["a067"]
 var impact := {"kind":"explosion","targetId":7,"depth":0,"attackId":123,"meteorImpact":true,"artifactEffectRadius":30.0,"artifactEffectDamage":10.0}
 Rules.on_event(sim,impact)
 Rules.on_event(sim,impact)
 check(sim.scheduled.size() == 1 and sim.scheduled[0].delay == 0.5 and sim.scheduled[0].data.context.depth == 1, "meteor impact schedules one derived aftershock")
 Rules.on_acquire(sim,"a053")
 Rules.on_acquire(sim,"a053")
 check(sim.state.artifactRuntime.has("acquired_a053"), "acquisition idempotent")
 # Independent GDD values for static and conditional modifier families.
 var manifest := [
  ["a013",{},"pickup_radius_add",40.0],
  ["a016",{"school":"그림자","damageKind":"direct"},"damage_add",0.12],
  ["a017",{"school":"비전"},"projectile_speed_mult",1.18],
  ["a018",{"sourceId":"m12"},"duration_add",0.5],
  ["a019",{"status":"ignite"},"duration_add",1.0],
  ["a020",{"school":"냉기"},"radius_mult",1.10],
  ["a021",{"sourceId":"m15"},"duration_add",0.5],
  ["a022",{"healingSchool":"생명"},"heal_mult",1.10],
  ["a023",{"damageKind":"incoming","direct":true},"incoming_mult",0.92],
  ["a024",{"groundEffect":true},"hit_interval_add",-0.05],
  ["a025",{"school":"냉기","moving":true},"damage_add",0.08],
  ["a026",{"rangedSearch":true},"range_add",40.0],
  ["a027",{"fireExplosion":true},"radius_mult",1.08],
  ["a028",{"damageKind":"direct","firstHit":true},"damage_add",0.12],
  ["a030",{"status":"mark"},"duration_add",1.0],
  ["a031",{"chestIndicator":true},"marker_range_add",80.0],
  ["a032",{"eliteWarning":true},"warning_advance",1.0],
  ["a033",{"sourceId":"m15"},"radius_mult",1.08],
  ["a035",{"sourceId":"meteor","telegraph":true},"radius_mult",1.10],
  ["a036",{},"event_warning_advance",2.0],
  ["a038",{"shockConsumption":true},"shock_bonus_mult",1.10],
  ["a039",{"status":"vulnerable"},"duration_add",0.5],
  ["a040",{"projectileNearby":true},"move_speed_mult",1.08],
  ["a042",{"sourceId":"m16"},"duration_add",2.0],
  ["a043",{"sourceId":"orbit","swordContact":true},"radius_mult",1.08],
  ["a044",{"sourceId":"lightning"},"first_jump_mult",1.10],
  ["a045",{"sourceId":"m18"},"wall_length_mult",1.15],
  ["a047",{"sourceId":"m13","targetSearch":true},"range_mult",1.20],
  ["a048",{"sourceId":"pulse"},"radius_mult",1.10],
  ["a051",{"school":"냉기","slowed":true,"targetKind":"boss"},"damage_add",0.09],
  ["a056",{"school":"비전","pierces":3},"damage_add",0.36],
  ["a058",{"damageKind":"incoming","eliteNearby":true},"incoming_mult",0.85],
  ["a066",{"seedAge":6.0},"heal_mult",1.30],
  ["a073",{"eventIndicator":true},"marker_range_add",200.0],
  ["a077",{"school":"화염"},"damage_add",0.15]
 ]
 var fixture := Stub.new()
 for row in manifest:
  fixture.state.artifacts = [row[0]]
  var observed: Dictionary = Rules.modifiers(fixture.state,row[1])
  check(is_equal_approx(float(observed[row[2]]),float(row[3])),"GDD modifier " + str(row[0]))
 var negatives := [
  ["a016",{"school":"그림자","damageKind":"dot"},"damage_add",0.0],
  ["a017",{"school":"화염"},"projectile_speed_mult",1.0],
  ["a018",{"sourceId":"meteor"},"duration_add",0.0],
  ["a019",{"status":"slow"},"duration_add",0.0],
  ["a020",{"school":"화염"},"radius_mult",1.0],
  ["a023",{"damageKind":"incoming","direct":false},"incoming_mult",1.0],
  ["a024",{"groundEffect":false},"hit_interval_add",0.0],
  ["a025",{"school":"냉기","moving":false},"damage_add",0.0],
  ["a027",{"fireExplosion":false},"radius_mult",1.0],
  ["a028",{"damageKind":"direct","firstHit":false},"damage_add",0.0],
  ["a035",{"sourceId":"meteor","telegraph":false},"radius_mult",1.0],
  ["a038",{"shockConsumption":false},"shock_bonus_mult",1.0],
  ["a043",{"sourceId":"orbit","swordContact":false},"radius_mult",1.0],
  ["a051",{"school":"냉기","slowed":false},"damage_add",0.0],
  ["a058",{"damageKind":"incoming","eliteNearby":false},"incoming_mult",1.0],
  ["a066",{"seedAge":5.99},"heal_mult",1.0],
  ["a073",{"eventIndicator":false},"marker_range_add",0.0]
 ]
 for row in negatives:
  fixture.state.artifacts = [row[0]]
  var observed: Dictionary = Rules.modifiers(fixture.state,row[1])
  check(is_equal_approx(float(observed[row[2]]),float(row[3])),"GDD negative boundary " + str(row[0]))
 fixture.state.artifacts = ["a089"]
 check(is_equal_approx(float(Rules.modifiers(fixture.state,{"inTelegraph":true}).move_speed_mult),1.3), "horizon shoes boost movement inside warning")
 Rules.on_event(fixture,{"kind":"player_hit","depth":0})
 check(is_equal_approx(float(Rules.modifiers(fixture.state,{"inTelegraph":true}).move_speed_mult),1.0), "horizon shoes disable after hit")
 Rules.tick(fixture,3.0)
 check(is_equal_approx(float(Rules.modifiers(fixture.state,{"inTelegraph":true}).move_speed_mult),1.3), "horizon shoes reactivate after three seconds")
 print("Artifact rules: %d checks, %d failures" % [checks, failures])
 quit(1 if failures else 0)
