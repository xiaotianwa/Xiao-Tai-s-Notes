import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class LatestAppVersionQueryDto {
  @IsString()
  platform!: string;

  @IsOptional()
  @IsString()
  channel = 'private';
}

export class AdminAppVersionsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  pageSize = 20;

  @IsOptional()
  @IsString()
  platform?: string;

  @IsOptional()
  @IsString()
  channel?: string;
}

export class CreateAppVersionDto {
  @IsString()
  platform!: string;

  @IsOptional()
  @IsString()
  channel = 'private';

  @IsString()
  versionName!: string;

  @IsString()
  versionCode!: string;

  @IsOptional()
  @IsString()
  changelog?: string;

  @IsOptional()
  @IsString()
  forceUpdate?: string;

  @IsOptional()
  @IsString()
  enabled?: string;
}

export class UpdateAppVersionDto {
  @IsOptional()
  @IsString()
  changelog?: string;

  @IsOptional()
  @IsBoolean()
  forceUpdate?: boolean;

  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
