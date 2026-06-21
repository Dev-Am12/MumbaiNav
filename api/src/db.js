import pg from 'pg';
import dotenv from 'dotenv';

dotenv.config();

const { Pool } = pg;

if (!process.env.DATABASE_URL) {
  console.warn(
    '[db] DATABASE_URL is not set. Copy .env.example to .env and fill in your Supabase connection string.'
  );
}

// Supabase requires SSL. rejectUnauthorized: false is the standard setting for
// Supabase's connection pooler — their cert chain isn't always in Node's default
// trust store, and this is the documented approach for connecting from app code.
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: process.env.DATABASE_URL?.includes('localhost')
    ? false
    : { rejectUnauthorized: false },
});

pool.on('error', (err) => {
  console.error('[db] Unexpected error on idle client', err);
});
