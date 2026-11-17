# CLAUDE.md – guida per continuare il progetto

Progetto **Legio 3000**: ARPG isometrico stile Diablo 3, Impero Romano nel 3000 d.C. Godot **4.7.2**, GDScript tipizzato.
L'utente parla **italiano**: rispondi in italiano. Commenti e testi di gioco sono in italiano.
Design e stato del gioco: `docs/GAME_DESIGN.md`. Panoramica: `README.md`.

## Regole dell'utente
- Stile Diablo 3, **niente roguelike**. Le **mappe** (livelli all'aperto, città) sono **fatte a mano**; i **dungeon** sono **procedurali**, con seme fisso (stessa mappa ogni volta).
- Lavora sempre sul branch **main** (niente branch nuovi).
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
            music.gd (musica dei livelli), settings.gd (opzioni video/audio/tasti), quests.gd (logica missioni), layers.gd,
            appearance.gd (pezzi dell'equipaggiamento nelle prese del modello), bounties.gd (taglie)
data/       hero_classes.gd (classi+abilità), enemy_db.gd, item_db.gd (basi, affissi, leggendari+poteri, drop,
            prezzi, materiali, ricette del fabbro, gemme, set), npc_db.gd (NPC e i loro dialoghi), quest_db.gd (missioni e loro testi),
            map_zones.gd (zone del terreno: colore, bordo, vegetazione sparsa), dungeon_db.gd (dungeon generati),
            world_db.gd (santuari, piloni, eventi, taglie), visual_db.gd (aspetto dell'equipaggiamento indossato), skill_db.gd (abilità alternative, varianti,
            passive, leggendari che cambiano le abilità), difficulty_db.gd (difficoltà e Labirinti di Dedalo)
entities/   player.gd, enemy.gd (+ affissi delle elite), npc.gd, projectile.gd, loot_drop.gd, health_globe.gd,
            hazard.gd (pozze di fuoco / sfere di ghiaccio / esplosioni delle elite)
world/      level.gd (script radice dei livelli), iso_camera.gd, occlusion_fader.gd, encounter_zone.gd (@tool),
            chest.gd, breakable.gd, checkpoint.gd (altare + viaggio rapido), level_exit.gd, lore_sign.gd, town_portal.gd,
            stash.gd (forziere personale), quest_gate.gd (cancello che si apre con un flag di missione),
            map_shape.gd / map_road.gd / map_area.gd / map_polygon.gd (@tool: "Forma" del livello),
            dungeon_gen.gd (pianta procedurale), dungeon_level.gd (livello dungeon + Labirinti), dungeon_entrance.gd (entrata),
            rift_obelisk.gd (Obelisco di Dedalo, in città), bounty_board.gd (Tabula delle taglie, in città),
            shrine.gd (santuari / piloni), world_event.gd (eventi casuali)
ui/         main_menu.gd, hud.gd, inventory_ui.gd, trade_ui.gd (mercante/fabbro+gioielliere/forziere), options_menu.gd,
            pause_menu.gd (+ difficoltà), minimap.gd, map_overlay.gd (nebbia di guerra + segnalini missioni), globe.gd,
            skill_slot.gd, skills_ui.gd (finestra Abilità, K), character_preview.gd (eroe 3D nello zaino)
tools/      build_world.gd (GENERATORE grayboxing: props, modelli, livello 1 + navmesh),
            build_ostia.gd / build_porto.gd (città e porto, estendono build_world.gd),
            map_builder.gd ("Ricostruisci terreno" dalla Forma + navmesh), map_preview.gd / export_maps.gd (piante PNG),
            export_dungeons.gd (piante PNG dei dungeon, anche per provare altri semi),
            test_ostia.gd / test_atto2.gd / test_mappa.gd / test_gemme_set.gd / test_dungeon.gd /
            test_equipaggiamento.gd / test_endgame.gd / test_interfaccia.gd / test_avventura.gd (test automatici)
addons/     legio_map/ (plugin dell'editor: pannello "Mappa")
docs/       GAME_DESIGN.md, PIANO_EQUIPAGGIAMENTO.md (pezzi agganciati alle ossa), mappe/*.png (piante dall'alto dei livelli, 2 px = 1 m)
audio/      music/ e sfx/ (vuote: vedi LEGGIMI.txt; i suoni sono sintetizzati, la musica manca)
scenes/     main_menu.tscn, levels/level_01.tscn, level_02_ostia.tscn, level_03_porto.tscn (navmesh incorporata),
            levels/dungeon.tscn (vuota: il dungeon si costruisce da codice al caricamento),
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
... --script res://tools/build_world.gd -- characters  # solo i corpi degli eroi (8 scene)
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
- Foglio Excel con tutti i dati (classi, abilità, varianti, oggetti, nemici, boss, difficoltà, labirinti...): `docs/Legio3000_dati.xlsx`. Si rigenera con `--script res://tools/export_dati.gd` (→ `user://dati.json`) e poi `python3 tools/export_excel.py <dati.json> docs/Legio3000_dati.xlsx`.

## Collegare i livelli
- `Game.LEVELS` (id → scena) e `Game.LEVEL_TITLES` (id → nome, anche ordine nell'elenco altari). `Game.HUB` = città del portale.
- `Game.travel(level_id, spawn, pos)`: `spawn` = nome di un Marker3D del livello o id di un altare; `pos` = posizione esatta.
- `LevelExit`: `target_level` + `target_spawn`. Senza target mostra il pannello di fine livello (comportamento vecchio).
- Ogni altare (`Checkpoint`) registra `hero.waypoints[id] = {level, title}` e `flags["cp_last_<livello>"]` (rinascita per livello).
- Nel nodo radice: `is_town` (città: portale di ritorno) e `intro_text` (mostrato alla prima visita).

## Gemme e set (data/item_db.gd)
- **Rarità Set** = `Item.Rarity.SET` (4, verde). `ItemDB.SETS`: 4 set (uno per classe) da 4 pezzi, bonus a 2/3/4 pezzi. `"stats"` si sommano in `HeroData.compute_stats`, `"skills"` = +% danni per id abilità (`Player.skill_bonus`, applicato in `Abilities.hit_enemy`). Un leggendario ha il 35% (`SET_CHANCE`) di uscire come pezzo di set (anche dal fabbro).
- **Gemme**: chiave `"tipo:grado"` (es. `"rubino:2"`, gradi 1-5). Stanno nel sacchetto `hero.gems` (non nello zaino), si raccolgono passandoci sopra (`LootDrop.make_gem`). Effetto per categoria (arma / elmo / altro) in `ItemDB.GEMS`, × `GEM_TIER_MULT`.
- **Orbite**: `item.gems` (array, "" = vuota). Tirate in `ItemDB._build` (`MAX_SOCKETS` per slot, `SOCKET_CHANCE` per rarità). `Item.stat_totals()` e `compute_stats` includono le gemme.
- **Gioielliere**: scheda del pannello del fabbro (`TradeUI._build_jeweler`): combina 3→1 (`combine_gem`), incastona (`socket_gem`), togli a pagamento (`unsocket_gem`).

## Dungeon generati (data/dungeon_db.gd, world/dungeon_*.gd)
- `DungeonGen.generate(cfg, seme)`: stanze + corridoi su griglia, anelli extra, partenza = stanza 0, boss = stanza più lontana a piedi. Stili: `"stanze"` (rettangoli, corridoi a L) e `"caverna"` (grotte irregolari, gallerie tortuose). Tipi di stanza (`kinds`): partenza, boss, normale, `colonne`, `cripta`, `tesoro` (pesi in `room_kinds`). Usa solo il suo `RandomNumberGenerator`: **stesso seme = stessa mappa** (`fingerprint()` per confrontare). Non crea nodi.
- `DungeonLevel` (estende `Level`, scena `scenes/levels/dungeon.tscn`, id livello `"dungeon"`): costruisce pavimento, muri (bassi sul lato sud, verso la telecamera), torce, props, forzieri, zone nemiche (boss unico nella stanza più lontana), scala di uscita, e fa il bake della navmesh al caricamento.
- Dungeon: **Catacombe del Mausoleo** (livello 1, `World/Luoghi/Mausoleo/IngressoCatacombe`, boss `custode`), **Caverne del Clan** (livello 1, `World/Luoghi/AccampamentoBarbaro/IngressoCaverne`, stile caverna, boss `tharvo`), **Cisterne del Porto** (livello 3, `World/Luoghi/Magazzini/IngressoCisterne`, sale a colonne, boss `madre_granchi`). I boss riusano modelli esistenti ingranditi (`model_scale` in EnemyDB).
- Entrata: prop `ingresso_catacombe` (`DungeonEntrance`, `dungeon_id`); è anche nei generatori dei livelli. Scrive `hero.flags["dungeon"] = {id, return_level, x, z}`; l'uscita del dungeon riporta davanti all'entrata. Salvare dentro il dungeon funziona (stessa mappa al ricaricamento).
- Nuovo dungeon: aggiungi una voce in `DungeonDB.DUNGEONS` (con `"entrance"` per il test) e piazza un `ingresso_catacombe` con quel `dungeon_id` (nell'editor, poi ricalcola la navmesh). Gli oggetti nelle stanze vanno solo su celle con tutte le vicine di pavimento (`is_open`). Per scegliere il seme: `--script res://tools/export_dungeons.gd -- <seme>` → `docs/mappe/dungeon_<id>_seme<seme>.png`.
- Nemici, forzieri e props ricompaiono a ogni ingresso; il boss (`custode`) è unico per partita come gli altri boss.

## Equipaggiamento visibile (data/visual_db.gd, core/appearance.gd)
- Piano completo: `docs/PIANO_EQUIPAGGIAMENTO.md`. Decisioni: **2 corpi per classe** (M/F, `HeroClasses` `"model"` / `"model_f"`), sesso scelto alla creazione (`HeroData.sex`, `model_path()`), stile D3 realistico ma non esagerato.
- I corpi (`scenes/characters/<classe>[_f].tscn`) NON hanno armi né armature: hanno il nodo `Prese` con 12 prese (`VisualDB.PRESE`, Marker3D; col modello vero diventano BoneAttachment3D con lo stesso nome). Le parti con metadato `body_part` (es. `Capelli`) possono essere nascoste da un pezzo (`"hide"`).
- `VisualDB.VISUALS[base_id]`: `"parts"` graybox (presa, forma, posizione, misure, materiale) oppure `"scene"` + `"socket"` (+ `"mirror"`) per il pezzo vero. Gioielli invisibili. Leggendari/set: tinta del colore di rarità + bagliore.
- `Appearance.apply(model, equipment)` è richiamato da `Player.refresh_stats()` (quindi a ogni cambio di equipaggiamento). Riapplicare non duplica.
- Nuova base in `ItemDB.BASES` → aggiungi la sua voce in `VISUALS` (il test lo controlla).

## Abilità, varianti e passive (data/skill_db.gd)
- Abilità base in `HeroClasses.DATA[..]["abilities"]`, alternative in `SkillDB.EXTRA`. Il campo `"slot"` dell'abilità è il suo **gruppo**: "lmb" (primarie), "rmb" (secondarie), "1".."4" (tattiche, vanno su qualunque tasto 1-4). `SkillDB.pool_for_slot`.
- `HeroData.skills` = tasto -> {id, rune}; `HeroData.passives` = 3 caselle (`PASSIVE_SLOTS` 10/20/30). `set_skill` / `set_passive` controllano livelli e gruppi (la stessa abilità su un altro tasto viene scambiata).
- `Player.abilities[tasto]` = `SkillDB.resolve(...)`: copia dell'abilità + variante (`"mods"` sostituisce, `"add"` somma, `"mul"` moltiplica) + leggendari di `SkillDB.POWER_MODS`. Rifatta da `rebuild_abilities()` (anche in `refresh_stats`), segnale `abilities_changed` (HUD).
- Il cooldown e i bonus dei set sono per **id dell'abilità** (non per tasto).
- Chiavi di effetto nuove (core/abilities.gd): `dot`/`dot_time`, `stun`, `heal_hit`, `gain_hit`, `pull`, `echo`, `self_buff`, `crit_bonus`; buff `move` (velocità) e `crit`. `Enemy.apply_stun` / `apply_dot`.
- Passive con `"stats"` (anche `armor_pct`, `life_pct`, `dr_pct`, `resource_regen_pct`, `resource_regen_flat`) in `compute_stats`; quelle `"special"` con `has_passive(id)` in player.gd/abilities.gd.

## Elite, difficoltà, Labirinti (data/enemy_db.gd, data/difficulty_db.gd)
- `EncounterZone.spawn()` con `elite`: 50% Campioni (tutti elite, stessi affissi) / 50% capo raro (`Enemy.rare`, giallo) + servitori normali (+2). Numero di affissi = `Game.enemy_scaling()["affixes"]`. Comportamento affissi in `Enemy._tick_affixes`, `take_damage`, `_hit_player`, `_die`.
- `Game.enemy_scaling()`: difficoltà dell'eroe (`HeroData.difficulty`, menu di pausa) oppure, se `Level.rift_grade > 0`, il grado del labirinto. Applicato in `Enemy._init_stats` (vita, danni, livello minimo = eroe da Esperto in su), `xp_value`, `Loot.drop` (sesterzi, `leg` → `ItemDB.roll_rarity(source, leg_mult)`).
- Labirinti: `RiftObelisk.start(grado)` scrive `flags["dungeon"] = {id "labirinto", rift, seed, return_level, x, z}`; `DungeonLevel` usa `DifficultyDB.rift_config` (seme nuovo a ogni tentativo: è l'endgame, la campagna resta a seme fisso). `on_enemy_died` riempie la barra, `_spawn_guardian`, `_complete_rift` (sblocca `flags["rift_max"]`, uscita "UscitaLabirinto"). Nei labirinti i boss non segnano `unique_<id>` né le missioni.
- L'Obelisco (`World/Luoghi/Foro/ObeliscoDedalo` in Ostia Nova, anche in build_ostia.gd) è solo sul livello "interagibile": non tocca la navmesh.

## Interfaccia e controller
- Finestra Abilità `SkillsUI` (azione `skills`, K). Zaino: `sort_bag`, statistiche dettagliate, `CharacterPreview` (SubViewport con mondo proprio). Mercante: `TradeUI.sell_all_up_to`. Forziere: schede (`Game.stash_tabs`, `STASH_TAB_PRICES`, file `{tabs, items}`; il formato vecchio ad array si legge ancora). Fabbro, scheda Aspetto: `HeroData.transmog`/`dyes`/`looks`, `TradeUI.set_look`/`set_dye`, `Appearance.apply(model, equipment, transmog, dyes)`.
- `MapOverlay` (figlio della minimappa): nebbia (`hero.flags["fog"][livello]`, celle da 8 m, niente in città, non salvata nei labirinti) e segnalini delle missioni (`quest_marks`).
- `Settings.loot_filter`, `always_show_items`, `damage_numbers`, `colorblind` (lettera della rarità), `ui_scale` (`content_scale_factor`) in Opzioni > Gioco (sezione `gameplay` di settings.cfg); azione `show_items` (Alt).
- Mappa grande (TAB): pannello laterale con legenda, altari (viaggio rapido) e dungeon della zona (`Minimap._build_side`). Oggetti nuovi (`Item.is_new`, stellina, si toglie passandoci sopra); Shift sul tooltip = confronto completo. Riepilogo alla morte. Record dei labirinti (`flags["rift_records"]`) nell'obelisco. Slot del menu con difficoltà, grado, hardcore. Suggerimenti dei primi minuti: `Hud.hint(id, testo)` (una volta per eroe, `flags["hint_<id>"]`).
- Col controller la barra mostra i pulsanti (`Hud.PAD_KEYS`); nei pannelli di mercante/fabbro/forziere A = clic (`TradeUI._pad_click`).
- Schermata di caricamento: `Game.go_to_level` la mostra e carica dopo 2 frame (tree in pausa); `Level._ready` chiama `Game.hide_loading`. Game ha `process_mode = ALWAYS`.
- Controller: eventi joypad aggiunti alle azioni in project.godot + azione `pad_primary` (A). `Player.using_pad`, `pad_aim()` (mira automatica), `_pad_primary()`. Con un pannello a fuoco il controller naviga i pulsanti e non muove l'eroe. `Settings.rebind` cambia tasto/mouse tenendo i pulsanti del controller.

## Slot, tipi di danno, gemme leggendarie
- 13 caselle (`HeroData.EQUIP_SLOTS`): in più spalle, cintura, bracciali, `anello2` (secondo anello, oggetti con slot "anello"). `ITEM_SLOTS` = tipi di oggetto (per il fabbro). `target_slot(it, alt)` / `equip_from_inventory(i, alt)`: Ctrl+clic = casella secondaria. **Doppia arma**: il Gladiatore (offhands con "gladio", "ascia") tiene un'arma in "secondaria" (+50% danni dell'arma come il pugio, +15% velocità); `Appearance` la mette nella mano sinistra.
- Tipi di danno `ItemDB.ELEMENTS` (fisico, fuoco, freddo, fulmine): `SkillDB.ELEMENTS` / `RUNE_ELEMENTS` → `ab["element"]`; affissi `<tipo>_pct`; il freddo rallenta; colore dei numeri di danno.
- Gemme leggendarie `ItemDB.LEGENDARY_GEMS`, chiave `"leg:<id>:<grado>"`, solo in amuleto/anelli; quelle con "stat" passano da `gem_affix`, le altre in player.gd (`legendary_gem_rank`, `special_damage_mult`, `on_damage_dealt`). Dal Guardiano (sempre la prima, poi 40%); dopo un labirinto in tempo 3 tentativi di potenziamento (`DungeonLevel.offer_gem_upgrade`, `leg_gem_upgrade_chance`).

## Mondo vivo, taglie, boss, hardcore
- Santuari (`WorldDB.SHRINES`, 120 s) e piloni (`PYLONS`, solo labirinti): `Shrine`, buff con chiavi nuove `xp`, `fortune`, `channel` (e "name" per la lista sopra la barra). Eventi (`WorldDB.EVENTS`: maledetto, assedio, prigionieri): `WorldEvent`. Nelle mappe all'aperto `Level._place_world_extras` li mette a ogni visita vicino a zone scelte a caso (nodo "Extra", non salvato; aspetta che la navmesh del livello sia nella mappa); nei dungeon `DungeonLevel._build_shrines`.
- Taglie: `Bounties` (core/bounties.gd), `HeroData.bounties`, Tabula in `World/Luoghi/Foro/TabulaTaglie` (anche in build_ostia.gd). Avanzano da `Enemy._die` → `Bounties.on_kill` e dagli eventi; luogo = `Bounties.level_key()`. I boss delle taglie ricompaiono (`wants_boss` in EncounterZone). Cassa del Prefetto = `claim_cache`.
- Boss: `EnemyDB.BOSSES` (attacchi nova/pioggia/onda/salto ogni 6 s, fasi a soglie: enrage, summon, shield finché vivono i rinforzi, attack:<nome>). In `Enemy`: `_check_phase`, `_boss_attack`, `_show_shield`.
- Hardcore: `HeroData.hardcore`, morte → `flags["dead"]` + salvataggio + pannello senza rinascita; slot non caricabile; forziere `user://stash_hardcore.json` (`Game._stash_path`, `_reset_stash` cambiando eroe).

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
- Tool che caricano un livello, lo mettono nell'albero e poi lo **risalvano**: imposta prima `load("res://world/map_shape.gd").keep_in_game = true`, altrimenti la `Forma` si cancella da sola e sparisce dal .tscn salvato (`test_mappa.gd` controlla che ogni livello abbia la Forma).
- I nemici bloccano fisicamente l'eroe: nei test che camminano tra i nemici bisogna "combattere" (vedi `_walk_to(..., fight)` in test_atto2.gd).
- `ResourceLoader.load_threaded_request` dei livelli si blocca a 0% in headless: per questo la schermata di caricamento usa il caricamento normale (dopo 2 frame).
- `Fx.flash` tiene in cache le mesh di un modello (`_fx_meshes`): chi aggiunge/toglie mesh a un modello (es. `Appearance.apply`) deve togliere la cache. `_apply_overlay` itera con `Variant` per non rompersi su mesh liberate.
- La mappa di navigazione del mondo resta tra un livello e l'altro: `map_get_iteration_id > 0` NON vuol dire che la navmesh del nuovo livello ci sia già. Aspettare che `map_get_closest_point` vicino all'eroe dia un punto vero (vedi `_place_world_extras`).
- Nei tool/test non usare `x is Shrine` / `is WorldEvent` (citano Game): confronta `get_script()`.
- `DungeonLevel._bake` in headless spegne le iterazioni asincrone della navigazione (altrimenti il terzo dungeon di fila in un test a volte non trova il percorso).

## Test
- Controllo veloce di compilazione: `--headless --import --path .`
- **`tools/test_ostia.gd`** (42 controlli): `--headless --path . --fixed-fps 60 --script res://tools/test_ostia.gd`. Uscita del livello 1 → città, NPC, altare, mercante (compra/vendi/riacquista), fabbro (smonta/forgia), poteri leggendari, viaggio rapido, portale, salvataggio. Usa e cancella lo slot 3.
- **`tools/test_atto2.gd`** (53 controlli): missioni dell'atto 1 e 2, segni degli NPC, cancello, forziere personale, porto percorso a piedi fino al faro, Vulso e rinforzi, portale, diario, rimappatura tasti, salvataggio. Ripristina il forziere personale vero.
- **`tools/test_gemme_set.gd`** (26 controlli): pezzi di set e bonus 2/4 pezzi, set dai leggendari, orbite, gioielliere (combina, incastona, togli), gemme raccolte da terra, salvataggio.
- **`tools/test_dungeon.gd`** (39 controlli): per ogni dungeon stesso seme = stessa mappa e 30 semi sempre collegati; catacombe percorse dall'entrata all'uscita (boss, forzieri, ricarica dentro il dungeon); per gli altri: entrata nel loro livello, percorso fino al boss e alla scala, boss che compare, stanze arredate.
- **`tools/test_equipaggiamento.gd`** (20 controlli): 8 corpi con tutte le prese, aspetto per ogni base, pezzi nelle prese giuste, niente doppioni, elmo che nasconde i capelli, tinta dei leggendari, sesso salvato, eroina in gioco che indossa e toglie.
- **`tools/test_endgame.gd`** (53 controlli): dati delle 40 abilità/varianti/passive, leggendari e set nuovi, scelte dell'eroe e salvataggio, varianti in gioco (stordimento, fiamme, cura, seconda salva), leggendario che cambia Pilum, passiva Ultimo baluardo, affissi delle elite, Campioni e Rari, difficoltà (affissi, livello, vita, leggendari), Labirinto completo (obelisco, barra, Guardiano, ricompensa, gemma leggendaria e suo potenziamento, record, grado, uscita).
- **`tools/test_interfaccia.gd`** (37 controlli): schermata di caricamento, finestra Abilità, zaino (ordina, dettagli, anteprima 3D), Aspetto e tinte, vendita in blocco, schede del forziere (ripristina il forziere vero), filtro del loot, Alt, nebbia di guerra, segnalini, controller (mira, A, stick, rimappatura), numeri di danno.
- **`tools/test_avventura.gd`** (53 controlli): slot nuovi, secondo anello, doppia arma (e mano sinistra addosso), tipi di danno, gemme leggendarie (incastonare, effetti, potenziamento, salvataggio), boss a fasi (scudo + rinforzi, furia, attacchi), taglie (tabula, boss che ricompare, ricompense, cassa), santuari ed eventi nel livello 1, pilone del flusso, mappa grande, oggetti nuovi, daltonici, pulsanti del controller, riepilogo alla morte, hardcore (forziere separato, eroe perso, slot).
- **`tools/test_mappa.gd`** (16 controlli): ogni livello ha la Forma; Forma e "Ricostruisci terreno" su una copia in memoria del porto (non salva nulla): ricostruzione ripetibile, luoghi/nemici intatti, nuova area raggiungibile a piedi, strada spostata, pianta PNG.
- Lo stesso schema (imposta `Game.hero`, `Game.travel(...)`, guida il `Player` con move_target/interact_target/_try_cast) serve per altri test. `--fixed-fps 60` fa girare il tempo di gioco più veloce del tempo reale.

## Stato (17-11-2026)
Fatto: menu + 3 slot di salvataggio, 4 classi complete, loot/equipaggiamento/inventario, nemici a zone con navmesh e RVO, elite e boss, grafica stile D3 (trasparenza, minimappa, HUD a globi), livello 1 in grayboxing (circa 1150 m).
Fatto il 16-11: città-hub Ostia Nova (livello 2) con 11 NPC, mercante e fabbro (sesterzi, materiali, forgia), 12 leggendari con poteri, viaggio rapido dagli altari, portale cittadino (T), particelle ed effetti sonori sintetizzati, volume nel menu di pausa, salvataggi versione 2 (compatibili con i vecchi).
Fatto il 16-11 (2): missioni (6, atti 1-2) con diario e segni sugli NPC, livello 3 "Porto di Ostia Nova" (circa 560 m, 20 zone, boss Vulso il Corsaro che chiama rinforzi, 5 nuovi nemici), forziere personale condiviso, opzioni (video, audio, rimappatura tasti) dal menu principale e dalla pausa, aggancio per la musica.
Fatto il 17-11: Forma dei livelli modificabile nell'editor (strade, aree, acqua) + plugin Legio Map (pannello Mappa, Ricostruisci terreno, piante PNG); i tre generatori usano la Forma.
Fatto il 17-11 (2): gemme (5 tipi × 5 gradi, orbite, gioielliere), 4 set di classe con bonus, dungeon generati con seme fisso (Catacombe del Mausoleo, boss Custode delle Ossa) con entrata nel livello 1.
Fatto il 17-11 (3): altri 2 dungeon (Caverne del Clan in stile caverna, Cisterne del Porto), tipi di stanza (colonne, cripta, tesoro), piano per l'equipaggiamento visibile (`docs/PIANO_EQUIPAGGIAMENTO.md`).
Fatto il 17-11 (4): equipaggiamento visibile in grayboxing (fase 1 del piano): corpi M/F per classe con prese, scelta del sesso alla creazione, pezzi per tutte le 24 basi indossabili.
Fatto il 17-11 (5): abilità alternative + 3 varianti per abilità + passive (finestra K), 12 leggendari che cambiano le abilità, 4 set nuovi, elite con affissi (Campioni / Rari con servitori), difficoltà Normale → Tormento X, Labirinti di Dedalo (endgame), anteprima 3D, ordina zaino, statistiche dettagliate, vendita in blocco, forziere a schede, Aspetto (trasmogrificazione + tinte), filtro loot e Alt, barra del boss, nebbia di guerra, segnalini missioni, schermata di caricamento, controller, numeri di danno.
Fatto il 17-11 (6): spallacci/cintura/bracciali/secondo anello/doppia arma, tipi di danno, gemme leggendarie, santuari e piloni, eventi casuali, taglie (modalità avventura), boss a fasi, hardcore; mappa grande con legenda e viaggio rapido, oggetti nuovi, confronto con Shift, opzioni (scala interfaccia, numeri di danno, daltonici), controller nei negozi, riepiloghi, record, slot dettagliati, suggerimenti.
Da fare: trama (testi in `data/quest_db.gd` e `data/npc_db.gd`, segnaposto `[TRAMA]`), musica e suoni veri, modelli Tripo + animazioni, atto 3, altri dungeon, bilanciamento (livelli alti, Tormenti, labirinti). Mai visto a schermo (solo test headless): finestre nuove, anteprima 3D, nebbia, controller.
