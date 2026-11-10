'use client';

import { useRef, useState, useTransition } from 'react';
import { Alert, Button, inputClass } from '@/components/ui';
import { removeNewsPicture, uploadNewsPicture } from '../actions';

const MAX_BYTES = 5 * 1024 * 1024;

/**
 * The picture on the article's card in the app. Shown cropped the two ways
 * the app crops it, so editors can see what learners will see.
 */
export function PictureCard({
  articleId,
  picture,
  editable,
}: {
  articleId: string;
  picture: { url: string; width: number; height: number } | null;
  editable: boolean;
}) {
  const input = useRef<HTMLInputElement>(null);
  const [error, setError] = useState<string>();
  const [pending, startTransition] = useTransition();
  const [busy, setBusy] = useState<'upload' | 'remove' | null>(null);
  // Same version as the API's address, so a new picture shows at once.
  const src = picture ? `/news/${articleId}/picture?v=${new URL(picture.url, 'http://x').searchParams.get('v')}` : null;

  const upload = (file: File | undefined) => {
    setError(undefined);
    if (!file) return;
    if (file.size > MAX_BYTES) return setError('The picture is larger than 5 MB.');
    const form = new FormData();
    form.set('file', file);
    setBusy('upload');
    startTransition(async () => {
      try {
        const res = await uploadNewsPicture(articleId, form);
        setError(res.error);
      } catch {
        setError('The picture could not be uploaded. Check your connection and try again.');
      }
      setBusy(null);
      if (input.current) input.current.value = '';
    });
  };

  const remove = () => {
    setError(undefined);
    setBusy('remove');
    startTransition(async () => {
      const res = await removeNewsPicture(articleId);
      setError(res.error);
      setBusy(null);
    });
  };

  return (
    <div className="flex flex-col gap-4">
      {src ? (
        <div className="flex flex-wrap items-end gap-4">
          <figure className="flex flex-col gap-1">
            {/* eslint-disable-next-line @next/next/no-img-element -- a private, already-small WebP */}
            <img src={src} alt="Home card crop" className="h-[124px] w-[248px] rounded-xl object-cover" />
            <figcaption className="text-xs text-muted">Home card</figcaption>
          </figure>
          <figure className="flex flex-col gap-1">
            {/* eslint-disable-next-line @next/next/no-img-element -- a private, already-small WebP */}
            <img src={src} alt="Updates list crop" className="h-[104px] w-[118px] rounded-lg object-cover" />
            <figcaption className="text-xs text-muted">Updates list</figcaption>
          </figure>
          <p className="text-xs text-muted">
            Stored at {picture!.width} × {picture!.height} pixels.
          </p>
        </div>
      ) : (
        <p className="text-sm text-muted">No picture yet. The app shows a painting for the category instead.</p>
      )}

      {editable && (
        <div className="flex flex-col gap-2">
          <label htmlFor="news-picture" className="text-sm font-medium">
            {src ? 'Replace picture' : 'Upload picture'}
          </label>
          <input
            ref={input}
            id="news-picture"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            disabled={pending}
            onChange={(e) => upload(e.target.files?.[0])}
            className={`${inputClass} file:mr-3 file:rounded-md file:border-0 file:bg-surface-2 file:px-3 file:py-1 file:text-text`}
          />
          <p className="text-xs text-muted">
            JPEG, PNG or WebP, up to 5 MB and at least 480 pixels wide. A landscape picture of about 1200 × 800 works
            best. Keep the main subject in the centre: the app trims the edges, and the top-right corner holds the save
            button in the Updates list.
          </p>
          {pending && <p className="text-sm text-muted">{busy === 'remove' ? 'Removing…' : 'Uploading…'}</p>}
          {src && (
            <div>
              <Button type="button" variant="secondary" disabled={pending} onClick={remove}>
                Remove picture
              </Button>
            </div>
          )}
        </div>
      )}
      {error && <Alert>{error}</Alert>}
    </div>
  );
}
