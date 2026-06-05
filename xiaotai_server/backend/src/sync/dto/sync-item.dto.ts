import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsInt,
  IsISO8601,
  IsObject,
  IsOptional,
  IsString,
  Max,
  Min,
  ValidateNested,
} from 'class-validator';

export class PullSyncItemsDto {
  @IsOptional()
  @IsISO8601()
  since?: string;

  @IsOptional()
  @IsString()
  type?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 100;
}

export class DeviceInfoDto {
  @IsOptional()
  @IsString()
  deviceName?: string;

  @IsOptional()
  @IsString()
  platform?: string;

  @IsOptional()
  @IsString()
  appVersionName?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  appVersionCode?: number;
}

export class UploadSyncItemDto {
  @IsString()
  type!: string;

  @IsString()
  clientId!: string;

  @IsISO8601()
  clientUpdatedAt!: string;

  @IsOptional()
  @IsISO8601()
  deletedAt?: string | null;

  @IsObject()
  data!: Record<string, unknown>;
}

export class BatchUploadSyncItemsDto {
  @IsString()
  deviceId!: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => DeviceInfoDto)
  device?: DeviceInfoDto;

  @IsArray()
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => UploadSyncItemDto)
  items!: UploadSyncItemDto[];
}
