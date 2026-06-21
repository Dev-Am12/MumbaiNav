import { pool } from '../db.js';

// Peak windows shared with the schedules seed (03_schedules.sql) and the PRD
// (Section 6.3) — one definition of "peak" used everywhere in the system.
const PEAK_WINDOWS = [
  { start: 8 * 60, end: 10 * 60 },  // 08:00-10:00
  { start: 18 * 60, end: 20 * 60 }, // 18:00-20:00
];

function minutesSinceMidnight(date) {
  return date.getHours() * 60 + date.getMinutes();
}

export function isPeak(date = new Date()) {
  const m = minutesSinceMidnight(date);
  return PEAK_WINDOWS.some((w) => m >= w.start && m < w.end);
}

function randomInRange(min, max) {
  return min + Math.random() * (max - min);
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

// Base density by mode + time-of-day, per PRD Section 6.3.
// Note: the sparse direct Harbour-line edge (Andheri<->Kurla) uses the same
// curve as the other train edges — crowding reflects how full the carriage
// is, which doesn't depend on how often that particular service runs.
export function baseDensity(mode, peak) {
  if (mode === 'bus') {
    return peak ? randomInRange(0.4, 0.6) : randomInRange(0.15, 0.3);
  }
  return peak ? randomInRange(0.7, 0.95) : randomInRange(0.2, 0.4);
}

export function addVariance(score) {
  // ±0.1 so repeated demo runs don't look identical/scripted, per PRD Section 6.3
  return clamp(score + randomInRange(-0.1, 0.1), 0, 1);
}

export async function updateCrowdDensity() {
  const now = new Date();
  const peak = isPeak(now);

  const { rows: edgeRows } = await pool.query(
    `SELECT id, mode FROM edges WHERE mode IN ('train', 'bus')`
  );

  for (const edge of edgeRows) {
    const score = addVariance(baseDensity(edge.mode, peak));
    await pool.query(
      `INSERT INTO crowd_density (edge_id, density_score, source) VALUES ($1, $2, 'simulated')`,
      [edge.id, score]
    );
  }

  return { updated: edgeRows.length, peak, timestamp: now.toISOString() };
}
