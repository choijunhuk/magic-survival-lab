import assert from 'node:assert/strict';
import { access, readFile, writeFile } from 'node:fs/promises';
import * as core from './core.mjs';

const root = new URL('./', import.meta.url);
const catalog = JSON.parse(await readFile(new URL('assets/catalog.json', root), 'utf8'));
const references = JSON.parse(await readFile(new URL('assets/references/catalog.json', root), 'utf8'));
const names = JSON.parse(await readFile(new URL('assets/display-names.json', root), 'utf8')).names;
const categories = {
  maps: '구역', subjects: '실험체', classes: '클래스', enemies: '적', bosses: '보스',
  magicImages: '마법', artifactImages: '유물', passiveImages: '패시브', researchImages: '연구',
  fieldItems: '필드 아이템', synergies: '시너지', screenshots: '화면', ui: 'UI',
};
const legacyCounts = { magicImages: 58, artifactImages: 153, passiveImages: 30, researchImages: 20 };
const implemented = new Map();
for (const item of [...(core.UPGRADES ?? []), ...(core.FUSIONS ?? []), ...(core.ARTIFACTS ?? [])]) {
  if (item.icon) implemented.set(item.icon, item);
}
const icons = [];
for (const { file, kind, source } of catalog.files) {
  const match = /^assets\/(magicImages|artifactImages|passiveImages|researchImages)\/([^/]+)\.png$/.exec(file);
  if (!match && kind !== 'image') continue;
  assert.equal(kind, 'image', `Not an image: ${file}`);
  await access(new URL(file, root));
  if (!match) {
    icons.push({ path: file, category: 'ui', name: file.split('/').at(-1),
      english: '', filename: file.split('/').at(-1), implemented: false,
      assetType: 'UI 이미지', source, sourcePage: catalog.repository, reference: true });
    continue;
  }
  const [, category, stem] = match;
  const game = implemented.get(file);
  const english = names[file] || stem.replace(/([a-z])([A-Z])/g, '$1 $2').replace(/[-_]/g, ' ');
  icons.push({
    path: file,
    category,
    name: game?.name || english,
    english,
    filename: `${stem}.png`,
    implemented: Boolean(game),
    assetType: '아이콘', source, sourcePage: catalog.repository,
    ...(game?.description ? { description: game.description } : {}),
  });
}
assert.equal(icons.length, 265);
for (const [category, count] of Object.entries(legacyCounts)) {
  assert.equal(icons.filter(icon => icon.category === category).length, count, category);
}
for (const item of references.files ?? []) {
  const { file, category, name, kind, source, source_page: sourcePage, asset_type: assetType } = item;
  assert.equal(kind, 'image', `Not an image: ${file}`);
  assert.ok(file?.startsWith('assets/references/') && !file.split('/').includes('..'), `Invalid reference path: ${file}`);
  assert.ok(category in categories, `Unknown reference category: ${category}`);
  await access(new URL(file, root));
  icons.push({ path: file, category, name: name || file.split('/').at(-1), english: item.english || item.english_name || '',
    filename: file.split('/').at(-1), implemented: false, reference: true,
    assetType: assetType || '참조 이미지', source, sourcePage,
    searchNames: [item.original_name, item.source_name, item.english_name].filter(Boolean) });
}
assert.equal(new Set(icons.map(icon => icon.path)).size, icons.length);
const counts = Object.fromEntries(Object.keys(categories).map(key => [key, icons.filter(icon => icon.category === key).length]));
icons.sort((a, b) => (Object.keys(categories).indexOf(a.category) - Object.keys(categories).indexOf(b.category)) || a.name.localeCompare(b.name));

// Escape script terminators and HTML-significant characters before embedding JSON.
const data = JSON.stringify(icons).replace(/[<>&\u2028\u2029]/g, char => ({
  '<': '\\u003c', '>': '\\u003e', '&': '\\u0026', '\u2028': '\\u2028', '\u2029': '\\u2029',
})[char]);
const categoryData = JSON.stringify(Object.fromEntries(Object.entries(categories).filter(([key]) => counts[key] > 0)));
const countData = JSON.stringify(counts);
const categoryTabs = Object.entries(categories).filter(([key]) => counts[key] > 0)
  .map(([key, label]) => '<button type="button" data-category="' + key + '" aria-pressed="false">' + label + '<span class="tab-total">' + counts[key] + '</span></button>')
  .join('\n    ');
const html = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>자료 도감 · 매직 서바이벌 팬게임</title>
<link rel="icon" type="image/png" href="assets/icon.png">
<style>
@font-face{font-family:MagicSurvival;src:url('assets/magicSurvival.ttf') format('truetype');font-display:swap}
:root{color-scheme:dark;font-family:system-ui,-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif;background:#020302;color:#f0f2eb}
*{box-sizing:border-box}body{margin:0;min-width:320px}a{color:#68dfd3}a:hover{text-decoration-thickness:2px}
button,input{font:inherit}button:focus-visible,input:focus-visible,a:focus-visible{outline:2px solid #6ceadd;outline-offset:3px}
header,main{max-width:1180px;margin:auto;padding:24px clamp(16px,4vw,40px)}header{border-bottom:1px solid #29352f}
.back{display:inline-block;margin-bottom:24px;color:#d8e1d8;text-decoration:none}
.eyebrow{font-family:MagicSurvival,serif;color:#5fe6d9;font-size:22px;margin:0 0 2px}
h1{font-size:clamp(30px,5vw,50px);font-weight:700;letter-spacing:-.04em;margin:0 0 12px}
.intro{color:#b7c1b6;line-height:1.7;margin:0;max-width:68ch}
.controls{display:grid;gap:18px;margin:0 0 20px}
.search{display:grid;gap:8px;color:#d9e1d8}.search input{width:100%;padding:13px 14px;background:#0b100c;border:1px solid #607367;color:#f0f2eb;min-height:48px}
.tab-wrap{min-width:0}.tabs{display:flex;gap:8px;flex-wrap:wrap}.tabs button{padding:10px 14px;min-height:44px;border:1px solid #49594d;background:#080c09;color:#dfe8e0;cursor:pointer}
.tabs button[aria-pressed=true]{background:#56cabe;color:#020302;border-color:#56cabe;font-weight:700}.tab-total{font-size:12px;opacity:.8;margin-left:5px}
.swipe-hint{display:none;margin:3px 0 0;color:#a9beb4;font-size:12px}
.check{display:flex;align-items:center;gap:9px;width:max-content;max-width:100%;cursor:pointer;color:#d9e1d8}.check input{width:20px;height:20px;accent-color:#56cabe}
.count{color:#b8c8bd;margin:0 0 18px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:12px;list-style:none;padding:0;margin:0}
.card{min-width:0;background:#080a08;border:1px solid #3a493c;padding:14px;display:grid;align-content:start;gap:9px}.image-link{display:grid;place-items:center;min-height:104px;background:#000;overflow:hidden}
.card img{display:block;width:96px;height:96px;object-fit:contain}.card.subjects img{image-rendering:pixelated}
.card.maps,.card.screenshots{grid-column:span 2}.card.maps .image-link,.card.screenshots .image-link{height:320px}.card.maps img,.card.screenshots img{width:100%;height:100%;object-fit:contain}
.card h2{font-size:16px;line-height:1.4;margin:0;overflow-wrap:anywhere}.english,.file,.description{margin:0;color:#a9b7ac;font-size:13px;line-height:1.5;overflow-wrap:anywhere}.file{font-size:12px;color:#aab6ac}.badge{width:max-content;border:1px solid #5c6a5c;padding:3px 7px;color:#c8d3c9;font-size:12px}.badge.live{border-color:#68dfd3;color:#68dfd3}.description{color:#dfe8e0}.links{display:flex;gap:14px;flex-wrap:wrap;font-size:13px;margin-top:4px}
.empty{padding:38px 20px;text-align:center;border:1px dashed #607367;color:#b8c8bd}
@media(max-width:700px){.tabs{flex-wrap:nowrap;overflow-x:auto;overscroll-behavior-inline:contain;scrollbar-color:#56cabe #101510;padding-bottom:8px}.tabs button{flex:none}.swipe-hint{display:block}}
@media(max-width:420px){header,main{padding:20px 16px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.card{padding:10px}.card img{width:78px;height:78px}.card.maps .image-link,.card.screenshots .image-link{height:270px}}
</style>
</head>
<body>
<header><a class="back" href="./">← 게임으로</a><p class="eyebrow">Magic Survival</p><h1>원작 이미지 자료관</h1><p class="intro">수집한 이미지 ${icons.length}개를 구역·실험체·적·마법 등으로 살펴보세요. 참조 스크린샷은 플레이 가능한 맵이나 게임용 배경 원본을 뜻하지 않습니다.</p></header>
<main>
<div class="controls">
  <label class="search">이름 또는 파일명 검색<input id="search" type="search" placeholder="한글·영문·일본어·파일명" autocomplete="off"></label>
  <div class="tab-wrap">
    <div class="tabs" role="group" aria-label="자료 종류">
      <button type="button" data-category="all" aria-pressed="true">전체<span class="tab-total">${icons.length}</span></button>
      ${categoryTabs}
    </div>
    <p class="swipe-hint" aria-hidden="true">분류를 옆으로 밀어보세요 →</p>
  </div>
  <label class="check"><input id="implemented" type="checkbox">현재 전투에 구현된 항목만 보기</label>
</div>
<p class="count" id="count" aria-live="polite"></p>
<ul class="grid" id="grid"></ul>
<p class="empty" id="empty" hidden>검색 결과가 없습니다. 검색어나 분류를 바꿔 보세요.</p>
</main>
<script>
const icons = ${data};
const labels = ${categoryData};
const categoryCounts = ${countData};
const typeLabels = {
  'zone-selection-screenshot':'구역 선택 스크린샷',
  'zone-overview-screenshot':'구역 요약 화면',
  'subject-portrait':'실험체 이미지',
  'class-portrait':'클래스 아이콘',
  'enemy-reference':'적 참조 이미지',
  'boss-reference':'보스 참조 이미지',
  'gameplay-screenshot':'게임 화면',
  'official-screenshot':'공식 스크린샷',
  'reference-screenshot':'참조 화면',
  'community-chart':'팬 제작 비교표',
  'map-comparison':'구역 비교 이미지',
  'research-icon':'연구 아이콘',
  'passive-icon':'패시브 아이콘',
  'synergy-icon':'시너지 아이콘',
  'field-item-reference':'필드 아이템 참조 이미지',
  'app-icon':'앱 아이콘',
};
const grid = document.getElementById('grid');
const search = document.getElementById('search');
const checkbox = document.getElementById('implemented');
const count = document.getElementById('count');
const empty = document.getElementById('empty');
const buttons = [...document.querySelectorAll('[data-category]')];
let category = categoryCounts.maps ? 'maps' : 'all';
const safeSource = value => { try { const url = new URL(value); return url.protocol === 'https:' ? url.href : ''; } catch { return ''; } };
function matches(icon, query, selected, implementedOnly) {
  return (selected === 'all' || icon.category === selected)
    && (!implementedOnly || icon.implemented)
    && [icon.name, icon.english, icon.filename, labels[icon.category], icon.assetType, ...(icon.searchNames || [])].some(value => String(value ?? '').toLocaleLowerCase().includes(query));
}
function render() {
  const query = search.value.trim().toLocaleLowerCase();
  const visible = icons.filter(icon => matches(icon, query, category, checkbox.checked));
  const fragment = document.createDocumentFragment();
  for (const icon of visible) {
    const card = document.createElement('li'); card.className = 'card ' + icon.category;
    const imageLink = document.createElement('a'); imageLink.className = 'image-link'; imageLink.href = icon.path;
    imageLink.target = '_blank'; imageLink.rel = 'noopener noreferrer'; imageLink.setAttribute('aria-label', icon.name + ' 원본 이미지 열기');
    const img = document.createElement('img'); img.src = icon.path; img.alt = icon.name + ' ' + (typeLabels[icon.assetType] || icon.assetType); img.loading = 'lazy'; imageLink.append(img); card.append(imageLink);
    const badge = document.createElement('span'); badge.className = 'badge' + (icon.implemented ? ' live' : ''); badge.textContent = icon.implemented ? '전투 구현' : icon.reference ? '참조 자료' : '아이콘 자료'; card.append(badge);
    const title = document.createElement('h2'); title.textContent = icon.name; card.append(title);
    if (icon.english !== icon.name) { const en = document.createElement('p'); en.className = 'english'; en.textContent = icon.english; card.append(en); }
    const meta = document.createElement('p'); meta.className = 'file'; meta.textContent = labels[icon.category] + ' · ' + (typeLabels[icon.assetType] || icon.assetType) + (icon.reference ? '' : ' · ' + icon.filename); card.append(meta);
    if (icon.description) { const detail = document.createElement('p'); detail.className = 'description'; detail.textContent = icon.description; card.append(detail); }
    const links = document.createElement('div'); links.className = 'links';
    const original = document.createElement('a'); original.href = icon.path; original.target = '_blank'; original.rel = 'noopener noreferrer'; original.textContent = '원본 보기'; links.append(original);
    const source = safeSource(icon.sourcePage || icon.source);
    if (source) { const anchor = document.createElement('a'); anchor.href = source; anchor.target = '_blank'; anchor.rel = 'noopener noreferrer'; anchor.textContent = '출처 보기'; links.append(anchor); }
    card.append(links);
    fragment.append(card);
  }
  grid.replaceChildren(fragment);
  count.textContent = '표시 중 ' + visible.length + '개 / 전체 ' + icons.length + '개';
  empty.hidden = visible.length > 0;
}
for (const button of buttons) button.addEventListener('click', () => {
  category = button.dataset.category;
  for (const tab of buttons) tab.setAttribute('aria-pressed', String(tab === button));
  render();
});
for (const button of buttons) button.setAttribute('aria-pressed', String(button.dataset.category === category));
search.addEventListener('input', render);
checkbox.addEventListener('change', render);
render();
</script>
</body>
</html>
`;
await writeFile(new URL('atlas.html', root), html);
console.log(`atlas.html built: ${icons.length} images, ${icons.filter(icon => icon.implemented).length} implemented`);
