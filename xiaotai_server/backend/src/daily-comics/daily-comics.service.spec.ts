import { BadRequestException } from '@nestjs/common';

import {
  dailyComicPublishCutoff,
  normalizeDailyComicImages,
  parseDailyComicPublishDate,
} from './daily-comics.service';

describe('DailyComicsService helpers', () => {
  it('normalizes image order for a valid comic payload', () => {
    const images = normalizeDailyComicImages([
      {
        imageUrl: '/api/v1/daily-comics/images/comic-a.webp',
        originalName: 'a.webp',
      },
      {
        imageUrl: '/api/v1/daily-comics/images/comic-b.webp',
        originalName: 'b.webp',
      },
    ]);

    expect(images).toHaveLength(2);
    expect(images[0].imageUrl).toContain('comic-a');
    expect(images[0].sortOrder).toBe(0);
    expect(images[1].imageUrl).toContain('comic-b');
    expect(images[1].sortOrder).toBe(1);
  });

  it('rejects comic payloads with more than ten images', () => {
    const images = Array.from({ length: 11 }, (_, index) => ({
      imageUrl: `/api/v1/daily-comics/images/comic-${index}.webp`,
    }));

    expect(() => normalizeDailyComicImages(images)).toThrow(BadRequestException);
  });

  it('rejects images not uploaded through the comic image endpoint', () => {
    expect(() =>
      normalizeDailyComicImages([{ imageUrl: '/api/v1/media/images/a.webp' }]),
    ).toThrow(BadRequestException);
  });

  it('parses publish date as a stable day boundary', () => {
    const date = parseDailyComicPublishDate('2026-05-27');

    expect(date.toISOString()).toBe('2026-05-27T00:00:00.000Z');
  });

  it('uses Asia Shanghai date for latest comic cutoff', () => {
    const cutoff = dailyComicPublishCutoff(
      new Date('2026-05-28T16:30:00.000Z'),
    );

    expect(cutoff.toISOString()).toBe('2026-05-29T00:00:00.000Z');
  });

  it('rejects invalid calendar dates', () => {
    expect(() => parseDailyComicPublishDate('2026-02-31')).toThrow(
      BadRequestException,
    );
  });
});
