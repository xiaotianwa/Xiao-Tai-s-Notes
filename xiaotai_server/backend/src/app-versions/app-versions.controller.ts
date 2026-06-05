import {
  BadRequestException,
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Patch,
  Post,
  Query,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { createReadStream } from 'node:fs';
import { tmpdir } from 'node:os';
import { extname } from 'node:path';
import { diskStorage } from 'multer';
import { stat } from 'node:fs/promises';

import type { AuthUser } from '../auth/auth-user';
import { Public } from '../common/decorators/public.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { AppVersionsService, UploadedApkFile } from './app-versions.service';
import {
  AdminAppVersionsQueryDto,
  CreateAppVersionDto,
  LatestAppVersionQueryDto,
  UpdateAppVersionDto,
} from './dto/app-version.dto';

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

const maxApkSize = 200 * 1024 * 1024;
const apkUploadOptions: Parameters<typeof FileInterceptor>[1] = {
  storage: diskStorage({
    destination: tmpdir(),
    filename: (_request, file, callback) => {
      const suffix = extname(file.originalname) || '.apk';
      callback(null, `xiaotai-apk-${Date.now()}-${Math.random().toString(36).slice(2)}${suffix}`);
    },
  }),
  limits: { fileSize: maxApkSize },
  fileFilter: (_request, file, callback) => {
    if (!file.originalname.toLowerCase().endsWith('.apk')) {
      callback(new BadRequestException('只支持上传 APK 文件'), false);
      return;
    }
    callback(null, true);
  },
};

@ApiTags('App Versions')
@Controller('app-versions')
export class AppVersionsController {
  constructor(private readonly appVersionsService: AppVersionsService) {}

  @Public()
  @Get('latest')
  @ApiOperation({ summary: '获取当前平台最新 APP 版本' })
  latest(@Query() query: LatestAppVersionQueryDto) {
    return this.appVersionsService.latest(query);
  }

  @Public()
  @Get(':id/apk')
  @Header('Content-Type', 'application/vnd.android.package-archive')
  @ApiOperation({ summary: '下载 APK 安装包' })
  async download(
    @Param('id') id: string,
    @Req() request: Request,
    @Res() response: Response,
  ) {
    const apk = await this.appVersionsService.getApkDownload(id);
    if (apk.redirectUrl) {
      response.redirect(302, apk.redirectUrl);
      return;
    }
    if (!apk.localPath) {
      response.status(404).send();
      return;
    }
    const fileStat = await stat(apk.localPath);
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="${encodeURIComponent(apk.fileName)}"`,
    );
    response.setHeader('Accept-Ranges', 'bytes');
    response.setHeader('Cache-Control', 'public, max-age=86400');
    response.type(apk.contentType);
    const range = request.headers.range;
    if (range) {
      const match = range.match(/^bytes=(\d*)-(\d*)$/);
      if (match) {
        const start = match[1] ? Number(match[1]) : 0;
        const end = match[2]
          ? Math.min(Number(match[2]), fileStat.size - 1)
          : fileStat.size - 1;
        if (start <= end && start >= 0 && end < fileStat.size) {
          response.status(206);
          response.setHeader('Content-Range', `bytes ${start}-${end}/${fileStat.size}`);
          response.setHeader('Content-Length', String(end - start + 1));
          createReadStream(apk.localPath, { start, end }).pipe(response);
          return;
        }
      }
    }
    response.setHeader('Content-Length', String(fileStat.size));
    createReadStream(apk.localPath).pipe(response);
  }
}

@ApiTags('Admin App Versions')
@ApiBearerAuth()
@Roles('admin')
@Controller('admin/app-versions')
export class AdminAppVersionsController {
  constructor(private readonly appVersionsService: AppVersionsService) {}

  @Get()
  @ApiOperation({ summary: '管理端 APP 版本列表' })
  list(@Query() query: AdminAppVersionsQueryDto) {
    return this.appVersionsService.list(query);
  }

  @Post()
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('apk', apkUploadOptions))
  @ApiOperation({ summary: '管理端发布新版 APK' })
  create(
    @Req() request: AuthenticatedRequest,
    @Body() body: CreateAppVersionDto,
    @UploadedFile() file?: UploadedApkFile,
  ) {
    return this.appVersionsService.create(request.user, body, file);
  }

  @Patch(':id')
  @ApiOperation({ summary: '管理端更新版本状态' })
  update(@Param('id') id: string, @Body() body: UpdateAppVersionDto) {
    return this.appVersionsService.update(id, body);
  }

  @Delete(':id')
  @ApiOperation({ summary: '管理端删除版本记录' })
  remove(@Param('id') id: string) {
    return this.appVersionsService.remove(id);
  }
}
