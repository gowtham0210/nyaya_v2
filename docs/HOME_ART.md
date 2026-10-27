# Home "Start here" cards — ChatGPT prompts

The carousel under "Explore Law" on Home
(`lib/features/home/presentation/widgets/explore_sections.dart`) has three cards. The Constitution card
uses `assets/images/explore_constitution.webp` (the Supreme Court painting). Both prompts below have
been generated and added (`explore_bns.webp`, `explore_everyday.webp`).

**Deliver:** square PNG, 1024×1024 or larger, **opaque**. The painting sits on the right of the card, and
the card's title and button sit over its left side. The left edge must fade into the flat blush
**#F0D5C5**, the card colour, so there is no seam. Send the PNGs; they get converted to `.webp` and saved
as `assets/images/<file name>.webp`.

## Shared style (paste before every prompt)

> Warm painterly illustration in the style of a soft watercolour-and-gouache editorial painting, golden
> late-afternoon light, gentle haze. Palette: terracotta #873F2B, burnt clay #B96243, red sandstone,
> cream #F5EBDD, sand #D9B994, muted olive-green foliage. Square image. The subject sits in the
> right half and lower right, cropped by the right and bottom edges. The whole left 40% is empty
> hazy sky that fades smoothly into a flat, even blush colour #F0D5C5 at the left edge, with nothing
> drawn there. No text, no letters, no logos, no watermarks, no borders.

## Prompts

| # | File name | Card | Subject prompt (append to the shared style) |
|---|-----------|------|----------------------------------------------|
| 1 | `explore_bns` | Bharatiya Nyaya Sanhita: offences and punishments under India's new criminal code | A large antique brass scales of justice standing on a stack of three thick hardbound law books with plain terracotta, sand and brown covers. The books rest on a carved dark-wood courtroom desk. Behind them, softly out of focus, are tall red-sandstone and cream colonnade columns. A wooden gavel lies beside the books. Warm light glints on the brass. |
| 2 | `explore_everyday` | Everyday Law: your rights in daily life | A lively Indian neighbourhood street corner at golden hour. A small chai stall with a striped awning and a kettle steaming, a parked bicycle and a scooter, potted plants and a neem tree, and cream and terracotta-plastered houses with wooden balconies and shuttered windows. People are seen only from behind or as small soft distant figures with no visible faces: a shopkeeper, a woman with a cloth shopping bag and a child with a school bag. |

Each painting's left edge colour is used as its card colour in `_FeaturedImage`, so there is no seam.
