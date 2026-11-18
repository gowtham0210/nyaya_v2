import { Controller, Get, Header } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOkResponse,
  ApiOperation,
  ApiTags,
} from '@nestjs/swagger';
import { Public, Roles } from '../auth/decorators.js';
import { ConstitutionDriftDto, ConstitutionDto } from './constitution.dto.js';
import { ConstitutionService } from './constitution.service.js';

/** The Constitution of India section of the app. Public: no account needed. */
@ApiTags('constitution')
@Controller('constitution')
export class ConstitutionController {
  constructor(private readonly constitution: ConstitutionService) {}

  @Public()
  @Get()
  // India Code metadata is already cached here; an hour more on the phone is fine.
  @Header('Cache-Control', 'public, max-age=3600')
  @ApiOperation({
    summary:
      "The Constitution of India's editions on India Code: official PDF links with size and warnings. No document is served by this API.",
  })
  @ApiOkResponse({ type: ConstitutionDto })
  list() {
    return this.constitution.list();
  }
}

@ApiTags('admin')
@ApiBearerAuth()
@Controller('admin/constitution')
export class AdminConstitutionController {
  constructor(private readonly constitution: ConstitutionService) {}

  @Get('drift')
  @Roles('admin')
  @ApiOperation({
    summary:
      'Compare India Code with the reviewed manifest: changed, missing and new editions',
  })
  @ApiOkResponse({ type: ConstitutionDriftDto })
  drift() {
    return this.constitution.drift();
  }
}
