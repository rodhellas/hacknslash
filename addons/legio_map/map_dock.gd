@tool
extends VBoxContainer
## Pannello "Mappa" dell'editor (plugin Legio Map).
##   Forma        aggiunge strade, aree, radure, acqua e terra al nodo Forma del livello aperto
##   Costruzione  "Ricostruisci terreno" rigenera terreno/confini/strade/acqua/vegetazione/lampioni
##                + navmesh dalla Forma, senza toccare ciò che hai piazzato a mano
##   Pianta       esporta la pianta dall'alto in docs/mappe/<livello>.png e la mostra qui
##   Oggetti      inserisce un oggetto di scena al centro della vista 3D (in World/Luoghi/Aggiunti)

const PROPS_DIR := "res://scenes/props/"

var plugin: EditorPlugin
var status: Label
var report: RichTextLabel
var preview: TextureRect
var preview_label: Label
var props: ItemList
var _prop_paths: Array = []


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	custom_minimum_size = Vector2(280, 0)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	scroll.add_child(v)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(status)

	v.add_child(_title("Forma"))
	var grid := GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	for pair: Array in [["Crea Forma", _create_shape], ["+ Strada", _add_road], ["+ Area", _add_area],
			["+ Radura", _add_clearing], ["+ Acqua", _add_water], ["+ Terra", _add_land]]:
		var b := Button.new()
		b.text = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(pair[1])
		grid.add_child(b)
	v.add_child(_hint("Strade e poligoni: trascina i punti della curva (Ctrl+clic per aggiungerne). Aree: sposta il nodo e cambia il raggio nell'Inspector. Zone: data/map_zones.gd."))

	v.add_child(_title("Costruzione"))
	var rebuild := Button.new()
	rebuild.text = "Ricostruisci terreno"
	rebuild.custom_minimum_size = Vector2(0, 36)
	rebuild.pressed.connect(_rebuild)
	v.add_child(rebuild)
	var nav := Button.new()
	nav.text = "Ricalcola solo la navmesh"
	nav.pressed.connect(_bake_only)
	v.add_child(nav)
	v.add_child(_hint("Rigenera solo i gruppi Terreno, Confini, Strade, Acqua, Vegetazione e ArredoStradale sotto World. Salva la scena prima: la ricostruzione non si annulla con Ctrl+Z (ricarica la scena per tornare indietro)."))
	report = RichTextLabel.new()
	report.fit_content = true
	report.bbcode_enabled = true
	report.selection_enabled = true
	v.add_child(report)

	v.add_child(_title("Pianta"))
	var exp := Button.new()
	exp.text = "Esporta pianta (PNG)"
	exp.pressed.connect(_export_png)
	v.add_child(exp)
	preview_label = _hint("")
	v.add_child(preview_label)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(0, 260)
	v.add_child(preview)

	v.add_child(_title("Oggetti di scena"))
	props = ItemList.new()
	props.custom_minimum_size = Vector2(0, 260)
	props.max_columns = 2
	props.same_column_width = true
	props.fixed_icon_size = Vector2i(48, 48)
	props.item_activated.connect(func(_i: int) -> void: _insert_prop())
	v.add_child(props)
	var ins := Button.new()
	ins.text = "Inserisci al centro della vista"
	ins.pressed.connect(_insert_prop)
	v.add_child(ins)
	v.add_child(_hint("Doppio clic su un oggetto per inserirlo. Puoi anche trascinare i .tscn da scenes/props nel viewport. Ricorda di ricalcolare la navmesh dopo."))
	_fill_props()
	if plugin:
		plugin.scene_changed.connect(func(_r: Node) -> void: _update_status())
	_update_status()


# --- Stato ----------------------------------------------------------------------------------------

func _root() -> Node3D:
	return EditorInterface.get_edited_scene_root() as Node3D


func _shape() -> MapShape:
	var r := _root()
	return MapBuilder.find_shape(r) if r else null


func _update_status() -> void:
	if status == null:
		return
	var r := _root()
	if r == null:
		status.text = "Apri un livello (scenes/levels/*.tscn)."
		return
	var s := _shape()
	if s == null:
		status.text = "Scena: %s\nNessuna Forma: premi \"Crea Forma\"." % r.name
	else:
		status.text = "Scena: %s\nForma: %d strade, %d aree, %d poligoni." % [r.name, s.roads().size(), s.areas().size(), s.polygons().size()]
	var png := MapPreview.OUT_DIR + r.scene_file_path.get_file().get_basename() + ".png"
	if FileAccess.file_exists(png):
		_show_png(png)


# --- Forma ----------------------------------------------------------------------------------------

func _create_shape() -> void:
	var r := _root()
	if r == null or _shape() != null:
		return
	var s := MapShape.new()
	s.name = "Forma"
	_add_node(r, s)


func _add_road() -> void:
	var road := MapRoad.new()
	road.name = "Strada"
	road.half_width = 8.0
	road.paved_width = 4.0
	road.curve = Curve3D.new()
	road.curve.add_point(Vector3(0, 0, 15))
	road.curve.add_point(Vector3(0, 0, -15))
	_add_to_shape(road)


func _add_area() -> void:
	var a := MapArea.new()
	a.name = "Area"
	a.radius = 15.0
	_add_to_shape(a)


func _add_clearing() -> void:
	var a := MapArea.new()
	a.name = "Radura"
	a.radius = 10.0
	a.walkable = false
	a.scatter = false
	_add_to_shape(a)


func _add_water() -> void:
	_add_polygon("Acqua", "acqua")


func _add_land() -> void:
	_add_polygon("Terra", "terra")


func _add_polygon(n: String, mode: String) -> void:
	var p := MapPolygon.new()
	p.name = n
	p.mode = mode
	p.curve = Curve3D.new()
	for c: Vector3 in [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 12), Vector3(-12, 0, 12)]:
		p.curve.add_point(c)
	_add_to_shape(p)


func _add_to_shape(n: Node3D) -> void:
	var s := _shape()
	if s == null:
		_create_shape()
		s = _shape()
	if s == null:
		push_warning("Apri prima un livello.")
		return
	n.position = s.to_local(_view_center())
	_add_node(s, n)


func _add_node(parent: Node, n: Node) -> void:
	var r := _root()
	var ur := plugin.get_undo_redo()
	ur.create_action("Mappa: aggiungi %s" % n.name)
	ur.add_do_method(parent, "add_child", n, true)
	ur.add_do_method(n, "set_owner", r)
	ur.add_do_reference(n)
	ur.add_undo_method(parent, "remove_child", n)
	ur.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(n)
	_update_status()


func _view_center() -> Vector3:
	var vp := EditorInterface.get_editor_viewport_3d(0)
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return Vector3.ZERO
	var c := Vector2(vp.size) * 0.5
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(c), cam.project_ray_normal(c))
	return hit if hit != null else Vector3.ZERO


# --- Costruzione ----------------------------------------------------------------------------------

func _rebuild() -> void:
	var r := _root()
	if r == null:
		return
	report.text = "Ricostruzione in corso..."
	var b := MapBuilder.new()
	var rep := b.build(r, true)
	report.text = rep.replace("ATTENZIONE", "[color=#ff8060]ATTENZIONE[/color]")
	EditorInterface.mark_scene_as_unsaved()
	_update_status()
	_export_png()


func _bake_only() -> void:
	var r := _root()
	var w := r.get_node_or_null("World") as NavigationRegion3D if r else null
	if w == null:
		report.text = "Nessun nodo World (NavigationRegion3D) nel livello."
		return
	w.bake_navigation_mesh(false)
	EditorInterface.mark_scene_as_unsaved()
	report.text = "Navmesh ricalcolata: %d poligoni." % (w.navigation_mesh.get_polygon_count() if w.navigation_mesh else 0)


# --- Pianta ---------------------------------------------------------------------------------------

func _export_png() -> void:
	var r := _root()
	if r == null:
		return
	var path := MapPreview.export(r, r.scene_file_path if r.scene_file_path != "" else String(r.name))
	if path == "":
		preview_label.text = "Pianta non disponibile: il livello non ha una Forma."
		return
	_show_png(path)
	EditorInterface.get_resource_filesystem().scan()


func _show_png(path: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null:
		return
	preview.texture = ImageTexture.create_from_image(img)
	preview_label.text = "%s  (%d × %d px, 2 px = 1 m; nord in alto)" % [path, img.get_width(), img.get_height()]


# --- Oggetti di scena -----------------------------------------------------------------------------

func _fill_props() -> void:
	props.clear()
	_prop_paths.clear()
	var files := DirAccess.get_files_at(PROPS_DIR)
	for f in files:
		if not f.ends_with(".tscn"):
			continue
		var path := PROPS_DIR + f
		var idx := props.add_item(f.get_basename())
		_prop_paths.append(path)
		EditorInterface.get_resource_previewer().queue_resource_preview(path, self, "_on_preview", idx)


func _on_preview(_path: String, tex: Texture2D, _thumb: Texture2D, idx: int) -> void:
	if tex != null and idx < props.item_count:
		props.set_item_icon(idx, tex)


func _insert_prop() -> void:
	var sel := props.get_selected_items()
	var r := _root()
	if sel.is_empty() or r == null:
		return
	var scene := load(_prop_paths[sel[0]]) as PackedScene
	var inst := scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	var parent := _ensure_group(r, ["World", "Luoghi", "Aggiunti"])
	inst.position = (parent as Node3D).to_local(_view_center())
	_add_node(parent, inst)


func _ensure_group(r: Node, path: Array) -> Node:
	var cur := r
	for part: String in path:
		var next := cur.get_node_or_null(part)
		if next == null:
			next = Node3D.new()
			next.name = part
			cur.add_child(next)
			next.owner = r
		cur = next
	return cur


func _title(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	return l


func _hint(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	return l
