// Offline test for the Temporal A* engine. Mirrors the real seeded
import { temporalAStar, heuristicSeconds, expectedWaitSeconds, restrictGraph, BKC_DESTINATIONS } from '../src/services/routingEngine.js';

const STATIONS = [
  ['Andheri', 19.1171747947178, 72.8465039707666],
  ['Bandra', 19.0555892333471, 72.8403282370921],
  ['Kurla', 19.0654774786936, 72.8793543303778],
  ['Bandra Station Bus Stop', 19.054996, 72.842047],
  ['Kurla Station Bus Stop', 19.067222, 72.878998],
  ['BKC Bus Stop (RBI, SW)', 19.057894, 72.853113],
  ['BKC Bus Stop (Diamond Bourse, NE)', 19.066511, 72.865906],
  ['Bandra Station Bike Dock', 19.0552, 72.8423],
  ['Kurla Station Bike Dock', 19.0674, 72.8793],
  ['BKC Bike Dock (Central)', 19.0622, 72.8595],
  ['Dadar (Western)', 19.0195608762157, 72.8431374888969],
  ['Dadar (Central)', 19.0181435365389, 72.843633420996],
];

const stations = new Map();
const nameToId = new Map();
STATIONS.forEach(([name, lat, lon], i) => {
  const id = i + 1;
  stations.set(id, { id, name, lat, lon });
  nameToId.set(name, id);
});
const N = (name) => nameToId.get(name);

const RAW_EDGES = [
  // [from, to, mode, duration_s, distance_m, profile]
  ['Andheri', 'Bandra', 'train', 780, 6900, 'frequent_trunk'],
  ['Bandra', 'Andheri', 'train', 780, 6900, 'frequent_trunk'],
  ['Andheri', 'Dadar (Western)', 'train', 1200, 10840, 'frequent_trunk'],
  ['Dadar (Western)', 'Andheri', 'train', 1200, 10840, 'frequent_trunk'],
  ['Dadar (Central)', 'Kurla', 'train', 720, 6460, 'frequent_trunk'],
  ['Kurla', 'Dadar (Central)', 'train', 720, 6460, 'frequent_trunk'],
  ['Andheri', 'Kurla', 'train', 1980, 16000, 'sparse_harbour'],
  ['Kurla', 'Andheri', 'train', 1980, 16000, 'sparse_harbour'],
  ['Dadar (Western)', 'Dadar (Central)', 'walk', 360, 250, null],
  ['Dadar (Central)', 'Dadar (Western)', 'walk', 360, 250, null],
  ['Bandra', 'Bandra Station Bus Stop', 'walk', 180, 200, null],
  ['Bandra Station Bus Stop', 'Bandra', 'walk', 180, 200, null],
  ['Bandra', 'Bandra Station Bike Dock', 'walk', 120, 150, null],
  ['Bandra Station Bike Dock', 'Bandra', 'walk', 120, 150, null],
  ['Kurla', 'Kurla Station Bus Stop', 'walk', 180, 200, null],
  ['Kurla Station Bus Stop', 'Kurla', 'walk', 180, 200, null],
  ['Kurla', 'Kurla Station Bike Dock', 'walk', 120, 150, null],
  ['Kurla Station Bike Dock', 'Kurla', 'walk', 120, 150, null],
  ['Bandra Station Bus Stop', 'BKC Bus Stop (RBI, SW)', 'bus', 450, 1200, 'bus_corridor'],
  ['BKC Bus Stop (RBI, SW)', 'Bandra Station Bus Stop', 'bus', 450, 1200, 'bus_corridor'],
  ['Kurla Station Bus Stop', 'BKC Bus Stop (Diamond Bourse, NE)', 'bus', 480, 1370, 'bus_corridor'],
  ['BKC Bus Stop (Diamond Bourse, NE)', 'Kurla Station Bus Stop', 'bus', 480, 1370, 'bus_corridor'],
  ['Bandra Station Bike Dock', 'BKC Bike Dock (Central)', 'bike', 540, 1960, null],
  ['BKC Bike Dock (Central)', 'Bandra Station Bike Dock', 'bike', 540, 1960, null],
  ['Kurla Station Bike Dock', 'BKC Bike Dock (Central)', 'bike', 600, 2160, null],
  ['BKC Bike Dock (Central)', 'Kurla Station Bike Dock', 'bike', 600, 2160, null],

  ['BKC Bike Dock (Central)', 'BKC Bus Stop (RBI, SW)', 'walk', 620, 820, null],
  ['BKC Bus Stop (RBI, SW)', 'BKC Bike Dock (Central)', 'walk', 620, 820, null],
  ['BKC Bike Dock (Central)', 'BKC Bus Stop (Diamond Bourse, NE)', 'walk', 620, 820, null],
  ['BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)', 'walk', 620, 820, null],
];

const PROFILE_BANDS = {
  frequent_trunk: [
    ['00:00:00', 8], ['08:00:00', 4], ['10:00:00', 8], ['18:00:00', 4], ['20:00:00', 8],
  ],
  bus_corridor: [
    ['00:00:00', 20], ['08:00:00', 10], ['10:00:00', 20], ['18:00:00', 10], ['20:00:00', 20],
  ],
  sparse_harbour: [['00:00:00', 150]],
};

const adjacency = new Map();
for (const id of stations.keys()) adjacency.set(id, []);
const schedulesByEdge = new Map();

RAW_EDGES.forEach(([from, to, mode, duration, distance, profile], i) => {
  const edge = {
    id: i + 1,
    from_station_id: N(from),
    to_station_id: N(to),
    mode,
    base_duration_seconds: duration,
    distance_meters: distance,
  };
  adjacency.get(edge.from_station_id).push(edge);
  if (profile) {
    schedulesByEdge.set(
      edge.id,
      PROFILE_BANDS[profile].map(([departure_time, frequency_minutes]) => ({ departure_time, frequency_minutes }))
    );
  }
});

const graph = { stations, adjacency, schedulesByEdge };

// ---- assertions ----
let passed = 0, failed = 0;
function assert(label, condition, detail = '') {
  if (condition) {
    passed++;
    console.log(`  PASS  ${label}`);
  } else {
    failed++;
    console.log(`  FAIL  ${label}  ${detail}`);
  }
}

function clockAt(hh, mm) {
  const d = new Date('2026-06-22T00:00:00'); // a Monday, arbitrary
  d.setHours(hh, mm, 0, 0);
  return d;
}

console.log('--- Heuristic sanity ---');
const directDist = heuristicSeconds(stations, N('Andheri'), [N('Bandra')]);
assert('heuristic(Andheri, Bandra) is a positive number of seconds', directDist > 0 && directDist < 780,
  `got ${directDist.toFixed(0)}s, must be < the real 780s edge cost to stay admissible`);

console.log('\n--- Wait-time bands ---');
const trunkEdgeId = RAW_EDGES.findIndex(e => e[0] === 'Andheri' && e[1] === 'Bandra') + 1;
const peakWait = expectedWaitSeconds(schedulesByEdge, trunkEdgeId, clockAt(9, 0));
const offPeakWait = expectedWaitSeconds(schedulesByEdge, trunkEdgeId, clockAt(14, 0));
assert('peak wait (4min freq) = 120s', peakWait === 120, `got ${peakWait}`);
assert('off-peak wait (8min freq) = 240s', offPeakWait === 240, `got ${offPeakWait}`);

const walkEdgeId = RAW_EDGES.findIndex(e => e[2] === 'walk') + 1;
assert('walk edges have zero wait', expectedWaitSeconds(schedulesByEdge, walkEdgeId, clockAt(9, 0)) === 0);

console.log('\n--- Single-leg route: Andheri -> Bandra ---');
const r1 = temporalAStar(graph, N('Andheri'), N('Bandra'), clockAt(9, 0));
assert('route found', r1 !== null);
assert('1 step', r1.steps.length === 1, `got ${r1.steps.length}`);
assert('total = wait(120) + travel(780) = 900s', r1.total_duration_seconds === 900, `got ${r1.total_duration_seconds}`);

console.log('\n--- Corridor strategies: via Bandra (restricted subgraph) ---');
const VIA_BANDRA = ['Andheri', 'Bandra', 'Bandra Station Bus Stop', 'Bandra Station Bike Dock', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'];
const VIA_KURLA = ['Andheri', 'Kurla', 'Dadar (Western)', 'Dadar (Central)', 'Kurla Station Bus Stop', 'Kurla Station Bike Dock', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'];

const bandraSub = restrictGraph(graph, VIA_BANDRA.map(N));
const kurlaSub = restrictGraph(graph, VIA_KURLA.map(N));

assert('via-Bandra subgraph has no Kurla node (prevents cross-interchange shortcut)', !bandraSub.stations.has(N('Kurla')));
assert('via-Kurla subgraph has no Bandra node', !kurlaSub.stations.has(N('Bandra')));

const bandraToRBI = temporalAStar(bandraSub, N('Andheri'), N('BKC Bus Stop (RBI, SW)'), clockAt(14, 0));
const bandraToBike = temporalAStar(bandraSub, N('Andheri'), N('BKC Bike Dock (Central)'), clockAt(14, 0));
console.log(`  via Bandra -> RBI:        ${(bandraToRBI.total_duration_seconds / 60).toFixed(1)} min, mode chosen: ${bandraToRBI.steps[bandraToRBI.steps.length - 1].mode} (last leg)`);
console.log(`  via Bandra -> Bike Dock:  ${(bandraToBike.total_duration_seconds / 60).toFixed(1)} min`);
assert('both via-Bandra destinations reachable', bandraToRBI !== null && bandraToBike !== null);

console.log('\n--- Mode-locked strategies: does bus vs. bike to RBI surface as TWO separate candidates? ---');
const bandraBusOnlySub = restrictGraph(graph, ['Andheri', 'Bandra', 'Bandra Station Bus Stop', 'BKC Bus Stop (RBI, SW)'].map(N));
const bandraBikeOnlySub = restrictGraph(graph, ['Andheri', 'Bandra', 'Bandra Station Bike Dock', 'BKC Bike Dock (Central)', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)'].map(N));

const rbiViaBus = temporalAStar(bandraBusOnlySub, N('Andheri'), N('BKC Bus Stop (RBI, SW)'), clockAt(14, 0));
const rbiViaBike = temporalAStar(bandraBikeOnlySub, N('Andheri'), N('BKC Bus Stop (RBI, SW)'), clockAt(14, 0));

console.log(`  RBI via bus:  ${(rbiViaBus.total_duration_seconds / 60).toFixed(1)} min — ${rbiViaBus.steps.map(s => s.mode).join('->')}`);
console.log(`  RBI via bike: ${(rbiViaBike.total_duration_seconds / 60).toFixed(1)} min — ${rbiViaBike.steps.map(s => s.mode).join('->')}`);
assert('both reach RBI', rbiViaBus !== null && rbiViaBike !== null);
assert('bus route actually uses a bus leg', rbiViaBus.steps.some(s => s.mode === 'bus'));
assert('bike route actually uses a bike leg (and ends with a walk, not a bus)', rbiViaBike.steps.some(s => s.mode === 'bike') && rbiViaBike.steps[rbiViaBike.steps.length - 1].mode === 'walk');
assert('the two modes are genuinely close in cost, not a token alternative (gap < 5 min)',
  Math.abs(rbiViaBus.total_duration_seconds - rbiViaBike.total_duration_seconds) < 300,
  `gap = ${Math.abs(rbiViaBus.total_duration_seconds - rbiViaBike.total_duration_seconds)}s`);

console.log('\n--- No loop-bug regression: via-Bandra search never touches a Kurla node ---');
const allBandraDestinations = ['BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)']
  .map(name => temporalAStar(bandraSub, N('Andheri'), N(name), clockAt(14, 0)));
const touchesKurlaSide = allBandraDestinations.some(r => r.steps.some(s =>
  s.from_station.includes('Kurla') || s.to_station.includes('Kurla') || s.from_station.includes('Dadar') || s.to_station.includes('Dadar')
));
assert('none of the via-Bandra routes touch Kurla/Dadar, even with the wider BKC node set', !touchesKurlaSide);

console.log('\n--- Corridor strategies: via Kurla, OFF-PEAK 14:00 (the interesting one) ---');
const kurlaToDiamond = temporalAStar(kurlaSub, N('Andheri'), N('BKC Bus Stop (Diamond Bourse, NE)'), clockAt(14, 0));
console.log(`  Chosen path: ${kurlaToDiamond.steps.map(s => `${s.from_station}--${s.mode}(wait ${s.wait_seconds}s)-->${s.to_station}`).join(' | ')}`);
console.log(`  Total: ${(kurlaToDiamond.total_duration_seconds / 60).toFixed(1)} min`);
const usesDirectHarbour = kurlaToDiamond.steps.some(s => s.travel_seconds === 1980);
const usesDadarTransfer = kurlaToDiamond.steps.some(s => s.from_station === 'Dadar (Western)' || s.to_station === 'Dadar (Western)');
assert(
  'within the via-Kurla subgraph, A* correctly avoids the sparse direct Harbour train (75min avg wait) in favor of the via-Dadar transfer',
  usesDadarTransfer && !usesDirectHarbour,
  `direct=${usesDirectHarbour}, viaDadar=${usesDadarTransfer}`
);
assert('no leftover bike-loop-through-BKC artifact (subgraph restriction prevents it)',
  !kurlaToDiamond.steps.some(s => s.mode === 'bike'));

console.log('\n--- Same via-Kurla question, but PEAK 09:00 (trunk lines faster, does the answer change?) ---');
const kurlaToDiamondPeak = temporalAStar(kurlaSub, N('Andheri'), N('BKC Bus Stop (Diamond Bourse, NE)'), clockAt(9, 0));
console.log(`  Total at peak: ${(kurlaToDiamondPeak.total_duration_seconds / 60).toFixed(1)} min — still via-Dadar (peak only makes the trunk legs faster, the sparse train's ~75min average wait doesn't change with time of day in this model)`);

console.log('\n--- Reverse direction: BKC (RBI stop) -> Andheri, PEAK 09:00 ---');
const r2 = temporalAStar(graph, N('BKC Bus Stop (RBI, SW)'), N('Andheri'), clockAt(9, 0));
assert('reverse route found', r2 !== null);
assert('reverse route ends at Andheri', r2.steps[r2.steps.length - 1].to_station === 'Andheri');

console.log('\n--- findRoutesToDestination mirror: does EVERY strategy reach EVERY BKC destination now? ---');
const ALL_FOUR_STRATEGIES = {
  via_bandra_bus: ['Andheri', 'Bandra', 'Bandra Station Bus Stop', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'],
  via_bandra_bike: ['Andheri', 'Bandra', 'Bandra Station Bike Dock', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'],
  via_kurla_bus: ['Andheri', 'Kurla', 'Dadar (Western)', 'Dadar (Central)', 'Kurla Station Bus Stop', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'],
  via_kurla_bike: ['Andheri', 'Kurla', 'Dadar (Western)', 'Dadar (Central)', 'Kurla Station Bike Dock', 'BKC Bus Stop (RBI, SW)', 'BKC Bus Stop (Diamond Bourse, NE)', 'BKC Bike Dock (Central)'],
};
for (const destName of BKC_DESTINATIONS) {
  const results = Object.entries(ALL_FOUR_STRATEGIES).map(([stratName, nodes]) => {
    const sub = restrictGraph(graph, nodes.map(N));
    const r = temporalAStar(sub, N('Andheri'), N(destName), clockAt(14, 0));
    return { stratName, minutes: r ? (r.total_duration_seconds / 60).toFixed(1) : null };
  });
  console.log(`  -> ${destName}:`);
  results.forEach(r => console.log(`       ${r.stratName}: ${r.minutes ?? 'UNREACHABLE'} min`));
  assert(`all 4 strategies reach "${destName}"`, results.every(r => r.minutes !== null));
}

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
