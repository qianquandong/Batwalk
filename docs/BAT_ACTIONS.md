# Bat Actions — 5 universal + signature actions per bat

Every Batwalk bat shares five **universal actions**. On top of those, each species has its own
**unique actions**, each taken from something its real-life counterpart actually does. That way
every bat's backstory is secretly true. The data lives in `Packages/BatwalkCore/Sources/BatwalkCore/BatActions.swift`
(`ActionCatalog`). This document is generated from that file plus the research sources.

**Totals:** 32 bats · 5 universal actions · 102 unique actions (29 bats × 3 + 3 Legendaries × 5).

**Playback status (2026-10-10):** Mochi, Sticky and Walker now have their five universal
clips and one Lv.4 signature each (18 clips / 74 frames). The remaining 99 unique
actions are design data, not playable animations. Lv.2/3 keepsakes still unlock;
their unique motion art is pending. See [pilot implementation and review](PILOT_ANIMATIONS.md).

## What we borrowed from Tamagotchi (and friends)

- **Each character moves in its own way.** On the Tamagotchi 4U, personality forms each have their own special idle
  animation ([Tamagotchi Wiki](https://tamagotchi.fandom.com/wiki/Personality_stage)). The Tamagotchi Uni gives each pet a
  personality that shapes its idle animations and reactions ([Tamagotchi Wiki](https://tamagotchi.fandom.com/wiki/Tamagotchi_Uni)).
- **The clock drives behaviour.** The Uni's pets yawn, nap and sing at set times of day. The Connection plays
  special animations at fixed times ([Tamagotchi Wiki](https://tamagotchi.fandom.com/wiki/Tamagotchi_Uni),
  [Tamazone FAQ](https://www.tapatalk.com/groups/tamazone/animation-faqs-t3451.html)). Here, that becomes Day sleep, Dusk wake-up and Night idle.
- **Rarer animations unlock over time.** Pokémon Sleep gives each species 3–4 named sleep styles. The rarer
  styles need a higher research rank ([Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Sleep_style)). Here, Friendship plays that role.
- **One small action per animation.** Pokémon Sleep's developers hand-keyed each style and gave it a single small
  action, such as a yawn or an eye-rub ([Famitsu interview](https://www.famitsu.com/news/202307/21310083.html)). That suits
  the Watch's battery and glance-length sessions.
- **Bond shows in body language, and only goes up.** The Pokémon Pikachu pedometer pet faces you more as
  friendship grows ([Bulbapedia](https://bulbapedia.bulbagarden.net/wiki/Pokémon_Pikachu)). We keep the growth
  and drop the sulking (PRD guardrail: no punishment).
- **"While you were away" surprises.** In Neko Atsume, cats only visit after you leave the app
  ([Kill Screen](https://www.killscreen.com/cats-finally-take-over-the-world-with-mobile-game-neko-atsume/)). Batwalk's version is
  the *Back from a walk* trigger.

## The 5 universal actions (every bat)

| Action | 中文 | Plays as | When |
|---|---|---|---|
| Idle | 待机 | `awake` | Default at night: breathing, ear twitch |
| Sleep | 睡觉 | `sleeping` | Daytime: hanging, wrapped in wings |
| Fly | 飞 | `playing` | Night activity loop |
| Pet | 被摸 | `happy` | Tap reaction: squish and blush |
| Eat | 吃果子 | `eating` | Feeding: hugs the fruit to its chest and munches |

These use the existing `bat_<id>_<mood>` sprites (`UniversalAction.mood`). Each bat still poses them
in its own body shape, as the concept board already does.

## Unique actions: how they unlock and when they play

| Slot | Unlock | PRD §2.7 says | Who has it |
|---|---|---|---|
| Hatch reveal | Lv.1 | High-value emotional moment | Legendary only |
| Idle quirk | Lv.2 | Additional idle animation | Every bat |
| Reaction | Lv.3 | New interaction reaction (after a pet or a feed) | Every bat |
| Signature | Lv.4 | Special signature animation | Every bat |
| Secret | Lv.5 | Special expression, next to the Friendship badge | Legendary only |

**Triggers:** Night idle · Dusk wake-up · Day sleep · After pet · After feed · Back from a walk (opening the app
after new steps) · New day (first look of the day) · Hatch · Rare.

**Play rules:**
- A unique action only plays while the bat is on screen, at most once per trigger moment. In between, the bat plays its universal actions.
- Nothing runs in the background, so the battery guardrails hold.
- Keep each action short and hand-keyed, with one readable gesture at real Watch size. Aim for about 1–2 s.
- When a level-up unlocks a new action, play it once straight away (`ActionCatalog.newlyUnlocked`).
- Keep it cozy, never scary: the Vampire Bat shares *fruit*, and the Ghost Bat's swoop ends with a gift.

### #1 Mochi Bat · Common

*Round, sleepy, friendly starter mascot.* **Real match:** Everyday bat behaviour: grooming, upside-down landings, wing masks.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Thumb Ear-Wash** `thumb-ear-wash` | 舔爪洗耳 | Night idle | Licks its thumb and scrubs inside one big ear, then the other. | Bats groom like cats for an hour or more a day, using a licked thumb to clean inside their ears. |
| 3 | **Wing Eye-Mask** `wing-eye-mask` | 翅膀眼罩 | After pet | Pulls one wing over its eyes like a sleep mask, then peeks out at you. | Bats shade their eyes with a wing on bright days. |
| 4 | **Cartwheel Landing** `cartwheel-landing` | 侧翻倒挂 | Back from a walk | Swoops up, does a half-cartwheel and catches the ceiling feet-first. | Bats land upside down by tucking one wing and flapping the other, flipping in a half-cartwheel. |

Sources: [1](https://tpwd.texas.gov/publications/nonpwdpubs/young_naturalist/animals/natures_bath_time/) · [2](https://engineering.brown.edu/news/2015-11-16/bats-use-weighty-wings-land-upside-down) · [3](https://kids.rangerrick.org/articles/bat-wings/)

### #2 Cocoa Bat · Common

*Chocolate brown, calm, wraps in wings.* **Real match:** Chocolate wattled bat (*Chalinolobus morio*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Sunrise Doze** `sunrise-doze` | 日出打盹 | Day sleep | Melts into a deep morning nap, nose bubble and all, then stretches awake. | Chocolate wattled bats dropped into torpor at sunrise on most summer days and woke mid-morning. |
| 3 | **Wattle Wiggle** `wattle-wiggle` | 肉垂晃晃 | After pet | Its little lip wattles wiggle and its pug nose scrunches. | The chocolate wattled bat has a pug nose and a small fleshy lobe (wattle) on its lip. |
| 4 | **Crèche Babysitter** `creche-babysitter` | 托儿所保姆 | Night idle | Tucks three tiny pink pups under one wing and rocks them to sleep. | Chocolate wattled bat colonies keep a crèche where a few adults babysit the pups while the rest hunt. |

Sources: [1](https://researchers.westernsydney.edu.au/en/publications/thermoregulatory-behavior-of-tree-roosting-chocolate-wattled-bats/) · [2](https://www.wildlife.vic.gov.au/__data/assets/pdf_file/0023/92435/Chocolate-Wattled-Bat.pdf) · [3](https://www.allaboutbats.org.au/chocolate-wattled-bat/)

### #3 Long Ear Bat · Common

*Oversized ears, curious reactions.* **Real match:** Brown long-eared bat (*Plecotus auritus*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Ram-Horn Ears** `ram-horn-ears` | 羊角卷耳 | Day sleep | Curls both ears back like ram's horns, then tucks them under its wings. | Resting brown long-eared bats curl their ears back or tuck them under their wings, leaving only the small inner flaps up. |
| 3 | **Ladybird Listen** `ladybird-listen` | 偷听瓢虫 | After pet | Freezes, ears swivelling, to follow a ladybird walking across a leaf. | The brown long-eared bat can hear a ladybird walking on a leaf. |
| 4 | **Butterfly Hover** `butterfly-hover` | 蝴蝶悬停 | Night idle | Goes quiet, hovers like a butterfly, and plucks a snack off a leaf. | It stops calling, hovers, listens, and picks insects straight off leaves. |

Sources: [1](https://www.bats.org.uk/about-bats/what-are-bats/uk-bats/brown-long-eared-bat) · [2](https://science.umd.edu/faculty/wilkinson/honr278c/Sppaccts/P_auritus_Willey.htm)

### #4 Fruit Bat · Common

*Round face, food-loving.* **Real match:** Egyptian fruit bat (*Rousettus aegyptiacus*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Fruit Hug** `fruit-hug` | 护食抱果 | Night idle | Hugs a fruit to its chest and glances left and right for snack thieves. | Egyptian fruit bats carry fruit to a perch and hug it to their chest so neighbours can't steal it. |
| 3 | **Spat Pop** `spat-pop` | 吐果渣 | After feed | Squishes the fruit, slurps the juice and spits out a tiny pulp pellet: ptoo! | Fruit bats press fruit against the palate, swallow the juice and spit out a pulp pellet called a spat. |
| 4 | **Squabble Squeaks** `squabble-squeaks` | 吱吱拌嘴 | Back from a walk | Squeak-argues with an invisible neighbour over a perch, then scoots over to share. | Decoded Egyptian fruit bat calls are mostly squabbles about food, sleeping spots and personal space. |

Sources: [1](https://animaldiversity.org/accounts/Rousettus_aegyptiacus/) · [2](https://www.wildlife.vic.gov.au/__data/assets/pdf_file/0024/27393/Bird-and-Flying-Fox-Bat-Damage-to-Orchard-Fruit.pdf) · [3](https://www.smithsonianmag.com/smart-news/researchers-translate-bat-talk-and-they-argue-lot-180961564/)

### #5 Cave Bat · Common

*Shy, hides in wings.* **Real match:** Lesser horseshoe bat (*Rhinolophus hipposideros*) and big cave nurseries.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Plum Wrap** `plum-wrap` | 李子团 | Day sleep | Wraps up into a plum-sized ball and sways gently from the ceiling. | Lesser horseshoe bats hang free with their wings wrapped around them, about the size of a plum. |
| 3 | **Peek Twist** `peek-twist` | 扭身偷看 | After pet | Twists around inside its wings to peek at you before deciding you're safe. | A lesser horseshoe bat twists its body to look around before flying off. |
| 4 | **Find-You Call** `find-you-call` | 呼唤找宝宝 | Back from a walk | Calls into a crowd of tiny sleeping shapes until one answers, then beams. | In huge cave nurseries, mothers find their own pup by voice, scent and memory. |

Sources: [1](https://www.bio.bris.ac.uk/research/bats/britishbats/batpages/lesserhorseshoe.htm) · [2](https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/mammals/lesser-horseshoe-bat/) · [3](https://www.batcon.org/visit)

### #6 Sleepy Bat · Common

*Half-closed eyes, tiny sleep cap.* **Real match:** Little brown bat (*Myotis lucifugus*) and hibernation.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **One Big Breath** `one-big-breath` | 一大口呼吸 | Day sleep | Snoozes perfectly still, then takes one enormous, slow breath. | A hibernating little brown bat may breathe only about once every 47 minutes. |
| 3 | **Groggy Wake** `groggy-wake` | 迷糊醒 | After pet | Blinks awake, licks a dewdrop off its fur, mumbles, and is asleep again. | Hibernating bats wake now and then and lick condensation droplets off their fur to drink. |
| 4 | **Pitcher Plant Bed** `pitcher-plant-bed` | 猪笼草睡袋 | New day | Climbs into a pitcher plant like a sleeping bag and settles in. | Hardwicke's woolly bat sleeps inside pitcher plants that guide it in with an echo reflector. |

Sources: [1](https://www.batcon.org/bats-in-winter/) · [2](https://www.usgs.gov/media/images/bats-torpor-water-droplets-their-fur) · [3](https://fau.eu/2015/07/news/research/carnivorous-plants-attract-bats-with-echo-reflectors)

### #7 Dust Bat · Common

*Fluffy gray, clumsy flight.* **Real match:** Young bats learning to fly.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Flap Practice** `flap-practice` | 拍翅练习 | Night idle | Hangs and does a burst of frantic wing-flaps, then pants, very proud. | Hanging bat pups practise flight with bursts of fast wing-flapping, peaking around two weeks old. |
| 3 | **Drop Start** `drop-start` | 松手起飞 | After pet | Lets go, plops down, remembers to flap, and flutters back up. | Bats take off by simply letting go and dropping into flight. |
| 4 | **Almost Landing** `almost-landing` | 差点着陆 | Back from a walk | Tries the upside-down landing, misses, somersaults, then sticks it in a puff of fluff. | Young free-tailed bats sometimes do a near-somersault to land back on the cave wall. |

Sources: [1](https://www.mdpi.com/2076-2615/10/8/1325/htm) · [2](https://www.reconnectwithnature.org/headlines/news/nature-curiosity-why-don-t-bats-get-dizzy-when-ha) · [3](https://www.discoverwildlife.com/animal-facts/mammals/brazilian-free-tailed-bats)

### #8 Pebble Bat · Common

*Stone-like round sleeper.* **Real match:** Eastern small-footed bat (*Myotis leibii*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Crack Squeeze** `crack-squeeze` | 挤石缝 | Day sleep | Flattens like a pancake and slides into a rock crack until only its mask shows. | Eastern small-footed bats have flattened skulls for squeezing into rock cracks. |
| 3 | **Bandit Peek** `bandit-peek` | 小偷面罩 | After pet | Pops out of its pebble pile wearing its black bandit mask. | The eastern small-footed bat has a black mask across golden fur. |
| 4 | **New Rock Every Day** `new-rock-every-day` | 每天换石头 | New day | Each new day it hops to a different pebble and settles in. | It roosts on sunny rock slopes and moves to a new rock nearly every day. |

Sources: [1](https://www.mass.gov/info-details/eastern-small-footed-bat) · [2](https://www.eaglehill.us/NENAonline/articles/NENA-18-1/18-Johnson.shtml)

### #9 Strawberry Bat · Uncommon

*Pink/red, strawberry motif, cheerful.* **Real match:** Eastern red bat (*Lasiurus borealis*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **One-Foot Sway** `one-foot-sway` | 单脚摇摆 | Day sleep | Hangs by one foot and twirls in the breeze like a ripe berry. | Eastern red bats hang by one foot among leaves, twisting in the breeze like a dead leaf. |
| 3 | **Tail Blanket** `tail-blanket` | 尾巴毯子 | After pet | Wraps itself in its furry tail like a blanket until only its face shows. | Red bats wrap themselves almost completely in their furry tail membrane. |
| 4 | **Berry Bunch** `berry-bunch` | 一串草莓 | Back from a walk | Three tiny pups dangle beside it like a bunch of strawberries. | Eastern red bats usually have about three pups, which hold mum with one foot and the branch with the other. |

Sources: [1](https://www.batcon.org/?p=17050) · [2](https://www.tn.gov/content/tn/twra/wildlife/mammals/mammals-bats/eastern-red-bat.html)

### #10 Blossom Bat · Uncommon

*Soft pink, petal particles.* **Real match:** Common blossom bat (*Syconycteris australis*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Brush-Tongue Sip** `brush-tongue-sip` | 刷子舌吸蜜 | Night idle | Hovers at a flower and paints out nectar with its brushy tongue. | The common blossom bat has a brush-tipped tongue and hovers at or lands on flowers. |
| 3 | **Pollen Sneeze** `pollen-sneeze` | 花粉喷嚏 | After pet | A pet sends up a puff of pollen from its fur — achoo! | Its fur is built to hold pollen; it carries about six times more than birds do. |
| 4 | **Flower Patrol** `flower-patrol` | 花丛巡逻 | Dusk wake-up | Shoos a rival off its flower patch, then fluffs up proudly. | Common blossom bats guard their flower patches fiercely. |

Sources: [1](https://www.sunshinecoast.qld.gov.au/environment/education-resources-and-events/environment-resources-and-publications/native-animals/blossom-bat) · [2](https://australian.museum/learn/animals/bats/common-blossom-bat/) · [3](https://www.animaldiversity.org/accounts/Syconycteris_australis/)

### #11 Moss Bat · Uncommon

*Green/brown, tiny sprout.* **Real match:** Seminole bat (*Lasiurus seminolus*), which roosts in Spanish moss.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Moss Hideout** `moss-hideout` | 苔藓藏身 | Day sleep | Burrows into a hanging tuft of Spanish moss, ears poking out. | Seminole bats roost alone inside clumps of Spanish moss in oak trees. |
| 3 | **Let-Go Drop** `let-go-drop` | 松手俯冲 | After pet | Lets go of the moss, drops straight down, and swoops back up. | Seminole bats pick roosts with open air below so they can drop straight into flight. |
| 4 | **Sprout Planting** `sprout-planting` | 种下小芽 | Back from a walk | Drops a seed as it flies; a tiny sprout pops up behind it. | Bats really replant forests: one fruit bat colony in Ghana spreads over 300,000 seeds a night. |

Sources: [1](https://www.depts.ttu.edu/nsrl/mammals-of-texas-online-edition/Accounts_Chiroptera/Lasiurus_seminolus.php) · [2](https://animaldiversity.org/accounts/Lasiurus_seminolus) · [3](https://www.mpg.de/13271542/fruit-bats-seed-dispersal)

### #12 Sunset Bat · Uncommon

*Orange/purple, energetic at dusk.* **Real match:** Mexican free-tailed bat emergence; greater mouse-eared bat's sunset compass.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Sunset Compass** `sunset-compass` | 落日指南针 | Dusk wake-up | Stares at the sunset glow while a tiny compass needle spins and settles. | Greater mouse-eared bats set their magnetic compass by the sunset glow. |
| 3 | **Crowd Dodge** `crowd-dodge` | 混进蝠群 | After pet | Zig-zags into an invisible crowd of friends and pops out the other side. | Free-tailed bats emerge in a dense crowd so no single bat stands out. |
| 4 | **Batnado** `batnado` | 蝙蝠龙卷风 | Dusk wake-up | Spirals up in a swirling column of silhouette friends, then streams away like a river. | Millions of Mexican free-tailed bats spiral out of Bracken Cave at dusk in a 'batnado'. |

Sources: [1](https://www.sciencefriday.com/segments/catching-a-texas-batnado/) · [2](https://www.mpg.de/research/bats-navigate-with-the-sun)

### #13 Snow Bat · Uncommon

*White/blue, snowflake particles.* **Real match:** Hoary bat (*Lasiurus cinereus*) and frosty hibernation.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Frost Beads** `frost-beads` | 结霜水珠 | Day sleep | Tiny droplets bead and sparkle all over its fur while it sleeps. | Hibernating bats cool to cave temperature, so condensation beads all over their fur. |
| 3 | **Sleeping Bag** `sleeping-bag` | 尾巴睡袋 | After pet | Shivers, then zips itself into its furry tail like a sleeping bag. | In harsh weather the hoary bat wraps its furry tail membrane around itself like a blanket. |
| 4 | **Great Migration** `great-migration` | 大迁徙 | Back from a walk | Pulls on a tiny scarf and flaps off over the horizon — and back. | Hoary bats are long-distance migrants; Hawaii's hoary bats descend from ancestors that crossed 2,000+ miles of ocean. |

Sources: [1](https://biokids.umich.edu/critters/Lasiurus_cinereus/) · [2](https://www.usgs.gov/media/images/bats-torpor-water-droplets-their-fur) · [3](https://www.nps.gov/havo/learn/nature/hawaiian-bat.htm)

### #14 Cloud Bat · Uncommon

*Fluffy white-gray, dreamy.* **Real match:** Brazilian free-tailed bats hunting high in the sky.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Radar Bloom** `radar-bloom` | 雷达云团 | Night idle | A ring of tiny dots blooms around it like a cloud on a weather radar. | Bat emergences show up on Doppler weather radar as blooming, ring-shaped clouds. |
| 3 | **Gust Surf** `gust-surf` | 乘风冲浪 | After pet | A puff of wind catches it and it surfs the gust, ears flapping. | Radar showed a distant storm's gust front sweeping a Texas cave's bats away like a broom. |
| 4 | **Sky-High Snack** `sky-high-snack` | 云端加餐 | Back from a walk | Rockets up to the clouds, snaps a snack from the wind and zooms back in speed lines. | Free-tailed bats hunt moths on night winds hundreds of metres up, with bursts near 100 mph. |

Sources: [1](https://tethys.pnnl.gov/sites/default/files/publications/mccracken-et-al-2008.pdf) · [2](https://wset.com/news/offbeat/holy-gust-front-radar-shows-texas-bats-getting-blown-away-by-distant-storm) · [3](https://www.newswise.com/articles/it-s-not-a-bird-it-s-not-a-plane-it-s-the-fastest-flying-mammal-says-ut-study)

### #15 Moonwing · Rare

*Deep blue, moon motifs, mysterious.* **Real match:** Lunar phobia; white-throated round-eared bat (*Lophostoma silvicolum*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Moon Shy** `moon-shy` | 害羞月亮 | Night idle | When the moon is bright it hides behind a wing and peeks up at it. | Many bats fly less on bright full-moon nights ('lunar phobia'). |
| 3 | **Katydid Hush** `katydid-hush` | 嘘——螽斯 | After pet | Holds a wing to its lips — shh — and a tiny katydid goes quiet too. | On bright moonlit nights a Panamanian bat and the katydids it hunts both go quiet. |
| 4 | **Termite-Mound Den** `termite-mound-den` | 白蚁丘小窝 | Day sleep | Chews a round, cosy den into a mound and curls up inside. | Male white-throated round-eared bats chew roost cavities into active termite nests. |

Sources: [1](https://repository.si.edu/bitstream/handle/10088/4116/Lang_et_al_2006.pdf) · [2](https://www.bio.umass.edu/biology/dumont/Dechmann_et_al_2009_Roost_Making_in_Bats_Excavating_termite_nests_JMamm.pdf)

### #16 Golden Bat · Rare

*Gold accents, confident sparkle.* **Real match:** Golden-tipped bat (*Kerivoula papuensis*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Nest Blend** `nest-blend` | 鸟巢隐身 | Day sleep | Fluffs its gold-tipped fur and vanishes into a hanging bird nest. | Golden-tipped bats live in hanging bird nests, their woolly fur blending with the nest fibres. |
| 3 | **Web Pluck** `web-pluck` | 蛛网摘点心 | After pet | Hovers at a dewy spider web and plucks off a snack with a flourish. | It eats almost only orb-weaving spiders, plucking them off their webs. |
| 4 | **Nest Party** `nest-party` | 鸟巢派对 | Back from a walk | The nest wiggles and golden faces pop out one by one — up to twelve. | Up to 12 golden-tipped bats have been found in a single nest. |

Sources: [1](https://cosmosmagazine.com/nature/amoty/golden-tipped-bat-gilded-masters-of-camouflage) · [2](https://australian.museum/learn/animals/bats/golden-tipped-bat/)

### #17 Crystal Bat · Rare

*Blue/purple crystalline wings.* **Real match:** Bats that glow under UV light; how bat wings sense and heal.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Blacklight Glow** `blacklight-glow` | 紫外荧光 | Night idle | Its wings flash a soft green glow, as if under a blacklight. | Several North American bats glow green on their wings under UV light, and nobody knows why. |
| 3 | **Wind Hairs** `wind-hairs` | 感风绒毛 | After pet | Tiny hairs on its wings sparkle as it tests the air. | Tiny domed hairs on bat wings work as airspeed sensors. |
| 4 | **Crystal Mend** `crystal-mend` | 水晶自愈 | New day | A crack in one crystal wing glimmers and seals itself shut. | Bat wings heal themselves: 8 mm holes closed in about four weeks in summer. |

Sources: [1](https://www.futurity.org/bats-glow-green-under-uv-light-3301602/) · [2](https://isr.umd.edu/news/story/tiny-hairs-on-bats-wings-act-as-speedometers) · [3](https://pmc.ncbi.nlm.nih.gov/articles/PMC4295170)

### #18 Vampire Bat · Rare

*Cute black/red cape, dramatic not scary.* **Real match:** Common vampire bat (*Desmodus rotundus*), cozy version: fruit instead of blood.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Gorilla Gallop** `gorilla-gallop` | 猩猩式奔跑 | Night idle | Drops to the ground and gallops along on its wings like a tiny gorilla. | The common vampire bat is the only bat known to truly run, about 2.5 mph on a treadmill. |
| 3 | **Grooming Buddy** `grooming-buddy` | 互相梳毛 | After pet | Grooms your finger right back — that's how bat friendships start. | Vampire bat strangers become friends by grooming first, then sharing food. |
| 4 | **Share Dinner** `share-dinner` | 分享晚餐 | After feed | Splits its fruit in two and offers you the bigger half. | Well-fed vampire bats share dinner with hungry roost-mates, even unrelated ones. |

Sources: [1](https://news.osu.edu/scientists-learn-how-vampire-bat-strangers-make-friends/) · [2](https://www.npr.org/2019/10/31/774358215/for-these-vampires-a-shared-blood-meal-lets-friendship-take-flight) · [3](https://news.cornell.edu/node/282646)

### #19 Galaxy Bat · Legendary ★

*Starfield body, premium particles.* **Real match:** How bats navigate and migrate at night.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 1 | **Star-Map Hatch** `star-map-hatch` | 星图孵化 | Hatch | The egg cracks into a little constellation map that folds into its body. | Wild Egyptian fruit bats carry a mental map of their home range. |
| 2 | **Shortcut Map** `shortcut-map` | 抄近路地图 | Night idle | Dotted lines draw a shortcut between twinkling fruit trees. | Egyptian fruit bats fly straight to trees they can't see or smell, and take shortcuts. |
| 3 | **Inner Compass** `inner-compass` | 体内罗盘 | After pet | The stars fade out — and the compass inside it still points true. | Neurons in wild bats keep an internal compass that works with or without the moon and stars. |
| 4 | **Migration Trail** `migration-trail` | 迁徙轨迹 | Back from a walk | Draws today's walk across its starry body as a migration route. | A Nathusius' pipistrelle flew 2,224 km from Latvia to Spain. |
| 5 | **Storm Surf** `storm-surf` | 风暴冲浪 | Rare | Rides a warm wind ahead of a storm, streaking across the whole sky. | Noctule bats surf warm winds ahead of storm fronts, covering nearly 400 km in a night. |

Sources: [1](https://www.bfhu.org/2020/07/09/cognitive-map-based-navigation-in-wild-bats-revealed-by-a-new-high-throughput-tracking-system/) · [2](https://wis-wander.weizmann.ac.il/node/12300) · [3](https://secemu.org/en/2200-km-transcontinental-migration-of-a-nathusius-pipistrelle-pipistrellus-nathusii-across-europe/) · [4](https://www.mpg.de/23893833/bats-surf-storm-fronts-during-continental-migration)

### #20 Eclipse Bat · Legendary ★

*Black/gold halo, silent and rare.* **Real match:** Barbastelle (*Barbastella barbastellus*), the whispering bat; bats during eclipses.

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 1 | **Totality Hatch** `totality-hatch` | 全食孵化 | Hatch | The screen dims to totality and the bat appears inside the golden ring. | During solar eclipses some bats behave as if dusk has come. |
| 2 | **Whisper Sonar** `whisper-sonar` | 耳语声呐 | Night idle | Sends sonar ripples so tiny that a moth drifts right past without noticing. | The barbastelle's calls are up to 100 times quieter; moths only notice it about 3.5 m away. |
| 3 | **Halo Ears** `halo-ears` | 光环耳朵 | After pet | Pulls its joined ears down like a hood, then pops them up into a halo. | Barbastelles have ears that join across the forehead. |
| 4 | **Old-Wood Hideaway** `old-wood-hideaway` | 古木藏身 | New day | Slips into a crack in an ancient dead tree; only the halo glints. | The barbastelle, one of the UK's rarest mammals, favours old woods with dead trees. |
| 5 | **Midday Dusk** `midday-dusk` | 正午黄昏 | Rare | In broad daylight the sky darkens; it wakes, peeks out as if dusk came, then shrugs back to sleep. | During a 1991 eclipse, gray sac-winged bats left their roost as if dusk had come. |

Sources: [1](https://www.sciencedaily.com/releases/2010/08/100819121210.htm) · [2](https://www.bats.org.uk/about-bats/what-are-bats/uk-bats/barbastelle) · [3](https://nhm.ac.uk/discover/joules-salisburys-rare-barbastelle-bat.html) · [4](https://www.nationalgeographic.com/animals/article/solar-eclipse-2024-north-america-bats-photography)

### #21 Bumblebee Bat · Common

*Thumb-sized, piggy nose, buzzes when it flies.* **Real match:** Kitti's hog-nosed bat (*Craseonycteris thonglongyai*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Moth Hover** `moth-hover` | 飞蛾悬停 | Night idle | Flutters in place like a tiny moth. | Kitti's hog-nosed bat has fluttery, moth-like flight and can hover. |
| 3 | **Warm Dome** `warm-dome` | 找暖窝 | After pet | Scoots up to the warmest spot on the ceiling and sighs happily. | Each bat roosts alone high in the warmest dome of a limestone cave ceiling. |
| 4 | **Thirty-Minute Dash** `thirty-minute-dash` | 三十分钟冲刺 | Dusk wake-up | Circles the cave mouth, then zips out for a tiny dusk flight with a ticking timer. | It circles the cave mouth, leaves about 10 minutes after sunset, and flies only about 30 minutes. |

Sources: [1](https://thesiamsociety.org/wp-content/uploads/2020/04/NHBSS_038_2g_Duangkhae_EcologyAndBehav.pdf) · [2](https://animaldiversity.org/accounts/Craseonycteris_thonglongyai/)

### #22 Sticky Bat · Common

*Suction-cup thumbs, naps head-up in a rolled leaf.* **Real match:** Spix's disk-winged bat (*Thyroptera tricolor*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Head-Up Nap** `head-up-nap` | 头朝上午睡 | Day sleep | Naps head-UP in a rolled leaf, the wrong way round from every other bat. | Spix's disk-winged bats cling head-up inside rolled leaves. |
| 3 | **Leaf Chorus** `leaf-chorus` | 叶子合唱 | After pet | Gives one call, and a chorus of tiny replies echoes back out of its leaf. | A flying bat gives one call; bats in the leaf reply with up to about 20 notes, the leaf acting as an ear trumpet. |
| 4 | **Moving Day** `moving-day` | 搬家日 | New day | Its leaf unrolls, so it suction-cups across to a fresh rolled leaf. | It moves to a new leaf almost every day, because the leaf unrolls as it grows. |

Sources: [1](https://www.nationalgeographic.com/science/article/how-sucker-winged-bats-hang-on) · [2](https://www.livescience.com/40429-speak-up-costa-rican-bats-use-leaves-as-hearing-aids.html)

### #23 Marshmallow Bat · Uncommon

*Snow-white puff, yellow nose and ears, sleeps in a leaf tent.* **Real match:** Honduran white bat (*Ectophylla alba*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Leaf Tent** `leaf-tent` | 叶子帐篷 | Day sleep | Nibbles a leaf's veins until it droops into a tent, then snuggles under. | Honduran white bats cut the side veins of a Heliconia leaf so it folds into a tent. |
| 3 | **Green Glow** `green-glow` | 绿光染色 | After pet | Sunlight through the leaf washes its white fluff minty green. | Light shining through the leaf tent makes their white fur look green. |
| 4 | **Fig Yellow** `fig-yellow` | 无花果变黄 | After feed | Eats a fig and its nose and ears glow brighter yellow. | Their yellow nose and ears get their colour from lutein in the figs they eat. |

Sources: [1](https://livescience.com/animals/bats/honduran-white-bats-the-fluffy-little-bats-that-roost-together-in-leaf-tents) · [2](https://www.batcon.org/bat/ectophylla-alba-2/) · [3](https://doi.org/10.1093/jmammal/gyz035)

### #24 Honk Bat · Uncommon

*Big goofy snout, honks when happy.* **Real match:** Hammer-headed bat (*Hypsignathus monstrosus*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Nose Wrap** `nose-wrap` | 翅膀包鼻子 | Day sleep | Sleeps with both wings wrapped over its giant nose. | Hammer-headed bats sleep with their wings wrapped over the nose. |
| 3 | **Happy Buzz** `happy-buzz` | 开心嗡嗡 | After pet | Lets out a fast, choppy buzz — you picked it! | When a female lands beside him, the chosen male gives a buzz call. |
| 4 | **Honk Concert** `honk-concert` | 喇叭音乐会 | Night idle | Flaps half-open wings and honks faster and faster into a buzzing crescendo. | Males line up and honk 60 to 120 times a minute while flapping half-open wings. |

Sources: [1](https://animaldiversity.org/accounts/Hypsignathus_monstrosus/) · [2](https://www.sciencefocus.com/nature/honking-hammerhead-bat)

### #25 Ember Bat · Uncommon

*Bright orange with black-trimmed wings, hides in dry leaves.* **Real match:** Painted bat (*Kerivoula picta*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Banana-Leaf Curl** `banana-leaf-curl` | 香蕉叶卷 | Day sleep | Rolls up inside a curled dry banana leaf like a spring roll. | Painted bats roost in curled dry banana leaves and hanging bird nests. |
| 3 | **Slow-Mo Wake** `slow-mo-wake` | 慢动作醒来 | After pet | Reacts to your pet in super slow motion. It is very sleepy by day. | Painted bats are drowsy by day and slow to react when disturbed. |
| 4 | **Tail Net** `tail-net` | 尾巴捕虫网 | Night idle | Flutters in low circles, scoops a firefly in its tail like a net, then lets it go. | Painted bats fly low in fluttery circles and scoop insects with their tail membrane. |

Sources: [1](https://www.thainationalparks.com/species/kerivoula-picta) · [2](https://animaldiversity.org/accounts/Kerivoula_picta/)

### #26 Nectar Bat · Uncommon

*Super-long tongue, blep, always sipping flowers.* **Real match:** Tube-lipped nectar bat (*Anoura fistulata*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Hummingbird Hover** `hummingbird-hover` | 蜂鸟悬停 | Night idle | Hovers at a long trumpet flower, head bobbing. | The tube-lipped nectar bat hovers like a hummingbird at long trumpet flowers. |
| 3 | **Mop Tongue** `mop-tongue` | 拖把舌头 | After feed | Unspools a ridiculously long tongue, mop tip fanning out, then slurps it back into its chest. | Its tongue, about 1.5 times its body length, has a bristly tip and pulls back into its chest. |
| 4 | **Straw Test** `straw-test` | 吸管测试 | Back from a walk | Sips from a drinking straw, reaching twice as deep as you'd think, head dusted in pollen. | Scientists found its tongue with a straw test: it reached over twice as far as other nectar bats. |

Sources: [1](https://www.nationalgeographic.com/photography/article/120611-bat-tongue-video-untamed-americas-science-longest) · [2](https://www.snexplores.org/article/tongue-and-half)

### #27 Tube-Nose Bat · Uncommon

*Snorkel nostrils, speckled wings, wise old face.* **Real match:** Tube-nosed fruit bats (*Nyctimene*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Dead-Leaf Disguise** `dead-leaf-disguise` | 枯叶伪装 | Day sleep | Wraps itself in its spotted wings and becomes a dappled leaf. | Tube-nosed fruit bats roost alone wrapped in spotted wings, looking like dead leaves. |
| 3 | **Stereo Sniff** `stereo-sniff` | 立体声嗅嗅 | After pet | Each nose tube wiggles on its own: sniff left, sniff right, sniff left. | Each tubular nostril can move on its own, perhaps to smell in stereo. |
| 4 | **Sideways Fig** `sideways-fig` | 侧挂吃无花果 | After feed | Hangs sideways, hugs a fig half its size and squeezes out the juice, whistling. | It carries figs over half its body weight, hangs at an angle to eat, and whistles in flight. |

Sources: [1](https://animaldiversity.org/accounts/Nyctimene_robinsoni) · [2](https://animaldiversity.org/accounts/Nyctimene_albiventer)

### #28 Polka Bat · Rare

*Black with three white spots, gigantic pink ears.* **Real match:** Spotted bat (*Euderma maculatum*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Ear Scarf** `ear-scarf` | 耳朵围巾 | Day sleep | Rolls its giant pink ears around its head like a scarf. | The spotted bat rolls its huge ears up when resting and unrolls them when active. |
| 3 | **Hear-Me Chirp** `hear-me-chirp` | 听得见的叫声 | After pet | Chirps a call you could actually hear, its sound rings drawn big and bold. | Its calls are low enough for people to hear. |
| 4 | **Same-Route Loop** `same-route-loop` | 老路线绕圈 | Back from a walk | Flies one big oval loop, the same route as last night, and drops a lap marker. | Spotted bats fly wide oval loops and often follow the same route every night. |

Sources: [1](https://desertmuseum.org/kids/bats/Spotted%20bat.php) · [2](https://www.env.gov.bc.ca/okanagan/esd/atlas/species/spotted_bat.html) · [3](https://www.canada.ca/en/environment-climate-change/services/species-risk-public-registry/cosewic-assessments-status-reports/spotted-bat-update/chapter-6.html)

### #29 Wrinkle Bat · Rare

*Squishy wrinkly face, hides behind a fluffy chin mask when shy.* **Real match:** Wrinkle-faced bat (*Centurio senex*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Wingtip Rub** `wingtip-rub` | 搓翅尖 | Night idle | Rubs its wingtips together, over and over, very pleased with itself. | Displaying male wrinkle-faced bats spend most of their time rubbing their wingtips together. |
| 3 | **Shy Mask** `shy-mask` | 害羞面罩 | After pet | Pulls its fluffy chin mask up over its face with both thumbs, then peeks. | Male wrinkle-faced bats pull a furry chin fold up and down over the face with their thumbs. |
| 4 | **Whistle Lunge** `whistle-lunge` | 口哨猛扑 | Dusk wake-up | Seven quick wingbeats, then a bold forward lunge with a loud whistle. | When another bat comes near, a male gives about seven quick wingbeats, then lunges with a whistle. |

Sources: [1](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0241063) · [2](https://livescience.com/ugly-bats-face-masks.html)

### #30 Walker Bat · Rare

*Folds its wings and power-walks everywhere — Batwalk's spirit animal.* **Real match:** New Zealand lesser short-tailed bat (*Mystacina tuberculata*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Leaf-Litter Dig** `leaf-litter-dig` | 刨落叶 | Night idle | Digs into leaf litter with its thumb claws, sniffing for snacks. | It has talon-like claws for digging through leaf litter and hunts partly by smell. |
| 3 | **Titter Song** `titter-song` | 咯咯情歌 | After pet | Sings a little tittering song from its tree. | Males take turns singing 'tittering' songs from roost trees. |
| 4 | **Power Walk** `power-walk` | 健步走 | Back from a walk | Folds its wings and power-walks across the screen with you, then sips a ground flower. | It folds its wings, scurries on its forearms, and visits ground-flowering wood roses. |

Sources: [1](https://www.australiangeographic.com.au/blogs/creatura-blog/2018/01/why-fly-when-you-can-shuffle-the-lesser-short-tailed-bat-prefers-the-ground/) · [2](https://www.doc.govt.nz/nature/native-animals/bats-pekapeka/short-tailed-bat/) · [3](https://doi.org/10.1093/beheco/arv070)

### #31 Fox Bat · Rare

*Huge cloak-like wings, fox face, golden crown of fur.* **Real match:** Giant golden-crowned flying fox (*Acerodon jubatus*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 2 | **Big Sleep** `big-sleep` | 超级大睡 | Day sleep | Sleeps hard, with one lazy wing-flap and a quick groom. | It sleeps about 76% of the day; the rest is grooming, wing-flapping and defending its spot. |
| 3 | **Wing Fan** `wing-fan` | 翅膀扇风 | After pet | Fans you with one huge wing to keep you cool. | Mothers fan their pups with one wing to keep them cool. |
| 4 | **Leaf Juice** `leaf-juice` | 榨叶汁 | After feed | Munches a fig, then crushes a leaf and sips just the juice. | It specialises in figs and also crushes leaves to swallow only the juice. |

Sources: [1](https://www.jstage.jst.go.jp/article/jvms/79/10/79_17-0329/_article) · [2](https://animaldiversity.org/accounts/Acerodon_jubatus/) · [3](https://www.batcon.org/bat/acerodon-jubatus/)

### #32 Ghost Bat · Legendary ★

*Pale glow, see-through wings, gentle never spooky.* **Real match:** Australian ghost bat (*Macroderma gigas*).

| Lv | Action | 中文 | Trigger | What it shows | Real basis |
|---|---|---|---|---|---|
| 1 | **Moonlit Unveiling** `moonlit-unveiling` | 月光现身 | Hatch | The egg turns see-through and a pale bat fades in from inside. | The ghost bat is named for its pale, ghostly fur. |
| 2 | **Dirrup Twitter** `dirrup-twitter` | 嘀噜嘀噜 | Night idle | Bobs excitedly and twitters 'dirrup dirrup'. | Ghost bats give a twittering 'dirrup' call when excited or before leaving the roost. |
| 3 | **Ear Zip** `ear-zip` | 拉链耳朵 | After pet | Zips its giant joined ears upright and stands tall. | Its ears are about twice the length of its head and joined at the base. |
| 4 | **Silhouette Watch** `silhouette-watch` | 看剪影 | Dusk wake-up | Watches a bird silhouette glide across the evening sky and waves a wing. | Big-eyed ghost bats can spot birds as silhouettes against the evening sky. |
| 5 | **Cloak Swoop** `cloak-swoop` | 斗篷俯冲 | Rare | Drops from its perch, swoops, wraps its wings into a cloak, and unveils a gift fruit for you. | It waits on a perch, drops down, and wraps its wings around its catch. |

Sources: [1](https://animaldiversity.org/accounts/Macroderma_gigas) · [2](https://en.wikipedia.org/wiki/Ghost_bat)

## Art production

- One sheet per unique action, named `bat_<speciesID>_<actionID>_sheet` (`BatAction.assetName` + `_sheet`),
  frames laid out horizontally on the shared logical canvas (Art/README.md). That's 102 sheets in total.
- Shiny reuses the same frames with a different palette. No extra animation is needed.
- Until a sheet exists, the game falls back to the universal action, so art can land one file at a time.

## Not built yet (follow-ups)

- A **"seen" record per action**, so the Batpedia can show "3 / 3 actions discovered" (Pokémon Sleep-style).
  This needs a save-format field, so it should go in a separate change.
- **Playback wiring** in the Watch views (milestone M2 animation component). The catalog and unlock rules are ready.
- **Calendar specials** across all bats (holidays, the player's birthday), the way the Tamagotchi Connection does it.
