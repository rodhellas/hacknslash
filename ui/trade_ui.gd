class_name TradeUI
extends CanvasLayer
## Pannello a sinistra (l'inventario si apre a destra) per:
##   Mercante: compra (clic sulla merce), vendi (clic destro su un oggetto dello zaino), riacquista.
##   Fabbro:   smonta (clic destro su un oggetto dello zaino) e forgia nuovi oggetti con i materiali.
##             Scheda Gioielliere: combina 3 gemme in una superiore, incastona e togli le gemme.
##   Forziere personale (stash): clic = riprendi nello zaino, clic destro sullo zaino = deposita.
## Prezzi, materiali e ricette sono in data/item_db.gd (SELL_VALUE, BUY_MULT, salvage_yield, RECIPES).

const STOCK_SIZE := 16
const BUYBACK_MAX := 12
const CLOSE_DIST := 8.0

var player: Player
var inv: InventoryUI
## Chi ha aperto il pannello (NPC o forziere): se l'eroe si allontana, il pannello si chiude.
var source: Node3D = null
var source_name := ""
var mode := ""
var is_open := false
var panel: PanelContainer
var title: Label
var subtitle: Label
var gold_label: Label
var content: VBoxContainer
var _tab := "merce"
var _slot_choice := "arma"
var _gem_choice := ""
## Merce di ogni mercante: si rinnova ogni volta che si rientra nel livello.
var _stock: Dictionary = {}


func _ready() -> void:
	layer = 6
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_left = 10
	panel.offset_right = 540
	panel.offset_top = 10
	panel.offset_bottom = -10
	panel.add_theme_stylebox_override("panel", Hud._panel_style(0.95))
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	title = _label(26, Hud.GOLD)
	head.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var x := Button.new()
	x.text = "Chiudi"
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(close)
	head.add_child(x)
	subtitle = _label(15, Color(0.75, 0.7, 0.6))
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(subtitle)
	gold_label = _label(18, Hud.GOLD)
	v.add_child(gold_label)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	v.add_child(content)
	panel.visible = false


func bind(p: Player, inventory: InventoryUI) -> void:
	player = p
	inv = inventory
	p.inventory_changed.connect(func() -> void:
		if is_open:
			refresh.call_deferred())


## mode: "vendor", "smith" o "stash".
func open(src: Node3D, p_mode: String, p_title: String) -> void:
	source = src
	source_name = p_title
	mode = p_mode
	_tab = "merce"
	is_open = true
	panel.visible = true
	refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	panel.visible = false
	source = null
	if inv:
		inv.hide_tooltip()


func _process(_delta: float) -> void:
	if not is_open:
		return
	if source == null or not is_instance_valid(source) or player.dead \
			or player.global_position.distance_to(source.global_position) > CLOSE_DIST:
		close()


func refresh() -> void:
	if not is_open:
		return
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	title.text = source_name
	gold_label.text = "%d sesterzi" % player.hero.gold
	if mode == "vendor":
		subtitle.text = "Clic su un oggetto: compra.   Clic destro su un oggetto del tuo zaino: vendi."
		_build_vendor()
	elif mode == "stash":
		subtitle.text = "Clic: riprendi nello zaino.   Clic destro su un oggetto dello zaino: deposita.\nIl forziere è condiviso da tutti i tuoi eroi."
		_build_stash()
	else:
		subtitle.text = "Clic destro su un oggetto del tuo zaino: smontalo per ottenere materiali."
		_build_tabs([["merce", "Fabbro"], ["gemme", "Gioielliere"]])
		if _tab == "gemme":
			subtitle.text = "Scegli una gemma, poi clicca un'orbita vuota per incastonarla. Clic su una gemma incastonata: toglila."
			_build_jeweler()
		else:
			_build_smith()


## Chiamato dall'inventario con il clic destro su un oggetto dello zaino.
func on_bag_right_click(index: int) -> void:
	match mode:
		"vendor": _sell(index)
		"stash": _deposit(index)
		_: _salvage(index)


# --- Forziere personale -----------------------------------------------------------------------

func _build_stash() -> void:
	var items := Game.stash()
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)
	var used := 0
	for i in items.size():
		var it: Item = items[i]
		var b := InventoryUI.make_slot_button(Vector2(60, 60))
		InventoryUI.paint_slot(b, it, "", it == null or player.hero.can_equip(it))
		if it != null:
			used += 1
			b.gui_input.connect(_on_stash_input.bind(i))
			b.mouse_entered.connect(func() -> void:
				inv.show_tooltip(it.tooltip_bbcode(player.hero.equipment.get(it.slot), player.hero.can_equip(it)), true))
			b.mouse_exited.connect(inv.hide_tooltip)
		grid.add_child(b)
	content.add_child(_label(14, Color(0.7, 0.65, 0.55), "%d / %d caselle occupate" % [used, items.size()]))


func _on_stash_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var items := Game.stash()
	var it: Item = items[index]
	if it == null:
		return
	if not player.hero.add_item(it):
		Game.level.hud.show_warning("Inventario pieno")
		return
	items[index] = null
	Sfx.play("pickup")
	inv.hide_tooltip()
	_after_change()


func _deposit(index: int) -> void:
	var it: Item = player.hero.inventory[index]
	if it == null:
		return
	var items := Game.stash()
	var free := items.find(null)
	if free < 0:
		Game.level.hud.show_warning("Il forziere è pieno")
		return
	items[free] = it
	player.hero.inventory[index] = null
	Sfx.play("chest", null, -6.0)
	_after_change()


# --- Mercante ---------------------------------------------------------------------------------

func _build_vendor() -> void:
	_build_tabs([["merce", "Merce"], ["riacquista", "Riacquista (%d)" % Game.buyback.size()]])
	var buyback := _tab == "riacquista"
	_build_vendor_items(buyback)


func _build_tabs(list: Array) -> void:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	for pair: Array in list:
		var b := Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.button_pressed = _tab == pair[0]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(160, 34)
		var id: String = pair[0]
		b.pressed.connect(func() -> void:
			_tab = id
			Sfx.play("ui_click")
			refresh.call_deferred())
		tabs.add_child(b)


func _build_vendor_items(buyback: bool) -> void:
	var items: Array = Game.buyback if buyback else _get_stock()
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	content.add_child(grid)
	for i in items.size():
		var it: Item = items[i]
		var b := InventoryUI.make_slot_button(Vector2(60, 60))
		InventoryUI.paint_slot(b, it, "", player.hero.can_equip(it))
		b.gui_input.connect(_on_item_input.bind(i, buyback))
		b.mouse_entered.connect(_on_item_hover.bind(it, buyback))
		b.mouse_exited.connect(inv.hide_tooltip)
		grid.add_child(b)
	if items.is_empty():
		content.add_child(_label(15, Color(0.6, 0.6, 0.6), "Niente da riacquistare." if buyback else "Merce esaurita."))
	var sell_all := Button.new()
	sell_all.text = "Vendi tutti gli oggetti comuni dello zaino"
	sell_all.focus_mode = Control.FOCUS_NONE
	sell_all.pressed.connect(func() -> void:
		var n := 0
		for i in player.hero.inventory.size():
			var it: Item = player.hero.inventory[i]
			if it != null and it.rarity == Item.Rarity.COMUNE:
				_sell(i, false)
				n += 1
		if n == 0:
			Game.level.hud.show_warning("Nessun oggetto comune nello zaino")
		_after_change())
	content.add_child(sell_all)


func _get_stock() -> Array:
	var key := source.get_instance_id()
	if not _stock.has(key):
		var list: Array = []
		var lvl := player.hero.level
		for i in STOCK_SIZE:
			var r := Item.Rarity.RARO if i < 4 else Item.Rarity.MAGICO
			list.append(ItemDB.generate(lvl, r, player.hero.class_id))
		_stock[key] = list
	return _stock[key]


func _price(it: Item, buyback: bool) -> int:
	return ItemDB.sell_value(it) if buyback else ItemDB.buy_price(it)


func _on_item_hover(it: Item, buyback: bool) -> void:
	var equipped: Item = player.hero.equipment.get(it.slot)
	var price := _price(it, buyback)
	var col := "f2c75a" if player.hero.gold >= price else "ff5050"
	inv.show_tooltip(it.tooltip_bbcode(equipped, player.hero.can_equip(it)) +
		"\n[color=#%s]Prezzo: %d sesterzi[/color]" % [col, price], true)


func _on_item_input(event: InputEvent, index: int, buyback: bool) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var list: Array = Game.buyback if buyback else _get_stock()
	if index >= list.size():
		return
	var it: Item = list[index]
	var price := _price(it, buyback)
	if player.hero.gold < price:
		Game.level.hud.show_warning("Sesterzi insufficienti")
		return
	if not player.hero.add_item(it):
		Game.level.hud.show_warning("Inventario pieno")
		return
	player.hero.gold -= price
	list.remove_at(index)
	Sfx.play("coins")
	Game.level.hud.log_pickup("%s (-%d sesterzi)" % [it.item_name, price], it.color())
	inv.hide_tooltip()
	_after_change()


func _sell(index: int, notify: bool = true) -> void:
	var it: Item = player.hero.inventory[index]
	if it == null:
		return
	var value := ItemDB.sell_value(it)
	player.hero.inventory[index] = null
	player.hero.gold += value
	Game.buyback.push_front(it)
	if Game.buyback.size() > BUYBACK_MAX:
		Game.buyback.resize(BUYBACK_MAX)
	Game.level.hud.log_pickup("Venduto: %s (+%d)" % [it.item_name, value], Hud.GOLD)
	if notify:
		Sfx.play("coins")
		_after_change()


# --- Fabbro -----------------------------------------------------------------------------------

func _build_smith() -> void:
	var mats := RichTextLabel.new()
	mats.bbcode_enabled = true
	mats.fit_content = true
	mats.add_theme_font_size_override("normal_font_size", 16)
	var t := ""
	for id: String in ItemDB.MATERIALS:
		var m: Dictionary = ItemDB.MATERIALS[id]
		t += "[color=#%s]%s: [b]%d[/b][/color]     " % [(m["color"] as Color).to_html(false), m["name"], player.hero.material(id)]
	mats.text = t
	content.add_child(mats)

	content.add_child(_label(20, Hud.GOLD, "Smonta"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	for pair: Array in [[Item.Rarity.COMUNE, "Tutti i comuni"], [Item.Rarity.MAGICO, "Tutti i magici"], [Item.Rarity.RARO, "Tutti i rari"]]:
		var b := Button.new()
		b.text = pair[1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_color_override("font_color", Item.RARITY_COLORS[pair[0]])
		var rarity: int = pair[0]
		b.pressed.connect(func() -> void: _salvage_all(rarity))
		row.add_child(b)
	content.add_child(_label(13, Color(0.6, 0.6, 0.6),
		"Comune: rottami.  Magico: rottami + essenza.  Raro: essenze.  Leggendario: frammento divino.\nGli oggetti indossati non vengono toccati."))

	content.add_child(_label(20, Hud.GOLD, "Forgia"))
	var srow := HBoxContainer.new()
	srow.add_child(_label(16, Color(0.85, 0.8, 0.7), "Tipo di oggetto: "))
	var opt := OptionButton.new()
	opt.focus_mode = Control.FOCUS_NONE
	var idx := 0
	for slot: String in HeroData.EQUIP_SLOTS:
		opt.add_item(Item.SLOT_NAMES[slot])
		opt.set_item_metadata(idx, slot)
		if slot == _slot_choice:
			opt.select(idx)
		idx += 1
	opt.item_selected.connect(func(i: int) -> void: _slot_choice = String(opt.get_item_metadata(i)))
	srow.add_child(opt)
	content.add_child(srow)
	var lvl := player.hero.level
	for rid: String in ItemDB.RECIPES:
		var r: Dictionary = ItemDB.RECIPES[rid]
		var gold := int(r["gold_per_level"]) * lvl
		var cost := "%d sesterzi" % gold
		var ok := player.hero.gold >= gold
		var mats_req: Dictionary = r["mats"]
		for m: String in mats_req:
			cost += ", %d %s" % [int(mats_req[m]), String(ItemDB.MATERIALS[m]["name"]).to_lower()]
			ok = ok and player.hero.material(m) >= int(mats_req[m])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var b := Button.new()
		b.text = String(r["name"])
		b.custom_minimum_size = Vector2(230, 38)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not ok
		b.add_theme_color_override("font_color", Item.RARITY_COLORS[int(r["rarity"])])
		b.pressed.connect(_craft.bind(rid))
		h.add_child(b)
		var l := _label(14, Color(0.85, 0.8, 0.7) if ok else Color(0.7, 0.4, 0.4), cost)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(240, 0)
		h.add_child(l)
		content.add_child(h)
	content.add_child(_label(13, Color(0.6, 0.6, 0.6),
		"Gli oggetti forgiati sono del tuo livello e adatti alla tua classe.\nIl leggendario è casuale (il tipo scelto viene ignorato) e può essere un pezzo di set."))


func _salvage(index: int, notify: bool = true) -> Dictionary:
	var it: Item = player.hero.inventory[index]
	if it == null:
		return {}
	var got := ItemDB.salvage_yield(it)
	for m: String in got:
		player.hero.add_material(m, int(got[m]))
	player.hero.inventory[index] = null
	Quests.notify("salvage")
	if notify:
		_log_materials(got)
		Sfx.play("anvil", null, -4.0)
		_after_change()
	return got


func _salvage_all(rarity: int) -> void:
	var total := {}
	for i in player.hero.inventory.size():
		var it: Item = player.hero.inventory[i]
		if it != null and it.rarity == rarity:
			var got := _salvage(i, false)
			for m: String in got:
				total[m] = int(total.get(m, 0)) + int(got[m])
	if total.is_empty():
		Game.level.hud.show_warning("Nessun oggetto di quella rarità nello zaino")
		return
	_log_materials(total)
	Sfx.play("anvil")
	_after_change()


func _log_materials(got: Dictionary) -> void:
	for m: String in got:
		var info: Dictionary = ItemDB.MATERIALS[m]
		Game.level.hud.log_pickup("+%d %s" % [int(got[m]), info["name"]], info["color"])


func _craft(rid: String) -> void:
	var r: Dictionary = ItemDB.RECIPES[rid]
	var h := player.hero
	var gold := int(r["gold_per_level"]) * h.level
	if h.gold < gold:
		Game.level.hud.show_warning("Sesterzi insufficienti")
		return
	var mats_req: Dictionary = r["mats"]
	for m: String in mats_req:
		if h.material(m) < int(mats_req[m]):
			Game.level.hud.show_warning("Materiali insufficienti")
			return
	if not h.inventory.has(null):
		Game.level.hud.show_warning("Inventario pieno")
		return
	var it := ItemDB.craft(rid, _slot_choice, h.level, h.class_id)
	if it == null:
		Game.level.hud.show_warning("Il %s non può usare questo tipo di oggetto" % player.cls["name"])
		return
	h.gold -= gold
	for m: String in mats_req:
		h.add_material(m, -int(mats_req[m]))
	h.add_item(it)
	Sfx.play("anvil")
	if it.is_special():
		Sfx.play("legendary")
	if source:
		Fx.burst(Game.world_root(), source.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.6, 0.2), 24, 5.0, 0.08, 0.6, -6.0, 60.0)
	Game.level.hud.log_pickup("Forgiato: %s" % it.item_name, it.color())
	_after_change()


# --- Gioielliere -------------------------------------------------------------------------------

func _build_jeweler() -> void:
	var h := player.hero
	content.add_child(_label(20, Hud.GOLD, "Sacchetto delle gemme"))
	var keys: Array = h.gems.keys()
	keys.sort()
	if not h.gems.has(_gem_choice):
		_gem_choice = String(keys[0]) if not keys.is_empty() else ""
	if keys.is_empty():
		content.add_child(_label(15, Color(0.6, 0.6, 0.6), "Nessuna gemma. Le lasciano nemici e forzieri: si raccolgono passandoci sopra."))
	for k: String in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var b := Button.new()
		b.text = "%s  ×%d" % [ItemDB.gem_name(k), h.gem_count(k)]
		b.toggle_mode = true
		b.button_pressed = k == _gem_choice
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(250, 32)
		b.add_theme_color_override("font_color", ItemDB.gem_color(k))
		b.add_theme_color_override("font_pressed_color", ItemDB.gem_color(k).lightened(0.4))
		b.tooltip_text = "Arma: %s\nElmo: %s\nAltro: %s" % [ItemDB.affix_text(ItemDB.gem_affix(k, "arma")),
			ItemDB.affix_text(ItemDB.gem_affix(k, "elmo")), ItemDB.affix_text(ItemDB.gem_affix(k, "armatura"))]
		b.pressed.connect(func() -> void:
			_gem_choice = k
			Sfx.play("ui_click")
			refresh.call_deferred())
		row.add_child(b)
		var tier := ItemDB.gem_tier(k)
		if tier < ItemDB.GEM_TIERS.size():
			var cost := ItemDB.GEM_COMBINE_GOLD * tier
			var c := Button.new()
			c.text = "Combina %d (%d sesterzi)" % [ItemDB.GEM_COMBINE_COST, cost]
			c.focus_mode = Control.FOCUS_NONE
			c.disabled = h.gem_count(k) < ItemDB.GEM_COMBINE_COST or h.gold < cost
			c.pressed.connect(combine_gem.bind(k))
			row.add_child(c)
		content.add_child(row)

	content.add_child(_label(20, Hud.GOLD, "Oggetti con orbite"))
	var any := false
	for slot: String in HeroData.EQUIP_SLOTS:
		var it: Item = h.equipment.get(slot)
		if it != null and not it.gems.is_empty():
			_socket_row(it, true)
			any = true
	for it: Variant in h.inventory:
		if it != null and not (it as Item).gems.is_empty():
			_socket_row(it, false)
			any = true
	if not any:
		content.add_child(_label(15, Color(0.6, 0.6, 0.6), "Nessun oggetto con orbite (indossato o nello zaino)."))
	content.add_child(_label(13, Color(0.6, 0.6, 0.6),
		"L'effetto di una gemma dipende da dove la incastoni: arma, elmo o altro.\nTogliere una gemma costa %d sesterzi per grado: la gemma torna nel sacchetto." % ItemDB.GEM_REMOVE_GOLD))


func _socket_row(it: Item, worn: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := _label(15, it.color(), ("%s  [indossato]" if worn else "%s") % it.item_name)
	lbl.custom_minimum_size = Vector2(230, 0)
	lbl.clip_text = true
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	lbl.mouse_entered.connect(func() -> void: inv.show_tooltip(it.tooltip_bbcode(), true))
	lbl.mouse_exited.connect(inv.hide_tooltip)
	row.add_child(lbl)
	for i in it.gems.size():
		var g: String = it.gems[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(80, 30)
		b.clip_text = true
		if g == "":
			b.text = "◇ vuota"
			b.disabled = _gem_choice == ""
		else:
			b.text = "◆ " + ItemDB.GEMS[ItemDB.gem_type(g)]["name"]
			b.add_theme_color_override("font_color", ItemDB.gem_color(g))
			b.tooltip_text = "%s: %s\nClic: togli (%d sesterzi)" % [ItemDB.gem_name(g),
				ItemDB.affix_text(ItemDB.gem_affix(g, it.slot)), ItemDB.GEM_REMOVE_GOLD * ItemDB.gem_tier(g)]
		b.pressed.connect(_on_socket.bind(it, i))
		row.add_child(b)
	content.add_child(row)


func _on_socket(it: Item, i: int) -> void:
	if String(it.gems[i]) == "":
		socket_gem(it, i, _gem_choice)
	else:
		unsocket_gem(it, i)


## Incastona una gemma del sacchetto nell'orbita i dell'oggetto. Ritorna true se riuscito.
func socket_gem(it: Item, i: int, key: String) -> bool:
	var h := player.hero
	if key == "" or h.gem_count(key) <= 0 or i >= it.gems.size() or String(it.gems[i]) != "":
		return false
	h.add_gem(key, -1)
	it.gems[i] = key
	Sfx.play("anvil", null, -8.0)
	Game.level.hud.log_pickup("Incastonato: %s" % ItemDB.gem_name(key), ItemDB.gem_color(key))
	player.refresh_stats()
	_after_change()
	return true


func unsocket_gem(it: Item, i: int) -> bool:
	var h := player.hero
	var key := String(it.gems[i])
	if key == "":
		return false
	var cost := ItemDB.GEM_REMOVE_GOLD * ItemDB.gem_tier(key)
	if h.gold < cost:
		Game.level.hud.show_warning("Sesterzi insufficienti")
		return false
	h.gold -= cost
	it.gems[i] = ""
	h.add_gem(key)
	Sfx.play("coins")
	player.refresh_stats()
	_after_change()
	return true


## 3 gemme uguali -> 1 del grado superiore.
func combine_gem(key: String) -> bool:
	var h := player.hero
	var tier := ItemDB.gem_tier(key)
	var cost := ItemDB.GEM_COMBINE_GOLD * tier
	if tier >= ItemDB.GEM_TIERS.size() or h.gem_count(key) < ItemDB.GEM_COMBINE_COST or h.gold < cost:
		return false
	h.gold -= cost
	h.add_gem(key, -ItemDB.GEM_COMBINE_COST)
	var up := ItemDB.gem_key(ItemDB.gem_type(key), tier + 1)
	h.add_gem(up)
	_gem_choice = up
	Sfx.play("anvil")
	Game.level.hud.log_pickup("Combinato: %s" % ItemDB.gem_name(up), ItemDB.gem_color(up))
	_after_change()
	return true


## Aggiorna inventario e pannello (il pannello si ricostruisce al frame dopo, tramite il segnale).
func _after_change() -> void:
	player.inventory_changed.emit()


func _label(size: int, color: Color, text: String = "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
