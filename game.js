import { MODES, SPELL_IDS, UPGRADES, FUSIONS, ARTIFACTS, createGame, startGame, updateGame, togglePause, chooseUpgrade, chooseArtifact, orbitPosition } from './core.mjs';
import { controlKey, usesNativeKeys } from './controls.mjs';
import { loadRecords, recordRun } from './records.mjs';

const $ = (id) => document.getElementById(id);
const canvas = $('game-canvas');
const ctx = canvas.getContext('2d');
const stage = $('stage');
const keys = new Set();
const movement = { x: 0, y: 0 };
const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
const spellIds = SPELL_IDS;
const spells = spellIds.map((id) => UPGRADES.find((upgrade) => upgrade.id === id));
const icons = new Map(UPGRADES.map((upgrade) => [upgrade.id, upgrade.icon]));
let state = createGame();
let width = 800;
let height = 600;
let scale = 1;
let previousPhase = '';
let previousLoadout = '';
let lastFrame = 0;
let accumulator = 0;
let pointer = null;
let audioContext;
let soundEnabled = false;
let previousKills = 0;
let lastSound = 0;
const storage = { getItem: key => localStorage.getItem(key), setItem: (key, value) => localStorage.setItem(key, value) };
let records = loadRecords(storage).records;
let selectedMode = 'quick';
let toastUntil = 0;
let previousFusions = '';
let resumeAfterRecipes = false;
const recipeDialog = $('recipe-dialog');
const chestImage = new Image();
chestImage.src = 'assets/artifactImages/holychest.png';

function saveBest() {
  const result = recordRun(storage, records, state);
  records = result.records;
  $('record-status').textContent = !result.saved ? '기록을 기기에 저장하지 못했습니다.' : result.updated ? '새 최고 기록' : '최고 기록 유지';
  updateBest();
}

function formatTime(seconds) {
  const time = Math.floor(seconds);
  return `${String(Math.floor(time / 60)).padStart(2, '0')}:${String(time % 60).padStart(2, '0')}`;
}

function updateBest() {
  const best = records[selectedMode];
  const detail = best ? `${best.endReason === 'boss-defeated' ? '우두머리 처치 · ' : best.endReason === 'timeout' ? '시간 초과 · ' : best.endReason === 'death' ? '전사 · ' : ''}${best.kills.toLocaleString()} 처치` : '아직 탐사 기록이 없습니다';
  $('best-heading').textContent = `${MODES[selectedMode].label} 최고 기록`;
  $('best-time').textContent = formatTime(best?.time || 0);
  $('best-kills').textContent = detail;
  $('mode-record').textContent = best ? `최고 기록 · ${formatTime(best.time)} · ${detail}` : '최고 기록 · 아직 기록이 없습니다';
}

function resize() {
  const rect = canvas.getBoundingClientRect();
  width = rect.width;
  height = rect.height;
  const dpr = Math.min(devicePixelRatio || 1, 2);
  canvas.width = Math.round(width * dpr);
  canvas.height = Math.round(height * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  scale = Math.min(1, Math.max(.65, width / 700));
}

function begin() {
  clearInput();
  state = createGame(Math.random, selectedMode);
  startGame(state);
  previousPhase = '';
  previousLoadout = '';
  previousKills = 0;
  previousFusions = '';
  toastUntil = 0;
  accumulator = 0;
  $('start-button').blur();
  $('restart-button').blur();
  playTone(440, .11, .035);
  updateUI();
}

function pause() {
  togglePause(state);
  clearInput();
  updateUI();
}

function selectUpgrade(id) {
  if (state.phase !== 'upgrade') return;
  chooseUpgrade(state, id);
  clearInput();
  previousPhase = '';
  playTone(660, .13, .04);
  updateUI();
}

function selectArtifact(id) {
  if (state.phase !== 'artifact') return;
  chooseArtifact(state, id);
  clearInput();
  previousPhase = '';
  playTone(740, .18, .04);
  updateUI();
}

function fillChoices(container, choices, select, artifact = false) {
  container.replaceChildren(...choices.map((upgrade, index) => {
    const button = document.createElement('button');
    const level = state.spells[upgrade.id];
    const label = artifact ? '유물 획득' : upgrade.kind === 'fusion' ? '마법 조합' : level === undefined ? '능력 강화' : level ? `Lv.${level} → ${level + 1}` : '새 마법';
    button.className = `upgrade-card${upgrade.kind === 'fusion' ? ' fusion-card' : ''}`;
    button.innerHTML = `<kbd>${index + 1}</kbd><img src="${upgrade.icon}" alt=""><strong>${upgrade.name}</strong><span class="description">${upgrade.description}</span><span class="spell-level">${label}</span>`;
    button.addEventListener('click', () => select(upgrade.id));
    return button;
  }));
  container.querySelector('button')?.focus({ preventScroll: true });
}

function renderRecipes() {
  $('recipe-list').replaceChildren(...FUSIONS.map((fusion) => {
    const row = document.createElement('article');
    const owned = state.fusions.includes(fusion.id);
    row.className = `recipe-row${owned ? ' acquired' : ''}`;
    const materials = Object.entries(fusion.requires).map(([id, required]) => {
      const spell = UPGRADES.find((item) => item.id === id);
      const level = state.spells[id];
      return `<span class="recipe-material${level >= required ? ' complete' : ''}"><img src="${spell.icon}" alt=""><span>${spell.name}<small>Lv.${level} / ${required}</small></span></span>`;
    }).join('<span class="recipe-plus" aria-hidden="true">+</span>');
    row.innerHTML = `<div class="recipe-result"><img src="${fusion.icon}" alt=""><div><h3>${fusion.name}</h3><p>${fusion.description}</p></div><span class="recipe-state">${owned ? '조합 완료' : Object.entries(fusion.requires).every(([id, required]) => state.spells[id] >= required) ? '선택 가능' : '조건 미달'}</span></div><div class="recipe-materials">${materials}</div>`;
    return row;
  }));
}

function clearInput() {
  keys.clear();
  movement.x = movement.y = 0;
  pointer = null;
  $('joystick').hidden = true;
}

function playTone(frequency, duration, volume) {
  if (!soundEnabled || !audioContext || audioContext.state !== 'running') return;
  const oscillator = audioContext.createOscillator();
  const gain = audioContext.createGain();
  oscillator.type = 'sine';
  oscillator.frequency.setValueAtTime(frequency, audioContext.currentTime);
  oscillator.frequency.exponentialRampToValueAtTime(frequency * .65, audioContext.currentTime + duration);
  gain.gain.setValueAtTime(volume, audioContext.currentTime);
  gain.gain.exponentialRampToValueAtTime(.001, audioContext.currentTime + duration);
  oscillator.connect(gain).connect(audioContext.destination);
  oscillator.start();
  oscillator.stop(audioContext.currentTime + duration);
}

function updateUI() {
  const hp = Math.max(0, Math.ceil(state.player.hp));
  $('health-text').textContent = `${hp} / ${state.player.maxHp}`;
  $('health-fill').style.width = `${Math.max(0, state.player.hp / state.player.maxHp) * 100}%`;
  $('health-bar').setAttribute('aria-valuemax', state.player.maxHp);
  $('health-bar').setAttribute('aria-valuenow', hp);
  $('time-text').textContent = formatTime(state.time);
  $('duration-text').textContent = `/ ${formatTime(state.duration)}`;
  $('run-caption').textContent = state.mode === 'quick' ? '5분간 살아남으세요' : '10분 안에 우두머리를 처치하세요';
  $('kills-text').textContent = state.kills.toLocaleString();
  $('level-text').textContent = state.level;
  $('xp-text').textContent = `${Math.floor(state.xp)} / ${state.xpNeeded}`;
  $('xp-fill').style.width = `${Math.min(100, state.xp / state.xpNeeded * 100)}%`;
  $('xp-bar').setAttribute('aria-valuemax', state.xpNeeded);
  $('xp-bar').setAttribute('aria-valuenow', Math.floor(state.xp));
  $('pause-button').disabled = !['playing', 'paused'].includes(state.phase);
  $('pause-button').firstChild.textContent = state.phase === 'paused' ? '계속하기 ' : '일시정지 ';
  $('battle-hint').hidden = state.phase !== 'playing' || state.time > 14;
  $('fusion-toast').hidden = state.phase !== 'playing' || state.time >= toastUntil;
  stage.dataset.phase = state.phase;
  const boss = state.enemies.find(enemy => enemy.id === state.bossId);
  $('boss-hud').hidden = !boss || state.phase === 'ready';
  $('boss-direction').hidden = true;
  if (boss) {
    const hp = Math.max(0, boss.hp / boss.maxHp * 100);
    $('boss-health-text').textContent = `${Math.ceil(boss.hp)} / ${boss.maxHp}`;
    $('boss-health-fill').style.width = `${hp}%`;
    $('boss-health-bar').setAttribute('aria-valuenow', Math.ceil(hp));
    const dx = (boss.x - state.player.x) * scale;
    const dy = (boss.y - state.player.y) * scale;
    if (Math.abs(dx) > width / 2 - boss.radius * scale || Math.abs(dy) > height / 2 - boss.radius * scale) {
      $('boss-direction').textContent = `우두머리 ${Math.abs(dx) > Math.abs(dy) ? dx > 0 ? '→' : '←' : dy > 0 ? '↓' : '↑'}`;
      $('boss-direction').hidden = false;
    }
  }
  const hazardText = state.hazards?.some(hazard => hazard.warning > 0) ? '위험 예고 · 표시된 곳에서 벗어나세요' : state.hazards?.some(hazard => hazard.active > 0) ? '위험 지역 활성' : '';
  if ($('hazard-status').textContent !== hazardText) $('hazard-status').textContent = hazardText;
  $('hazard-status').hidden = !hazardText || state.phase !== 'playing';

  const loadout = [spellIds.map((id) => state.spells[id]).join(','), state.fusions.join(','), state.artifacts.join(',')].join('|');
  if (loadout !== previousLoadout) {
    $('spell-count').textContent = `${spellIds.filter((id) => state.spells[id] > 0).length} / ${spellIds.length}`;
    $('spell-list').replaceChildren(...spells.filter((spell) => state.spells[spell.id] > 0).map((spell) => {
      const level = state.spells[spell.id];
      const slot = document.createElement('div');
      slot.className = `spell-slot${level ? '' : ' locked'}`;
      slot.innerHTML = `<span class="spell-icon"><img src="${spell.icon}" alt=""></span><span class="spell-info"><strong>${spell.name}</strong><span>${level ? '자동 발동' : '레벨업 시 습득'}</span></span><span class="spell-level-label">${level ? `Lv.${level}` : '—'}</span>`;
      return slot;
    }));
    $('mobile-spells').replaceChildren(...spells.filter((spell) => state.spells[spell.id]).map((spell) => {
      const item = document.createElement('span');
      item.innerHTML = `<img src="${icons.get(spell.id)}" alt="${spell.name}"><span>${state.spells[spell.id]}</span>`;
      return item;
    }));
    $('fusion-count').textContent = `${state.fusions.length} / ${FUSIONS.length}`;
    $('fusion-list').replaceChildren(...FUSIONS.map((fusion) => {
      const owned = state.fusions.includes(fusion.id);
      const row = document.createElement('div');
      row.className = `fusion-row${owned ? ' acquired' : ''}`;
      const progress = Object.entries(fusion.requires).map(([id, required]) => `${UPGRADES.find((item) => item.id === id).name} ${Math.min(state.spells[id], required)}/${required}`).join(' + ');
      row.innerHTML = `<img src="${fusion.icon}" alt=""><span><strong>${fusion.name}</strong><small>${owned ? '조합 완료' : progress}</small></span>`;
      return row;
    }));
    $('artifact-count').textContent = `${state.artifacts.length} / ${ARTIFACTS.length}`;
    $('artifact-list').replaceChildren(...state.artifacts.map((id) => {
      const artifact = ARTIFACTS.find((item) => item.id === id);
      const row = document.createElement('div');
      row.className = 'artifact-item';
      row.innerHTML = `<img src="${artifact.icon}" alt=""><span><strong>${artifact.name}</strong><small>${artifact.description}</small></span>`;
      return row;
    }));
    if (!state.artifacts.length) $('artifact-list').innerHTML = '<p class="inventory-empty">정예를 처치하고 보물상자를 여세요.</p>';
    $('pause-inventory').replaceChildren(...[...$('artifact-list').children].map((item) => item.cloneNode(true)));
    for (const item of [...FUSIONS.filter((fusion) => state.fusions.includes(fusion.id)), ...ARTIFACTS.filter((artifact) => state.artifacts.includes(artifact.id))]) {
      const chip = document.createElement('span');
      chip.title = item.name;
      chip.innerHTML = `<img src="${item.icon}" alt="${item.name}"><span>✦</span>`;
      $('mobile-spells').append(chip);
    }
    const fusionKey = state.fusions.join(',');
    if (fusionKey !== previousFusions && state.fusions.length) {
      const fusion = FUSIONS.find((item) => item.id === state.fusions.at(-1));
      $('fusion-toast').textContent = `${fusion.name} 조합 완성`;
      toastUntil = state.time + 4;
      $('announcement').textContent = `${fusion.name} 조합이 완성되었습니다.`;
    }
    previousFusions = fusionKey;
    previousLoadout = loadout;
  }

  if (state.phase === previousPhase) return;
  previousPhase = state.phase;
  $('overlay').hidden = state.phase === 'playing';
  $('welcome').hidden = state.phase !== 'ready';
  $('pause-panel').hidden = state.phase !== 'paused';
  $('upgrade-panel').hidden = state.phase !== 'upgrade';
  $('artifact-panel').hidden = state.phase !== 'artifact';
  $('result-panel').hidden = !['won', 'lost'].includes(state.phase);
  $('status-label').textContent = ({ ready: '황혼의 폐허', playing: '탐사 진행 중', paused: '시간이 멈춘 자리', upgrade: '마력 각성', artifact: '유물 발견', won: '여명을 맞이하다', lost: '탐사 종료' })[state.phase];

  if (state.phase === 'upgrade') {
    fillChoices($('upgrade-choices'), state.choices, selectUpgrade);
    $('announcement').textContent = `레벨 ${state.level}. 마법을 선택하세요.`;
    $('upgrade-choices').querySelector('button')?.focus({ preventScroll: true });
    playTone(880, .25, .035);
  } else if (state.phase === 'artifact') {
    fillChoices($('artifact-choices'), state.artifactChoices, selectArtifact, true);
    $('announcement').textContent = '보물상자를 열었습니다. 유물을 선택하세요.';
    playTone(560, .25, .04);
  } else if (state.phase === 'paused' && !recipeDialog.open) {
    $('resume-button').focus({ preventScroll: true });
  } else if (['won', 'lost'].includes(state.phase)) {
    saveBest();
    const resultCopy = {
      survived: ['여명을 맞이하다', '5분 생존 성공', '✦'],
      'boss-defeated': ['균열을 닫다', '우두머리 처치 · 원정 성공', '✦'],
      timeout: ['균열에 남다', '10분 종료 · 우두머리 미처치', '◇'],
      death: ['어둠에 잠기다', '생명력이 다했습니다', '◇'],
    }[state.endReason] || ['탐사 종료', '이번 탐사의 기록', '◇'];
    $('result-title').textContent = resultCopy[0];
    $('result-label').textContent = resultCopy[1];
    $('result-symbol').textContent = resultCopy[2];
    $('result-time').textContent = formatTime(state.time);
    $('result-kills').textContent = state.kills.toLocaleString();
    $('result-level').textContent = state.level;
    $('announcement').textContent = `${resultCopy[1]}. ${formatTime(state.time)}, ${state.kills} 처치.`;
    $('restart-button').focus({ preventScroll: true });
  }
}

function circle(x, y, radius, fill, stroke, lineWidth = 1) {
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  if (fill) { ctx.fillStyle = fill; ctx.fill(); }
  if (stroke) { ctx.strokeStyle = stroke; ctx.lineWidth = lineWidth; ctx.stroke(); }
}

function drawGround(time, cameraX, cameraY) {
  ctx.fillStyle = '#111d27';
  ctx.fillRect(0, 0, width, height);
  ctx.save();
  ctx.translate(width / 2 - cameraX * scale, height / 2 - cameraY * scale);
  ctx.scale(scale, scale);
  const left = cameraX - width / 2 / scale;
  const top = cameraY - height / 2 / scale;
  const right = left + width / scale;
  const bottom = top + height / scale;
  // Stable world-space marks make movement readable without loading a map texture.
  for (let x = Math.floor(left / 70) * 70; x < right + 70; x += 70) {
    for (let y = Math.floor(top / 70) * 70; y < bottom + 70; y += 70) {
      const seed = Math.sin(x * 1.27 + y * .91) * 43758.5453;
      const fraction = seed - Math.floor(seed);
      ctx.fillStyle = fraction > .5 ? '#8299a414' : '#070d153b';
      ctx.fillRect(x + fraction * 48, y + fraction * 26, fraction > .7 ? 3 : 1.5, 2);
      if (fraction > .82) {
        ctx.strokeStyle = '#667b8218';
        ctx.beginPath(); ctx.moveTo(x + 18, y + 20); ctx.lineTo(x + 12, y + 8); ctx.moveTo(x + 18, y + 20); ctx.lineTo(x + 24, y + 12); ctx.stroke();
      }
    }
  }
  const ruinStep = 620;
  for (let x = Math.floor(left / ruinStep) * ruinStep; x < right + ruinStep; x += ruinStep) {
    for (let y = Math.floor(top / ruinStep) * ruinStep; y < bottom + ruinStep; y += ruinStep) {
      ctx.save(); ctx.translate(x + 210, y + 170); ctx.rotate(.35);
      circle(0, 0, 94, null, '#7f979c0e'); circle(0, 0, 105, null, '#7f979c0a');
      ctx.strokeStyle = '#7f979c0e';
      for (let i = 0; i < 8; i++) { const angle = i * Math.PI / 4; ctx.beginPath(); ctx.moveTo(Math.cos(angle) * 83, Math.sin(angle) * 83); ctx.lineTo(Math.cos(angle) * 104, Math.sin(angle) * 104); ctx.stroke(); }
      ctx.restore();
    }
  }
  ctx.restore();
  const glow = ctx.createRadialGradient(width * .6, height * .42, 0, width * .55, height * .5, width * .7);
  glow.addColorStop(0, '#456e7b14'); glow.addColorStop(1, '#0000');
  ctx.fillStyle = glow; ctx.fillRect(0, 0, width, height);
}

function drawPlayer(x, y, time, invulnerable = 0) {
  ctx.save(); ctx.translate(x, y);
  if (invulnerable > 0 && Math.floor(time * 14) % 2) ctx.globalAlpha = .45;
  const halo = ctx.createRadialGradient(0, 0, 3, 0, 0, 55);
  halo.addColorStop(0, '#a0e1df32'); halo.addColorStop(1, '#80d4d100');
  circle(0, 0, 55, halo);
  circle(0, 9, 17, '#02071170');
  ctx.save(); ctx.scale(1, .42); circle(0, 23, 27, null, '#91d8d63a'); ctx.restore();
  ctx.strokeStyle = '#5c6d86'; ctx.lineWidth = 1.4;
  ctx.fillStyle = '#1e2c45'; ctx.beginPath(); ctx.moveTo(0, -12); ctx.lineTo(-12, 15); ctx.quadraticCurveTo(0, 22, 12, 15); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#2c4661'; ctx.beginPath(); ctx.moveTo(-1, -10); ctx.lineTo(-3, 17); ctx.lineTo(7, 17); ctx.closePath(); ctx.fill();
  circle(0, -10, 8, '#7b9dac', '#b8d7d8', 1.5);
  ctx.fillStyle = '#263b51'; ctx.beginPath(); ctx.moveTo(0, -24); ctx.lineTo(-10, -9); ctx.quadraticCurveTo(0, -5, 10, -9); ctx.closePath(); ctx.fill(); ctx.strokeStyle = '#8ea9b6'; ctx.stroke();
  ctx.strokeStyle = '#9e9577'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(13, 14); ctx.lineTo(16, -15); ctx.stroke();
  ctx.shadowBlur = reducedMotion ? 0 : 15; ctx.shadowColor = '#8fe4dc'; circle(16, -17, 3, '#b8fff0'); ctx.shadowBlur = 0;
  ctx.restore();
}

function drawEnemy(enemy, time) {
  if (enemy.kind === 'boss') {
    ctx.save(); ctx.translate(enemy.x, enemy.y);
    circle(0, enemy.radius * .6, enemy.radius * 1.25, '#03071185');
    for (const [x, y, size] of [[-25, 2, 20], [23, 5, 22], [0, -12, 31]]) {
      ctx.fillStyle = '#372d3a'; ctx.strokeStyle = '#c58b84'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(x, y - size); ctx.lineTo(x + size * .8, y - size * .2); ctx.lineTo(x + size * .65, y + size); ctx.lineTo(x - size * .7, y + size * .8); ctx.lineTo(x - size, y - size * .15); ctx.closePath(); ctx.fill(); ctx.stroke();
    }
    circle(-9, -12, 3, '#f7c7a5'); circle(9, -12, 3, '#f7c7a5');
    ctx.restore();
    return;
  }
  const elite = enemy.kind === 'elite';
  const swift = enemy.kind === 'swift';
  const radius = enemy.radius;
  ctx.save(); ctx.translate(enemy.x, enemy.y);
  circle(0, radius * .5, radius * .9, '#03071160');
  ctx.rotate(Math.sin(time * 2 + enemy.id) * .2);
  ctx.beginPath();
  for (let i = 0; i < 10; i++) {
    const angle = i * Math.PI / 5;
    const r = radius * (i % 2 ? .74 : 1.13);
    const x = Math.cos(angle) * r;
    const y = Math.sin(angle) * r;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.closePath();
  ctx.fillStyle = elite ? '#492f3d' : swift ? '#31464b' : '#2e3043'; ctx.fill();
  ctx.strokeStyle = elite ? '#b5808b' : swift ? '#789b91' : '#77617c'; ctx.lineWidth = elite ? 2 : 1; ctx.stroke();
  circle(-radius * .24, -2, elite ? 3 : 2, elite ? '#f7b38c' : '#d29cbb'); circle(radius * .24, -2, elite ? 3 : 2, elite ? '#f7b38c' : '#d29cbb');
  if (enemy.hp < enemy.maxHp) { ctx.fillStyle = '#383d49'; ctx.fillRect(-radius, -radius - 7, radius * 2, 2); ctx.fillStyle = '#b17f90'; ctx.fillRect(-radius, -radius - 7, radius * 2 * Math.max(0, enemy.hp / enemy.maxHp), 2); }
  ctx.restore();
}

function render(now) {
  const ready = state.phase === 'ready';
  const time = ready ? (reducedMotion ? 0 : now / 1000) : state.time;
  const cameraX = ready ? -100 : state.player.x;
  const cameraY = ready ? 0 : state.player.y;
  drawGround(time, cameraX, cameraY);
  ctx.save();
  ctx.translate(width / 2 - cameraX * scale, height / 2 - cameraY * scale);
  ctx.scale(scale, scale);

  if (ready) {
    const x = width * .2 / scale;
    circle(x, 0, 105, null, '#91d8d620'); circle(x, 0, 98, null, '#91d8d612');
    for (let i = 0; i < 14; i++) {
      const angle = i * Math.PI / 7 + time * .08;
      circle(x + Math.cos(angle) * (100 + i * 3), Math.sin(angle) * (100 + i * 3), i % 3 ? 1.5 : 3, '#91d8d65a');
    }
    drawPlayer(x, 0, time);
  } else {
    for (const chest of state.chests) {
      const pulse = 1 + Math.sin(time * 3) * .08;
      circle(chest.x, chest.y, 23 * pulse, '#d9b66f12', '#d9b66f70');
      if (chestImage.complete && chestImage.naturalWidth) ctx.drawImage(chestImage, chest.x - 16, chest.y - 16, 32, 32);
      else { ctx.fillStyle = '#d9b66f'; ctx.fillRect(chest.x - 10, chest.y - 8, 20, 16); }
    }
    for (const zone of state.zones) {
      ctx.save(); ctx.translate(zone.x, zone.y); ctx.rotate(time * 1.6);
      circle(0, 0, zone.radius, '#85b9ca0a', '#85b9ca50');
      ctx.strokeStyle = '#a0cedb70'; ctx.lineWidth = 2;
      for (let i = 0; i < 5; i++) {
        ctx.rotate(Math.PI * 2 / 5); ctx.beginPath(); ctx.arc(0, 0, zone.radius * (.35 + i * .1), .1, Math.PI * 1.2); ctx.stroke();
      }
      ctx.restore();
    }
    for (const hazard of state.hazards) {
      const warning = hazard.warning > 0;
      circle(hazard.x, hazard.y, hazard.radius, warning ? '#c9a66b12' : '#c4655f4d', warning ? '#e0bc76' : '#f49a8d', warning ? 2 : 3);
      ctx.save(); ctx.beginPath(); ctx.arc(hazard.x, hazard.y, hazard.radius, 0, Math.PI * 2); ctx.clip();
      ctx.strokeStyle = warning ? '#e0bc7666' : '#ffd0bf88'; ctx.lineWidth = warning ? 1 : 2;
      if (warning) ctx.setLineDash([6, 8]);
      for (let offset = -hazard.radius * 2; offset < hazard.radius * 2; offset += 14) {
        ctx.beginPath(); ctx.moveTo(hazard.x + offset, hazard.y - hazard.radius); ctx.lineTo(hazard.x + offset + hazard.radius * 2, hazard.y + hazard.radius); ctx.stroke();
      }
      ctx.restore();
    }
    for (const strike of state.strikes) {
      const progress = Math.max(0, 1 - strike.life / strike.maxLife);
      circle(strike.x, strike.y, strike.radius, '#d4826310', '#dc997b90');
      circle(strike.x, strike.y, strike.radius * progress, '#dc997b20', '#dc997b60');
      ctx.strokeStyle = '#dc997b80'; ctx.beginPath(); ctx.moveTo(strike.x - 6, strike.y); ctx.lineTo(strike.x + 6, strike.y); ctx.moveTo(strike.x, strike.y - 6); ctx.lineTo(strike.x, strike.y + 6); ctx.stroke();
    }
    for (const gem of state.gems) {
      ctx.save(); ctx.translate(gem.x, gem.y); ctx.rotate(Math.PI / 4);
      ctx.shadowBlur = reducedMotion ? 0 : 7; ctx.shadowColor = '#75d0d8';
      ctx.fillStyle = gem.value > 1 ? '#dcc69a' : '#87d2d6'; ctx.fillRect(-3, -3, 6, 6); ctx.restore();
    }
    for (const enemy of state.enemies) drawEnemy(enemy, time);
    for (const projectile of state.projectiles) {
      const length = Math.hypot(projectile.vx, projectile.vy) || 1;
      const fireball = projectile.kind === 'fireball';
      ctx.strokeStyle = fireball ? '#f5b57870' : '#9fd7e052'; ctx.lineWidth = fireball ? 4 : 2; ctx.beginPath(); ctx.moveTo(projectile.x, projectile.y); ctx.lineTo(projectile.x - projectile.vx / length * 18, projectile.y - projectile.vy / length * 18); ctx.stroke();
      circle(projectile.x, projectile.y, projectile.radius || 3, fireball ? '#f5c58b' : '#c5f0eb');
    }
    if (state.spells.orbit > 0) {
      const count = Math.min(8, state.spells.orbit);
      for (let i = 0; i < count; i++) {
        const position = orbitPosition(state, i);
        ctx.save(); ctx.translate(position.x, position.y); ctx.rotate(time * 2.4 + i * Math.PI * 2 / count + Math.PI / 2);
        ctx.shadowBlur = reducedMotion ? 0 : 15; ctx.shadowColor = '#d6cb9f';
        ctx.fillStyle = '#e9d9b8'; ctx.beginPath(); ctx.moveTo(0, -13); ctx.lineTo(4, 6); ctx.lineTo(0, 10); ctx.lineTo(-4, 6); ctx.closePath(); ctx.fill(); ctx.restore();
      }
    }
    drawPlayer(state.player.x, state.player.y, time, state.player.invulnerable);
    if (state.player.shield) circle(state.player.x, state.player.y, 27, '#80d4d10c', '#a8dedab0', 1.5);
    for (const effect of state.effects) {
      const alpha = Math.max(0, Math.min(1, effect.life / (effect.maxLife || .4)));
      ctx.save(); ctx.globalAlpha = alpha;
      if (effect.type === 'beam') {
        ctx.strokeStyle = '#a8ece8'; ctx.lineWidth = 5; ctx.shadowBlur = reducedMotion ? 0 : 18; ctx.shadowColor = '#80d4d1';
        ctx.beginPath(); ctx.moveTo(effect.fromX, effect.fromY); ctx.lineTo(effect.x, effect.y); ctx.stroke();
      } else if (effect.type === 'lightning') {
        const fromX = effect.fromX ?? state.player.x;
        const fromY = effect.fromY ?? state.player.y;
        ctx.strokeStyle = '#e7d7a3'; ctx.lineWidth = 2; ctx.shadowColor = '#e7d7a3'; ctx.shadowBlur = reducedMotion ? 0 : 14;
        ctx.beginPath(); ctx.moveTo(fromX, fromY);
        for (let i = 1; i < 6; i++) ctx.lineTo(fromX + (effect.x - fromX) * i / 6 + Math.sin(i * 14) * 12, fromY + (effect.y - fromY) * i / 6 + Math.cos(i * 5) * 12);
        ctx.lineTo(effect.x, effect.y); ctx.stroke();
      } else if (effect.type === 'frost') {
        const radius = (effect.radius || 115) * (1 - alpha * .6);
        circle(effect.x, effect.y, radius, '#97d9ec08', '#a4dced', 2);
        circle(effect.x, effect.y, radius * .8, null, '#a4dced55');
        for (let i = 0; i < 8; i++) { const angle = i * Math.PI / 4; ctx.strokeStyle = '#a4dced70'; ctx.beginPath(); ctx.moveTo(effect.x + Math.cos(angle) * radius * .7, effect.y + Math.sin(angle) * radius * .7); ctx.lineTo(effect.x + Math.cos(angle) * radius, effect.y + Math.sin(angle) * radius); ctx.stroke(); }
      } else if (['explosion', 'meteor', 'fireball'].includes(effect.type)) {
        const radius = (effect.radius || 40) * (.3 + (1 - alpha) * .7);
        circle(effect.x, effect.y, radius, '#efab6f18', '#f1c18d', 2);
        circle(effect.x, effect.y, radius * .65, '#f2cf8818', '#f2cf8870');
        if (effect.type === 'meteor') {
          ctx.strokeStyle = '#efc691a0'; ctx.lineWidth = 5;
          ctx.beginPath(); ctx.moveTo(effect.x - 55 * alpha, effect.y - 95 * alpha); ctx.lineTo(effect.x, effect.y); ctx.stroke();
        }
      } else if (effect.type === 'pulse') {
        circle(effect.x, effect.y, effect.radius || 25, '#d3c2f00a', '#d3c2f0b0', 2);
      } else if (effect.type === 'vortex') {
        circle(effect.x, effect.y, (effect.radius || 50) * (1 - alpha * .3), null, '#9bcbd6', 1.5);
      } else {
        const radius = effect.type === 'death' ? 17 * (1 - alpha) + 3 : 9;
        circle(effect.x, effect.y, radius, null, effect.type === 'heal' ? '#b6dfba' : '#bbcee3', 1.4);
      }
      ctx.restore();
    }
  }
  ctx.restore();
}

function frame(now) {
  const elapsed = Math.min((now - lastFrame) / 1000 || 0, .1);
  lastFrame = now;
  if (state.phase === 'playing') {
    const x = pointer ? movement.x : (keys.has('d') || keys.has('arrowright') ? 1 : 0) - (keys.has('a') || keys.has('arrowleft') ? 1 : 0);
    const y = pointer ? movement.y : (keys.has('s') || keys.has('arrowdown') ? 1 : 0) - (keys.has('w') || keys.has('arrowup') ? 1 : 0);
    accumulator += elapsed;
    while (accumulator >= 1 / 60 && state.phase === 'playing') {
      updateGame(state, 1 / 60, { x, y });
      accumulator -= 1 / 60;
    }
    if (state.kills > previousKills && now - lastSound > 120) { playTone(160 + Math.random() * 80, .05, .015); lastSound = now; }
    previousKills = state.kills;
    updateUI();
  } else { accumulator = 0; }
  render(now);
  requestAnimationFrame(frame);
}

$('start-button').addEventListener('click', begin);
$('restart-button').addEventListener('click', begin);
for (const option of document.querySelectorAll('input[name="mode"]')) option.addEventListener('change', () => {
  if (!option.checked || state.phase !== 'ready') return;
  selectedMode = option.value;
  state = createGame(Math.random, selectedMode);
  updateBest();
  updateUI();
});
$('pause-button').addEventListener('click', pause);
$('resume-button').addEventListener('click', pause);
$('recipes-button').addEventListener('click', () => {
  resumeAfterRecipes = state.phase === 'playing';
  if (resumeAfterRecipes) pause();
  clearInput();
  renderRecipes();
  recipeDialog.showModal();
});
$('recipe-close').addEventListener('click', () => recipeDialog.close());
recipeDialog.addEventListener('close', () => {
  clearInput();
  if (resumeAfterRecipes && state.phase === 'paused') pause();
  resumeAfterRecipes = false;
});
$('sound-button').addEventListener('click', async () => {
  try {
    audioContext ??= new AudioContext();
    await audioContext.resume();
    soundEnabled = !soundEnabled;
    $('sound-button').textContent = soundEnabled ? '소리 켜짐' : '소리 꺼짐';
    $('sound-button').setAttribute('aria-pressed', String(soundEnabled));
    playTone(520, .1, .03);
  } catch { $('sound-button').textContent = '소리 사용 불가'; }
});

document.addEventListener('keydown', (event) => {
  const key = controlKey(event);
  if (recipeDialog.open) {
    if (key === 'escape') { event.preventDefault(); recipeDialog.close(); }
    return;
  }
  if (usesNativeKeys(event.target)) return;
  const buttonSpace = key === ' ' && event.target instanceof HTMLButtonElement;
  if (['w', 'a', 's', 'd', 'arrowup', 'arrowdown', 'arrowleft', 'arrowright', ' ', 'p', 'escape'].includes(key) && !buttonSpace) event.preventDefault();
  if ((key === 'p' || key === 'escape' || (key === ' ' && !buttonSpace)) && !event.repeat) pause();
  if (['upgrade', 'artifact'].includes(state.phase) && /^[123]$/.test(key)) {
    const choice = (state.phase === 'artifact' ? state.artifactChoices : state.choices)[Number(key) - 1];
    if (choice) (state.phase === 'artifact' ? selectArtifact : selectUpgrade)(choice.id);
  }
  if (event.key === 'Tab' && ['paused', 'upgrade', 'artifact', 'won', 'lost'].includes(state.phase)) {
    const buttons = [...$('overlay').querySelectorAll('section:not([hidden]) button')];
    const first = buttons[0];
    const last = buttons.at(-1);
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
  }
  keys.add(key);
});
document.addEventListener('keyup', (event) => keys.delete(controlKey(event)));
window.addEventListener('blur', () => { clearInput(); if (state.phase === 'playing') pause(); });
document.addEventListener('visibilitychange', () => { if (document.hidden && state.phase === 'playing') pause(); });

canvas.addEventListener('pointerdown', (event) => {
  if (state.phase !== 'playing' || pointer) return;
  pointer = { id: event.pointerId, x: event.clientX, y: event.clientY };
  canvas.setPointerCapture(event.pointerId);
  const rect = stage.getBoundingClientRect();
  $('joystick').style.left = `${event.clientX - rect.left - 46}px`;
  $('joystick').style.top = `${event.clientY - rect.top - 46}px`;
  $('joystick-knob').style.transform = 'translate(0,0)';
  $('joystick').hidden = false;
});
canvas.addEventListener('pointermove', (event) => {
  if (!pointer || pointer.id !== event.pointerId) return;
  const dx = event.clientX - pointer.x;
  const dy = event.clientY - pointer.y;
  const distance = Math.hypot(dx, dy);
  const denominator = Math.max(35, distance);
  movement.x = dx / denominator;
  movement.y = dy / denominator;
  $('joystick-knob').style.transform = `translate(${movement.x * 28}px,${movement.y * 28}px)`;
});
for (const event of ['pointerup', 'pointercancel', 'lostpointercapture']) canvas.addEventListener(event, (value) => { if (pointer?.id === value.pointerId) clearInput(); });

new ResizeObserver(resize).observe(stage);
resize();
updateBest();
updateUI();
requestAnimationFrame(frame);
