# Testi per generare la grafica 2D che manca

**Fatte e collegate (20-11-2026)**: tutte le 74 immagini (test `tools/test_grafica.gd`). Dettagli in CLAUDE.md, "Grafica 2D".

Dopo effetti (`docs/TEXTURE_AI.md`) e icone delle abilità (`docs/ICONE_AI.md`) restano tre gruppi:

| Parte | Cosa | Quante | Priorità |
|---|---|---|---|
| A | Icone degli oggetti (zaino, negozi, forziere) | 49 | alta |
| B | Texture del terreno e dei dungeon | 15 | media (meglio quando arrivano i primi modelli Tripo) |
| C | Interfaccia: icona dell'app, sfondo del menu, schermate di caricamento, cornici, globi | 10 | C1 alta, il resto bassa |

Personaggi, nemici, oggetti di scena ed edifici **non** servono: i modelli Tripo hanno già le loro texture.
I testi sono **in inglese**. Quando le immagini sono pronte, avvisa Claude: le collega al gioco.

---

## A. Icone degli oggetti — 49 immagini

### Regole
- Stesso set **"Grafite e braci"** delle abilità: usa 2-3 icone di `textures/icone/abilita/` come **riferimento di
  stile** (Midjourney `--sref`, image_gen/ChatGPT: allega l'immagine e scrivi "same style as the reference").
- **Sfondo trasparente** (PNG con alfa) se il generatore lo permette, altrimenti **nero uniforme**: la casella dello
  zaino ha già il colore della rarità dietro.
- **Senza tinte di rarità o di classe** sull'oggetto: colori naturali (bronzo, acciaio, cuoio, oro). Rarità, leggendari
  e set li colora il gioco (bordo e bagliore), così una sola icona serve per tutte le rarità.
- **Armi = metallo avvolto dall'energia** (direzione artistica, `docs/GAME_DESIGN.md`): lama di metallo con un
  alone di energia **azzurra** (il colore base dell'energia nel gioco).
- Oggetto **intero, unico, centrato, inclinato a 45°** (armi in diagonale, dal basso a sinistra all'alto a destra),
  con un po' di margine. Niente mani, niente persone, niente scritte, niente cornici.
- Quadrate, ridotte a **256 × 256**.

### Stile (da aggiungere DOPO ogni soggetto)
> , game inventory item icon, single object, ancient Roman empire in the year 3000, graphite and embers painterly style, dark smoky charcoal atmosphere with warm ember glow on the edges, dramatic rim light, strong readable silhouette, centered, transparent background, no frame, no border, no text, no hands, square

### File
`textures/icone/oggetti/<id>.png` (l'id è quello della tabella, uguale al codice).

#### Armi — `arma`
| `id` | Nome nel gioco | Soggetto |
|---|---|---|
| `gladio_plasma` | Gladio al plasma | A short Roman gladius, steel blade wrapped in a thin aura of cyan energy, bronze crossguard, leather grip |
| `spatha` | Spatha a vibrazione | A long Roman spatha sword, steel blade humming with a cyan energy aura and faint vibration lines |
| `scure` | Scure da arena | A heavy one-handed battle axe, steel head with cyan energy along the edge, wooden haft wrapped in leather |
| `arco_plasma` | Arco al plasma | A recurve bow of dark wood and bronze, with a glowing string of cyan plasma |
| `manuballista` | Manuballista a rotaia | A Roman hand crossbow with a metal rail along the stock, cyan energy charge in the groove |
| `lituo` | Lituo augurale | A Roman augur's curved staff (lituus) of dark wood, golden spiral top with a small glowing blue crystal |
| `bastone_giove` | Bastone di Giove | A tall staff of dark wood and gold topped by a large crystal sphere crackling with lightning |

#### Mano secondaria — `secondaria`
| `id` | Nome | Soggetto |
|---|---|---|
| `scutum` | Scutum a campo di forza | A curved rectangular Roman legionary shield, red with a golden eagle emblem, edges glowing with a cyan force field |
| `parma` | Parma rotonda | A round bronze Roman shield with a central iron boss |
| `pugio` | Pugio | A Roman dagger (pugio), short steel blade with a faint cyan energy edge, ornate bronze hilt |
| `faretra` | Faretra energetica | A leather quiver on its side, glowing cyan energy cells instead of arrows |
| `sfera_oracolo` | Sfera oracolare | A crystal orb on a small golden stand, swirling violet mist inside |

#### Elmi — `elmo`
| `id` | Nome | Soggetto |
|---|---|---|
| `galea` | Galea | A Roman legionary helmet (galea) of polished iron with cheek guards and a short red crest |
| `elmo_centurione` | Elmo da centurione | A Roman centurion helmet with a tall transverse red crest, bronze and steel, ornate |
| `cappuccio` | Cappuccio augurale | A hooded augur's cowl of pale cloth with golden embroidered edge and a small laurel clasp |

#### Armature — `armatura`
| `id` | Nome | Soggetto |
|---|---|---|
| `lorica` | Lorica segmentata | Roman segmented plate armor (lorica segmentata), steel bands with bronze fittings, seen from the front |
| `lorica_hamata` | Lorica hamata | Roman chainmail shirt (lorica hamata) with shoulder doubling, iron rings |
| `toga` | Toga rinforzata | A folded reinforced Roman toga of pale cloth with a purple border and thin metal plates sewn in |

#### Spalle, guanti, cintura, bracciali
| `id` | Nome | Soggetto |
|---|---|---|
| `humeralia` | Humeralia | A pair of layered steel shoulder guards (humeralia) |
| `spallacci_bronzo` | Spallacci di bronzo | A pair of round bronze shoulder pauldrons with engraved rims |
| `manicae` | Manicae | A segmented armored arm guard (manica) of steel bands, with a gauntlet |
| `guanti_cuoio` | Guanti di cuoio sintetico | A pair of dark synthetic leather gloves with small metal studs |
| `cingulum` | Cingulum militare | A Roman military belt (cingulum) with bronze plates and hanging studded leather straps |
| `balteo` | Balteo | A leather baldric (shoulder sword belt) with a bronze buckle |
| `armillae` | Armillae | A pair of golden Roman armbands (armillae) with simple engravings |
| `bracciali_cuoio` | Bracciali di cuoio | A pair of laced leather bracers |

#### Gambe e piedi — `gambali`, `calzari`
| `id` | Nome | Soggetto |
|---|---|---|
| `ocreae` | Ocreae | A pair of bronze greaves (ocreae) shaped like shins |
| `bracae` | Bracae | A pair of folded Roman-Gallic trousers (bracae) of rough brown cloth |
| `caligae` | Caligae | A pair of Roman hobnailed military sandals (caligae) of leather straps |
| `calcei` | Calcei | A pair of closed Roman leather shoes (calcei) |

#### Gioielli — `amuleto`, `anello`
| `id` | Nome | Soggetto |
|---|---|---|
| `bulla` | Bulla | A round golden Roman amulet (bulla) on a leather cord |
| `torque` | Torque | A twisted golden neck ring (torque) with ornate ends |
| `anello_sigillo` | Anello con sigillo | A heavy golden signet ring with a carved red stone |
| `anello_ferro` | Anello di ferro | A simple iron ring with a small engraved band |

#### Gemme — `textures/icone/gemme/<tipo>.png`
Una per tipo: i 5 gradi li disegna il gioco (bordo e brillantezza).
| `tipo` | Soggetto |
|---|---|
| `rubino` | A cut ruby gemstone, deep red, faceted, glowing softly |
| `smeraldo` | A cut emerald gemstone, vivid green, faceted, glowing softly |
| `topazio` | A cut topaz gemstone, golden yellow, faceted, glowing softly |
| `ametista` | A cut amethyst gemstone, violet, faceted, glowing softly |
| `diamante` | A cut diamond gemstone, icy white-blue, faceted, glowing softly |

#### Gemme leggendarie — `textures/icone/gemme_leggendarie/<id>.png`
| `id` | Nome | Soggetto |
|---|---|---|
| `cuore_marte` | Cuore di Marte | A heart-shaped blood-red gem set in an ornate golden mount, small flames around it |
| `occhio_giano` | Occhio di Giano | A round gem with two eyes looking in opposite directions inside, silver-blue, golden mount |
| `pietra_vesta` | Pietra di Vesta | A warm amber stone with an eternal flame inside, in a round golden mount |
| `lacrima_niobe` | Lacrima di Niobe | A teardrop-shaped pale blue gem, glowing, in a delicate silver mount |
| `scintilla_vulcano` | Scintilla di Vulcano | A jagged orange gem with molten cracks, sparks flying, in a blackened iron mount |
| `dente_cerbero` | Dente di Cerbero | A curved fang-shaped dark gem with green glow, in a three-headed dog golden mount |

#### Materiali e monete — `textures/icone/materiali/<id>.png`
| `id` | Nome | Soggetto |
|---|---|---|
| `rottami` | Rottami di bronzo | A small pile of bronze scrap pieces, gears and bent plates |
| `essenza` | Essenza arcana | A small glass vial with swirling glowing blue essence |
| `frammento` | Frammento divino | A shard of glowing orange crystal with golden light inside |
| `sesterzi` | Sesterzi | A small stack of Roman bronze sesterce coins with an emperor's profile, one coin standing |

---

## B. Texture del terreno e dei dungeon — 15 immagini

### Regole
- **Ripetibili senza cuciture** (seamless/tileable: con Stable Diffusion opzione *tiling*; con image_gen scrivilo
  nel testo e controlla i bordi), **vista dall'alto perpendicolare**, **luce uniforme senza ombre**, nessun oggetto
  grande (niente alberi, sassi enormi, persone).
- **1024 × 1024** PNG. Colori naturali e non troppo saturi: il gioco può dare una leggera tinta per zona.
- Il terreno è visto da lontano (telecamera isometrica): dettagli medi, leggibili, non fotografie minute.
- File: `textures/terreno/<nome>.png`.

### Stile (da aggiungere DOPO ogni soggetto)
> , seamless tileable ground texture, top-down orthographic view, flat even lighting, no shadows, no perspective, hand-painted stylized realistic like a classic isometric action RPG, medium detail readable from a distance, square

### Mondo all'aperto
| `nome` | Zone che la usano (`data/map_zones.gd`) | Soggetto |
|---|---|---|
| `erba` | fattoria, boschetto, fiume, tempio | Lush green grass with small clover patches and a few tiny wildflowers |
| `erba_secca` | campi, bordi | Dry yellow-green grass with patches of bare earth |
| `sottobosco` | bosco | Forest floor: dark soil, fallen leaves, moss, twigs and pine needles |
| `terra_battuta` | campo (accampamento), cantieri, cantiere, relitto | Packed dirt ground with footprints, small stones and wheel ruts |
| `ghiaia` | necropoli, faro | Grey gravel and small broken stones with sparse dry weeds |
| `lastricato` | strade, città, urbe, piazzale, magazzini | Roman road paving of large irregular grey basalt polygonal stones (basoli) with dark gaps |
| `marmo_foro` | foro | Large square white and pale grey marble slabs, slightly worn, thin joints |
| `saline` | sale | Salt flats: cracked white salt crust with pale sand |
| `assi_molo` | molo | Weathered wooden harbor planks with iron nails and dark gaps between boards |
| `piastre_metallo` | spazioporto | Futuristic Roman metal floor plates with engraved meander patterns and faint glowing cyan seams |

### Dungeon (pavimento e muri)
| `nome` | Dungeon | Soggetto |
|---|---|---|
| `pavimento_catacombe` | Catacombe del Mausoleo | Ancient underground stone floor of worn square tiles with dust, bone fragments and cracks |
| `muro_catacombe` | Catacombe del Mausoleo | Catacomb wall of tuff stone blocks with burial niches outlines and old plaster, seen straight on |
| `roccia_caverna` | Caverne del Clan (pavimento e muri) | Rough dark brown cave rock with mineral veins and damp patches |
| `pavimento_cisterne` | Cisterne del Porto | Wet Roman cistern floor of opus signinum (reddish crushed brick concrete) with shallow puddles |
| `muro_cisterne` | Cisterne del Porto | Roman brick wall (opus latericium) wet and stained by water, with green algae lines, seen straight on |

L'**acqua** (porto, fiume) non serve come immagine: le onde le genera il gioco (normal map da codice).

---

## C. Interfaccia — 10 immagini

### C1. Icona dell'app — `textures/ui/icona_app.png` (1024 × 1024) — priorità alta
Serve prima di dare l'APK o l'eseguibile a qualcuno (oggi c'è quella di Godot).
> App icon for a game called Legio 3000: a Roman legionary helmet with red crest in profile, the visor glowing with cyan energy, over a dark graphite background with ember glow, bold simple shapes readable at small size, centered, no text, square, graphite and embers painterly style

Per Android serve anche la versione "adattiva" (il sistema la ritaglia a cerchio/goccia):
- `textures/ui/icona_app_primo_piano.png` (432 × 432): solo l'elmo su **sfondo trasparente**, con molto margine
  (il soggetto dentro il cerchio centrale di 264 px);
- `textures/ui/icona_app_sfondo.png` (432 × 432): solo lo sfondo grafite e braci, senza soggetto.

### C2. Sfondo del menu principale — `textures/ui/sfondo_menu.png` (1920 × 1080)
> Wide cinematic painting: the Roman port city of Ostia Nova in the year 3000 at dusk, temples and aqueducts mixed with sleek starship docks, a fleet of Roman-styled starships in the orange sky, a lone legionary on a hill in the foreground seen from behind, graphite and embers painterly style, dramatic warm light, empty dark area on the left side for the menu buttons, no text, 16:9

### C3. Schermate di caricamento — `textures/ui/caricamento_<livello>.png` (1920 × 1080)
Stile come C2, **zona scura in basso** per il nome del luogo e la barra.
| `livello` | Soggetto |
|---|---|
| `level_01` | Roman countryside villa and farmland at dawn, ruined temple on a hill, a dark forest, smoke of a barbarian camp in the distance |
| `ostia_nova` | Busy forum of a futuristic Roman city, marble temples with glowing cyan lines, merchants and legionaries |
| `level_03_porto` | Roman harbor at night with a giant lighthouse, wooden docks, warehouses and pirate ships with energy sails |
| `dungeon` | Dark underground catacomb corridor lit by torches, burial niches, glowing runes on the floor |

### C4. Cornici e globi (facoltativi: oggi li disegna il codice)
| File | Misure | Soggetto |
|---|---|---|
| `textures/ui/cornice_pannello.png` | 512 × 512 | Ornate square frame of dark bronze with Roman meander pattern and small rivets, empty dark transparent center, for a 9-slice game UI panel, flat front view, no text |
| `textures/ui/globo_cornice.png` | 512 × 512 | Ornate circular bronze frame for a health orb, Roman eagle wings on the sides, empty transparent center, flat front view, no text |
| `textures/ui/barra_abilita.png` | 1024 × 256 | Horizontal bronze and dark stone bar for a game skill bar with six square empty slots, Roman decorations, transparent background, flat front view, no text |

Stile per C4 (dopo il soggetto): `, game UI element, graphite and embers painterly style, sharp clean edges, transparent background`.

---

## Dopo averle generate
1. Riduci alle misure indicate e controlla bordi (texture ripetibili) e sfondi (trasparenti o neri uniformi).
2. Mettile nelle cartelle indicate con i nomi esatti.
3. Avvisa Claude: icone nello zaino/negozi/forziere (con il colore della rarità), terreno per zona, icona dell'app
   nel progetto e nel preset Android, sfondi nel menu e nel caricamento. Dove un file manca resta la grafica di oggi.
