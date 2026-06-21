import { pool } from '../db.js';

const DOCKS_TOTAL = 15;

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function minutesSinceMidnight(date) {
  return date.getHours() * 60 + date.getMinutes();
}

export function isPeakEgress(date = new Date()) {
  const m = minutesSinceMidnight(date);
  return (m >= 8 * 60 && m < 10 * 60) || (m >= 18 * 60 && m < 20 * 60);
}

export function nextBikeCount(current, peak) {
  const baseStep = Math.floor(Math.random() * 3) - 1; // -1, 0, or +1
  const bias = peak ? -1 : 1; // peak egress drains docks; off-peak they refill
  const biasApplies = Math.random() < 0.5;
  return clamp(current + baseStep + (biasApplies ? bias : 0), 0, DOCKS_TOTAL);
}

export async function updateBikeAvailability() {
  const now = new Date();
  const peak = isPeakEgress(now);

  const { rows: docks } = await pool.query(
    `SELECT id FROM stations WHERE type = 'bike_dock'`
  );

  for (const dock of docks) {
    const { rows: lastRows } = await pool.query(
      `SELECT bikes_available FROM bike_availability
       WHERE dock_station_id = $1
       ORDER BY timestamp DESC LIMIT 1`,
      [dock.id]
    );
    const current =
      lastRows.length > 0 ? lastRows[0].bikes_available : Math.floor(DOCKS_TOTAL / 2);

    const next = nextBikeCount(current, peak);

    await pool.query(
      `INSERT INTO bike_availability (dock_station_id, bikes_available, docks_total) VALUES ($1, $2, $3)`,
      [dock.id, next, DOCKS_TOTAL]
    );
  }

  return { updated: docks.length, peak, timestamp: now.toISOString() };
}
