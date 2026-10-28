import test from 'node:test';
import assert from 'node:assert/strict';
import { DURATION, MODES, createGame, startGame, togglePause, updateGame } from '../core.mjs';

function expedition() {
  const state = createGame(() => .5, 'expedition');
  startGame(state);
  state.spawnTimer = Infinity;
  state.eliteTimer = Infinity;
  state.cooldowns.bolt = Infinity;
  return state;
}

test('quick remains the default and invalid modes safely use it', () => {
  assert.equal(DURATION, 300);
  for (const state of [createGame(() => .5), createGame(() => .5, 'unknown')]) {
    assert.equal(state.mode, 'quick');
    assert.equal(state.duration, 300);
    state.time = 299.99;
    startGame(state);
    updateGame(state, .05);
    assert.equal(state.phase, 'won');
    assert.equal(state.endReason, 'survived');
  }
  assert.deepEqual(Object.keys(MODES), ['quick', 'expedition']);
  assert.equal(MODES.expedition.duration, 600);
});

test('boss spawns once at 510 seconds even at the enemy cap and remains in chase range', () => {
  const state = expedition();
  state.time = 509.94;
  updateGame(state, .05);
  assert.equal(state.bossId, null);
  state.enemies = Array.from({ length: 200 }, (_, id) => ({ id: id + 1, x: 800, y: 0, hp: 10, radius: 10, kind: 'normal', speed: 0 }));
  updateGame(state, .05);
  assert.equal(state.enemies.length, 200);
  assert.equal(state.enemies.filter(enemy => enemy.kind === 'boss').length, 1);
  const boss = state.enemies.find(enemy => enemy.id === state.bossId);
  assert.ok(boss && boss.hp > 0 && boss.speed >= state.player.speed);
  boss.slow = 2;
  const gap = boss.x - state.player.x;
  updateGame(state, .05, { x: -1 });
  assert.ok(boss.x - state.player.x < gap, 'the slowed boss still closes the gap');
  state.player.x += 2000;
  updateGame(state, .05);
  assert.ok(state.enemies.includes(boss));
  for (let i = 0; i < 10; i++) updateGame(state, .05);
  assert.equal(state.enemies.filter(enemy => enemy.kind === 'boss').length, 1);
});

test('boss circles warn for at least 0.8 seconds, hit once, and pause freezes hazards', () => {
  const state = expedition();
  state.time = 509.99;
  updateGame(state, .05);
  const circles = state.hazards.filter(hazard => hazard.kind === 'circle');
  const rays = state.hazards.filter(hazard => hazard.kind === 'ray');
  assert.ok(circles.length > 0 && rays.length >= 4);
  assert.ok(state.hazards.every(hazard => hazard.warning >= .8 && hazard.active > 0 && !hazard.hit));
  const circle = circles[0];
  state.player.x = circle.x;
  state.player.y = circle.y;
  state.enemies.find(enemy => enemy.kind === 'boss').x = 800;
  const hp = state.player.hp;
  togglePause(state);
  const time = state.time;
  updateGame(state, .05);
  assert.equal(state.time, time);
  assert.equal(circle.warning, circles[0].warning);
  togglePause(state);
  for (let i = 0; i < 16; i++) updateGame(state, .05);
  assert.equal(state.player.hp, hp);
  for (let i = 0; i < 8; i++) updateGame(state, .05);
  assert.equal(state.player.hp, hp - 1);
  for (let i = 0; i < 8; i++) updateGame(state, .05);
  assert.equal(state.player.hp, hp - 1);
});

test('boss defeat wins immediately without elite chest or extra drops', () => {
  const state = expedition();
  state.time = 509.99;
  updateGame(state, .05);
  const boss = state.enemies.find(enemy => enemy.kind === 'boss');
  state.enemies = [boss];
  boss.x = 100;
  boss.y = 0;
  boss.hp = 1;
  state.cooldowns.bolt = 0;
  for (let i = 0; i < 20 && state.phase === 'playing'; i++) updateGame(state, .05);
  assert.equal(state.phase, 'won');
  assert.equal(state.endReason, 'boss-defeated');
  assert.equal(state.bossDefeated, true);
  assert.equal(state.chests.length, 0);
  assert.equal(state.hazards.length, 0);
});

test('expedition times out without boss defeat; death and deadline outrank a same-frame kill', () => {
  const timeout = expedition();
  timeout.time = 599.99;
  updateGame(timeout, .05);
  assert.equal(timeout.phase, 'lost');
  assert.equal(timeout.endReason, 'timeout');

  for (const [time, hp, reason] of [[520, 0, 'death'], [599.99, 6, 'timeout']]) {
    const state = expedition();
    state.time = time;
    state.bossSpawned = true;
    state.bossId = 1;
    state.enemies.push({ id: 1, kind: 'boss', x: 0, y: 0, hp: 1, maxHp: 550, radius: 30, speed: 0, damage: 0 });
    state.player.hp = hp;
    state.spells.orbit = 1;
    state.enemies[0].radius = 100;
    updateGame(state, .05);
    assert.equal(state.endReason, reason);
    assert.equal(state.phase, 'lost');
  }
});

test('active boss hazard death outranks a pulse kill earlier in the same frame', () => {
  const state = expedition();
  state.time = 520;
  state.bossSpawned = true;
  state.bossId = 1;
  state.player.hp = 1;
  state.enemies.push({ id: 1, kind: 'boss', x: 0, y: 0, hp: 1, maxHp: 550, radius: 38, speed: 0, damage: 0 });
  state.hazards.push({ id: 1, kind: 'circle', x: 0, y: 0, radius: 70, warning: 0, active: .5, hit: false });
  state.effects.push({ type: 'pulse', x: 0, y: 0, life: .5, maxLife: .6,
    radius: 0, maxRadius: 120, damage: 2, hitIds: new Set() });
  updateGame(state, .05);
  assert.equal(state.bossDefeated, true);
  assert.equal(state.player.hp, 0);
  assert.equal(state.phase, 'lost');
  assert.equal(state.endReason, 'death');
  assert.equal(state.hazards.length, 0);
});
