import assert from 'node:assert/strict';
import { access, readFile, writeFile } from 'node:fs/promises';
import * as core from './core.mjs';

const root = new URL('./', import.meta.url);
const catalog = JSON.parse(await readFile(new URL('assets/catalog.json', root), 'utf8'));
const names = JSON.parse(await readFile(new URL('assets/display-names.json', root), 'utf8')).names;
const categories = {
  magicImages: ['마법', 58],
  artifactImages: ['유물', 153],
  passiveImages: ['패시브', 30],
  researchImages: ['연구', 20],
};
const implemented = new Map();
for (const item of [...(core.UPGRADES ?? []), ...(core.FUSIONS ?? []), ...(core.ARTIFACTS ?? [])]) {
  if (item.icon) implemented.set(item.icon, item);
}
const counts = Object.fromEntries(Object.keys(categories).map(key => [key, 0]));
const icons = [];
for (const { file, kind } of catalog.files) {
  const match = /^assets\/(magicImages|artifactImages|passiveImages|researchImages)\/([^/]+)\.png$/.exec(file);
  if (!match) continue;
  assert.equal(kind, 'image', `Not an image: ${file}`);
  await access(new URL(file, root));
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
    ...(game?.description ? { description: game.description } : {}),
  });
  counts[category]++;
}
assert.equal(icons.length, 261);
assert.equal(new Set(icons.map(icon => icon.path)).size, icons.length);
for (const [key, [, count]] of Object.entries(categories)) assert.equal(counts[key], count, key);

// Escape script terminators and HTML-significant characters before embedding JSON.
const data = JSON.stringify(icons).replace(/[<>&\u2028\u2029]/g, char => ({
  '<': '\\u003c', '>': '\\u003e', '&': '\\u0026', '\u2028': '\\u2028', '\u2029': '\\u2029',
})[char]);
const html = `<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>자료 도감 · 매직 서바이벌 팬게임</title>
<style>
:root{color-scheme:dark;font-family:system-ui,-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif;background:#0b1016;color:#e2e8e5}
*{box-sizing:border-box}body{margin:0;min-width:320px}a{color:#d9b66f}a:hover{text-decoration-thickness:2px}
button,input{font:inherit}button:focus-visible,input:focus-visible,a:focus-visible{outline:3px solid #80d4d1;outline-offset:3px}
header,main{max-width:1120px;margin:auto;padding:24px clamp(16px,4vw,40px)}header{border-bottom:1px solid #354653}
.back{display:inline-block;margin-bottom:22px;text-decoration:none}h1{font-family:Georgia,serif;font-size:clamp(28px,5vw,42px);font-weight:normal;color:#d9b66f;margin:0 0 8px}
.intro{color:#b8c6c8;line-height:1.6;margin:0}.controls{display:grid;gap:18px;margin:0 0 22px}
.search{display:grid;gap:8px;color:#b8c6c8}.search input{width:100%;padding:13px 14px;background:#111b25;border:1px solid #536372;border-radius:8px;color:#e2e8e5}
.tabs{display:flex;gap:8px;flex-wrap:wrap}.tabs button{padding:9px 15px;border:1px solid #536372;border-radius:999px;background:#172330;color:#e2e8e5;cursor:pointer}
.tabs button[aria-pressed=true]{background:#d9b66f;color:#0b1016;border-color:#d9b66f;font-weight:700}.check{display:flex;align-items:center;gap:9px;width:max-content;max-width:100%;cursor:pointer}.check input{width:18px;height:18px;accent-color:#d9b66f}
.count{color:#b8c6c8;margin:0 0 18px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:14px;list-style:none;padding:0;margin:0}
.card{min-width:0;background:#111b25;border:1px solid #354653;border-radius:12px;padding:17px;display:grid;align-content:start;gap:10px}.card img{display:block;width:84px;height:84px;object-fit:contain;margin:auto}
.card h2{font-size:16px;line-height:1.4;margin:0;overflow-wrap:anywhere}.english,.file,.description{margin:0;color:#b8c6c8;font-size:13px;line-height:1.5;overflow-wrap:anywhere}.file{color:#91a6ad}.badge{width:max-content;border:1px solid #63757d;border-radius:999px;padding:3px 8px;color:#b8c6c8;font-size:12px}.badge.live{border-color:#d9b66f;color:#d9b66f}.description{color:#e2e8e5}
.empty{padding:38px 20px;text-align:center;border:1px dashed #536372;border-radius:12px;color:#b8c6c8}
@media(max-width:420px){header,main{padding:20px 16px}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.card{padding:12px}.card img{width:72px;height:72px}}
</style>
</head>
<body>
<header><a class="back" href="play.html">← 전투 화면으로</a><h1>자료 도감</h1><p class="intro">매직 서바이벌 팬게임 · 보유한 아이콘 261개를 살펴보세요. “전투 구현”은 현재 게임에서 효과가 작동하는 항목입니다.</p></header>
<main>
<div class="controls">
  <label class="search">이름 또는 파일명 검색<input id="search" type="search" placeholder="한글·영문·파일명" autocomplete="off"></label>
  <div class="tabs" role="group" aria-label="자료 종류">
    <button type="button" data-category="all" aria-pressed="true">전체</button>
    <button type="button" data-category="magicImages" aria-pressed="false">마법</button>
    <button type="button" data-category="artifactImages" aria-pressed="false">유물</button>
    <button type="button" data-category="passiveImages" aria-pressed="false">패시브</button>
    <button type="button" data-category="researchImages" aria-pressed="false">연구</button>
  </div>
  <label class="check"><input id="implemented" type="checkbox">전투 구현만 보기</label>
</div>
<p class="count" id="count" aria-live="polite"></p>
<ul class="grid" id="grid"></ul>
<p class="empty" id="empty" hidden>검색 결과가 없습니다. 검색어나 분류를 바꿔 보세요.</p>
</main>
<script>
const icons = ${data};
const labels = {magicImages:'마법',artifactImages:'유물',passiveImages:'패시브',researchImages:'연구'};
const grid = document.getElementById('grid');
const search = document.getElementById('search');
const checkbox = document.getElementById('implemented');
const count = document.getElementById('count');
const empty = document.getElementById('empty');
const buttons = [...document.querySelectorAll('[data-category]')];
let category = 'all';
function matches(icon, query, selected, implementedOnly) {
  return (selected === 'all' || icon.category === selected)
    && (!implementedOnly || icon.implemented)
    && [icon.name, icon.english, icon.filename].some(value => value.toLocaleLowerCase().includes(query));
}
function render() {
  const query = search.value.trim().toLocaleLowerCase();
  const visible = icons.filter(icon => matches(icon, query, category, checkbox.checked));
  const fragment = document.createDocumentFragment();
  for (const icon of visible) {
    const card = document.createElement('li'); card.className = 'card';
    const img = document.createElement('img'); img.src = icon.path; img.alt = icon.name + ' 아이콘'; img.loading = 'lazy'; img.width = 84; img.height = 84; card.append(img);
    const badge = document.createElement('span'); badge.className = 'badge' + (icon.implemented ? ' live' : ''); badge.textContent = icon.implemented ? '전투 구현' : '보유 자료'; card.append(badge);
    const title = document.createElement('h2'); title.textContent = icon.name; card.append(title);
    if (icon.english !== icon.name) { const en = document.createElement('p'); en.className = 'english'; en.textContent = icon.english; card.append(en); }
    const meta = document.createElement('p'); meta.className = 'file'; meta.textContent = labels[icon.category] + ' · ' + icon.filename; card.append(meta);
    if (icon.description) { const detail = document.createElement('p'); detail.className = 'description'; detail.textContent = icon.description; card.append(detail); }
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
search.addEventListener('input', render);
checkbox.addEventListener('change', render);
console.assert(icons.length === 261 && icons.filter(icon => matches(icon, '', 'magicImages', false)).length === 58);
render();
</script>
</body>
</html>
`;
await writeFile(new URL('atlas.html', root), html);
console.log(`atlas.html built: ${icons.length} icons, ${icons.filter(icon => icon.implemented).length} implemented`);
