/* Launch personalities. Hand-authored gestures, props and staging on the SAME
 * editable pixel characters as engine.js. No per-species recoloured template.
 * Each function is a tiny beginning/action/recovery scene from BAT_ACTIONS.md.
 * Mochi's two raster additions and existing cartwheel are packaged separately.
 * 64 px canvas, eight held keyframes; no runtime canvas or animation timer. */
'use strict';
const E = require('./engine');
const C = { ink:'#35403B', cream:'#F4E7C8', gold:'#E7C45B', pink:'#EEA5AF', leaf:'#91AE78',
  stem:'#637951', bark:'#886C51', stone:'#999993', blue:'#ACD6DF', cloud:'#DDE7E5' };
const pick = (f, values) => values[Math.min(f, values.length - 1)];
const flash = (f) => f >= 2 && f <= 6;
function star(g,x,y,c=C.gold) { g.line(x-1,y,x+1,y,c); g.line(x,y-1,x,y+1,c); }
function ring(g,x,y,r,c=C.blue) {
  for(let a=0;a<24;a++) { const t=a*Math.PI/12; g.set(x+Math.cos(t)*r,y+Math.sin(t)*r,c); }
}
function leaf(g,x,y,rx=6) { g.ell(x,y,rx,3,C.leaf); g.line(x-rx+1,y+1,x+rx-1,y-1,C.stem); }
function flower(g,x,y) {
  g.line(x,y+2,x,y+13,C.stem); leaf(g,x+3,y+9,3);
  for(let a=0;a<5;a++)g.ell(x+Math.cos(a*1.256)*3,y+Math.sin(a*1.256)*3,2,2,C.pink);
  g.ell(x,y,1.5,1.5,C.gold);
}
function fruit(g,x,y,r=4) {g.ell(x,y,r,r,C.pink);g.set(x-1,y-1,C.cream);g.line(x,y-r,x+1,y-r-2,C.stem);}
function branch(g,y=12) {g.line(9,y,54,y,C.bark);g.line(12,y+1,52,y+1,'#5E4B38');leaf(g,50,y-2,4);}
function rock(g,x,y,rx=10,ry=5) {g.ell(x,y,rx,ry,C.ink);g.ell(x,y-1,rx-1,ry-1,C.stone);g.line(x-rx+4,y-2,x-2,y-3,C.cloud);}
function pup(g,x,y,c=C.pink,awake=false) {
  g.tri(x-4,y-1,x-2,y-7,x,y-2,c);g.tri(x,y-2,x+2,y-7,x+4,y-1,c);g.ell(x,y,4,4,c);
  g.rect(x-2,y,1,awake?2:1,C.ink);g.rect(x+1,y,1,awake?2:1,C.ink);
}
function silhouette(g,x,y,c=C.ink) {g.ell(x,y,1.5,2,c);g.line(x-4,y-2,x,y,c);g.line(x,y,x+4,y-2,c);}
function wind(g,x,y,n=0) {g.line(x,y,x+10,y,C.blue);g.line(x+3,y+3+n,x+14,y+3+n,C.blue);g.set(x+15,y+2+n,C.blue);}
function moon(g,x,y,r=6) {g.ell(x,y,r,r,C.cream);g.ell(x+3,y-2,r-1,r-1,null);}
function bubble(g,x,y,r) {ring(g,x,y,r,C.blue);g.set(x-r+1,y-1,C.cream);}
function note(g,x,y,c=C.gold) {g.line(x+2,y-4,x+2,y,c);g.rect(x+2,y-4,3,1,c);g.ell(x,y+1,2,1,c);}
function moth(g,x,y) {g.ell(x-2,y,2,2,C.cream);g.ell(x+2,y,2,2,C.cream);g.line(x,y-2,x,y+2,C.bark);}
function nest(g,x,y,rx=16) {
  g.ell(x,y,rx,9,C.bark);g.ell(x,y-3,rx-3,5,'#493C31');
  for(let a=0;a<7;a++)g.line(x-rx+2+a*4,y+2,x-rx+7+a*3,y+6,C.cream);
}
function hand(g,x,y,P) {g.ell(x,y,2.5,2.5,P.line);g.ell(x,y-1,1.5,1.5,P.base);}
function mask(g,P,cx,cy,peek=false) {
  g.tri(cx-12,cy+8,cx+10,cy-5,cx+13,cy+9,P.wing||P.shade);
  g.line(cx-11,cy+7,cx+9,cy-4,P.line);
  if(peek){g.rect(cx+4,cy-2,3,2,P.light);g.set(cx+5,cy-2,P.line);}
}
function blanket(g,P,cx,cy,amount) {
  g.ell(cx,cy+9,13,6,P.shade);g.tri(cx-13,cy+9,cx+13,cy+9,cx,cy+9-amount,P.shade);
  g.line(cx-12,cy+8,cx,cy+9-amount,P.line);g.line(cx,cy+9-amount,cx+12,cy+8,P.light);
}
function copy(g,src,dx=0,dy=0,angle=0) {
  // Inverse nearest sampling preserves filled pixel clusters on a turning bat.
  const a=angle*Math.PI/180,co=Math.cos(a),si=Math.sin(a);
  for(let y=1;y<63;y++)for(let x=1;x<63;x++){
    const xx=x-32-dx, yy=y-35-dy;
    const color=src.get(Math.round(xx*co+yy*si+32),Math.round(-xx*si+yy*co+35));
    if(color)g.set(x,y,color);
  }
}
function scene(id,f,p={},back=()=>{},front=()=>{},options={}) {
  p={...p,wingFold:Math.max(0,Math.abs((p.dx||0)+(options.x||0))-1)};
  const original=E.species(id),spec={...original,body:{...original.body},ears:{...original.ears},face:{...original.face},pal:{...original.pal}};
  if(options.ears)Object.assign(spec.ears,options.ears);
  if(options.face)Object.assign(spec.face,options.face);
  if(options.palette)Object.assign(spec.pal,options.palette);
  if(options.noMotif)spec.motif=null;
  if(options.noBack)spec.back=null;
  const g=new E.Grid();back(g);
  if(!options.hidden)copy(g,E.drawBat(spec,p,false),options.x||0,options.y||0,options.angle||0);
  front(g,spec.pal,32+(p.dx||0)+(options.x||0),37+(p.dy||0)-(p.lift||0)+(options.y||0));
  return g;
}
const draw = {};
function add(id, fn, seconds) {draw[id]={fn,seconds:seconds||[.26,.18,.2,.24,.2,.2,.24,.48]};}

// #02 Cocoa — sleepy caregiver, a scrunched nose rather than a generic bounce.
add('cocoa/sunrise-doze',f=>scene('cocoa',f,{eyes:f<6?'closed':'half',mouth:f===6?'open':'small',wings:f===6?'up':undefined,dy:pick(f,[0,1,2,2,2,1,0,0])},
  g=>{g.ell(52,14,5,5,C.gold);},(g,P,x,y)=>{if(f>0&&f<6)bubble(g,x+5,y+2,pick(f,[0,2,3,4,4,2]));}));
add('cocoa/wattle-wiggle',f=>scene('cocoa',f,{eyes:f>1&&f<6?'happy':'half',mouth:'small'},()=>{},(g,P,x,y)=>{
  g.ell(x,y+2,3,2,P.shade);g.set(x-1,y+1,P.line);g.set(x+1,y+1,P.line);
  const d=pick(f,[0,-1,1,-2,2,-1,1,0]);g.ell(x-2+d,y+5,1.5,2,P.ear);g.ell(x+2-d,y+5,1.5,2,P.ear);
}));
add('cocoa/creche-babysitter',f=>scene('cocoa',f,{eyes:f<3?'open':'happy',wings:f<3?'mid':undefined,dx:pick(f,[0,0,0,-1,1,-1,1,0])},()=>{},(g,P,x,y)=>{
  for(let i=0;i<3;i++)pup(g,x-7+i*7,y+10-(f===1?i:0),C.pink,f<3);
  if(f>=3){g.tri(x-15,y+5,x+14,y+15,x-11,y+17,P.wing);g.line(x-11,y+8,x+11,y+15,P.light);}
  if(f>=5)g.rect(49,20-(f-5)*2,3,1,C.cream);
}));

// #03 Long Ear — ears actually fold, track sound, and lead a quiet leaf hover.
add('long-ear/ram-horn-ears',f=>scene('long-ear',f,{eyes:'closed'},()=>{},(g,P,x,y)=>{
  if(f>0){for(const s of [-1,1]){g.ell(x+s*8,y-11,4,4,P.base);ring(g,x+s*8,y-11,2,P.ear);}
    if(f>=4)blanket(g,P,x,y,18);}
}, {ears:f===0||f===7?{type:'long'}:{type:'small'}}));
add('long-ear/ladybird-listen',f=>scene('long-ear',f,{eyes:'open',earTwitch:pick(f,[0,-2,-1,0,1,2,1,0]),look:pick(f,[-1,-1,-1,0,0,1,1,0])},g=>leaf(g,32,54,17),(g)=>{
  const x=pick(f,[18,21,25,29,33,37,41,44]);g.ell(x,52,2,2,'#D85E56');g.set(x,51,C.ink);g.set(x+1,52,C.ink);
}));
add('long-ear/butterfly-hover',f=>scene('long-ear',f,{wings:pick(f,[0,-12,8,-12,8,-10,6,0]),lift:pick(f,[0,2,4,4,4,3,2,0]),dx:pick(f,[0,2,4,6,6,4,2,0]),eyes:f===5?'happy':'open'},g=>leaf(g,49,48,9),(g,P,x,y)=>{
  if(f<5)fruit(g,48,44,2);if(f>=3&&f<6)hand(g,x+9,y+5,P);
}));

// #04 Fruit — protective, a little quarrelsome, then generous with its perch.
add('fruit/fruit-hug',f=>scene('fruit',f,{look:pick(f,[0,-2,-2,0,2,2,0,0]),eyes:f===1||f===4?'half':'open'},()=>{},(g,P,x,y)=>{
  fruit(g,x,y+8,6);hand(g,x-5,y+8,P);hand(g,x+5,y+8,P);
}));
add('fruit/spat-pop',f=>scene('fruit',f,{mouth:f<3?'chew':f<6?'open':'smile',chewSide:f%2?1:-1,eyes:f<4?'closed':'happy'},()=>{},(g,P,x,y)=>{
  if(f<3){fruit(g,x+6,y+5,4-f);hand(g,x+8,y+8,P);}
  if(f>=3&&f<7){g.ell(x+4+(f-3)*5,y+3+(f-3)*(f-3),2,1,C.bark);g.set(x+3,y+4,C.blue);}
}));
add('fruit/squabble-squeaks',f=>scene('fruit',f,{dx:pick(f,[0,-1,0,-1,1,4,7,7]),mouth:f>0&&f<5?'open':'smile',eyes:f<4?'half':'happy'},g=>branch(g,52),(g)=>{
  if(f<5)note(g,15,24-f,C.pink);if(f===2||f===4)note(g,53,28,C.cream);
  if(f>=5){g.rect(12,49,9,1,C.gold);star(g,16,44);}
}));

// #05 Cave — shy wrapped silhouette; a very particular answered nursery call.
add('cave/plum-wrap',f=>{
  const bat=scene('cave',f,{eyes:'closed'},()=>{},(g,P,x,y)=>blanket(g,P,x,y,pick(f,[10,17,24,29,29,29,24,10])));
  const g=new E.Grid();branch(g,12);g.line(32,13,32,17,C.bark);
  copy(g,bat,0,-5,180+pick(f,[0,-3,-5,0,5,3,0,0]));return g;
});
add('cave/peek-twist',f=>scene('cave',f,{eyes:f<2?'closed':'dot',look:pick(f,[0,0,-2,-2,1,2,1,0]),dx:pick(f,[0,0,-2,-1,1,2,1,0])},()=>{},(g,P,x,y)=>mask(g,P,x,y,f>=2),{angle:pick(f,[0,0,-7,-10,0,7,3,0])}));
add('cave/find-you-call',f=>scene('cave',f,{dy:-7,mouth:f===1||f===3?'open':'smile',eyes:f>=5?'happy':'open'},()=>{},(g)=>{
  [17,27,37,47].forEach((x,i)=>pup(g,x,54,i===2?'#B9B2CC':'#676278',f>=4&&i===2));
  if(f===1||f===3)note(g,46,29);if(f>=4)note(g,39,43-(f-4)*2,C.blue);
}));

// #06 Sleepy — extended stillness, dew lick and a botanical sleeping bag.
add('sleepy/one-big-breath',f=>scene('sleepy',f,{eyes:'closed',mouth:f===4?'open':'small',sy:pick(f,[0,0,0,1,2,1,0,0])},()=>{},(g,P,x,y)=>{
  if(f===5||f===6){g.ell(x+14+(f-5)*3,y+2,3,2,C.cloud);}
}),[.65,.35,.25,.24,.3,.25,.2,.45]);
add('sleepy/groggy-wake',f=>scene('sleepy',f,{eyes:pick(f,['closed','half','open','half','half','closed','closed','closed']),mouth:f<4?'small':'open'},()=>{},(g,P,x,y)=>{
  if(f<4){g.ell(x+7,y+4,2,2,C.blue);g.set(x+7,y+3,C.cream);}
  if(f===2||f===3)g.line(x,y+3,x+6,y+4,C.pink);
  if(f===5)note(g,46,28,C.cloud);
}));
add('sleepy/pitcher-plant-bed',f=>scene('sleepy',f,{dy:pick(f,[-7,-5,-2,1,4,4,4,4]),eyes:f<3?'half':'closed'},g=>{
  g.line(46,17,47,47,C.stem);leaf(g,39,15,10);
},g=>{
  g.ell(32,48,16,12,C.stem);g.ell(32,47,13,11,C.leaf);g.ell(32,40,14,4,C.stem);
  if(f<3)g.ell(32,39,12,2,'#485A3D');
  if(f>=4){g.rect(24,39,17,2,C.leaf);star(g,49,24,C.cream);}
}));

// #07 Dust — practise, forget to flap, recover. Asymmetric timing sells clumsiness.
add('dust/flap-practice',f=>scene('dust',f,{wings:pick(f,[0,-14,10,-14,10,-14,0,0]),eyes:f>=6?'happy':'open',mouth:f>=5?'open':'small'},g=>branch(g,9),g=>{if(f===6)g.ell(51,39,3,2,C.cloud);},{angle:180,y:-5}));
add('dust/drop-start',f=>scene('dust',f,{wings:pick(f,[undefined,undefined,undefined,10,-12,10,-10,undefined]),dy:pick(f,[-9,-7,1,9,5,-2,-6,-8]),mouth:f===3?'open':'smile'},g=>branch(g,8),()=>{}, {angle:f<2?180:0}));
add('dust/almost-landing',f=>scene('dust',f,{wings:f<4?pick(f,[0,-10,10,undefined]):undefined,eyes:f===3?'open':'happy'},g=>branch(g,9),g=>{
  if(f>=5&&f<7){for(const x of [13,20,46,52])g.ell(x,38+(x%3)*3,2,2,C.cloud);}
},{angle:pick(f,[0,-45,-100,-30,100,180,180,180]),y:pick(f,[2,-2,-4,5,2,-4,-4,-4])}));

// #08 Pebble — the rock is part of the gesture, never a scaled character variant.
add('pebble/crack-squeeze',f=>scene('pebble',f,{dy:pick(f,[0,1,3,5,6,6,6,0]),eyes:'half'},g=>rock(g,33,50,22,7),(g)=>{
  rock(g,32,24,24,9);if(f>=3&&f<7){rock(g,32,42,23,9);g.rect(25,34,14,4,C.ink);g.set(28,35,C.cream);g.set(35,35,C.cream);}
}));
add('pebble/bandit-peek',f=>scene('pebble',f,{dy:pick(f,[9,7,3,0,-2,0,3,8]),eyes:'open'},g=>rock(g,18,48,13,9),(g,P,x,y)=>{
  g.rect(x-8,y-4,16,5,C.ink);g.set(x-5,y-2,C.cream);g.set(x+4,y-2,C.cream);
  rock(g,45,50,13,8);rock(g,30,55,17,7);
}));
add('pebble/new-rock-every-day',f=>scene('pebble',f,{dx:pick(f,[-9,-9,-5,0,5,9,9,9]),dy:pick(f,[0,-1,-5,-7,-4,-1,1,1]),eyes:f<5?'open':'closed'},g=>{rock(g,19,54,11,6);rock(g,46,52,12,8);},g=>{if(f>=5)leaf(g,49,53,7);}));

// #09 Strawberry — single-foot sway, furry wrap, then a three-pup berry bunch.
add('strawberry/one-foot-sway',f=>scene('strawberry',f,{eyes:'closed'},g=>{branch(g,9);g.line(32,10,32,17,C.bark);},()=>{}, {angle:pick(f,[180,174,167,174,180,187,193,180]),y:-3}));
add('strawberry/tail-blanket',f=>scene('strawberry',f,{eyes:f>2?'happy':'open'},()=>{},(g,P,x,y)=>{
  blanket(g,P,x,y,pick(f,[0,5,10,17,20,20,18,12]));g.rect(x-4,y+11,2,2,P.light);g.rect(x+2,y+8,2,2,P.light);
}));
add('strawberry/berry-bunch',f=>scene('strawberry',f,{dx:-7,dy:-2,eyes:'happy'},g=>branch(g,11),(g)=>{
  for(let i=0;i<Math.min(3,f);i++){const x=39+i*8,y=28+i*8+(f%2);g.line(x,12,x,y-5,C.bark);pup(g,x,y,'#EC8A86',true);leaf(g,x,y-5,3);}
},{angle:180}));

// #10 Blossom — brush-tongue, dusty sneeze and an assertive flower guardian.
add('blossom/brush-tongue-sip',f=>scene('blossom',f,{dx:-6,wings:pick(f,[0,-12,8,-10,8,-10,0,0]),lift:3,eyes:f>=3?'happy':'open'},g=>flower(g,51,34),(g,P,x,y)=>{
  if(f>=2&&f<7){g.line(x,y+3,x+pick(f,[0,0,8,16,21,21,12]),y+3,C.pink);for(let d=-1;d<=1;d++)g.set(50,34+d,C.gold);}
}));
add('blossom/pollen-sneeze',f=>scene('blossom',f,{eyes:f<4?'closed':'open',mouth:f===3?'open':'small',dy:pick(f,[0,0,-1,1,0,0,0,0])},()=>{},(g)=>{
  if(f<3){[[22,30],[42,36],[26,44]].forEach(([x,y])=>g.set(x,y,C.gold));}
  else if(f<7)for(let a=0;a<9;a++){const t=a*Math.PI*2/9,r=8+(f-3)*4;g.set(32+Math.cos(t)*r,34+Math.sin(t)*r,C.gold);}
}));
add('blossom/flower-patrol',f=>scene('blossom',f,{dx:pick(f,[0,-6,-3,4,8,3,0,0]),wings:f>0&&f<5?'up':undefined,eyes:f>5?'happy':'open'},g=>{flower(g,12,44);flower(g,49,44);},g=>{
  if(f<5)silhouette(g,45+f*3,17-f,C.bark);if(f>=5)star(g,47,22,C.gold);
}));

// #11 Moss — disappearing in hanging moss is distinct from the seed-drop return.
function moss(g,front,f) {for(let i=0;i<9;i++){const x=13+i*5;g.line(x,12,x+(f%2),front?43-(i%3)*4:23+(i%3)*7,i%2?C.leaf:C.stem);}}
add('moss/moss-hideout',f=>scene('moss',f,{dy:pick(f,[2,0,-3,-5,-6,-6,-6,2]),eyes:'closed'},g=>{branch(g,10);moss(g,false,f);},g=>{if(f>=2&&f<7)moss(g,true,f);}));
add('moss/let-go-drop',f=>scene('moss',f,{dy:pick(f,[-9,-5,3,10,6,-1,-6,-8]),dx:pick(f,[0,0,0,1,5,6,3,0]),wings:f>=3&&f<7?pick(f,[0,0,0,10,-12,5,-10]):undefined},g=>{branch(g,8);moss(g,false,0);},()=>{}, {angle:f<2?180:0}));
add('moss/sprout-planting',f=>scene('moss',f,{dx:pick(f,[-7,-5,-2,2,6,9,9,5]),dy:-7,wings:pick(f,[0,-12,8,-12,8,0,0,0])},g=>g.line(8,58,56,58,C.stem),(g)=>{
  if(f<5)g.ell(25+Math.min(f,2)*2,39+f*4,1,2,C.bark);
  if(f>=5){g.line(29,57,29,57-(f-4)*3,C.stem);leaf(g,26,55-(f-4)*3,3);leaf(g,33,54-(f-4)*3,3);}
}));

// #12 Sunset — compass calibration, a crowd weave and a spiralling emergence.
function compass(g,x,y,f){ring(g,x,y,5,C.gold);const a=pick(f,[0,2,4,5,5.5,6.28,6.28,6.28]);g.line(x,y,x+Math.sin(a)*4,y-Math.cos(a)*4,C.pink);g.set(x,y,C.cream);}
add('sunset/sunset-compass',f=>scene('sunset',f,{look:1,eyes:f<6?'open':'happy'},g=>{g.ell(52,20,7,7,C.gold);g.line(43,24,60,24,C.pink);},g=>compass(g,13,47,f)));
add('sunset/crowd-dodge',f=>scene('sunset',f,{dx:pick(f,[0,-7,-3,6,8,0,-4,0]),dy:pick(f,[0,-3,-6,-2,2,0,-2,0]),wings:pick(f,[0,-10,7,-10,7,0,7,0])},g=>{
  for(let i=0;i<5;i++)silhouette(g,9+i*11,18+(i%2)*6,C.bark);
},g=>{if(f>1&&f<6){silhouette(g,12+f*5,46,C.ink);silhouette(g,54-f*4,50,C.ink);}}));
add('sunset/batnado',f=>scene('sunset',f,{dy:-f,dx:f<5?0:(f-5)*4,wings:f%2?'up':'down'},g=>{
  for(let i=0;i<9;i++){const a=i*1.1+f*.7,y=53-i*4,x=32+Math.sin(a)*(16-i);silhouette(g,x,y,i%2?C.bark:C.gold);}
},g=>{if(f>4)for(let i=0;i<f-3;i++)silhouette(g,41+i*5,12+i*2,C.cream);}));

// #13 Snow — condensation, tail zip, scarf and a there-and-back ocean crossing.
add('snow/frost-beads',f=>scene('snow',f,{eyes:'closed'},()=>{},(g)=>{
  [[24,27],[38,26],[22,40],[43,39],[29,46],[37,44]].slice(0,Math.min(6,f+1)).forEach(([x,y],i)=>{g.ell(x,y,1,1,C.blue);if((f+i)%3===0)star(g,x,y,'#FFFFFF');});
}));
add('snow/sleeping-bag',f=>scene('snow',f,{dx:pick(f,[-1,1,-1,1,0,0,0,0]),eyes:f>=4?'closed':'open'},()=>{},(g,P,x,y)=>{
  blanket(g,P,x,y,pick(f,[0,0,3,7,12,18,20,20]));if(f>=4)g.line(x,y+12,x,y+12-(f-3)*3,P.light);
}));
add('snow/great-migration',f=>scene('snow',f,{dx:pick(f,[0,-2,4,10,12,7,1,0]),lift:pick(f,[0,2,4,7,8,5,2,0]),wings:f>1&&f<7?(f%2?'up':'down'):undefined},g=>{
  g.line(7,55,56,55,C.blue);for(let x=8;x<56;x+=9)g.line(x,58,x+4,58,C.blue);
},(g,P,x,y)=>{g.rect(x-8,y+4,15,3,C.pink);g.line(x+6,y+6,x+14,y+10-(f%2)*3,C.pink);}));

// #14 Cloud — radar geometry, a gust to ride, and a moth caught above the clouds.
add('cloud/radar-bloom',f=>scene('cloud',f,{eyes:'half'},g=>{const r=14+f;for(let a=0;a<16;a++){const t=a*Math.PI/8;g.set(32+Math.cos(t)*r,34+Math.sin(t)*r,C.blue);}},g=>{if(f>3)star(g,48,14,C.cloud);}));
add('cloud/gust-surf',f=>scene('cloud',f,{wings:'mid',earTwitch:f%2?1:-1,dx:pick(f,[-6,-3,1,6,9,7,3,0]),lift:pick(f,[0,1,3,5,6,4,2,0]),eyes:'happy'},g=>{wind(g,7,48,1);wind(g,37,54,-1);},()=>{}, {angle:pick(f,[0,-4,-8,-12,-8,-4,0,0])}));
add('cloud/sky-high-snack',f=>scene('cloud',f,{lift:pick(f,[0,3,9,15,15,9,3,0]),wings:f%2?'up':'down',mouth:f===3?'open':'smile'},g=>{g.ell(12,48,8,3,C.cloud);g.ell(53,46,8,3,C.cloud);if(f<4)moth(g,34,24);},g=>{
  if(f>1&&f<7){g.line(18,46,18,54,C.blue);g.line(46,45,46,52,C.blue);}
}));

// #15 Moonwing — shy gaze, shared hush, a carefully chewed den.
add('moonwing/moon-shy',f=>scene('moonwing',f,{eyes:'open',look:1},g=>moon(g,52,15),(g,P,x,y)=>{if(f>0&&f<7)mask(g,P,x,y,f>=4);}));
add('moonwing/katydid-hush',f=>scene('moonwing',f,{mouth:'small',eyes:'half'},g=>leaf(g,51,51,9),(g,P,x,y)=>{
  if(f>0) {g.line(x+12,y+10,x+2,y+2,P.wing);hand(g,x+2,y+2,P);}
  g.ell(51,47,3,1,C.stem);g.line(50,48,48,51,C.stem);g.line(52,48,55,51,C.stem);if(f<3)note(g,55,38,C.leaf);
}));
add('moonwing/termite-mound-den',f=>scene('moonwing',f,{eyes:f>4?'closed':'open',mouth:f<5?'chew':'small',dy:f>4?2:0},g=>{
  g.ell(32,41,24,21,C.bark);g.ell(32,37,Math.min(16,6+f*2),Math.min(16,6+f*2),'#423E36');
},g=>{if(f<5){for(let i=0;i<3;i++)g.set(14+f*2+i*5,47+i*3,C.cream);}else{g.ell(32,55,18,7,C.bark);}}));

// #16 Golden — a nest camouflage, delicate web pluck, twelve party guests.
add('golden/nest-blend',f=>scene('golden',f,{eyes:f>=3?'closed':'open',dy:pick(f,[-3,-1,2,4,5,5,4,-3])},g=>{g.line(32,4,32,16,C.bark);nest(g,32,45,23);},g=>{
  if(f>=2&&f<7){nest(g,32,f>=4?40:49,23);g.line(15,26,25,48,C.bark);g.line(48,26,39,49,C.bark);}
  if(f>=4&&f<7){g.line(25,33,28,35,C.gold);g.line(37,33,39,35,C.gold);}
},{hidden:f>=4&&f<7}));
add('golden/web-pluck',f=>scene('golden',f,{dx:-7,wings:pick(f,[0,-10,8,-10,8,0,0,0]),eyes:f>=5?'happy':'open'},g=>{
  for(let i=0;i<6;i++){const a=i*Math.PI/3;g.line(51,26,51+Math.cos(a)*10,26+Math.sin(a)*10,C.cloud);}ring(g,51,26,5,C.blue);ring(g,51,26,9,C.blue);
},(g,P,x,y)=>{if(f<4)g.ell(51,26,2,2,C.bark);if(f>=2&&f<6){g.line(x+8,y+6,48,28,P.wing||P.shade);hand(g,48,28,P);}if(f===6)star(g,47,32);}));
add('golden/nest-party',f=>scene('golden',f,{dy:-10,eyes:'happy'},g=>nest(g,32,49,25),g=>{
  const n=Math.min(12,f*2);for(let i=0;i<n;i++){const x=12+(i%6)*8,y=46+Math.floor(i/6)*10; pup(g,x,y+(f%2),i%2?'#E8BB4D':'#F6DA8E',true);}
}));

// #17 Crystal — wing-specific glow, sensing hairs, closing a tiny crystal seam.
add('crystal/blacklight-glow',f=>scene('crystal',f,{wings:'mid',eyes:'half'},()=>{},()=>{},
  {palette:flash(f)?{wing:pick(f,['','','#7CCCA4','#A3E2B9','#BDECCD','#A3E2B9','#7CCCA4']),wingShade:'#618E85'}:{}}));
add('crystal/wind-hairs',f=>scene('crystal',f,{wings:'mid',eyes:'open'},g=>{if(f>0)wind(g,5,16,f%2);},(g)=>{
  for(const s of [-1,1])for(let i=0;i<4;i++){const x=32+s*(15+i*3),y=32+i;g.line(x,y,x+(f%2?1:0),y-3,C.cloud);if((i+f)%3===0)star(g,x,y-4,C.gold);}
}));
add('crystal/crystal-mend',f=>scene('crystal',f,{wings:'mid',eyes:f<4?'open':'happy'},()=>{},g=>{
  const length=pick(f,[8,8,7,6,4,2,1,0]);for(let i=0;i<length;i++)g.set(47+(i%3===0?1:0),30+i,f<2?C.ink:C.cream);
  if(f>=2&&f<=6)star(g,48,30+length,C.gold);
}));

// #18 Vampire — wing-powered gait, returning a groom, sharing the larger half.
add('vampire/gorilla-gallop',f=>scene('vampire',f,{dx:pick(f,[-7,-5,-2,1,4,7,4,0]),dy:f>0&&f<6?5:0,eyes:'open'},g=>g.line(8,57,56,57,C.bark),(g,P,x,y)=>{
  if(f>0&&f<7){const k=f%2?3:-2;g.line(x-10,y+4,x-13+k,55,P.wing);g.line(x+10,y+4,x+13-k,55,P.wing);g.rect(x-15+k,54,4,2,P.line);g.rect(x+11-k,54,4,2,P.line);}
}));
add('vampire/grooming-buddy',f=>scene('vampire',f,{eyes:f>1?'happy':'open',dx:f>1?3:0,mouth:'small'},g=>{g.rect(49,39,12,6,'#D7B693');g.ell(49,42,3,3,'#E8C9AA');},(g,P,x,y)=>{
  if(f>1&&f<7){hand(g,47,42-(f%2),P);g.line(x+1,y+4,48,42,C.pink);}if(f===6)star(g,53,32,C.pink);
}));
add('vampire/share-dinner',f=>scene('vampire',f,{eyes:f>=3?'happy':'open',mouth:'smile'},()=>{},(g,P,x,y)=>{
  if(f<3){fruit(g,x,y+8,6);hand(g,x-5,y+10,P);hand(g,x+5,y+10,P);}
  else{fruit(g,x-5,y+8,3);const d=pick(f,[0,0,0,4,7,11,14,14]);fruit(g,x+d,y+9,5);g.line(x+4,y+10,x+d,y+12,P.wing);hand(g,x+d,y+12,P);}
}));

// #19 Galaxy — maps fold into its constellation; the walk is symbolic steps,
// not GPS tracking. Keep the body present while a small star field tells the beat.
const stars=[[14,18],[30,10],[49,17],[52,36],[40,49],[18,45]];
function constellation(g,f,collapse=false){stars.forEach(([x,y],i)=>{
  const t=collapse?Math.min(1,f/6):0;const xx=x+(32-x)*t, yy=y+(36-y)*t;star(g,xx,yy,i%2?C.blue:C.gold);
  if(i<f&&i<stars.length-1){const [a,b]=stars[i+1];g.line(xx,yy,a+(32-a)*t,b+(36-b)*t,C.blue);}
});}
add('galaxy/star-map-hatch',f=>scene('galaxy',f,{eyes:'open'},g=>{if(f<6)constellation(g,f,true);},g=>{if(f>=5){star(g,21,29);star(g,36,38,C.blue);}}, {hidden:f<5}));
add('galaxy/shortcut-map',f=>scene('galaxy',f,{eyes:'half'},g=>{fruit(g,10,20,3);fruit(g,54,20,3);g.line(10,24,10,29,C.stem);g.line(54,24,54,29,C.stem);},g=>{
  for(let i=0;i<Math.min(11,f*2);i++)g.set(12+i*4,18-Math.round(Math.sin(i*Math.PI/10)*5),C.gold);
  if(f>=5)star(g,53,18,C.cream);
}));
add('galaxy/inner-compass',f=>scene('galaxy',f,{eyes:'closed'},g=>{if(f<3)stars.slice(f*2).forEach(([x,y])=>star(g,x,y));},g=>compass(g,32,43,Math.min(f+2,7))));
add('galaxy/migration-trail',f=>scene('galaxy',f,{wings:flash(f)?'mid':undefined,eyes:'happy'},()=>{},g=>{
  const route=[[21,34],[25,37],[28,33],[32,39],[37,35],[41,39],[44,33]];
  for(let i=0;i<Math.min(f,route.length);i++){const [x,y]=route[i];star(g,x,y,i%2?C.blue:C.gold);if(i>0)g.line(...route[i-1],x,y,C.blue);}
}));
add('galaxy/storm-surf',f=>scene('galaxy',f,{wings:f%2?'up':'mid',dx:pick(f,[-7,-5,-2,2,7,10,5,0]),lift:pick(f,[0,2,4,6,8,7,3,0]),eyes:'happy'},g=>{
  g.ell(14,15,10,4,'#777795');g.ell(22,12,7,5,'#777795');wind(g,7,53,f%2);wind(g,39,49,1);
},g=>{if(f>1&&f<7){star(g,12+f*3,47,C.gold);g.line(6+f*3,49,10+f*3,48,C.blue);}}));

// #20 Eclipse — hushed sonar, a hood of joined ears, old bark and a false dusk.
function halo(g,x,y,r=14){ring(g,x,y,r,C.gold);}
add('eclipse/totality-hatch',f=>scene('eclipse',f,{eyes:'glint'},g=>{
  g.ell(32,32,23,23,pick(f,['#B3A071','#998D70','#7A735D','#484642','#282630','#24222B','#24222B','#24222B']));
  halo(g,32,31,23);
},()=>{}, {hidden:f<3,noBack:true}));
add('eclipse/whisper-sonar',f=>scene('eclipse',f,{mouth:f>1&&f<5?'small':'smile'},()=>{},(g,P,x,y)=>{
  if(f>1&&f<6){g.set(x+10+f,y+3,C.blue);g.set(x+11+f,y+2,C.blue);g.set(x+11+f,y+4,C.blue);}
  moth(g,50-f*3,18);
}));
add('eclipse/halo-ears',f=>scene('eclipse',f,{eyes:f<5?'closed':'happy'},()=>{},(g,P,x,y)=>{
  if(f>0&&f<5){g.ell(x,y-11,12,6,P.shade);g.ell(x,y-10,8,4,P.ear);}
  if(f>=5)halo(g,x,y-17,10);
},{ears:f>0&&f<5?{type:'small'}:{type:'pointy'},noBack:f>0}));
add('eclipse/old-wood-hideaway',f=>scene('eclipse',f,{dy:f>1?2:0,eyes:'closed'},g=>{
  g.rect(11,9,43,50,C.bark);g.line(17,12,16,57,'#5E4B38');g.line(48,12,45,57,'#5E4B38');g.ell(32,36,15,22,'#29282E');
},g=>{if(f>=2){const width=pick(f,[0,0,3,6,8,10,11,11]);g.rect(17,10,width,47,C.bark);g.rect(47-width,10,width,47,C.bark);star(g,32,20,C.gold);}}));
add('eclipse/midday-dusk',f=>scene('eclipse',f,{eyes:pick(f,['closed','closed','half','open','open','half','closed','closed']),mouth:f===5?'small':'smile'},g=>{
  g.ell(51,15,7,7,C.gold);
  const cx=51+pick(f,[-16,-10,-5,0,0,5,11,16]);
  for(let y=7;y<=23;y++)for(let x=43;x<=59;x++)if(g.get(x,y)&&Math.hypot(x-cx,y-15)<=7)g.set(x,y,'#34303D');
},g=>{if(f===4||f===5){g.rect(12,26,1,3,C.cream);g.set(12,31,C.cream);}}));

module.exports = {draw, frames(key) {
  const d=draw[key];if(!d)throw new Error('Missing choreography: '+key);
  return d.seconds.map((seconds,f)=>({seconds,grid:d.fn(f),index:f}));
}};
