import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from "@nestjs/core";

import { AiModule } from "./ai/ai.module";
import { AdminModule } from "./admin/admin.module";
import { AnnouncementsModule } from "./announcements/announcements.module";
import { AppVersionsModule } from "./app-versions/app-versions.module";
import { AuthModule } from "./auth/auth.module";
import { ApiExceptionFilter } from "./common/filters/api-exception.filter";
import { JwtAuthGuard } from "./common/guards/jwt-auth.guard";
import { RolesGuard } from "./common/guards/roles.guard";
import { ApiResponseInterceptor } from "./common/interceptors/api-response.interceptor";
import { PrismaModule } from "./common/prisma/prisma.module";
import { configuration } from "./config/configuration";
import { DailyComicsModule } from "./daily-comics/daily-comics.module";
import { MediaModule } from "./media/media.module";
import { MonitorModule } from "./monitor/monitor.module";
import { MusicModule } from "./music/music.module";
import { SyncModule } from "./sync/sync.module";
import { AppController } from "./app.controller";
import { UsersModule } from "./users/users.module";
import { WeatherModule } from "./weather/weather.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [configuration],
    }),
    PrismaModule,
    AdminModule,
    AnnouncementsModule,
    AppVersionsModule,
    AuthModule,
    DailyComicsModule,
    MediaModule,
    MonitorModule,
    MusicModule,
    UsersModule,
    SyncModule,
    WeatherModule,
    AiModule,
  ],
  controllers: [AppController],
  providers: [
    {
      provide: APP_FILTER,
      useClass: ApiExceptionFilter,
    },
    {
      provide: APP_INTERCEPTOR,
      useClass: ApiResponseInterceptor,
    },
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
    {
      provide: APP_GUARD,
      useClass: RolesGuard,
    },
  ],
})
export class AppModule {}
