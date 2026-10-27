extends Control

signal game_won

const HERO_TEXTURE := preload("res://assets/characters/hero_walk_user_v3.png")
const GARDEN_TEXTURE := preload("res://assets/platform/campus_garden.svg")
const LEDGE_TEXTURE := preload("res://assets/platform/garden_ledge.svg")
const SLIME_TEXTURE := preload("res://assets/platform/slime.svg")
const STAGE_LAYER := 8 # 복도 바닥과 충돌하지 않는 플랫포머 전용 레이어.
const MOVE_SPEED := 250.0
const JUMP_SPEED := 515.0
const GRAVITY := 1450.0

var world: Node2D
var player: CharacterBody2D
var player_sprite: AnimatedSprite2D
var moving_platform: AnimatableBody2D
var enemies: Array[Dictionary] = []
var coins_collected := 0
var health := 2
var has_wing_shoes := false
var double_jump_available := false
var invincible := false
var finished := false
var platform_time := 0.0
var coyote_left := 0.0
var jump_buffer := 0.0
var was_grounded := false
var stage_generation := 0
var flag_cloth: Polygon2D

var coin_label: Label
var heart_label: Label
var item_label: Label
var message_label: Label
var result_overlay: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_interface()
	visible = false


func build_interface() -> void:
	var sky := ColorRect.new()
	sky.color = Color("#172554")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(sky)

	var horizon := ColorRect.new()
	horizon.color = Color("#2563a8")
	horizon.position = Vector2(0, 235)
	horizon.size = Vector2(960, 305)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(horizon)

	world = Node2D.new()
	add_child(world)

	var hud := ColorRect.new()
	hud.color = Color("#0f172ae8")
	hud.position = Vector2.ZERO
	hud.size = Vector2(960, 64)
	add_child(hud)

	coin_label = make_label(Vector2(24, 15), Vector2(180, 36), 22, Color("#fde047"))
	hud.add_child(coin_label)
	heart_label = make_label(Vector2(225, 15), Vector2(180, 36), 22, Color("#fb7185"))
	hud.add_child(heart_label)
	item_label = make_label(Vector2(435, 15), Vector2(330, 36), 17, Color("#bae6fd"))
	item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(item_label)

	message_label = make_label(Vector2(210, 72), Vector2(540, 42), 19, Color.WHITE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_shadow_color", Color("#243b44"))
	message_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(message_label)

	result_overlay = ColorRect.new()
	result_overlay.color = Color("#020617ed")
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	add_child(result_overlay)

	var result_title := make_label(Vector2(180, 155), Vector2(600, 90), 48, Color("#4ade80"))
	result_title.text = "ROOM 2 CLEAR!"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_overlay.add_child(result_title)

	var result_text := make_label(Vector2(220, 255), Vector2(520, 45), 20, Color("#e2e8f0"))
	result_text.text = "코인 3개를 모으고 플랫포머 방을 통과했습니다"
	result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_overlay.add_child(result_text)

	var return_button := Button.new()
	return_button.position = Vector2(350, 340)
	return_button.size = Vector2(260, 62)
	return_button.text = "복도로 돌아가기"
	return_button.add_theme_font_size_override("font_size", 20)
	return_button.pressed.connect(_on_return_pressed)
	result_overlay.add_child(return_button)


func start_game() -> void:
	visible = true
	result_overlay.visible = false
	rebuild_stage()


func rebuild_stage() -> void:
	stage_generation += 1
	coyote_left = 0.0
	jump_buffer = 0.0
	was_grounded = false
	for child in world.get_children():
		world.remove_child(child)
		child.queue_free()
	enemies.clear()
	coins_collected = 0
	health = 2
	has_wing_shoes = false
	double_jump_available = false
	invincible = false
	finished = false
	platform_time = 0.0
	message_label.text = "A/D 또는 ←/→ 이동 · SPACE 점프 · 코인 3개를 모아 오른쪽 깃발까지!"

	build_scenery()
	build_ground()
	build_platform(Vector2(145, 395), Vector2(125, 18))
	build_platform(Vector2(455, 300), Vector2(145, 18))
	build_platform(Vector2(790, 395), Vector2(150, 18))
	build_moving_platform()
	build_player()
	build_coin(Vector2(207, 345))
	build_coin(Vector2(527, 250))
	build_coin(Vector2(700, 300))
	build_wing_shoes(Vector2(395, 449))
	build_spikes(Vector2(620, 480), Vector2(165, 20))
	build_enemy(Vector2(315, 488), 275.0, 365.0, 54.0)
	build_enemy(Vector2(520, 288), 475.0, 575.0, 42.0)
	build_enemy(Vector2(850, 383), 810.0, 915.0, 48.0)
	build_flag(Vector2(920, 395))
	update_hud()


func build_scenery() -> void:
	var scenery := Sprite2D.new()
	scenery.texture = GARDEN_TEXTURE
	scenery.centered = false
	world.add_child(scenery)
	for i in 18:
		var mote := Polygon2D.new()
		mote.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(0, -2), Vector2(2, 0), Vector2(0, 2)])
		mote.color = Color("#fff6c680")
		mote.position = Vector2(35 + i * 52, 170 + (i * 47) % 290)
		world.add_child(mote)
		var drift := create_tween().set_loops()
		drift.tween_property(mote, "position", mote.position + Vector2(15, -18), 2.1 + i * 0.07).set_trans(Tween.TRANS_SINE)
		drift.tween_property(mote, "position", mote.position, 2.1 + i * 0.07).set_trans(Tween.TRANS_SINE)
		drift.bind_node(mote)


func build_ground() -> void:
	var ground := build_solid_rect(Vector2(0, 500), Vector2(960, 40), Color("#66564a"))
	decorate_ledge(ground, Vector2(-480, -20), Vector2(960, 40))


func build_platform(position_value: Vector2, size_value: Vector2) -> void:
	var ledge := build_solid_rect(position_value, size_value, Color("#66564a"))
	decorate_ledge(ledge, -size_value / 2.0, Vector2(size_value.x, 32))


func decorate_ledge(parent: Node2D, origin: Vector2, dimensions: Vector2) -> void:
	var texture := TextureRect.new()
	texture.texture = LEDGE_TEXTURE
	texture.position = origin
	texture.size = dimensions
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_TILE
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(texture)


func build_solid_rect(position_value: Vector2, size_value: Vector2, color: Color) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position_value + size_value / 2.0
	body.collision_layer = STAGE_LAYER
	body.collision_mask = STAGE_LAYER
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size_value
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := make_rect(-size_value / 2.0, size_value, color)
	body.add_child(visual)
	world.add_child(body)
	return body


func build_moving_platform() -> void:
	moving_platform = AnimatableBody2D.new()
	moving_platform.position = Vector2(675, 390)
	moving_platform.collision_layer = STAGE_LAYER
	moving_platform.collision_mask = STAGE_LAYER
	moving_platform.sync_to_physics = true
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(105, 18)
	shape_node.shape = shape
	moving_platform.add_child(shape_node)
	var visual := make_rect(Vector2(-52.5, -9), Vector2(105, 18), Color("#f59e0b"))
	moving_platform.add_child(visual)
	decorate_ledge(moving_platform, Vector2(-52.5, -9), Vector2(105, 28))
	for x in [-38, 38]:
		var lamp := make_rect(Vector2(x, 3), Vector2(7, 4), Color("#fff1ac"))
		moving_platform.add_child(lamp)
	world.add_child(moving_platform)


func build_player() -> void:
	player = CharacterBody2D.new()
	player.position = Vector2(70, 480)
	player.collision_layer = STAGE_LAYER
	player.collision_mask = STAGE_LAYER
	var collider := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 14
	capsule.height = 48
	collider.shape = capsule
	collider.position = Vector2(0, -24)
	player.add_child(collider)

	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = make_hero_frames()
	player_sprite.animation = "walk"
	player_sprite.scale = Vector2(0.075, 0.075)
	player_sprite.position = Vector2(0, -28)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(player_sprite)
	world.add_child(player)


func build_coin(position_value: Vector2) -> void:
	var coin := Area2D.new()
	coin.position = position_value
	coin.collision_layer = 2
	coin.collision_mask = STAGE_LAYER
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 15
	shape_node.shape = shape
	coin.add_child(shape_node)
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(0, -17), Vector2(11, -12), Vector2(15, 0), Vector2(11, 12),
		Vector2(0, 17), Vector2(-11, 12), Vector2(-15, 0), Vector2(-11, -12)
	])
	visual.color = Color("#fde047")
	coin.add_child(visual)
	var shine := make_rect(Vector2(-3, -11), Vector2(5, 22), Color("#fff7ae"))
	coin.add_child(shine)
	var rim := Line2D.new()
	rim.points = visual.polygon
	rim.closed = true
	rim.width = 2.0
	rim.default_color = Color("#b17c2e")
	coin.add_child(rim)
	var bob := create_tween().set_loops().bind_node(coin)
	bob.tween_property(coin, "position:y", position_value.y - 6, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(coin, "position:y", position_value.y, 0.6).set_trans(Tween.TRANS_SINE)
	var spin := create_tween().set_loops().bind_node(coin)
	spin.tween_property(visual, "scale:x", 0.2, 0.4)
	spin.tween_property(visual, "scale:x", 1.0, 0.4)
	coin.body_entered.connect(_on_coin_collected.bind(coin))
	world.add_child(coin)


func build_wing_shoes(position_value: Vector2) -> void:
	var item := Area2D.new()
	item.position = position_value
	item.collision_layer = 2
	item.collision_mask = STAGE_LAYER
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40, 32)
	shape_node.shape = shape
	item.add_child(shape_node)
	var shoe := make_rect(Vector2(-18, -7), Vector2(34, 18), Color("#38bdf8"))
	item.add_child(shoe)
	var wing := Polygon2D.new()
	wing.polygon = PackedVector2Array([Vector2(-12, -5), Vector2(-27, -20), Vector2(-25, 2)])
	wing.color = Color("#f8fafc")
	item.add_child(wing)
	for i in 3:
		var feather := make_rect(Vector2(-27 + i * 4, -20 + i * 4), Vector2(16, 3), Color("#e0f2fe"))
		feather.rotation = -0.5
		item.add_child(feather)
	var float_item := create_tween().set_loops().bind_node(item)
	float_item.tween_property(item, "position:y", position_value.y - 7, 0.8).set_trans(Tween.TRANS_SINE)
	float_item.tween_property(item, "position:y", position_value.y, 0.8).set_trans(Tween.TRANS_SINE)
	item.body_entered.connect(_on_wing_shoes_collected.bind(item))
	world.add_child(item)


func build_spikes(position_value: Vector2, size_value: Vector2) -> void:
	var spikes := Area2D.new()
	spikes.position = position_value + size_value / 2.0
	spikes.collision_layer = 2
	spikes.collision_mask = STAGE_LAYER
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size_value
	shape_node.shape = shape
	spikes.add_child(shape_node)
	var visual := Polygon2D.new()
	var points := PackedVector2Array()
	points.append(Vector2(-size_value.x / 2.0, size_value.y / 2.0))
	var spike_count := 9
	for i in spike_count:
		var x: float = -size_value.x / 2.0 + float(i) * size_value.x / float(spike_count)
		points.append(Vector2(x + size_value.x / float(spike_count * 2), -size_value.y / 2.0))
		points.append(Vector2(x + size_value.x / float(spike_count), size_value.y / 2.0))
	visual.polygon = points
	visual.color = Color("#e2e8f0")
	spikes.add_child(visual)
	spikes.body_entered.connect(_on_spikes_touched)
	world.add_child(spikes)


func build_enemy(position_value: Vector2, left_bound: float, right_bound: float, speed: float) -> void:
	var enemy := Area2D.new()
	enemy.position = position_value
	enemy.collision_layer = 2
	enemy.collision_mask = STAGE_LAYER
	var shape_node := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 17
	shape.height = 30
	shape_node.shape = shape
	enemy.add_child(shape_node)
	var body_visual := Polygon2D.new()
	body_visual.polygon = PackedVector2Array([
		Vector2(-21, 14), Vector2(-19, -5), Vector2(-11, -18),
		Vector2(0, -22), Vector2(11, -18), Vector2(19, -5), Vector2(21, 14)
	])
	body_visual.color = Color("#a855f7")
	# Keep collision independent from the animated illustrated body.
	body_visual.visible = false
	enemy.add_child(body_visual)
	var left_eye := make_rect(Vector2(-10, -9), Vector2(5, 7), Color("#f8fafc"))
	var right_eye := make_rect(Vector2(5, -9), Vector2(5, 7), Color("#f8fafc"))
	left_eye.queue_free()
	right_eye.queue_free()
	var slime := Sprite2D.new()
	slime.texture = SLIME_TEXTURE
	slime.name = "SlimeVisual"
	slime.scale = Vector2(0.65, 0.65)
	slime.position = Vector2(0, -4)
	enemy.add_child(slime)
	enemy.body_entered.connect(_on_enemy_touched.bind(enemy))
	world.add_child(enemy)
	enemies.append({"node": enemy, "left": left_bound, "right": right_bound, "speed": speed, "direction": 1.0})


func build_flag(position_value: Vector2) -> void:
	var flag := Area2D.new()
	flag.position = position_value
	flag.collision_layer = 2
	flag.collision_mask = STAGE_LAYER
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(42, 110)
	shape_node.shape = shape
	shape_node.position = Vector2(0, -55)
	flag.add_child(shape_node)
	var pole := make_rect(Vector2(-3, -115), Vector2(6, 115), Color("#e2e8f0"))
	flag.add_child(pole)
	var cloth := Polygon2D.new()
	flag_cloth = cloth
	cloth.polygon = PackedVector2Array([Vector2(3, -110), Vector2(3, -70), Vector2(-42, -90)])
	cloth.color = Color("#22c55e")
	flag.add_child(cloth)
	flag.body_entered.connect(_on_flag_reached)
	world.add_child(flag)


func _physics_process(delta: float) -> void:
	if not visible or finished or not is_instance_valid(player):
		return

	platform_time += delta
	if is_instance_valid(flag_cloth):
		flag_cloth.polygon = PackedVector2Array([Vector2(3, -110), Vector2(3, -70), Vector2(-42, -90 + sin(platform_time * 4.0) * 5.0)])
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if player.is_on_floor():
		coyote_left = 0.1
	else:
		coyote_left = maxf(0.0, coyote_left - delta)
	if jump_buffer > 0.0 and coyote_left > 0.0:
		perform_jump(false)
	if is_instance_valid(moving_platform):
		moving_platform.position.x = 700.0 + sin(platform_time * 1.8) * 65.0

	update_enemies(delta)
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A):
		direction = -1.0
	elif Input.is_key_pressed(KEY_D):
		direction = 1.0
	player.velocity.x = move_toward(player.velocity.x, direction * MOVE_SPEED, (2100.0 if direction != 0 else 1700.0) * delta)
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	else:
		double_jump_available = has_wing_shoes

	if direction != 0.0:
		player_sprite.flip_h = direction < 0.0
		player_sprite.play("walk")
	else:
		player_sprite.pause()
		player_sprite.frame = 0

	player.move_and_slide()
	player.position.x = clampf(player.position.x, 18.0, 942.0)
	if player.is_on_floor() and not was_grounded:
		burst(player.position, Color("#dce5cc"), 9)
		player_sprite.scale = Vector2(0.09, 0.061)
	player_sprite.scale = player_sprite.scale.lerp(Vector2(0.075, 0.075), minf(delta * 13.0, 1.0))
	player_sprite.rotation = lerpf(player_sprite.rotation, direction * 0.045 if player.is_on_floor() else player.velocity.x * 0.0004, minf(delta * 10.0, 1.0))
	if not player.is_on_floor():
		player_sprite.pause()
	was_grounded = player.is_on_floor()
	if player.position.y > 570:
		restart_after_failure("아래로 떨어졌습니다!")


func _unhandled_input(event: InputEvent) -> void:
	if not visible or finished or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			jump_buffer = 0.12
			if player.is_on_floor() or coyote_left > 0.0:
				perform_jump(false)
			elif double_jump_available:
				perform_jump(true)
	elif event is InputEventKey and not event.pressed and event.keycode == KEY_SPACE and player.velocity.y < -180.0:
		player.velocity.y *= 0.55


func perform_jump(extra: bool) -> void:
	player.velocity.y = -JUMP_SPEED
	jump_buffer = 0.0
	coyote_left = 0.0
	if extra:
		double_jump_available = false
		show_message("이단 점프!", 0.7)
	player_sprite.scale = Vector2(0.061, 0.088)
	burst(player.position, Color("#b5e9f1") if extra else Color("#e3dbc4"), 10)
	Sfx.play("jump", -5.0, 1.18 if extra else 0.92, 0.05)


func burst(at: Vector2, tint: Color, count: int) -> void:
	for i in count:
		var spark := make_rect(at, Vector2(3, 3), tint)
		world.add_child(spark)
		var angle := TAU * float(i) / float(count)
		var tween := create_tween().set_parallel(true).bind_node(spark)
		tween.tween_property(spark, "position", at + Vector2(cos(angle) * 25.0, sin(angle) * 18.0 - 8.0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.35)
		tween.chain().tween_callback(spark.queue_free)


func update_enemies(delta: float) -> void:
	for enemy_data in enemies:
		if not is_instance_valid(enemy_data["node"]):
			continue
		var enemy: Area2D = enemy_data["node"]
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.has_meta("defeated"):
			continue
		var direction: float = enemy_data["direction"]
		enemy.position.x += direction * float(enemy_data["speed"]) * delta
		var slime := enemy.get_node("SlimeVisual") as Sprite2D
		var wobble := sin(platform_time * 8.0 + float(enemy_data["left"]))
		slime.scale = Vector2(0.65 + wobble * 0.045, 0.65 - wobble * 0.045)
		slime.rotation = direction * 0.06
		slime.flip_h = direction < 0.0
		if enemy.position.x <= float(enemy_data["left"]):
			enemy.position.x = float(enemy_data["left"])
			enemy_data["direction"] = 1.0
		elif enemy.position.x >= float(enemy_data["right"]):
			enemy.position.x = float(enemy_data["right"])
			enemy_data["direction"] = -1.0


func _on_coin_collected(body: Node2D, coin: Area2D) -> void:
	if body != player or coin.is_queued_for_deletion():
		return
	coins_collected += 1
	burst(coin.position, Color("#ffe19b"), 16)
	Sfx.play("coin", -1.0, 1.0 + float(coins_collected - 1) * 0.08)
	coin.queue_free()
	update_hud()
	show_message("코인 획득!  %d / 3" % coins_collected, 0.8)


func _on_wing_shoes_collected(body: Node2D, item: Area2D) -> void:
	if body != player or item.is_queued_for_deletion():
		return
	has_wing_shoes = true
	burst(item.position, Color("#c4f5ff"), 20)
	Sfx.play("ui_confirm", 0.0, 1.08)
	double_jump_available = true
	item.queue_free()
	update_hud()
	show_message("날개 신발 획득! 공중에서 SPACE를 한 번 더 누르세요", 2.0)


func _on_spikes_touched(body: Node2D) -> void:
	if body == player:
		restart_after_failure("가시에 닿았습니다!")


func _on_enemy_touched(body: Node2D, enemy: Area2D) -> void:
	if body != player or finished or enemy.is_queued_for_deletion() or enemy.has_meta("defeated"):
		return
	if player.velocity.y > 80.0 and player.position.y < enemy.position.y:
		Sfx.play("enemy_down", -2.0, 1.15, 0.05)
		burst(enemy.position, Color("#90dbc6"), 18)
		enemy.set_meta("defeated", true)
		enemy.set_deferred("monitoring", false)
		var collapse := create_tween().set_parallel(true).bind_node(enemy)
		collapse.tween_property(enemy, "scale", Vector2(1.35, 0.12), 0.16)
		collapse.tween_property(enemy, "modulate:a", 0.0, 0.22)
		collapse.chain().tween_callback(enemy.queue_free)
		player.velocity.y = -330.0
		show_message("슬라임을 밟았습니다!", 0.7)
	elif not invincible:
		take_damage(enemy.position)


func take_damage(enemy_position: Vector2) -> void:
	Sfx.play("player_hit", -1.0, 0.9, 0.04)
	burst(player.position - Vector2(0, 20), Color("#ffb3a1"), 15)
	var generation := stage_generation
	health -= 1
	update_hud()
	if health <= 0:
		restart_after_failure("하트를 모두 잃었습니다!")
		return
	invincible = true
	player.velocity = Vector2(-260.0 if player.position.x < enemy_position.x else 260.0, -300.0)
	player_sprite.modulate = Color("#ffffff66")
	show_message("몬스터에게 닿았습니다!", 0.8)
	await get_tree().create_timer(0.85).timeout
	if generation != stage_generation:
		return
	if is_instance_valid(player):
		player_sprite.modulate = Color.WHITE
	invincible = false


func restart_after_failure(reason: String) -> void:
	if finished:
		return
	finished = true
	message_label.text = reason + "  다시 시작합니다"
	await get_tree().create_timer(0.75).timeout
	if visible:
		rebuild_stage()


func _on_flag_reached(body: Node2D) -> void:
	if body != player or finished:
		return
	if coins_collected < 3:
		show_message("코인이 부족합니다!  %d / 3" % coins_collected, 1.2)
		return
	finished = true
	Sfx.play("ui_confirm", 1.0, 1.0)
	result_overlay.visible = true


func _on_return_pressed() -> void:
	visible = false
	result_overlay.visible = false
	game_won.emit()


func update_hud() -> void:
	coin_label.text = "◆ 코인  %d / 3" % coins_collected
	heart_label.text = "♥ 하트  %d / 2" % health
	item_label.text = "날개 신발: ON · 이단 점프 가능" if has_wing_shoes else "날개 신발: 아직 없음"


func show_message(text_value: String, duration: float) -> void:
	message_label.text = text_value
	var expected_text := text_value
	await get_tree().create_timer(duration).timeout
	if message_label.text == expected_text and visible and not finished:
		message_label.text = "A/D 또는 ←/→ 이동 · SPACE 점프 · 코인 3개를 모아 오른쪽 깃발까지!"


func make_hero_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	var frame_width: float = float(HERO_TEXTURE.get_width()) / 4.0
	for i in 4:
		var atlas := AtlasTexture.new()
		atlas.atlas = HERO_TEXTURE
		atlas.region = Rect2(frame_width * i, 0, frame_width, HERO_TEXTURE.get_height())
		frames.add_frame("walk", atlas)
	return frames


func make_rect(position_value: Vector2, size_value: Vector2, color: Color) -> Polygon2D:
	var rect := Polygon2D.new()
	rect.position = position_value
	rect.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size_value.x, 0), size_value, Vector2(0, size_value.y)])
	rect.color = color
	return rect


func make_label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
