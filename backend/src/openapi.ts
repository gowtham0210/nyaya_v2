import { writeFileSync } from 'node:fs';
import { buildOpenApi, createApp } from './app.setup.js';
import { loadConfig } from './core/config.js';

// Writes the contract to openapi.json (in-memory database, nothing persisted).
const app = await createApp(
  { ...loadConfig({}), databaseUrl: undefined, pgliteDir: undefined },
  { logger: false },
);
await app.init();
writeFileSync(
  'openapi.json',
  JSON.stringify(buildOpenApi(app), null, 2) + '\n',
);
await app.close();
console.log('Wrote openapi.json');
