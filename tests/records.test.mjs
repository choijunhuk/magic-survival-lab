import test from 'node:test';
import assert from 'node:assert/strict';
import { loadRecords, recordRun, RECORD_KEY } from '../records.mjs';

function storage(initial = {}) {
  const data = new Map(Object.entries(initial));
  return {
    data,
    getItem: key => data.get(key) ?? null,
    setItem: (key, value) => data.set(key, value),
  };
}

test('valid legacy quick result migrates without inventing its outcome or deleting it', () => {
  const store = storage({ 'magic-survival-best': JSON.stringify({ time: 215.5, kills: 32 }) });
  const { records } = loadRecords(store);
  assert.deepEqual(records.quick, { time: 215.5, kills: 32, endReason: null, bossDefeated: null });
  assert.equal(records.expedition, null);
  const result = recordRun(store, records, { mode: 'expedition', time: 517, kills: 80, endReason: 'death', bossDefeated: false });
  assert.equal(result.saved, true);
  assert.equal(JSON.parse(store.data.get(RECORD_KEY)).version, 2);
  assert.equal(store.data.get('magic-survival-best'), JSON.stringify({ time: 215.5, kills: 32 }));
});

test('corrupt records are ignored and storage errors stay playable', () => {
  assert.equal(loadRecords(storage({ [RECORD_KEY]: '{', 'magic-survival-best': '{' })).records.quick, null);
  assert.equal(loadRecords(storage({ [RECORD_KEY]: '{', 'magic-survival-best': '{"time":42,"kills":7}' })).records.quick.time, 42);
  const blocked = { getItem: () => { throw Error('blocked'); }, setItem: () => { throw Error('blocked'); } };
  const loaded = loadRecords(blocked);
  assert.equal(loaded.records.quick, null);
  const result = recordRun(blocked, loaded.records, { mode: 'quick', time: 20, kills: 3, endReason: 'death', bossDefeated: false });
  assert.equal(result.saved, false);
  assert.equal(result.records.quick.time, 20);
});

test('quick and expedition records rank independently with expedition wins ahead of longer losses', () => {
  const store = storage();
  let records = loadRecords(store).records;
  for (const run of [
    { mode: 'expedition', time: 599, kills: 80, endReason: 'timeout', bossDefeated: false },
    { mode: 'quick', time: 100, kills: 10, endReason: 'death', bossDefeated: false },
    { mode: 'expedition', time: 550, kills: 5, endReason: 'boss-defeated', bossDefeated: true },
    { mode: 'expedition', time: 540, kills: 3, endReason: 'boss-defeated', bossDefeated: true },
    { mode: 'quick', time: 100, kills: 11, endReason: 'death', bossDefeated: false },
  ]) records = recordRun(store, records, run).records;
  assert.deepEqual([records.quick.time, records.quick.kills], [100, 11]);
  assert.deepEqual([records.expedition.time, records.expedition.kills, records.expedition.endReason], [540, 3, 'boss-defeated']);
  records = recordRun(store, records, { mode: 'expedition', time: 540, kills: 4, endReason: 'boss-defeated', bossDefeated: true }).records;
  assert.equal(records.expedition.kills, 4);
  assert.equal(recordRun(store, records, { mode: 'expedition', time: 600, kills: 999, endReason: 'timeout', bossDefeated: false }).updated, false);
});
