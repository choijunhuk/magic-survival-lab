export const DURATION = 300;
export const SPELL_IDS = ['bolt', 'orbit', 'lightning', 'frost', 'fireball', 'vortex', 'meteor', 'pulse'];

export const UPGRADES = [
  { id: 'bolt', name: '마나 창', description: '자동 투사체의 위력을 높입니다', color: '#80d4d1', icon: 'assets/magicImages/manaSpear.png' },
  { id: 'orbit', name: '염동력 검', description: '주위를 도는 검을 추가합니다', color: '#d9b66f', icon: 'assets/magicImages/telekineticSword.png' },
  { id: 'lightning', name: '번개', description: '가까운 적에게 연쇄 번개를 내립니다', color: '#b5bdff', icon: 'assets/magicImages/heartOfLightning.png' },
  { id: 'frost', name: '냉기', description: '주변 적을 얼리고 피해를 줍니다', color: '#a2d9f4', icon: 'assets/magicImages/snowflakeBlossom.png' },
  { id: 'fireball', name: '화염구', description: '폭발하는 화염구를 발사합니다', color: '#f3a36b', icon: 'assets/magicImages/pyrotechnics.png' },
  { id: 'vortex', name: '소용돌이', description: '적을 둔화시키는 지속 영역을 만듭니다', color: '#9bd0df', icon: 'assets/magicImages/vortex.png' },
  { id: 'meteor', name: '운석', description: '잠시 뒤 넓은 지역에 운석이 떨어집니다', color: '#ed8f70', icon: 'assets/magicImages/greatImpact.png' },
  { id: 'pulse', name: '파동', description: '주위로 퍼지는 마력 파동을 방출합니다', color: '#c0a9eb', icon: 'assets/magicImages/energyBombardment.png' },
  { id: 'power', name: '지능', description: '모든 마법의 피해를 높입니다', color: '#edb878', icon: 'assets/passiveImages/intelligence.png' },
  { id: 'haste', name: '고속 시전', description: '마법을 더 자주 사용합니다', color: '#d6b4e8', icon: 'assets/passiveImages/fastcasting.png' },
  { id: 'vitality', name: '활력', description: '최대 체력과 현재 체력을 높입니다', color: '#d7979c', icon: 'assets/passiveImages/vitality.png' },
  { id: 'magnet', name: '레이더', description: '경험치 수집 범위를 넓힙니다', color: '#a8d59e', icon: 'assets/artifactImages/radar.png' },
];

export const FUSIONS = [
  { id: 'plasma', name: '플라즈마', description: '마나 창이 적을 관통하는 광선이 됩니다', icon: 'assets/magicImages/plasmaRay.png', color: '#92e7f4', requires: { bolt: 3, lightning: 3 }, kind: 'fusion' },
  { id: 'blizzard', name: '눈보라', description: '냉기와 소용돌이의 범위와 둔화를 강화합니다', icon: 'assets/magicImages/winterStorm.png', color: '#b9e9f5', requires: { frost: 3, vortex: 3 }, kind: 'fusion' },
  { id: 'supernova', name: '초신성', description: '화염구와 운석의 폭발이 거대해집니다', icon: 'assets/magicImages/supernova.png', color: '#ffb27f', requires: { fireball: 3, meteor: 3 }, kind: 'fusion' },
  { id: 'hyperion', name: '히페리온', description: '공전 검과 파동의 사거리와 위력을 높입니다', icon: 'assets/magicImages/hyperion.png', color: '#eac782', requires: { orbit: 3, pulse: 3 }, kind: 'fusion' },
];

export const ARTIFACTS = [
  { id: 'magicwand', name: '마법 지팡이', description: '모든 마법 피해 +20%', icon: 'assets/artifactImages/magicwand.png', color: '#e4c483' },
  { id: 'blackcat', name: '검은 고양이', description: '시전 속도 +12%', icon: 'assets/artifactImages/blackcat.png', color: '#aaa3ce' },
  { id: 'broom', name: '빗자루', description: '이동 속도 +15%', icon: 'assets/artifactImages/broom.png', color: '#d7b878' },
  { id: 'secondheart', name: '두 번째 심장', description: '최대 체력 +3, 체력 +3', icon: 'assets/artifactImages/secondheart.png', color: '#e89b9e' },
  { id: 'worldtreeleaf', name: '세계수 잎', description: '초당 체력 0.06 회복', icon: 'assets/artifactImages/worldtreeleaf.png', color: '#a9d39a' },
  { id: 'radar', name: '레이더', description: '경험치 끌어당김 범위 +80', icon: 'assets/artifactImages/radar.png', color: '#a8d59e' },
  { id: 'battery', name: '전지', description: '연쇄 번개 대상 +1', icon: 'assets/artifactImages/battery.png', color: '#b6c6f4' },
  { id: 'ruby', name: '루비', description: '화염구와 운석 피해 +30%', icon: 'assets/artifactImages/ruby.png', color: '#ed9393' },
  { id: 'snowflakecrown', name: '눈꽃 왕관', description: '둔화 지속 시간 증가', icon: 'assets/artifactImages/snowflakecrown.png', color: '#bce8f0' },
  { id: 'circularsawblade', name: '원형 톱날', description: '공전 검 피해 +25%', icon: 'assets/artifactImages/circularsawblade.png', color: '#c7ccd0' },
  { id: 'sapphire', name: '사파이어', description: '획득 경험치 +25%', icon: 'assets/artifactImages/sapphire.png', color: '#89bcf2' },
  { id: 'aegis', name: '이지스', description: '15초마다 피해 1회 방어', icon: 'assets/artifactImages/aegis.png', color: '#e8d6a5' },
];

export function createGame(rng = Math.random) {
  return {
    phase: 'ready', time: 0, kills: 0, level: 1, xp: 0, xpNeeded: 6,
    player: { x: 0, y: 0, hp: 6, maxHp: 6, speed: 220, radius: 15, invulnerable: 0, shield: 0 },
    spells: { bolt: 1, orbit: 0, lightning: 0, frost: 0, fireball: 0, vortex: 0, meteor: 0, pulse: 0 },
    stats: { power: 0, haste: 0, vitality: 0, magnet: 0 },
    fusions: [], artifacts: [], enemies: [], projectiles: [], gems: [], effects: [], choices: [],
    chests: [], artifactChoices: [], zones: [], strikes: [],
    cooldowns: { bolt: 0, lightning: 0, frost: 0, fireball: 0, vortex: 0, meteor: 0, pulse: 0 },
    spawnTimer: 0.8, eliteTimer: 30, nextEnemyId: 1, nextChestId: 1, shieldTimer: 0, rng,
  };
}

export function startGame(state) {
  if (state.phase === 'ready') state.phase = 'playing';
}

export function togglePause(state) {
  if (state.phase === 'playing') state.phase = 'paused';
  else if (state.phase === 'paused') state.phase = 'playing';
}

export function orbitPosition(state, index) {
  const count = Math.min(state.spells.orbit, 8);
  const angle = state.time * 2.4 + index * Math.PI * 2 / Math.max(1, count);
  const radius = state.fusions.includes('hyperion') ? 105 : 72;
  return { x: state.player.x + Math.cos(angle) * radius, y: state.player.y + Math.sin(angle) * radius };
}

const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const damageScale = state => (1 + state.stats.power * .25) * (state.artifacts.includes('magicwand') ? 1.2 : 1);
const hasteScale = state => (1 + state.stats.haste * .12) * (state.artifacts.includes('blackcat') ? 1.12 : 1);

function effect(state, type, x, y, life, extra = {}) {
  state.effects.push({ type, x, y, life, maxLife: life, ...extra });
}

function hurtEnemy(state, enemy, damage) {
  enemy.hp -= damage;
  effect(state, 'hit', enemy.x, enemy.y, .18);
  if (enemy.hp > 0) return;
  state.enemies.splice(state.enemies.indexOf(enemy), 1);
  state.kills++;
  state.gems.push({ x: enemy.x, y: enemy.y, value: enemy.kind === 'elite' ? 4 : 1, radius: 6 });
  if (enemy.kind === 'elite') state.chests.push({ id: state.nextChestId++, x: enemy.x, y: enemy.y });
  effect(state, 'death', enemy.x, enemy.y, .35);
}

function nearestEnemy(state, point, range, excluded = new Set()) {
  let target = null;
  let best = range;
  for (const enemy of state.enemies) {
    if (excluded.has(enemy)) continue;
    const d = distance(point, enemy);
    if (d < best) { target = enemy; best = d; }
  }
  return target;
}

function spawnEnemy(state, elite = false) {
  if (state.enemies.length >= 200) return;
  const angle = state.rng() * Math.PI * 2;
  const radius = 500 + state.rng() * 200;
  const swift = !elite && state.rng() < Math.min(.35, state.time / 750);
  const kind = elite ? 'elite' : swift ? 'swift' : 'normal';
  const hp = (elite ? 30 : swift ? 4 : 3) * (1 + state.time / 180);
  state.enemies.push({
    id: state.nextEnemyId++, x: state.player.x + Math.cos(angle) * radius,
    y: state.player.y + Math.sin(angle) * radius, hp, maxHp: hp,
    radius: elite ? 24 : swift ? 11 : 15, kind,
    speed: (elite ? 52 : swift ? 110 : 66) * (1 + state.time / 600),
    damage: elite ? 2 : 1, slow: 0, orbitHitUntil: 0,
  });
}

function offerUpgrade(state) {
  state.level++;
  state.xp -= state.xpNeeded;
  state.xpNeeded = 6 + (state.level - 1) * 3;
  const available = UPGRADES.filter(upgrade => !SPELL_IDS.includes(upgrade.id) || state.spells[upgrade.id] < 5);
  const fusions = FUSIONS.filter(item => !state.fusions.includes(item.id) && Object.entries(item.requires).every(([id, level]) => state.spells[id] >= level));
  const unlearned = available.filter(upgrade => SPELL_IDS.includes(upgrade.id) && state.spells[upgrade.id] === 0);
  state.choices = [];
  while (fusions.length && state.choices.length < 3 - (unlearned.length ? 1 : 0)) {
    const index = Math.min(fusions.length - 1, Math.floor(state.rng() * fusions.length));
    state.choices.push(fusions.splice(index, 1)[0]);
  }
  if (unlearned.length) {
    const choice = unlearned[Math.min(unlearned.length - 1, Math.floor(state.rng() * unlearned.length))];
    state.choices.push(choice);
    available.splice(available.indexOf(choice), 1);
  }
  while (state.choices.length < 3) {
    const index = Math.min(available.length - 1, Math.floor(state.rng() * available.length));
    state.choices.push(available.splice(index, 1)[0]);
  }
  state.phase = 'upgrade';
}

export function chooseUpgrade(state, id) {
  if (state.phase !== 'upgrade' || !state.choices.some(choice => choice.id === id)) return false;
  const fusion = FUSIONS.find(item => item.id === id);
  if (fusion) {
    if (state.fusions.includes(id) || !Object.entries(fusion.requires).every(([spell, level]) => state.spells[spell] >= level)) return false;
    state.fusions.push(id);
  } else if (id in state.spells) {
    if (state.spells[id] >= 5) return false;
    state.spells[id]++;
  }
  else {
    state.stats[id]++;
    if (id === 'vitality') {
      state.player.maxHp += 2;
      state.player.hp = Math.min(state.player.maxHp, state.player.hp + 2);
      effect(state, 'heal', state.player.x, state.player.y, .5);
    }
  }
  state.choices = [];
  state.phase = 'playing';
  if (state.xp >= state.xpNeeded) offerUpgrade(state);
  return true;
}

function offerArtifact(state) {
  const available = ARTIFACTS.filter(item => !state.artifacts.includes(item.id));
  if (!available.length) {
    state.player.hp = Math.min(state.player.maxHp, state.player.hp + 2);
    effect(state, 'heal', state.player.x, state.player.y, .5);
    return;
  }
  state.artifactChoices = [];
  while (state.artifactChoices.length < 3 && available.length) {
    const index = Math.min(available.length - 1, Math.floor(state.rng() * available.length));
    state.artifactChoices.push(available.splice(index, 1)[0]);
  }
  state.phase = 'artifact';
}

export function chooseArtifact(state, id) {
  if (state.phase !== 'artifact' || !state.artifactChoices.some(item => item.id === id) || state.artifacts.includes(id)) return false;
  state.artifacts.push(id);
  if (id === 'broom') state.player.speed *= 1.15;
  if (id === 'secondheart') {
    state.player.maxHp += 3;
    state.player.hp = Math.min(state.player.maxHp, state.player.hp + 3);
    effect(state, 'heal', state.player.x, state.player.y, .5);
  }
  if (id === 'aegis') state.player.shield = 1;
  state.artifactChoices = [];
  state.phase = 'playing';
  if (state.xp >= state.xpNeeded) offerUpgrade(state);
  return true;
}

function blast(state, x, y, radius, damage) {
  effect(state, 'explosion', x, y, .35, { radius });
  for (const enemy of [...state.enemies]) {
    if (distance({ x, y }, enemy) <= radius + enemy.radius) hurtEnemy(state, enemy, damage);
  }
}

export function updateGame(state, dt, input = { x: 0, y: 0 }) {
  if (state.phase !== 'playing' || !Number.isFinite(dt) || dt <= 0) return;
  dt = Math.min(dt, .05);
  state.time = Math.min(DURATION, state.time + dt);
  const player = state.player;
  const magnitude = Math.hypot(input.x || 0, input.y || 0);
  if (magnitude) {
    player.x += (input.x || 0) / Math.max(1, magnitude) * player.speed * dt;
    player.y += (input.y || 0) / Math.max(1, magnitude) * player.speed * dt;
  }
  player.invulnerable = Math.max(0, player.invulnerable - dt);
  if (state.artifacts.includes('worldtreeleaf')) player.hp = Math.min(player.maxHp, player.hp + .06 * dt);
  if (state.artifacts.includes('aegis') && !player.shield) {
    state.shieldTimer -= dt;
    if (state.shieldTimer <= 0) player.shield = 1;
  }
  for (const visual of state.effects) {
    visual.life -= dt;
    if (visual.type === 'pulse') {
      visual.radius = visual.maxRadius * Math.min(1, 1 - visual.life / visual.maxLife);
      for (const enemy of [...state.enemies]) {
        if (!visual.hitIds.has(enemy.id) && distance(visual, enemy) <= visual.radius + enemy.radius) {
          visual.hitIds.add(enemy.id);
          hurtEnemy(state, enemy, visual.damage);
        }
      }
    }
  }
  state.effects = state.effects.filter(visual => visual.life > 0);
  state.enemies = state.enemies.filter(enemy => distance(enemy, player) < 950);
  state.chests = state.chests.filter(chest => distance(chest, player) < 950);
  state.gems = state.gems.filter(gem => distance(gem, player) < 950);

  state.spawnTimer -= dt;
  if (state.spawnTimer <= 0) {
    const count = Math.min(7, 1 + Math.floor(state.time / 50));
    for (let i = 0; i < count; i++) spawnEnemy(state);
    state.spawnTimer = Math.max(.35, 1.25 - state.time / 360);
  }
  state.eliteTimer -= dt;
  if (state.eliteTimer <= 0) {
    spawnEnemy(state, true);
    state.eliteTimer = Math.max(16, 30 - state.time / 25);
  }

  for (const enemy of state.enemies) {
    const d = distance(enemy, player);
    if (d > 0) {
      const step = (enemy.speed || 0) * (enemy.slow > 0 ? .45 : 1) * dt;
      enemy.x += (player.x - enemy.x) / d * Math.min(step, d);
      enemy.y += (player.y - enemy.y) / d * Math.min(step, d);
    }
    enemy.slow = Math.max(0, (enemy.slow || 0) - dt);
    if (player.invulnerable <= 0 && distance(enemy, player) < enemy.radius + player.radius) {
      if (player.shield) {
        player.shield = 0;
        state.shieldTimer = 15;
      } else player.hp = Math.max(0, player.hp - (enemy.damage || 1));
      player.invulnerable = .65;
      effect(state, 'hit', player.x, player.y, .3);
    }
  }

  state.cooldowns.bolt -= dt;
  if (state.cooldowns.bolt <= 0) {
    const target = nearestEnemy(state, player, 540);
    if (target) {
      const d = distance(target, player) || 1;
      if (state.fusions.includes('plasma')) {
        const dx = (target.x - player.x) / d;
        const dy = (target.y - player.y) / d;
        effect(state, 'beam', player.x + dx * 540, player.y + dy * 540, .2, { fromX: player.x, fromY: player.y, radius: 14 });
        for (const enemy of [...state.enemies]) {
          const along = (enemy.x - player.x) * dx + (enemy.y - player.y) * dy;
          const across = Math.abs((enemy.x - player.x) * dy - (enemy.y - player.y) * dx);
          if (along >= 0 && along <= 540 && across <= enemy.radius + 14) hurtEnemy(state, enemy, (2 + state.spells.bolt) * 1.3 * damageScale(state));
        }
      } else {
        state.projectiles.push({ x: player.x, y: player.y, vx: (target.x - player.x) / d * 460,
          vy: (target.y - player.y) / d * 460, radius: 6, damage: (2 + state.spells.bolt) * damageScale(state), life: 1.4 });
        effect(state, 'bolt', player.x, player.y, .12);
      }
      state.cooldowns.bolt = Math.max(.15, .65 / hasteScale(state));
    }
  }
  for (const projectile of state.projectiles) {
    projectile.x += projectile.vx * dt;
    projectile.y += projectile.vy * dt;
    projectile.life -= dt;
    const target = state.enemies.find(enemy => distance(projectile, enemy) <= projectile.radius + enemy.radius);
    if (target) {
      if (projectile.kind === 'fireball') blast(state, projectile.x, projectile.y, projectile.explosionRadius, projectile.damage);
      else hurtEnemy(state, target, projectile.damage);
      projectile.life = 0;
    } else if (projectile.life <= 0 && projectile.kind === 'fireball') {
      blast(state, projectile.x, projectile.y, projectile.explosionRadius, projectile.damage);
    }
  }
  state.projectiles = state.projectiles.filter(projectile => projectile.life > 0);

  for (let i = 0; i < Math.min(state.spells.orbit, 8); i++) {
    const pos = orbitPosition(state, i);
    for (const enemy of [...state.enemies]) {
      if (distance(pos, enemy) < enemy.radius + 12 && !(enemy.orbitHitUntil > state.time)) {
        enemy.orbitHitUntil = state.time + .45;
        hurtEnemy(state, enemy, (1.5 + state.spells.orbit * .5) * damageScale(state)
          * (state.fusions.includes('hyperion') ? 1.5 : 1) * (state.artifacts.includes('circularsawblade') ? 1.25 : 1));
      }
    }
  }
  state.cooldowns.lightning -= dt;
  if (state.spells.lightning && state.cooldowns.lightning <= 0) {
    let from = player;
    const used = new Set();
    for (let i = 0; i < Math.min(8, state.spells.lightning + 1 + (state.artifacts.includes('battery') ? 1 : 0)); i++) {
      const target = nearestEnemy(state, from, i ? 160 : 360, used);
      if (!target) break;
      used.add(target);
      effect(state, 'lightning', target.x, target.y, .24, { fromX: from.x, fromY: from.y });
      hurtEnemy(state, target, (3 + state.spells.lightning) * damageScale(state));
      from = target;
    }
    state.cooldowns.lightning = Math.max(.5, 2.7 / hasteScale(state));
  }
  state.cooldowns.frost -= dt;
  if (state.spells.frost && state.cooldowns.frost <= 0) {
    const radius = 120 + (state.spells.frost - 1) * 18 + (state.fusions.includes('blizzard') ? 45 : 0);
    effect(state, 'frost', player.x, player.y, .45, { radius });
    for (const enemy of [...state.enemies]) {
      if (distance(player, enemy) < radius + enemy.radius) {
        enemy.slow = 2 + (state.fusions.includes('blizzard') ? 1 : 0) + (state.artifacts.includes('snowflakecrown') ? 1 : 0);
        hurtEnemy(state, enemy, (1.5 + state.spells.frost * .5) * damageScale(state));
      }
    }
    state.cooldowns.frost = Math.max(1, 4 / hasteScale(state));
  }

  state.cooldowns.fireball -= dt;
  if (state.spells.fireball && state.cooldowns.fireball <= 0) {
    const target = nearestEnemy(state, player, 480);
    if (target) {
      const d = distance(target, player) || 1;
      const fused = state.fusions.includes('supernova');
      state.projectiles.push({ kind: 'fireball', x: player.x, y: player.y,
        vx: (target.x - player.x) / d * 340, vy: (target.y - player.y) / d * 340,
        radius: 10, life: 1.5, explosionRadius: 65 + state.spells.fireball * 8 + (fused ? 45 : 0),
        damage: (3 + state.spells.fireball) * damageScale(state) * (fused ? 1.5 : 1) * (state.artifacts.includes('ruby') ? 1.3 : 1) });
      effect(state, 'fireball', player.x, player.y, .2, { radius: 14 });
      state.cooldowns.fireball = Math.max(.7, 3 / hasteScale(state));
    }
  }
  state.cooldowns.vortex -= dt;
  if (state.spells.vortex && state.cooldowns.vortex <= 0) {
    const target = nearestEnemy(state, player, 400);
    if (target) {
      const radius = 70 + state.spells.vortex * 12 + (state.fusions.includes('blizzard') ? 35 : 0);
      state.zones.push({ x: target.x, y: target.y, radius, life: 3, maxLife: 3, nextTick: 0 });
      state.cooldowns.vortex = Math.max(1.5, 5 / hasteScale(state));
    }
  }
  for (const zone of state.zones) {
    zone.life -= dt;
    zone.nextTick -= dt;
    if (zone.nextTick <= 0) {
      effect(state, 'vortex', zone.x, zone.y, .45, { radius: zone.radius });
      for (const enemy of [...state.enemies]) {
        if (distance(zone, enemy) <= zone.radius + enemy.radius) {
          enemy.slow = Math.max(enemy.slow || 0, 1 + (state.fusions.includes('blizzard') ? 1 : 0) + (state.artifacts.includes('snowflakecrown') ? 1 : 0));
          hurtEnemy(state, enemy, (1 + state.spells.vortex * .5) * damageScale(state) * (state.fusions.includes('blizzard') ? 1.3 : 1));
        }
      }
      zone.nextTick = .5;
    }
  }
  state.zones = state.zones.filter(zone => zone.life > 0 && distance(zone, player) < 950);

  state.cooldowns.meteor -= dt;
  if (state.spells.meteor && state.cooldowns.meteor <= 0) {
    const target = nearestEnemy(state, player, 550);
    if (target) {
      state.strikes.push({ x: target.x, y: target.y, radius: 95 + state.spells.meteor * 12 + (state.fusions.includes('supernova') ? 50 : 0), life: .7, maxLife: .7 });
      effect(state, 'meteor', target.x, target.y, .7, { radius: state.strikes.at(-1).radius });
      state.cooldowns.meteor = Math.max(2, 6 / hasteScale(state));
    }
  }
  for (const strike of state.strikes) {
    strike.life -= dt;
    if (strike.life <= 0) blast(state, strike.x, strike.y, strike.radius,
      (5 + state.spells.meteor * 2) * damageScale(state) * (state.fusions.includes('supernova') ? 1.5 : 1) * (state.artifacts.includes('ruby') ? 1.3 : 1));
  }
  state.strikes = state.strikes.filter(strike => strike.life > 0 && distance(strike, player) < 950);

  state.cooldowns.pulse -= dt;
  if (state.spells.pulse && state.cooldowns.pulse <= 0) {
    effect(state, 'pulse', player.x, player.y, .6, { radius: 0,
      maxRadius: 120 + state.spells.pulse * 22 + (state.fusions.includes('hyperion') ? 50 : 0),
      damage: (2 + state.spells.pulse) * damageScale(state) * (state.fusions.includes('hyperion') ? 1.4 : 1), hitIds: new Set() });
    state.cooldowns.pulse = Math.max(.8, 3.3 / hasteScale(state));
  }

  const pickupRadius = 42 + state.stats.magnet * 30;
  for (const gem of state.gems) {
    const d = distance(gem, player);
    if (d < 175 + state.stats.magnet * 50 + (state.artifacts.includes('radar') ? 80 : 0) && d > 0) {
      const step = Math.min(d, (320 + state.stats.magnet * 60) * dt);
      gem.x += (player.x - gem.x) / d * step;
      gem.y += (player.y - gem.y) / d * step;
    }
    if (distance(gem, player) < pickupRadius + (gem.radius || 0)) {
      state.xp += gem.value * (state.artifacts.includes('sapphire') ? 1.25 : 1);
      gem.collected = true;
    }
  }
  state.gems = state.gems.filter(gem => !gem.collected);
  if (player.hp <= 0) state.phase = 'lost';
  else if (state.time >= DURATION) state.phase = 'won';
  else {
    const chest = state.chests.find(item => distance(item, player) <= 50);
    if (chest) {
      state.chests.splice(state.chests.indexOf(chest), 1);
      offerArtifact(state);
    }
    if (state.phase === 'playing' && state.xp >= state.xpNeeded) offerUpgrade(state);
  }
}
