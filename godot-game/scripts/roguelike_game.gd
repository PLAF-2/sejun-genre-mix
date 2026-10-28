extends Control

signal game_won
signal boss_gauntlet_won

const ARENA_SIZE := Vector2(960, 540)
const PLAYER_SPEED := 235.0
const GAME_DURATION := 60.0
const HERO_TEXTURE := preload("res://assets/characters/hero_walk_user_v3.png")
const AI_TEXTURES := [preload("res://assets/ai-logos/grok-badge.svg"), preload("res://assets/ai-logos/gemini-color-badge.svg"), preload("res://assets/ai-logos/claude-color-badge.svg")]
const BOSS_TEXTURE := preload("res://assets/ai-logos/openai-badge.svg")
const ENEMY_CELL_SIZE := 724.0
const GAUNTLET_KILL_TARGET := 120

var world: Node2D
var player: Node2D
var player_sprite: AnimatedSprite2D
var player_position := Vector2(480, 285)
var enemies: Array[Dictionary] = []
var gems: Array[Dictionary] = []
var healing_items: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var hostile_projectiles: Array[Dictionary] = []
var skill_levels := {"fire": 1, "lightning": 0, "ice": 0}

var state := "idle"
var elapsed := 0.0
var spawn_timer := 0.0
var fire_timer := 0.0
var lightning_timer := 0.0
var ice_timer := 0.0
var invincible_timer := 0.0
var health := 5
var level := 1
var experience := 0
var next_experience := 5
var boss_spawned := false
var boss_alive := false
var boss_attack_timer := 0.0
var kills := 0
var regeneration_ticks := 0
var regeneration_timer := 0.0
var boss_gauntlet_mode := false
var gauntlet_spawned := 0
var gauntlet_skill_snapshot := {"fire": 1, "lightning": 0, "ice": 0}

var timer_label: Label
var health_label: Label
var level_label: Label
var skill_label: Label
var xp_bar: ProgressBar
var boss_bar: ProgressBar
var message_label: Label
var level_overlay: ColorRect
var level_title: Label
var skill_buttons: Dictionary = {}
var fail_overlay: ColorRect
var clear_overlay: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_interface()
	visible = false


func build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#071a22")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	world = Node2D.new()
	add_child(world)

	var top_bar := ColorRect.new()
	top_bar.color = Color("#0f172aee")
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(960, 72)
	top_bar.z_index = 30
	add_child(top_bar)

	timer_label = make_label(Vector2(22, 15), Vector2(190, 40), 24, Color("#fde68a"))
	top_bar.add_child(timer_label)
	health_label = make_label(Vector2(225, 15), Vector2(190, 40), 22, Color("#fb7185"))
	top_bar.add_child(health_label)
	level_label = make_label(Vector2(420, 15), Vector2(180, 40), 21, Color("#86efac"))
	top_bar.add_child(level_label)
	skill_label = make_label(Vector2(590, 12), Vector2(185, 46), 14, Color("#bae6fd"))
	skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_bar.add_child(skill_label)

	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(20, 78)
	xp_bar.size = Vector2(920, 14)
	xp_bar.show_percentage = false
	xp_bar.z_index = 30
	add_child(xp_bar)

	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(280, 104)
	boss_bar.size = Vector2(400, 18)
	boss_bar.max_value = 300
	boss_bar.value = 300
	boss_bar.show_percentage = false
	boss_bar.visible = false
	boss_bar.z_index = 30
	add_child(boss_bar)

	message_label = make_label(Vector2(210, 126), Vector2(540, 38), 18, Color.WHITE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color", Color("#020617"))
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.z_index = 30
	add_child(message_label)

	build_level_overlay()
	build_fail_overlay()
	build_clear_overlay()


func build_level_overlay() -> void:
	level_overlay = ColorRect.new()
	level_overlay.color = Color("#020617e8")
	level_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_overlay.visible = false
	level_overlay.z_index = 100
	add_child(level_overlay)

	level_title = make_label(Vector2(200, 62), Vector2(560, 64), 39, Color("#fde047"))
	level_title.text = "LEVEL UP!"
	level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_overlay.add_child(level_title)

	var guide := make_label(Vector2(210, 126), Vector2(540, 34), 18, Color("#cbd5e1"))
	guide.text = "강화할 스킬을 하나 선택하세요"
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_overlay.add_child(guide)

	var skill_data := [
		["fire", "🔥 화염", Color("#f97316")],
		["lightning", "⚡ 번개", Color("#facc15")],
		["ice", "❄ 얼음", Color("#67e8f9")]
	]
	for i in skill_data.size():
		var key: String = skill_data[i][0]
		var button := Button.new()
		button.position = Vector2(90 + i * 275, 190)
		button.size = Vector2(230, 205)
		button.add_theme_font_size_override("font_size", 19)
		button.add_theme_color_override("font_color", skill_data[i][2])
		button.pressed.connect(_choose_skill.bind(key))
		level_overlay.add_child(button)
		skill_buttons[key] = button

	var note := make_label(Vector2(175, 430), Vector2(610, 42), 16, Color("#94a3b8"))
	note.text = "LV.3까지 자유 강화 · 세 스킬이 모두 LV.3이면 LV.4 궁극 진화 해금"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_overlay.add_child(note)


func build_fail_overlay() -> void:
	fail_overlay = ColorRect.new()
	fail_overlay.color = Color("#020617ed")
	fail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fail_overlay.visible = false
	fail_overlay.z_index = 110
	add_child(fail_overlay)

	var title := make_label(Vector2(200, 135), Vector2(560, 78), 45, Color("#fb7185"))
	title.text = "SURVIVAL FAILED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fail_overlay.add_child(title)

	var retry := Button.new()
	retry.position = Vector2(265, 300)
	retry.size = Vector2(205, 60)
	retry.text = "처음부터 재도전"
	retry.add_theme_font_size_override("font_size", 19)
	retry.pressed.connect(_retry_current_mode)
	fail_overlay.add_child(retry)

	var exit := Button.new()
	exit.position = Vector2(490, 300)
	exit.size = Vector2(205, 60)
	exit.text = "복도로 돌아가기"
	exit.add_theme_font_size_override("font_size", 19)
	exit.pressed.connect(_exit_to_corridor)
	fail_overlay.add_child(exit)


func build_clear_overlay() -> void:
	clear_overlay = ColorRect.new()
	clear_overlay.color = Color("#020617ed")
	clear_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_overlay.visible = false
	clear_overlay.z_index = 110
	add_child(clear_overlay)

	var title := make_label(Vector2(190, 120), Vector2(580, 82), 45, Color("#4ade80"))
	title.text = "ROOM 4 CLEAR!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_overlay.add_child(title)

	var summary := make_label(Vector2(210, 220), Vector2(540, 55), 20, Color("#e2e8f0"))
	summary.name = "Summary"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_overlay.add_child(summary)

	var return_button := Button.new()
	return_button.position = Vector2(350, 325)
	return_button.size = Vector2(260, 62)
	return_button.text = "복도로 돌아가기"
	return_button.add_theme_font_size_override("font_size", 20)
	return_button.pressed.connect(_finish_room)
	clear_overlay.add_child(return_button)


func start_game() -> void:
	boss_gauntlet_mode = false
	visible = true
	level_overlay.visible = false
	fail_overlay.visible = false
	clear_overlay.visible = false
	state = "playing"
	elapsed = 0.0
	spawn_timer = 0.35
	fire_timer = 0.2
	lightning_timer = 0.0
	ice_timer = 0.0
	invincible_timer = 0.0
	health = 5
	level = 1
	experience = 0
	next_experience = 5
	boss_spawned = false
	boss_alive = false
	boss_attack_timer = 0.0
	boss_bar.visible = false
	kills = 0
	regeneration_ticks = 0
	regeneration_timer = 0.0
	skill_levels = {"fire": 1, "lightning": 0, "ice": 0}
	clear_world()
	build_arena()
	build_player()
	message_label.text = "WASD 이동 · 자동 공격 · 경험치 보석을 모아 레벨업 스킬을 고르세요"
	update_hud()


func start_boss_gauntlet(inherited_skills: Dictionary) -> void:
	boss_gauntlet_mode = true
	gauntlet_spawned = 0
	visible = true
	level_overlay.visible = false
	fail_overlay.visible = false
	clear_overlay.visible = false
	state = "playing"
	elapsed = 0.0
	spawn_timer = 0.05
	fire_timer = 0.05
	lightning_timer = 0.05
	ice_timer = 0.05
	invincible_timer = 0.0
	health = 5
	experience = 0
	next_experience = 999999
	boss_spawned = false
	boss_alive = false
	boss_attack_timer = 0.0
	boss_bar.visible = false
	kills = 0
	regeneration_ticks = 0
	regeneration_timer = 0.0
	for key in ["fire", "lightning", "ice"]:
		skill_levels[key] = clampi(int(inherited_skills.get(key, 0)), 0, 4)
	gauntlet_skill_snapshot = skill_levels.duplicate(true)
	if int(skill_levels.fire)+int(skill_levels.lightning)+int(skill_levels.ice) == 0: skill_levels.fire = 1
	level = int(skill_levels.fire) + int(skill_levels.lightning) + int(skill_levels.ice)
	clear_world()
	build_arena()
	build_player()
	message_label.text = "FINAL RUSH · 강화 능력 그대로 부하 %d마리를 쓸어버리세요!" % GAUNTLET_KILL_TARGET
	update_hud()


func clear_world() -> void:
	for child in world.get_children():
		child.queue_free()
	enemies.clear()
	gems.clear()
	healing_items.clear()
	projectiles.clear()
	hostile_projectiles.clear()


func build_arena() -> void:
	for x in range(0, 960, 64):
		for y in range(96, 540, 64):
			var tile := Polygon2D.new()
			tile.position = Vector2(x, y)
			tile.polygon = PackedVector2Array([Vector2.ZERO, Vector2(62, 0), Vector2(62, 62), Vector2(0, 62)])
			tile.color = Color("#0f2f35") if (x / 64 + y / 64 as int) % 2 == 0 else Color("#123941")
			tile.z_index = 0
			world.add_child(tile)


func build_player() -> void:
	player_position = Vector2(480, 305)
	player = Node2D.new()
	player.position = player_position
	player.z_index = 5
	world.add_child(player)
	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = make_hero_frames()
	player_sprite.animation = "walk"
	player_sprite.scale = Vector2(0.074, 0.074)
	player_sprite.position = Vector2(0, -11)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.add_child(player_sprite)


func _process(delta: float) -> void:
	if not visible or state != "playing" or level_overlay.visible:
		return
	elapsed += delta
	invincible_timer = maxf(0.0, invincible_timer - delta)
	update_player(delta)
	update_spawning(delta)
	update_enemies(delta)
	update_projectiles(delta)
	update_hostile_projectiles(delta)
	update_gems(delta)
	update_healing_items(delta)
	update_regeneration(delta)
	update_skills(delta)
	if not boss_gauntlet_mode and elapsed >= 48.0 and not boss_spawned:
		spawn_boss()
	if not boss_gauntlet_mode and elapsed >= GAME_DURATION and boss_alive:
		message_label.text = "마지막 보스를 쓰러뜨리세요!"
	if boss_alive:
		boss_attack_timer -= delta
		if boss_attack_timer <= 0.0:
			cast_boss_attack()
			boss_attack_timer = 1.55
	update_hud()


func update_player(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): direction.y += 1.0
	if direction.length_squared() > 0.0:
		direction = direction.normalized()
		if absf(direction.x) > 0.05:
			player_sprite.flip_h = direction.x < 0.0
		player_sprite.play("walk")
	else:
		player_sprite.pause()
		player_sprite.frame = 0
	player_position += direction * PLAYER_SPEED * delta
	player_position.x = clampf(player_position.x, 28.0, 932.0)
	player_position.y = clampf(player_position.y, 120.0, 512.0)
	player.position = player_position
	player.modulate.a = 0.45 if invincible_timer > 0.0 and int(invincible_timer * 12.0) % 2 == 0 else 1.0


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


func update_spawning(delta: float) -> void:
	if boss_gauntlet_mode:
		if gauntlet_spawned >= GAUNTLET_KILL_TARGET:
			return
		if enemies.size() >= 55:
			return
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			var burst_count := mini(6,mini(55-enemies.size(),GAUNTLET_KILL_TARGET-gauntlet_spawned))
			for i in burst_count:
				spawn_enemy(randf() < 0.10)
				gauntlet_spawned += 1
			spawn_timer = 0.24
		return
	if elapsed >= GAME_DURATION:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_enemy(false)
		# 레벨 3 전에는 일반 몬스터만 천천히 등장해 스킬 선택을 익힐 시간을 준다.
		if level < 3:
			spawn_timer = 0.92
			return
		if elapsed > 20.0 and randf() < 0.30:
			spawn_enemy(true)
		if elapsed > 38.0 and randf() < 0.34:
			spawn_enemy(false)
		spawn_timer = maxf(0.21, 0.72 - elapsed * 0.007)


func spawn_enemy(elite: bool) -> void:
	var spawn_position: Vector2
	var side := randi() % 4
	if side == 0: spawn_position = Vector2(randf_range(20, 940), 105)
	elif side == 1: spawn_position = Vector2(940, randf_range(110, 520))
	elif side == 2: spawn_position = Vector2(randf_range(20, 940), 520)
	else: spawn_position = Vector2(20, randf_range(110, 520))
	var node := Node2D.new()
	node.position = spawn_position
	node.z_index = 2
	world.add_child(node)
	var radius := 18.0 if not elite else 25.0
	var shadow := make_ellipse(Vector2(radius, radius * 0.4), Color("#02061799"))
	shadow.position = Vector2(0, radius * 0.72)
	shadow.z_index = -1
	node.add_child(shadow)
	var sprite_index := 2 if elite else randi() % 2
	var sprite := make_enemy_sprite(sprite_index, 62.0 if not elite else 82.0)
	sprite.position = Vector2(0, -8 if not elite else -13)
	node.add_child(sprite)
	var beginner_phase := not boss_gauntlet_mode and level < 3 and not elite
	enemies.append({
		"node": node, "hp": 3.4 if beginner_phase else 3.2 if boss_gauntlet_mode and not elite else 5.5 if not elite else 8.5 if boss_gauntlet_mode else 16.0,
		"speed": randf_range(48.0, 62.0) if beginner_phase else randf_range(72.0, 98.0) if boss_gauntlet_mode and not elite else randf_range(68.0, 88.0) if not elite else 68.0 if boss_gauntlet_mode else 60.0,
		"radius": radius, "xp": 1 if not elite else 3,
		"slow": 0.0, "boss": false
	})


func spawn_boss() -> void:
	boss_spawned = true
	boss_alive = true
	boss_attack_timer = 1.0
	boss_bar.visible = true
	boss_bar.max_value = 300.0
	boss_bar.value = 300.0
	message_label.text = "WARNING · 보스 등장!"
	var node := Node2D.new()
	node.position = Vector2(480, 125)
	node.z_index = 3
	world.add_child(node)
	var boss_shadow := make_ellipse(Vector2(58, 18), Color("#020617bb"))
	boss_shadow.position = Vector2(0, 44)
	boss_shadow.z_index = -2
	node.add_child(boss_shadow)
	var aura := make_circle(72.0, Color("#a855f733"))
	aura.z_index = -3
	node.add_child(aura)
	var boss_sprite := AnimatedSprite2D.new()
	boss_sprite.sprite_frames = make_boss_idle_frames()
	boss_sprite.animation = "idle"
	boss_sprite.scale = Vector2.ONE * (158.0 / float(BOSS_TEXTURE.get_height()))
	boss_sprite.position = Vector2(0, -10)
	boss_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	node.add_child(boss_sprite)
	boss_sprite.play("idle")
	enemies.append({"node": node, "hp": 300.0, "speed": 46.0, "radius": 50.0, "xp": 0, "slow": 0.0, "boss": true})
	flash_world(Color("#a855f7"))


func make_boss_idle_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 3.2)
	frames.set_animation_loop("idle", true)
	frames.add_frame("idle", BOSS_TEXTURE)
	return frames


func update_enemies(delta: float) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy.node):
			continue
		enemy.slow = maxf(0.0, float(enemy.slow) - delta)
		var direction: Vector2 = (player_position - enemy.node.position).normalized()
		var speed_multiplier := 0.56 if enemy.slow > 0.0 else 1.0
		enemy.node.position += direction * float(enemy.speed) * speed_multiplier * delta
		if enemy.node.position.distance_to(player_position) < float(enemy.radius) + 15.0:
			damage_player(1)


func damage_player(amount: int) -> void:
	if invincible_timer > 0.0 or state != "playing":
		return
	health -= amount
	Sfx.play("player_hit", -3.0, 0.9, 0.06)
	invincible_timer = 1.0
	flash_world(Color("#ef4444"))
	if health <= 0:
		state = "failed"
		fail_overlay.visible = true
	update_hud()


func update_skills(delta: float) -> void:
	fire_timer -= delta
	lightning_timer -= delta
	ice_timer -= delta
	if fire_timer <= 0.0:
		cast_fire()
		fire_timer = 0.74
	if skill_levels.lightning > 0 and lightning_timer <= 0.0:
		cast_lightning()
		lightning_timer = 1.35
	if skill_levels.ice > 0 and ice_timer <= 0.0:
		cast_ice()
		ice_timer = 1.15


func cast_fire() -> void:
	var target := nearest_enemy(player_position)
	if target.is_empty(): return
	var base_direction: Vector2 = (target.node.position - player_position).normalized()
	var directions := [base_direction]
	if skill_levels.fire >= 4:
		directions = [base_direction.rotated(-0.36), base_direction.rotated(-0.18), base_direction, base_direction.rotated(0.18), base_direction.rotated(0.36)]
	elif skill_levels.fire >= 3:
		directions = [base_direction.rotated(-0.24), base_direction, base_direction.rotated(0.24)]
	for direction in directions:
		var damage := 2.2 if skill_levels.fire == 1 else 5.4 if skill_levels.fire >= 4 else 4.0
		spawn_projectile(player_position, direction, 390.0 if skill_levels.fire >= 4 else 370.0, damage, "fire", Color("#fb923c"), 10.0 if skill_levels.fire >= 4 else 8.0)


func cast_lightning() -> void:
	var target_count := 7 if skill_levels.lightning >= 4 else 4 if skill_levels.lightning >= 3 else 1
	var targets := nearest_enemies(player_position, target_count)
	var origin := player_position
	for enemy in targets:
		spawn_lightning_arc(origin, enemy.node.position, skill_levels.lightning >= 3, skill_levels.lightning >= 4)
		var damage := 3.0 if skill_levels.lightning == 1 else 7.0 if skill_levels.lightning >= 4 else 5.2
		damage_enemy(enemy, damage, "lightning")
		origin = enemy.node.position


func cast_ice() -> void:
	var target := nearest_enemy(player_position)
	if target.is_empty(): return
	if skill_levels.ice >= 4:
		spawn_frost_nova()
		for enemy in enemies.duplicate():
			if is_instance_valid(enemy.node) and enemy.node.position.distance_to(player_position) < 125.0:
				enemy.slow = 3.2
				damage_enemy(enemy, 2.5, "ice")
		for i in 12:
			spawn_projectile(player_position, Vector2.RIGHT.rotated(TAU * float(i) / 12.0), 310.0, 4.6, "ice", Color("#67e8f9"), 8.0)
	elif skill_levels.ice >= 3:
		spawn_frost_nova()
		for i in 8:
			spawn_projectile(player_position, Vector2.RIGHT.rotated(TAU * float(i) / 8.0), 285.0, 3.8, "ice", Color("#67e8f9"), 7.0)
	else:
		var direction: Vector2 = (target.node.position - player_position).normalized()
		spawn_projectile(player_position, direction, 300.0, 2.0 if skill_levels.ice == 1 else 3.8, "ice", Color("#67e8f9"), 7.0)


func spawn_projectile(position_value: Vector2, direction: Vector2, speed: float, damage: float, kind: String, color: Color, radius: float) -> void:
	var node := Node2D.new()
	node.position = position_value
	node.z_index = 6
	world.add_child(node)
	if kind == "fire":
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([Vector2(12, 0), Vector2(2, -8), Vector2(-11, 0), Vector2(2, 8)])
		flame.color = color
		node.add_child(flame)
		var flame_core := make_circle(4.0, Color("#fef08a"))
		node.add_child(flame_core)
	else:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(13, 0), Vector2(0, -6), Vector2(-10, 0), Vector2(0, 6)])
		shard.color = color
		node.add_child(shard)
		var shard_core := Polygon2D.new()
		shard_core.polygon = PackedVector2Array([Vector2(8, 0), Vector2(0, -2), Vector2(-3, 0), Vector2(0, 2)])
		shard_core.color = Color.WHITE
		node.add_child(shard_core)
	node.rotation = direction.angle()
	var glow := make_circle(radius * 1.8, Color(color, 0.18))
	glow.z_index = -1
	node.add_child(glow)
	projectiles.append({"node": node, "direction": direction, "speed": speed, "damage": damage, "kind": kind, "radius": radius, "life": 2.0, "trail": 0.0})


func update_projectiles(delta: float) -> void:
	for projectile in projectiles.duplicate():
		if not is_instance_valid(projectile.node): continue
		projectile.node.position += projectile.direction * float(projectile.speed) * delta
		projectile.life = float(projectile.life) - delta
		projectile.trail = float(projectile.trail) - delta
		if projectile.trail <= 0.0:
			spawn_projectile_trail(projectile.node.position, projectile.kind)
			projectile.trail = 0.035 if projectile.kind == "fire" and skill_levels.fire >= 4 else 0.045 if projectile.kind == "fire" and skill_levels.fire >= 3 else 0.08
		var hit := false
		for enemy in enemies.duplicate():
			if not is_instance_valid(enemy.node): continue
			if projectile.node.position.distance_to(enemy.node.position) <= float(projectile.radius) + float(enemy.radius):
				damage_enemy(enemy, float(projectile.damage), projectile.kind)
				if projectile.kind == "ice": enemy.slow = 2.4
				if projectile.kind == "fire" and skill_levels.fire >= 3:
					fire_explosion(projectile.node.position)
				hit = true
				break
		if hit or projectile.life <= 0.0 or not Rect2(-40, 60, 1040, 540).has_point(projectile.node.position):
			remove_projectile(projectile)


func cast_boss_attack() -> void:
	var boss := {}
	for enemy in enemies:
		if enemy.boss and is_instance_valid(enemy.node):
			boss = enemy
			break
	if boss.is_empty(): return
	message_label.text = "보스의 지옥불 탄막!"
	var warning := make_ring(48.0, 39.0, Color("#f97316aa"))
	warning.position = boss.node.position
	warning.z_index = 8
	world.add_child(warning)
	var warning_tween := create_tween()
	warning_tween.set_parallel(true)
	warning_tween.tween_property(warning, "scale", Vector2(2.0, 2.0), 0.38)
	warning_tween.tween_property(warning, "modulate:a", 0.0, 0.38)
	warning_tween.chain().tween_callback(warning.queue_free)
	for i in 12:
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / 12.0 + elapsed * 0.17)
		spawn_hostile_projectile(boss.node.position, direction)


func spawn_hostile_projectile(position_value: Vector2, direction: Vector2) -> void:
	var node := Node2D.new()
	node.position = position_value
	node.z_index = 7
	world.add_child(node)
	var outer := Polygon2D.new()
	outer.polygon = PackedVector2Array([Vector2(0, -11), Vector2(8, 0), Vector2(0, 11), Vector2(-8, 0)])
	outer.color = Color("#ef4444")
	node.add_child(outer)
	var core := make_circle(4.0, Color("#fef08a"))
	node.add_child(core)
	hostile_projectiles.append({"node": node, "direction": direction, "speed": 175.0, "life": 4.2, "radius": 9.0})


func update_hostile_projectiles(delta: float) -> void:
	for projectile in hostile_projectiles.duplicate():
		if not is_instance_valid(projectile.node): continue
		projectile.node.position += projectile.direction * float(projectile.speed) * delta
		projectile.node.rotation += delta * 5.0
		projectile.life = float(projectile.life) - delta
		if projectile.node.position.distance_to(player_position) < float(projectile.radius) + 14.0:
			damage_player(1)
			remove_hostile_projectile(projectile)
		elif projectile.life <= 0.0 or not Rect2(-60, 50, 1080, 560).has_point(projectile.node.position):
			remove_hostile_projectile(projectile)


func remove_hostile_projectile(projectile: Dictionary) -> void:
	hostile_projectiles.erase(projectile)
	if is_instance_valid(projectile.node): projectile.node.queue_free()


func fire_explosion(position_value: Vector2) -> void:
	var ultimate: bool = int(skill_levels.fire) >= 4
	var blast_radius := 68.0 if ultimate else 42.0
	var burst := make_circle(blast_radius, Color("#ef444477") if ultimate else Color("#f9731666"))
	burst.position = position_value
	burst.z_index = 5
	world.add_child(burst)
	var ring := make_ring(55.0 if ultimate else 35.0, 42.0 if ultimate else 27.0, Color("#ffffffdd") if ultimate else Color("#fef08acc"))
	ring.position = position_value
	ring.z_index = 6
	world.add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(1.7, 1.7), 0.22)
	tween.tween_property(burst, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(burst.queue_free)
	var ring_tween := create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(2.0, 2.0), 0.24)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	ring_tween.chain().tween_callback(ring.queue_free)
	if ultimate:
		var inferno_ring := make_ring(32.0, 23.0, Color("#a855f7dd"))
		inferno_ring.position = position_value
		inferno_ring.z_index = 7
		world.add_child(inferno_ring)
		var inferno_tween := create_tween()
		inferno_tween.set_parallel(true)
		inferno_tween.tween_property(inferno_ring, "scale", Vector2(3.0, 3.0), 0.32)
		inferno_tween.tween_property(inferno_ring, "modulate:a", 0.0, 0.32)
		inferno_tween.chain().tween_callback(inferno_ring.queue_free)
	for i in 10:
		spawn_hit_particles(position_value + Vector2.RIGHT.rotated(TAU * float(i) / 10.0) * 18.0, Color("#fb923c"))
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy.node) and enemy.node.position.distance_to(position_value) < (82.0 if ultimate else 55.0):
			damage_enemy(enemy, 3.2 if ultimate else 2.0, "fire")


func spawn_lightning_arc(from: Vector2, to: Vector2, evolved: bool, ultimate: bool) -> void:
	var line := Line2D.new()
	var points := PackedVector2Array()
	var segment_count := 9 if evolved else 6
	var perpendicular := (to - from).normalized().orthogonal()
	for i in segment_count + 1:
		var ratio := float(i) / float(segment_count)
		var jitter := 0.0 if i == 0 or i == segment_count else randf_range(-11.0, 11.0) * (1.35 if evolved else 0.7)
		points.append(from.lerp(to, ratio) + perpendicular * jitter)
	line.points = points
	line.width = 9.0 if ultimate else 7.0 if evolved else 4.0
	line.default_color = Color("#ffffff") if ultimate else Color("#fef08a")
	line.z_index = 7
	world.add_child(line)
	if evolved:
		var glow: Line2D = line.duplicate()
		glow.width = 15.0
		glow.default_color = Color("#60a5fa55")
		glow.z_index = 6
		world.add_child(glow)
		create_tween().tween_property(glow, "modulate:a", 0.0, 0.22).finished.connect(glow.queue_free)
	if ultimate:
		for i in 3:
			var spark_position := from.lerp(to, float(i + 1) / 4.0)
			spawn_hit_particles(spark_position, Color("#c084fc"))
	create_tween().tween_property(line, "modulate:a", 0.0, 0.18).finished.connect(line.queue_free)


func spawn_frost_nova() -> void:
	var ring := make_ring(28.0, 21.0, Color("#a5f3fccc"))
	ring.position = player_position
	ring.z_index = 6
	world.add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.36)
	tween.chain().tween_callback(ring.queue_free)


func spawn_projectile_trail(position_value: Vector2, kind: String) -> void:
	var color := Color("#fb923c88") if kind == "fire" else Color("#67e8f988")
	var particle := make_circle(4.0 if kind == "fire" else 3.0, color)
	particle.position = position_value
	particle.z_index = 4
	world.add_child(particle)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "scale", Vector2(0.2, 0.2), 0.20)
	tween.tween_property(particle, "modulate:a", 0.0, 0.20)
	tween.chain().tween_callback(particle.queue_free)


func damage_enemy(enemy: Dictionary, damage: float, kind: String) -> void:
	if not is_instance_valid(enemy.node): return
	enemy.hp = float(enemy.hp) - damage
	if enemy.boss:
		boss_bar.value = maxf(0.0, float(enemy.hp))
	enemy.node.scale = Vector2(1.25, 0.78)
	create_tween().tween_property(enemy.node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	spawn_hit_particles(enemy.node.position, Color("#fb923c") if kind == "fire" else Color("#fef08a") if kind == "lightning" else Color("#67e8f9"))
	if enemy.hp <= 0.0:
		kill_enemy(enemy)


func kill_enemy(enemy: Dictionary) -> void:
	if not enemies.has(enemy): return
	var death_position: Vector2 = enemy.node.position
	var was_boss: bool = enemy.boss
	var xp_amount: int = enemy.xp
	Sfx.play("enemy_down", -8.0 if not enemy.boss else 0.0, 1.08 if not enemy.boss else 0.72, 0.08)
	enemies.erase(enemy)
	enemy.node.queue_free()
	kills += 1
	if boss_gauntlet_mode and not was_boss:
		spawn_gauntlet_kill_burst(death_position, kills)
		if kills % 15 == 0: spawn_healing_item(death_position)
		if gauntlet_spawned >= GAUNTLET_KILL_TARGET and enemies.is_empty():
			complete_boss_gauntlet()
			return
	if was_boss:
		boss_alive = false
		boss_bar.visible = false
		complete_game()
	elif xp_amount > 0 and not boss_gauntlet_mode:
		spawn_gem(death_position, xp_amount)
		var healing_chance := 0.18 if xp_amount >= 3 else 0.07
		if randf() < healing_chance:
			spawn_healing_item(death_position + Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)))


func spawn_gem(position_value: Vector2, amount: int) -> void:
	var node := Polygon2D.new()
	node.position = position_value
	node.polygon = PackedVector2Array([Vector2(0, -8), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)])
	node.color = Color("#4ade80") if amount == 1 else Color("#facc15")
	node.z_index = 3
	world.add_child(node)
	gems.append({"node": node, "amount": amount})


func update_gems(delta: float) -> void:
	for gem in gems.duplicate():
		if not is_instance_valid(gem.node): continue
		var distance: float = gem.node.position.distance_to(player_position)
		if distance < 145.0:
			gem.node.position = gem.node.position.move_toward(player_position, (320.0 + (145.0 - distance) * 3.0) * delta)
		if gem.node.position.distance_to(player_position) < 22.0:
			collect_gem(gem)


func collect_gem(gem: Dictionary) -> void:
	experience += int(gem.amount)
	gems.erase(gem)
	gem.node.queue_free()
	if not boss_gauntlet_mode and experience >= next_experience:
		trigger_level_up()
	update_hud()


func spawn_healing_item(position_value: Vector2) -> void:
	var node := Node2D.new()
	node.position = position_value
	node.z_index = 4
	world.add_child(node)
	var glow := make_circle(16.0, Color("#4ade8044"))
	glow.z_index = -1
	node.add_child(glow)
	var heart := Polygon2D.new()
	heart.polygon = PackedVector2Array([
		Vector2(0, 11), Vector2(-13, -2), Vector2(-11, -10), Vector2(-5, -14),
		Vector2(0, -10), Vector2(5, -14), Vector2(11, -10), Vector2(13, -2)
	])
	heart.color = Color("#fb7185")
	node.add_child(heart)
	var shine := make_circle(3.0, Color("#ffffffcc"))
	shine.position = Vector2(-5, -7)
	node.add_child(shine)
	var pulse := create_tween().set_loops()
	pulse.tween_property(node, "scale", Vector2(1.18, 1.18), 0.45).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(node, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)
	healing_items.append({"node": node, "life": 12.0, "phase": randf_range(0.0, TAU)})


func update_healing_items(delta: float) -> void:
	for item in healing_items.duplicate():
		if not is_instance_valid(item.node):
			healing_items.erase(item)
			continue
		item.life = float(item.life) - delta
		item.phase = float(item.phase) + delta * 2.5
		item.node.rotation = sin(float(item.phase)) * 0.08
		if item.node.position.distance_to(player_position) < 27.0:
			collect_healing_item(item)
		elif item.life <= 0.0:
			healing_items.erase(item)
			item.node.queue_free()


func collect_healing_item(item: Dictionary) -> void:
	healing_items.erase(item)
	var pickup_position: Vector2 = item.node.position
	item.node.queue_free()
	regeneration_ticks = mini(8, regeneration_ticks + 4)
	Sfx.play("ui_confirm", -1.0, 1.25)
	regeneration_timer = 0.15
	message_label.text = "재생 하트 획득 · 2초마다 체력 회복!"
	spawn_hit_particles(pickup_position, Color("#4ade80"))


func update_regeneration(delta: float) -> void:
	if regeneration_ticks <= 0:
		return
	regeneration_timer -= delta
	if regeneration_timer <= 0.0:
		regeneration_timer = 2.0
		regeneration_ticks -= 1
		if health < 5:
			health += 1
			flash_world(Color("#4ade80"))
			message_label.text = "재생 효과로 체력이 회복되었습니다"


func trigger_level_up() -> void:
	if all_skills_maxed(): return
	Sfx.play("ui_confirm", 1.0, 0.82)
	experience -= next_experience
	level += 1
	next_experience = 6 if level == 2 else 4 + level * 2
	state = "levelup"
	level_overlay.visible = true
	level_title.text = "LEVEL %d!" % level
	update_skill_buttons()


func update_skill_buttons() -> void:
	var ultimate_unlocked := fourth_tier_unlocked()
	for key in ["fire", "lightning", "ice"]:
		var button: Button = skill_buttons[key]
		var current: int = skill_levels[key]
		button.disabled = current >= 4 or (current == 3 and not ultimate_unlocked)
		var name_text := "화염" if key == "fire" else "번개" if key == "lightning" else "얼음"
		if current == 0:
			button.text = "%s\n\nNEW\n기본 스킬 습득" % name_text
		elif current == 1:
			button.text = "%s  LV.1 → LV.2\n\n데미지 강화\n공격력 대폭 증가" % name_text
		elif current == 2:
			var effect := "3방향 화염 + 폭발" if key == "fire" else "4연쇄 번개" if key == "lightning" else "8방향 얼음 폭발"
			button.text = "%s  LV.2 → LV.3\n\n화려한 강화\n%s" % [name_text, effect]
		elif current == 3:
			if ultimate_unlocked:
				var effect := "5방향 지옥불 + 대폭발" if key == "fire" else "7연쇄 천둥 폭풍" if key == "lightning" else "12방향 절대영도 폭풍"
				button.text = "%s  LV.3 → LV.4\n\n궁극 진화 해금!\n%s" % [name_text, effect]
			else:
				button.text = "%s  LV.3 완료\n\nLV.4 궁극 진화 준비\n모든 스킬 LV.3 필요" % name_text
		else:
			button.text = "%s  LV.4 MAX\n\n궁극 진화 완료" % name_text


func _choose_skill(key: String) -> void:
	if skill_levels[key] >= 4: return
	if skill_levels[key] == 3 and not fourth_tier_unlocked(): return
	Sfx.play("ui_select", 0.0, 1.05)
	skill_levels[key] += 1
	level_overlay.visible = false
	state = "playing"
	message_label.text = "%s 스킬이 강화되었습니다!" % ("화염" if key == "fire" else "번개" if key == "lightning" else "얼음")
	update_hud()
	if experience >= next_experience and not all_skills_maxed():
		call_deferred("trigger_level_up")


func all_skills_maxed() -> bool:
	return skill_levels.fire >= 4 and skill_levels.lightning >= 4 and skill_levels.ice >= 4


func fourth_tier_unlocked() -> bool:
	return skill_levels.fire >= 3 and skill_levels.lightning >= 3 and skill_levels.ice >= 3


func nearest_enemy(origin: Vector2) -> Dictionary:
	var closest := {}
	var closest_distance := INF
	for enemy in enemies:
		if not is_instance_valid(enemy.node): continue
		var distance := origin.distance_squared_to(enemy.node.position)
		if distance < closest_distance:
			closest_distance = distance
			closest = enemy
	return closest


func nearest_enemies(origin: Vector2, count: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for enemy in enemies:
		if is_instance_valid(enemy.node): candidates.append(enemy)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return origin.distance_squared_to(a.node.position) < origin.distance_squared_to(b.node.position)
	)
	return candidates.slice(0, mini(count, candidates.size()))


func remove_projectile(projectile: Dictionary) -> void:
	projectiles.erase(projectile)
	if is_instance_valid(projectile.node): projectile.node.queue_free()


func spawn_hit_particles(position_value: Vector2, color: Color) -> void:
	for i in 5:
		var particle := make_circle(3.0, color)
		particle.position = position_value
		particle.z_index = 8
		world.add_child(particle)
		var target := position_value + Vector2.RIGHT.rotated(TAU * float(i) / 5.0 + randf_range(-0.3, 0.3)) * randf_range(18, 34)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, 0.22)
		tween.tween_property(particle, "modulate:a", 0.0, 0.22)
		tween.chain().tween_callback(particle.queue_free)


func spawn_gauntlet_kill_burst(position_value: Vector2, streak: int) -> void:
	var ring := make_ring(18.0, 12.0, Color("#fef08add"))
	ring.position = position_value
	ring.z_index = 9
	world.add_child(ring)
	var ring_tween := create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(3.1, 3.1), 0.24).set_trans(Tween.TRANS_BACK)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.24)
	ring_tween.chain().tween_callback(ring.queue_free)
	for i in 4:
		spawn_hit_particles(position_value + Vector2.RIGHT.rotated(TAU * float(i) / 4.0) * 8.0, [Color("#fb923c"), Color("#fef08a"), Color("#67e8f9")][i % 3])
	if streak % 5 == 0:
		var combo := make_label(position_value + Vector2(-65, -58), Vector2(130, 34), 23, Color("#fde047"))
		combo.text = "%d KILL!" % streak
		combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combo.z_index = 12
		world.add_child(combo)
		var combo_tween := create_tween()
		combo_tween.set_parallel(true)
		combo_tween.tween_property(combo, "position:y", combo.position.y - 35.0, 0.55)
		combo_tween.tween_property(combo, "modulate:a", 0.0, 0.55)
		combo_tween.chain().tween_callback(combo.queue_free)


func complete_boss_gauntlet() -> void:
	if state != "playing": return
	state = "clear"
	message_label.text = "부하 섬멸 완료 · %d KILL!" % kills
	flash_world(Color("#fde047"))
	await get_tree().create_timer(0.65, false).timeout
	visible = false
	boss_gauntlet_won.emit()


func stop_boss_gauntlet() -> void:
	state = "idle"
	visible = false
	boss_gauntlet_mode = false


func _retry_current_mode() -> void:
	if boss_gauntlet_mode:
		start_boss_gauntlet(gauntlet_skill_snapshot)
	else:
		start_game()


func flash_world(color: Color) -> void:
	var flash := ColorRect.new()
	flash.color = Color(color, 0.22)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.16).finished.connect(flash.queue_free)


func complete_game() -> void:
	state = "clear"
	clear_overlay.get_node("Summary").text = "보스 처치 · 레벨 %d · 몬스터 %d마리 처치" % [level, kills]
	clear_overlay.visible = true


func update_hud() -> void:
	var remaining := maxi(0, int(ceil(GAME_DURATION - elapsed)))
	timer_label.text = "남은 적 %d · 처치 %d / %d" % [GAUNTLET_KILL_TARGET-kills,kills,GAUNTLET_KILL_TARGET] if boss_gauntlet_mode else "TIME  %02d:%02d" % [remaining / 60, remaining % 60]
	health_label.text = "LIFE  " + "♥".repeat(maxi(0, health))
	if regeneration_ticks > 0:
		health_label.text += "  +%d" % regeneration_ticks
	level_label.text = "NO LEVEL UP" if boss_gauntlet_mode else "LEVEL  %d" % level
	skill_label.text = "🔥 %d/4   ⚡ %d/4   ❄ %d/4" % [skill_levels.fire, skill_levels.lightning, skill_levels.ice]
	xp_bar.visible = not boss_gauntlet_mode
	xp_bar.max_value = next_experience
	xp_bar.value = experience


func _finish_room() -> void:
	visible = false
	game_won.emit()


func _exit_to_corridor() -> void:
	visible = false
	state = "idle"


func make_label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func make_circle(radius: float, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 20:
		var angle := TAU * float(i) / 20.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	shape.polygon = points
	shape.color = color
	return shape


func make_ellipse(radius: Vector2, color: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		var angle := TAU * float(i) / 24.0
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	shape.polygon = points
	shape.color = color
	return shape


func make_ring(outer_radius: float, inner_radius: float, color: Color) -> Polygon2D:
	var ring := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		points.append(Vector2(cos(angle), sin(angle)) * outer_radius)
	for i in 28:
		var reverse_index := 27 - i
		var angle := TAU * float(reverse_index) / 28.0
		points.append(Vector2(cos(angle), sin(angle)) * inner_radius)
	ring.polygon = points
	ring.color = color
	return ring


func make_enemy_sprite(index: int, target_height: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = AI_TEXTURES[index % AI_TEXTURES.size()]
	sprite.scale = Vector2.ONE * (target_height / 128.0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return sprite
