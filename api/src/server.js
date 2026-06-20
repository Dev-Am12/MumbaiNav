import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { pool } from './db.js';

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

// Basic liveness check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// DB connectivity + PostGIS setup check
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

//seed check
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

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`MumbaiNav API listening on port ${PORT}`);
});
