// Packages the imagegen-created mark; no artwork is drawn or replaced here.
// Run from the repository root with `node scripts/package_studio_icon.cjs`.
// Requires sharp (0.34.x); generated Android PNGs are committed.
const sharp = require('sharp');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const asset = name => path.join(root, 'assets/icon', name);
const res = path.join(root, 'android/app/src/main/res');
const transparent = { r:0, g:0, b:0, alpha:0 };

async function main() {
  const trimmed = await sharp(asset('marj-studio-source.png')).trim().png().toBuffer();
  const foreground = await sharp(trimmed).resize(500, 420, { fit:'inside' }).png().toBuffer();
  const layer = await sharp({ create:{ width:1080, height:1080, channels:4, background:transparent } })
    .composite([{ input:foreground, gravity:'centre' }]).png().toBuffer();
  const { data, info } = await sharp(layer).raw().toBuffer({ resolveWithObject:true });
  for (let i=0; i<data.length; i+=4) data[i]=data[i+1]=data[i+2]=255;
  const mono = await sharp(data, { raw:info }).png().toBuffer();
  // Background matches ic_launcher_background.xml exactly.
  const background = Buffer.from('<svg width="1080" height="1080" xmlns="http://www.w3.org/2000/svg"><defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#19263D"/><stop offset="1" stop-color="#0B1220"/></linearGradient></defs><rect width="1080" height="1080" fill="url(#bg)"/></svg>');
  const complete = await sharp(background).composite([{ input:layer }]).png().toBuffer();
  const cropped = await sharp(complete).extract({ left:180, top:180, width:720, height:720 }).png().toBuffer();
  const mask = Buffer.from('<svg width="720" height="720" xmlns="http://www.w3.org/2000/svg"><rect width="720" height="720" rx="162" fill="white"/></svg>');
  const legacy = await sharp(cropped).composite([{ input:mask, blend:'dest-in' }]).png().toBuffer();
  for (const [name, scale] of Object.entries({ mdpi:1, hdpi:1.5, xhdpi:2, xxhdpi:3, xxxhdpi:4 })) {
    const folder=path.join(res, `mipmap-${name}`);
    await sharp(layer).resize(108*scale).toFile(path.join(folder, 'ic_launcher_foreground.png'));
    await sharp(mono).resize(108*scale).toFile(path.join(folder, 'ic_launcher_monochrome.png'));
    await sharp(legacy).resize(48*scale).toFile(path.join(folder, 'ic_launcher.png'));
  }
  await sharp(legacy).resize(1024).toFile(asset('marj-studio.png'));
  await sharp(trimmed).resize(256,256,{ fit:'contain', background:transparent }).toFile(asset('marj-studio-mark.png'));
  await sharp(cropped).resize(512).toFile(path.join(root, 'android/app/src/main/ic_launcher-playstore.png'));
  console.log('Packaged 15 launcher layers, store icon, app icon and in-app mark.');
}
main().catch(error => { console.error(error); process.exitCode=1; });
