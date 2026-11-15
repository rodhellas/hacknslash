class_name Loot
extends RefCounted
## Genera a terra oggetti, sesterzi e globi di vita.


static func on_enemy_killed(e: Enemy) -> void:
	var source := "unique" if e.unique else ("elite" if e.elite else "normal")
	drop(source, e.global_position, e.level)
	var globe_chance := 0.6 if (e.elite or e.unique) else 0.16
	if randf() < globe_chance:
		var g := HealthGlobe.new()
		g.position = _scatter(e.global_position, 1.5)
		Game.world_root().add_child.call_deferred(g)


static func drop(source: String, pos: Vector3, ilvl: int) -> void:
	if Game.hero == null:
		return
	var gold_find := 0.0
	if Game.level and Game.level.player:
		gold_find = float(Game.level.player.stats.get("gold_find", 0.0))
	for it: Item in ItemDB.roll_drops(source, ilvl, Game.hero.class_id):
		spawn_item(it, pos)
	var g := ItemDB.roll_gold(source, ilvl, gold_find)
	if g > 0:
		var d := LootDrop.make_gold(g)
		d.position = _scatter(pos, 1.8)
		Game.world_root().add_child.call_deferred(d)


static func spawn_item(it: Item, pos: Vector3) -> void:
	var d := LootDrop.make_item(it)
	d.position = _scatter(pos, 1.8)
	Game.world_root().add_child.call_deferred(d)


static func _scatter(pos: Vector3, r: float) -> Vector3:
	var a := randf() * TAU
	var d := randf_range(0.5, r)
	return Vector3(pos.x + cos(a) * d, 0.0, pos.z + sin(a) * d)
