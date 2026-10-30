import { Module } from '@nestjs/common';
import { StaffController, StaffSetupController } from './staff.controller.js';
import { StaffService } from './staff.service.js';

@Module({
  controllers: [StaffController, StaffSetupController],
  providers: [StaffService],
})
export class StaffModule {}
