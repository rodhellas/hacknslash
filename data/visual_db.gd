class_name VisualDB
extends RefCounted
## Aspetto dell'equipaggiamento indossato (vedi docs/PIANO_EQUIPAGGIAMENTO.md).
## Ogni base di ItemDB.BASES può avere una voce in VISUALS (chiave = id della base). Una voce ha:
##   "scene": scena .tscn/.glb del pezzo vero (Tripo); se c'è si istanzia nella presa "socket"
##            (e anche in "mirror", per i pezzi doppi come schinieri e calzari) e "parts" si ignora;
##   "socket": presa per "scene";  "mirror": seconda presa per "scene" (copia specchiata in x);
##   "parts": pezzi graybox [presa, forma, posizione, dimensioni, materiale, rotazione in gradi (facoltativa)];
##            forma = "box" | "cyl" | "sphere" | "capsule"; dimensioni come in build_world.gd
##            (box = lati; cyl = (raggio sopra, altezza, raggio sotto); sphere/capsule = (raggio, altezza));
##   "hide": nodi del corpo (dentro "Graybox" o il modello) da nascondere mentre il pezzo è indossato.
## Le prese sono nodi con nome fisso dentro il modello del personaggio (PRESE): Marker3D ora,
## BoneAttachment3D con lo stesso nome quando arriva il modello con lo scheletro.
## Gioielli (amuleto, anello) non si vedono.

const PRESE := [
	"Presa_Testa", "Presa_Busto", "Presa_Schiena", "Presa_Bacino",
	"Presa_ManoDx", "Presa_ManoSx", "Presa_AvambraccioDx", "Presa_AvambraccioSx",
	"Presa_StincoDx", "Presa_StincoSx", "Presa_PiedeDx", "Presa_PiedeSx",
]

## Materiali dei pezzi graybox (colore base; rarità alte aggiungono una tinta e un bagliore).
const MATERIALS := {
	"bronzo": Color(0.72, 0.52, 0.26), "ferro": Color(0.55, 0.57, 0.6), "acciaio": Color(0.75, 0.78, 0.82),
	"oro": Color(0.95, 0.78, 0.3), "cuoio": Color(0.42, 0.28, 0.16), "stoffa": Color(0.88, 0.86, 0.8),
	"porpora": Color(0.45, 0.2, 0.6), "rosso": Color(0.65, 0.1, 0.1), "verde": Color(0.22, 0.38, 0.22),
	"legno": Color(0.4, 0.27, 0.15), "plasma": Color(0.2, 0.9, 1.0), "cristallo": Color(0.55, 0.65, 1.0),
	"energia": Color(0.35, 0.85, 1.0),
}
## "energia" non è un materiale solido: è un guscio di energia che scorre (Vfx "energy") attorno al metallo.
## Direzione artistica: nel 3000 le armi sono metallo (struttura) avvolto dall'energia. Il pezzo "energia"
## va un po' più grande della lama che avvolge. Leggendari e set: l'energia prende il colore della rarità.
## Materiali che brillano sempre (lame al plasma, cristalli).
const GLOW := {"plasma": 4.0, "cristallo": 3.0}

const VISUALS := {
	# --- Armi (presa: mano destra; la lama punta in avanti, verso -Z) ---
	"gladio_plasma": {"parts": [
		["Presa_ManoDx", "box", Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.22), "cuoio"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.14), Vector3(0.22, 0.05, 0.05), "oro"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.5), Vector3(0.08, 0.025, 0.68), "acciaio"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.51), Vector3(0.15, 0.08, 0.76), "energia"]]},
	"spatha": {"parts": [
		["Presa_ManoDx", "box", Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.24), "cuoio"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.15), Vector3(0.26, 0.05, 0.05), "ferro"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.65), Vector3(0.08, 0.03, 1.0), "acciaio"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.66), Vector3(0.14, 0.08, 1.08), "energia"]]},
	"scure": {"parts": [
		["Presa_ManoDx", "box", Vector3(0, 0, -0.35), Vector3(0.07, 0.07, 0.95), "legno"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.78), Vector3(0.06, 0.45, 0.25), "acciaio"],
		["Presa_ManoDx", "box", Vector3(0, 0, -0.78), Vector3(0.12, 0.52, 0.32), "energia"]]},
	"arco_plasma": {"parts": [
		["Presa_ManoSx", "box", Vector3(0, 0, 0), Vector3(0.06, 1.5, 0.08), "legno"],
		["Presa_ManoSx", "box", Vector3(0, 0, 0.08), Vector3(0.02, 1.4, 0.02), "plasma"]]},
	"manuballista": {"parts": [
		["Presa_ManoDx", "box", Vector3(0, 0, -0.3), Vector3(0.1, 0.12, 0.7), "ferro"],
		["Presa_ManoDx", "box", Vector3(0, 0.02, -0.55), Vector3(0.75, 0.05, 0.07), "acciaio"],
		["Presa_ManoDx", "box", Vector3(0, 0.08, -0.35), Vector3(0.03, 0.03, 0.6), "plasma"]]},
	"lituo": {"parts": [
		["Presa_ManoDx", "cyl", Vector3(0, 0.25, 0), Vector3(0.03, 1.6, 0.03), "legno"],
		["Presa_ManoDx", "cyl", Vector3(0, 1.1, -0.08), Vector3(0.03, 0.25, 0.03), "oro", Vector3(-50, 0, 0)],
		["Presa_ManoDx", "sphere", Vector3(0, 1.18, -0.2), Vector3(0.07, 0.14, 0), "cristallo"]]},
	"bastone_giove": {"parts": [
		["Presa_ManoDx", "cyl", Vector3(0, 0.32, 0), Vector3(0.04, 2.2, 0.04), "legno"],
		["Presa_ManoDx", "sphere", Vector3(0, 1.48, 0), Vector3(0.16, 0.32, 0), "cristallo"]]},
	# --- Mano secondaria ---
	"scutum": {"parts": [
		["Presa_AvambraccioSx", "box", Vector3(-0.08, 0, 0), Vector3(0.08, 1.0, 0.7), "rosso"],
		["Presa_AvambraccioSx", "box", Vector3(-0.13, 0, 0), Vector3(0.03, 0.2, 0.2), "oro"],
		["Presa_AvambraccioSx", "box", Vector3(-0.13, 0, 0), Vector3(0.02, 1.02, 0.04), "plasma"]]},
	"parma": {"parts": [
		["Presa_AvambraccioSx", "cyl", Vector3(-0.08, 0, 0), Vector3(0.32, 0.06, 0.32), "bronzo", Vector3(0, 0, 90)],
		["Presa_AvambraccioSx", "sphere", Vector3(-0.12, 0, 0), Vector3(0.08, 0.16, 0), "ferro"]]},
	"pugio": {"parts": [
		["Presa_ManoSx", "box", Vector3(0, 0, 0), Vector3(0.08, 0.08, 0.14), "cuoio"],
		["Presa_ManoSx", "box", Vector3(0, 0, -0.25), Vector3(0.07, 0.025, 0.35), "acciaio"],
		["Presa_ManoSx", "box", Vector3(0, 0, -0.26), Vector3(0.12, 0.07, 0.41), "energia"]]},
	"faretra": {"parts": [
		["Presa_Schiena", "cyl", Vector3(0.12, 0, 0), Vector3(0.11, 0.75, 0.11), "cuoio", Vector3(0, 0, -20)],
		["Presa_Schiena", "box", Vector3(0.25, 0.4, 0), Vector3(0.12, 0.12, 0.12), "plasma", Vector3(0, 0, -20)]]},
	"sfera_oracolo": {"parts": [
		["Presa_ManoSx", "sphere", Vector3(0, 0.12, 0), Vector3(0.14, 0.28, 0), "cristallo"]]},
	# --- Elmi ---
	"galea": {"hide": ["Capelli"], "parts": [
		["Presa_Testa", "sphere", Vector3(0, 0.06, 0), Vector3(0.24, 0.4, 0), "ferro"],
		["Presa_Testa", "box", Vector3(0, 0.3, 0.02), Vector3(0.06, 0.16, 0.45), "rosso"]]},
	"elmo_centurione": {"hide": ["Capelli"], "parts": [
		["Presa_Testa", "sphere", Vector3(0, 0.06, 0), Vector3(0.25, 0.42, 0), "bronzo"],
		["Presa_Testa", "box", Vector3(0, 0.32, 0), Vector3(0.55, 0.18, 0.07), "rosso"],
		["Presa_Testa", "box", Vector3(0, -0.02, -0.2), Vector3(0.3, 0.06, 0.06), "oro"]]},
	"cappuccio": {"hide": ["Capelli"], "parts": [
		["Presa_Testa", "cyl", Vector3(0, 0.12, 0.03), Vector3(0.0, 0.55, 0.3), "porpora"]]},
	# --- Busto ---
	"lorica": {"parts": [
		["Presa_Busto", "box", Vector3(0, 0.12, 0), Vector3(0.66, 0.16, 0.42), "ferro"],
		["Presa_Busto", "box", Vector3(0, -0.04, 0), Vector3(0.62, 0.14, 0.4), "ferro"],
		["Presa_Busto", "box", Vector3(0, -0.2, 0), Vector3(0.58, 0.14, 0.38), "ferro"],
		["Presa_Busto", "box", Vector3(-0.38, 0.22, 0), Vector3(0.2, 0.1, 0.32), "acciaio"],
		["Presa_Busto", "box", Vector3(0.38, 0.22, 0), Vector3(0.2, 0.1, 0.32), "acciaio"]]},
	"lorica_hamata": {"parts": [
		["Presa_Busto", "box", Vector3(0, -0.05, 0), Vector3(0.62, 0.62, 0.4), "acciaio"],
		["Presa_Busto", "box", Vector3(0, 0.2, 0), Vector3(0.78, 0.1, 0.38), "ferro"]]},
	"toga": {"parts": [
		["Presa_Busto", "cyl", Vector3(0, -0.45, 0), Vector3(0.3, 1.25, 0.46), "stoffa"],
		["Presa_Busto", "box", Vector3(0.05, -0.05, 0), Vector3(0.66, 0.12, 0.46), "porpora", Vector3(0, 0, 35)]]},
	# --- Guanti (una copia per mano) ---
	"manicae": {"parts": [
		["Presa_AvambraccioDx", "box", Vector3(0, 0, 0), Vector3(0.15, 0.32, 0.15), "ferro"],
		["Presa_AvambraccioSx", "box", Vector3(0, 0, 0), Vector3(0.15, 0.32, 0.15), "ferro"]]},
	"guanti_cuoio": {"parts": [
		["Presa_ManoDx", "box", Vector3(0, 0.05, 0), Vector3(0.13, 0.16, 0.13), "cuoio"],
		["Presa_ManoSx", "box", Vector3(0, 0.05, 0), Vector3(0.13, 0.16, 0.13), "cuoio"]]},
	# --- Gambe ---
	"ocreae": {"parts": [
		["Presa_StincoDx", "box", Vector3(0, 0, -0.03), Vector3(0.16, 0.38, 0.12), "bronzo"],
		["Presa_StincoSx", "box", Vector3(0, 0, -0.03), Vector3(0.16, 0.38, 0.12), "bronzo"]]},
	"bracae": {"parts": [
		["Presa_Bacino", "box", Vector3(0, -0.12, 0), Vector3(0.5, 0.3, 0.34), "verde"],
		["Presa_StincoDx", "box", Vector3(0, 0.05, 0), Vector3(0.17, 0.42, 0.17), "verde"],
		["Presa_StincoSx", "box", Vector3(0, 0.05, 0), Vector3(0.17, 0.42, 0.17), "verde"]]},
	# --- Spallacci, cinture, bracciali ---
	"humeralia": {"parts": [
		["Presa_Busto", "box", Vector3(-0.4, 0.26, 0), Vector3(0.24, 0.08, 0.34), "ferro", Vector3(0, 0, 15)],
		["Presa_Busto", "box", Vector3(0.4, 0.26, 0), Vector3(0.24, 0.08, 0.34), "ferro", Vector3(0, 0, -15)]]},
	"spallacci_bronzo": {"parts": [
		["Presa_Busto", "sphere", Vector3(-0.4, 0.24, 0), Vector3(0.16, 0.2, 0), "bronzo"],
		["Presa_Busto", "sphere", Vector3(0.4, 0.24, 0), Vector3(0.16, 0.2, 0), "bronzo"]]},
	"cingulum": {"parts": [
		["Presa_Bacino", "box", Vector3(0, 0.12, 0), Vector3(0.6, 0.09, 0.38), "cuoio"],
		["Presa_Bacino", "box", Vector3(0, -0.08, -0.2), Vector3(0.22, 0.3, 0.03), "bronzo"]]},
	"balteo": {"parts": [
		["Presa_Busto", "box", Vector3(0, -0.05, 0), Vector3(0.08, 0.75, 0.36), "cuoio", Vector3(0, 0, 35)]]},
	"armillae": {"parts": [
		["Presa_AvambraccioDx", "cyl", Vector3(0, -0.08, 0), Vector3(0.1, 0.1, 0.1), "oro"],
		["Presa_AvambraccioSx", "cyl", Vector3(0, -0.08, 0), Vector3(0.1, 0.1, 0.1), "oro"]]},
	"bracciali_cuoio": {"parts": [
		["Presa_AvambraccioDx", "cyl", Vector3(0, -0.05, 0), Vector3(0.1, 0.18, 0.1), "cuoio"],
		["Presa_AvambraccioSx", "cyl", Vector3(0, -0.05, 0), Vector3(0.1, 0.18, 0.1), "cuoio"]]},
	# --- Calzari ---
	"caligae": {"parts": [
		["Presa_PiedeDx", "box", Vector3(0, 0, -0.04), Vector3(0.15, 0.12, 0.3), "cuoio"],
		["Presa_PiedeSx", "box", Vector3(0, 0, -0.04), Vector3(0.15, 0.12, 0.3), "cuoio"]]},
	"calcei": {"parts": [
		["Presa_PiedeDx", "box", Vector3(0, 0.02, -0.04), Vector3(0.14, 0.16, 0.28), "porpora"],
		["Presa_PiedeSx", "box", Vector3(0, 0.02, -0.04), Vector3(0.14, 0.16, 0.28), "porpora"]]},
}

## Tinte disponibili nella scheda Aspetto (chiavi di MATERIALS): colorano i pezzi tranne quelli che brillano.
const DYES := ["rosso", "porpora", "verde", "oro", "acciaio", "bronzo", "cuoio", "stoffa"]

## Slot che si vedono addosso (gli altri, i gioielli, no).
const VISIBLE_SLOTS := ["arma", "secondaria", "elmo", "armatura", "spalle", "cintura", "bracciali", "guanti", "gambali", "calzari"]


static func get_visual(base_id: String) -> Dictionary:
	return VISUALS.get(base_id, {})
