import test from 'node:test';
import assert from 'node:assert/strict';
import { DURATION, UPGRADES, createGame, startGame, updateGame, togglePause, chooseUpgrade, orbitPosition } from '../core.mjs';

const game = () => { const state = createGame(() => 0.5); startGame(state); state.spawnTimer = Infinity; return state; };

test('the public game starts ready and moves at a fixed speed only while playing', () => {
  const state = createGame(() => 0.5);
  assert.equal(DURATION, 300);
  assert.equal(state.phase, 'ready');
  assert.equal(state.spells.bolt, 1);
  startGame(state);
  updateGame(state, 1, { x: 1, y: 1 });
  assert.ok(Math.abs(state.player.x - state.player.speed * .05 / Math.SQRT2) < .001);
  togglePause(state);
  const x = state.player.x;
  updateGame(state, .05, { x: 1 });
  assert.equal(state.player.x, x);
  togglePause(state);
  assert.equal(state.phase, 'playing');
});

test('bolt automatically kills a nearby enemy and its gem levels up into three valid choices', () => {
  const state = game();
  state.enemies.push({ id: 1, x: 100, y: 0, hp: 1, maxHp: 1, radius: 12, kind: 'normal', speed: 0 });
  for (let i = 0; i < 50 && state.enemies.length; i++) updateGame(state, .05);
  assert.equal(state.kills, 1);
  assert.equal(state.gems.length, 1);
  state.gems[0].value = 6;
  state.gems[0].x = 0;
  updateGame(state, .05);
  assert.equal(state.phase, 'upgrade');
  assert.equal(state.level, 2);
  assert.equal(state.choices.length, 3);
  assert.equal(new Set(state.choices.map(choice => choice.id)).size, 3);
  assert.ok(state.choices.every(choice => UPGRADES.includes(choice)));
  assert.equal(chooseUpgrade(state, 'invalid'), false);
  assert.equal(state.phase, 'upgrade');
  const choice = state.choices[0].id;
  assert.equal(chooseUpgrade(state, choice), true);
  assert.equal(state.phase, 'playing');
});

test('overflow XP queues another upgrade after the first choice', () => {
  const state = game();
  state.gems.push({ x: 0, y: 0, value: 30, radius: 6 });
  updateGame(state, .05);
  assert.equal(state.phase, 'upgrade');
  chooseUpgrade(state, state.choices[0].id);
  assert.equal(state.phase, 'upgrade');
  assert.equal(state.level, 3);
});

test('contact damage has an invulnerability window and death overrides a simultaneous win', () => {
  const state = game();
  state.player.hp = 1;
  state.time = DURATION - .02;
  state.enemies.push({ id: 1, x: 0, y: 0, hp: 100, maxHp: 100, radius: 16, kind: 'normal', speed: 0, damage: 1 });
  updateGame(state, .05);
  assert.equal(state.phase, 'lost');
  assert.equal(state.player.hp, 0);
  const won = game();
  won.time = DURATION - .01;
  updateGame(won, .05);
  assert.equal(won.phase, 'won');
  assert.equal(won.time, DURATION);
});

test('one enemy contact cannot drain health every frame', () => {
  const state = game();
  state.enemies.push({ id: 1, x: 0, y: 0, hp: 100, maxHp: 100, radius: 16, kind: 'normal', speed: 0, damage: 1 });
  updateGame(state, .05);
  updateGame(state, .05);
  assert.equal(state.player.hp, 5);
});

test('orbit alone damages a touching enemy at most once per contact cooldown', () => {
  const state = game();
  state.spells.orbit = 1;
  const pos = orbitPosition(state, 0);
  state.enemies.push({ id: 1, x: pos.x, y: pos.y, hp: 10, maxHp: 10, radius: 10, kind: 'normal', speed: 0 });
  updateGame(state, .05);
  const hp = state.enemies[0].hp;
  assert.ok(hp < 10);
  updateGame(state, .05);
  assert.equal(state.enemies[0].hp, hp);
});

test('orbit, lightning, and frost each affect enemies when acquired', () => {
  const state = game();
  state.spells.orbit = 1;
  state.spells.lightning = 1;
  state.spells.frost = 1;
  state.cooldowns.lightning = 0;
  state.cooldowns.frost = 0;
  const orbit = orbitPosition(state, 0);
  state.enemies.push({ id: 1, x: orbit.x, y: orbit.y, hp: 20, maxHp: 20, radius: 10, kind: 'normal', speed: 0 });
  updateGame(state, .05);
  assert.ok(state.enemies[0].hp < 20);
  assert.ok(state.enemies[0].slow > 0);
  assert.ok(state.effects.some(effect => effect.type === 'lightning'));
  assert.ok(state.effects.some(effect => effect.type === 'frost'));
});

test('a near miss cannot shield an overlapping larger enemy from a projectile', () => {
  const state = game();
  state.cooldowns.bolt = 100;
  state.projectiles.push({ x: 0, y: 0, vx: 0, vy: 0, radius: 6, damage: 3, life: 1 });
  state.enemies.push(
    { id: 1, x: 18, y: 0, hp: 10, maxHp: 10, radius: 11, kind: 'swift', speed: 0 },
    { id: 2, x: 25, y: 0, hp: 10, maxHp: 10, radius: 24, kind: 'elite', speed: 0 },
  );
  updateGame(state, .01);
  assert.equal(state.enemies[0].hp, 10);
  assert.equal(state.enemies[1].hp, 7);
});

test('spawns stay outside the view and the enemy count stays bounded', () => {
  const state = game();
  state.spawnTimer = 0;
  updateGame(state, .05);
  assert.ok(Math.hypot(state.enemies[0].x, state.enemies[0].y) >= 500);
  state.enemies = Array.from({ length: 200 }, (_, id) => ({ id, x: 800, y: 0, hp: 1, maxHp: 1, radius: 10, kind: 'normal', speed: 0 }));
  state.spawnTimer = 0;
  updateGame(state, .05);
  assert.equal(state.enemies.length, 200);
  state.enemies[0].x = 1200;
  updateGame(state, .05);
  assert.equal(state.enemies.length, 199);
});
