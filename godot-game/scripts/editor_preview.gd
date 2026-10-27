@tool
extends Node2D

const CAMPUS_BACKGROUND := preload("res://assets/gachon_campus_pixel_background.png")
const DOOR_TEXTURE := preload("res://assets/genre_portal_door_pixel.png")
const STAGES := ["CARD", "PLATFORM", "RHYTHM", "ROGUELIKE", "SHOOTER", "FINAL BOSS"]
const STAGE_COLORS := [
	Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"),
	Color("#118ab2"), Color("#8b5cf6"), Color("#f97316")
]
const WORLD_WIDTH := 4650.0


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, WORLD_WIDTH, 540), Color("#070a14"))
	draw_campus_strip()
	draw_rect(Rect2(0, 70, WORLD_WIDTH, 385), Color("#07101f66"))
	draw_rect(Rect2(0, 455, WORLD_WIDTH, 85), Color("#1f2937"))
	draw_rect(Rect2(0, 455, WORLD_WIDTH, 8), Color("#64748b"))

	for i in STAGES.size():
		draw_room_door(i, 680.0 + float(i) * 700.0)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(145, 425), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#cbd5e1"))


func draw_campus_strip() -> void:
	var segment_height := 385.0
	var scale_value: float = segment_height / float(CAMPUS_BACKGROUND.get_height())
	var segment_width: float = float(CAMPUS_BACKGROUND.get_width()) * scale_value
	var segment_count := int(ceil(WORLD_WIDTH / segment_width))
	for i in segment_count:
		var segment_x := float(i) * segment_width
		if i % 2 == 0:
			draw_set_transform(Vector2(segment_x, 70), 0.0, Vector2(scale_value, scale_value))
		else:
			draw_set_transform(Vector2(segment_x + segment_width, 70), 0.0, Vector2(-scale_value, scale_value))
		draw_texture(CAMPUS_BACKGROUND, Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_room_door(index: int, door_x: float) -> void:
	var accent: Color = STAGE_COLORS[index]
	var aura := PackedVector2Array([
		Vector2(door_x - 135, 455), Vector2(door_x + 135, 455),
		Vector2(door_x + 126, 226), Vector2(door_x + 78, 150),
		Vector2(door_x, 114), Vector2(door_x - 78, 150), Vector2(door_x - 126, 226)
	])
	draw_colored_polygon(aura, Color(accent, 0.22))
	var target_height := 350.0
	var door_width: float = float(DOOR_TEXTURE.get_width()) * target_height / float(DOOR_TEXTURE.get_height())
	draw_texture_rect(DOOR_TEXTURE, Rect2(door_x - door_width / 2.0, 105, door_width, target_height), false)

	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(door_x - 75, 205), "ROOM %02d" % (index + 1), HORIZONTAL_ALIGNMENT_CENTER, 150, 17, Color.WHITE)
	draw_string(font, Vector2(door_x - 68, 267), STAGES[index], HORIZONTAL_ALIGNMENT_CENTER, 136, 16, Color.WHITE)
	var badge_color := Color("#166534") if index == 0 else Color("#7f1d1d")
	var status := "OPEN" if index == 0 else "LOCKED"
	draw_rect(Rect2(door_x - 42, 404, 84, 29), badge_color)
	draw_string(font, Vector2(door_x - 42, 426), status, HORIZONTAL_ALIGNMENT_CENTER, 84, 13, Color.WHITE)
