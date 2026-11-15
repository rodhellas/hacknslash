class_name Layers
extends RefCounted
## Livelli fisici e visivi usati in tutto il progetto (vedi anche Impostazioni progetto > Nomi livelli).

const WORLD := 1          # terreno, muri, alberi: ostacoli che bloccano e generano la navmesh
const PLAYER := 2         # giocatore
const ENEMY := 4          # nemici (anche per il clic del mouse)
const INTERACT := 8       # oggetti cliccabili: forzieri, loot, anfore, cartelli
const OCCLUDER := 16      # volumi che coprono la visuale (chiome, tetti): diventano trasparenti
const VIS_MINIMAP := 1 << 10   # livello visivo 11: icone visibili solo nella minimappa
