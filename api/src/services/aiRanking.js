import { GoogleGenAI } from '@google/genai';

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

// Human-readable names for every route_id in ROUTE_STRATEGIES.
// Used in the prompt so Gemini never references a raw route_id in prose,
// and as a sanitizer fallback if it does anyway.
const ROUTE_HUMAN_NAMES = {
  via_bandra_bus:  'Western Line train to Bandra, then BEST bus to BKC',
  via_bandra_bike: 'Western Line train to Bandra, then Yulu bike to BKC',
  via_kurla_bus:   'train via Kurla, then BEST bus to BKC',
  via_kurla_bike:  'train via Kurla, then Yulu bike to BKC',
};

// Sanitize AI text that accidentally leaks raw route_id values.
// Belt-and-suspenders: the prompt already forbids this, but this catches
// any slip-through before the text reaches the user's screen.
function sanitizeRouteIds(text) {
  if (!text) return text;
  let result = text;
  for (const [id, name] of Object.entries(ROUTE_HUMAN_NAMES)) {
    result = result.replace(new RegExp(`'?${id}'?`, 'gi'), name);
  }
  return result;
}

const RANKING_RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    ranked_routes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          route_id: { type: 'string' },
          rank:     { type: 'integer' },
          reason:   { type: 'string' },
        },
        required: ['route_id', 'rank', 'reason'],
      },
    },
    top_choice_reason: { type: 'string' },
  },
  required: ['ranked_routes', 'top_choice_reason'],
};

// ── Pure functions ────────────────────────────────────────────────────────────

export function summarizeCandidateForPrompt(candidate) {
  const etaMin    = (candidate.total_duration_seconds / 60).toFixed(1);
  const humanName = ROUTE_HUMAN_NAMES[candidate.route_id] || candidate.route_id;

  // Give Gemini both the route_id (needed for JSON) and a plain-English
  // description so it can write human-readable reasons without ever
  // repeating the route_id in its prose.
  const parts = [
    `route_id: ${candidate.route_id}`,
    `description: ${humanName}`,
    `ETA: ${etaMin} min`,
    `last-mile mode: ${candidate.last_mile_mode}`,
  ];

  const trainStep = candidate.steps.find((s) => s.mode === 'train' && s.crowd_density !== undefined);
  if (trainStep) parts.push(`train crowd: ${trainStep.crowd_density}`);

  const busStep = candidate.steps.find((s) => s.mode === 'bus' && s.crowd_density !== undefined);
  if (busStep) parts.push(`bus crowd: ${busStep.crowd_density}`);

  if (candidate.min_bikes_available !== null && candidate.min_bikes_available !== undefined) {
    parts.push(`bikes available: ${candidate.min_bikes_available}`);
  }

  return parts.join(' | ');
}

export function buildRankingPrompt(candidates, { destination, departureTime }) {
  const routeLines = candidates
    .map((c, i) => `${i + 1}. ${summarizeCandidateForPrompt(c)}`)
    .join('\n');

  return `You are a transit routing assistant for MumbaiNav, helping a commuter travel from Andheri to ${destination} in Mumbai, departing around ${departureTime}.

Given the candidate routes below and their current real-time conditions, rank them from best to worst and provide a one-sentence reason for each.

CRITICAL LANGUAGE RULES — follow these exactly or the output will be rejected:
- NEVER write a route_id value (e.g. "via_bandra_bus") in any reason or top_choice_reason. Use the route's "description" field or plain phrases like "the Bandra bus route" or "the Kurla bike option".
- Write every reason as if speaking directly to the commuter in plain English, not to a developer.
- A route with very low bikes available (0-1) is unreliable even if its ETA looks fast — the commuter may not get a bike.
- High crowd density (above 0.8) is uncomfortable but usable; weigh it as a lesser downside compared to a route that may not be rideable.

Routes:
${routeLines}

Respond with structured JSON only: a ranked_routes array (each entry has route_id, rank starting at 1, and a one-sentence commuter-friendly reason) covering every route_id exactly once, plus a top_choice_reason summarizing why the #1 pick beats the alternatives.`;
}

export function validateRankingResponse(parsed, candidates) {
  const knownIds = new Set(candidates.map((c) => c.route_id));
  if (!parsed || !Array.isArray(parsed.ranked_routes)) {
    throw new Error('AI response missing ranked_routes array');
  }
  const seenIds = new Set();
  for (const entry of parsed.ranked_routes) {
    if (!knownIds.has(entry.route_id)) {
      throw new Error(`AI response referenced unknown route_id "${entry.route_id}"`);
    }
    seenIds.add(entry.route_id);
  }
  for (const id of knownIds) {
    if (!seenIds.has(id)) {
      throw new Error(`AI response is missing a ranking for route_id "${id}"`);
    }
  }
  if (typeof parsed.top_choice_reason !== 'string' || parsed.top_choice_reason.length === 0) {
    throw new Error('AI response missing top_choice_reason');
  }
  return true;
}

// ── Network call ──────────────────────────────────────────────────────────────

export async function rankRoutesWithAI(candidates, { destination, departureTime }) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY is not set — copy .env.example and add your key');
  }
  if (candidates.length === 0) {
    throw new Error('no candidates to rank');
  }

  const ai     = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  const prompt = buildRankingPrompt(candidates, { destination, departureTime });

  const response = await ai.models.generateContent({
    model:    GEMINI_MODEL,
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      responseSchema:   RANKING_RESPONSE_SCHEMA,
    },
  });

  let parsed;
  try {
    parsed = JSON.parse(response.text);
  } catch (err) {
    throw new Error(`AI response was not valid JSON: ${err.message}`);
  }

  validateRankingResponse(parsed, candidates);

  // Sanitize any route_id leakage before text leaves the server
  parsed.top_choice_reason = sanitizeRouteIds(parsed.top_choice_reason);
  parsed.ranked_routes = parsed.ranked_routes.map((r) => ({
    ...r,
    reason: sanitizeRouteIds(r.reason),
  }));

  return parsed;
}