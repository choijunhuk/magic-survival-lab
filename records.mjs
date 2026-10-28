export const RECORD_KEY = 'magic-survival-records-v2';
const LEGACY_KEY = 'magic-survival-best';
const empty = () => ({ version: 2, quick: null, expedition: null });

function valid(record, duration, legacy = false) {
  return record && Number.isFinite(record.time) && record.time >= 0 && record.time <= duration
    && Number.isSafeInteger(record.kills) && record.kills >= 0
    && (legacy || (['death', 'timeout', 'boss-defeated', 'survived'].includes(record.endReason)
      && typeof record.bossDefeated === 'boolean'));
}

export function loadRecords(storage) {
  const records = empty();
  try {
    const current = JSON.parse(storage.getItem(RECORD_KEY));
    if (current?.version === 2) {
      if (valid(current.quick, 300)) records.quick = current.quick;
      if (valid(current.expedition, 600)) records.expedition = current.expedition;
    }
  } catch { /* Storage may be blocked or contain malformed JSON. */ }
  if (!records.quick) {
    try {
      const legacy = JSON.parse(storage.getItem(LEGACY_KEY));
      if (valid(legacy, 300, true)) records.quick = { time: legacy.time, kills: legacy.kills, endReason: null, bossDefeated: null };
    } catch { /* Keep the run playable without a record. */ }
  }
  return { records };
}

function better(next, previous, mode) {
  if (!previous) return true;
  if (mode === 'expedition') {
    const won = next.endReason === 'boss-defeated';
    const previousWon = previous.endReason === 'boss-defeated';
    if (won !== previousWon) return won;
    if (won && next.time !== previous.time) return next.time < previous.time;
  }
  return next.time > previous.time || (next.time === previous.time && next.kills > previous.kills);
}

export function recordRun(storage, records, run) {
  const mode = run.mode;
  if (!['quick', 'expedition'].includes(mode) || !valid(run, mode === 'quick' ? 300 : 600)) return { records, updated: false, saved: false };
  if (!better(run, records[mode], mode)) return { records, updated: false, saved: true };
  const next = { ...records, [mode]: { time: run.time, kills: run.kills, endReason: run.endReason, bossDefeated: run.bossDefeated } };
  try {
    storage.setItem(RECORD_KEY, JSON.stringify(next));
    return { records: next, updated: true, saved: true };
  } catch {
    return { records: next, updated: true, saved: false };
  }
}
