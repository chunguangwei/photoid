// SVG → PNG 光栅化（图标构建期工具）。用法：
//   npm i sharp && node logo/render.mjs .
// 产物交给 `dart run flutter_launcher_icons` 生成各平台图标。

import sharp from 'sharp';
import { readFileSync } from 'fs';

const ROOT = process.argv[2];
const jobs = [
  ['logo.svg',            'logo/icon.png',            true ],  // 不透明（iOS 要求无 alpha）
  ['logo_foreground.svg', 'logo/icon_foreground.png', false],  // 透明底
  ['logo_background.svg', 'logo/icon_background.png', true ],
  ['logo.svg',            'logo/logo-preview.png',      true ],
];

for (const [src, out, flatten] of jobs) {
  let img = sharp(readFileSync(`${ROOT}/logo/${src}`), { density: 384 })
              .resize(1024, 1024, { fit: 'fill' });
  if (flatten) img = img.flatten({ background: '#7B93C5' });
  const info = await img.png({ compressionLevel: 9 }).toFile(`${ROOT}/${out}`);
  console.log(out.padEnd(34), `${info.width}x${info.height}`,
              (info.size / 1024).toFixed(0) + 'KB', flatten ? '(opaque)' : '(alpha)');
}
