# Legio 3000

Action RPG isometrico in stile **Diablo 3**, ambientato nell'**Impero Romano del 3000 d.C.**: l'Impero non è mai caduto e governa la galassia da Nova Roma.

Motore: **Godot 4.7.2** (GDScript, renderer Forward+). Grafica attuale: **grayboxing** (forme semplici), pensata per essere sostituita da modelli generati con **Tripo 3D** e animazioni **Mixamo**.

## Come avviarlo

1. Apri Godot 4.7.2 → *Importa* → seleziona `project.godot`.
2. Premi **F5**: parte il menu principale (Nuova partita → slot → classe → nome).
3. Per provare subito un livello senza menu: apri `scenes/levels/level_01.tscn` (o `level_02_ostia.tscn`, la città) e premi **F6** (eroe di prova Legionario, salvataggi disattivati).

## Comandi

| Tasto | Azione |
|---|---|
| Clic sinistro (tenuto) | Muovi / attacca il nemico sotto il cursore / raccogli / apri |
| Shift + clic sinistro | Attacca sul posto |
| Clic destro, 1, 2, 3, 4 | Abilità |
| Q | Pozione (60% vita, ricarica 30 s) |
| E | Interagisci con l'oggetto più vicino |
| T | Portale per Ostia Nova (in città clicca il portale per tornare dov'eri) |
| Clic su un altare attivato | Viaggio rapido verso gli altri altari (anche tra livelli) |
| Clic destro sullo zaino (con mercante/fabbro/forziere aperto) | Vendi / smonta / deposita |
| J | Diario delle missioni |
| WASD | Movimento diretto (alternativa al clic) |
| I / C | Personaggio e inventario |
| TAB | Mappa grande |
| Rotellina | Zoom |
| ESC | Pausa (salva, comandi, opzioni, menu) |

I tasti si possono cambiare in **Opzioni > Comandi** (dal menu principale o dalla pausa).

## Cosa c'è

- **4 classi** con 6 abilità ciascuna, sbloccate ai livelli 1, 1, 2, 3, 4, 6: Legionario, Gladiatore, Sagittario, Augure.
- **Loot stile Diablo**: rarità comune/magico/raro/leggendario, affissi casuali, loot "intelligente" per la classe, confronto con l'oggetto indossato.
- **12 leggendari con poteri** che cambiano il modo di giocare (es. esplosioni sui critici, proiettili perforanti, scudo d'emergenza).
- **Ostia Nova, la città-hub**: mercante (compra / vendi / riacquista), fabbro (smonta gli oggetti in materiali e forgia oggetti magici, rari e leggendari), prefetto, vestale, guardie e cittadini con dialoghi.
- **Viaggi**: altari con viaggio rapido tra livelli, portale cittadino (T), uscite che collegano i livelli.
- **Missioni** con obiettivi in sequenza, ricompense, diario (J) e segni "!" / "?" sopra gli NPC: 6 missioni tra atto 1 e atto 2 (testi segnaposto).
- **Forziere personale** in città, condiviso da tutti gli eroi.
- **Opzioni**: schermo intero, V-Sync, ombre, SSAO, bagliore, antialiasing, risoluzione 3D, volumi, rimappatura dei tasti.
- **Effetti e audio segnaposto**: particelle per colpi, morti, esplosioni, scie dei proiettili e level up; effetti sonori sintetizzati da codice (sostituibili con file veri in `audio/sfx/`).
- **9 slot di equipaggiamento**, zaino da 40 caselle, statistiche (Forza/Destrezza/Intelligenza/Vitalità, armatura, critico, velocità d'attacco...).
- **Nemici a zone** (EncounterZone): compaiono quando ti avvicini, il gruppo si attiva insieme, tornano a casa se scappi. Ci sono gli elite (Campioni, blu) e un boss unico (Brenno, arancione).
- **Navigazione**: navmesh + evitamento RVO, i nemici aggirano gli ostacoli.
- **Grafica stile D3**: telecamera fissa verso nord, oggetti che diventano trasparenti quando coprono l'eroe, minimappa + mappa grande, globi vita/risorsa, numeri di danno, nomi del loot colorati e colonne di luce sui rari.
- **Menu principale con 3 slot di salvataggio** (JSON in `user://saves/`), altari-checkpoint con salvataggio automatico, rinascita all'ultimo altare.
- **Livello 1 "Campagna di Lazio Prime"**: dalla villa di famiglia alla porta di Ostia Nova, percorso di circa 1150 m (circa 3 minuti a piedi senza combattere), con zone laterali esplorabili.
- **Livello 2 "Ostia Nova"**: la città-hub (circa 100 × 110 m), raggiunta dall'uscita del livello 1.
- **Livello 3 "Porto di Ostia Nova"** (atto 2): magazzini, moli, cantieri navali, spazioporto e faro; pirati cilici, automi portuali, granchi meccanici e il boss Vulso il Corsaro. Si apre con la missione del prefetto.

## Modificare le mappe

Ogni livello ha un nodo **Forma** con strade, aree e specchi d'acqua che si modificano trascinandoli nell'editor. Il pannello **Mappa** (plugin *Legio Map*, già attivo) ha il pulsante **Ricostruisci terreno**: rigenera terreno, bordi, strade, acqua, vegetazione e navmesh senza toccare luoghi, nemici, forzieri e NPC piazzati a mano. Le piante dall'alto dei livelli sono in `docs/mappe/`.

Vedi [docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) per il design e [CLAUDE.md](CLAUDE.md) per l'architettura del codice.
