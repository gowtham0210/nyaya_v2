import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';
import { ROLES, type Role } from '../db/schema.js';

export class SignInDto {
  @ApiProperty({ example: 'editor@example.com' })
  @IsEmail()
  @MaxLength(254)
  email: string;

  @ApiProperty({ format: 'password' })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  password: string;
}

export class RefreshDto {
  @ApiProperty()
  @IsString()
  @MinLength(20)
  @MaxLength(200)
  refresh_token: string;
}

export class MeDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() email: string;
  @ApiProperty() display_name: string;
  @ApiProperty({ enum: ROLES, isArray: true }) roles: Role[];
}

export class SessionDto {
  @ApiProperty() access_token: string;
  @ApiProperty({ description: 'Seconds until the access token expires' })
  expires_in: number;
  @ApiProperty({ description: 'Single use: each refresh returns a new one' })
  refresh_token: string;
  @ApiProperty({ type: MeDto }) user: MeDto;
}
