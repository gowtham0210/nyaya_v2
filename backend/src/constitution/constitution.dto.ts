import { ApiProperty } from '@nestjs/swagger';

export class ConstitutionFileDto {
  @ApiProperty({ example: 'pdf' }) format: string;
  @ApiProperty({
    description:
      'As India Code reports it; treat as approximate (the served file can differ)',
  })
  size_bytes: number;
  @ApiProperty({ description: 'MD5 as India Code reports it' })
  checksum_md5: string;
  @ApiProperty({
    type: String,
    format: 'date',
    description: 'The day the item last changed on India Code',
  })
  source_modified_at: string;
}

export class ConstitutionFlagsDto {
  @ApiProperty({
    description: 'A large download: warn before opening on mobile data',
  })
  large: boolean;
  @ApiProperty({
    description:
      'Scanned pages with no text layer: cannot be searched or read aloud',
  })
  scanned: boolean;
}

export class ConstitutionEditionDto {
  @ApiProperty({
    example: 'ta',
    description: 'Stable id; `original` for the 1950 copy',
  })
  id: string;
  @ApiProperty({ type: String, nullable: true, example: 'ta' })
  language_code: string | null;
  @ApiProperty({ example: 'Tamil' }) language_name: string;
  @ApiProperty({ type: String, nullable: true, example: 'தமிழ்' })
  native_name: string | null;
  @ApiProperty({ type: String, nullable: true }) script: string | null;
  @ApiProperty({ example: 'The Constitution of India in Tamil' }) title: string;
  @ApiProperty({
    type: String,
    nullable: true,
    description:
      "India Code's own title for the item, kept for attribution (it can contain typos)",
  })
  source_title: string | null;
  @ApiProperty({
    type: String,
    nullable: true,
    description:
      'Reviewed wording about this edition’s legal standing; null until approved. Do not infer authority when null.',
  })
  authority_note: string | null;
  @ApiProperty({
    description:
      'Official India Code address of the PDF (https, India Code host only)',
  })
  download_url: string;
  @ApiProperty({ description: "The item's page on India Code" })
  source_page_url: string;
  @ApiProperty({ type: ConstitutionFileDto }) file: ConstitutionFileDto;
  @ApiProperty({ type: ConstitutionFlagsDto }) flags: ConstitutionFlagsDto;
}

export class ConstitutionSourceDto {
  @ApiProperty() name: string;
  @ApiProperty({ description: 'The collection page on India Code' })
  collection_url: string;
  @ApiProperty({
    type: String,
    format: 'date-time',
    nullable: true,
    description: 'When India Code was last read; null if it never was',
  })
  fetched_at: string | null;
  @ApiProperty({
    description:
      'True when India Code could not be reached and reviewed values are shown',
  })
  stale: boolean;
}

export class ConstitutionDto {
  @ApiProperty({ type: ConstitutionSourceDto }) source: ConstitutionSourceDto;
  @ApiProperty({ description: 'Neutral attribution to show with the list' })
  notice: string;
  @ApiProperty({ type: ConstitutionEditionDto, nullable: true })
  original: ConstitutionEditionDto | null;
  @ApiProperty({ type: [ConstitutionEditionDto] })
  editions: ConstitutionEditionDto[];
}

export const DRIFT_STATES = [
  'unchanged',
  'changed',
  'missing',
  'unknown',
] as const;
export type DriftState = (typeof DRIFT_STATES)[number];

export class DriftLiveDto {
  @ApiProperty({ format: 'uuid' }) bitstream_uuid: string;
  @ApiProperty() md5: string;
  @ApiProperty() size_bytes: number;
  @ApiProperty({ type: String, format: 'date' }) item_modified: string;
}

export class DriftItemDto {
  @ApiProperty() id: string;
  @ApiProperty() language_name: string;
  @ApiProperty({ enum: DRIFT_STATES }) state: DriftState;
  @ApiProperty({
    type: [String],
    description:
      'What differs from the reviewed values: bitstream, checksum, size, text_layer',
  })
  changed_fields: string[];
  @ApiProperty({
    description:
      'The item was edited on India Code after the review, though its file may be the same',
  })
  modified_since_review: boolean;
  @ApiProperty({ type: DriftLiveDto, nullable: true })
  live: DriftLiveDto | null;
}

export class DriftNewItemDto {
  @ApiProperty({ format: 'uuid' }) item_uuid: string;
  @ApiProperty() handle: string;
  @ApiProperty() title: string;
  @ApiProperty({ type: Number, nullable: true }) size_bytes: number | null;
}

export class DriftSummaryDto {
  @ApiProperty() unchanged: number;
  @ApiProperty() changed: number;
  @ApiProperty() missing: number;
  @ApiProperty() new: number;
}

export class ConstitutionDriftDto {
  @ApiProperty({ type: String, format: 'date-time', nullable: true })
  fetched_at: string | null;
  @ApiProperty({
    type: String,
    nullable: true,
    description: 'Why the last read of India Code failed, if it did',
  })
  last_error: string | null;
  @ApiProperty({ type: DriftSummaryDto }) summary: DriftSummaryDto;
  @ApiProperty({ type: [DriftItemDto] }) items: DriftItemDto[];
  @ApiProperty({
    type: [DriftNewItemDto],
    description:
      'On India Code but not in the manifest: hidden from the app until curated',
  })
  new_items: DriftNewItemDto[];
}
