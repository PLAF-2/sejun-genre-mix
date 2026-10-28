extends Node2D

const STAGES := ["CARD", "PLATFORM", "RHYTHM", "ROGUELIKE", "SHOOTER", "FINAL BOSS"]
const STAGE_COLORS := [
	Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"),
	Color("#118ab2"), Color("#8b5cf6"), Color("#f97316")
]
const HERO_TEXTURE := preload("res://assets/characters/hero_walk_user_v3.png")
const CAMPUS_BACKGROUND := preload("res://assets/gachon_campus_pixel_background.png")
const DOOR_TEXTURE := preload("res://assets/platform/ordinary_door.svg")
const WORLD_WIDTH := 4650.0
const FLOOR_Y := 455.0
const WALK_SPEED := 260.0
const GRAVITY := 1500.0
const SETTINGS_PATH := "user://settings.cfg"
const CARD_GAME_SCRIPT := preload("res://scripts/card_game.gd")
const PLATFORM_GAME_SCRIPT := preload("res://scripts/platform_game.gd")
const RHYTHM_GAME_SCRIPT := preload("res://scripts/rhythm_game.gd")
const ROGUELIKE_GAME_SCRIPT := preload("res://scripts/roguelike_game.gd")
const SHOOTER_GAME_SCRIPT := preload("res://scripts/shooter_game.gd")

var player: CharacterBody2D
var hero_sprite: AnimatedSprite2D
var nearby_stage := -1
var cleared_count := 0
var door_bodies: Array[StaticBody2D] = []
var door_centers: Array[float] = []
var door_visuals: Array[Sprite2D] = []
var door_status_labels: Array[Label] = []
var door_status_badges: Array[Polygon2D] = []
var prompt_label: Label
var progress_label: Label
var overlay: Control
var overlay_title: Label
var overlay_button: Button
var settings_overlay: Control
var bgm_slider: HSlider
var sfx_slider: HSlider
var bgm_value_label: Label
var sfx_value_label: Label
var card_game: Control
var platform_game: Control
var rhythm_game: Control
var roguelike_game: Control
var shooter_game: Control
var final_boss_game: Control
var skip_button: Button
var dev_room_override := -1


func _ready() -> void:
	ThemeDB.fallback_font = preload("res://assets/fonts/NanumGothic-Regular.ttf")
	process_mode = Node.PROCESS_MODE_ALWAYS
	$EditorPreview.visible = false
	ensure_audio_buses()
	build_world()
	build_player()
	build_hud()
	# Main keeps receiving ESC; gameplay must not inherit its ALWAYS mode.
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	load_audio_settings()
	if "--card-preview" in OS.get_cmdline_user_args() or "--card-preview" in OS.get_cmdline_args():
		call_deferred("_start_card_preview")
	elif "--platform-preview" in OS.get_cmdline_user_args() or "--platform-preview" in OS.get_cmdline_args():
		call_deferred("_start_platform_preview")
	elif "--rhythm-preview" in OS.get_cmdline_user_args() or "--rhythm-preview" in OS.get_cmdline_args():
		call_deferred("_start_rhythm_preview")
	elif "--roguelike-preview" in OS.get_cmdline_user_args() or "--roguelike-preview" in OS.get_cmdline_args():
		call_deferred("_start_roguelike_preview")
	elif "--shooter-preview" in OS.get_cmdline_user_args() or "--shooter-preview" in OS.get_cmdline_args():
		call_deferred("_start_shooter_preview")
	elif "--boss-preview" in OS.get_cmdline_user_args() or "--boss-preview" in OS.get_cmdline_args():
		call_deferred("_start_boss_preview")
	if "--full-flow-auto-test" in OS.get_cmdline_user_args() or "--full-flow-auto-test" in OS.get_cmdline_args():
		call_deferred("debug_test_full_progression")


func _start_card_preview() -> void:
	await get_tree().process_frame
	card_game.start_game()


func _start_platform_preview() -> void:
	await get_tree().process_frame
	platform_game.start_game()


func _start_rhythm_preview() -> void:
	await get_tree().process_frame
	rhythm_game.start_game()


func _start_roguelike_preview() -> void:
	await get_tree().process_frame
	roguelike_game.start_game()


func _start_shooter_preview() -> void:
	await get_tree().process_frame
	shooter_game.start_game()


func _start_boss_preview() -> void:
	await get_tree().process_frame
	final_boss_game.start_game()


func debug_test_full_progression() -> void:
	await get_tree().process_frame
	var rooms: Array[Control] = [card_game, platform_game, rhythm_game, roguelike_game, shooter_game, final_boss_game]
	for room_index in STAGES.size():
		open_room(room_index)
		await get_tree().process_frame
		if not rooms[room_index].visible:
			push_error("Full progression test failed to open room %d" % [room_index + 1])
			get_tree().quit(1)
			return
		rooms[room_index].visible = false
		rooms[room_index].emit_signal("game_won")
		await get_tree().process_frame
		if cleared_count != room_index + 1:
			push_error("Full progression test failed after room %d" % [room_index + 1])
			get_tree().quit(1)
			return
	if cleared_count != STAGES.size() or not skip_button.disabled:
		push_error("Full progression test failed to reach ALL CLEAR")
		get_tree().quit(1)
		return
	print("FULL FLOW AUTO TEST: ALL CLEAR")
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if dev_room_override >= 0 and not any_room_visible():
		dev_room_override = -1
	if overlay.visible or settings_overlay.visible or card_game.visible or platform_game.visible or rhythm_game.visible or roguelike_game.visible or shooter_game.visible or final_boss_game.visible:
		player.velocity = Vector2.ZERO
		return

	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0

	player.velocity.x = direction * WALK_SPEED
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	else:
		player.velocity.y = 0.0

	if direction != 0.0:
		hero_sprite.flip_h = direction < 0.0
		hero_sprite.play("walk")
	else:
		hero_sprite.pause()
		hero_sprite.frame = 0

	player.move_and_slide()
	update_door_interaction()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			toggle_settings()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F11:
			toggle_fullscreen()
		elif event.keycode == KEY_F2 and not settings_overlay.visible:
			dev_skip_current_room()
		elif event.keycode == KEY_E and nearby_stage == cleared_count and not overlay.visible and not settings_overlay.visible:
			open_room(nearby_stage)
		elif not settings_overlay.visible and not any_room_visible() and room_number_from_key(event.keycode) >= 0:
			dev_open_room(room_number_from_key(event.keycode))


func build_world() -> void:
	add_rect(Vector2(0, 0), Vector2(WORLD_WIDTH, 540), Color("#070a14"))
	build_campus_background()
	add_rect(Vector2(0, 70), Vector2(WORLD_WIDTH, 385), Color("#07101f66"))
	add_rect(Vector2(0, FLOOR_Y), Vector2(WORLD_WIDTH, 85), Color("#1f2937"))
	add_rect(Vector2(0, FLOOR_Y), Vector2(WORLD_WIDTH, 8), Color("#64748b"))

	var floor_body := StaticBody2D.new()
	var floor_shape := CollisionShape2D.new()
	var floor_rectangle := RectangleShape2D.new()
	floor_rectangle.size = Vector2(WORLD_WIDTH, 90)
	floor_shape.shape = floor_rectangle
	floor_shape.position = Vector2(WORLD_WIDTH / 2.0, FLOOR_Y + 45)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	for i in STAGES.size():
		var door_x := 680.0 + i * 700.0
		build_room_gate(i, door_x)

	var start_label := make_world_label("START", 24, Color("#94a3b8"))
	start_label.position = Vector2(150, 395)
	add_child(start_label)


func build_campus_background() -> void:
	var segment_height := 385.0
	var segment_width: float = float(CAMPUS_BACKGROUND.get_width()) * segment_height / float(CAMPUS_BACKGROUND.get_height())
	var segment_count := int(ceil(WORLD_WIDTH / segment_width))
	for i in segment_count:
		var campus := Sprite2D.new()
		campus.texture = CAMPUS_BACKGROUND
		campus.centered = false
		campus.position = Vector2(float(i) * segment_width, 70)
		campus.scale = Vector2(segment_height / float(CAMPUS_BACKGROUND.get_height()), segment_height / float(CAMPUS_BACKGROUND.get_height()))
		campus.flip_h = i % 2 == 1
		campus.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(campus)


func build_room_gate(index: int, door_x: float) -> void:
	door_centers.append(door_x)

	var door := Sprite2D.new()
	var target_height := 172.0
	var door_scale: float = target_height / float(DOOR_TEXTURE.get_height())
	var rendered_width: float = float(DOOR_TEXTURE.get_width()) * door_scale
	door.texture = DOOR_TEXTURE
	door.centered = false
	door.position = Vector2(door_x - rendered_width / 2.0, 283)
	door.scale = Vector2(door_scale, door_scale)
	door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	door.modulate = Color.WHITE.lerp(STAGE_COLORS[index], 0.14)
	add_child(door)
	door_visuals.append(door)

	var number_label := make_world_label("ROOM %02d" % (index + 1), 17, Color("#f8fafc"))
	number_label.position = Vector2(door_x - 75, 234)
	number_label.size = Vector2(150, 26)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.add_theme_color_override("font_outline_color", Color("#020617"))
	number_label.add_theme_constant_override("outline_size", 6)
	add_child(number_label)
	var genre_label := make_world_label(STAGES[index], 16, Color("#f8fafc"))
	genre_label.position = Vector2(door_x - 68, 261)
	genre_label.size = Vector2(136, 30)
	genre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	genre_label.add_theme_color_override("font_outline_color", Color("#020617"))
	genre_label.add_theme_constant_override("outline_size", 6)
	add_child(genre_label)

	var badge_color := Color("#166534") if index == 0 else Color("#7f1d1d")
	var status_badge := add_rect(Vector2(door_x - 42, 460), Vector2(84, 23), badge_color)
	door_status_badges.append(status_badge)
	var status_label := make_world_label("OPEN" if index == 0 else "LOCKED", 13, Color.WHITE)
	status_label.position = Vector2(door_x - 42, 461)
	status_label.size = Vector2(84, 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door_status_labels.append(status_label)
	add_child(status_label)

	var blocker := StaticBody2D.new()
	var blocker_shape := CollisionShape2D.new()
	var blocker_rectangle := RectangleShape2D.new()
	blocker_rectangle.size = Vector2(26, 265)
	blocker_shape.shape = blocker_rectangle
	blocker_shape.position = Vector2(door_x + 108.0, 322.5)
	blocker.add_child(blocker_shape)
	add_child(blocker)
	door_bodies.append(blocker)



func update_door_interaction() -> void:
	var centered_stage := -1
	var closest_distance := 48.0
	for i in door_centers.size():
		var distance := absf(player.position.x - door_centers[i])
		if distance <= closest_distance:
			closest_distance = distance
			centered_stage = i

	if centered_stage == nearby_stage:
		return
	nearby_stage = centered_stage
	if nearby_stage == -1:
		prompt_label.visible = false
		return
	if nearby_stage == cleared_count:
		prompt_label.text = "[ E ]  ROOM %d 입장 · %s" % [nearby_stage + 1, STAGES[nearby_stage]]
	else:
		prompt_label.text = "LOCKED · 이전 방을 먼저 클리어하세요"
	prompt_label.visible = true


func build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(200, 410)
	player.collision_layer = 1
	player.collision_mask = 1

	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 15
	capsule.height = 54
	collider.shape = capsule
	collider.position = Vector2(0, -27)
	player.add_child(collider)

	hero_sprite = AnimatedSprite2D.new()
	hero_sprite.sprite_frames = make_hero_frames()
	hero_sprite.animation = "walk"
	hero_sprite.scale = Vector2(0.082, 0.082)
	hero_sprite.position = Vector2(0, -31)
	hero_sprite.play("walk")
	player.add_child(hero_sprite)

	var camera := Camera2D.new()
	camera.position = Vector2(210, -120)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0
	camera.limit_right = int(WORLD_WIDTH)
	camera.limit_top = 0
	camera.limit_bottom = 540
	player.add_child(camera)
	add_child(player)


func make_hero_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	var frame_width := HERO_TEXTURE.get_width() / 4.0
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = HERO_TEXTURE
		atlas.region = Rect2(frame_width * i, 0, frame_width, HERO_TEXTURE.get_height())
		frames.add_frame("walk", atlas)
	return frames


func build_hud() -> void:
	var canvas: CanvasLayer = $GameCanvas

	var top_bar := ColorRect.new()
	top_bar.color = Color("#0f172aee")
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(960, 72)
	canvas.add_child(top_bar)

	progress_label = Label.new()
	progress_label.position = Vector2(24, 18)
	progress_label.size = Vector2(912, 36)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 19)
	progress_label.text = "ROOM 1 / 6  ·  CARD"
	canvas.add_child(progress_label)

	var dev_hint := Label.new()
	dev_hint.position = Vector2(18, 505)
	dev_hint.size = Vector2(330, 25)
	dev_hint.text = "DEV 바로 입장  [1] [2] [3] [4] [5] [6]"
	dev_hint.add_theme_font_size_override("font_size", 14)
	dev_hint.add_theme_color_override("font_color", Color("#94a3b8"))
	canvas.add_child(dev_hint)

	var control_hint := Label.new()
	control_hint.position = Vector2(475, 505)
	control_hint.size = Vector2(465, 25)
	control_hint.text = "A/D 또는 ←/→ 이동 · E 입장 · ESC 설정"
	control_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	control_hint.add_theme_font_size_override("font_size", 14)
	control_hint.add_theme_color_override("font_color", Color("#cbd5e1"))
	canvas.add_child(control_hint)

	prompt_label = Label.new()
	prompt_label.position = Vector2(250, 455)
	prompt_label.size = Vector2(460, 54)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color("#f8fafc"))
	prompt_label.visible = false
	canvas.add_child(prompt_label)

	overlay = ColorRect.new()
	overlay.color = Color("#050816f2")
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(960, 540)
	overlay.visible = false
	canvas.add_child(overlay)

	overlay_title = Label.new()
	overlay_title.position = Vector2(180, 150)
	overlay_title.size = Vector2(600, 90)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 48)
	overlay.add_child(overlay_title)

	var room_message := Label.new()
	room_message.position = Vector2(230, 255)
	room_message.size = Vector2(500, 50)
	room_message.text = "미니게임 프로토타입 자리"
	room_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_message.add_theme_font_size_override("font_size", 20)
	overlay.add_child(room_message)

	overlay_button = Button.new()
	overlay_button.position = Vector2(350, 340)
	overlay_button.size = Vector2(260, 60)
	overlay_button.text = "CLEAR ROOM"
	overlay_button.add_theme_font_size_override("font_size", 20)
	overlay_button.pressed.connect(clear_current_room)
	overlay.add_child(overlay_button)

	card_game = CARD_GAME_SCRIPT.new()
	card_game.game_won.connect(_on_card_game_won)
	canvas.add_child(card_game)

	platform_game = PLATFORM_GAME_SCRIPT.new()
	platform_game.game_won.connect(_on_platform_game_won)
	canvas.add_child(platform_game)

	rhythm_game = RHYTHM_GAME_SCRIPT.new()
	rhythm_game.game_won.connect(_on_rhythm_game_won)
	canvas.add_child(rhythm_game)

	roguelike_game = ROGUELIKE_GAME_SCRIPT.new()
	roguelike_game.game_won.connect(_on_roguelike_game_won)
	canvas.add_child(roguelike_game)

	shooter_game = SHOOTER_GAME_SCRIPT.new()
	shooter_game.game_won.connect(_on_shooter_game_won)
	canvas.add_child(shooter_game)

	final_boss_game = $GameCanvas/FinalBossGame
	final_boss_game.game_won.connect(_on_final_boss_game_won)
	build_dev_skip_button(canvas)

	build_settings_menu(canvas)


func build_dev_skip_button(canvas: CanvasLayer) -> void:
	skip_button = Button.new()
	skip_button.z_index = 400
	skip_button.position = Vector2(788, 12)
	skip_button.size = Vector2(154, 46)
	skip_button.text = "DEV SKIP  [F2]"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_size_override("font_size", 15)
	skip_button.add_theme_color_override("font_color", Color("#fdf2f8"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#831843dd")
	style.border_color = Color("#f472b6")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	skip_button.add_theme_stylebox_override("normal", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = Color("#be185d")
	skip_button.add_theme_stylebox_override("hover", hover_style)
	skip_button.add_theme_stylebox_override("pressed", hover_style)
	skip_button.pressed.connect(dev_skip_current_room)
	canvas.add_child(skip_button)


func build_settings_menu(canvas: CanvasLayer) -> void:
	settings_overlay = ColorRect.new()
	settings_overlay.z_index = 500
	settings_overlay.color = Color("#020617e8")
	settings_overlay.position = Vector2.ZERO
	settings_overlay.size = Vector2(960, 540)
	settings_overlay.visible = false
	settings_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(settings_overlay)

	var panel := Panel.new()
	panel.position = Vector2(260, 55)
	panel.size = Vector2(440, 430)
	settings_overlay.add_child(panel)

	var title := Label.new()
	title.position = Vector2(30, 24)
	title.size = Vector2(380, 56)
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	panel.add_child(title)

	var bgm_label := Label.new()
	bgm_label.position = Vector2(44, 104)
	bgm_label.size = Vector2(190, 30)
	bgm_label.text = "BGM 볼륨"
	bgm_label.add_theme_font_size_override("font_size", 19)
	panel.add_child(bgm_label)

	bgm_value_label = Label.new()
	bgm_value_label.position = Vector2(315, 104)
	bgm_value_label.size = Vector2(80, 30)
	bgm_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bgm_value_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(bgm_value_label)

	bgm_slider = HSlider.new()
	bgm_slider.position = Vector2(44, 140)
	bgm_slider.size = Vector2(350, 34)
	bgm_slider.min_value = 0
	bgm_slider.max_value = 100
	bgm_slider.step = 1
	bgm_slider.value = 80
	bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	panel.add_child(bgm_slider)

	var sfx_label := Label.new()
	sfx_label.position = Vector2(44, 198)
	sfx_label.size = Vector2(190, 30)
	sfx_label.text = "효과음 볼륨"
	sfx_label.add_theme_font_size_override("font_size", 19)
	panel.add_child(sfx_label)

	sfx_value_label = Label.new()
	sfx_value_label.position = Vector2(315, 198)
	sfx_value_label.size = Vector2(80, 30)
	sfx_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sfx_value_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(sfx_value_label)

	sfx_slider = HSlider.new()
	sfx_slider.position = Vector2(44, 234)
	sfx_slider.size = Vector2(350, 34)
	sfx_slider.min_value = 0
	sfx_slider.max_value = 100
	sfx_slider.step = 1
	sfx_slider.value = 90
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	panel.add_child(sfx_slider)

	var continue_button := Button.new()
	continue_button.position = Vector2(44, 302)
	continue_button.size = Vector2(168, 54)
	continue_button.text = "계속하기"
	continue_button.add_theme_font_size_override("font_size", 19)
	continue_button.pressed.connect(close_settings)
	panel.add_child(continue_button)

	var quit_button := Button.new()
	quit_button.position = Vector2(228, 302)
	quit_button.size = Vector2(168, 54)
	quit_button.text = "게임 종료"
	quit_button.add_theme_font_size_override("font_size", 19)
	quit_button.add_theme_color_override("font_color", Color("#fca5a5"))
	quit_button.pressed.connect(quit_game)
	panel.add_child(quit_button)

	var hint := Label.new()
	hint.position = Vector2(44, 378)
	hint.size = Vector2(352, 24)
	hint.text = "ESC를 다시 누르면 게임으로 돌아갑니다"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("#94a3b8"))
	panel.add_child(hint)


func open_room(index: int) -> void:
	Sfx.play("ui_select", -1.0, 0.95 + float(index) * 0.025)
	if index == 0:
		prompt_label.visible = false
		card_game.start_game()
		return
	if index == 1:
		prompt_label.visible = false
		platform_game.start_game()
		return
	if index == 2:
		prompt_label.visible = false
		rhythm_game.start_game()
		return
	if index == 3:
		prompt_label.visible = false
		roguelike_game.start_game()
		return
	if index == 4:
		prompt_label.visible = false
		shooter_game.start_game()
		return
	if index == 5:
		prompt_label.visible = false
		final_boss_game.set_inherited_skills(roguelike_game.skill_levels)
		final_boss_game.start_game()
		return
	overlay_title.text = STAGES[index]
	overlay_title.add_theme_color_override("font_color", STAGE_COLORS[index])
	overlay.visible = true
	prompt_label.visible = false


func clear_current_room() -> void:
	if dev_room_override >= 0:
		dev_room_override = -1
		overlay.visible = false
		prompt_label.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if cleared_count >= STAGES.size():
		return
	door_bodies[cleared_count].queue_free()
	door_visuals[cleared_count].modulate = Color("#86efac")
	door_status_badges[cleared_count].color = Color("#14532d")
	door_status_labels[cleared_count].text = "CLEAR"
	Sfx.play("ui_confirm", 1.0, 0.92)
	cleared_count += 1
	nearby_stage = -1
	overlay.visible = false
	if cleared_count < STAGES.size():
		door_status_badges[cleared_count].color = Color("#166534")
		door_status_labels[cleared_count].text = "OPEN"
		progress_label.text = "ROOM %d / %d  ·  %s" % [cleared_count + 1, STAGES.size(), STAGES[cleared_count]]
	else:
		progress_label.text = "ALL ROOMS CLEARED"
		skip_button.disabled = true
		skip_button.text = "ALL CLEAR"


func dev_skip_current_room() -> void:
	if cleared_count >= STAGES.size():
		return
	card_game.visible = false
	platform_game.visible = false
	rhythm_game.visible = false
	roguelike_game.visible = false
	shooter_game.visible = false
	final_boss_game.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	overlay.visible = false
	prompt_label.visible = false
	clear_current_room()


func any_room_visible() -> bool:
	return overlay.visible or card_game.visible or platform_game.visible or rhythm_game.visible or roguelike_game.visible or shooter_game.visible or final_boss_game.visible


func room_number_from_key(keycode: Key) -> int:
	match keycode:
		KEY_1, KEY_KP_1: return 0
		KEY_2, KEY_KP_2: return 1
		KEY_3, KEY_KP_3: return 2
		KEY_4, KEY_KP_4: return 3
		KEY_5, KEY_KP_5: return 4
		KEY_6, KEY_KP_6: return 5
	return -1


func dev_open_room(index: int) -> void:
	if index < 0 or index >= STAGES.size(): return
	dev_room_override = index
	prompt_label.visible = false
	open_room(index)


func _on_card_game_won() -> void:
	clear_current_room()


func _on_platform_game_won() -> void:
	clear_current_room()


func _on_rhythm_game_won() -> void:
	clear_current_room()


func _on_roguelike_game_won() -> void:
	clear_current_room()


func _on_shooter_game_won() -> void:
	clear_current_room()


func _on_final_boss_game_won() -> void:
	clear_current_room()


func _on_door_area_entered(body: Node2D, index: int) -> void:
	if body != player:
		return
	nearby_stage = index
	if index == cleared_count:
		prompt_label.text = "[ E ]  ROOM %d 입장 · %s" % [index + 1, STAGES[index]]
	else:
		prompt_label.text = "LOCKED · 이전 방을 먼저 클리어하세요"
	prompt_label.visible = true


func _on_door_area_exited(body: Node2D, index: int) -> void:
	if body == player and nearby_stage == index:
		nearby_stage = -1
		prompt_label.visible = false


func add_rect(rect_position: Vector2, rect_size: Vector2, color: Color) -> Polygon2D:
	var rect := Polygon2D.new()
	rect.position = rect_position
	rect.polygon = PackedVector2Array([
		Vector2.ZERO, Vector2(rect_size.x, 0), rect_size, Vector2(0, rect_size.y)
	])
	rect.color = color
	add_child(rect)
	return rect


func add_polygon(points: PackedVector2Array, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	add_child(shape)
	return shape


func make_world_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func ensure_audio_buses() -> void:
	for bus_name in ["BGM", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var new_index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(new_index, bus_name)


func toggle_settings() -> void:
	if settings_overlay.visible:
		close_settings()
	else:
		settings_overlay.visible = true
		get_tree().paused = true
		if shooter_game.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if final_boss_game.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_settings() -> void:
	settings_overlay.visible = false
	get_tree().paused = false
	if shooter_game.visible and shooter_game.state in ["playing", "playing_enemy"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif final_boss_game.visible and final_boss_game.phase in ["shooter","defeated"]:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	save_audio_settings()


func quit_game() -> void:
	save_audio_settings()
	get_tree().paused = false
	get_tree().quit()


func _on_bgm_volume_changed(value: float) -> void:
	bgm_value_label.text = "%d%%" % int(value)
	set_bus_volume("BGM", value)


func _on_sfx_volume_changed(value: float) -> void:
	sfx_value_label.text = "%d%%" % int(value)
	set_bus_volume("SFX", value)


func set_bus_volume(bus_name: String, value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		return
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(max(value / 100.0, 0.0001)))


func load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		bgm_slider.value = float(config.get_value("audio", "bgm", 80.0))
		sfx_slider.value = float(config.get_value("audio", "sfx", 90.0))
	_on_bgm_volume_changed(bgm_slider.value)
	_on_sfx_volume_changed(sfx_slider.value)


func save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm", bgm_slider.value)
	config.set_value("audio", "sfx", sfx_slider.value)
	config.save(SETTINGS_PATH)


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
