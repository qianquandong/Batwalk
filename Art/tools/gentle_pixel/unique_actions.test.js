'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'../../..');
const manifest=require('../../gentle-pixel/launch-actions/manifest.json');
const portraits=require('../../gentle-pixel/portraits-v3/manifest.json');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');

test('64 designed launch actions have 256 distinct packaged RGBA frames',()=>{
  assert.equal(manifest.clips.length,64);
  assert.equal(new Set(manifest.clips.map(c=>c.speciesID)).size,20);
  const names=new Set();
  for(const c of manifest.clips){
    assert.equal(c.frames.length,4);assert.equal(c.seconds.length,4);
    assert.ok(new Set(c.sha256).size>=3,c.speciesID+'/'+c.actionID+' is effectively a still');
    assert.ok(c.seconds.every(t=>t>=.1&&t<=1.2));
    assert.ok(c.seconds.reduce((a,b)=>a+b,0)<=3);
    c.frames.forEach((name,i)=>{
      const file='Apps/Shared/Sprites.xcassets/'+name+'.imageset/sprite.png';
      const png=fs.readFileSync(path.join(root,file));
      assert.equal(png.readUInt32BE(16),128,name);assert.equal(png.readUInt32BE(20),128,name);
      assert.equal(png[25],6,'RGBA required');
      assert.equal(sha(file),c.sha256[i],name);
      assert.ok(!names.has(name));names.add(name);
    });
  }
  assert.equal(names.size,256);
});

test('every clip traces back to unchanged approved portrait and stored source sheet',()=>{
  for(const c of manifest.clips){
    const original=portraits.characters.find(p=>p.id===c.speciesID);
    assert.equal(c.portraitSHA256,original.sha256,c.speciesID);
    assert.equal(sha(c.portrait),original.sha256,c.speciesID);
    assert.ok(c.source&&c.sourceSHA256,c.actionID+' lacks source provenance');
    assert.equal(sha(c.source),c.sourceSHA256,c.actionID);
    if(c.speciesID!=='mochi'){
      assert.equal(c.framing.frames.length,4);
      assert.ok(c.framing.scale>0);
      assert.ok(c.framing.frames.every(f=>f.rect.length===4&&f.anchor.length===2));
    }
  }
});

test('the three approved sample sheets remain the exact accepted images',()=>{
  const samples=require('../../gentle-pixel/portrait-action-samples-v1/manifest.json');
  for(const sample of samples.characters){
    const clip=manifest.clips.find(c=>c.speciesID===sample.id&&c.actionID===sample.action);
    assert.equal(clip.sourceSHA256,sample.sheetSHA256);
    assert.deepEqual(clip.seconds,sample.frameDurationsMs.map(t=>t/1000));
    assert.deepEqual(clip.framing.frames.map(f=>f.anchor),sample.frames.map(f=>f.anchor));
  }
});
