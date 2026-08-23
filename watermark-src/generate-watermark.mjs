// Generates static/img/watermark.png: a small square badge (the tiger
// source image with the watermark text baked in) rendered at 12% opacity
// (alpha channel), pinned to the bottom-left corner by src/theme/Root.tsx.
import sharp from "sharp";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const WATERMARK_LINES = ['בודל ע"י', "יהלי כהן"];
const SIZE = 400; // square canvas; displayed small via CSS background-size
const OPACITY = 0.12;

const lineHeight = 46;
const firstLineY = SIZE / 2 - lineHeight / 2;
const tspans = WATERMARK_LINES.map(
  (line, i) => `<tspan x="50%" y="${firstLineY + i * lineHeight}">${line}</tspan>`,
).join("");

const svgText = `
<svg width="${SIZE}" height="${SIZE}" xmlns="http://www.w3.org/2000/svg">
  <text
    text-anchor="middle"
    direction="rtl"
    font-family="Arial, 'Noto Sans Hebrew', sans-serif"
    font-size="36"
    font-weight="bold"
    fill="#ffffff"
    stroke="#000000"
    stroke-width="1.5"
  >${tspans}</text>
</svg>
`;

async function main() {
  const tigerPath = path.join(__dirname, "tiger.jpg");
  const outPath = path.join(__dirname, "..", "static", "img", "watermark.png");

  const tile = await sharp(tigerPath)
    .resize(SIZE, SIZE, { fit: "cover" })
    .composite([{ input: Buffer.from(svgText), top: 0, left: 0 }])
    .ensureAlpha()
    .png()
    .toBuffer();

  // Scale the alpha channel down to OPACITY (R,G,B untouched, A * 0.12).
  await sharp(tile)
    .linear([1, 1, 1, OPACITY], [0, 0, 0, 0])
    .png()
    .toFile(outPath);

  console.log(`watermark written to ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
