import {
  Body,
  Controller,
  Delete,
  Get,
  Header,
  Param,
  Post,
  Query,
  Req,
  Res,
  UploadedFile,
  UseInterceptors,
} from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import {
  ApiBearerAuth,
  ApiConsumes,
  ApiOperation,
  ApiTags,
} from "@nestjs/swagger";
import type { Request, Response } from "express";

import type { AuthUser } from "../auth/auth-user";
import { Public } from "../common/decorators/public.decorator";
import { Roles } from "../common/decorators/roles.decorator";
import { MediaListQueryDto, UploadMediaDto } from "./dto/media.dto";
import { MediaService, UploadedMediaFile } from "./media.service";

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

@ApiTags("Media")
@ApiBearerAuth()
@Controller("media")
export class MediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Get()
  @ApiOperation({ summary: "当前用户媒体文件列表" })
  list(
    @Req() request: AuthenticatedRequest,
    @Query() query: MediaListQueryDto,
  ) {
    return this.mediaService.listForUser(request.user, query);
  }

  @Post()
  @ApiConsumes("multipart/form-data")
  @UseInterceptors(
    FileInterceptor("file", { limits: { fileSize: 500 * 1024 * 1024 } }),
  )
  @ApiOperation({ summary: "上传当前用户选择的图片或视频" })
  upload(
    @Req() request: AuthenticatedRequest,
    @Body() body: UploadMediaDto,
    @UploadedFile() file?: UploadedMediaFile,
  ) {
    return this.mediaService.upload(request.user, body, file);
  }

  @Get(":id")
  @ApiOperation({ summary: "当前用户媒体详情" })
  get(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.mediaService.get(id, request.user);
  }

  @Get(":id/file")
  @Header("Cache-Control", "private, max-age=604800, immutable")
  @ApiOperation({ summary: "当前用户下载原始媒体" })
  async file(
    @Param("id") id: string,
    @Req() request: AuthenticatedRequest,
    @Res() response: Response,
  ) {
    sendMediaFile(response, await this.mediaService.readFile(id, request.user));
  }

  @Get(":id/thumb")
  @Header("Cache-Control", "private, max-age=604800, immutable")
  @ApiOperation({ summary: "当前用户查看媒体缩略图" })
  async thumb(
    @Param("id") id: string,
    @Req() request: AuthenticatedRequest,
    @Res() response: Response,
  ) {
    sendMediaFile(
      response,
      await this.mediaService.readFile(id, request.user, undefined, true),
    );
  }

  @Delete(":id")
  @ApiOperation({ summary: "当前用户删除云端媒体文件" })
  remove(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.mediaService.remove(id, request.user);
  }
}

@ApiTags("Admin Media")
@ApiBearerAuth()
@Roles("admin")
@Controller("admin/media")
export class AdminMediaController {
  constructor(private readonly mediaService: MediaService) {}

  @Get()
  @ApiOperation({ summary: "管理端媒体文件列表" })
  list(@Query() query: MediaListQueryDto) {
    return this.mediaService.list(query);
  }

  @Get(":id")
  @ApiOperation({ summary: "管理端媒体详情" })
  get(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.mediaService.get(id, request.user, request);
  }

  @Get(":id/file")
  @Header("Cache-Control", "private, max-age=3600")
  @ApiOperation({ summary: "管理端下载原始媒体" })
  async file(
    @Param("id") id: string,
    @Req() request: AuthenticatedRequest,
    @Res() response: Response,
  ) {
    sendMediaFile(
      response,
      await this.mediaService.readFile(id, request.user, request),
    );
  }

  @Post(":id/download-ticket")
  @ApiOperation({ summary: "管理端创建短期媒体下载链接" })
  createDownloadTicket(
    @Param("id") id: string,
    @Req() request: AuthenticatedRequest,
  ) {
    return this.mediaService.createAdminDownloadTicket(id, request.user, request);
  }

  @Get(":id/thumb")
  @Header("Cache-Control", "private, max-age=3600")
  @ApiOperation({ summary: "管理端查看媒体缩略图" })
  async thumb(
    @Param("id") id: string,
    @Req() request: AuthenticatedRequest,
    @Res() response: Response,
  ) {
    sendMediaFile(
      response,
      await this.mediaService.readFile(id, request.user, request, true),
    );
  }

  @Delete(":id")
  @ApiOperation({ summary: "管理端删除媒体文件" })
  remove(@Param("id") id: string, @Req() request: AuthenticatedRequest) {
    return this.mediaService.remove(id, request.user, request);
  }
}

@ApiTags("Admin Media")
@Controller("admin/media-downloads")
export class AdminMediaDownloadController {
  constructor(private readonly mediaService: MediaService) {}

  @Public()
  @Get(":ticket")
  @Header("Cache-Control", "private, max-age=300")
  @ApiOperation({ summary: "使用短期票据下载管理端媒体原文件" })
  async download(
    @Param("ticket") ticket: string,
    @Res() response: Response,
  ) {
    sendMediaFile(
      response,
      await this.mediaService.readFileByDownloadTicket(ticket),
      "attachment",
    );
  }
}

function sendMediaFile(
  response: Response,
  file: { fileName: string; contentType: string; bytes: Buffer },
  disposition: "inline" | "attachment" = "inline",
): void {
  response.setHeader(
    "Content-Disposition",
    `${disposition}; filename*=UTF-8''${encodeURIComponent(file.fileName)}`,
  );
  response.type(file.contentType).send(file.bytes);
}
