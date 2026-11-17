class_name LootDrop
extends Area3D
## Oggetto o sesterzi a terra. Gli oggetti si raccolgono cliccandoci (o con E),
## i sesterzi passandoci sopra. Il nome è colorato in base alla rarità, come in Diablo.

var item: Item = null
var gold := 0
var gem := ""   # chiave di una gemma ("rubino:2"): si raccoglie passandoci sopra come i sesterzi
var _visual: Node3D


static func make_item(it: Item) -> LootDrop:
	var d := LootDrop.new()
	d.item = it
	return d


static func make_gem(key: String) -> LootDrop:
	var d := LootDrop.new()
	d.gem = key
	return d


static func make_gold(amount: int) -> LootDrop:
	var d := LootDrop.new()
	d.gold = amount
	return d


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = Layers.INTERACT
	collision_mask = Layers.PLAYER if item == null else 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.7
	shape.shape = sphere
	shape.position.y = 0.4
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label.pixel_size = 0.008
	label.visibility_range_end = 40.0
	label.position.y = 1.0
	add_child(label)

	if item != null:
		var col := item.color()
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.22, 0.35)
		box.mesh = bm
		box.material_override = Fx.mat(col, 2.5 if item.rarity >= Item.Rarity.RARO else 0.4)
		box.position.y = 0.11
		_visual.add_child(box)
		label.text = item.item_name
		label.modulate = col
		label.font_size = 30
		if item.rarity >= Item.Rarity.RARO:
			var beam := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var h := 9.0 if item.is_special() else 3.5
			cm.top_radius = 0.12
			cm.bottom_radius = 0.18
			cm.height = h
			beam.mesh = cm
			var bc := col
			bc.a = 0.45
			beam.material_override = Fx.mat(bc, 3.0, true, true)
			beam.position.y = h * 0.5
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_visual.add_child(beam)
			Fx.minimap_icon(self, col, 1.2, "square")
			Sfx.play("legendary" if item.is_special() else "rare_drop", global_position)
	elif gem != "":
		var gc := ItemDB.gem_color(gem)
		var stone := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.26
		sm.radial_segments = 6
		sm.rings = 2
		stone.mesh = sm
		stone.material_override = Fx.mat(gc, 2.5)
		stone.position.y = 0.16
		_visual.add_child(stone)
		label.text = ItemDB.gem_name(gem)
		label.modulate = gc
		label.font_size = 24
		Fx.minimap_icon(self, gc, 1.0, "square")
		body_entered.connect(_on_body_entered)
	else:
		for i in 3:
			var coin := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.14
			cm.bottom_radius = 0.14
			cm.height = 0.05
			coin.mesh = cm
			coin.material_override = Fx.mat(Color(1.0, 0.8, 0.2), 1.0)
			coin.position = Vector3(randf_range(-0.2, 0.2), 0.03 + i * 0.05, randf_range(-0.2, 0.2))
			_visual.add_child(coin)
		label.text = "%d sesterzi" % gold
		label.modulate = Color(1.0, 0.85, 0.3)
		label.font_size = 22
		body_entered.connect(_on_body_entered)

	# Piccolo "salto" quando cade a terra
	_visual.position.y = 1.2
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func interact_name() -> String:
	if item != null:
		return item.item_name
	return ItemDB.gem_name(gem) if gem != "" else "%d sesterzi" % gold


func can_interact() -> bool:
	return true


func interact(p: Player) -> void:
	if item == null:
		_take_gold()
		return
	if Game.hero.add_item(item):
		Game.level.hud.log_pickup(item.item_name, item.color())
		Sfx.play("pickup")
		p.inventory_changed.emit()
		queue_free()
	else:
		Game.level.hud.show_warning("Inventario pieno")


func _on_body_entered(body: Node) -> void:
	if body is Player:
		_take_gold()


func _take_gold() -> void:
	if is_queued_for_deletion():
		return
	if gem != "":
		Game.hero.add_gem(gem)
		Game.level.hud.log_pickup(ItemDB.gem_name(gem), ItemDB.gem_color(gem))
		Sfx.play("pickup")
		Game.level.player.inventory_changed.emit()
		queue_free()
		return
	Game.hero.gold += gold
	Game.level.hud.log_pickup("+%d sesterzi" % gold, Color(1.0, 0.85, 0.3))
	Sfx.play("gold")
	var p := Game.level.player
	if p and p.has_power("cesare"):
		p.heal(float(p.stats["max_life"]) * 0.02, false)
	queue_free()
