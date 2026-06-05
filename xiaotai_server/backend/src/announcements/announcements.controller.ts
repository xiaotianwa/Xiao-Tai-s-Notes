import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  Query,
  Request,
  Res,
  Header,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import type { Response } from 'express';
import {
  AnnouncementsService,
  UploadedAnnouncementImage,
} from './announcements.service';
import { CreateAnnouncementDto } from './dto/create-announcement.dto';
import { UpdateAnnouncementDto } from './dto/update-announcement.dto';
import { QueryAnnouncementsDto } from './dto/query-announcements.dto';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import type { AuthUser } from '../auth/auth-user';

interface RequestWithUser {
  user: AuthUser;
}

@ApiTags('announcements')
@Controller('announcements')
export class AnnouncementsController {
  constructor(private readonly announcementsService: AnnouncementsService) {}

  @Get('active')
  @Public()
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取当前生效的公告（APP 端）' })
  async findActive(@Request() req: Partial<RequestWithUser>) {
    const userId = req.user?.id;
    return this.announcementsService.findActive(userId);
  }

  @Get()
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取公告列表（管理端）' })
  async findAll(@Query() query: QueryAnnouncementsDto) {
    return this.announcementsService.findAll(query);
  }

  @Public()
  @Get('images/:fileName')
  @Header('Cache-Control', 'public, max-age=604800')
  @ApiOperation({ summary: '读取公告图片' })
  async image(@Param('fileName') fileName: string, @Res() response: Response) {
    const file = await this.announcementsService.readImage(fileName);
    response.setHeader(
      'Content-Disposition',
      `inline; filename="${encodeURIComponent(file.fileName)}"`,
    );
    response.type(file.contentType).send(file.bytes);
  }

  @Post('image')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('image', { limits: { fileSize: 5 * 1024 * 1024 } }))
  @ApiOperation({ summary: '上传公告图片（单张）' })
  async uploadImage(@UploadedFile() file?: UploadedAnnouncementImage) {
    return this.announcementsService.uploadImage(file);
  }

  @Get(':id')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '获取公告详情（管理端）' })
  async findOne(@Param('id') id: string) {
    return this.announcementsService.findOne(id);
  }

  @Post()
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '创建公告（管理端）' })
  async create(@Body() dto: CreateAnnouncementDto, @Request() req: RequestWithUser) {
    return this.announcementsService.create(dto, req.user.id);
  }

  @Patch(':id')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '更新公告（管理端）' })
  async update(@Param('id') id: string, @Body() dto: UpdateAnnouncementDto) {
    return this.announcementsService.update(id, dto);
  }

  @Delete(':id')
  @Roles('admin')
  @ApiBearerAuth()
  @ApiOperation({ summary: '删除公告（管理端）' })
  async remove(@Param('id') id: string) {
    await this.announcementsService.remove(id);
    return { success: true };
  }
}
