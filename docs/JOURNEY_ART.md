# Journey (Case Path) artwork — ChatGPT prompts

Paintings sit at the left/right edges of each chapter's stretch of road, behind the
road and level bubbles. Code: `lib/features/journey/presentation/journey_scenery.dart`.
Until a file exists the map shows a faint icon in its place, so they can arrive one by one.

**Deliver:** square PNG, 1024×1024, **transparent background** (if transparency fails, use a
flat solid `#F5EBDD` background). Send the PNGs; they get converted to `.webp` and saved as
`assets/images/<file name>.webp`.

## Shared style (paste before every prompt)

> Soft watercolour and gouache illustration in a warm, painterly editorial style, like a
> vintage Indian travel poster faded to pastel. Palette only: terracotta #873F2B, burnt clay
> #B96243, sand #D9B994, warm cream #F5EBDD, muted sage green trees, soft ochre light.
> Low contrast, hazy and airy, gentle paper texture, edges dissolving softly into nothing
> (no hard frame, no border, no ground line cutting off). Single isolated subject, generous
> empty space around it, transparent background. No text, no letters, no logos, no people's
> faces in close-up, no flags, no national emblem.

## Prompts

| # | File name | Placement | Subject prompt (append to the shared style) |
|---|-----------|-----------|----------------------------------------------|
| 1 | `journey_constitution_landmark` | Ch 1, top right | The Supreme Court of India building in New Delhi (central dome, red-sandstone and cream colonnade), seen from a three-quarter angle on the left side, with two leafy trees beside it and two small birds in the sky. Building anchored to the right edge of the canvas. |
| 2 | `journey_constitution_prop` | Ch 1, bottom left | A stack of three thick antique leather-bound law books lying flat, the top one slightly angled, with a few olive and fern leaves growing behind them. Books anchored to the bottom-left of the canvas. Spines plain, no lettering. |
| 3 | `journey_scales` | Ch 1 bottom right, Ch 6 bottom right | Classic brass scales of justice, balanced, standing on a small base, drawn faint and pale like a watermark. Centred, lots of space around. |
| 4 | `journey_rights_landmark` | Ch 2, top left | The old circular Parliament House of India (Samvidhan Sadan) with its ring of cream colonnades, seen from a low three-quarter angle, a neem tree in front. Anchored to the left edge of the canvas. |
| 5 | `journey_rights_prop` | Ch 2, bottom right | A rolled parchment scroll partly open, a feather quill resting in a brass inkpot and a small lit clay diya, on a hint of wooden desk. Anchored to the bottom-right. |
| 6 | `journey_criminal_landmark` | Ch 3, top right | A colonial-era red-brick Indian district court building with arched verandas and a clock tower, a large banyan tree beside it. Anchored to the right edge. |
| 7 | `journey_criminal_prop` | Ch 3, bottom left | A wooden judge's gavel resting on its sound block next to two closed law books. Anchored to the bottom-left. |
| 8 | `journey_procedure_landmark` | Ch 4, top left | The Madras High Court in Chennai in Indo-Saracenic style — red domes, minarets and arches — with palm trees. Anchored to the left edge. |
| 9 | `journey_procedure_prop` | Ch 4, bottom right | A tall stack of old Indian court case files tied with faded red cloth tape, a couple of loose papers sliding off. Anchored to the bottom-right. |
| 10 | `journey_civil_landmark` | Ch 5, top right | A traditional Indian family house with a tiled sloping roof, wooden pillared veranda and a courtyard tulsi planter, a mango tree beside it. Anchored to the right edge. |
| 11 | `journey_civil_prop` | Ch 5, bottom left | A signed agreement on old stamp paper with a fountain pen lying across it and a round wax-free rubber stamp beside it. Writing shown only as illegible scribbles. Anchored to the bottom-left. |
| 12 | `journey_everyday_landmark` | Ch 6, top left | A quiet Indian neighbourhood street corner: a small general store with an awning, a parked auto-rickshaw and a street lamp, a gulmohar tree. Anchored to the left edge. |

Priority: 1–3 are visible on the first screen, then 4–5; the rest can follow.
