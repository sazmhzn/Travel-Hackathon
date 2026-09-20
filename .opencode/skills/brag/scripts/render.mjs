import { chromium } from 'playwright';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, renameSync, rmSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const skillRoot = resolve(here, '..');

const positional = process.argv.slice(2).filter((a) => !a.startsWith('--'));
const htmlPath = resolve(positional[0] ?? resolve(skillRoot, 'assets/intro.template.html'));
const outPath = resolve(positional[1] ?? resolve(process.cwd(), 'brag-out/whitemountain-intro.mp4'));

const WIDTH = 1920;
const HEIGHT = 1080;
const FPS = 30;

if (!existsSync(htmlPath)) {
  console.error(`[brag] HTML not found: ${htmlPath}`);
  process.exit(1);
}

async function findFfmpeg() {
  try {
    const mod = await import('ffmpeg-static');
    const bin = mod.default;
    if (bin && existsSync(bin)) return bin;
  } catch {
    // ffmpeg-static not installed; fall through to a system binary.
  }
  if (spawnSync('ffmpeg', ['-version'], { stdio: 'ignore' }).status === 0) return 'ffmpeg';
  return null;
}

const tmpDir = resolve(skillRoot, '.tmp');
rmSync(tmpDir, { recursive: true, force: true });
mkdirSync(tmpDir, { recursive: true });
mkdirSync(dirname(outPath), { recursive: true });

console.log(`[brag] source : ${htmlPath}`);
console.log(`[brag] output : ${outPath}`);

const browser = await chromium.launch();
const context = await browser.newContext({
  viewport: { width: WIDTH, height: HEIGHT },
  deviceScaleFactor: 1,
  recordVideo: { dir: tmpDir, size: { width: WIDTH, height: HEIGHT } },
});

const page = await context.newPage();
await page.goto(pathToFileURL(htmlPath).href, { waitUntil: 'load' });
await page.waitForFunction(() => window.__brag && window.__brag.duration > 0);

const duration = await page.evaluate(() => window.__brag.duration);
console.log(`[brag] recording ${(duration / 1000).toFixed(1)}s at ${WIDTH}x${HEIGHT}`);

await page.waitForTimeout(duration + 400);

const video = page.video();
await context.close();
await browser.close();

const webm = await video.path();
const ffmpeg = await findFfmpeg();

if (!ffmpeg) {
  const fallback = outPath.replace(/\.mp4$/i, '.webm');
  renameSync(webm, fallback);
  rmSync(tmpDir, { recursive: true, force: true });
  console.warn(`[brag] ffmpeg not found - wrote WebM instead: ${fallback}`);
  console.warn('[brag] install ffmpeg (`winget install Gyan.FFmpeg`) and re-run for MP4.');
  process.exit(0);
}

const result = spawnSync(
  ffmpeg,
  [
    '-y',
    '-i', webm,
    '-c:v', 'libx264',
    '-preset', 'medium',
    '-crf', '18',
    '-pix_fmt', 'yuv420p',
    '-r', String(FPS),
    '-movflags', '+faststart',
    '-an',
    outPath,
  ],
  { stdio: 'inherit' },
);

if (result.status !== 0) {
  console.error('[brag] ffmpeg failed to encode the video.');
  process.exit(1);
}

rmSync(tmpDir, { recursive: true, force: true });
const megabytes = (statSync(outPath).size / 1e6).toFixed(1);
console.log(`[brag] done -> ${outPath} (${megabytes} MB, ${(duration / 1000).toFixed(1)}s)`);
