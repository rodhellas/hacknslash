# Legio 3000

Action RPG isometrico in stile **Diablo 3**, ambientato nell'**Impero Romano del 3000 d.C.**: l'Impero non è mai caduto e governa la galassia da Nova Roma.

Motore: **Godot 4.7.2** (GDScript, renderer Forward+). Grafica attuale: **grayboxing** (forme semplici), pensata per essere sostituita da modelli generati con **Tripo 3D** e animazioni **Mixamo**.

## Come avviarlo

1. Apri Godot 4.7.2 → *Importa* → seleziona `project.godot`.
2. Premi **F5**: parte il menu principale (Nuova partita → slot → classe → nome).
3. Per provare subito il livello senza menu: apri `scenes/levels/level_01.tscn` e premi **F6** (eroe di prova Legionario, salvataggi disattivati).

## Comandi

| Tasto | Azione |
|---|---|
| Clic sinistro (tenuto) | Muovi / attacca il nemico sotto il cursore / raccogli / apri |
| Shift + clic sinistro | Attacca sul posto |
| Clic destro, 1, 2, 3, 4 | Abilità |
| Q | Pozione (60% vita, ricarica 30 s) |
| E | Interagisci con l'oggetto più vicino |
| WASD | Movimento diretto (alternativa al clic) |
| I / C | Personaggio e inventario |
| TAB | Mappa grande |
| Rotellina | Zoom |
| ESC | Pausa (salva, comandi, menu) |

## Cosa c'è

- **4 classi** con 6 abilità ciascuna, sbloccate ai livelli 1, 1, 2, 3, 4, 6: Legionario, Gladiatore, Sagittario, Augure.
- **Loot stile Diablo**: rarità comune/magico/raro/leggendario, affissi casuali, 9 leggendari, loot "intelligente" per la classe, confronto con l'oggetto indossato.
- **9 slot di equipaggiamento**, zaino da 40 caselle, statistiche (Forza/Destrezza/Intelligenza/Vitalità, armatura, critico, velocità d'attacco...).
- **Nemici a zone** (EncounterZone): compaiono quando ti avvicini, il gruppo si attiva insieme, tornano a casa se scappi. Ci sono gli elite (Campioni, blu) e un boss unico (Brenno, arancione).
- **Navigazione**: navmesh + evitamento RVO, i nemici aggirano gli ostacoli.
- **Grafica stile D3**: telecamera fissa verso nord, oggetti che diventano trasparenti quando coprono l'eroe, minimappa + mappa grande, globi vita/risorsa, numeri di danno, nomi del loot colorati e colonne di luce sui rari.
- **Menu principale con 3 slot di salvataggio** (JSON in `user://saves/`), altari-checkpoint con salvataggio automatico, rinascita all'ultimo altare.
- **Livello 1 "Campagna di Lazio Prime"**: dalla villa di famiglia alla porta di Ostia Nova, percorso di circa 1150 m (circa 3 minuti a piedi senza combattere), con zone laterali esplorabili.

Vedi [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) per il design e [CLAUDE.md](CLAUDE.md) per l'architettura del codice.
