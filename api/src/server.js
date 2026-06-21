import express from 'express';
import http from 'http';
import cors from 'cors';
import dotenv from 'dotenv';
import { Server } from 'socket.io';
import { pool } from './db.js';
import { startSyntheticDataJob } from './jobs/syntheticDataJob.js';
import routeRouter from './routes/route.js';

dotenv.config();

const app = express();
const httpServer = http.createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',
  },
});

app.use(cors());
app.use(express.json());

io.on('connection', (socket) => {
  console.log(`[socket.io] client connected: ${socket.id}`);
});

app.use('/route', routeRouter);

// Basic liveness check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// DB connectivity + PostGIS check
app.get('/health/db', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT NOW() AS time, PostGIS_Version() AS postgis_version'
    );
    res.json({ status: 'connected', ...result.rows[0] });
  } catch (err) {
    console.error('[health/db] query failed:', err.message);
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// Quick check once stations are seeded — count + a sample row
app.get('/health/stations', async (req, res) => {
  try {
    const count = await pool.query('SELECT COUNT(*) FROM stations');
    const sample = await pool.query(
      'SELECT id, name, type, line, ST_AsText(geom::geometry) AS geom_text FROM stations LIMIT 5'
    );
    res.json({
      total_stations: Number(count.rows[0].count),
      sample: sample.rows,
    });
  } catch (err) {
    console.error('[health/stations] query failed:', err.message);
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// density check
app.get('/health/crowd-density', async (req, res) => {
  try {
    const total = await pool.query('SELECT COUNT(*) FROM crowd_density');
    const latest = await pool.query(`
      SELECT DISTINCT ON (edge_id) edge_id, density_score, source, timestamp
      FROM crowd_density
      ORDER BY edge_id, timestamp DESC
    `);
    res.json({
      total_rows: Number(total.rows[0].count),
      latest_per_edge: latest.rows,
    });
  } catch (err) {
    console.error('[health/crowd-density] query failed:', err.message);
    res.status(500).json({ status: 'error', message: err.message });
  }
});

// bike count check
app.get('/health/bike-availability', async (req, res) => {
  try {
    const latest = await pool.query(`
      SELECT DISTINCT ON (dock_station_id) dock_station_id, bikes_available, docks_total, timestamp
      FROM bike_availability
      ORDER BY dock_station_id, timestamp DESC
    `);
    res.json({ latest_per_dock: latest.rows });
  } catch (err) {
    console.error('[health/bike-availability] query failed:', err.message);
    res.status(500).json({ status: 'error', message: err.message });
  }
});

const PORT = process.env.PORT || 4000;
httpServer.listen(PORT, () => {
  console.log(`MumbaiNav API listening on port ${PORT}`);
  startSyntheticDataJob();
});

export { app, httpServer, io };
