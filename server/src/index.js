'use strict';

/**
 * When R U Free — optional thin server.
 *
 * The Flutter app is local-first and does NOT need this server for the MVP.
 * It exists for two future jobs (see README in this folder):
 *
 *  1. Microsoft Graph token swap: keep the client secret server-side while
 *     the app only ever holds a refresh token (no-data-stored architecture).
 *  2. Shared overlap computation for clients that prefer a REST call over
 *     the in-app AvailabilityService (same algorithm, mirrored in JS).
 *
 * Run:  npm install && npm start   (listens on PORT, default 3000)
 */

const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json({ limit: '256kb' }));

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'whenrufree-server', time: new Date().toISOString() });
});

/**
 * POST /api/overlap
 * Body: {
 *   "timetables": { "Ava": [{weekday,startMin,endMin}], ... },
 *   "weekdays": [1,2,3,4,5],
 *   "windowStartMin": 480, "windowEndMin": 1080, "minDurationMin": 30
 * }
 * Returns ranked mutual free slots across the week.
 */
app.post('/api/overlap', (req, res) => {
  try {
    const {
      timetables = {},
      weekdays = [1, 2, 3, 4, 5],
      windowStartMin = 480,
      windowEndMin = 1080,
      minDurationMin = 30,
    } = req.body || {};

    const results = [];
    for (const day of weekdays) {
      const eachFree = Object.entries(timetables).map(([who, lessons]) =>
        freeIntervals((lessons || []).filter((l) => l.weekday === day), windowStartMin, windowEndMin, who),
      );
      const mutual = intersectAll(eachFree, day).filter(
        (s) => s.endMin - s.startMin >= minDurationMin,
      );
      results.push(...mutual);
    }
    results.sort((a, b) => b.endMin - b.startMin - (a.endMin - a.startMin));
    res.json({ slots: results.slice(0, 20) });
  } catch (err) {
    res.status(400).json({ error: String(err && err.message || err) });
  }
});

function freeIntervals(lessons, winStart, winEnd, who) {
  const busy = lessons
    .map((l) => ({ start: Math.max(l.startMin, winStart), end: Math.min(l.endMin, winEnd) }))
    .filter((b) => b.end > b.start)
    .sort((a, b) => a.start - b.start);
  const merged = [];
  for (const b of busy) {
    const last = merged[merged.length - 1];
    if (!last || b.start > last.end) merged.push({ ...b });
    else last.end = Math.max(last.end, b.end);
  }
  const free = [];
  let cursor = winStart;
  for (const b of merged) {
    if (b.start > cursor) free.push({ startMin: cursor, endMin: b.start, whoFree: [who] });
    cursor = Math.max(cursor, b.end);
  }
  if (cursor < winEnd) free.push({ startMin: cursor, endMin: winEnd, whoFree: [who] });
  return free;
}

function intersectTwo(a, b, weekday) {
  const out = [];
  let i = 0, j = 0;
  while (i < a.length && j < b.length) {
    const s = Math.max(a[i].startMin, b[j].startMin);
    const e = Math.min(a[i].endMin, b[j].endMin);
    if (e > s) {
      out.push({ weekday, startMin: s, endMin: e, whoFree: [...new Set([...a[i].whoFree, ...b[j].whoFree])] });
    }
    if (a[i].endMin < b[j].endMin) i++; else j++;
  }
  return out;
}

function intersectAll(each, weekday) {
  if (!each.length) return [];
  let acc = each[0];
  for (let k = 1; k < each.length; k++) {
    acc = intersectTwo(acc, each[k], weekday);
    if (!acc.length) break;
  }
  return acc;
}

// POST /api/graph/refresh (STUB) — swaps a refresh token for an access token
// server-side so the client secret never ships in the app. Requires env:
//   MS_CLIENT_ID, MS_CLIENT_SECRET, MS_TENANT (common|tenant-id)
app.post('/api/graph/refresh', (req, res) => {
  res.status(501).json({
    error: 'Not configured. Set MS_CLIENT_ID/MS_CLIENT_SECRET/MS_TENANT and implement the token swap. The app works without this until Microsoft 365 sync ships.',
  });
});

const PORT = process.env.PORT || 3000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`whenrufree-server listening on :${PORT}`));
}

module.exports = { app, freeIntervals, intersectAll };
