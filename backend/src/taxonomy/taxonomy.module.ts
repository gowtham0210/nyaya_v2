import { Module } from '@nestjs/common';
import { AdminTaxonomyController } from './admin-taxonomy.controller.js';
import { AdminTaxonomyService } from './admin-taxonomy.service.js';
import { TaxonomyController } from './taxonomy.controller.js';

@Module({
  controllers: [TaxonomyController, AdminTaxonomyController],
  providers: [AdminTaxonomyService],
})
export class TaxonomyModule {}
