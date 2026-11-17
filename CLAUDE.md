# CLAUDE.md – guida per continuare il progetto

Progetto **Legio 3000**: ARPG isometrico stile Diablo 3, Impero Romano nel 3000 d.C. Godot **4.7.2**, GDScript tipizzato.
L'utente parla **italiano**: rispondi in italiano. Commenti e testi di gioco sono in italiano.
Design e stato del gioco: `docs/GAME_DESIGN.md`. Panoramica: `README.md`.

## Regole dell'utente
- Stile Diablo 3, **niente roguelike**, livelli fatti a mano.
- Nessuna IP esistente (niente Star Wars né attori reali): tutto originale.
- Grafica in grayboxing finché non arrivano i modelli **Tripo 3D** (l'utente ha l'abbonamento); animazioni previste da **Mixamo**.
- Commit + push solo quando l'utente lo chiede.

## Godot su questo PC
- Windows: `C:\Users\Budo\Apps\Godot_v4.7.2-stable_win64.exe` (editor) e `..._console.exe` (riga di comando). Non è nel PATH.
- Linux (stesso progetto su disco condiviso): `~/Scaricati/Godot_v4.7.2-stable_linux.x86_64` (solo headless: la libX11 del sistema è troppo vecchia per aprire finestre).
- Su un altro PC chiedi all'utente dove si trova Godot 4.7.x.
- Fine riga: `.gitattributes` (`* text=auto`) normalizza a LF nel repository; Windows e Linux non vedono più modifiche fantasma.

## Struttura
```
core/       game.gd (autoload "Game": partita, salvataggi, cambio scena, viaggi), hero_data.gd, item.gd,
            abilities.gd (esecuzione abilità), loot.gd, fx.gd (materiali/effetti/particelle), sfx.gd (suoni),
            music.gd (musica dei livelli), settings.gd (opzioni video/audio/tasti), quests.gd (logica missioni), layers.gd
data/       hero_classes.gd (classi+abilità), enemy_db.gd, item_db.gd (basi, affissi, leggendari+poteri, drop,
            prezzi, materiali, ricette del fabbro), npc_db.gd (NPC e i loro dialoghi), quest_db.gd (missioni e loro testi),
            map_zones.gd (zone del terreno: colore, bordo, vegetazione sparsa)
entities/   player.gd, enemy.gd, npc.gd, projectile.gd, loot_drop.gd, health_globe.gd
world/      level.gd (script radice dei livelli), iso_camera.gd, occlusion_fader.gd, encounter_zone.gd (@tool),
            chest.gd, breakable.gd, checkpoint.gd (altare + viaggio rapido), level_exit.gd, lore_sign.gd, town_portal.gd,
            stash.gd (forziere personale), quest_gate.gd (cancello che si apre con un flag di missione),
            map_shape.gd / map_road.gd / map_area.gd / map_polygon.gd (@tool: "Forma" del livello)
ui/         main_menu.gd, hud.gd, inventory_ui.gd, trade_ui.gd (mercante/fabbro/forziere), options_menu.gd,
            pause_menu.gd, minimap.gd, globe.gd, skill_slot.gd
tools/      build_world.gd (GENERATORE grayboxing: props, modelli, livello 1 + navmesh),
            build_ostia.gd / build_porto.gd (città e porto, estendono build_world.gd),
            map_builder.gd ("Ricostruisci terreno" dalla Forma + navmesh), map_preview.gd / export_maps.gd (piante PNG),
            test_ostia.gd / test_atto2.gd / test_mappa.gd (test automatici)
addons/     legio_map/ (plugin dell'editor: pannello "Mappa")
docs/       GAME_DESIGN.md, mappe/*.png (piante dall'alto dei livelli, 2 px = 1 m)
audio/      music/ e sfx/ (vuote: vedi LEGGIMI.txt; i suoni sono sintetizzati, la musica manca)
scenes/     main_menu.tscn, levels/level_01.tscn, level_02_ostia.tscn, level_03_porto.tscn (navmesh incorporata),
            props/*.tscn, characters/*.tscn, enemies/*.tscn, npcs/*.tscn
```
- Quasi tutto è **guidato dai dati** (dizionari in `data/`). Per bilanciare, cambia i numeri lì.
- UI, eroe, nemici e proiettili sono costruiti **da codice**. Livelli, oggetti di scena e modelli sono **scene .tscn** modificabili nell'editor.
- Ogni modello (classe/nemico/NPC) è una scena a parte, referenziata da `HeroClasses.DATA[..]["model"]` / `EnemyDB.DATA[..]["model"]` / `NpcDB.DATA[..]["model"]`. Per usare un modello Tripo: sostituisci il nodo `Graybox` della scena con il .glb, orientato verso **−Z**. Se il modello ha un `AnimationPlayer` con le animazioni `idle`, `run`, `attack`, `cast`, `hit`, `death`, `Player` le riproduce da solo.
- Gli oggetti di scena hanno la radice `StaticBody3D` (livello fisico 1), il gruppo `fadeable` se alti, un `OcclusionVolume` (livello 5) per le chiome/tetti e il figlio `Graybox` da sostituire.

## Livelli fisici (core/layers.gd)
1 mondo/ostacoli (genera la navmesh) · 2 giocatore · 3 nemici · 4 interagibili (clic) · 5 occlusione (trasparenza) · livello **visivo** 11 = icone della minimappa (la telecamera principale lo esclude).

## Generatore della mappa
```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_world.gd            # tutto
... --script res://tools/build_world.gd -- props    # solo oggetti di scena
... --script res://tools/build_world.gd -- models   # solo modelli personaggi/nemici
... --script res://tools/build_world.gd -- level    # solo livello 1 (+ navmesh)
... --script res://tools/build_world.gd -- missing  # solo props e modelli che non esistono ancora
... --script res://tools/build_ostia.gd             # città di Ostia Nova (+ props/modelli NPC mancanti)
... --script res://tools/build_porto.gd             # livello 3, porto (+ props/modelli mancanti)
```
- `build_ostia.gd` e `build_porto.gd` estendono `build_world.gd` (riusano `_place`, `_strip`, `_part`...) e sovrascrivono `_generate()` e `_allowed()`. Rigenerarli **sovrascrive il loro .tscn**. Nuovi props/modelli si aggiungono in `build_world.gd` (`_prop_defs`, `_model_defs`): i generatori creano solo quelli mancanti.
- Nel porto il mare è a est (`_shore_x`), i bordi sull'acqua sono ostacoli invisibili, quelli sulla terra sono `isolato`/`scogliera`.
- Il livello 1 ha anche il marker `DaOstia` e l'uscita con `target_level = "ostia_nova"`: sono già nel .tscn e nel generatore.
- È deterministico (seed 3000). **Rigenerare il livello sovrascrive `level_01.tscn`**: dopo modifiche a mano nell'editor, NON rigenerare il livello (props e modelli sì, ma attenzione: rigenerare un prop sovrascrive le sostituzioni Tripo fatte in quella scena).
- La navmesh è salvata dentro il .tscn del livello. Se sposti oggetti nell'editor: pannello Mappa → *Ricalcola solo la navmesh* (oppure nodo `World` → *Bake NavigationMesh*).
- Tutto ciò che deve bloccare il movimento o la navmesh va messo **sotto il nodo `World`** con un collider sul livello 1.
- Nuovi nemici: aggiungi un nodo con `world/encounter_zone.gd` sotto `Incontri` e impostalo dall'Inspector (nell'editor appare come disco colorato).

## Forma dei livelli e plugin Legio Map
- Ogni livello ha un nodo `Forma` (`MapShape`, fuori da `World`) con strade (`MapRoad`, Path3D), aree circolari (`MapArea`) e poligoni (`MapPolygon`, modo terra/acqua/buco). Definiscono dove si cammina, le zone del terreno (`data/map_zones.gd`) e l'acqua. In gioco la Forma si elimina da sola (`MapShape.keep_in_game = true` nei tool/test per tenerla).
- Pannello **Mappa** (plugin `addons/legio_map`, attivo in project.godot): crea Forma / aggiungi strada, area, radura, acqua, terra; **Ricostruisci terreno**; ricalcola solo la navmesh; esporta pianta PNG; inserisci oggetti di scena al centro della vista.
- **Ricostruisci terreno** (`tools/map_builder.gd`) rigenera SOLO `World/Terreno`, `Confini`, `Strade`, `Acqua`, `Vegetazione`, `ArredoStradale` e la navmesh. Luoghi (`World/Luoghi`), nemici, forzieri, altari, NPC restano dove sono; il resoconto segnala quelli rimasti fuori dall'area calpestabile. Stessa forma + stesso seme = stesso risultato.
- La strada principale è quella con `zone_breaks` (zone lungo il percorso, es. `"0.17=bosco"`).
- Piante di tutti i livelli: `--headless --path . --script res://tools/export_maps.gd` → `docs/mappe/*.png`.

## Collegare i livelli
- `Game.LEVELS` (id → scena) e `Game.LEVEL_TITLES` (id → nome, anche ordine nell'elenco altari). `Game.HUB` = città del portale.
- `Game.travel(level_id, spawn, pos)`: `spawn` = nome di un Marker3D del livello o id di un altare; `pos` = posizione esatta.
- `LevelExit`: `target_level` + `target_spawn`. Senza target mostra il pannello di fine livello (comportamento vecchio).
- Ogni altare (`Checkpoint`) registra `hero.waypoints[id] = {level, title}` e `flags["cp_last_<livello>"]` (rinascita per livello).
- Nel nodo radice: `is_town` (città: portale di ritorno) e `intro_text` (mostrato alla prima visita).

## Missioni (data/quest_db.gd, core/quests.gd)
- Obiettivi in sequenza: kill, kill_unique, enter, altar, talk, salvage, chest. Eventi inviati con `Quests.notify(tipo, bersaglio)`.
- Gli NPC prima provano `Quests.talk(npc_id)` (consegna/affida), poi aprono negozio/dialogo. Segni "!" / "?" sopra la testa.
- `Game.quests_changed` aggiorna HUD (elenco a sinistra, diario J), segni degli NPC e `QuestGate`.
- Missioni senza `giver` partono da sole (`Quests.start_automatic`, a ogni ingresso in un livello). Obiettivi già fatti in passato vengono saltati (`_check_already`).
- Il cancello nord di Ostia Nova (`QuestGate`, fuori dal nodo World) si apre col flag `porto_aperto` (missione "Il porto sbarrato").

## Insidie note (importante)
- **GDScript tipizzato**: `var x := dict["k"]` è un errore di compilazione ("Cannot infer the type"). Usa `var x: float = ...` oppure `float(...)`.
- Script lanciati con `--script` (tool/test headless): le classi che citano l'autoload `Game` **non compilano** se sono referenziate staticamente dallo script principale (vengono compilate prima che esista l'autoload). Nei tool/test usa `load("res://...").new()` e variabili non tipizzate. Nel gioco normale non è un problema.
- Le operazioni che richiedono l'albero di scena (bake della navmesh) vanno fatte nel primo `_process`, non in `_initialize`.
- I personaggi si muovono a y = 0 (niente gravità). Il terreno è piatto e il mouse usa il piano y = 0.
- La navmesh ha "isole" sopra gli oggetti alti: `Player.snap_to_nav` scarta i punti con y > 0.
- `Item` usa `item_name` (non `name`).
- La superficie della navmesh è a **y = 0.5** (non 0); le "isole" sopra gli oggetti da 2 m in su. Le soglie sono a 1.0.
- Gli script dei nodi girano anche nei generatori (es. `Npc._ready`): non modificare lì proprietà salvate nella scena (rotazione, posizione), altrimenti finiscono nel .tscn.
- Timer con lambda: usa `nodo.create_tween().tween_callback(...).set_delay(t)` invece di `get_tree().create_timer()`, così il callback non parte se il nodo sparisce cambiando livello.
- `Sfx.play` / `Music.play` non fanno nulla in headless; `DisplayServer.keyboard_get_keycode_from_physical` non è supportato in headless.
- Godot 4.7 limita la ricerca dei percorsi a **4096 poligoni** (`path_search_max_polygons`); il livello 1 ne ha circa 6300. Per i clic del giocatore basta, ma nei test su percorsi lunghi usa `path_search_max_polygons = 0`.
- Navmesh ricostruita più volte a runtime in uno script `--script`: con le iterazioni asincrone (predefinite) la mappa di navigazione non si sincronizza più. Nei test spegnile con `NavigationServer3D.region_set_use_async_iterations(rid, false)` e `map_set_use_async_iterations(map, false)` (vedi test_mappa.gd).
- I nemici bloccano fisicamente l'eroe: nei test che camminano tra i nemici bisogna "combattere" (vedi `_walk_to(..., fight)` in test_atto2.gd).

## Test
- Controllo veloce di compilazione: `--headless --import --path .`
- **`tools/test_ostia.gd`** (41 controlli): `--headless --path . --fixed-fps 60 --script res://tools/test_ostia.gd`. Uscita del livello 1 → città, NPC, altare, mercante (compra/vendi/riacquista), fabbro (smonta/forgia), poteri leggendari, viaggio rapido, portale, salvataggio. Usa e cancella lo slot 3.
- **`tools/test_atto2.gd`** (53 controlli): missioni dell'atto 1 e 2, segni degli NPC, cancello, forziere personale, porto percorso a piedi fino al faro, Vulso e rinforzi, portale, diario, rimappatura tasti, salvataggio. Ripristina il forziere personale vero.
- **`tools/test_mappa.gd`** (13 controlli): Forma e "Ricostruisci terreno" su una copia in memoria del porto (non salva nulla): ricostruzione ripetibile, luoghi/nemici intatti, nuova area raggiungibile a piedi, strada spostata, pianta PNG.
- Lo stesso schema (imposta `Game.hero`, `Game.travel(...)`, guida il `Player` con move_target/interact_target/_try_cast) serve per altri test. `--fixed-fps 60` fa girare il tempo di gioco più veloce del tempo reale.

## Stato (17-11-2026)
Fatto: menu + 3 slot di salvataggio, 4 classi complete, loot/equipaggiamento/inventario, nemici a zone con navmesh e RVO, elite e boss, grafica stile D3 (trasparenza, minimappa, HUD a globi), livello 1 in grayboxing (circa 1150 m).
Fatto il 16-11: città-hub Ostia Nova (livello 2) con 11 NPC, mercante e fabbro (sesterzi, materiali, forgia), 12 leggendari con poteri, viaggio rapido dagli altari, portale cittadino (T), particelle ed effetti sonori sintetizzati, volume nel menu di pausa, salvataggi versione 2 (compatibili con i vecchi).
Fatto il 16-11 (2): missioni (6, atti 1-2) con diario e segni sugli NPC, livello 3 "Porto di Ostia Nova" (circa 560 m, 20 zone, boss Vulso il Corsaro che chiama rinforzi, 5 nuovi nemici), forziere personale condiviso, opzioni (video, audio, rimappatura tasti) dal menu principale e dalla pausa, aggancio per la musica.
Fatto il 17-11: Forma dei livelli modificabile nell'editor (strade, aree, acqua) + plugin Legio Map (pannello Mappa, Ricostruisci terreno, piante PNG); i tre generatori usano la Forma.
Da fare: trama (testi in `data/quest_db.gd` e `data/npc_db.gd`, segnaposto `[TRAMA]`), musica e suoni veri, modelli Tripo, gemme/set, atto 3, bilanciamento.
