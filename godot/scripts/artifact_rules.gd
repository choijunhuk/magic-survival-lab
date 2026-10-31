extends RefCounted
## Campaign artifact rules. Legacy A001-A012 remain owned by CampaignRules.

const LEGACY := ["magicwand", "blackcat", "broom", "secondheart", "worldtreeleaf", "radar", "battery", "ruby", "snowflakecrown", "circularsawblade", "sapphire", "aegis"]

const CONDITIONS := {
 "battery":["lightning"], "ruby":["fireball","meteor"], "circularsawblade":["orbit"],
 "a016":["m13","m21"], "a017":["bolt","orbit","pulse","m16"],
 "a018":["vortex","m12"], "a019":["fireball","meteor","m09","m17"],
 "a020":["frost","m10","m18"], "a021":["m15"], "a022":["m14","m22"],
 "a025":["frost","m10","m18"], "a027":["fireball","meteor"],
 "a033":["m15"], "a035":["meteor"], "a037":["fireball","meteor","m09","m17"],
 "a038":["lightning","m11","m19"], "a039":["m13","m21"],
 "a042":["m16"], "a043":["orbit"], "a044":["lightning"], "a045":["m18"],
 "a047":["m13"], "a048":["pulse"], "a049":["lightning","m11","m19"],
 "a050":["fireball","meteor","m09","m17"], "a051":["frost","m10","m18"],
 "a052":["m12"], "a053":["m13"], "a055":["m15"], "a056":["bolt","m16"],
 "a060":["vortex","m12","m15"], "a063":["m24"], "a065":["lightning"],
 "a066":["m14"], "a067":["meteor"], "a068":["orbit"], "a069":["m13"],
 "a070":["frost","m10","m18"], "a071":["lightning","m11","m19"],
 "a075":["bolt","orbit","lightning","frost","fireball","vortex","meteor","pulse","m09","m10","m11","m12","m13","m14","m15","m16","m17","m18","m19","m20","m21","m22","m23","m24"],
 "a074":["meteor"], "a076":["bolt","orbit","pulse","m16"], "a077":["fireball","meteor","m09","m17"],
 "a078":["m21"], "a079":["m20"], "a081":["fireball","meteor"],
 "a082":["frost","m10","m18"], "a083":["lightning"], "a084":["m12"],
 "a085":["m13","m21"], "a086":["m14"], "a087":["m15"],
 "a088":["bolt","orbit","pulse","m16"], "a090":["meteor"], "a093":["orbit"],
 "a095":["m21"]
}

static func eligible(state: Dictionary, artifact_id: String) -> bool:
 var id := artifact_id.to_lower()
 if id.begins_with("a") and id.length() == 4 and id.substr(1).is_valid_int():
  var number := int(id.substr(1))
  if number < 1 or number > 96: return false
  if number <= 12: id = LEGACY[number - 1]
 elif not LEGACY.has(id): return false
 var items: Array = state.get("artifacts", [])
 if items.has(id) or items.has(artifact_id) or items.has(artifact_id.to_upper()): return false
 if id == "a075" and state.get("fusions", []).size() < 2: return false
 if not CONDITIONS.has(id): return true
 var spells: Dictionary = state.get("spells", {})
 for spell in CONDITIONS[id]:
  if int(spells.get(spell, 0)) > 0: return true
 return false

static func modifiers(state: Dictionary, context: Dictionary) -> Dictionary:
 var out := {"damage_add":0.0,"damage_mult":1.0,"cooldown_mult":1.0,"radius_mult":1.0,"duration_mult":1.0,"projectile_speed_mult":1.0,"move_speed_mult":1.0,"pickup_radius_mult":1.0,"xp_mult":1.0,"pierce_add":0,"count_add":0,"incoming_mult":1.0,"incoming_flat_reduction":0.0,"block":false,"save_hp":null,"defense_source":""}
 out.merge({"pickup_radius_add":0.0,"duration_add":0.0,"range_add":0.0,"range_mult":1.0,"hit_interval_add":0.0,"heal_mult":1.0,"marker_range_add":0.0,"warning_advance":0.0,"event_warning_advance":0.0,"first_jump_mult":1.0,"wall_length_mult":1.0,"shock_bonus_mult":1.0,"veil_outline":false,"reroll_available":false})
 var a: Array = state.get("artifacts", [])
 var rt: Dictionary = state.get("artifactRuntime", {})
 var p: Dictionary = state.get("player", {})
 var hp := float(p.get("hp", 0.0))
 var source := str(context.get("sourceId", ""))
 var school := str(context.get("school", ""))
 var kind := str(context.get("damageKind", ""))
 var target := str(context.get("targetKind", ""))
 if a.has("a041"): out.veil_outline = true
 if a.has("a072") and not rt.get("a072Used", false): out.reroll_available = true
 if a.has("a013"): out.pickup_radius_add += 40.0
 if a.has("a018") and source in ["vortex", "m12"]: out.duration_add += 0.5
 if a.has("a019") and context.get("status", "") == "ignite": out.duration_add += 1.0
 if a.has("a021") and source == "m15": out.duration_add += 0.5
 if a.has("a022") and context.get("healingSchool", "") in ["life", "생명"]: out.heal_mult *= 1.1
 if a.has("a024") and context.get("groundEffect", false): out.hit_interval_add -= 0.05
 if a.has("a026") and context.get("rangedSearch", false): out.range_add += 40.0
 if a.has("a030") and context.get("status", "") == "mark": out.duration_add += 1.0
 if a.has("a031") and context.get("chestIndicator", false): out.marker_range_add += 80.0
 if a.has("a032") and context.get("eliteWarning", false): out.warning_advance += 1.0
 if a.has("a035") and source == "meteor" and context.get("telegraph", false): out.radius_mult *= 1.1
 if a.has("a036"): out.event_warning_advance += 2.0
 if a.has("a037") and kind == "direct" and context.get("ignited", false) and float(rt.get("a037_" + str(context.get("targetId", "")), 0.0)) <= 0: out.damage_add += 0.1
 if a.has("a038") and context.get("shockConsumption", false): out.shock_bonus_mult *= 1.10
 if a.has("a039") and context.get("status", "") == "vulnerable": out.duration_add += 0.5
 if a.has("a042") and source == "m16": out.duration_add += 2.0
 if a.has("a044") and source == "lightning": out.first_jump_mult *= 1.1
 if a.has("a045") and source == "m18": out.wall_length_mult *= 1.15
 if a.has("a046") and hp <= float(p.get("maxHp", 0.0)) * 0.5: out.heal_mult *= 1.12
 if a.has("a047") and source == "m13" and context.get("targetSearch", false): out.range_mult *= 1.2
 if a.has("a066") and context.get("seedAge", 0.0) >= 6.0: out.heal_mult *= 1.3
 if a.has("a069") and source == "m13" and context.get("targetSearch", false) and rt.get("a069", false): out.range_mult *= 1.3
 if a.has("a073") and context.get("eventIndicator", false): out.marker_range_add += 200.0
 if a.has("a016") and school in ["shadow", "그림자"] and kind == "direct": out.damage_add += 0.12
 if a.has("a017") and school in ["arcane", "비전"]: out.projectile_speed_mult *= 1.18
 if a.has("a020") and school in ["cold", "냉기"]: out.radius_mult *= 1.10
 if a.has("a023") and kind == "incoming" and context.get("direct", false): out.incoming_mult *= 0.92
 if a.has("a025") and school in ["cold", "냉기"] and context.get("moving", false): out.damage_add += 0.08
 if a.has("a027") and context.get("fireExplosion", false): out.radius_mult *= 1.08
 if a.has("a028") and kind == "direct" and context.get("firstHit", false): out.damage_add += 0.12
 if a.has("a029") and float(rt.get("a029", 0.0)) > 0: out.move_speed_mult *= 1.15
 if a.has("a033") and source == "m15": out.radius_mult *= 1.08
 if a.has("a040") and context.get("projectileNearby", false): out.move_speed_mult *= 1.08
 if a.has("a043") and source == "orbit" and context.get("swordContact", false): out.radius_mult *= 1.08
 if a.has("a048") and source == "pulse": out.radius_mult *= 1.10
 if a.has("a051") and school in ["cold", "냉기"] and context.get("slowed", false): out.damage_add += 0.09 if target == "boss" else 0.18
 if a.has("a053") and source == "m13" and rt.get("a053", false): out.damage_add += 0.20
 if a.has("a055") and source == "m15" and rt.get("a055", false): out.cooldown_mult *= 0.8
 if a.has("a056") and school in ["arcane", "비전"]: out.damage_add += 0.12 * mini(3, int(context.get("pierces", 0)))
 if a.has("a058") and kind == "incoming" and context.get("eliteNearby", false): out.incoming_mult *= 0.85
 if a.has("a059") and kind == "direct" and ((rt.has("a059AttackId") and rt.a059AttackId == context.get("attackId")) or (not rt.has("a059AttackId") and float(rt.get("a059", 0.0)) > 0)): out.damage_add += 0.20
 if a.has("a061") and hp <= 2.0: out.cooldown_mult *= 0.9
 if a.has("a062") and kind == "incoming" and context.get("projectile", false) and float(rt.get("a062", 0.0)) > 0: out.incoming_mult *= 0.65
 if a.has("a063") and float(rt.get("a063", 0.0)) > 0: out.move_speed_mult *= 1.25
 if a.has("a064") and kind == "incoming" and float(rt.get("a064", 0.0)) > 0: out.incoming_mult *= 0.9
 if a.has("a068") and source == "orbit" and int(context.get("projectileCount", 0)) < 8: out.count_add += 1
 if a.has("a074") and kind == "direct" and context.get("targetingPolicy", "") == "highest_hp" and context.get("firstHit", false) and context.get("highHpPriority", false): out.damage_add += 0.15
 if a.has("a075") and state.get("fusions", []).size() >= 2 and context.get("fusionMaterial", false): out.damage_add += 0.08
 if a.has("a077") and hp >= 5.0 and school in ["fire", "화염"]: out.damage_add += 0.15
 if a.has("a079") and school in ["storm", "폭풍"] and rt.get("a079", false): out.damage_add += 0.18
 if a.has("a080") and float(rt.get("movingTime", 0.0)) >= 3.0: out.cooldown_mult *= 1.0 / 1.1
 if a.has("a085") and hp <= 3.0 and school in ["shadow", "그림자"]: out.damage_add += 0.35
 if a.has("a089") and context.get("inTelegraph", false) and float(rt.get("a089", 0.0)) <= 0: out.move_speed_mult *= 1.30
 if a.has("a092") and rt.get("a092Ready", false) and kind == "direct" and context.get("attackId") != rt.get("a092ChargeAttackId") and (not rt.has("a092AttackId") or rt.a092AttackId == context.get("attackId")): out.damage_add += 0.40
 if a.has("a095") and source == "m21" and float(rt.get("a095", 0.0)) > 0: out.radius_mult *= 1.25
 out.move_speed_mult = minf(1.6, out.move_speed_mult)
 if kind == "incoming":
  var incoming := float(context.get("damage", 0.0)) * float(out.incoming_mult)
  if context.get("direct", false) and incoming > 0: incoming = maxf(1.0, incoming)
  if a.has("a091") and not rt.get("a091Used", false) and incoming >= hp and hp > 0 and not context.get("m24Available", false):
   out.save_hp = 1.0
   out.defense_source = "a091"
  elif a.has("a096") and not context.get("aegisAvailable", false) and float(rt.get("a096", 0.0)) <= 0 and hp >= float(p.get("maxHp", 0.0)) and incoming > 0:
   out.incoming_flat_reduction = minf(1.0, incoming)
   out.defense_source = "a096"
 return out

static func on_acquire(sim, artifact_id: String) -> void:
 if not sim.state.has("artifactRuntime"): sim.state.artifactRuntime = {}
 var rt: Dictionary = sim.state.artifactRuntime
 var key := "acquired_" + artifact_id.to_lower()
 if rt.has(key): return
 rt[key] = true
 if artifact_id.to_lower() == "a015" and float(sim.state.player.hp) <= 2.0 and float(sim.state.player.hp) > 0:
  rt.a015Used = true
  rt.a015Pending = 1.0

static func on_event(sim, event: Dictionary) -> void:
 if not sim.state.has("artifactRuntime"): sim.state.artifactRuntime = {}
 var rt: Dictionary = sim.state.artifactRuntime
 var a: Array = sim.state.get("artifacts", [])
 var kind := str(event.get("kind", ""))
 if kind == "defense_used":
  if event.get("sourceId", "") == "a091": rt.a091Used = true
  if event.get("sourceId", "") == "a096": rt.a096 = 20.0
 if kind == "player_hit":
  if a.has("a015") and not rt.get("a015Used", false) and float(sim.state.player.hp) <= 2.0 and float(sim.state.player.hp) > 0:
   rt.a015Used = true
   rt.a015Pending = 1.0
  if a.has("a029"): rt.a029 = 2.0
  if a.has("a062"): rt.a062 = 1.0
  if a.has("a089"): rt.a089 = 3.0
 # Derived kills still count as kills; they must not retrigger secondary damage procs.
 if kind == "kill" and a.has("a014") and event.get("targetKind", "") != "boss":
  rt.a014Kills = int(rt.get("a014Kills", 0)) + 1
  if rt.a014Kills >= 30:
   rt.a014Kills = 0
   sim.heal(0.2, "a014")
 if int(event.get("depth", 0)) != 0: return
 var target_id := int(event.get("targetId", -1))
 var enemy_index: int = sim._enemy_index(target_id) if target_id >= 0 else -1
 var target: Dictionary = sim.state.enemies[enemy_index] if enemy_index >= 0 else {}
 var pos: Vector2 = event.get("targetPosition", Vector2.ZERO)
 var derived := {"depth":1,"sourceId":"artifact","school":event.get("school", ""),"damageKind":"derived","attackId":event.get("attackId", 0)}
 if kind == "hit" and a.has("a083") and event.get("chainComplete", false):
  var origin_index: int = sim._enemy_index(int(event.get("chainOriginTargetId", -1)))
  if origin_index >= 0 and event.has("artifactEffectDamage"):
   sim.apply_damage(sim.state.enemies[origin_index],float(event.artifactEffectDamage),derived.merged({"sourceId":"a083"},true))
 if kind == "explosion" and event.has("artifactEffectRadius"):
  var effect_radius := float(event.artifactEffectRadius)
  var effect_damage := float(event.get("artifactEffectDamage", 0.0))
  if a.has("a067") and event.get("meteorImpact", false):
   var impact_key := "a067_" + str(event.get("attackId", ""))
   if not rt.has(impact_key):
    rt[impact_key] = true
    sim.schedule_artifact_effect(0.5,"damage_radius",{"position":pos,"radius":effect_radius,"damage":effect_damage,"context":derived.merged({"sourceId":"a067"},true)})
  if a.has("a090") and event.get("meteorImpact", false):
   var fragment_key := "a090_" + str(event.get("attackId", ""))
   if not rt.has(fragment_key):
    rt[fragment_key] = true
    for fragment in event.get("fragmentPositions", []):
     sim.schedule_artifact_effect(0.5,"damage_radius",{"position":fragment,"radius":effect_radius,"damage":effect_damage,"context":derived.merged({"sourceId":"a090"},true)})
  if a.has("a081") and event.get("fireExplosion", false):
   var split_key := "a081_" + str(event.get("explosionId", event.get("attackId", "")))
   if not rt.has(split_key):
    rt[split_key] = true
    for point in event.get("secondaryPositions", []):
     sim.damage_radius(point,effect_radius,float(event.get("originalDamage", 0.0))*0.4,derived.merged({"sourceId":"a081","noIgnite":true,"precalculatedDamage":true},true))
 if kind == "control" and a.has("a093") and event.get("swordLine", false):
  for line_target in event.get("lineTargetIds", []):
   var line_key := "a093_" + str(event.get("lineId", "default")) + "_" + str(line_target)
   if float(rt.get(line_key,0.0)) > 0: continue
   var line_index: int = sim._enemy_index(int(line_target))
   if line_index >= 0:
    rt[line_key] = 1.0
    sim.apply_damage(sim.state.enemies[line_index],float(event.get("artifactEffectDamage",0.0)),derived.merged({"sourceId":"a093"},true))
 if kind == "kill":
  if a.has("a050") and event.get("ignited", false): sim.damage_radius(pos,55.0,0.4,derived.merged({"sourceId":"a050"},true))
  if a.has("a078") and event.get("inVeil", false) and not event.get("summon", false) and float(rt.get("a078",0.0)) <= 0:
   sim.heal(0.1,"a078")
   rt.a078 = 1.0
 if kind == "seed_collected" and a.has("a086"): sim.spawn_heal_field(pos, 1.0)
 if kind == "hit" and not target.is_empty():
  if a.has("a037") and event.get("ignited", false) and event.get("damageKind", "") == "direct" and float(rt.get("a037_" + str(target_id),0.0)) <= 0: rt["a037_" + str(target_id)] = 3.0
  if a.has("a049") and event.get("shockedConsumed", false): sim.apply_damage(target,0.3,derived.merged({"sourceId":"a049"},true))
  if a.has("a052") and event.get("sourceId", "") == "m12" and event.get("centerHit", false):
   var key := "a052_" + str(event.get("wellId", "")) + "_" + str(target_id)
   if not rt.has(key):
    rt[key] = true
    sim.apply_damage(target,0.6,derived.merged({"sourceId":"a052"},true))
  if a.has("a065") and event.get("maximumChain", false): sim.apply_damage(target,0.5,derived.merged({"sourceId":"a065"},true))
  if a.has("a076") and event.get("vulnerable", false) and event.get("school", "") in ["arcane", "비전"]: sim.extend_status(target_id,"vulnerable",0.3,4.0)
  if a.has("a082") and event.get("school", "") in ["cold", "냉기"] and float(rt.get("a082_"+str(target_id),0.0)) <= 0:
   rt["a082_"+str(target_id)] = 8.0
   sim.apply_status(target,"root",0.6,1.0)
  if a.has("a088") and event.get("firstTarget", false) and event.get("school", "") in ["arcane", "비전"]: sim.apply_status(target,"mark",3.0,1.0)
 if kind == "control":
  if a.has("a034") and event.get("seedSpawned", false) and not event.get("extra", false) and sim.rng.randf() < 0.15: sim.spawn_seed(pos, true)
  if a.has("a054") and event.get("healed", false) and float(rt.get("a054",0.0)) <= 0:
   rt.a054 = 1.0
   sim.damage_radius(event.get("healPosition",pos), 55.0, 0.3, derived.merged({"sourceId":"a054"},true))
 if kind in ["control", "cast"] and a.has("a084") and event.get("gravityWell", false):
  var well_key := "a084_" + str(event.get("wellId", ""))
  var remaining := maxi(0, 8 - int(rt.get(well_key, 0)))
  if remaining > 0: rt[well_key] = int(rt.get(well_key, 0)) + sim.absorb_projectiles(pos, float(event.get("radius", 0.0)), remaining)
 if kind == "control" and not target.is_empty():
  if a.has("a052") and event.get("sourceId", "") == "m12" and event.get("centerHit", false):
   var center_key := "a052_" + str(event.get("wellId", "")) + "_" + str(target_id)
   if not rt.has(center_key):
    rt[center_key] = true
    sim.apply_damage(target,0.6,derived.merged({"sourceId":"a052"},true))
  if a.has("a071") and event.get("shockApplied", false) and sim.status_time(target,"ignite") > 0 and float(rt.get("a071_"+str(target_id),0.0)) <= 0:
   rt["a071_"+str(target_id)] = 2.0
   sim.apply_damage(target,0.3,derived.merged({"sourceId":"a071"},true))
  if a.has("a060") and event.get("exitedGround", false): sim.apply_status(target,"slow",1.0,float(event.get("slowStrength", 0.5)))
  if a.has("a070") and event.get("slowExpired", false) and float(rt.get("a070_"+str(target_id),0.0)) <= 0:
   rt["a070_"+str(target_id)] = 3.0
   sim.apply_damage(target,0.2,derived.merged({"sourceId":"a070"},true))
  if a.has("a087") and event.get("dashInGlyph", false) and event.get("targetKind", "") == "normal" and float(rt.get("a087_"+str(target_id),0.0)) <= 0:
   rt["a087_"+str(target_id)] = 10.0
   sim.cancel_enemy_dash(target_id)
  if a.has("a094") and event.get("eliteCastDelayed", false) and event.get("targetKind", "") == "elite": sim.delay_enemy_cast(target_id,0.8)
 if kind == "kill" and event.get("vulnerable", false):
  if a.has("a053"): rt.a053 = true
  if a.has("a095"): rt.a095 = 3.0
 if kind == "control":
  if a.has("a069") and event.get("daggerExecute", false): rt.a069 = true
  if a.has("a055") and event.get("sealDelayed", false): rt.a055 = true
  if a.has("a059") and event.get("dodged", false):
   rt.a059 = 2.0
   rt.erase("a059AttackId")
  if a.has("a063") and event.get("sourceId", "") == "m24": rt.a063 = 2.0
  if a.has("a079") and event.get("deflected", false): rt.a079 = true
  if a.has("a064") and event.get("healed", false): rt.a064 = 2.0
 if kind == "cast" and event.get("sourceId", "") == "m15": rt.a055 = false
 if kind == "cast" and event.get("sourceId", "") == "m13": rt.a069 = false
 if kind == "hit":
  if event.get("sourceId", "") == "m13": rt.a053 = false
  if event.get("school", "") in ["storm", "폭풍"]: rt.a079 = false
  if event.get("damageKind", "direct") == "direct" and a.has("a059"):
   if not rt.has("a059AttackId") and float(rt.get("a059", 0.0)) > 0: rt.a059AttackId = event.get("attackId")
   elif rt.has("a059AttackId") and rt.a059AttackId != event.get("attackId"):
    rt.a059 = 0.0
    rt.erase("a059AttackId")
  if rt.get("a092Ready", false) and event.get("damageKind", "direct") == "direct":
   if not rt.has("a092AttackId") and event.get("attackId") != rt.get("a092ChargeAttackId"):
    rt.a092AttackId = event.get("attackId")
   elif rt.has("a092AttackId") and rt.a092AttackId != event.get("attackId"):
    rt.a092Ready = false
    rt.a092Schools = []
    rt.a092Window = 0.0
    rt.erase("a092AttackId")
    rt.erase("a092ChargeAttackId")
  elif a.has("a092") and not rt.get("a092Ready", false):
   var school := str(event.get("school", ""))
   if not school.is_empty():
    var schools: Array = rt.get("a092Schools", [])
    if not schools.has(school): schools.append(school)
    rt.a092Schools = schools
    if float(rt.get("a092Window", 0.0)) <= 0: rt.a092Window = 6.0
    if schools.size() >= 3:
     rt.a092Ready = true
     rt.a092ChargeAttackId = event.get("attackId")

static func tick(sim, dt: float) -> void:
 if not sim.state.has("artifactRuntime"): sim.state.artifactRuntime = {}
 var rt: Dictionary = sim.state.artifactRuntime
 if sim.state.get("artifacts", []).has("a015") and not rt.get("a015Used", false) and float(sim.state.player.hp) <= 2.0 and float(sim.state.player.hp) > 0:
  rt.a015Used = true
  rt.a015Pending = 1.0
 if float(rt.get("a015Pending", 0.0)) > 0:
  rt.a015Pending = minf(float(rt.a015Pending), maxf(0.0, float(sim.state.player.maxHp) - float(sim.state.player.hp)))
  rt.a015Pending = maxf(0.0, float(rt.a015Pending) - float(sim.heal(float(rt.a015Pending),"a015")))
 for key in rt.keys():
  if str(key).begins_with("a037_") or str(key).begins_with("a070_") or str(key).begins_with("a071_") or str(key).begins_with("a082_") or str(key).begins_with("a087_") or str(key).begins_with("a093_"):
   rt[key] = maxf(0.0, float(rt[key]) - dt)
 if sim.state.get("artifacts", []).has("a057"):
  rt.a057 = float(rt.get("a057", 20.0)) - dt
  if rt.a057 <= 0:
   sim.pull_gems(0.0)
   rt.a057 += 20.0
 for key in ["a054", "a078", "a029", "a059", "a062", "a063", "a064", "a089", "a095", "a096", "a092Window"]:
  if rt.has(key): rt[key] = maxf(0.0, float(rt[key]) - dt)
 if float(rt.get("a092Window", 0.0)) <= 0 and not rt.get("a092Ready", false): rt.a092Schools = []
 if sim.state.get("moving", false): rt.movingTime = float(rt.get("movingTime", 0.0)) + dt
 else: rt.movingTime = 0.0
