import { Module } from "@nestjs/common";

import { ObjectStorageModule } from "../common/object-storage/object-storage.module";
import { PrismaModule } from "../common/prisma/prisma.module";
import {
  AdminMediaController,
  AdminMediaDownloadController,
  MediaController,
} from "./media.controller";
import { MediaService } from "./media.service";

@Module({
  imports: [ObjectStorageModule, PrismaModule],
  controllers: [MediaController, AdminMediaController, AdminMediaDownloadController],
  providers: [MediaService],
})
export class MediaModule {}
