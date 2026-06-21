import { pool } from '../db.js';

const HEURISTIC_MAX_SPEED_MPS = (60 * 1000) / 3600;

export const BKC_DESTINATIONS = [
  'BKC Bus Stop (RBI, SW)',
  'BKC Bus Stop (Diamond Bourse, NE)',
  'BKC Bike Dock (Central)',
];

const ALL_BKC_NODES = ['BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'];

const ROUTE_STRATEGIES = [
  {
    name: 'via_bandra_bus',
    via: 'via_bandra',
    last_mile_mode: 'bus',
    nodes: ['Andheri', 'Bandra', 'Bandra Station Bus Stop', ...ALL_BKC_NODES],
  },
  {
    name: 'via_bandra_bike',
    via: 'via_bandra',
    last_mile_mode: 'bike',
    nodes: ['Andheri', 'Bandra', 'Bandra Station Bike Dock', ...ALL_BKC_NODES],
  },
  {
    name: 'via_kurla_bus',
    via: 'via_kurla',
    last_mile_mode: 'bus',
    nodes: ['Andheri', 'Kurla', 'Dadar (Western)', 'Dadar (Central)', 'Kurla Station Bus Stop', ...ALL_BKC_NODES],
  },
  {
    name: 'via_kurla_bike',
    via: 'via_kurla',
    last_mile_mode: 'bike',
    nodes: ['Andheri', 'Kurla', 'Dadar (Western)', 'Dadar (Central)', 'Kurla Station Bike Dock', ...ALL_BKC_NODES],
  },
];

export function restrictGraph(graph, allowedIds) {
  const allowed = new Set(allowedIds);
  const stations = new Map([...graph.stations].filter(([id]) => allowed.has(id)));
  const adjacency = new Map();
  for (const id of allowed) adjacency.set(id, []);
  for (const [id, edges] of graph.adjacency) {
    if (!allowed.has(id)) continue;
    adjacency.set(id, edges.filter((e) => allowed.has(e.to_station_id)));
  }
  return { stations, adjacency, schedulesByEdge: graph.schedulesByEdge };
}

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

export function heuristicSeconds(stations, fromId, goalIds) {
  const from = stations.get(fromId);
  let minMeters = Infinity;
  for (const goalId of goalIds) {
    const goal = stations.get(goalId);
    const d = haversineMeters(from.lat, from.lon, goal.lat, goal.lon);
    if (d < minMeters) minMeters = d;
  }
  return minMeters / HEURISTIC_MAX_SPEED_MPS;
}

function timeStringToSeconds(t) {
  const [h, m, s] = t.split(':').map(Number);
  return h * 3600 + m * 60 + (s || 0);
}

function secondsOfDay(date) {
  return date.getHours() * 3600 + date.getMinutes() * 60 + date.getSeconds();
}

export function expectedWaitSeconds(schedulesByEdge, edgeId, arrivalDate) {
  const bands = schedulesByEdge.get(edgeId);
  if (!bands || bands.length === 0) return 0;

  const nowSec = secondsOfDay(arrivalDate);
  let applicable = bands[bands.length - 1]; // wraps to the last band pre-midnight
  for (const band of bands) {
    if (timeStringToSeconds(band.departure_time) <= nowSec) applicable = band;
  }
  return (applicable.frequency_minutes * 60) / 2;
}

class PriorityQueue {
  constructor() {
    this.items = [];
  }
  push(item) {
    this.items.push(item);
  }
  pop() {
    let minIdx = 0;
    for (let i = 1; i < this.items.length; i++) {
      if (this.items[i].f < this.items[minIdx].f) minIdx = i;
    }
    return this.items.splice(minIdx, 1)[0];
  }
  isEmpty() {
    return this.items.length === 0;
  }
}

function reconstructPath(graph, cameFrom, originId, destinationId, gScore, departureDate) {
  const steps = [];
  let cur = destinationId;
  while (cur !== originId) {
    const link = cameFrom.get(cur);
    steps.unshift({ edge: link.edge, fromId: link.fromId, toId: cur, wait: link.wait });
    cur = link.fromId;
  }

  let clock = new Date(departureDate.getTime());
  const detailedSteps = steps.map((step) => {
    const departAt = new Date(clock.getTime() + step.wait * 1000);
    const arriveAt = new Date(departAt.getTime() + step.edge.base_duration_seconds * 1000);
    clock = arriveAt;
    return {
      edge_id: step.edge.id,
      from_station_id: step.fromId,
      to_station_id: step.toId,
      from_station: graph.stations.get(step.fromId).name,
      to_station: graph.stations.get(step.toId).name,
      mode: step.edge.mode,
      wait_seconds: Math.round(step.wait),
      travel_seconds: step.edge.base_duration_seconds,
      distance_meters: step.edge.distance_meters,
      depart_at: departAt.toISOString(),
      arrive_at: arriveAt.toISOString(),
    };
  });

  return {
    destination_station_id: destinationId,
    destination_name: graph.stations.get(destinationId).name,
    total_duration_seconds: Math.round(gScore.get(destinationId)),
    departure_time: departureDate.toISOString(),
    arrival_time: clock.toISOString(),
    steps: detailedSteps,
  };
}

export function temporalAStar(graph, originId, destinationId, departureDate) {
  const { stations, adjacency, schedulesByEdge } = graph;

  const gScore = new Map([[originId, 0]]);
  const cameFrom = new Map();
  const visited = new Set();

  const open = new PriorityQueue();
  open.push({ id: originId, f: heuristicSeconds(stations, originId, [destinationId]) });

  while (!open.isEmpty()) {
    const current = open.pop();
    if (visited.has(current.id)) continue;
    visited.add(current.id);

    if (current.id === destinationId) {
      return reconstructPath(graph, cameFrom, originId, destinationId, gScore, departureDate);
    }

    const elapsedSoFar = gScore.get(current.id);
    const currentClock = new Date(departureDate.getTime() + elapsedSoFar * 1000);

    for (const edge of adjacency.get(current.id) || []) {
      if (visited.has(edge.to_station_id)) continue;

      const wait = expectedWaitSeconds(schedulesByEdge, edge.id, currentClock);
      const tentativeG = elapsedSoFar + wait + edge.base_duration_seconds;

      if (!gScore.has(edge.to_station_id) || tentativeG < gScore.get(edge.to_station_id)) {
        gScore.set(edge.to_station_id, tentativeG);
        cameFrom.set(edge.to_station_id, { edge, fromId: current.id, wait });
        const h = heuristicSeconds(stations, edge.to_station_id, [destinationId]);
        open.push({ id: edge.to_station_id, f: tentativeG + h });
      }
    }
  }

  return null; // destination unreachable from origin
}

// ============================================================
// DB-loading wrapper
// ============================================================

async function loadGraph() {
  const [stationsRes, edgesRes, schedulesRes] = await Promise.all([
    pool.query(
      `SELECT id, name, type, line, ST_X(geom::geometry) AS lon, ST_Y(geom::geometry) AS lat FROM stations`
    ),
    pool.query(
      `SELECT id, from_station_id, to_station_id, mode, base_duration_seconds, distance_meters FROM edges`
    ),
    pool.query(`SELECT edge_id, departure_time, frequency_minutes FROM schedules ORDER BY edge_id, departure_time`),
  ]);

  const stations = new Map(stationsRes.rows.map((s) => [s.id, s]));

  const adjacency = new Map();
  for (const id of stations.keys()) adjacency.set(id, []);
  for (const edge of edgesRes.rows) {
    adjacency.get(edge.from_station_id).push(edge);
  }

  const schedulesByEdge = new Map();
  for (const row of schedulesRes.rows) {
    if (!schedulesByEdge.has(row.edge_id)) schedulesByEdge.set(row.edge_id, []);
    schedulesByEdge.get(row.edge_id).push(row);
  }

  return { stations, adjacency, schedulesByEdge };
}

function findStationIdByName(stations, name) {
  for (const [id, s] of stations.entries()) {
    if (s.name === name) return id;
  }
  return null;
}

export async function findDirectRoute({ originName, destinationName, departureDate = new Date() }) {
  const graph = await loadGraph();

  const originId = findStationIdByName(graph.stations, originName);
  if (originId === null) throw new Error(`Unknown origin station: "${originName}"`);
  const destinationId = findStationIdByName(graph.stations, destinationName);
  if (destinationId === null) throw new Error(`Unknown destination station: "${destinationName}"`);

  return temporalAStar(graph, originId, destinationId, departureDate);
}

export async function findRoutesToDestination({ originName, destinationName, departureDate = new Date() }) {
  const graph = await loadGraph();

  const originId = findStationIdByName(graph.stations, originName);
  if (originId === null) throw new Error(`Unknown origin station: "${originName}"`);
  const destinationId = findStationIdByName(graph.stations, destinationName);
  if (destinationId === null) throw new Error(`Unknown destination station: "${destinationName}"`);

  const candidates = [];
  for (const strategy of ROUTE_STRATEGIES) {
    const allowedIds = strategy.nodes
      .map((name) => findStationIdByName(graph.stations, name))
      .filter((id) => id !== null);
    if (!allowedIds.includes(destinationId)) continue;

    const subgraph = restrictGraph(graph, allowedIds);
    const result = temporalAStar(subgraph, originId, destinationId, departureDate);
    if (result) {
      candidates.push({ ...result, route_id: strategy.name, via: strategy.via, last_mile_mode: strategy.last_mile_mode });
    }
  }

  candidates.sort((a, b) => a.total_duration_seconds - b.total_duration_seconds);

  return {
    origin: originName,
    destination: destinationName,
    departure_time: departureDate.toISOString(),
    candidates,
  };
}

export async function findRoutes({ originName, departureDate = new Date() }) {
  const graph = await loadGraph();

  const originId = findStationIdByName(graph.stations, originName);
  if (originId === null) throw new Error(`Unknown origin station: "${originName}"`);

  const candidates = [];
  for (const strategy of ROUTE_STRATEGIES) {
    const allowedIds = strategy.nodes
      .map((name) => findStationIdByName(graph.stations, name))
      .filter((id) => id !== null);
    const subgraph = restrictGraph(graph, allowedIds);

    const destinationIds = BKC_DESTINATIONS
      .map((name) => findStationIdByName(graph.stations, name))
      .filter((id) => id !== null && allowedIds.includes(id));

    for (const destId of destinationIds) {
      const result = temporalAStar(subgraph, originId, destId, departureDate);
      if (result) {
        candidates.push({ ...result, via: strategy.via, last_mile_mode: strategy.last_mile_mode });
      }
    }
  }

  candidates.sort((a, b) => a.total_duration_seconds - b.total_duration_seconds);

  return {
    origin: originName,
    departure_time: departureDate.toISOString(),
    candidates,
  };
}
