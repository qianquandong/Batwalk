'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict');
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'../../..');
const manifest=require('../../gentle-pixel/portrait-universals-v1/manifest.json');
const portraits=require('../../gentle-pixel/portraits-v3/manifest.json');
const pilot=require('../../gentle-pixel/pilots-v1/manifest.json');
const sha=file=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,file))).digest('hex');

test('all launch bats have five animated universal actions, 400 loadable RGBA frames',()=>{
  assert.equal(manifest.clips.length,100);
  const names=new Set();
  for(const bat of portraits.characters.filter(b=>b.number<=20)){
    const clips=manifest.clips.filter(c=>c.speciesID===bat.id);
    assert.deepEqual(clips.map(c=>c.actionID),['idle','sleep','fly','pet','eat']);
    for(const c of clips){
      assert.equal(c.unlockLevel,1);
      assert.equal(c.frames.length,4);assert.equal(c.seconds.length,4);
      assert.ok(new Set(c.sha256).size>=3,bat.id+'/'+c.actionID+' must animate');
      assert.ok(c.seconds.every(t=>t>=.18&&t<=2.4));
      assert.equal(c.restSeconds>0,['idle','sleep'].includes(c.actionID));
      c.frames.forEach((name,i)=>{
        assert.ok(name.startsWith(bat.id==='mochi'?'pilot_bat_':'universal_bat_'));
        const file='Apps/Shared/Sprites.xcassets/'+name+'.imageset/sprite.png';
        const png=fs.readFileSync(path.join(root,file));
        assert.equal(png.readUInt32BE(16),128,name);assert.equal(png.readUInt32BE(20),128,name);
        assert.equal(png[25],6,'RGBA required');assert.equal(sha(file),c.sha256[i],name);
        const info=JSON.parse(fs.readFileSync(path.join(root,path.dirname(file),'Contents.json')));
        assert.ok(info.images.some(i=>i.filename==='sprite.png'&&i.scale==='2x'));
        assert.ok(!names.has(name));names.add(name);
      });
    }
  }
  assert.equal(names.size,400);
});

test('original portraits and accepted Mochi pilot pixels stay unchanged',()=>{
  for(const c of manifest.clips){
    const original=portraits.characters.find(p=>p.id===c.speciesID);
    assert.equal(c.portraitSHA256,original.sha256);assert.equal(sha(c.portrait),original.sha256);
    assert.equal(sha(c.source),c.sourceSHA256);
    if(c.speciesID==='mochi'){
      const accepted=pilot.clips.find(p=>p.speciesID==='mochi'&&p.actionID===c.actionID);
      assert.deepEqual(c.frames,accepted.frames);
      // Pilot hashes describe decoded 64 px RGBA, checked by the Python packager.
    }else{
      assert.equal(c.framing.frames.length,4);
      assert.ok(c.framing.scale>0);
    }
  }
});

test('reviewed flight corrections and neutral dust pet frame are packaged',()=>{
  for(const id of ['cocoa','fruit','cave','vampire','galaxy']){
    assert.ok(manifest.clips.find(c=>c.speciesID===id&&c.actionID==='fly').source.endsWith(id+'-fly-fix-v1.png'));
  }
  const dust=manifest.clips.filter(c=>c.speciesID==='dust');
  assert.deepEqual(dust.find(c=>c.actionID==='pet').framing.frames[0].rect,dust.find(c=>c.actionID==='idle').framing.frames[0].rect);
});
