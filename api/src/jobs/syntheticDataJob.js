import { updateCrowdDensity } from '../services/crowdDensityGenerator.js';
import { updateBikeAvailability } from '../services/bikeAvailabilityGenerator.js';
import { io } from '../server.js';

const TICK_INTERVAL_MS = 15_000;

let intervalHandle = null;

async function tick() {
  try {
    const [density, bikes] = await Promise.all([
      updateCrowdDensity(),
      updateBikeAvailability(),
    ]);
    io.emit('live_conditions_update', {
      timestamp: Date.now(),
      density_updated: true,
      bikes_updated: true,
    });
    console.log(
      `[synthetic-data] tick @ ${density.timestamp} — crowd_density: ${density.updated} edges (peak=${density.peak}), bike_availability: ${bikes.updated} docks (peak=${bikes.peak})`
    );
  } catch (err) {
    console.error('[synthetic-data] tick failed:', err.message);
  }
}

export function startSyntheticDataJob() {
  tick(); // run once immediately
  intervalHandle = setInterval(tick, TICK_INTERVAL_MS);
  console.log(`[synthetic-data] job started, ticking every ${TICK_INTERVAL_MS / 1000}s`);
}

export function stopSyntheticDataJob() {
  if (intervalHandle) clearInterval(intervalHandle);
}
