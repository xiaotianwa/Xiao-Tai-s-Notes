import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import helmet from "helmet";

import { AppModule } from "./app.module";
import type { AppConfig } from "./config/configuration";

interface ExpressLikeApp {
  set(setting: string, value: unknown): void;
}

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const configService = app.get(ConfigService<AppConfig, true>);
  const expressApp = app.getHttpAdapter().getInstance() as ExpressLikeApp;

  expressApp.set("trust proxy", true);

  app.setGlobalPrefix("api/v1", {
    exclude: ["health"],
  });
  app.use(
    helmet({
      crossOriginResourcePolicy: { policy: "cross-origin" },
    }),
  );
  app.enableCors({
    origin: configService.get("corsOrigins", { infer: true }),
    credentials: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  const swaggerConfig = new DocumentBuilder()
    .setTitle("婷婷的小笨笔记 V2 API")
    .setDescription("婷婷的小笨笔记私有同步与管理端 API")
    .setVersion("0.1.0")
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup("api/docs", app, document);

  await app.listen(configService.get("port", { infer: true }));
}

void bootstrap();
