#!/usr/bin/env node
/* Export the Gentle-pixel engine's animation frames into the app.
 *
 *   node Art/tools/gentle_pixel/export_frames.js            # all 32 species
 *   node Art/tools/gentle_pixel/export_frames.js cocoa fox  # a few
 *
 * Writes, per species and action, one imageset per frame:
 *   Apps/Shared/Sprites.xcassets/gen_bat_<id>_<action>_<n>.imageset/{sprite.png, Contents.json}
 * as 128 × 128 PNGs (64 px logical canvas at 2×, nearest-neighbour — the same
 * contract as the hand-drawn pilots), plus a review sheet per species and a
 * manifest in Art/gentle-pixel/generated-frames/. No dependencies: the PNG
 * encoder below is 40 lines on top of Node's zlib.
 *
 * The frame plan (counts, seconds, rest) lives in engine.js PLAN and is
 * mirrored by GeneratedFramePlan in Packages/BatwalkCore/Sources/BatwalkCore/BatAnimation.swift.
 * Change both together. */
'use strict';
const fs = require('fs');
const path = require('path');
const E = require('./engine.js');

const repo = path.resolve(__dirname, '..', '..', '..');
const catalog = path.join(repo, 'Apps', 'Shared', 'Sprites.xcassets');
const review = path.join(repo, 'Art', 'gentle-pixel', 'generated-frames');
const SCALE = 2;
const PREFIX = 'gen_bat_';

// ---------------------------------------------------------------- png
const {png, rasterize, blit} = require('./pixel_io');

// ---------------------------------------------------------------- export
const wanted = process.argv.slice(2);
const species = E.SPECIES.filter(s => !wanted.length || wanted.includes(s.id));
if (!species.length) { console.error('no such species:', wanted.join(' ')); process.exit(1); }
fs.mkdirSync(catalog, { recursive: true });
fs.mkdirSync(review, { recursive: true });

const contents = JSON.stringify({ images: [{ filename: 'sprite.png', idiom: 'universal', scale: '2x' }], info: { author: 'xcode', version: 1 } }, null, 2) + '\n';
let written = 0;
const manifest = { version: 2, engine: 'Art/tools/gentle_pixel/engine.js', prefix: PREFIX, logicalSize: E.W, scale: SCALE, plan: E.PLAN, species: {} };
const bgSheet = [0x1C, 0x2E, 0x32];

for (const s of species) {
  const maxFrames = Math.max(...E.ACTIONS.map(a => E.POSES[a].length));
  const sheet = { w: maxFrames * E.W * SCALE, h: E.ACTIONS.length * E.H * SCALE, rgba: Buffer.alloc(maxFrames * E.W * SCALE * E.ACTIONS.length * E.H * SCALE * 4) };
  for (let i = 0; i < sheet.w * sheet.h; i++) { sheet.rgba[i * 4] = bgSheet[0]; sheet.rgba[i * 4 + 1] = bgSheet[1]; sheet.rgba[i * 4 + 2] = bgSheet[2]; sheet.rgba[i * 4 + 3] = 255; }
  manifest.species[s.id] = {};
  E.ACTIONS.forEach((action, row) => {
    const frames = E.frameGrids(s.id, action, false);
    manifest.species[s.id][action] = frames.map(f => `${PREFIX}${s.id}_${action}_${f.index}`);
    for (const f of frames) {
      const name = `${PREFIX}${s.id}_${action}_${f.index}`;
      const dir = path.join(catalog, `${name}.imageset`);
      fs.mkdirSync(dir, { recursive: true });
      const cell = rasterize(f.grid, SCALE, null);
      fs.writeFileSync(path.join(dir, 'sprite.png'), png(cell.w, cell.h, cell.rgba));
      fs.writeFileSync(path.join(dir, 'Contents.json'), contents);
      blit(sheet, rasterize(f.grid, SCALE, bgSheet), f.index * E.W * SCALE, row * E.H * SCALE);
      written++;
    }
  });
  fs.writeFileSync(path.join(review, `${s.id}.png`), png(sheet.w, sheet.h, sheet.rgba));
}

fs.writeFileSync(path.join(review, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`${written} frames for ${species.length} species → ${path.relative(repo, catalog)}; review sheets in ${path.relative(repo, review)}`);
