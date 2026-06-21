import { GoogleGenAI } from '@google/genai';

const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';

const RANKING_RESPONSE_SCHEMA = {
  type: 'object',
  properties: {
    ranked_routes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          route_id: { type: 'string' },
          rank: { type: 'integer' },
          reason: { type: 'string' },
        },
        required: ['route_id', 'rank', 'reason'],
      },
    },
    top_choice_reason: { type: 'string' },
  },
  required: ['ranked_routes', 'top_choice_reason'],
};

// ============================================================
// Pure functions — no network access, fully unit-testable.
// ============================================================
export function summarizeCandidateForPrompt(candidate) {
  const etaMin = (candidate.total_duration_seconds / 60).toFixed(1);
  const parts = [`route_id: ${candidate.route_id}`, `ETA: ${etaMin} min`, `last-mile mode: ${candidate.last_mile_mode}`];

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
  const routeLines = candidates.map((c) => `${candidates.indexOf(c) + 1}. ${summarizeCandidateForPrompt(c)}`).join('\n');

  const prompt = `You are a transit routing assistant for MumbaiNav, helping a commuter travel from Andheri to ${destination} in Mumbai, departing around ${departureTime}.

Given the candidate routes below and their current real-time conditions, rank them from best to worst for the commuter and provide a one-sentence reason for each. A route with very low bikes available (0-1) should generally be treated as unreliable even if its on-paper ETA is fastest — the commuter may not actually be able to get a bike. A route with high train or bus crowd density (above ~0.8) is uncomfortable but still usable; weigh it as a real but lesser downside compared to a route that isn't actually rideable.

Routes:
${routeLines}

Respond with structured JSON only: a ranked_routes array (each with route_id, rank starting at 1, and a one-sentence reason) covering every route_id listed above exactly once, plus a top_choice_reason summarizing why the #1 pick was chosen over the alternatives.`;

  return prompt;
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

// ============================================================
// The only function that actually calls the network.
// ============================================================

export async function rankRoutesWithAI(candidates, { destination, departureTime }) {
  if (!process.env.GEMINI_API_KEY) {
    throw new Error('GEMINI_API_KEY is not set — copy .env.example and add your key from Google AI Studio');
  }
  if (candidates.length === 0) {
    throw new Error('no candidates to rank');
  }

  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });
  const prompt = buildRankingPrompt(candidates, { destination, departureTime });

  const response = await ai.models.generateContent({
    model: GEMINI_MODEL,
    contents: prompt,
    config: {
      responseMimeType: 'application/json',
      responseSchema: RANKING_RESPONSE_SCHEMA,
    },
  });

  let parsed;
  try {
    parsed = JSON.parse(response.text);
  } catch (err) {
    throw new Error(`AI response was not valid JSON: ${err.message}`);
  }

  validateRankingResponse(parsed, candidates);
  return parsed;
}
