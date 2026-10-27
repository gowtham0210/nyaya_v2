import {
  DynamicModule,
  Global,
  Inject,
  Module,
  OnApplicationShutdown,
} from '@nestjs/common';
import { AuditService } from './audit.service.js';
import { APP_CONFIG, type AppConfig } from './config.js';
import { DB, openDb, type DbHandle } from './db.js';

const DB_HANDLE = Symbol('DB_HANDLE');

/** Config, database and audit log, available everywhere. */
@Global()
@Module({})
export class CoreModule implements OnApplicationShutdown {
  constructor(@Inject(DB_HANDLE) private readonly handle: DbHandle) {}

  static register(config: AppConfig): DynamicModule {
    return {
      module: CoreModule,
      providers: [
        { provide: APP_CONFIG, useValue: config },
        { provide: DB_HANDLE, useFactory: () => openDb(config) },
        { provide: DB, useFactory: (h: DbHandle) => h.db, inject: [DB_HANDLE] },
        AuditService,
      ],
      exports: [APP_CONFIG, DB, AuditService],
    };
  }

  async onApplicationShutdown() {
    await this.handle.close();
  }
}
