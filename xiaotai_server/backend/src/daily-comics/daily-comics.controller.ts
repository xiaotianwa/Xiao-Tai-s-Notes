import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Query,
  Request,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';

import type { AuthUser } from '../auth/auth-user';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import {
  DailyComicsService,
  UploadedDailyComicImage,
} from './daily-comics.service';
import { CreateDailyComicDto } from './dto/create-daily-comic.dto';
import { QueryDailyComicsDto } from './dto/query-daily-comics.dto';
import { UpdateDailyComicDto } from './dto/update-daily-comic.dto';

interface RequestWithUser {
  user: AuthUser;
}

@ApiTags('daily-comics')
@Controller('daily-comics')
export class DailyComicsController {
  constructor(private readonly dailyComicsService: DailyComicsService) {}

  @Get('latest')
  @Public()
  @ApiOperation({ summary: '获取最新启用的每日漫画（APP 端）' })
  async latest() {
    return this.dailyComicsService.findLatest();
  }

  @Get('published')
  @Public()
  @ApiOperation({ summary: '获取已发布的每日漫画列表（APP 端往期）' })
  async published(@Query() query: QueryDailyComicsDto) {
    return this.dailyComicsService.findPublished(query);
  }

  @Public()
  @Get('images/:fileName')
  @Header('Cache-Control', 'public, max-age=604800')
  @ApiOperation({ summary: '读取每日漫画图片' })
  async image(@Param('fileName') fileName: string, @Res() response: Response) {
    const file = await this.dailyComicsService.readImage(fileName);
    response.setHeader(
      'Content-Disposition',
      `inline; filename="${encodeURIComponent(file.fileName)}"`,
    );
    response.type(file.contentType).send(file.bytes);
  }

  @Get()
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取每日漫画列表（管理端）' })
  async findAll(@Query() query: QueryDailyComicsDto) {
    return this.dailyComicsService.findAll(query);
  }

  @Post('image')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileInterceptor('image', { limits: { fileSize: 5 * 1024 * 1024 } }),
  )
  @ApiOperation({ summary: '上传每日漫画图片（单张）' })
  async uploadImage(@UploadedFile() file?: UploadedDailyComicImage) {
    return this.dailyComicsService.uploadImage(file);
  }

  @Get(':id')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取每日漫画详情（管理端）' })
  async findOne(@Param('id') id: string) {
    return this.dailyComicsService.findOne(id);
  }

  @Post()
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建每日漫画（管理端）' })
  async create(@Body() dto: CreateDailyComicDto, @Request() req: RequestWithUser) {
    return this.dailyComicsService.create(dto, req.user.id);
  }

  @Patch(':id')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新每日漫画（管理端）' })
  async update(@Param('id') id: string, @Body() dto: UpdateDailyComicDto) {
    return this.dailyComicsService.update(id, dto);
  }

  @Delete(':id')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除每日漫画（管理端）' })
  async remove(@Param('id') id: string) {
    await this.dailyComicsService.remove(id);
    return { success: true };
  }
}
