import {
  IsBoolean,
  IsIn,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class CreatePushDto {
  @IsString()
  @MaxLength(80)
  userId!: string;

  @IsString()
  @MaxLength(80)
  title!: string;

  @IsString()
  @MaxLength(2000)
  content!: string;

  @IsOptional()
  @IsIn(["info", "warn", "critical"])
  level?: string;

  @IsOptional()
  @IsISO8601()
  expiresAt?: string;
}

export class UpdatePushDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  content?: string;

  @IsOptional()
  @IsIn(["info", "warn", "critical"])
  level?: string;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @IsOptional()
  @IsISO8601()
  expiresAt?: string | null;
}
