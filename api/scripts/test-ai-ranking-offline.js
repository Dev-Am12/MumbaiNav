import { summarizeCandidateForPrompt, buildRankingPrompt, validateRankingResponse } from '../src/services/aiRanking.js';

let passed = 0, failed = 0;
function assert(label, condition, detail = '') {
  if (condition) { passed++; console.log(`  PASS  ${label}`); }
  else { failed++; console.log(`  FAIL  ${label}  ${detail}`); }
}

const mockCandidates = [
  {
    route_id: 'via_bandra_bus',
    via: 'via_bandra',
    last_mile_mode: 'bus',
    total_duration_seconds: 2250,
    min_bikes_available: null,
    steps: [
      { mode: 'train', crowd_density: 0.91 },
      { mode: 'walk' },
      { mode: 'bus', crowd_density: 0.35 },
    ],
  },
  {
    route_id: 'via_bandra_bike',
    via: 'via_bandra',
    last_mile_mode: 'bike',
    total_duration_seconds: 2300,
    min_bikes_available: 1,
    steps: [
      { mode: 'train', crowd_density: 0.91 },
      { mode: 'walk' },
      { mode: 'bike', bikes_available: 1 },
      { mode: 'walk' },
    ],
  },
];

console.log('--- summarizeCandidateForPrompt ---');
const line1 = summarizeCandidateForPrompt(mockCandidates[0]);
console.log(`  ${line1}`);
assert('includes route_id', line1.includes('via_bandra_bus'));
assert('includes ETA in minutes', line1.includes('37.5 min'));
assert('includes train crowd', line1.includes('train crowd: 0.91'));
assert('includes bus crowd', line1.includes('bus crowd: 0.35'));
assert('does NOT include a bikes-available line (this route has none)', !line1.includes('bikes available'));

const line2 = summarizeCandidateForPrompt(mockCandidates[1]);
console.log(`  ${line2}`);
assert('low-bike route surfaces the bikes-available figure', line2.includes('bikes available: 1'));

console.log('\n--- buildRankingPrompt ---');
const prompt = buildRankingPrompt(mockCandidates, { destination: 'BKC Bus Stop (RBI, SW)', departureTime: '14:00' });
console.log(prompt);
assert('prompt mentions the destination', prompt.includes('BKC Bus Stop (RBI, SW)'));
assert('prompt lists both route_ids', prompt.includes('via_bandra_bus') && prompt.includes('via_bandra_bike'));
assert('prompt explicitly instructs treating very-low-bike routes as unreliable', prompt.toLowerCase().includes('unreliable'));
assert('prompt asks for structured JSON only', prompt.includes('structured JSON'));

console.log('\n--- validateRankingResponse ---');
const goodResponse = {
  ranked_routes: [
    { route_id: 'via_bandra_bus', rank: 1, reason: 'Bike option only has 1 bike left, risky.' },
    { route_id: 'via_bandra_bike', rank: 2, reason: 'Slightly faster on paper but unreliable bike availability.' },
  ],
  top_choice_reason: 'The bus route is nearly as fast and does not depend on bike availability.',
};
let threw = false;
try { validateRankingResponse(goodResponse, mockCandidates); } catch (e) { threw = true; }
assert('valid response passes without throwing', !threw);

const missingRoute = { ranked_routes: [{ route_id: 'via_bandra_bus', rank: 1, reason: 'x' }], top_choice_reason: 'x' };
let caughtMissing = false;
try { validateRankingResponse(missingRoute, mockCandidates); } catch (e) { caughtMissing = e.message.includes('missing a ranking'); }
assert('catches a response that omits a known route_id', caughtMissing);

const hallucinatedRoute = {
  ranked_routes: [
    { route_id: 'via_bandra_bus', rank: 1, reason: 'x' },
    { route_id: 'via_kurla_bus', rank: 2, reason: 'this route_id was never sent to the model' },
  ],
  top_choice_reason: 'x',
};
let caughtHallucinated = false;
try { validateRankingResponse(hallucinatedRoute, mockCandidates); } catch (e) { caughtHallucinated = e.message.includes('unknown route_id'); }
assert('catches a response that invents a route_id never sent to it', caughtHallucinated);

const missingReason = { ranked_routes: goodResponse.ranked_routes, top_choice_reason: '' };
let caughtMissingReason = false;
try { validateRankingResponse(missingReason, mockCandidates); } catch (e) { caughtMissingReason = e.message.includes('top_choice_reason'); }
assert('catches a missing top_choice_reason', caughtMissingReason);

console.log(`\n${passed} passed, ${failed} failed`);
process.exit(failed > 0 ? 1 : 0);
