import { PrismaService } from '../../core/prisma/prisma.service';

/**
 * Calendar-day helpers in a user's own IANA timezone (e.g. "Asia/Kolkata").
 * Streaks, "solved today" and daily counters must follow the user's midnight,
 * not the server's UTC midnight (05:30 in India).
 */

const formatters = new Map<string, Intl.DateTimeFormat>();

function formatter(tz: string): Intl.DateTimeFormat {
  let f = formatters.get(tz);
  if (!f) {
    f = new Intl.DateTimeFormat('en-CA', {
      timeZone: tz, hourCycle: 'h23',
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
    });
    formatters.set(tz, f);
  }
  return f;
}

export function isValidTimeZone(tz: string): boolean {
  try {
    formatter(tz);
    return true;
  } catch {
    return false;
  }
}

/** Unknown or corrupt values fall back to UTC instead of throwing. */
export function safeTimeZone(tz: string | null | undefined): string {
  return tz && isValidTimeZone(tz) ? tz : 'UTC';
}

function localParts(date: Date, tz: string) {
  const p: Record<string, number> = {};
  for (const { type, value } of formatter(tz).formatToParts(date)) {
    if (type !== 'literal') p[type] = Number(value);
  }
  return { y: p.year, m: p.month, d: p.day, h: p.hour, mi: p.minute, s: p.second };
}

/** "YYYY-MM-DD" of `date` as seen in `tz`. Keys compare correctly as strings. */
export function localDateKey(date: Date, tz: string): string {
  const { y, m, d } = localParts(date, tz);
  return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

/** Hour 0-23 of `date` in `tz`. */
export function localHour(date: Date, tz: string): number {
  return localParts(date, tz).h;
}

/** Shift a "YYYY-MM-DD" key by whole days. */
export function addDaysToKey(key: string, days: number): string {
  const d = new Date(`${key}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/** Value for a Postgres DATE column holding a local calendar day. */
export function dateFromKey(key: string): Date {
  return new Date(`${key}T00:00:00Z`);
}

function utcOffsetMs(date: Date, tz: string): number {
  const p = localParts(date, tz);
  const asUtc = Date.UTC(p.y, p.m - 1, p.d, p.h, p.mi, p.s);
  return asUtc - Math.floor(date.getTime() / 1000) * 1000;
}

/** The instant at which the local day containing `date` began in `tz`. */
export function startOfLocalDay(date: Date, tz: string): Date {
  const [y, m, d] = localDateKey(date, tz).split('-').map(Number);
  const utcMidnight = Date.UTC(y, m - 1, d);
  // Two passes so a DST change near midnight resolves to the right offset.
  let guess = utcMidnight - utcOffsetMs(new Date(utcMidnight), tz);
  guess = utcMidnight - utcOffsetMs(new Date(guess), tz);
  return new Date(guess);
}

export async function getUserTimeZone(prisma: PrismaService, userId: string): Promise<string> {
  const profile = await prisma.userProfile.findUnique({ where: { userId }, select: { timezone: true } });
  return safeTimeZone(profile?.timezone);
}
