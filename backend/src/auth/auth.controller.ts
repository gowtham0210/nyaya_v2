import {
  Body,
  Controller,
  Get,
  HttpCode,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiNoContentResponse,
  ApiOkResponse,
  ApiTags,
} from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import type { Request } from 'express';
import { MeDto, RefreshDto, SessionDto, SignInDto } from './auth.dto.js';
import type { AuthUser } from './auth-user.js';
import { AuthService } from './auth.service.js';
import { CurrentUser, Public } from './decorators.js';

@ApiTags('auth')
@Controller('auth')
@UseGuards(ThrottlerGuard)
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('session')
  @HttpCode(200)
  @ApiOkResponse({ type: SessionDto })
  signIn(@Body() body: SignInDto, @Req() req: Request) {
    return this.auth.signIn(body.email, body.password, req.id);
  }

  @Public()
  @Post('refresh')
  @HttpCode(200)
  @ApiOkResponse({ type: SessionDto })
  refresh(@Body() body: RefreshDto, @Req() req: Request) {
    return this.auth.refresh(body.refresh_token, req.id);
  }

  @Public()
  @Post('sign-out')
  @HttpCode(204)
  @ApiNoContentResponse()
  async signOut(@Body() body: RefreshDto) {
    await this.auth.signOut(body.refresh_token);
  }
}

@ApiTags('auth')
@ApiBearerAuth()
@Controller('me')
export class MeController {
  constructor(private readonly auth: AuthService) {}

  @Get()
  @ApiOkResponse({ type: MeDto })
  me(@CurrentUser() user: AuthUser) {
    return this.auth.me(user.id);
  }
}
