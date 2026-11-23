import { Module } from '@nestjs/common';
import {
  AdminConstitutionController,
  ConstitutionController,
} from './constitution.controller.js';
import {
  CONSTITUTION_MANIFEST,
  ConstitutionService,
} from './constitution.service.js';
import { HttpIndiaCodeClient, IndiaCodeClient } from './indiacode.client.js';
import { loadManifest } from './manifest.js';

@Module({
  controllers: [ConstitutionController, AdminConstitutionController],
  providers: [
    ConstitutionService,
    { provide: IndiaCodeClient, useClass: HttpIndiaCodeClient },
    // Read and checked once at startup: a bad manifest stops the server.
    { provide: CONSTITUTION_MANIFEST, useFactory: () => loadManifest() },
  ],
})
export class ConstitutionModule {}
