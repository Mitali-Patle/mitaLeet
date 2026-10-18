// Runs in every test worker before any module is imported.
// All configuration comes from here (the app ignores .env when NODE_ENV=test).
process.env.NODE_ENV = 'test';
process.env.DATABASE_URL =
  process.env.TEST_DATABASE_URL ?? 'postgresql://ml:ml@localhost:55432/ml_test?schema=public';
process.env.JWT_SECRET = 'e2e-test-secret-not-used-anywhere-else';
process.env.JWT_ACCESS_EXPIRATION = '15m';
process.env.JWT_REFRESH_EXPIRES_IN = '30d';
process.env.GOOGLE_CLIENT_ID = 'test-google-client-id';
process.env.FIREBASE_PROJECT_ID = 'test-project';
process.env.ENABLE_DEV_LOGIN = 'true';
process.env.LEETCODE_QUICK_SYNC_INTERVAL_MS = '0';
// Suites make many requests; test/rate-limit.e2e-spec.ts turns limits back on.
process.env.THROTTLE_DISABLED = 'true';
