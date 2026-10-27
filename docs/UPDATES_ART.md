# Legal Updates thumbnails — ChatGPT prompts

Each card on the Updates tab shows a thumbnail on the right
(`lib/features/legal_updates/presentation/updates_screen.dart`). Until a file exists, the card
shows its category's Journey painting on a sand tile, so thumbnails can arrive one by one.
The header reuses `journey_constitution_landmark.webp` and needs no new art.

**Deliver:** square PNG, 1024×1024, **opaque** (full-bleed, no transparency, no border). The card
crops it to about 8:7 with the centre kept, so keep the subject centred with some room on every
side. Send the PNGs; they get converted to `.webp` and saved as `assets/images/<file name>.webp`.

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
