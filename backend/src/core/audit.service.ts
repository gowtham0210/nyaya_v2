import { Injectable } from '@nestjs/common';
import { auditLog } from '../db/schema.js';
import type { Tx } from './db.js';
import { newId } from './ids.js';

export interface Actor {
  id: string;
  requestId: string;
}

export interface AuditEntry {
  action: string;
  entityType: string;
  entityId?: string;
  data?: Record<string, unknown>;
}

/** Writes the append-only audit log, inside the caller's transaction. */
@Injectable()
export class AuditService {
  async record(tx: Tx, actor: Actor | null, entry: AuditEntry) {
    await tx.insert(auditLog).values({
      id: newId(),
      actorId: actor?.id ?? null,
      requestId: actor?.requestId ?? null,
      ...entry,
    });
  }
}
