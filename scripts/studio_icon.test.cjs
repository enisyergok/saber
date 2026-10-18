const { test } = require('node:test');
const assert = require('node:assert/strict');
const sharp = require('sharp');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
for (const [density, side] of Object.entries({ mdpi:108, hdpi:162, xhdpi:216, xxhdpi:324, xxxhdpi:432 })) {
  test(`${density}: adaptive mark survives a circular launcher mask`, async () => {
    for (const layer of ['foreground', 'monochrome']) {
      const file = path.join(root, `android/app/src/main/res/mipmap-${density}/ic_launcher_${layer}.png`);
      const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject:true });
      assert.equal(info.width, side);
      assert.equal(info.height, side);
      let visible = 0;
      for (let y=0; y<side; y++) for (let x=0; x<side; x++) {
        if (data[(y*side+x)*4+3] < 16) continue;
        visible++;
        assert.ok(Math.hypot(x + .5 - side/2, y + .5 - side/2) <= side*33/108,
          `${layer}: visible pixel (${x},${y}) is outside the safe circle`);
      }
      assert.ok(visible > side*side*.03, 'mark must not be empty or unreadably small');
    }
  });
}
