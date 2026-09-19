import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { pool, query } from '../config/database.js';
import { logger } from '../utils/logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

export async function runMigrations(): Promise<void> {
  const client = await pool.connect();
  try {
    logger.info('Checking and applying database migrations...');

    // Create migrations tracking table
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
      );
    `);

    const migrationsDir = path.join(__dirname, 'migrations');
    if (!fs.existsSync(migrationsDir)) {
      logger.warn(`Migrations directory not found at ${migrationsDir}`);
      return;
    }

    const files = fs.readdirSync(migrationsDir)
      .filter((file) => file.endsWith('.sql'))
      .sort();

    for (const file of files) {
      const version = file;
      const res = await client.query('SELECT 1 FROM schema_migrations WHERE version = $1', [version]);
      
      if (res.rowCount === 0) {
        logger.info(`Applying migration: ${file}`);
        const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
        
        await client.query('BEGIN');
        try {
          await client.query(sql);
          await client.query('INSERT INTO schema_migrations (version) VALUES ($1)', [version]);
          await client.query('COMMIT');
          logger.info(`Successfully applied migration: ${file}`);
        } catch (err) {
          await client.query('ROLLBACK');
          logger.error({ err, file }, `Failed to apply migration: ${file}`);
          throw err;
        }
      } else {
        logger.debug(`Migration ${file} already applied.`);
      }
    }

    logger.info('Database migrations are up to date.');
  } finally {
    client.release();
  }
}

// Auto-run when executed directly
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  runMigrations()
    .then(() => {
      logger.info('Migration run completed.');
      process.exit(0);
    })
    .catch((err) => {
      logger.error({ err }, 'Migration run failed.');
      process.exit(1);
    });
}
