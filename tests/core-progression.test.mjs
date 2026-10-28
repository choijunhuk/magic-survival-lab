import test from 'node:test';
import assert from 'node:assert/strict';
import { ARTIFACTS, FUSIONS, SPELL_IDS, UPGRADES, createGame, startGame, updateGame, chooseUpgrade, chooseArtifact, orbitPosition } from '../core.mjs';

function game() { const state = createGame(() => 0); startGame(state); state.spawnTimer = Infinity; state.eliteTimer = Infinity; return state; }
function enemy(id, x, y, hp = 100, kind = 'normal') { return { id, x, y, hp, maxHp: hp, radius: 12, kind, speed: 0, damage: 1 }; }
function tick(state, frames = 1) { for (let i = 0; i < frames; i++) updateGame(state, .05); }

test('spell catalog has eight distinct spells and levels cap at five', () => {
  assert.equal(SPELL_IDS.length, 8);
  assert.equal(new Set(SPELL_IDS).size, 8);
  assert.ok(SPELL_IDS.every(id => UPGRADES.some(upgrade => upgrade.id === id)));
  const state = game();
  for (const id of SPELL_IDS) state.spells[id] = 5;
  state.spells.fireball = 0;
  state.gems.push({ x: 0, y: 0, radius: 6, value: 6 });
  tick(state);
  assert.equal(state.choices.length, 3);
  assert.equal(state.choices[0].id, 'plasma');
  assert.ok(state.choices.some(choice => choice.id === 'fireball'));
  assert.ok(state.choices.every(choice => !SPELL_IDS.includes(choice.id) || state.spells[choice.id] < 5));
  assert.equal(chooseUpgrade(state, 'bolt'), false);
});

test('eligible fusion is offered first, needs its recipe, and is granted only by selection', () => {
  const state = game();
  state.spells.bolt = 3;
  state.spells.lightning = 3;
  state.gems.push({ x: 0, y: 0, radius: 6, value: 6 });
  tick(state);
  assert.equal(state.choices[0].id, 'plasma');
  assert.deepEqual(state.fusions, []);
  state.spells.lightning = 2;
  assert.equal(chooseUpgrade(state, 'plasma'), false);
  state.spells.lightning = 3;
  assert.equal(chooseUpgrade(state, 'plasma'), true);
  assert.deepEqual(state.fusions, ['plasma']);
  state.gems.push({ x: 0, y: 0, radius: 6, value: 9 });
  tick(state);
  assert.equal(state.phase, 'upgrade');
  assert.ok(state.choices.every(choice => choice.id !== 'plasma'));
  assert.equal(FUSIONS.length, 4);
});

test('two eligible fusions are both offered without blocking an unlearned spell', () => {
  const state = game();
  state.spells.bolt = 3;
  state.spells.lightning = 3;
  state.spells.frost = 3;
  state.spells.vortex = 3;
  state.gems.push({ x: 0, y: 0, radius: 6, value: 6 });
  tick(state);
  assert.deepEqual(state.choices.map(item => item.id), ['plasma', 'blizzard', 'orbit']);
  assert.equal(chooseUpgrade(state, 'blizzard'), true);
  assert.deepEqual(state.fusions, ['blizzard']);
});

test('plasma beam pierces aligned enemies without a projectile', () => {
  const state = game();
  state.fusions.push('plasma');
  state.enemies.push(enemy(1, 100, 0), enemy(2, 200, 0));
  tick(state);
  assert.ok(state.enemies.every(item => item.hp < 100));
  assert.equal(state.projectiles.length, 0);
  assert.ok(state.effects.some(item => item.type === 'beam' && Number.isFinite(item.fromX)));
});

test('fireball explodes once across multiple enemies; supernova strengthens it', () => {
  const normal = game();
  normal.spells.fireball = 1;
  normal.cooldowns.bolt = 100;
  normal.enemies.push(enemy(1, 60, 0), enemy(2, 90, 0));
  tick(normal, 8);
  assert.ok(normal.enemies.every(item => item.hp < 100));
  assert.ok(normal.effects.some(item => item.type === 'explosion'));
  const damage = 100 - normal.enemies[1].hp;
  tick(normal, 1);
  assert.equal(100 - normal.enemies[1].hp, damage);

  const fused = game();
  fused.spells.fireball = 1;
  fused.fusions.push('supernova');
  fused.cooldowns.bolt = 100;
  fused.enemies.push(enemy(1, 60, 0), enemy(2, 90, 0));
  tick(fused, 8);
  assert.ok(fused.enemies[1].hp < normal.enemies[1].hp);
});

test('vortex zone slows and damages with a tick cooldown; blizzard expands frost reach', () => {
  const state = game();
  state.spells.vortex = 1;
  state.cooldowns.bolt = 100;
  state.enemies.push(enemy(1, 180, 0));
  tick(state);
  assert.equal(state.zones.length, 1);
  assert.ok(state.enemies[0].hp < 100);
  const hp = state.enemies[0].hp;
  tick(state);
  assert.equal(state.enemies[0].hp, hp);
  assert.ok(state.enemies[0].slow > 0);
  const frost = game();
  frost.spells.frost = 1;
  frost.cooldowns.bolt = 100;
  frost.enemies.push(enemy(1, 150, 0));
  tick(frost);
  assert.equal(frost.enemies[0].hp, 100);
  frost.fusions.push('blizzard');
  frost.cooldowns.frost = 0;
  tick(frost);
  assert.ok(frost.enemies[0].hp < 100);
});

test('meteor is delayed and pulse expands once per enemy; hyperion increases orbit reach', () => {
  const meteor = game();
  meteor.spells.meteor = 1;
  meteor.cooldowns.bolt = 100;
  meteor.enemies.push(enemy(1, 250, 0));
  tick(meteor);
  assert.equal(meteor.enemies[0].hp, 100);
  assert.equal(meteor.strikes.length, 1);
  tick(meteor, 16);
  assert.ok(meteor.enemies[0].hp < 100);
  const pulse = game();
  pulse.spells.pulse = 1;
  pulse.cooldowns.bolt = 100;
  pulse.enemies.push(enemy(1, 100, 0));
  tick(pulse, 10);
  assert.ok(pulse.enemies[0].hp < 100);
  const damage = 100 - pulse.enemies[0].hp;
  tick(pulse, 2);
  assert.equal(100 - pulse.enemies[0].hp, damage);
  const orbit = game();
  orbit.spells.orbit = 1;
  orbit.cooldowns.bolt = 100;
  orbit.enemies.push(enemy(1, 105, 0));
  tick(orbit);
  assert.equal(orbit.enemies[0].hp, 100);
  orbit.fusions.push('hyperion');
  orbit.enemies[0].x = orbitPosition(orbit, 0).x;
  orbit.enemies[0].y = orbitPosition(orbit, 0).y;
  tick(orbit);
  assert.ok(orbit.enemies[0].hp < 100);
});

test('elite drops one chest; opening offers unique artifacts and applies one once', () => {
  const state = game();
  state.cooldowns.bolt = 100;
  state.enemies.push(enemy(1, 90, 0, 1, 'elite'));
  state.projectiles.push({ x: 90, y: 0, vx: 0, vy: 0, radius: 6, damage: 1, life: 1 });
  tick(state);
  assert.equal(state.chests.length, 1);
  assert.equal(state.chests[0].x, 90);
  state.player.x = 90;
  tick(state);
  assert.equal(state.phase, 'artifact');
  assert.equal(state.artifactChoices.length, 3);
  assert.equal(new Set(state.artifactChoices.map(item => item.id)).size, 3);
  assert.equal(chooseArtifact(state, 'invalid'), false);
  const choice = state.artifactChoices[0].id;
  assert.equal(chooseArtifact(state, choice), true);
  assert.deepEqual(state.artifacts, [choice]);
  assert.equal(chooseArtifact(state, choice), false);
  assert.equal(ARTIFACTS.length, 12);
});

test('artifact shield, regeneration, and XP bonus work only while playing', () => {
  const state = game();
  state.artifacts.push('aegis', 'worldtreeleaf', 'sapphire');
  state.player.shield = 1;
  state.player.hp = 4;
  state.enemies.push(enemy(1, 0, 0));
  tick(state);
  assert.equal(state.player.shield, 0);
  assert.equal(state.player.hp, 4.003);
  state.enemies = [];
  state.gems.push({ x: 0, y: 0, radius: 6, value: 1 });
  tick(state);
  assert.equal(state.xp, 1.25);
  state.phase = 'paused';
  const hp = state.player.hp;
  const shieldTimer = state.shieldTimer;
  tick(state, 20);
  assert.equal(state.player.hp, hp);
  assert.equal(state.shieldTimer, shieldTimer);
  state.phase = 'playing';
  tick(state, 300);
  assert.equal(state.player.shield, 1);
  assert.ok(state.player.hp > hp);
});

test('terminal outcome takes priority over chests and XP; exhausted artifacts heal', () => {
  const terminal = game();
  terminal.time = 299.99;
  terminal.chests.push({ id: 1, x: 0, y: 0 });
  terminal.gems.push({ x: 0, y: 0, radius: 6, value: 6 });
  tick(terminal);
  assert.equal(terminal.phase, 'won');
  const exhausted = game();
  exhausted.artifacts = ARTIFACTS.map(item => item.id);
  exhausted.player.hp = 2;
  exhausted.chests.push({ id: 1, x: 0, y: 0 });
  tick(exhausted);
  assert.equal(exhausted.phase, 'playing');
  assert.ok(exhausted.player.hp >= 4);
  assert.equal(exhausted.chests.length, 0);
});

test('equipment changes movement, health, pickup range, and spell timing', () => {
  const state = game();
  for (const id of ['broom', 'secondheart']) {
    state.phase = 'artifact';
    state.artifactChoices = [ARTIFACTS.find(item => item.id === id)];
    assert.equal(chooseArtifact(state, id), true);
  }
  assert.ok(Math.abs(state.player.speed - 253) < .001);
  assert.equal(state.player.maxHp, 9);
  assert.equal(state.player.hp, 9);
  state.artifacts.push('radar', 'blackcat');
  state.gems.push({ x: 220, y: 0, radius: 6, value: 1 });
  state.enemies.push(enemy(1, 100, 0));
  tick(state);
  assert.ok(state.gems[0].x < 220);
  assert.ok(state.cooldowns.bolt < .65);
});

test('battery adds a lightning target and snowflake crown extends frost slow', () => {
  const plain = game();
  plain.spells.lightning = 1;
  plain.spells.frost = 1;
  plain.cooldowns.bolt = 100;
  plain.enemies.push(enemy(1, 100, 0), enemy(2, 200, 0), enemy(3, 300, 0));
  tick(plain);
  const equipped = game();
  equipped.spells.lightning = 1;
  equipped.spells.frost = 1;
  equipped.cooldowns.bolt = 100;
  equipped.artifacts.push('battery', 'snowflakecrown');
  equipped.enemies.push(enemy(1, 100, 0), enemy(2, 200, 0), enemy(3, 300, 0));
  tick(equipped);
  assert.equal(plain.enemies[2].hp, 100);
  assert.ok(equipped.enemies[2].hp < 100);
  assert.ok(equipped.enemies[0].slow > plain.enemies[0].slow);
});

test('damage artifacts increase their matching attack damage', () => {
  function fireballDamage(artifact) {
    const state = game();
    state.spells.fireball = 1;
    state.cooldowns.bolt = 100;
    if (artifact) state.artifacts.push(artifact);
    state.enemies.push(enemy(1, 90, 0));
    tick(state, 8);
    return 100 - state.enemies[0].hp;
  }
  assert.ok(fireballDamage('ruby') > fireballDamage());
  assert.ok(fireballDamage('magicwand') > fireballDamage());
  function orbitDamage(artifact) {
    const state = game();
    state.spells.orbit = 1;
    state.cooldowns.bolt = 100;
    if (artifact) state.artifacts.push(artifact);
    const pos = orbitPosition(state, 0);
    state.enemies.push(enemy(1, pos.x, pos.y));
    tick(state);
    return 100 - state.enemies[0].hp;
  }
  assert.ok(orbitDamage('circularsawblade') > orbitDamage());
});
