import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  ArrayMaxSize,
  ArrayMinSize,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { STAFF_ROLES, type Role } from '../db/schema.js';

type StaffRole = Exclude<Role, 'learner'>;

/** Staff passwords guard publishing legal content, so they are longer than learners'. */
export const STAFF_PASSWORD_MIN = 12;

class RolesField {
  @ApiProperty({ enum: STAFF_ROLES, isArray: true, minItems: 1 })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(STAFF_ROLES.length)
  @ArrayUnique()
  @IsIn(STAFF_ROLES, { each: true })
  roles: StaffRole[];
}

export class InviteStaffDto extends RolesField {
  @ApiProperty({ example: 'priya@example.com' })
  @IsEmail()
  @MaxLength(254)
  email: string;

  @ApiProperty({ example: 'Priya Raman' })
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  display_name: string;
}

export class UpdateStaffDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(80)
  display_name?: string;

  @ApiPropertyOptional({ enum: STAFF_ROLES, isArray: true, minItems: 1 })
  @IsOptional()
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(STAFF_ROLES.length)
  @ArrayUnique()
  @IsIn(STAFF_ROLES, { each: true })
  roles?: StaffRole[];

  @ApiPropertyOptional({
    description: 'false disables the account and signs it out everywhere',
  })
  @IsOptional()
  @IsBoolean()
  is_active?: boolean;
}

export class SetupPasswordDto {
  @ApiProperty({ description: 'The token from the setup link' })
  @IsString()
  @MinLength(20)
  @MaxLength(200)
  token: string;

  @ApiProperty({ format: 'password', minLength: STAFF_PASSWORD_MIN })
  @IsString()
  @MinLength(STAFF_PASSWORD_MIN)
  @MaxLength(200)
  password: string;
}

// ------------------------------------------------------------ responses

export class StaffSetupDto {
  @ApiProperty({ format: 'date-time' }) expires_at: string;
  @ApiProperty() expired: boolean;
}

export class StaffMemberDto {
  @ApiProperty({ format: 'uuid' }) id: string;
  @ApiProperty() email: string;
  @ApiProperty() display_name: string;
  @ApiProperty({ enum: STAFF_ROLES, isArray: true }) roles: StaffRole[];
  @ApiProperty() is_active: boolean;
  @ApiProperty({
    type: StaffSetupDto,
    nullable: true,
    description: 'Set while a setup link is waiting to be used',
  })
  setup: StaffSetupDto | null;
  @ApiProperty({ format: 'date-time' }) created_at: string;
}

export class StaffListDto {
  @ApiProperty({ type: [StaffMemberDto] }) items: StaffMemberDto[];
}

export class SetupLinkDto {
  @ApiProperty({ type: StaffMemberDto }) staff: StaffMemberDto;
  @ApiProperty({
    description:
      'Shown once: put it in the link to the portal setup page and send it to the person',
  })
  setup_token: string;
  @ApiProperty({ format: 'date-time' }) expires_at: string;
}
