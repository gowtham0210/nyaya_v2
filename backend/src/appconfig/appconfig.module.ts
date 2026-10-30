import { Module } from '@nestjs/common';
import { AppConfigController } from './appconfig.controller.js';

@Module({ controllers: [AppConfigController] })
export class AppConfigModule {}
