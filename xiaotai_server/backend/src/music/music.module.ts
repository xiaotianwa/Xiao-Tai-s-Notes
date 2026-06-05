import { Module } from "@nestjs/common";

import { ObjectStorageModule } from "../common/object-storage/object-storage.module";
import { PrismaModule } from "../common/prisma/prisma.module";
import { AdminMusicController, MusicController } from "./music.controller";
import { MusicService } from "./music.service";

@Module({
  imports: [ObjectStorageModule, PrismaModule],
  controllers: [MusicController, AdminMusicController],
  providers: [MusicService],
})
export class MusicModule {}
