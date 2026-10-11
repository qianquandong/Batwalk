'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const U=require('./unique_actions'),E=require('./engine');
const root=path.resolve(__dirname,'../../..');
const manifest=require('../../gentle-pixel/launch-actions/manifest.json');

test('every designed launch action has real, distinct PNG frames at the bundle size',()=>{
  assert.equal(manifest.clips.length,64);assert.equal(new Set(manifest.clips.map(c=>c.speciesID)).size,20);
  const names=new Set();
  for(const c of manifest.clips){
    assert.equal(c.frames.length,c.seconds.length);
    assert.ok(new Set(c.sha256).size>=3,c.speciesID+'/'+c.actionID+' is effectively a still');
    c.frames.forEach((name,i)=>{
      const png=fs.readFileSync(path.join(root,'Apps/Shared/Sprites.xcassets',name+'.imageset/sprite.png'));
      assert.equal(png.readUInt32BE(16),128,name);assert.equal(png.readUInt32BE(20),128,name);
      assert.equal(png[25],6,'RGBA required');
      assert.equal(crypto.createHash('sha256').update(png).digest('hex'),c.sha256[i],name);
      assert.ok(!names.has(name));names.add(name);
    });
  }
  assert.equal(names.size,500);
});

test('choreography preserves source identities and stays within the sprite canvas',()=>{
  const before=E.SPECIES.map(s=>JSON.stringify(s));
  for(const key of Object.keys(U.draw)){
    for(const {grid,index} of U.frames(key)){
      assert.equal(grid.p.length,64*64);
      assert.ok(grid.count()>15,key+'/'+index+' empty');
      assert.ok(grid.count()<64*64*.8,key+'/'+index+' opaque backdrop');
      // Nothing is drawn at the crop edge. A one-pixel gutter is mandatory.
      for(let n=0;n<64;n++)assert.ok(!grid.get(n,0)&&!grid.get(n,63)&&!grid.get(0,n)&&!grid.get(63,n),key+'/'+index+' crop edge');
      assert.ok(grid.p.every(c=>c===null||/^#[0-9a-f]{6}$/i.test(c)),key+' invalid palette');
    }
  }
  assert.deepEqual(E.SPECIES.map(s=>JSON.stringify(s)),before,'Animating must not mutate other clips');
});

test('small gestures have genuine changes in body parts or props, not duplicate frames',()=>{
  for(const key of Object.keys(U.draw)){
    const frames=U.frames(key);const hashes=frames.map(f=>crypto.createHash('sha256').update(JSON.stringify(f.grid.p)).digest('hex'));
    assert.ok(new Set(hashes).size>=3,key);
    assert.ok(frames.every(f=>f.seconds>=.1));
    assert.ok(frames.reduce((s,f)=>s+f.seconds,0)<=3,key);
  }
});
