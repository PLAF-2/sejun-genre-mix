extends Control

signal game_won

const RHYTHM_TRACK := preload("res://assets/audio/usagi_rap_video_section_45s.mp3")
const BPM := 105.0
const BEAT_INTERVAL := 60.0 / BPM
const PERFECT_WINDOW := 0.075
const GOOD_WINDOW := 0.17
const PATH_TILE_COUNT := 79

var background: ColorRect
var world: Node2D
var path_points: PackedVector2Array
var tiles: Array[Polygon2D] = []
var reveal_details: Array[CanvasItem] = []
var character_fill: Polygon2D
var path_glow: Line2D
var orb_a: Polygon2D
var orb_b: Polygon2D
var pulse_ring: Polygon2D
var music_player: AudioStreamPlayer
var screen_flash: ColorRect

var state := "idle"
var countdown_left := 3.0
var song_time := 0.0
var target_index := 1
var hearts := 3
var combo := 0
var max_combo := 0
var perfect_count := 0
var good_count := 0
var miss_count := 0
var active_orb_is_a := true
var view_center := Vector2.ZERO
var view_zoom := Vector2.ONE
var shake_strength := 0.0
var judge_generation := 0

var status_label: Label
var heart_label: Label
var combo_label: Label
var judge_label: Label
var timing_label: Label
var instruction_label: Label
var progress_bar: ProgressBar
var fail_overlay: ColorRect
var clear_panel: Panel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_PAUSABLE
	build_interface()
	visible = false


func build_interface() -> void:
	background = ColorRect.new()
	background.color = Color("#080b22")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	world = Node2D.new()
	add_child(world)

	music_player = AudioStreamPlayer.new()
	music_player.stream = RHYTHM_TRACK
	music_player.bus = "BGM"
	add_child(music_player)

	var top_bar := ColorRect.new()
	top_bar.color = Color("#11152eec")
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(960, 68)
	add_child(top_bar)

	var title := make_label(Vector2(22, 13), Vector2(270, 42), 23, Color("#fef3c7"))
	title.text = "ROOM 3 · RHYTHM"
	top_bar.add_child(title)

	heart_label = make_label(Vector2(300, 15), Vector2(200, 38), 22, Color("#fb7185"))
	top_bar.add_child(heart_label)

	combo_label = make_label(Vector2(690, 14), Vector2(245, 38), 21, Color("#67e8f9"))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(combo_label)

	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(25, 76)
	progress_bar.size = Vector2(910, 12)
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.show_percentage = false
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress_bar)

	status_label = make_label(Vector2(250, 94), Vector2(460, 34), 18, Color("#cbd5e1"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(status_label)

	judge_label = make_label(Vector2(280, 202), Vector2(400, 82), 42, Color.WHITE)
	judge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	judge_label.add_theme_color_override("font_outline_color", Color("#020617"))
	judge_label.add_theme_constant_override("outline_size", 9)
	judge_label.visible = false
	add_child(judge_label)

	timing_label = make_label(Vector2(330, 277), Vector2(300, 32), 16, Color("#cbd5e1"))
	timing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_label.visible = false
	add_child(timing_label)

	instruction_label = make_label(Vector2(145, 475), Vector2(670, 42), 18, Color("#e2e8f0"))
	instruction_label.text = "SPACE · 클릭 · 터치  |  회전하는 공이 다음 타일에 닿을 때 입력"
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(instruction_label)

	screen_flash = ColorRect.new()
	screen_flash.color = Color.WHITE
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.modulate.a = 0.0
	add_child(screen_flash)

	build_fail_overlay()
	build_clear_panel()


func build_fail_overlay() -> void:
	fail_overlay = ColorRect.new()
	fail_overlay.color = Color("#020617ed")
	fail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fail_overlay.visible = false
	add_child(fail_overlay)

	var fail_title := make_label(Vector2(220, 135), Vector2(520, 80), 45, Color("#fb7185"))
	fail_title.text = "RHYTHM LOST"
	fail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_overlay.add_child(fail_title)

	var fail_text := make_label(Vector2(190, 225), Vector2(580, 44), 19, Color("#e2e8f0"))
	fail_text.text = "하트가 모두 사라졌습니다 · 체크포인트 없이 처음부터 재도전"
	fail_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_overlay.add_child(fail_text)

	var retry_button := Button.new()
	retry_button.position = Vector2(265, 315)
	retry_button.size = Vector2(205, 60)
	retry_button.text = "처음부터 재도전"
	retry_button.add_theme_font_size_override("font_size", 19)
	retry_button.pressed.connect(start_game)
	fail_overlay.add_child(retry_button)

	var exit_button := Button.new()
	exit_button.position = Vector2(490, 315)
	exit_button.size = Vector2(205, 60)
	exit_button.text = "복도로 돌아가기"
	exit_button.add_theme_font_size_override("font_size", 19)
	exit_button.pressed.connect(_exit_to_corridor)
	fail_overlay.add_child(exit_button)


func build_clear_panel() -> void:
	clear_panel = Panel.new()
	clear_panel.position = Vector2(285, 382)
	clear_panel.size = Vector2(390, 130)
	clear_panel.visible = false
	add_child(clear_panel)

	var clear_title := make_label(Vector2(15, 8), Vector2(360, 48), 29, Color("#fde047"))
	clear_title.text = "치이카와 길 완성!"
	clear_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_panel.add_child(clear_title)

	var return_button := Button.new()
	return_button.position = Vector2(85, 66)
	return_button.size = Vector2(220, 48)
	return_button.text = "복도로 돌아가기"
	return_button.add_theme_font_size_override("font_size", 18)
	return_button.pressed.connect(_finish_room)
	clear_panel.add_child(return_button)


func start_game() -> void:
	music_player.stop()
	visible = true
	fail_overlay.visible = false
	clear_panel.visible = false
	instruction_label.visible = true
	judge_label.visible = false
	timing_label.visible = false
	state = "countdown"
	countdown_left = 3.0
	song_time = 0.0
	target_index = 1
	hearts = 3
	combo = 0
	max_combo = 0
	perfect_count = 0
	good_count = 0
	miss_count = 0
	active_orb_is_a = true
	shake_strength = 0.0
	rebuild_path()
	update_hud()
	status_label.text = "준비 · 3"
	view_center = path_points[0]
	view_zoom = Vector2(2.45, 2.45)
	apply_world_view()


func rebuild_path() -> void:
	for child in world.get_children():
		child.queue_free()
	tiles.clear()
	reveal_details.clear()

	var outline := build_chiikawa_outline()
	path_points = resample_closed_path(outline, PATH_TILE_COUNT)

	character_fill = Polygon2D.new()
	character_fill.polygon = outline
	character_fill.color = Color("#fffdf0")
	character_fill.visible = false
	character_fill.z_index = -3
	world.add_child(character_fill)

	var closed_path := path_points.duplicate()
	closed_path.append(path_points[0])
	var shadow_line := Line2D.new()
	shadow_line.points = closed_path
	shadow_line.width = 15.0
	shadow_line.default_color = Color("#111827")
	shadow_line.joint_mode = Line2D.LINE_JOINT_ROUND
	shadow_line.z_index = -2
	world.add_child(shadow_line)

	path_glow = Line2D.new()
	path_glow.points = closed_path
	path_glow.width = 5.0
	path_glow.default_color = Color("#f59e0b66")
	path_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	path_glow.z_index = -1
	world.add_child(path_glow)

	for i in path_points.size():
		var tile := Polygon2D.new()
		tile.position = path_points[i]
		tile.polygon = PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)])
		tile.rotation = PI / 4.0
		tile.color = Color("#fde68a") if i == 0 else Color("#334155")
		world.add_child(tile)
		tiles.append(tile)

	pulse_ring = Polygon2D.new()
	pulse_ring.polygon = make_ring_polygon(20.0, 15.5, 24)
	pulse_ring.color = Color("#fef08aaa")
	pulse_ring.position = path_points[0]
	pulse_ring.z_index = 2
	world.add_child(pulse_ring)

	orb_a = make_orb(Color("#facc15"), Color("#fff7b3"))
	orb_b = make_orb(Color("#f8fafc"), Color("#bae6fd"))
	world.add_child(orb_a)
	world.add_child(orb_b)
	build_hidden_face()
	update_orbs(0.0)


func build_chiikawa_outline() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(290, 505), Vector2(260, 512), Vector2(230, 502), Vector2(215, 480),
		Vector2(220, 448), Vector2(198, 440), Vector2(180, 420), Vector2(175, 395),
		Vector2(180, 370), Vector2(158, 352), Vector2(148, 325), Vector2(151, 295),
		Vector2(164, 267), Vector2(181, 240), Vector2(204, 218), Vector2(224, 203),
		Vector2(216, 180), Vector2(218, 153), Vector2(232, 132), Vector2(254, 126),
		Vector2(273, 140), Vector2(280, 164), Vector2(310, 158), Vector2(340, 160),
		Vector2(348, 139), Vector2(367, 126), Vector2(390, 132), Vector2(404, 153),
		Vector2(406, 180), Vector2(397, 204), Vector2(420, 220), Vector2(441, 242),
		Vector2(458, 270), Vector2(468, 301), Vector2(468, 332), Vector2(457, 358),
		Vector2(438, 375), Vector2(442, 399), Vector2(434, 424), Vector2(414, 442),
		Vector2(394, 448), Vector2(400, 478), Vector2(384, 502), Vector2(354, 512),
		Vector2(326, 504), Vector2(309, 488)
	])


func resample_closed_path(control_points: PackedVector2Array, desired_count: int) -> PackedVector2Array:
	var lengths := PackedFloat32Array()
	var total_length := 0.0
	for i in control_points.size():
		var length := control_points[i].distance_to(control_points[(i + 1) % control_points.size()])
		lengths.append(length)
		total_length += length
	var result := PackedVector2Array()
	var segment_index := 0
	var distance_before_segment := 0.0
	for sample_index in desired_count:
		var target_distance := total_length * float(sample_index) / float(desired_count)
		while distance_before_segment + lengths[segment_index] < target_distance:
			distance_before_segment += lengths[segment_index]
			segment_index = (segment_index + 1) % control_points.size()
		var progress := (target_distance - distance_before_segment) / maxf(lengths[segment_index], 0.001)
		result.append(control_points[segment_index].lerp(control_points[(segment_index + 1) % control_points.size()], progress))
	return result


func build_hidden_face() -> void:
	for face_data in [
		[Vector2(270, 305), Vector2(7, 13), Color("#1f2937")],
		[Vector2(358, 305), Vector2(7, 13), Color("#1f2937")],
		[Vector2(225, 347), Vector2(14, 8), Color("#fda4af")],
		[Vector2(405, 347), Vector2(14, 8), Color("#fda4af")]
	]:
		var detail := make_ellipse(face_data[1], face_data[2])
		detail.position = face_data[0]
		detail.visible = false
		detail.z_index = -1
		world.add_child(detail)
		reveal_details.append(detail)
	var mouth := Line2D.new()
	mouth.points = PackedVector2Array([Vector2(295, 345), Vector2(306, 353), Vector2(315, 343), Vector2(324, 353), Vector2(335, 345)])
	mouth.width = 4.0
	mouth.default_color = Color("#1f2937")
	mouth.begin_cap_mode = Line2D.LINE_CAP_ROUND
	mouth.end_cap_mode = Line2D.LINE_CAP_ROUND
	mouth.visible = false
	mouth.z_index = -1
	world.add_child(mouth)
	reveal_details.append(mouth)


func _process(delta: float) -> void:
	if not visible:
		return
	shake_strength = move_toward(shake_strength, 0.0, delta * 28.0)
	apply_world_view()
	if state == "countdown":
		countdown_left -= delta
		status_label.text = "준비 · %d" % maxi(1, int(ceil(countdown_left)))
		pulse_visual(0.0)
		if countdown_left <= 0.0:
			state = "playing"
			song_time = 0.0
			music_player.play()
			status_label.text = "첫 박자!"
	elif state == "playing":
		song_time = get_precise_song_position()
		update_orbs(song_time)
		pulse_visual(song_time)
		view_center = view_center.lerp(path_points[target_index - 1], minf(1.0, delta * 8.0))
		var target_time := float(target_index) * BEAT_INTERVAL
		if song_time - target_time > GOOD_WINDOW:
			register_miss("LATE")
	elif state == "reveal" or state == "complete":
		pulse_visual(song_time)


func get_precise_song_position() -> float:
	if not music_player.playing:
		return song_time
	return maxf(0.0, music_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())


func _unhandled_input(event: InputEvent) -> void:
	if not visible or state != "playing":
		return
	var pressed := false
	if event is InputEventKey:
		pressed = event.pressed and not event.echo and event.keycode == KEY_SPACE
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed:
		judge_input()
		get_viewport().set_input_as_handled()


func judge_input() -> void:
	if target_index >= path_points.size():
		return
	# 입력 프레임 직전 _process 값이 아니라 실제 오디오 재생 헤드를 다시 읽어 지연을 줄인다.
	song_time = get_precise_song_position()
	var target_time := float(target_index) * BEAT_INTERVAL
	var signed_difference := song_time - target_time
	var difference := absf(signed_difference)
	if difference <= PERFECT_WINDOW:
		Sfx.play("ui_confirm", -7.0, 1.18, 0.03)
		perfect_count += 1
		combo += 1
		show_judgement("PERFECT", Color("#67e8f9"), signed_difference)
		advance_step(true)
	elif difference <= GOOD_WINDOW:
		Sfx.play("ui_select", -8.0, 1.04, 0.03)
		good_count += 1
		combo += 1
		show_judgement("GOOD", Color("#fde047"), signed_difference)
		advance_step(true)
	elif signed_difference < -0.32:
		show_judgement("WAIT", Color("#c4b5fd"), signed_difference)
	else:
		register_miss("EARLY" if signed_difference < 0.0 else "LATE")


func register_miss(reason: String) -> void:
	if state != "playing":
		return
	hearts -= 1
	Sfx.play("ui_error", -4.0, 0.82, 0.03)
	miss_count += 1
	combo = 0
	show_judgement("MISS", Color("#fb7185"), song_time - float(target_index) * BEAT_INTERVAL, reason)
	shake_strength = 10.0
	flash_screen(Color("#ef4444"), 0.22)
	if hearts <= 0:
		update_hud()
		state = "failed"
		music_player.stop()
		fail_overlay.visible = true
		return
	advance_step(false)


func advance_step(hit: bool) -> void:
	if target_index >= path_points.size():
		return
	var landing_position := path_points[target_index]
	if hit:
		tiles[target_index].color = Color("#fbbf24")
		spawn_impact(landing_position, Color("#fde047"))
		flash_tile(tiles[target_index])
		shake_strength = 4.0 if combo < 10 else 6.5
		flash_screen(Color("#fef9c3"), 0.09 if combo < 10 else 0.15)
		squash_orbs()
	else:
		tiles[target_index].color = Color("#7f1d1d")
	pulse_ring.position = landing_position
	active_orb_is_a = not active_orb_is_a
	max_combo = maxi(max_combo, combo)
	target_index += 1
	update_hud()
	if target_index >= path_points.size():
		begin_reveal()
	else:
		update_orbs(song_time)


func update_orbs(time_value: float) -> void:
	if path_points.is_empty() or target_index >= path_points.size():
		return
	var pivot_index := target_index - 1
	var pivot := path_points[pivot_index]
	var next_point := path_points[target_index]
	var previous_point: Vector2
	if pivot_index == 0:
		previous_point = pivot - (next_point - pivot)
	else:
		previous_point = path_points[pivot_index - 1]
	var step_start := float(target_index - 1) * BEAT_INTERVAL
	var progress := clampf((time_value - step_start) / BEAT_INTERVAL, 0.0, 1.0)
	var start_vector := previous_point - pivot
	var end_vector := next_point - pivot
	var radius := end_vector.length()
	var start_angle := start_vector.angle()
	var arc := fposmod(end_vector.angle() - start_angle, TAU)
	if arc < 0.20:
		arc += TAU
	var angle := start_angle + arc * progress
	var moving_position := pivot + Vector2(cos(angle), sin(angle)) * radius
	if active_orb_is_a:
		orb_a.position = pivot
		orb_b.position = moving_position
		orb_a.z_index = 4
		orb_b.z_index = 5
	else:
		orb_b.position = pivot
		orb_a.position = moving_position
		orb_b.z_index = 4
		orb_a.z_index = 5


func pulse_visual(time_value: float) -> void:
	var phase := fmod(maxf(time_value, 0.0), BEAT_INTERVAL) / BEAT_INTERVAL
	var impact := pow(1.0 - phase, 4.0)
	pulse_ring.scale = Vector2.ONE * (1.0 + impact * 0.32)
	pulse_ring.modulate.a = 0.3 + impact * 0.7
	path_glow.width = 5.0 + impact * 2.5
	background.color = Color("#080b22").lerp(Color("#231447"), impact * 0.34)


func spawn_impact(world_position: Vector2, color: Color) -> void:
	var impact_root := Node2D.new()
	impact_root.position = world_position
	impact_root.z_index = 8
	world.add_child(impact_root)
	var ring := Polygon2D.new()
	ring.polygon = make_ring_polygon(18.0, 13.0, 24)
	ring.color = color
	impact_root.add_child(ring)
	var ring_tween := create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.30).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.30)
	for i in 10:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])
		shard.color = color.lerp(Color.WHITE, float(i % 3) * 0.25)
		impact_root.add_child(shard)
		var angle := TAU * float(i) / 10.0 + randf_range(-0.12, 0.12)
		var target := Vector2(cos(angle), sin(angle)) * randf_range(30.0, 52.0)
		var shard_tween := create_tween()
		shard_tween.set_parallel(true)
		shard_tween.tween_property(shard, "position", target, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		shard_tween.tween_property(shard, "rotation", randf_range(-2.5, 2.5), 0.34)
		shard_tween.tween_property(shard, "modulate:a", 0.0, 0.34).set_delay(0.08)
	get_tree().create_timer(0.5).timeout.connect(impact_root.queue_free)


func squash_orbs() -> void:
	var landed_orb := orb_b if active_orb_is_a else orb_a
	landed_orb.scale = Vector2(1.5, 0.65)
	landed_orb.rotation = randf_range(-0.15, 0.15)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(landed_orb, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(landed_orb, "rotation", 0.0, 0.18)


func flash_screen(color: Color, strength: float) -> void:
	screen_flash.color = color
	screen_flash.modulate.a = strength
	create_tween().tween_property(screen_flash, "modulate:a", 0.0, 0.15)


func show_judgement(text_value: String, color: Color, offset: float, detail := "") -> void:
	judge_generation += 1
	var generation := judge_generation
	judge_label.text = text_value
	judge_label.add_theme_color_override("font_color", color)
	judge_label.visible = true
	judge_label.modulate.a = 1.0
	judge_label.scale = Vector2(1.45, 0.72)
	judge_label.pivot_offset = judge_label.size / 2.0
	var timing_text := "%+.0f ms" % (offset * 1000.0)
	if detail != "":
		timing_text = detail + "  ·  " + timing_text
	timing_label.text = timing_text
	timing_label.add_theme_color_override("font_color", color)
	timing_label.visible = true
	timing_label.modulate.a = 1.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(judge_label, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(judge_label, "modulate:a", 0.0, 0.34).set_delay(0.20)
	tween.tween_property(timing_label, "modulate:a", 0.0, 0.32).set_delay(0.22)
	tween.chain().tween_callback(func() -> void:
		if generation == judge_generation:
			judge_label.visible = false
			timing_label.visible = false
	)


func flash_tile(tile: Polygon2D) -> void:
	tile.scale = Vector2(1.8, 1.8)
	tile.rotation += 0.18
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "rotation", PI / 4.0, 0.20)


func begin_reveal() -> void:
	state = "reveal"
	instruction_label.visible = false
	status_label.text = "길의 정체가 드러납니다!"
	for tile in tiles:
		tile.color = Color("#fde047")
	for detail in reveal_details:
		detail.visible = true
	character_fill.visible = true
	spawn_impact(path_points[path_points.size() - 1], Color("#fef08a"))
	flash_screen(Color.WHITE, 0.34)
	shake_strength = 8.0
	var center := Vector2(310, 320)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "view_center", center, 1.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "view_zoom", Vector2(0.82, 0.82), 1.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(_show_clear_result)


func apply_world_view() -> void:
	world.scale = view_zoom
	var shake_offset := Vector2.ZERO
	if shake_strength > 0.0:
		shake_offset = Vector2(randf_range(-shake_strength, shake_strength), randf_range(-shake_strength, shake_strength))
	world.position = Vector2(480, 300) - view_center * view_zoom + shake_offset


func _show_clear_result() -> void:
	state = "complete"
	status_label.text = "PERFECT %d · GOOD %d · MISS %d · MAX COMBO %d" % [perfect_count, good_count, miss_count, max_combo]
	clear_panel.visible = true


func update_hud() -> void:
	heart_label.text = "LIFE  " + "♥".repeat(maxi(0, hearts))
	combo_label.text = "COMBO  %d" % combo
	progress_bar.value = float(target_index - 1) / float(path_points.size() - 1) * 100.0


func _finish_room() -> void:
	music_player.stop()
	visible = false
	game_won.emit()


func _exit_to_corridor() -> void:
	music_player.stop()
	visible = false
	state = "idle"


func make_label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_orb(main_color: Color, highlight_color: Color) -> Polygon2D:
	var orb := make_circle(10.0, main_color)
	var highlight := make_circle(3.2, highlight_color)
	highlight.position = Vector2(-3.0, -3.0)
	orb.add_child(highlight)
	var outline := Line2D.new()
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle), sin(angle)) * 10.0)
	outline.points = points
	outline.width = 2.0
	outline.default_color = Color("#111827")
	orb.add_child(outline)
	return orb


func make_circle(radius: float, color: Color) -> Polygon2D:
	var circle := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var angle := float(i) / 24.0 * TAU
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.polygon = points
	circle.color = color
	return circle


func make_ellipse(radius: Vector2, color: Color) -> Polygon2D:
	var ellipse := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var angle := float(i) / 24.0 * TAU
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	ellipse.polygon = points
	ellipse.color = color
	return ellipse


func make_ring_polygon(outer_radius: float, inner_radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	for i in segments:
		var reverse_index := segments - 1 - i
		var angle := float(reverse_index) / float(segments) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	return points
