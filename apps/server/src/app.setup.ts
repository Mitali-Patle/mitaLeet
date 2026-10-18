import { INestApplication, ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { TransformInterceptor } from './common/interceptors/transform.interceptor';
import { LoggingInterceptor } from './common/interceptors/logging.interceptor';

/**
 * Global HTTP setup shared by the real server (main.ts) and the e2e tests,
 * so tests exercise exactly the same middleware, prefix, pipes and filters.
 */
export function configureApp(app: INestApplication): void {
  const config = app.get(ConfigService);

  // Behind Render/Cloudflare the client IP arrives in X-Forwarded-For; trust that
  // many proxy hops so rate limits and logs see real client IPs.
  (app as NestExpressApplication).set('trust proxy', Number(config.get('TRUST_PROXY_HOPS', 1)));

  // Security
  app.use(helmet());

  const isDev = config.get<string>('NODE_ENV', 'development') !== 'production';

  // Build the origin allowlist. In dev every localhost variant is allowed;
  // in production the list comes from the CORS_ORIGINS env var.
  const prodOrigins = config
    .get<string>('CORS_ORIGINS', '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean);

  const devOrigins = [
    'http://localhost:3000',
    'http://localhost:4200',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'capacitor://localhost',
    'ionic://localhost',
  ];

  const allowedOrigins = isDev ? devOrigins : prodOrigins;

  console.log(`[CORS] mode=${isDev ? 'dev' : 'prod'} origins=${JSON.stringify(allowedOrigins)}`);

  app.enableCors({
    origin: (
      origin: string | undefined,
      callback: (err: Error | null, allow?: boolean) => void,
    ) => {
      // No origin = mobile app / curl / Postman — always allow
      if (!origin) return callback(null, true);
      // In dev also allow any localhost port
      if (isDev && (origin.startsWith('http://localhost') || origin.startsWith('http://127.0.0.1'))) {
        return callback(null, true);
      }
      if (allowedOrigins.includes(origin)) return callback(null, true);
      console.warn(`[CORS] blocked origin: ${origin}`);
      callback(null, false);
    },
    credentials: true,
    methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  // API prefix + versioning (health checks stay at /health for the platform)
  app.setGlobalPrefix('api/v1', { exclude: ['health', 'health/live'] });

  // Global pipes
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // Global filters & interceptors
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(
    new LoggingInterceptor(),
    new TransformInterceptor(),
  );
}
