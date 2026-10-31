# Sound effects

All sounds come from **Envato Elements** (the user's subscription, downloaded 2026-10-31). Keep the
Envato licence certificate for each item with the project's other licences.

Each file in `assets/sounds/` was cut from the original WAV (silence removed, short fade-out), made
mono, levelled so a wrong answer is never louder than a right one, peaks limited to −1 dB, and saved as
MP3 at 96 kbps. All 8 together are about 150 KB.

| File | Plays when | Envato item (download) | Cut |
|---|---|---|---|
| `correct.mp3` | a right answer (instant-feedback modes) | Correct Answer Sound Pack → *Correct Answer 02* | 0–0.62 s |
| `wrong.mp3` | a wrong or timed-out answer | Negative Pop | 0–0.40 s |
| `level_complete.mp3` | result with confetti (2+ stars, perfect run) | Quiz Complete → *Quiz Complete 1* | 0–2.65 s |
| `chest.mp3` | a chapter chest opens | Collect Item (4-sound pack) → *Collect Item 1* | 0–2.10 s |
| `streak.mp3` | result with a streak milestone | Tiny Victory | 0–1.22 s |
| `duel_won.mp3` | duel won | Short Win → *Short Win 1* | 0–2.00 s |
| `duel_lost.mp3` | duel lost (no suitable "lose" sound was found, so a spare wrong-answer sound is used) | Soft Negative Tone | 0–1.26 s |
| `tick.mp3` | each of the last 5 seconds on a running clock (Exam Chamber, Daily Docket, duel questions) | Clock Tick (one tick) | 1.18–1.50 s |

Downloaded but not used: Correct Answer 01/03/04, Game Item or Key 5/6, Collect Item (single),
Collect Item 2–4, Quiz Complete 2/3, Quiz Success 1–3, Short Win 2–4, Sweet UI Error, Wrong Answer,
Fast Clock Tick. To swap a sound, replace the MP3 with the same name; to recut, see the ffmpeg
settings above.
