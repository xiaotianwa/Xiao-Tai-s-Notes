import { Module } from '@nestjs/common';

import { ObjectStorageModule } from '../common/object-storage/object-storage.module';
import { PrismaModule } from '../common/prisma/prisma.module';
import {
  AdminAppVersionsController,
  AppVersionsController,
} from './app-versions.controller';
import { AppVersionsService } from './app-versions.service';

@Module({
  imports: [ObjectStorageModule, PrismaModule],
  controllers: [AppVersionsController, AdminAppVersionsController],
  providers: [AppVersionsService],
})
export class AppVersionsModule {}
