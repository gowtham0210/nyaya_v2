import { createHash } from 'node:crypto';
import { HttpStatus } from '@nestjs/common';
import sharp from 'sharp';
import { ApiError } from '../core/errors.js';

/** Largest upload the portal may send. */
export const MAX_PICTURE_BYTES = 5 * 1024 * 1024;

/** Stored pictures are at most this wide or tall: sharp on any phone, small to download. */
const MAX_SIDE = 1200;

/** Narrower pictures look blurry on the app's cards. */
const MIN_WIDTH = 480;

const ACCEPTED = new Set(['jpeg', 'png', 'webp']);

export interface CardPicture {
  data: Buffer;
  width: number;
  height: number;
  /** Changes whenever the bytes do; part of the picture's address. */
  version: string;
}

const invalid = (reason: string) =>
  new ApiError(HttpStatus.UNPROCESSABLE_ENTITY, 'invalid_picture', reason);

/**
 * Checks an uploaded picture and re-encodes it as WebP. Re-encoding keeps
 * only the pixels: camera details and location are dropped, and nothing but
 * a plain image is ever served from our domain.
 */
export async function toCardPicture(input: Buffer): Promise<CardPicture> {
  let format: string | undefined;
  let width = 0;
  try {
    ({ format, width = 0 } = await sharp(input).metadata());
  } catch {
    throw invalid('This file is not a picture we can read');
  }
  if (!format || !ACCEPTED.has(format))
    throw invalid('Upload a JPEG, PNG or WebP picture');
  if (width < MIN_WIDTH)
    throw invalid(`The picture must be at least ${MIN_WIDTH} pixels wide`);
  try {
    const { data, info } = await sharp(input, {
      failOn: 'error',
      limitInputPixels: 50_000_000,
    })
      .rotate() // upright, from the camera's orientation
      .resize({
        width: MAX_SIDE,
        height: MAX_SIDE,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .webp({ quality: 80 })
      .toBuffer({ resolveWithObject: true });
    return {
      data,
      width: info.width,
      height: info.height,
      version: createHash('sha256').update(data).digest('hex').slice(0, 16),
    };
  } catch {
    throw invalid('This picture is damaged or too large to process');
  }
}
