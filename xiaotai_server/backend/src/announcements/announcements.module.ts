import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";

import { ObjectStorageModule } from "../common/object-storage/object-storage.module";
import { PrismaModule } from "../common/prisma/prisma.module";
import { AnnouncementsService } from "./announcements.service";
import { AnnouncementsController } from "./announcements.controller";

@Module({
  imports: [ConfigModule, ObjectStorageModule, PrismaModule],
  controllers: [AnnouncementsController],
  providers: [AnnouncementsService],
  exports: [AnnouncementsService],
})
export class AnnouncementsModule {}
