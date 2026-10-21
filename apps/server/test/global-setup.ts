import { execSync } from 'child_process';

/** Recreate the test database schema from the committed migrations once per run. */
export default async function globalSetup(): Promise<void> {
  const url =
    process.env.TEST_DATABASE_URL ?? 'postgresql://ml:ml@localhost:55432/ml_test?schema=public';
  if (!/test/i.test(url)) {
    throw new Error(`Refusing to reset a database whose URL does not mention "test": ${url.replace(/\/\/.*@/, '//***@')}`);
  }
  execSync('npx prisma migrate reset --force --skip-seed --skip-generate', {
    stdio: 'inherit',
    env: { ...process.env, DATABASE_URL: url },
  });
}
