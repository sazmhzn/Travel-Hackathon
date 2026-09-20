---
name: brag
description: Generate a polished introduction / promo video for the WhiteMountain app — an animated HTML/CSS motion-graphics reel recorded with Playwright and encoded to MP4. Use when the user says "brag", "/brag", "intro video", "introduction video", "promo video", "demo video", "pitch video", or wants to show off the project. Produces a 16:9 video file, not a live page.
---

# brag — generate the WhiteMountain intro video

Build a cinematic ~40s introduction video for this project by animating a
self-contained HTML page and recording it headlessly. Everything lives next to
this file; the repo root is four directories up.

```
.opencode/skills/brag/
├── SKILL.md                      ← you are here
├── package.json                  ← playwright + ffmpeg-static
├── assets/intro.template.html    ← the reel (edit this)
└── scripts/render.mjs            ← records HTML → MP4
```

## What the video says

The page currently contains a 7-scene timeline. Keep this skeleton, refresh the
copy from the codebase each time so the reel never drifts from reality:

1. **Brand** — `WhiteMountain`, tagline *"Outdoor travel. Never lose anyone."*
2. **Live group telemetry** — WebSocket streams + PostGIS history.
3. **Offline-first mesh** — Nearby Connections + local Wi-Fi hotspot.
4. **BLE proximity radar** — locate a missing member by signal strength.
5. **Emergency escalation** — in-app → nearby users → FCM guides → Telegram.
6. **AI destination agent** — Gemini itinerary from weather/places/routes.
7. **Closing** — stack badges + CTA.

## Workflow

### 1. Re-read the source of truth

Before touching the copy, read `Project_Briefing.md` (project overview, feature
list, tech stack) and skim `TT/lib/features/` and `tt backend/tt/src/modules/`.
Update headline, feature blurbs, and stack badges so they match what actually
shipped. Avoid claiming anything the brief marks as a stub.

### 2. Edit the template

`assets/intro.template.html` holds everything: palette, scenes, and the timeline.
The app's colours are deep teal `#0F766E` and accent orange `#EA580C`.

- Each scene is `<section class="scene" style="--in:5.2s;--out:10.4s">`.
- `--in` / `--out` are the **absolute seconds** the scene fades in and out.
- `window.__brag.duration` at the bottom is the total length in **ms**. If you
  move scene timings, update it and the `--dur` progress-bar variable to match.
  The render script reads this value to know when to stop recording.
- The logo is loaded from `../../../../TT/assets/images/wandersafe_logo.png`
  and silently falls back to the CSS mountain mark if missing.

Keep it to one page, no external network requests (fonts are system fonts) so
it renders offline.

### 3. Install once

From this skill directory:

```powershell
npm install
npx playwright install chromium
```

`ffmpeg-static` ships a private ffmpeg binary, so no system ffmpeg is required.
If the install cannot reach the network, fall back to a system ffmpeg
(`winget install Gyan.FFmpeg`) — the script detects either.

### 4. Render

```powershell
node scripts/render.mjs
```

Options (both positional, optional):

```powershell
node scripts/render.mjs [path/to/intro.html] [path/to/output.mp4]
```

Defaults: the bundled template → `./brag-out/whitemountain-intro.mp4` relative
to the current working directory. The script launches Chromium at 1920×1080,
records to WebM, transcodes to H.264/yuv420p MP4 (`+faststart`), and cleans up.

If ffmpeg is unavailable it writes `whitemountain-intro.webm` and prints how to
get the MP4 instead.

### 5. Report

Return the output path and duration. Do not commit the MP4 or `node_modules`
unless the user explicitly asks; `node_modules/` is already git-ignored, and
`brag-out/` is scratch output.

## Troubleshooting

- **`ffmpeg failed to encode`** — `ffmpeg-static` sometimes finishes with a
  truncated download. Check `node_modules/ffmpeg-static/ffmpeg.exe`: a real
  Windows build is ~80 MB. If it is ~10 MB, it is corrupt:
  `Remove-Item -Recurse -Force node_modules/ffmpeg-static; npm install ffmpeg-static`.
- **`Executable is not a valid application for this OS platform`** — same cause
  as above.
- **`ffmpeg not found - wrote WebM instead`** — no bundled or system ffmpeg.
  Reinstall the dependency, or `winget install Gyan.FFmpeg` and re-run.
- **Video length is wrong** — `window.__brag.duration` in the template does not
  match the last scene's `--out`. Keep them in sync.

## Style rules

- 16:9, 1920×1080, dark cinematic background, restrained motion (fades +
  short translates, ~0.7s, `cubic-bezier(.16,1,.3,1)`).
- Max two accent colours; no gradients on text, no drop-shadow slop.
- One idea per scene; never more than ~12 words of body copy on screen.
- Every claim must be traceable to the briefing or source.
