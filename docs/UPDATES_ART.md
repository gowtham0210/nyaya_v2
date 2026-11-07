# Legal Updates thumbnails — ChatGPT prompts

Each news article's card picture is **uploaded in the content portal** (News → article → *Card
picture*) and served by the API; it is no longer bundled in the app. Without one, the card shows
its category's Journey painting. The prompts below are a starting point for editors.

**Upload:** JPEG, PNG or WebP, up to 5 MB and at least 480 pixels wide. A landscape picture of
about 1536×1024 works best. The API re-saves it as WebP, at most 1200 pixels. The Home card
crops it to 2:1 and the Updates list to about 8:7, both centred, and the list's top-right corner
holds the save button: keep the subject centred and the edges quiet.

## Shared style (paste before every prompt)

> Warm, softly lit editorial still life in a realistic painterly style, like a premium Indian
> news magazine photo. Shallow depth of field, gentle window light from the left, subtle film
> grain. Palette: terracotta #873F2B, burnt clay #B96243, sand #D9B994, warm cream #F5EBDD,
> deep brown wood, touches of muted sage green. Calm, low contrast, no harsh shadows. Full-bleed
> square image, subject centred. No people, no faces, no logos, no watermarks, no national emblem.

## Prompts

| # | File name | Card | Subject prompt (append to the shared style) |
|---|-----------|------|----------------------------------------------|
| 1 | `update_tn_governor_assent` | SC sets timelines for Governors on State Bills | The Supreme Court of India building in New Delhi (central dome, red-sandstone and cream colonnade), seen from the front on a clear soft morning, leafy trees on both sides, a few birds in a pale sky. |
| 2 | `update_waqf_amendment_2025` | Waqf (Amendment) Act, 2025 | Close-up of a printed government gazette page lying slightly angled on a wooden desk, a fountain pen beside it. Printed text only as blurred, illegible lines. |
| 3 | `update_pocso_csam` | Storing or watching abuse material is an offence | A dark wooden judge's gavel resting on its round sound block on a polished courtroom desk, warm light, blurred bookshelves behind. |
| 4 | `update_sc_subclassification` | States may sub-classify Scheduled Castes | Corner of a cream stone court building with tall classical columns and a tall wooden door, the words "EQUALITY · JUSTICE · OPPORTUNITY" carved into the stone wall. |
| 5 | `update_new_criminal_laws` | BNS, BNSS and BSA replace IPC, CrPC and Evidence Act | Three new hardbound law books standing upright side by side on a desk, plain terracotta, sand and brown covers, an older faded book lying flat behind them. Spines show only "BNS", "BNSS" and "BSA". |
| 6 | `update_electoral_bonds` | Electoral Bonds Scheme struck down | A wooden ballot box with a slot on a table, a few blank folded slips of paper beside it, soft light. |
| 7 | `update_dpdp_act` | Digital Personal Data Protection Act, 2023 | A smartphone lying face up on a wooden desk, its screen showing a simple glowing padlock symbol, a cup of chai and a notebook out of focus beside it. |
| 8 | `update_explainer_zero_fir` | Explainer: Zero FIR and e-FIR | A stack of three old leather-bound books on a desk, the top one with "FIR" embossed in gold on its cover. |
| 9 | `update_explainer_legal_aid` | Explainer: Who can get free legal aid? | Two hands across a wooden desk, one passing a simple folder of papers to the other, only hands and sleeves visible, a small brass scales of justice out of focus behind. |
| 10 | `update_mediation_act` | Mediation Act makes mediation mainstream | A round wooden table with two empty chairs facing each other, two cups of tea and a few papers on it, soft light through a window. |

Priority: 1–4 are on the first screen, then 8 (Explainers).

## Category paintings (bundled in the app)

An article with no uploaded picture shows its category's painting. These used to be borrowed from
the Journey map, so the same pictures showed up in two places (tester review, 2026-11-07). The four
prompts below give each category its own painting. Until a file is added, the card keeps showing
the Journey painting.

Save each into `assets/images/` with the file name shown; I convert to WebP at about 480 × 420.
The Updates list crops to about 8:7 with the save button over the top-right corner, so keep that
corner plain. These prompts use the watercolour style of the Home art, not the shared photo style
above.

### `updates_supreme_court` — Supreme Court

> Create an image. Soft hand-painted watercolour illustration in a warm Indian editorial style, like a premium law-journal cover. Warm sunlit cream and parchment palette with terracotta #873F2B, burnt clay #B96243, sand #D9B994, muted sage green and a little ochre gold. Gentle brush texture, soft edges, no hard black outlines, calm low contrast. Square picture, 1024 x 1024 pixels, subject in the middle, top-right corner left quiet and plain. No people, no faces, no letters or text, no logos, no watermark, no border or frame, no national emblem. A judge's wooden gavel resting on its round sound block on a polished desk, an open leather-bound judgment volume behind it with a red ribbon bookmark, warm light from the left.

### `updates_high_courts` — High Courts

> Create an image. Soft hand-painted watercolour illustration in a warm Indian editorial style, like a premium law-journal cover. Warm sunlit cream and parchment palette with terracotta #873F2B, burnt clay #B96243, sand #D9B994, muted sage green and a little ochre gold. Gentle brush texture, soft edges, no hard black outlines, calm low contrast. Square picture, 1024 x 1024 pixels, subject in the middle, top-right corner left quiet and plain. No people, no faces, no letters or text, no logos, no watermark, no border or frame, no national emblem. A red-brick colonial-era court building with tall arched windows and a clock tower, palm and neem trees in front, a pale warm sky.

### `updates_legislation` — Legislation (new laws)

> Create an image. Soft hand-painted watercolour illustration in a warm Indian editorial style, like a premium law-journal cover. Warm sunlit cream and parchment palette with terracotta #873F2B, burnt clay #B96243, sand #D9B994, muted sage green and a little ochre gold. Gentle brush texture, soft edges, no hard black outlines, calm low contrast. Square picture, 1024 x 1024 pixels, subject in the middle, top-right corner left quiet and plain. No people, no faces, no letters or text, no logos, no watermark, no border or frame, no national emblem. A rolled parchment scroll tied with a terracotta ribbon and a wax seal, lying beside a fountain pen and an inkpot on a wooden desk.

### `updates_explainer` — Explainers

> Create an image. Soft hand-painted watercolour illustration in a warm Indian editorial style, like a premium law-journal cover. Warm sunlit cream and parchment palette with terracotta #873F2B, burnt clay #B96243, sand #D9B994, muted sage green and a little ochre gold. Gentle brush texture, soft edges, no hard black outlines, calm low contrast. Square picture, 1024 x 1024 pixels, subject in the middle, top-right corner left quiet and plain. No people, no faces, no letters or text, no logos, no watermark, no border or frame, no national emblem. An open notebook with a few blank lined pages, a glowing brass desk lamp above it and a pair of round reading glasses resting on the page.
