import { Controller, Get, Inject } from '@nestjs/common';
import {
  ApiOkResponse,
  ApiOperation,
  ApiProperty,
  ApiTags,
} from '@nestjs/swagger';
import { Public } from '../auth/decorators.js';
import { APP_CONFIG, type AppConfig } from '../core/config.js';

class AppConfigDto {
  @ApiProperty({
    type: String,
    nullable: true,
    example: '0.2.0',
    description:
      'The oldest app version that may still be used. An older build shows an update screen. Null: no build is blocked.',
  })
  min_app_version: string | null;

  @ApiProperty({
    type: String,
    nullable: true,
    description:
      'The store page the update screen opens (https). Null: no button.',
  })
  update_url: string | null;
}

@ApiTags('app')
@Controller('app-config')
export class AppConfigController {
  constructor(@Inject(APP_CONFIG) private readonly config: AppConfig) {}

  @Public()
  @Get()
  @ApiOperation({
    summary: 'Settings the app reads before anything else: the minimum version',
  })
  @ApiOkResponse({ type: AppConfigDto })
  get(): AppConfigDto {
    return {
      min_app_version: this.config.minAppVersion ?? null,
      update_url: this.config.appUpdateUrl ?? null,
    };
  }
}
