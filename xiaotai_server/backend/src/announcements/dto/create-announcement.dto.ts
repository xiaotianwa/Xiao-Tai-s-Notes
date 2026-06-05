import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsString,
  IsNotEmpty,
  IsOptional,
  IsBoolean,
  IsInt,
  IsDateString,
  IsIn,
  Min,
  Max,
} from 'class-validator';

export class CreateAnnouncementDto {
  @ApiProperty({ description: '公告标题', example: '系统维护通知' })
  @IsString()
  @IsNotEmpty()
  title!: string;

  @ApiProperty({
    description: '公告内容',
    example: '系统将于今晚 22:00 - 23:00 进行维护，期间可能无法访问',
  })
  @IsString()
  @IsNotEmpty()
  content!: string;

  @ApiPropertyOptional({
    description: '公告类型',
    enum: ['info', 'warning', 'success', 'error'],
    default: 'info',
  })
  @IsOptional()
  @IsIn(['info', 'warning', 'success', 'error'])
  type?: string;

  @ApiPropertyOptional({
    description: '优先级（数字越大优先级越高）',
    default: 0,
    minimum: 0,
    maximum: 100,
  })
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  priority?: number;

  @ApiPropertyOptional({
    description: '目标用户 ID 列表（逗号分隔，为空表示全部用户）',
    example: 'user1,user2,user3',
  })
  @IsOptional()
  @IsString()
  targetUsers?: string;

  @ApiPropertyOptional({
    description: '公告图片 URL（单张，可为空）',
    example: '/api/v1/announcements/images/announcement-xxx.webp',
  })
  @IsOptional()
  @IsString()
  imageUrl?: string;

  @ApiPropertyOptional({
    description: '生效开始时间（ISO 8601 格式）',
    example: '2026-05-26T10:00:00Z',
  })
  @IsOptional()
  @IsDateString()
  startAt?: string | null;

  @ApiPropertyOptional({
    description: '生效结束时间（ISO 8601 格式）',
    example: '2026-05-27T10:00:00Z',
  })
  @IsOptional()
  @IsDateString()
  endAt?: string | null;

  @ApiPropertyOptional({ description: '是否启用', default: true })
  @IsOptional()
  @IsBoolean()
  enabled?: boolean;
}
