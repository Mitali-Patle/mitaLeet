import { Logger } from '@nestjs/common';
import { createHash } from 'crypto';
import { PrismaService } from '../../core/prisma/prisma.service';

const logger = new Logger('RunExclusive');

/** Stable 64-bit advisory-lock key for a job name. */
function lockKey(name: string): bigint {
  return createHash('sha256').update(`mitaleet:${name}`).digest().readBigInt64BE(0);
}

/**
 * Run a scheduled job on exactly one instance at a time, using a Postgres
 * transaction-scoped advisory lock (released automatically on commit/rollback,
 * so a crashed instance never leaves it held). Other instances skip the run.
 */
export async function runExclusive(
  prisma: PrismaService,
  name: string,
  job: () => Promise<void>,
  maxDurationMs = 25 * 60_000,
): Promise<boolean> {
  const key = lockKey(name);
  return prisma.$transaction(
    async (tx) => {
      const [{ locked }] = await tx.$queryRaw<{ locked: boolean }[]>`SELECT pg_try_advisory_xact_lock(${key}) AS locked`;
      if (!locked) {
        logger.log(`${name}: running on another instance, skipping`);
        return false;
      }
      await job();
      return true;
    },
    { maxWait: 10_000, timeout: maxDurationMs },
  );
}
