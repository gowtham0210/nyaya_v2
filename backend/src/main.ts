import { existsSync } from 'node:fs';
import { buildOpenApi, createApp } from './app.setup.js';
import { loadConfig } from './core/config.js';
import { SwaggerModule } from '@nestjs/swagger';

if (existsSync('.env')) process.loadEnvFile('.env');
// Without DATABASE_URL, development keeps an embedded database in .data/.
if (!process.env.DATABASE_URL) process.env.PGLITE_DIR ??= '.data/pglite';

const config = loadConfig();
const app = await createApp(config);
if (!config.isProduction) SwaggerModule.setup('docs', app, buildOpenApi(app));
await app.listen(process.env.PORT ?? 3000);
