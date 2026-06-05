import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

export class DailyComicImageDto {
  @ApiProperty({
    description: '漫画图片 URL',
    example: '/api/v1/daily-comics/images/comic-xxx.webp',
  })
  @IsString()
  @MaxLength(500)
  imageUrl!: string;

  @ApiPropertyOptional({ description: '原始文件名' })
  @IsOptional()
  @IsString()
  @MaxLength(180)
  originalName?: string;

  @ApiPropertyOptional({ description: '图片 MIME 类型' })
  @IsOptional()
  @IsString()
  @MaxLength(80)
  mimeType?: string;

  @ApiPropertyOptional({ description: '图片大小，单位 byte' })
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(5 * 1024 * 1024)
  size?: number;
}
