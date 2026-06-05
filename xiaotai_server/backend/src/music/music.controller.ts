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
  Req,
  Res,
  UploadedFiles,
  UseInterceptors,
} from "@nestjs/common";
import { FileFieldsInterceptor } from "@nestjs/platform-express";
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
import {
  CreateMusicTrackDto,
  MusicQueryDto,
  UpdateMusicTrackDto,
} from "./dto/music.dto";
import { MusicService, MusicTrackFiles } from "./music.service";

interface AuthenticatedRequest extends Request {
  user: AuthUser;
}

const musicUploadInterceptor = FileFieldsInterceptor(
  [
    { name: "audio", maxCount: 1 },
    { name: "cover", maxCount: 1 },
    { name: "lyricsFile", maxCount: 1 },
  ],
  { limits: { fileSize: 80 * 1024 * 1024 } },
);

@ApiTags("Music")
@Controller("music/tracks")
export class MusicController {
  constructor(private readonly musicService: MusicService) {}

  @Public()
  @Get()
  @ApiOperation({ summary: "APP 获取已启用音乐列表" })
  list(@Query() query: MusicQueryDto) {
    return this.musicService.list(query, true);
  }

  @Public()
  @Get(":id")
  @ApiOperation({ summary: "APP 获取音乐详情" })
  get(@Param("id") id: string) {
    return this.musicService.get(id, true);
  }

  @Public()
  @Get(":id/audio")
  @Header("Cache-Control", "public, max-age=604800")
  @ApiOperation({ summary: "APP 播放音乐文件" })
  async audio(@Param("id") id: string, @Res() response: Response) {
    sendFile(response, await this.musicService.readAudio(id), "inline");
  }

  @Public()
  @Get(":id/cover")
  @Header("Cache-Control", "public, max-age=604800")
  @ApiOperation({ summary: "APP 获取音乐封面" })
  async cover(@Param("id") id: string, @Res() response: Response) {
    sendFile(response, await this.musicService.readCover(id), "inline");
  }
}

@ApiTags("Admin Music")
@ApiBearerAuth()
@Roles("admin")
@Controller("admin/music/tracks")
export class AdminMusicController {
  constructor(private readonly musicService: MusicService) {}

  @Get()
  @ApiOperation({ summary: "管理端音乐列表" })
  list(@Query() query: MusicQueryDto) {
    return this.musicService.list(query);
  }

  @Post()
  @ApiConsumes("multipart/form-data")
  @UseInterceptors(musicUploadInterceptor)
  @ApiOperation({ summary: "管理端上传音乐" })
  create(
    @Req() request: AuthenticatedRequest,
    @Body() body: CreateMusicTrackDto,
    @UploadedFiles() files: MusicTrackFiles,
  ) {
    return this.musicService.create(body, files ?? {}, request.user.id);
  }

  @Patch(":id")
  @ApiConsumes("multipart/form-data")
  @UseInterceptors(musicUploadInterceptor)
  @ApiOperation({ summary: "管理端编辑音乐" })
  update(
    @Param("id") id: string,
    @Body() body: UpdateMusicTrackDto,
    @UploadedFiles() files: MusicTrackFiles,
  ) {
    return this.musicService.update(id, body, files ?? {});
  }

  @Delete(":id")
  @ApiOperation({ summary: "管理端删除音乐" })
  remove(@Param("id") id: string) {
    return this.musicService.remove(id);
  }
}

function sendFile(
  response: Response,
  file: { fileName: string; contentType: string; bytes: Buffer },
  disposition: "inline" | "attachment",
): void {
  response.setHeader("Accept-Ranges", "bytes");
  response.setHeader(
    "Content-Disposition",
    `${disposition}; filename*=UTF-8''${encodeURIComponent(file.fileName)}`,
  );
  response.type(file.contentType).send(file.bytes);
}
