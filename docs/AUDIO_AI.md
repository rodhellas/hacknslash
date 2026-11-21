# Testi per generare suoni, ambienti e musica con un'AI

Tre parti: **A** effetti sonori (92 suoni, 190 file contando le versioni), **B** ambienti in loop (7),
**C** musica (7 brani, più 3 facoltativi per i singoli dungeon). Il catalogo nel codice è `data/sound_db.gd`; dove un file manca il gioco usa il suono
sintetizzato di oggi (o il silenzio), quindi puoi consegnarli poco alla volta.

Strumenti consigliati: **ElevenLabs Sound Effects** o **Stable Audio** per A e B (testo → suono, durata a scelta),
**Suno** o **Udio** per C (in modalità *strumentale*). In alternativa per A: pacchetti CC0 (Kenney, Sonniss GDC).

## Regole comuni

- **Formato**: `.ogg` (o `.wav`), mono per gli effetti, stereo per ambienti e musica, 44,1 kHz.
- **Nomi**: esattamente quelli delle tabelle. Dove la colonna "Versioni" dice 3, genera 3 file diversi con lo stesso
  testo e salvali come `nome_1.ogg`, `nome_2.ogg`, `nome_3.ogg`: il gioco ne sceglie uno a caso ogni volta.
- **Effetti**: niente silenzio all'inizio (il suono deve partire subito), coda breve, **niente musica**, niente voci
  che parlano (solo grida/versi dove indicato). Taglia il silenzio finale.
- **Volumi**: normalizza tutti gli effetti allo stesso livello (circa −3 dB di picco); il bilanciamento lo fa il gioco.
- **Cartelle**: effetti in `audio/sfx/`, ambienti in `audio/ambience/`, musica in `audio/music/`.

### Stile (da aggiungere DOPO ogni testo degli effetti)
> , video game sound effect, dark fantasy action RPG, ancient Roman empire in the year 3000, mix of bronze, steel and leather with humming sci-fi energy, punchy and weighty, high quality, no music

---

## A. Effetti sonori — `audio/sfx/`

### A1. Combattimento dell'eroe
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `fendente` | 3 | 0,4 s | Fast sword swing whoosh of a short Roman gladius, with a faint electric energy hum trailing the blade |
| `fendente_pesante` | 3 | 0,6 s | Heavy slow swing of a long sword or axe cutting the air, deep whoosh with an energy hum |
| `turbine` | 3 | 0,5 s | Spinning blade whirl, circular whoosh with crackling energy |
| `colpo_fisico` | 3 | 0,3 s | Blade impact on armored flesh, metallic clank and meaty thud |
| `colpo_fuoco` | 3 | 0,4 s | Impact with a burst of flame, fiery whoomp and sizzle |
| `colpo_freddo` | 3 | 0,4 s | Impact with shattering ice, crisp crackle of frost |
| `colpo_fulmine` | 3 | 0,4 s | Impact with an electric shock, sharp zap and crackle |
| `critico` | 3 | 0,5 s | Brutal critical hit, heavy crunchy impact with a bright metallic ring and bass punch |
| `colpo_scudo` | 2 | 0,4 s | Large metal shield bashing an enemy, heavy clang and thud |

### A2. Abilità
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `pilum` | 2 | 0,8 s | A javelin of pure energy forming in the hand with a rising hum, then thrown with a powerful electric whoosh |
| `dardo` | 3 | 0,4 s | Bow shot firing a bolt of energy, string twang with a short plasma zip |
| `sfera_fuoco` | 2 | 0,8 s | Large ball of fire launched, roaring flame whoosh |
| `lancio_fulmine` | 3 | 0,5 s | Lightning bolt cast from the hand, sharp electric crack and buzz |
| `rete` | 2 | 0,6 s | Net of energy filaments thrown and spreading open, electric crackle and swish |
| `bolas` | 2 | 0,6 s | Spinning bolas thrown, rhythmic whirring with an energy hum |
| `scure_lancio` | 2 | 0,6 s | Throwing axe spinning through the air, rhythmic whoosh-whoosh with energy hum |
| `granata` | 2 | 0,5 s | Unstable energy sphere lobbed, pulsing whine rising in pitch |
| `trappola` | 2 | 0,7 s | Energy trap placed on the ground and armed, mechanical click and rising electric hum |
| `raggio_orbitale` | 2 | 1,2 s | Jupiter thunderbolt: rumbling storm charge in the clouds, then a massive descending bolt of divine light and thunder |
| `meteora` | 2 | 1,2 s | Flaming meteor falling from the sky, growing roar and whistle |
| `saetta` | 2 | 1,0 s | Thunderbolt striking the ground, deafening thunder crack with electric sizzle |
| `pioggia_dardi` | 2 | 2,5 s | Dozens of energy bolts raining down, rapid whistling and impacts on the ground |
| `corvi` | 2 | 2,5 s | Swarm of spectral energy ravens, flapping wings, eerie caws and electric shimmer |
| `terremoto` | 2 | 1,5 s | Earthquake stomp, deep rumble of the ground cracking with rocks and glowing energy |
| `onda_urto` | 2 | 0,8 s | Shockwave blast pushing enemies back, deep whump and rushing air |
| `ondata` | 2 | 1,2 s | Magical tidal wave crashing outward, water surge and splash |
| `anello_fuoco` | 2 | 1,2 s | Ring of fire erupting around the caster, roaring flames |
| `grido_guerra` | 2 | 1,2 s | Powerful male war cry of a Roman warrior with an echoing battle roar |
| `folla` | 1 | 2,0 s | Roaring arena crowd cheering, Roman colosseum |
| `scudo` | 2 | 0,8 s | Protective energy shield activating, rising hum and shimmering bubble |
| `concentrazione` | 2 | 0,8 s | Focus ability, deep breath and a sharp metallic ring of concentration |
| `carica` | 2 | 0,8 s | Warrior charging forward with heavy armored footsteps and rushing wind |
| `capriola` | 2 | 0,5 s | Quick acrobatic roll, cloth and leather rustle with a soft whoosh |
| `balzo` | 2 | 0,6 s | Powerful leap into the air, grunt and whoosh |
| `atterraggio` | 2 | 0,8 s | Heavy landing from a leap smashing the ground, deep impact and debris |
| `teletrasporto` | 2 | 0,6 s | Teleport, energy zap and pop with a short whoosh |
| `lancio_magia` | 3 | 0,6 s | Divine spell cast, shimmering magical whoosh with energy hum |

### A3. Esplosioni
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `esplosione_fisico` | 2 | 1,0 s | Heavy ground explosion, rocks and dust, deep boom |
| `esplosione_fuoco` | 3 | 1,2 s | Fiery explosion, big whoomp with crackling flames |
| `esplosione_freddo` | 2 | 1,0 s | Ice explosion, shattering crystals and freezing burst |
| `esplosione_fulmine` | 2 | 1,0 s | Electric explosion, thunderous discharge with crackling sparks |

### A4. Eroe
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `passo_terra` | 4 | 0,25 s | Single footstep of a sandal on dirt and grass, soft crunch |
| `passo_pietra` | 4 | 0,25 s | Single footstep of a hobnailed Roman sandal on stone pavement, light clack |
| `eroe_ferito_m` | 3 | 0,4 s | Male warrior short pain grunt |
| `eroe_ferito_f` | 3 | 0,4 s | Female warrior short pain grunt |
| `eroe_morte_m` | 1 | 1,2 s | Male warrior dying, final groan and armor collapsing on the ground |
| `eroe_morte_f` | 1 | 1,2 s | Female warrior dying, final groan and armor collapsing on the ground |
| `pozione` | 2 | 0,8 s | Drinking a healing potion, glass vial uncork, gulp and a warm magical shimmer |
| `globo_vita` | 2 | 0,5 s | Picking up a health orb, soft warm magical chime and heartbeat |
| `livello` | 1 | 2,0 s | Level up, triumphant golden magical swell with choir and brass hit |

### A5. Nemici
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `umano_attacco` | 3 | 0,5 s | Male enemy warrior attack grunt with a weapon swing |
| `umano_morte` | 3 | 0,8 s | Male enemy warrior death scream, short |
| `lupo_attacco` | 2 | 0,5 s | Wolf snarling and biting |
| `lupo_morte` | 2 | 0,8 s | Wolf whimper and death yelp |
| `macchina_attacco` | 2 | 0,5 s | Robot automaton attacking, servo motors whir and metal strike |
| `macchina_morte` | 2 | 1,0 s | Robot automaton destroyed, electric sparks, power down and metal parts falling |
| `spettro_attacco` | 2 | 0,6 s | Ghostly undead spirit attack, eerie hiss and whisper |
| `spettro_morte` | 2 | 1,0 s | Undead spirit dissolving, fading ghostly wail |
| `granchio_attacco` | 2 | 0,5 s | Giant crab claws snapping, chitin clicking |
| `granchio_morte` | 2 | 0,8 s | Giant crab dying, shell cracking and wet squelch |
| `proiettile_nemico` | 2 | 0,4 s | Enemy firing a sling stone or plasma shot, short whoosh |
| `boss_ruggito` | 2 | 2,0 s | Huge boss monster roar, terrifying and echoing |
| `boss_attacco` | 2 | 1,0 s | Boss special attack, massive magical blast building up |

### A6. Mondo
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `forziere` | 2 | 1,0 s | Heavy wooden chest with bronze fittings opening, creak and clink of treasure |
| `rottura` | 4 | 0,6 s | Clay amphora or wooden crate breaking, shattering and splintering |
| `altare` | 1 | 2,0 s | Ancient altar activated, deep resonant hum and choir swell |
| `santuario` | 1 | 1,5 s | Shrine blessing, bright magical chime and power-up swell |
| `portale` | 1 | 1,5 s | Magical portal opening, swirling energy vortex whoosh |
| `ingresso_dungeon` | 1 | 1,5 s | Entering a dark underground dungeon, heavy stone door grinding and echo |
| `cancello` | 1 | 2,0 s | Large city gate opening, heavy iron and wood creaking |
| `evento_inizio` | 1 | 1,5 s | Danger alert in battle, ominous horn blast |
| `evento_fine` | 1 | 1,5 s | Event completed, short triumphant brass fanfare |
| `missione_nuova` | 1 | 1,0 s | New quest received, parchment unroll and soft chime |
| `missione_compiuta` | 1 | 2,0 s | Quest completed, triumphant fanfare with choir |
| `ricompensa` | 1 | 1,2 s | Reward received, coins pouring and bright chime |
| `guardiano` | 1 | 2,0 s | Powerful guardian boss appearing, dark magical rumble and roar |

### A7. Bottino
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `monete` | 3 | 0,4 s | Picking up a few gold and bronze coins, bright jingle |
| `raccogli` | 3 | 0,3 s | Picking up an item, leather and metal rustle |
| `gemma` | 2 | 0,5 s | Picking up a gemstone, crystal clink and sparkle |
| `drop_raro` | 1 | 1,0 s | Rare item dropped on the ground, golden chime |
| `drop_leggendario` | 1 | 2,0 s | Legendary item dropped, powerful orange magical beam with choir and deep impact |

### A8. Città e interfaccia
| File | Versioni | Durata | Testo |
|---|---|---|---|
| `npc_saluto` | 3 | 0,6 s | Short friendly murmur of a townsperson greeting, no words |
| `monete_borsa` | 2 | 0,6 s | Coin purse transaction, coins counted and pouch closed |
| `fabbro` | 2 | 1,0 s | Blacksmith hammering on an anvil, metallic clang with sparks |
| `smonta` | 2 | 0,8 s | Dismantling an item, metal parts unscrewed and breaking apart |
| `incastona` | 2 | 0,6 s | Gem set into jewelry, crystal click and soft chime |
| `potenziamento_ok` | 1 | 1,0 s | Upgrade succeeded, bright rising magical chime |
| `potenziamento_fallito` | 1 | 0,8 s | Upgrade failed, dull thud and fading sparkle |
| `clic` | 2 | 0,1 s | Interface button click, soft metallic tick |
| `zaino` | 2 | 0,5 s | Opening a leather backpack, leather and buckle rustle |
| `equipaggia` | 3 | 0,4 s | Equipping armor or weapon, metal and leather clank |
| `errore` | 1 | 0,3 s | Action not possible, short low muted thud |

---

## B. Ambienti in loop — `audio/ambience/` (stereo, 30-60 s, che si ripetono senza stacco)

Testo comune da aggiungere: `, seamless loop ambience, no music, no voices speaking, high quality stereo field recording`.

| File | Testo |
|---|---|
| `level_01` | Mediterranean countryside at day, wind in olive trees and cypresses, cicadas, distant birds, faraway sheep |
| `ostia_nova` | Busy ancient Roman city forum, crowd murmur, distant hammering, fountains, occasional low hum of floating machines |
| `level_03_porto` | Ancient harbor at night, waves against wooden docks, creaking ships, seagulls, distant electric hum of a lighthouse |
| `dungeon_catacombe` | Underground catacombs, dripping water, low wind through tunnels, distant crackling torches |
| `dungeon_caverne_clan` | Damp cave, deep echoing drips, distant tribal drums, crackling bonfire |
| `dungeon_cisterne` | Ancient water cisterns, echoing drips, sloshing water, distant scuttling of crabs |
| `labirinto` | Otherworldly magical labyrinth, deep droning hum, whispers in the distance, shifting stone |

## C. Musica — `audio/music/` (stereo, strumentale, 2-3 minuti, in loop)

Testo comune da aggiungere (Suno/Udio, modalità **instrumental**):
`, instrumental, dark epic orchestral soundtrack for an action RPG, ancient Rome meets science fiction, Roman brass (cornu, tuba), frame drums, low male choir, subtle synth pads, seamless loop`

| File | Quando | Testo |
|---|---|---|
| `menu` | menu principale | Majestic and melancholic main theme, slow build, solo duduk then full orchestra and choir, sense of an eternal empire |
| `level_01` | Campagna di Lazio Prime | Pastoral but tense exploration, lyre and flute over low strings, light percussion, distant threat |
| `ostia_nova` | città | Calm city hub theme, harp and lyre, warm strings, soft synth pads, safe and welcoming |
| `level_03_porto` | porto | Mysterious nocturnal harbor exploration, low strings, tribal percussion, sea-faring motifs, synth pulses |
| `dungeon` | tutti i dungeon (o `dungeon_catacombe`, `dungeon_caverne_clan`, `dungeon_cisterne` per uno solo) | Dark ambient dungeon music, deep drones, sparse percussion, eerie choir, growing tension |
| `labirinto` | Labirinti di Dedalo | Intense fast-paced combat music, driving percussion, aggressive brass ostinato, pulsing synth bass |
| `boss` | combattimento con un boss | Epic boss battle, full orchestra and choir, thundering war drums, heroic brass, very intense |

Il brano del boss parte da solo quando compare la barra del boss e, finito lo scontro, si torna alla musica del luogo.

---

## Dopo averli generati
1. Taglia il silenzio, normalizza, converti in `.ogg` (anche Audacity va bene), nomi esatti (con `_1`, `_2`... per le versioni).
2. Mettili nelle cartelle `audio/sfx/`, `audio/ambience/`, `audio/music/`.
3. Avvisa Claude: controlla che i nomi siano giusti (`tools/test_audio.gd`) e bilancia i volumi in `data/sound_db.gd`.
