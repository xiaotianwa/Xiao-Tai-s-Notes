import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  ValidateNested,
} from 'class-validator';

import { DailyComicImageDto } from './daily-comic-image.dto';

export class CreateDailyComicDto {
  @ApiProperty({ description: '漫画标题', example: '今天的小笨漫画' })
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  title!: string;

  @ApiPropertyOptional({ description: '漫画说明' })
  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string;

  @ApiProperty({
    description: '发布日期，格式 YYYY-MM-DD',
    example: '2026-05-27',
  })
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  publishDate!: string;

  @ApiPropertyOptional({ description: '是否启用', default: true })
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;

  @ApiProperty({
    description: '漫画图片列表，按数组顺序展示，最多 10 张',
    type: [DailyComicImageDto],
  })
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(10)
  @ValidateNested({ each: true })
  @Type(() => DailyComicImageDto)
  images!: DailyComicImageDto[];
}
