import { Module } from "@nestjs/common";

import { ObjectStorageModule } from "../common/object-storage/object-storage.module";
import { PrismaModule } from "../common/prisma/prisma.module";
import { AdminController } from "./admin.controller";
import { AdminService } from "./admin.service";

@Module({
  imports: [ObjectStorageModule, PrismaModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
