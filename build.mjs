import { readFile, writeFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const root = new URL('./', import.meta.url);
const read = path => readFile(new URL(path, root), 'utf8');
const [html, css, core, controls, game, catalogSource] = await Promise.all([
  read('index.html'), read('style.css'), read('core.mjs'), read('controls.mjs'), read('game.js'), read('assets/catalog.json'),
]);
assert.match(game, /^import .*from '\.\/core\.mjs';/);
assert.ok(html.includes('<link rel="stylesheet" href="style.css">'));
assert.ok(html.includes('<script type="module" src="game.js"></script>'));
const script = [core, controls].map(source => source.replace(/^export /gm, '')).join('\n') + '\n' + game.replace(/^import[^\n]+\n/gm, '');
assert.doesNotMatch(script, /^\s*(import|export) /m);
let standalone = html
  .replace('<link rel="stylesheet" href="style.css">', () => `<style>\n${css}\n</style>`)
  .replace('<script type="module" src="game.js"></script>', () => `<script type="module">\n${script}\n</script>`);
const catalog = JSON.parse(catalogSource);
const usedPaths = [...new Set(standalone.match(/assets\/[\w/.-]+\.png/g))];
const usedAssets = usedPaths.map(path => {
  const item = catalog.files.find(entry => entry.file === path);
  assert.ok(item, `Untracked game asset: ${path}`);
  return item;
});
for (const item of usedAssets) {
  const image = await readFile(new URL(item.file, root));
  standalone = standalone.replaceAll(item.file, `data:image/png;base64,${image.toString('base64')}`);
}
assert.doesNotMatch(standalone, /(?:src|href)="(?:assets\/|game\.js|style\.css)/);
await writeFile(new URL('play.html', root), standalone);
await writeFile(new URL('assets/sources.json', root), JSON.stringify({ project: catalog.project, repository: catalog.repository, commit: catalog.commit, files: usedAssets }, null, 2) + '\n');
await import('./build-atlas.mjs');
console.log(`play.html built: ${Math.round(Buffer.byteLength(standalone) / 1024)} KB, ${usedAssets.length} assets, no server required`);
