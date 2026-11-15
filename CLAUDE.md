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
- Su un altro PC chiedi all'utente dove si trova Godot 4.7.x.

## Struttura
```
core/       game.gd (autoload "Game": partita, salvataggi, cambio scena), hero_data.gd, item.gd,
            abilities.gd (esecuzione abilità), loot.gd, fx.gd (materiali/effetti), layers.gd
data/       hero_classes.gd (classi+abilità), enemy_db.gd, item_db.gd (basi, affissi, leggendari, drop)
entities/   player.gd, enemy.gd, projectile.gd, loot_drop.gd, health_globe.gd
world/      level.gd (script radice dei livelli), iso_camera.gd, occlusion_fader.gd, encounter_zone.gd (@tool),
            chest.gd, breakable.gd, checkpoint.gd, level_exit.gd, lore_sign.gd
ui/         main_menu.gd, hud.gd, inventory_ui.gd, pause_menu.gd, minimap.gd, globe.gd, skill_slot.gd
tools/      build_world.gd (GENERATORE grayboxing: props, modelli, livello 1 + navmesh)
scenes/     main_menu.tscn, levels/level_01.tscn (+ navmesh .res), props/*.tscn, characters/*.tscn, enemies/*.tscn
```
- Quasi tutto è **guidato dai dati** (dizionari in `data/`). Per bilanciare, cambia i numeri lì.
- UI, eroe, nemici e proiettili sono costruiti **da codice**. Livelli, oggetti di scena e modelli sono **scene .tscn** modificabili nell'editor.
- Ogni modello (classe/nemico) è una scena a parte, referenziata da `HeroClasses.DATA[..]["model"]` / `EnemyDB.DATA[..]["model"]`. Per usare un modello Tripo: sostituisci il nodo `Graybox` della scena con il .glb, orientato verso **−Z**. Se il modello ha un `AnimationPlayer` con le animazioni `idle`, `run`, `attack`, `cast`, `hit`, `death`, `Player` le riproduce da solo.
- Gli oggetti di scena hanno la radice `StaticBody3D` (livello fisico 1), il gruppo `fadeable` se alti, un `OcclusionVolume` (livello 5) per le chiome/tetti e il figlio `Graybox` da sostituire.

## Livelli fisici (core/layers.gd)
1 mondo/ostacoli (genera la navmesh) · 2 giocatore · 3 nemici · 4 interagibili (clic) · 5 occlusione (trasparenza) · livello **visivo** 11 = icone della minimappa (la telecamera principale lo esclude).

## Generatore della mappa
```
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/build_world.gd            # tutto
... --script res://tools/build_world.gd -- props    # solo oggetti di scena
... --script res://tools/build_world.gd -- models   # solo modelli personaggi/nemici
... --script res://tools/build_world.gd -- level    # solo livello 1 (+ navmesh)
```
- È deterministico (seed 3000). **Rigenerare il livello sovrascrive `level_01.tscn`**: dopo modifiche a mano nell'editor, NON rigenerare il livello (props e modelli sì, ma attenzione: rigenerare un prop sovrascrive le sostituzioni Tripo fatte in quella scena).
- La navmesh è salvata in `scenes/levels/level_01_navmesh.res`. Se modifichi il livello nell'editor: seleziona il nodo `World` (NavigationRegion3D) → *Bake NavigationMesh*.
- Tutto ciò che deve bloccare il movimento o la navmesh va messo **sotto il nodo `World`** con un collider sul livello 1.
- Nuovi nemici: aggiungi un nodo con `world/encounter_zone.gd` sotto `Incontri` e impostalo dall'Inspector (nell'editor appare come disco colorato).

## Insidie note (importante)
- **GDScript tipizzato**: `var x := dict["k"]` è un errore di compilazione ("Cannot infer the type"). Usa `var x: float = ...` oppure `float(...)`.
- Script lanciati con `--script` (tool/test headless): le classi che citano l'autoload `Game` **non compilano** se sono referenziate staticamente dallo script principale (vengono compilate prima che esista l'autoload). Nei tool/test usa `load("res://...").new()` e variabili non tipizzate. Nel gioco normale non è un problema.
- Le operazioni che richiedono l'albero di scena (bake della navmesh) vanno fatte nel primo `_process`, non in `_initialize`.
- I personaggi si muovono a y = 0 (niente gravità). Il terreno è piatto e il mouse usa il piano y = 0.
- La navmesh ha "isole" sopra gli oggetti alti: `Player.snap_to_nav` scarta i punti con y > 0.
- `Item` usa `item_name` (non `name`).

## Test
- Controllo veloce di compilazione: `--headless --import --path .`
- Test di gioco automatico: uno script SceneTree che imposta `Game.hero`, fa `change_scene_to_file` del livello e guida il `Player` (move_target/attack_target/_try_cast). È servito a verificare che il percorso sia completabile, il loot, la navmesh e i salvataggi.

## Stato (15-11-2026)
Fatto: menu + 3 slot di salvataggio, 4 classi complete, loot/equipaggiamento/inventario, nemici a zone con navmesh e RVO, elite e boss, grafica stile D3 (trasparenza, minimappa, HUD a globi), livello 1 in grayboxing (circa 1150 m).
Da fare: trama, livello 2 (Ostia Nova hub), venditori, audio, effetti veri, modelli Tripo, bilanciamento.
