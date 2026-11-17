class_name Item
extends RefCounted
## Oggetto equipaggiabile (arma, armatura, gioiello). Si salva/carica come Dictionary (JSON).

enum Rarity { COMUNE, MAGICO, RARO, LEGGENDARIO, SET }

const RARITY_NAMES := ["Comune", "Magico", "Raro", "Leggendario", "Set"]
const RARITY_COLORS := [Color(0.92, 0.92, 0.92), Color(0.45, 0.62, 1.0), Color(1.0, 0.88, 0.3), Color(1.0, 0.55, 0.1), Color(0.3, 0.95, 0.3)]
const SLOT_NAMES := {
	"arma": "Arma", "secondaria": "Mano secondaria", "elmo": "Elmo", "armatura": "Armatura", "guanti": "Guanti",
	"gambali": "Gambali", "calzari": "Calzari", "amuleto": "Amuleto", "anello": "Anello", "anello2": "Anello",
	"spalle": "Spallacci", "cintura": "Cintura", "bracciali": "Bracciali",
}

var uid := ""
var base_id := ""
var item_name := ""
var slot := ""
var weapon_type := ""
var rarity := 0
var ilvl := 1
var dmg_min := 0.0
var dmg_max := 0.0
var attack_speed := 0.0
var armor := 0.0
var affixes: Array = []   # [{ "stat": String, "value": float }]
var flavor := ""
var power := ""   # potere leggendario (chiave di ItemDB.POWERS)
var set_id := ""  # pezzo di set (chiave di ItemDB.SETS)
var gems: Array = []   # orbite: una chiave di gemma ("rubino:2") o "" se vuota; size() = numero di orbite
var is_new := false    # appena raccolto: segnato nello zaino finché non ci passi sopra


func color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, RARITY_COLORS.size() - 1)]


## Leggendari e set: colonna di luce alta, suono speciale.
func is_special() -> bool:
	return rarity >= Rarity.LEGGENDARIO


func free_sockets() -> int:
	return gems.count("")


## Statistiche delle gemme incastonate.
func gem_affixes() -> Array:
	var out: Array = []
	for g: String in gems:
		if g != "":
			var a := ItemDB.gem_affix(g, slot)
			if not a.is_empty():
				out.append(a)
	return out


func dps() -> float:
	return (dmg_min + dmg_max) * 0.5 * attack_speed


## Somma dei valori degli affissi per statistica.
func stat_totals() -> Dictionary:
	var t := {}
	for a: Dictionary in affixes + gem_affixes():
		t[a["stat"]] = float(t.get(a["stat"], 0.0)) + float(a["value"])
	return t


## Lettera della rarità (opzione per daltonici).
func rarity_letter() -> String:
	return ["C", "M", "R", "L", "S"][clampi(rarity, 0, 4)]


func short_label() -> String:
	var words := item_name.split(" ", false)
	var s := ""
	for w in words:
		if w.length() > 2 and s.length() < 3:
			s += w[0].to_upper()
	return s if s != "" else item_name.left(2)


func to_dict() -> Dictionary:
	return {
		"uid": uid, "base_id": base_id, "name": item_name, "slot": slot, "weapon_type": weapon_type,
		"rarity": rarity, "ilvl": ilvl, "dmg_min": dmg_min, "dmg_max": dmg_max, "attack_speed": attack_speed,
		"armor": armor, "affixes": affixes, "flavor": flavor, "power": power,
		"set_id": set_id, "gems": gems, "new": is_new,
	}


static func from_dict(d: Dictionary) -> Item:
	var it := Item.new()
	it.uid = String(d.get("uid", ""))
	it.base_id = String(d.get("base_id", ""))
	it.item_name = String(d.get("name", "?"))
	it.slot = String(d.get("slot", ""))
	it.weapon_type = String(d.get("weapon_type", ""))
	it.rarity = int(d.get("rarity", 0))
	it.ilvl = int(d.get("ilvl", 1))
	it.dmg_min = float(d.get("dmg_min", 0.0))
	it.dmg_max = float(d.get("dmg_max", 0.0))
	it.attack_speed = float(d.get("attack_speed", 0.0))
	it.armor = float(d.get("armor", 0.0))
	it.flavor = String(d.get("flavor", ""))
	it.power = String(d.get("power", ""))
	if it.power == "" and it.rarity == Rarity.LEGGENDARIO:
		it.power = ItemDB.power_for_name(it.item_name)
	it.set_id = String(d.get("set_id", ""))
	it.is_new = bool(d.get("new", false))
	for g: Variant in d.get("gems", []):
		it.gems.append(String(g))
	for a: Dictionary in d.get("affixes", []):
		it.affixes.append({"stat": String(a["stat"]), "value": float(a["value"])})
	return it


## Testo del tooltip in BBCode, con confronto rispetto a un oggetto equipaggiato.
func tooltip_bbcode(compare: Item = null, usable: bool = true) -> String:
	var c := color().to_html(false)
	var t := "[font_size=20][color=#%s]%s[/color][/font_size]\n" % [c, item_name]
	t += "[color=#%s]%s - %s[/color]   [color=#888888]Liv. oggetto %d[/color]\n" % [c, RARITY_NAMES[rarity], SLOT_NAMES.get(slot, slot), ilvl]
	if weapon_type != "":
		t += "[color=#aaaaaa]Tipo: %s[/color]\n" % weapon_type.capitalize()
	if not usable:
		t += "[color=#ff5050]Non utilizzabile dalla tua classe[/color]\n"
	if dmg_max > 0.0:
		if slot == "arma":
			t += "\n[font_size=22]%.1f[/font_size] danno al secondo" % dps()
			if compare and compare.dmg_max > 0.0:
				t += _diff(dps() - compare.dps(), "%.1f")
			t += "\n%d-%d danni   %.2f attacchi al secondo\n" % [roundi(dmg_min), roundi(dmg_max), attack_speed]
		else:
			t += "\n+%d-%d danni aggiuntivi\n" % [roundi(dmg_min), roundi(dmg_max)]
	if armor > 0.0:
		t += "\n[font_size=22]%d[/font_size] armatura" % roundi(armor)
		if compare:
			t += _diff(armor - compare.armor, "%d")
		t += "\n"
	if not affixes.is_empty():
		t += "\n"
		for a: Dictionary in affixes:
			t += "[color=#7fa8ff]%s[/color]\n" % ItemDB.affix_text(a)
	if not gems.is_empty():
		t += "\n"
		for g: String in gems:
			if g == "":
				t += "[color=#777777]◇ Orbita vuota[/color]\n"
			else:
				var gtxt := ItemDB.leg_gem_text(g) if ItemDB.is_legendary_gem(g) else ItemDB.affix_text(ItemDB.gem_affix(g, slot))
				t += "[color=#%s]◆ %s:[/color] [color=#7fa8ff]%s[/color]\n" % [ItemDB.gem_color(g).to_html(false),
					ItemDB.gem_name(g), gtxt]
	if power != "":
		t += "\n[color=#ff9a30]%s[/color]\n" % ItemDB.POWERS.get(power, "")
	if set_id != "" and ItemDB.SETS.has(set_id):
		t += _set_text()
	if flavor != "":
		t += "\n[i][color=#c8a050]%s[/color][/i]\n" % flavor
	if compare:
		var mine := stat_totals()
		var theirs := compare.stat_totals()
		var keys := mine.keys()
		for k in theirs.keys():
			if not k in keys:
				keys.append(k)
		var lines := ""
		for k: String in keys:
			var d := float(mine.get(k, 0.0)) - float(theirs.get(k, 0.0))
			if absf(d) > 0.01:
				var col := "60ff60" if d > 0 else "ff6060"
				lines += "[color=#%s]%s[/color]\n" % [col, ItemDB.affix_text({"stat": k, "value": d}, true)]
		if lines != "":
			t += "\n[color=#999999]Rispetto a ciò che indossi:[/color]\n" + lines
	return t


## Elenco dei pezzi del set (verdi quelli indossati) e dei bonus (attivi in verde).
func _set_text() -> String:
	var st: Dictionary = ItemDB.SETS[set_id]
	var worn := {}
	var game: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Game")
	if game != null and game.get("hero") != null:
		var eq: Dictionary = game.hero.equipment
		for k: String in eq:
			var w: Item = eq[k]
			if w.set_id == set_id:
				worn[w.item_name] = true
	var t := "\n[color=#4cf24c]%s[/color]\n" % st["name"]
	for pd: Dictionary in st["pieces"]:
		t += "[color=#%s]  %s[/color]\n" % ["4cf24c" if worn.has(pd["name"]) else "777777", pd["name"]]
	var bonus: Dictionary = st["bonus"]
	for n: int in bonus:
		var col := "4cf24c" if worn.size() >= n else "777777"
		t += "[color=#%s](%d) %s[/color]\n" % [col, n, ItemDB.set_bonus_text(bonus[n])]
	return t


static func _diff(d: float, fmt: String) -> String:
	if absf(d) < 0.05:
		return ""
	var col := "60ff60" if d > 0 else "ff6060"
	var sign := "+" if d > 0 else ""
	return "  [color=#%s](%s%s)[/color]" % [col, sign, fmt % d]
