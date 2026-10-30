import {
  Body,
  Controller,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { Request } from 'express';
import { CurrentActor, Public, Roles } from '../auth/decorators.js';
import type { Actor } from '../core/audit.service.js';
import {
  InviteStaffDto,
  SetupLinkDto,
  SetupPasswordDto,
  StaffListDto,
  StaffMemberDto,
  UpdateStaffDto,
} from './staff.dto.js';
import { StaffService } from './staff.service.js';

const Id = () => Param('id', new ParseUUIDPipe());

@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin/staff')
@Roles('admin')
export class StaffController {
  constructor(private readonly staff: StaffService) {}

  @Get()
  @ApiOkResponse({ type: StaffListDto })
  list() {
    return this.staff.list();
  }

  @Post()
  @ApiOperation({
    summary:
      'Add a staff account and a one-time link for them to choose a password',
  })
  @ApiCreatedResponse({ type: SetupLinkDto })
  invite(@CurrentActor() actor: Actor, @Body() body: InviteStaffDto) {
    return this.staff.invite(actor, body);
  }

  @Patch(':id')
  @ApiOperation({
    summary:
      'Change name or roles, or disable (signs out at once); never your own admin role, never the last admin',
  })
  @ApiOkResponse({ type: StaffMemberDto })
  update(
    @CurrentActor() actor: Actor,
    @Id() id: string,
    @Body() body: UpdateStaffDto,
  ) {
    return this.staff.update(actor, id, body);
  }

  @Post(':id/setup-link')
  @HttpCode(200)
  @ApiOperation({
    summary:
      'A new one-time setup link; the old password stops working and they are signed out',
  })
  @ApiOkResponse({ type: SetupLinkDto })
  resetLink(@CurrentActor() actor: Actor, @Id() id: string) {
    return this.staff.resetLink(actor, id);
  }
}

/** Public, and rate-limited like sign-in. */
@ApiTags('auth')
@Controller('auth')
@UseGuards(ThrottlerGuard)
export class StaffSetupController {
  constructor(private readonly staff: StaffService) {}

  @Public()
  @Post('setup-password')
  @HttpCode(204)
  @ApiOperation({ summary: 'Choose a password with a one-time setup link' })
  @ApiNoContentResponse()
  async setPassword(@Body() body: SetupPasswordDto, @Req() req: Request) {
    await this.staff.setPassword(body.token, body.password, req.id);
  }
}
