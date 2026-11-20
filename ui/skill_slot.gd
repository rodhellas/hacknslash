class_name SkillSlot
extends Control
## Casella della barra abilità: mostra tasto, sigla, ricarica, blocco per livello.

var ability: Dictionary = {}
var key_text := ""
var cd_left := 0.0
var cd_total := 1.0
var locked := false
var unaffordable := false
var label_override := ""
var color := Color(0.5, 0.5, 0.5)
## Icona (textures/icone); senza icona si disegna la sigla.
var icon: Texture2D = null


func _ready() -> void:
	custom_minimum_size = Vector2(62, 62)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_ability(ab: Dictionary, key: String) -> void:
	ability = ab
	key_text = key
	color = ab.get("color", Color.GRAY)
	icon = Icons.ability(String(ab.get("id", "")))
	tooltip_text = "%s  [%s]\n%s" % [ab.get("name", ""), key, ab.get("desc", "")]
	if String(ab.get("rune_name", "")) != "":
		var r := SkillDB.find_rune(String(ab.get("id", "")), String(ab.get("rune", "")))
		tooltip_text += "\nVariante: %s – %s" % [ab["rune_name"], r.get("desc", "")]
	if ab.has("cost"):
		tooltip_text += "\nCosto: %d" % int(ab["cost"])
	if ab.has("cooldown"):
		tooltip_text += "\nRicarica: %.0f s" % float(ab["cooldown"])
	if int(ab.get("unlock", 1)) > 1:
		tooltip_text += "\nSi sblocca al livello %d" % int(ab["unlock"])


func _process(_delta: float) -> void:
	queue_redraw()


func _abbrev() -> String:
	if label_override != "":
		return label_override
	var words := String(ability.get("name", "?")).split(" ", false)
	var s := ""
	for w in words:
		if w.length() > 2:
			s += w[0].to_upper()
	return s.left(3)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.05, 0.04, 0.03))
	var font := get_theme_default_font()
	if icon != null:
		draw_texture_rect(icon, rect.grow(-3), false)
	else:
		draw_rect(rect.grow(-4), color.darkened(0.55))
		draw_string_outline(font, Vector2(0, size.y * 0.62), _abbrev(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 4, Color.BLACK)
		draw_string(font, Vector2(0, size.y * 0.62), _abbrev(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, color.lightened(0.4))
	if unaffordable:
		draw_rect(rect.grow(-4), Color(0.1, 0.2, 0.7, 0.45))
	if cd_left > 0.0 and cd_total > 0.0:
		var f := clampf(cd_left / cd_total, 0.0, 1.0)
		draw_rect(Rect2(4, 4, size.x - 8, (size.y - 8) * f), Color(0, 0, 0, 0.65))
		draw_string_outline(font, Vector2(0, size.y * 0.62), "%.0f" % ceilf(cd_left), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, 4, Color.BLACK)
		draw_string(font, Vector2(0, size.y * 0.62), "%.0f" % ceilf(cd_left), HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color.WHITE)
	if locked:
		draw_rect(rect.grow(-4), Color(0, 0, 0, 0.75))
		draw_string(font, Vector2(0, size.y * 0.58), "Liv. %d" % int(ability.get("unlock", 1)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(0.7, 0.7, 0.7))
	draw_rect(rect, Color(0.6, 0.48, 0.25), false, 2.0)
	draw_string_outline(font, Vector2(4, 14), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color.BLACK)
	draw_string(font, Vector2(4, 14), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.9, 0.6))
