import { randomBytes } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { createApp } from '../src/app.setup.js';
import { loadConfig } from '../src/core/config.js';
import { DB, type Db } from '../src/core/db.js';
import { newId } from '../src/core/ids.js';
import { hashPassword } from '../src/auth/passwords.js';
import { subjects, topics, users, type Role } from '../src/db/schema.js';

export interface TestApp {
  app: INestApplication;
  db: Db;
  http: () => ReturnType<typeof request>;
  topicId: string;
  /** Creates a user with these roles and returns a signed-in session. */
  signInAs: (...roles: Role[]) => Promise<{
    id: string;
    token: string;
    refresh: string;
    email: string;
    password: string;
  }>;
  close: () => Promise<void>;
}

/** A fresh app on an in-memory database with one subject and topic. */
export async function startApp(
  overrides: { authRateLimitPerMinute?: number; trustProxyHops?: number } = {},
): Promise<TestApp> {
  const config = {
    ...loadConfig({}),
    authRateLimitPerMinute: 1000,
    ...overrides,
  };
  const app = await createApp(config, { logger: false });
  await app.init();
  const db = app.get<Db>(DB);
  const http = () => request(app.getHttpServer());

  const subjectId = newId();
  const topicId = newId();
  await db.insert(subjects).values({
    id: subjectId,
    slug: 'constitution',
    name: 'Constitution Basics',
  });
  await db.insert(topics).values({
    id: topicId,
    subjectId,
    slug: 'constitution-basics',
    name: 'Preamble and Parliament',
  });

  const signInAs = async (...roles: Role[]) => {
    const email = `${roles.join('-') || 'user'}-${randomBytes(4).toString('hex')}@test.local`;
    const password = randomBytes(12).toString('base64url');
    const id = newId();
    await db.insert(users).values({
      id,
      email,
      displayName: 'Test',
      passwordHash: await hashPassword(password),
      roles,
    });
    const res = await http()
      .post('/v1/auth/session')
      .send({ email, password })
      .expect(200);
    return {
      id,
      token: res.body.access_token as string,
      refresh: res.body.refresh_token as string,
      email,
      password,
    };
  };

  return { app, db, http, topicId, signInAs, close: () => app.close() };
}
