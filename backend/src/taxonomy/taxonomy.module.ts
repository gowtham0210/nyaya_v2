import { Module } from '@nestjs/common';
import { TaxonomyController } from './taxonomy.controller.js';

@Module({ controllers: [TaxonomyController] })
export class TaxonomyModule {}
