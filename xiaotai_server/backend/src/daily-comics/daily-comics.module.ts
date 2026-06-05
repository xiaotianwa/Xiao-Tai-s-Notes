import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";

import { ObjectStorageModule } from "../common/object-storage/object-storage.module";
import { PrismaModule } from "../common/prisma/prisma.module";
import { DailyComicsController } from "./daily-comics.controller";
import { DailyComicsService } from "./daily-comics.service";

@Module({
  imports: [ConfigModule, ObjectStorageModule, PrismaModule],
  controllers: [DailyComicsController],
  providers: [DailyComicsService],
  exports: [DailyComicsService],
})
export class DailyComicsModule {}
