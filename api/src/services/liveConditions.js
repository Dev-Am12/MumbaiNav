import { pool } from '../db.js';

export async function enrichWithLiveConditions(candidates) {
  const edgeIds = new Set();
  const dockStationIds = new Set();

  for (const candidate of candidates) {
    for (const step of candidate.steps) {
      if (step.mode === 'train' || step.mode === 'bus') edgeIds.add(step.edge_id);
      if (step.mode === 'bike') dockStationIds.add(step.from_station_id);
    }
  }

  const [crowdRows, bikeRows] = await Promise.all([
    edgeIds.size > 0
      ? pool.query(
          `SELECT DISTINCT ON (edge_id) edge_id, density_score, timestamp
           FROM crowd_density
           WHERE edge_id = ANY($1::int[])
           ORDER BY edge_id, timestamp DESC`,
          [[...edgeIds]]
        )
      : { rows: [] },
    dockStationIds.size > 0
      ? pool.query(
          `SELECT DISTINCT ON (dock_station_id) dock_station_id, bikes_available, docks_total, timestamp
           FROM bike_availability
           WHERE dock_station_id = ANY($1::int[])
           ORDER BY dock_station_id, timestamp DESC`,
          [[...dockStationIds]]
        )
      : { rows: [] },
  ]);

  const crowdByEdge = new Map(crowdRows.rows.map((r) => [r.edge_id, r]));
  const bikeByStation = new Map(bikeRows.rows.map((r) => [r.dock_station_id, r]));

  return candidates.map((candidate) => {
    let minBikesOnRoute = null;
    const enrichedSteps = candidate.steps.map((step) => {
      const enriched = { ...step };
      if ((step.mode === 'train' || step.mode === 'bus') && crowdByEdge.has(step.edge_id)) {
        const row = crowdByEdge.get(step.edge_id);
        enriched.crowd_density = Number(row.density_score.toFixed(2));
        enriched.crowd_reading_at = row.timestamp;
      }
      if (step.mode === 'bike' && bikeByStation.has(step.from_station_id)) {
        const row = bikeByStation.get(step.from_station_id);
        enriched.bikes_available = row.bikes_available;
        enriched.docks_total = row.docks_total;
        if (minBikesOnRoute === null || row.bikes_available < minBikesOnRoute) {
          minBikesOnRoute = row.bikes_available;
        }
      }
      return enriched;
    });

    return {
      ...candidate,
      steps: enrichedSteps,
      min_bikes_available: minBikesOnRoute,
      max_crowd_density:
        enrichedSteps
          .map((s) => s.crowd_density)
          .filter((v) => v !== undefined)
          .reduce((max, v) => Math.max(max, v), 0) || null,
    };
  });
}
