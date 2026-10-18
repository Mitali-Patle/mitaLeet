import { ConsoleLogger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { AppModule } from './app.module';
import { configureApp } from './app.setup';

async function bootstrap() {
  // Structured JSON logs in production (searchable fields in Render / log drains).
  const app = await NestFactory.create(AppModule, {
    logger: new ConsoleLogger({ json: process.env.NODE_ENV === 'production' }),
  });
  configureApp(app);
  // Run onModuleDestroy hooks on SIGTERM (every deploy) so in-flight work
  // finishes and DB connections close cleanly.
  app.enableShutdownHooks();

  const port = app.get(ConfigService).get<number>('PORT', 3000);
  await app.listen(port, '0.0.0.0');
  console.log(`[mitaLeet] Server running on port ${port}`);
}
bootstrap();
