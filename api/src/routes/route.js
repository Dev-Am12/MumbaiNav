import { Router } from 'express';
import { findRoutes, findDirectRoute, findRoutesToDestination, BKC_DESTINATIONS } from '../services/routingEngine.js';
import { enrichWithLiveConditions } from '../services/liveConditions.js';
import { rankRoutesWithAI } from '../services/aiRanking.js';

const router = Router();

function parseDepartureDate(timeParam) {
  if (!timeParam) return new Date();
  const [hh, mm] = timeParam.split(':').map(Number);
  if (Number.isNaN(hh) || Number.isNaN(mm)) {
    throw new Error('time must be in HH:MM format, e.g. 09:30');
  }
  const d = new Date();
  d.setHours(hh, mm, 0, 0);
  return d;
}

router.get('/', async (req, res) => {
  try {
    const from = req.query.from || 'Andheri';
    const departureDate = parseDepartureDate(req.query.time);
    const result = await findRoutes({ originName: from, departureDate });
    res.json(result);
  } catch (err) {
    console.error('[route] query failed:', err.message);
    res.status(400).json({ status: 'error', message: err.message });
  }
});

router.get('/direct', async (req, res) => {
  try {
    const { from, to } = req.query;
    if (!from || !to) {
      return res.status(400).json({ status: 'error', message: 'both from and to query params are required' });
    }
    const departureDate = parseDepartureDate(req.query.time);
    const result = await findDirectRoute({ originName: from, destinationName: to, departureDate });
    if (!result) {
      return res.status(404).json({ status: 'error', message: `no route found from "${from}" to "${to}"` });
    }
    res.json(result);
  } catch (err) {
    console.error('[route/direct] query failed:', err.message);
    res.status(400).json({ status: 'error', message: err.message });
  }
});

router.get('/smart', async (req, res) => {
  try {
    const from = req.query.from || 'Andheri';
    const to = req.query.to || BKC_DESTINATIONS[0];
    const departureDate = parseDepartureDate(req.query.time);

    const raw = await findRoutesToDestination({ originName: from, destinationName: to, departureDate });
    if (raw.candidates.length === 0) {
      return res.status(404).json({ status: 'error', message: `no routes found from "${from}" to "${to}"` });
    }

    const enrichedCandidates = await enrichWithLiveConditions(raw.candidates);

    let ai;
    let aiError = null;
    try {
      ai = await rankRoutesWithAI(enrichedCandidates, {
        destination: to,
        departureTime: departureDate.toTimeString().slice(0, 5),
      });
    } catch (err) {
      console.error('[route/smart] AI ranking failed, returning raw candidates only:', err.message);
      aiError = err.message;
    }

    res.json({
      origin: from,
      destination: to,
      departure_time: departureDate.toISOString(),
      candidates: enrichedCandidates,
      ai_ranking: ai || null,
      ai_error: aiError,
    });
  } catch (err) {
    console.error('[route/smart] query failed:', err.message);
    res.status(400).json({ status: 'error', message: err.message });
  }
});

export default router;
