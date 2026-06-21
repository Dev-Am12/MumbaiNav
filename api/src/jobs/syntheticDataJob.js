import { updateCrowdDensity } from '../services/crowdDensityGenerator.js';
import { updateBikeAvailability } from '../services/bikeAvailabilityGenerator.js';

// 45s — inside the PRD Section 6.3 "every 30-60 seconds" window.
// NOTE: this updates the DB tables only. Pushing changed values out over
// Socket.io is Day 4 scope (PRD Section 10) — wiring that in is just
// adding an io.emit() call inside tick() once the server has a socket
// instance, no structural change needed here.
const TICK_INTERVAL_MS = 45_000;

let intervalHandle = null;

async function tick() {
  try {
    const [density, bikes] = await Promise.all([
      updateCrowdDensity(),
      updateBikeAvailability(),
    ]);
    console.log(
      `[synthetic-data] tick @ ${density.timestamp} — crowd_density: ${density.updated} edges (peak=${density.peak}), bike_availability: ${bikes.updated} docks (peak=${bikes.peak})`
    );
  } catch (err) {
    console.error('[synthetic-data] tick failed:', err.message);
  }
}

export function startSyntheticDataJob() {
  tick(); // run once immediately so there's data right away, don't wait 45s
  intervalHandle = setInterval(tick, TICK_INTERVAL_MS);
  console.log(`[synthetic-data] job started, ticking every ${TICK_INTERVAL_MS / 1000}s`);
}

export function stopSyntheticDataJob() {
  if (intervalHandle) clearInterval(intervalHandle);
}
