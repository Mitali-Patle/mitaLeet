import {
  addDaysToKey, isValidTimeZone, localDateKey, localHour, safeTimeZone, startOfLocalDay,
} from './user-day';

describe('user-day helpers', () => {
  // 2026-03-10 20:00 UTC = 2026-03-11 01:30 in India
  const lateUtc = new Date('2026-03-10T20:00:00Z');

  it('uses the local calendar day, not the UTC one', () => {
    expect(localDateKey(lateUtc, 'UTC')).toBe('2026-03-10');
    expect(localDateKey(lateUtc, 'Asia/Kolkata')).toBe('2026-03-11');
    expect(localHour(lateUtc, 'Asia/Kolkata')).toBe(1);
  });

  it('finds the instant local midnight began', () => {
    expect(startOfLocalDay(lateUtc, 'Asia/Kolkata').toISOString()).toBe('2026-03-10T18:30:00.000Z');
    expect(startOfLocalDay(lateUtc, 'UTC').toISOString()).toBe('2026-03-10T00:00:00.000Z');
    expect(startOfLocalDay(new Date('2026-03-10T03:00:00Z'), 'America/Los_Angeles').toISOString())
      .toBe('2026-03-09T07:00:00.000Z');
  });

  it('handles a DST change (US spring forward 2026-03-08)', () => {
    const day = new Date('2026-03-08T12:00:00Z');
    expect(startOfLocalDay(day, 'America/New_York').toISOString()).toBe('2026-03-08T05:00:00.000Z');
    const next = new Date('2026-03-09T12:00:00Z');
    expect(startOfLocalDay(next, 'America/New_York').toISOString()).toBe('2026-03-09T04:00:00.000Z');
  });

  it('shifts day keys across month and year ends', () => {
    expect(addDaysToKey('2026-03-01', -1)).toBe('2026-02-28');
    expect(addDaysToKey('2026-12-31', 1)).toBe('2027-01-01');
  });

  it('validates and falls back safely', () => {
    expect(isValidTimeZone('Asia/Kolkata')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
    expect(safeTimeZone('Mars/Olympus')).toBe('UTC');
    expect(safeTimeZone(null)).toBe('UTC');
  });
});
