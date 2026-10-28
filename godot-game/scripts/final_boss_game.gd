extends Control

signal game_won

const VIEW_SIZE := Vector2(960, 540)
const HERO_TEXTURE := preload("res://assets/characters/hero_walk_user_v3.png")
const CLUB_LEADER_IDLE_TEXTURE := preload("res://assets/characters/club_leader_boss_idle_v4.png")
const CLUB_LEADER_RUN_TEXTURE := preload("res://assets/characters/club_leader_boss_run_v4.png")
const CLUB_LEADER_3D_SCENE := preload("res://assets/3d/club_leader_boss/club_leader_boss_mixamo_v7.glb")
const ROGUELIKE_GAME_SCRIPT := preload("res://scripts/roguelike_game.gd")
const CARD_GAME_SCRIPT := preload("res://scripts/card_game.gd")
const GUN_EFFECTS := preload("res://scripts/gun_effects.gd")
const GARDEN_TEXTURE := preload("res://assets/platform/campus_garden_v2.png")
const LEDGE_TEXTURE := preload("res://assets/platform/garden_ledge.svg")
const SLIME_TEXTURE := preload("res://assets/platform/slime.svg")
const CONCRETE_DETAIL := preload("res://assets/platform/concrete_detail.tres")
const CARD_LOUNGE_ART := preload("res://assets/boss_art/card_lounge_v2.png")
const EXIT_ART := preload("res://assets/boss_art/lounge_exit_v2.png")
const CARD_BACK_ART := preload("res://assets/boss_art/card_back.svg")
const PRISON_ART := preload("res://assets/boss_art/prison_ending.png")
const PRISON_GATE := preload("res://assets/boss_art/prison_gate.svg")
const RHYTHM_FIRE_ART := preload("res://assets/vfx/animated/fire_burst_sheet_0.png")
const RHYTHM_ICE_ART := preload("res://assets/vfx/boss_ice_burst.png")
const RHYTHM_LIGHTNING_ART := preload("res://assets/vfx/boss_lightning_strike.png")
const BOSS_SCORE := preload("res://assets/audio/boss_approach_original.wav")
const ENDING_SCORE := preload("res://assets/audio/ending_the_entertainer.mp3")
const BOSS_BEAT := 60.0 / 96.0
const BOSS_RHYTHM_BEATS := [4.0,5.0,6.0,7.5,8.0,8.25,9.0,10.5,11.0,12.0,13.25,13.5,14.0,15.5,16.0,16.5,17.0,17.5,18.0,19.5,20.0,20.25,21.0,22.0,22.5,23.0,23.5,24.0,25.5,26.0,26.25,27.0,27.5,28.0,28.5,29.0,29.5,30.0,30.5,31.0,31.25,32.0]
const GROUND_Y := 430.0
const GRAVITY_2D := 1450.0
const CHASE_WORLD_WIDTH := 2800.0
const CHASE_MOVE_SPEED := 275.0
const CHASE_JUMP_SPEED := 620.0
const SHOOTER_GRAVITY := 18.0
const SHOOTER_SPEED := 6.4
const BOSS_CAPTURED_WALK_SPEED := 5.566
const MOUSE_SENSITIVITY := 0.0022
const FINAL_BOSS_MAX_HEALTH := 3600
const BOSS_TELEGRAPH_TIME := 1.05

var phase := "idle"
var next_phase := ""
var story_lines: Array[String] = []
var story_index := 0
var story_char_timer := 0.0
var story_tween: Tween
var story_portrait: TextureRect
var chase_particles: Array[Dictionary] = []
var chase_last_direction := 1.0
var rhythm_music: AudioStreamPlayer
var rhythm_feedback := ""
var rhythm_feedback_left := 0.0
var rhythm_impact := 0.0
var vfx_material_cache: Dictionary = {}
var combat_render_ready := false

var title_label: Label
var phase_label: Label
var status_label: Label
var help_label: Label
var story_panel: Panel
var speaker_label: Label
var dialogue_label: Label
var continue_label: Label
var card_buttons: Array[Button] = []
var boss_card_deck: Array[String] = []
var boss_card_pairs: Array[String] = []
var card_round_ticket := 0
var card_pair_panel: StyleBoxFlat
var roll_time_left := 0.0
var roll_cooldown := 0.0
var roll_direction := Vector3.ZERO
var roll_local := Vector2(0,-1)
var roll_kind := "forward"
const ROLL_DURATION := 0.48
const ROLL_COOLDOWN := 1.4
var roll_label: Label
var ending_time := 0.0
var credits_label: Label
var credits_mask: Control
var skill_overlay: ColorRect
var skill_buttons: Array[Button] = []
var finish_button: Button
var chapter_skip_button: Button
var rogue_room_game: Control
var boss_card_room: Control
var freeze_timer := 0.0
var blind_timer := 0.0
var blind_overlay: ColorRect
var burning_zones: Array[Dictionary] = []
var burn_damage_cooldown := 0.0
var rhythm_miss_flash := 0.0
var rhythm_jolt := 0.0
var ending_music: AudioStreamPlayer
var defeat_elapsed := 0.0
var defeat_pose_settled := false

# 플랫포머 추격전
var chase_time := 0.0
var chase_player_pos := Vector2(70, GROUND_Y - 46.0)
var chase_velocity_y := 0.0
var chase_on_floor := true
var chase_camera_x := 0.0
var chase_hp := 3
var chase_invincible := 0.0
var chase_reached_boss := false
var chase_surfaces: Array[Rect2] = []
var chase_hazards: Array[Rect2] = []
var chase_enemies: Array[Dictionary] = []

# 리듬 회피전
var rhythm_time := 0.0
var rhythm_spawn_timer := 0.0
var rhythm_spawned := 0
var rhythm_resolved := 0
var rhythm_hp := 5
var rhythm_combo := 0
var rhythm_attacks: Array[Dictionary] = []

# 로그라이크 부하전
var rogue_player := Vector2(480, 300)
var rogue_hp := 100.0
var rogue_xp := 0
var rogue_level := 1
var rogue_kills := 0
var rogue_spawn_timer := 0.0
var rogue_shot_timer := 0.0
var rogue_lightning_timer := 0.0
var rogue_enemies: Array[Dictionary] = []
var rogue_projectiles: Array[Dictionary] = []
var skill_levels := {"fire": 1, "lightning": 0, "ice": 0}
var inherited_skill_levels := {"fire": 1, "lightning": 0, "ice": 0}

# 3D 결투
var game_viewport: SubViewport
var viewport_texture: TextureRect
var world_3d: Node3D
var fps_player: CharacterBody3D
var fps_camera: Camera3D
var fps_gun: Node3D
var fps_muzzle: OmniLight3D
var fps_muzzle_flash: Node3D
var fps_player_collision: CollisionShape3D
var fps_player_capsule: CapsuleShape3D
var fps_is_crouching := false
var boss_body: StaticBody3D
var boss_visual: Node3D
var boss_spine: Node3D
var boss_head_pivot: Node3D
var boss_left_arm: Node3D
var boss_right_arm: Node3D
var boss_left_forearm: Node3D
var boss_right_forearm: Node3D
var boss_left_leg: Node3D
var boss_right_leg: Node3D
var boss_left_knee: Node3D
var boss_right_knee: Node3D
var boss_skeleton: Skeleton3D
var boss_animation_player: AnimationPlayer
var boss_motion_clips: Dictionary = {}
var boss_turning := false
var boss_dash_tween: Tween
var boss_turn_tween: Tween
var boss_recover_tween: Tween
var boss_glow_tween: Tween
var boss_head_bone := -1
var boss_left_arm_bone := -1
var boss_right_arm_bone := -1
var boss_bone_controls: Dictionary = {}
var boss_rest_poses: Dictionary = {}
var boss_stride := 0.0
var boss_walk_blend := 0.0
var boss_cast_pose := 0.0
var boss_aura: OmniLight3D
var boss_move_time := 0.0
var boss_casting := false
var camera_shake := 0.0
var fps_health := 100
var boss_health := FINAL_BOSS_MAX_HEALTH
var ammo := 30
var reserve_ammo := 120
var reload_timer := 0.0
var shot_timer := 0.0
var gun_sound_timer := 0.0
var boss_attack_timer := 1.5
var slow_timer := 0.0
var yaw := 0.0
var pitch := 0.0
var arena_attacks: Array[Dictionary] = []
var boss_bar: ProgressBar
var reload_bar: ProgressBar
var reload_hint: Label
var health_label: Label
var ammo_label: Label
var damage_flash: ColorRect
var damage_indicator: Label


func _ready() -> void:
	position = Vector2.ZERO
	size = VIEW_SIZE
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_interface()
	visibility_changed.connect(func() -> void:
		if not visible:
			rhythm_music.stop()
			ending_music.stop()
			boss_card_room.stop_game()
			if is_instance_valid(boss_animation_player): boss_animation_player.stop(true)
	)


func build_interface() -> void:
	title_label = make_label(Vector2(22, 14), Vector2(916, 42), 27, Color("#f8fafc"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)

	phase_label = make_label(Vector2(20, 66), Vector2(300, 28), 17, Color("#fbbf24"))
	add_child(phase_label)
	status_label = make_label(Vector2(320, 66), Vector2(620, 30), 17, Color("#e2e8f0"))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(status_label)
	help_label = make_label(Vector2(20, 500), Vector2(920, 28), 16, Color("#cbd5e1"))
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(help_label)

	story_panel = Panel.new()
	story_panel.position = Vector2(95, 330)
	story_panel.size = Vector2(770, 155)
	story_panel.z_index = 50
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color("#171d26f5")
	bubble.border_color = Color("#8c8169")
	bubble.set_border_width_all(2)
	bubble.set_corner_radius_all(14)
	bubble.shadow_color = Color("#00000080")
	bubble.shadow_size = 8
	story_panel.add_theme_stylebox_override("panel", bubble)
	add_child(story_panel)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(45, 1), Vector2(65, -14), Vector2(80, 1)])
	tail.color = bubble.bg_color
	story_panel.add_child(tail)
	story_portrait = TextureRect.new()
	story_portrait.position = Vector2(20, 28)
	story_portrait.size = Vector2(76, 96)
	story_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	story_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	story_panel.add_child(story_portrait)
	speaker_label = make_label(Vector2(112, 14), Vector2(630, 30), 19, Color("#fbbf24"))
	story_panel.add_child(speaker_label)
	dialogue_label = make_label(Vector2(112, 47), Vector2(630, 62), 20, Color("#f8fafc"))
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_panel.add_child(dialogue_label)
	continue_label = make_label(Vector2(112, 116), Vector2(630, 24), 14, Color("#94a3b8"))
	continue_label.text = "[ SPACE / 클릭 ] 다음"
	continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	story_panel.add_child(continue_label)

	for i in 7:
		var button := Button.new()
		button.position = Vector2(150 + i * 96, 225)
		button.size = Vector2(84, 118)
		button.text = "◆\n?\n◆"
		button.icon = CARD_BACK_ART
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 84)
		button.text = ""
		button.add_theme_font_size_override("font_size", 26)
		style_boss_card_back(button)
		button.visible = false
		button.pressed.connect(select_boss_card.bind(i))
		add_child(button)
		card_buttons.append(button)

	skill_overlay = ColorRect.new()
	skill_overlay.position = Vector2.ZERO
	skill_overlay.size = VIEW_SIZE
	skill_overlay.color = Color("#020617dc")
	skill_overlay.z_index = 80
	skill_overlay.visible = false
	add_child(skill_overlay)
	var skill_title := make_label(Vector2(180, 120), Vector2(600, 55), 34, Color("#f8fafc"))
	skill_title.text = "LEVEL UP · 강화 선택"
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_overlay.add_child(skill_title)
	var names := ["화염 강화", "번개 강화", "얼음 강화"]
	var colors := [Color("#fb7185"), Color("#facc15"), Color("#67e8f9")]
	for i in 3:
		var button := Button.new()
		button.position = Vector2(135 + i * 235, 220)
		button.size = Vector2(220, 100)
		button.text = names[i]
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", colors[i])
		button.pressed.connect(select_skill.bind(i))
		skill_overlay.add_child(button)
		skill_buttons.append(button)

	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(230, 102)
	boss_bar.size = Vector2(500, 22)
	boss_bar.max_value = FINAL_BOSS_MAX_HEALTH
	boss_bar.show_percentage = false
	boss_bar.visible = false
	boss_bar.z_index = 30
	add_child(boss_bar)
	health_label = make_label(Vector2(20, 102), Vector2(190, 28), 18, Color("#86efac"))
	health_label.visible = false
	add_child(health_label)
	ammo_label = make_label(Vector2(745, 102), Vector2(195, 28), 18, Color("#fde68a"))
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.visible = false
	add_child(ammo_label)
	reload_bar = ProgressBar.new()
	reload_bar.position = Vector2(745, 132)
	reload_bar.size = Vector2(195, 12)
	reload_bar.max_value = 1.35
	reload_bar.show_percentage = false
	reload_bar.visible = false
	reload_bar.z_index = 31
	add_child(reload_bar)
	reload_hint = make_label(Vector2(320, 345), Vector2(320, 35), 19, Color("#eee1ba"))
	reload_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_hint.z_index = 40
	reload_hint.visible = false
	add_child(reload_hint)

	damage_flash = ColorRect.new()
	damage_flash.position = Vector2.ZERO
	damage_flash.size = VIEW_SIZE
	damage_flash.color = Color(0.95, 0.08, 0.06, 0.0)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.z_index = 420
	add_child(damage_flash)
	damage_indicator = make_label(Vector2(330, 205), Vector2(300, 80), 42, Color(1.0, 0.85, 0.82, 0.0))
	damage_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	damage_indicator.pivot_offset = damage_indicator.size * 0.5
	damage_indicator.z_index = 421
	damage_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_indicator)
	blind_overlay = ColorRect.new()
	blind_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blind_overlay.color = Color("#f7faff")
	blind_overlay.modulate.a = 0.0
	blind_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blind_overlay.z_index = 415
	add_child(blind_overlay)

	finish_button = Button.new()
	finish_button.position = Vector2(350, 410)
	finish_button.size = Vector2(260, 58)
	finish_button.text = "보스방 클리어"
	finish_button.add_theme_font_size_override("font_size", 21)
	finish_button.visible = false
	finish_button.z_index = 100
	finish_button.pressed.connect(finish_room)
	add_child(finish_button)
	roll_label = make_label(Vector2(22, 460), Vector2(300, 30), 17, Color("#decdaa"))
	roll_label.z_index = 40
	roll_label.visible = false
	add_child(roll_label)
	credits_mask = Control.new()
	credits_mask.position = Vector2(540, 102)
	credits_mask.size = Vector2(395, 360)
	credits_mask.clip_contents = true
	credits_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_mask.z_index = 40
	credits_mask.visible = false
	add_child(credits_mask)
	credits_label = make_label(Vector2(15, 360), Vector2(365, 830), 20, Color("#e7e1d1"))
	credits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credits_label.text = "THIS IS ME\nGENRE MIX GAME\n\n기획 · 개발\n노세준\n\n주인공\n노세준\n\n최종 보스\n동아리장 특별 출연\n\n제작\nGodot · Blender / MPFB\n\n효과음\nKenney · CC0\n\nAI 로고\nLobe Icons · MIT\n\n음악 · 배경 제작 보조\nCodex · OpenAI 이미지 도구\n\n함께해 준 PLAF 동아리원들과\n플레이해 준 여러분께\n\n감사합니다\n\nTHANK YOU FOR PLAYING"
	credits_mask.add_child(credits_label)
	credits_label.text = credits_label.text.replace("동아리장 특별 출연", "이상민")
	credits_label.text = credits_label.text.replace("음악 · 배경 제작 보조", "의상 원본\nSnow Rig © Blender Foundation\nstudio.blender.org · CC BY\n수정·리타게팅 적용\n\n음악 · 배경 제작 보조")
	credits_label.text = credits_label.text.replace("음악 · 배경 제작 보조", "걷기 모션\nAdobe Mixamo · Walking\n\n음악 · 배경 제작 보조")
	credits_label.text = credits_label.text.replace("음악 · 배경 제작 보조", "엔딩 음악\nThe Entertainer · Scott Joplin\n연주 Kevin MacLeod\nincompetech.com · CC BY 4.0\n\n음악 · 배경 제작 보조")

	rogue_room_game = ROGUELIKE_GAME_SCRIPT.new()
	rogue_room_game.z_index = 70
	rogue_room_game.boss_gauntlet_won.connect(_on_boss_gauntlet_won)
	add_child(rogue_room_game)
	boss_card_room = CARD_GAME_SCRIPT.new()
	boss_card_room.boss_encounter = true
	boss_card_room.z_index = 70
	boss_card_room.game_won.connect(_on_boss_card_won)
	add_child(boss_card_room)

	chapter_skip_button = Button.new()
	chapter_skip_button.position = Vector2(754, 14)
	chapter_skip_button.size = Vector2(185, 45)
	chapter_skip_button.text = "CHAPTER SKIP  [F3]"
	chapter_skip_button.add_theme_font_size_override("font_size", 15)
	chapter_skip_button.z_index = 500
	chapter_skip_button.pressed.connect(skip_current_chapter)
	add_child(chapter_skip_button)
	rhythm_music = AudioStreamPlayer.new()
	rhythm_music.stream = BOSS_SCORE
	rhythm_music.bus = "BGM"
	add_child(rhythm_music)
	ending_music = AudioStreamPlayer.new()
	ending_music.stream = ENDING_SCORE
	ending_music.bus = "BGM"
	ending_music.volume_db = -12
	add_child(ending_music)


func start_game() -> void:
	visible = true
	reset_all()
	title_label.text = "FINAL BOSS · 도박장의 도망자"
	show_story([
		"나|오늘도 늘 가던 도박장에 들렀다. 마침 카드 테이블 한 자리가 비어 있었다.",
		"상대|혼자 왔어? 그럼 나랑 조커 뽑기 한 판 하지.",
		"나|좋아. 가볍게 한 판만 하자.",
		"딜러|마지막까지 조커를 들고 있는 사람이 지는 겁니다. 시작하시죠."
	], "card")
	if "--boss-auto-test" in OS.get_cmdline_args() or "--boss-auto-test" in OS.get_cmdline_user_args():
		call_deferred("debug_test_all_phases")


func set_inherited_skills(room_four_skills: Dictionary) -> void:
	for key in ["fire", "lightning", "ice"]:
		inherited_skill_levels[key] = clampi(int(room_four_skills.get(key, 0)), 0, 4)


func debug_test_all_phases() -> void:
	start_card_phase()
	start_chase_phase()
	chase_player_pos = Vector2(2590, GROUND_Y - 46.0)
	update_chase(0.016)
	if phase != "story" or next_phase != "rhythm":
		push_error("Final boss platform goal transition test failed")
	start_rhythm_phase()
	update_rhythm(0.016)
	start_rogue_phase()
	if not rogue_room_game.visible or rogue_room_game.skill_levels != inherited_skill_levels:
		push_error("Final boss room-4 gauntlet inheritance test failed")
	rogue_room_game.stop_boss_gauntlet()
	start_shooter_phase()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var test_circle := make_spell_disc(Vector3(0, 0.08, -5), Color("#67e8f9aa"), 3.0)
	var test_lane := make_spell_lane(0.0, Color("#fde04799"))
	var test_charge_lane := make_charge_lane(Vector3(0, 0.08, -13), Vector3(3, 0.08, 2), Color("#ff3b30cc"), 2.5)
	spawn_spell_impact("fire", Vector3(-3, 0.08, -4))
	spawn_spell_impact("ice", Vector3(0, 0.08, -5))
	spawn_spell_impact("lightning", Vector3(3, 0.08, -3))
	spawn_spell_impact("charge", Vector3(3, 0.08, 2))
	test_circle.queue_free()
	test_lane.queue_free()
	test_charge_lane.queue_free()
	fps_camera.look_at(boss_body.global_position + Vector3(0, 2.5, 0), Vector3.UP)
	var before := boss_health
	shoot_boss()
	if boss_health >= before:
		push_error("Final boss aimed-shot test failed")
	var health_before_hit := fps_health
	damage_fps_player(5, Color("#ff6b36"))
	if fps_health != health_before_hit - 5:
		push_error("Final boss damage feedback test failed")


func reset_all() -> void:
	rhythm_music.stop()
	ending_music.stop()
	boss_card_room.stop_game()
	freeze_timer = 0
	blind_timer = 0
	blind_overlay.modulate.a = 0
	clear_burning_zones()
	reload_hint.visible = false
	roll_label.visible = false
	credits_mask.visible = false
	roll_time_left = 0.0
	roll_cooldown = 0.0
	card_round_ticket += 1
	phase = "story"
	next_phase = ""
	story_lines.clear()
	story_index = 0
	for button in card_buttons: button.visible = false
	skill_overlay.visible = false
	finish_button.visible = false
	boss_bar.visible = false
	health_label.visible = false
	ammo_label.visible = false
	reload_bar.visible = false
	if is_instance_valid(damage_flash): damage_flash.color.a = 0.0
	if is_instance_valid(damage_indicator): damage_indicator.modulate.a = 0.0
	if is_instance_valid(viewport_texture): viewport_texture.queue_free()
	if is_instance_valid(game_viewport): game_viewport.queue_free()
	if is_instance_valid(rogue_room_game): rogue_room_game.stop_boss_gauntlet()
	game_viewport = null
	viewport_texture = null
	chase_surfaces.clear()
	chase_hazards.clear()
	chase_enemies.clear()
	rhythm_attacks.clear()
	rogue_enemies.clear()
	rogue_projectiles.clear()
	arena_attacks.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	queue_redraw()


func show_story(lines: Array[String], destination: String) -> void:
	rhythm_music.stop()
	boss_card_room.stop_game()
	hide_combat_ui()
	reload_hint.visible = false
	roll_label.visible = false
	for button in card_buttons: button.visible = false
	phase = "story"
	next_phase = destination
	story_lines = lines
	story_index = 0
	story_panel.visible = true
	phase_label.text = "STORY"
	status_label.text = ""
	help_label.text = "SPACE 또는 화면 클릭으로 대화를 진행하세요"
	show_current_story_line()
	queue_redraw()


func show_current_story_line() -> void:
	if story_index >= story_lines.size():
		story_panel.visible = false
		start_named_phase(next_phase)
		return
	var parts := story_lines[story_index].split("|", true, 1)
	var speaker := parts[0]
	speaker_label.text = "이상민" if speaker in ["보스", "상대", "동아리장"] else speaker
	dialogue_label.text = parts[1] if parts.size() > 1 else ""
	dialogue_label.visible_characters = 0
	story_char_timer = 0.0
	continue_label.text = "SPACE / 클릭 · 전체 문장 보기"
	var portrait := AtlasTexture.new()
	if speaker == "나" or speaker in ["보스", "상대", "동아리장", "이상민"]:
		portrait.atlas = HERO_TEXTURE if speaker == "나" else CLUB_LEADER_IDLE_TEXTURE
		portrait.region = Rect2(0, 0, portrait.atlas.get_width() / 4.0, portrait.atlas.get_height())
		story_portrait.texture = portrait
		story_portrait.visible = true
	else:
		# Dealer/narrator lines must not borrow the boss's face.
		story_portrait.texture = null
		story_portrait.visible = false
	if story_tween != null and story_tween.is_valid(): story_tween.kill()
	story_panel.position.y = 342
	story_panel.modulate.a = 0.0
	story_tween = create_tween().set_parallel(true)
	story_tween.tween_property(story_panel, "position:y", 330.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	story_tween.tween_property(story_panel, "modulate:a", 1.0, 0.18)


func update_story_text(delta: float) -> void:
	if dialogue_label.visible_characters < 0: return
	story_char_timer -= delta
	while story_char_timer <= 0.0 and dialogue_label.visible_characters < dialogue_label.text.length():
		var index := dialogue_label.visible_characters
		dialogue_label.visible_characters += 1
		story_char_timer += 0.065
		if dialogue_label.text[index] in [".", "?", "!", ",", "…"]: story_char_timer += 0.22
	if dialogue_label.visible_characters >= dialogue_label.text.length():
		continue_label.text = "SPACE / 클릭 · 다음 대화  ▾"


func advance_story() -> void:
	if dialogue_label.visible_characters >= 0 and dialogue_label.visible_characters < dialogue_label.text.length():
		dialogue_label.visible_characters = -1
		continue_label.text = "SPACE / 클릭 · 다음 대화  ▾"
		return
	story_index += 1
	show_current_story_line()


func start_named_phase(destination: String) -> void:
	match destination:
		"card": start_card_phase()
		"chase": start_chase_phase()
		"rhythm": start_rhythm_phase()
		"rhythm_play": begin_boss_rhythm()
		"rogue": start_rogue_phase()
		"shooter": start_shooter_phase()
		"ending": start_ending()


func start_card_phase() -> void:
	hide_combat_ui()
	story_panel.visible = false
	phase = "card"
	phase_label.text = "PHASE 1 / 5 · JOKER DRAW"
	for button in card_buttons: button.visible = false
	boss_card_room.start_game()
	queue_redraw()


func _on_boss_card_won() -> void:
	if phase != "card": return
	show_story([
		"이상민|말도 안 돼… 내 손에 조커만 남았잖아!",
		"나|내가 이겼네. 약속한 판돈 줘.",
		"이상민|잠깐만! 밖에서 가져올 테니까 기다려!",
		"나|돈 들고 도망가네? 거기 서!"
	], "chase")


func refresh_boss_cards() -> void:
	var count := boss_card_deck.size()
	var start_x := (960.0 - float(count) * 84.0 - float(count - 1) * 12.0) * 0.5
	for i in card_buttons.size():
		var button := card_buttons[i]
		button.visible = i < count
		button.position = Vector2(start_x + i * 96, 225)
		button.scale = Vector2.ONE
		button.disabled = false
		button.text = ""
		style_boss_card_back(button)
	status_label.text = "맞춘 짝 %d / 6 · 상대 카드 %d장" % [boss_card_pairs.size(), count]
	help_label.text = "같은 숫자는 짝으로 내려놓습니다 · 조커가 남는 쪽이 패배!"


func style_boss_card_back(button: Button) -> void:
	button.icon = null
	var back := StyleBoxTexture.new()
	back.texture = CARD_BACK_ART
	button.add_theme_stylebox_override("normal", back)
	button.add_theme_stylebox_override("disabled", back)
	var hover := back.duplicate() as StyleBoxTexture
	hover.modulate_color = Color("#fff3d8")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func select_boss_card(index: int) -> void:
	if phase != "card" or index >= boss_card_deck.size(): return
	phase = "card_result"
	var ticket := card_round_ticket
	var rank := boss_card_deck[index]
	for button in card_buttons: button.disabled = true
	var selected := card_buttons[index]
	selected.text = "JOKER" if rank == "JOKER" else rank + " ♠"
	var face := StyleBoxFlat.new()
	face.bg_color = Color("#f1ecd9")
	face.set_corner_radius_all(7)
	selected.add_theme_stylebox_override("disabled", face)
	selected.add_theme_color_override("font_disabled_color", Color("#26322f"))
	var lift := selected.create_tween().set_parallel(true)
	lift.tween_property(selected, "position:y", 207.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	lift.tween_property(selected, "scale", Vector2(1.04, 1.04), 0.2)
	Sfx.play("card_draw", -5)
	status_label.text = "조커! 상대가 내 손에서 다시 뽑아 갔다…" if rank == "JOKER" else rank + " 짝 완성!"
	await get_tree().create_timer(0.8, false).timeout
	if ticket != card_round_ticket or phase != "card_result": return
	if rank != "JOKER":
		boss_card_pairs.append(rank)
		boss_card_deck.remove_at(index)
		Sfx.play("card_pair", -4)
	else:
		boss_card_deck.shuffle()
	if boss_card_deck.size() > 1:
		phase = "card"
		refresh_boss_cards()
		queue_redraw()
		return
	for button in card_buttons: button.visible = false
	show_story([
		"상대|말도 안 돼... 내가 조커를 들고 있다니!",
		"나|내가 이겼네. 약속한 판돈 줘.",
		"상대|그 돈은 못 줘! 잡을 수 있으면 잡아 봐!",
		"나|돈 떼먹고 도망가네? 거기 서!"
	], "chase")


func start_chase_phase() -> void:
	rhythm_music.stop()
	boss_card_room.stop_game()
	story_panel.visible = false
	phase = "chase"
	chase_time = 0.0
	chase_player_pos = Vector2(70, GROUND_Y - 46.0)
	chase_velocity_y = 0.0
	chase_on_floor = true
	chase_camera_x = 0.0
	chase_hp = 3
	chase_invincible = 0.0
	chase_reached_boss = false
	chase_particles.clear()
	chase_surfaces = [
		Rect2(0, 430, 610, 110), Rect2(735, 430, 545, 110),
		Rect2(1410, 430, 590, 110), Rect2(2120, 430, 680, 110),
		Rect2(250, 350, 145, 20), Rect2(485, 285, 145, 20),
		Rect2(830, 335, 165, 20), Rect2(1070, 270, 135, 20),
		Rect2(1320, 360, 145, 20), Rect2(1570, 305, 150, 20),
		Rect2(1810, 250, 155, 20), Rect2(2040, 345, 150, 20),
		Rect2(2310, 300, 160, 20)
	]
	for i in chase_surfaces.size():
		if chase_surfaces[i].size.y == 20.0:
			chase_surfaces[i] = Rect2(chase_surfaces[i].position, Vector2(chase_surfaces[i].size.x, 32))
	chase_hazards = [Rect2(890, 405, 80, 25), Rect2(1510, 405, 95, 25), Rect2(2240, 405, 90, 25)]
	chase_enemies = [
		{"pos": Vector2(1020, 400), "left": 990.0, "right": 1190.0, "dir": 1.0},
		{"pos": Vector2(1690, 400), "left": 1620.0, "right": 1930.0, "dir": -1.0},
		{"pos": Vector2(2380, 270), "left": 2320.0, "right": 2445.0, "dir": 1.0}
	]
	phase_label.text = "PHASE 2 / 5 · PLATFORM CHASE"
	help_label.text = "A/D 또는 ←/→ 이동 · SPACE 점프 · 맵 끝의 도망자를 따라잡으세요"
	queue_redraw()


func start_rhythm_phase() -> void:
	show_story(["안내|불은 Q, 얼음은 W, 번개는 E! 공격이 원에 닿는 순간 해당 키를 누르세요.","안내|색뿐 아니라 공격 위의 Q/W/E 글자를 확인하세요. SPACE나 마우스로는 피할 수 없습니다. 실수 5번이면 재도전합니다. 준비되면 다음으로 진행하세요."],"rhythm_play")
	phase_label.text = "RHYTHM · 조작 안내"


func begin_boss_rhythm() -> void:
	hide_combat_ui()
	story_panel.visible = false
	phase = "rhythm"
	rhythm_time = 0.0
	rhythm_spawn_timer = 0.6
	rhythm_spawned = 0
	rhythm_resolved = 0
	rhythm_hp = 5
	rhythm_combo = 0
	rhythm_attacks.clear()
	rhythm_impact = 0.0
	rhythm_miss_flash = 0.0
	rhythm_jolt = 0.0
	rhythm_feedback = "불 Q · 얼음 W · 번개 E"
	rhythm_feedback_left = 2.0
	rhythm_music.play()
	phase_label.text = "PHASE 3 / 5 · RHYTHM DODGE"
	help_label.text = "불 Q · 얼음 W · 번개 E · 공격이 원에 닿을 때 해당 키!"
	queue_redraw()


func start_rogue_phase() -> void:
	rhythm_music.stop()
	phase = "rogue"
	skill_levels = inherited_skill_levels.duplicate(true)
	phase_label.text = "PHASE 4 / 5 · MINION SURVIVAL"
	help_label.text = "4번 방의 모든 기능과 강화 상태로 부하를 섬멸하세요"
	status_label.text = "FINAL RUSH 시작"
	story_panel.visible = false
	rogue_room_game.start_boss_gauntlet(skill_levels)
	queue_redraw()


func _on_boss_gauntlet_won() -> void:
	if phase != "rogue": return
	show_story([
		"보스|말도 안 돼... 그 많은 부하들을 전부 쓰러뜨렸다고?",
		"나|4번 방에서 완성한 힘을 그대로 가져왔으니까.",
		"보스|그렇다면 마지막은 내가 직접 상대해 주지!",
		"나|5번 방에서 익힌 방식으로 끝내 주겠어."
	], "shooter")


func _physics_process(delta: float) -> void:
	if not visible or skill_overlay.visible: return
	update_chase_particles(delta)
	match phase:
		"story": update_story_text(delta)
		"chase": update_chase(delta)
		"rhythm": update_rhythm(delta)
		"rogue": pass # 실제 4번 방 인스턴스가 자체적으로 갱신한다.
		"shooter": update_shooter(delta)
		"defeated": update_boss_defeat(delta)
		"ending": update_ending(delta)
	queue_redraw()


func update_chase(delta: float) -> void:
	chase_time += delta
	chase_invincible = maxf(0.0, chase_invincible - delta)
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_key_pressed(KEY_A): direction = -1.0
	elif Input.is_key_pressed(KEY_D): direction = 1.0
	if direction != 0.0: chase_last_direction = direction
	var old_rect := Rect2(chase_player_pos, Vector2(42, 46))
	chase_player_pos.x = clampf(chase_player_pos.x + direction * CHASE_MOVE_SPEED * delta, 0.0, CHASE_WORLD_WIDTH - 42.0)
	for surface in chase_surfaces:
		if old_rect.end.y > surface.position.y + 2.0 and old_rect.position.y < surface.end.y - 2.0:
			if direction > 0.0 and old_rect.end.x <= surface.position.x and chase_player_pos.x + 42 > surface.position.x:
				chase_player_pos.x = surface.position.x - 42
			elif direction < 0.0 and old_rect.position.x >= surface.end.x and chase_player_pos.x < surface.end.x:
				chase_player_pos.x = surface.end.x
	var old_bottom := chase_player_pos.y + 46.0
	chase_velocity_y += GRAVITY_2D * delta
	chase_player_pos.y += chase_velocity_y * delta
	var new_bottom := chase_player_pos.y + 46.0
	var was_on_floor := chase_on_floor
	chase_on_floor = false
	var landing_y := INF
	if chase_velocity_y >= 0.0:
		for surface in chase_surfaces:
			var overlaps_x := chase_player_pos.x + 38.0 > surface.position.x and chase_player_pos.x + 4.0 < surface.end.x
			if overlaps_x and old_bottom <= surface.position.y + 3.0 and new_bottom >= surface.position.y:
				landing_y = minf(landing_y, surface.position.y)
	if landing_y < INF:
		chase_player_pos.y = landing_y - 46.0
		chase_velocity_y = 0.0
		chase_on_floor = true
		if not was_on_floor: spawn_chase_particles(chase_player_pos + Vector2(21, 46), Color("#e0d8c2"), 10)
	elif chase_velocity_y < 0.0:
		for surface in chase_surfaces:
			if chase_player_pos.x + 38 > surface.position.x and chase_player_pos.x + 4 < surface.end.x and old_rect.position.y >= surface.end.y - 1 and chase_player_pos.y <= surface.end.y:
				chase_player_pos.y = surface.end.y
				chase_velocity_y = 0.0
	if chase_on_floor and direction != 0.0 and fmod(chase_time, 0.14) < delta:
		spawn_chase_particles(chase_player_pos + Vector2(21, 46), Color("#c9bca4"), 2)
	var player_rect := Rect2(chase_player_pos, Vector2(42, 46))
	for hazard in chase_hazards:
		if player_rect.intersects(hazard):
			reset_chase_player("가시에 닿았습니다")
			return
	for enemy in chase_enemies:
		enemy.pos.x += float(enemy.dir) * 72.0 * delta
		if enemy.pos.x <= float(enemy.left) or enemy.pos.x >= float(enemy.right):
			enemy.dir = -float(enemy.dir)
		var enemy_rect := Rect2(enemy.pos - Vector2(18, 30), Vector2(36, 30))
		if player_rect.intersects(enemy_rect) and chase_invincible <= 0.0:
			if chase_velocity_y > 100.0 and player_rect.end.y <= enemy_rect.position.y + 18.0:
				enemy.dead = true
				spawn_chase_particles(enemy.pos - Vector2(0, 12), Color("#8db9a3"), 16)
				chase_velocity_y = -360.0
			else:
				reset_chase_player("순찰 몬스터와 부딪혔습니다")
				return
	chase_enemies = chase_enemies.filter(func(enemy: Dictionary) -> bool: return not enemy.get("dead", false))
	if chase_player_pos.y > 570.0:
		reset_chase_player("낭떠러지로 떨어졌습니다")
		return
	chase_camera_x = clampf(chase_player_pos.x - 250.0, 0.0, CHASE_WORLD_WIDTH - VIEW_SIZE.x)
	var progress := int(clampf(chase_player_pos.x / 2600.0, 0.0, 1.0) * 100.0)
	status_label.text = "도망자까지 %d%%   ·   HP %s" % [progress, "♥".repeat(chase_hp)]
	if chase_player_pos.x >= 2580.0 and not chase_reached_boss:
		chase_reached_boss = true
		show_story([
			"나|드디어 따라잡았다. 이제 판돈 돌려줘.",
			"상대|여기까지 쫓아올 줄은 몰랐는데... 더 가까이 오지 마!",
			"나|돈을 들고 도망가면 끝일 줄 알았어?",
			"상대|그럼 이 공격도 피해 봐!",
			"나|공격에 일정한 박자가 있어. 타이밍을 맞추면 피할 수 있겠어."
		], "rhythm")


func reset_chase_player(reason: String) -> void:
	chase_hp = maxi(1, chase_hp - 1)
	chase_player_pos = Vector2(70, GROUND_Y - 46.0)
	chase_velocity_y = 0.0
	chase_camera_x = 0.0
	chase_invincible = 1.0
	status_label.text = reason + " · 출발점으로 돌아갑니다"


func spawn_chase_particles(at: Vector2, tint: Color, count: int) -> void:
	for i in count:
		chase_particles.append({"pos": at, "velocity": Vector2(randf_range(-65, 65), randf_range(-100, -25)), "life": 0.45, "color": tint})


func update_chase_particles(delta: float) -> void:
	for particle in chase_particles:
		particle.life = float(particle.life) - delta
		particle.pos += particle.velocity * delta
		particle.velocity.y += 200.0 * delta
	chase_particles = chase_particles.filter(func(p: Dictionary) -> bool: return float(p.life) > 0.0)


func update_rhythm(delta: float) -> void:
	# One audio clock drives both visible travel and judgement, including audio latency.
	if rhythm_music.playing:
		rhythm_time = maxf(0.0, rhythm_music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	rhythm_feedback_left = maxf(0.0, rhythm_feedback_left - delta)
	rhythm_impact = move_toward(rhythm_impact, 0.0, delta * 5.0)
	rhythm_miss_flash = move_toward(rhythm_miss_flash, 0.0, delta * 2.5)
	rhythm_jolt = move_toward(rhythm_jolt, 0.0, delta * 5.0)
	while rhythm_spawned < BOSS_RHYTHM_BEATS.size() and rhythm_time >= float(BOSS_RHYTHM_BEATS[rhythm_spawned]) * BOSS_BEAT - 1.5:
		var impact_time := float(BOSS_RHYTHM_BEATS[rhythm_spawned]) * BOSS_BEAT
		var origin_y: float = [160.0,300.0,430.0].pick_random()
		rhythm_attacks.append({"x": 850.0, "y": origin_y, "origin_y": origin_y, "time": impact_time, "type": randi_range(0,2), "resolved": false})
		rhythm_spawned += 1
	for attack in rhythm_attacks:
		attack.x = 165.0 + (float(attack.time) - rhythm_time) * (685.0 / 1.5)
		var progress := 1.0 - (float(attack.time) - rhythm_time) / 1.5
		attack.y = lerpf(float(attack.origin_y), 300.0, progress)
		if not attack.resolved and rhythm_time - float(attack.time) > 0.14:
			attack.resolved = true
			rhythm_resolved += 1
			rhythm_hp -= 1
			rhythm_combo = 0
			rhythm_feedback = "MISS · 다음 북소리에 집중!"
			rhythm_feedback_left = 0.65
			rhythm_miss_flash = 1.0
			rhythm_jolt = 1.0
			Sfx.play("hit", -6, 0.55, 0.02)
			spawn_chase_particles(Vector2(165,300), Color("#ff5252"), 24)
	rhythm_attacks = rhythm_attacks.filter(func(item: Dictionary) -> bool: return float(item.x) > 75.0)
	if rhythm_hp <= 0:
		show_story(["안내|보호막이 깨졌습니다. 불 Q · 얼음 W · 번개 E를 확인하고 다시 도전하세요."],"rhythm_play")
		return
	if rhythm_resolved >= BOSS_RHYTHM_BEATS.size() and rhythm_time > float(BOSS_RHYTHM_BEATS[-1]) * BOSS_BEAT + 1.0:
		show_story([
			"보스|내 공격을 전부 피했다고? 얘들아, 전부 나와!",
			"나|부하가 아무리 많아도 내 스킬이면 충분해."
		], "rogue")
	else:
		status_label.text = rhythm_feedback if rhythm_feedback_left > 0.0 else "HP %d / 5   ·   COMBO %d   ·   %d / %d" % [rhythm_hp, rhythm_combo, rhythm_resolved, BOSS_RHYTHM_BEATS.size()]


func rhythm_dodge(input_type: int = -1) -> void:
	if phase != "rhythm": return
	if rhythm_music.playing:
		rhythm_time = maxf(0.0, rhythm_music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency())
	var best: Dictionary = {}
	var best_distance := 9999.0
	for attack in rhythm_attacks:
		if attack.resolved: continue
		# Judge the earliest unresolved note so a double tap cannot skip its first hit.
		best = attack
		best_distance = absf(float(attack.time) - rhythm_time)
		break
	if not best.is_empty() and best_distance <= 0.14:
		if input_type != int(best.type):
			best.resolved = true
			rhythm_resolved += 1
			rhythm_hp -= 1
			rhythm_combo = 0
			rhythm_miss_flash = 1.0
			rhythm_feedback = "잘못된 키! · 불 Q / 얼음 W / 번개 E"
			rhythm_feedback_left = 0.65
			Sfx.play("hit",-6,0.55)
			return
		best.resolved = true
		rhythm_resolved += 1
		rhythm_combo += 1
		rhythm_feedback = ("PERFECT!" if best_distance <= 0.075 else "GOOD!") + " · COMBO %d" % rhythm_combo
		rhythm_feedback_left = 0.5
		Sfx.play("ui_confirm", -9, 0.9, 0.02)
		Sfx.play("hit", -13, 1.2, 0.02)
		rhythm_impact = 1.0
		rhythm_jolt = 0.35
		spawn_chase_particles(Vector2(165, 300), Color("#e7d6ac"), 24)


func update_rogue(delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vector.x = -1
	if Input.is_key_pressed(KEY_D): input_vector.x = 1
	if Input.is_key_pressed(KEY_W): input_vector.y = -1
	if Input.is_key_pressed(KEY_S): input_vector.y = 1
	rogue_player += input_vector.normalized() * 235.0 * delta
	rogue_player.x = clampf(rogue_player.x, 45, 915)
	rogue_player.y = clampf(rogue_player.y, 125, 470)
	rogue_spawn_timer -= delta
	if rogue_spawn_timer <= 0.0 and rogue_kills + rogue_enemies.size() < 18:
		rogue_spawn_timer = maxf(0.28, 0.72 - rogue_kills * 0.015)
		spawn_rogue_enemy()
	for enemy in rogue_enemies:
		var direction: Vector2 = (rogue_player - enemy.pos).normalized()
		var slow := 0.62 if int(skill_levels.ice) > 0 else 1.0
		enemy.pos += direction * float(enemy.speed) * slow * delta
		if enemy.pos.distance_to(rogue_player) < 27.0:
			rogue_hp -= 22.0 * delta
	rogue_shot_timer -= delta
	if rogue_shot_timer <= 0.0 and not rogue_enemies.is_empty():
		rogue_shot_timer = maxf(0.12, 0.34 - int(skill_levels.fire) * 0.035)
		var closest: Dictionary = rogue_enemies[0]
		for enemy in rogue_enemies:
			if enemy.pos.distance_to(rogue_player) < closest.pos.distance_to(rogue_player): closest = enemy
		rogue_projectiles.append({"pos": rogue_player, "vel": (closest.pos - rogue_player).normalized() * 510.0, "damage": 18.0 + int(skill_levels.fire) * 7.0})
	for projectile in rogue_projectiles:
		projectile.pos += projectile.vel * delta
		for enemy in rogue_enemies:
			if not projectile.get("dead", false) and projectile.pos.distance_to(enemy.pos) < 20.0:
				enemy.hp = float(enemy.hp) - float(projectile.damage)
				projectile.dead = true
	rogue_lightning_timer -= delta
	if int(skill_levels.lightning) > 0 and rogue_lightning_timer <= 0.0 and not rogue_enemies.is_empty():
		rogue_lightning_timer = maxf(0.35, 1.15 - int(skill_levels.lightning) * 0.2)
		var lightning_target: Dictionary = rogue_enemies.pick_random()
		lightning_target.hp = float(lightning_target.hp) - 18.0 * int(skill_levels.lightning)
	rogue_projectiles = rogue_projectiles.filter(func(item: Dictionary) -> bool: return not item.get("dead", false) and Rect2(-40, 80, 1040, 450).has_point(item.pos))
	for i in range(rogue_enemies.size() - 1, -1, -1):
		if float(rogue_enemies[i].hp) <= 0.0:
			rogue_enemies.remove_at(i)
			rogue_kills += 1
	if rogue_hp <= 0:
		rogue_hp = 100
		rogue_player = Vector2(480, 300)
		rogue_enemies.clear()
		status_label.text = "부하들에게 밀렸지만 다시 일어났습니다"
	status_label.text = "HP %d   ·   🔥 %d  ⚡ %d  ❄ %d   ·   부하 %d / 18" % [int(rogue_hp), skill_levels.fire, skill_levels.lightning, skill_levels.ice, rogue_kills]
	if rogue_kills >= 18:
		show_story([
			"보스|내 부하들까지... 이제 진짜로 끝을 내주지.",
			"나|좋아. 마지막은 정면 승부다.",
			"보스|이곳에서는 네 권총 따위로는 부족할 거다!",
			"나|그래서 돌격소총을 준비했지."
		], "shooter")


func spawn_rogue_enemy() -> void:
	var side := randi() % 4
	var pos := Vector2.ZERO
	if side == 0: pos = Vector2(randf_range(20, 940), 105)
	elif side == 1: pos = Vector2(940, randf_range(110, 480))
	elif side == 2: pos = Vector2(randf_range(20, 940), 480)
	else: pos = Vector2(20, randf_range(110, 480))
	rogue_enemies.append({"pos": pos, "hp": 34.0 + rogue_kills * 1.3, "speed": randf_range(62, 90)})


func show_skill_choice() -> void:
	skill_overlay.visible = true
	for i in 3:
		var key: String = ["fire", "lightning", "ice"][i]
		skill_buttons[i].text = ["화염", "번개", "얼음"][i] + "  Lv.%d → Lv.%d" % [int(skill_levels[key]), int(skill_levels[key]) + 1]


func select_skill(index: int) -> void:
	var key: String = ["fire", "lightning", "ice"][index]
	skill_levels[key] = int(skill_levels[key]) + 1
	skill_overlay.visible = false


func start_shooter_phase() -> void:
	rhythm_music.stop()
	roll_time_left = 0.0
	roll_cooldown = 0.0
	roll_label.visible = true
	for button in card_buttons: button.visible = false
	phase = "shooter"
	phase_label.text = "PHASE 5 / 5 · 3D FINAL DUEL"
	help_label.text = "WASD 이동 · 클릭 연사 · SHIFT 구르기 · R 재장전 · SPACE 점프 · C 웅크리기"
	status_label.text = "5번 방 방식 그대로 이동하고 사격해 강화된 보스를 쓰러뜨리세요"
	story_panel.visible = false
	build_boss_arena()
	fps_health = 100
	boss_health = FINAL_BOSS_MAX_HEALTH
	ammo = 30
	reserve_ammo = 240
	reload_timer = 0.0
	reload_bar.visible = false
	shot_timer = 0.0
	gun_sound_timer = 0.0
	boss_attack_timer = 1.8
	slow_timer = 0.0
	freeze_timer = 0.0
	blind_timer = 0.0
	blind_overlay.modulate.a = 0.0
	clear_burning_zones()
	yaw = 0.0
	pitch = 0.0
	boss_bar.max_value = FINAL_BOSS_MAX_HEALTH
	boss_bar.value = FINAL_BOSS_MAX_HEALTH
	boss_bar.visible = true
	health_label.visible = true
	ammo_label.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	damage_flash.color.a = 0.0
	damage_indicator.modulate.a = 0.0
	update_shooter_hud()
	combat_render_ready = false
	call_deferred("warm_up_spell_effects")


func warm_up_spell_effects() -> void:
	if phase != "shooter" or not is_instance_valid(world_3d): return
	var warmup := Node3D.new()
	warmup.position = Vector3(0, -30, -4)
	world_3d.add_child(warmup)
	spawn_vfx_particles(warmup, Color("#ffb09f"), 4, 0.2)
	spawn_fire_volume_particles(warmup, 4, 0.2)
	for child in warmup.get_children():
		if child is GPUParticles3D:
			child.visibility_aabb = AABB(Vector3(-64, -64, -64), Vector3(128, 128, 128))
	for i in 4: await get_tree().process_frame
	if is_instance_valid(warmup): warmup.queue_free()
	combat_render_ready = true


func build_boss_arena() -> void:
	game_viewport = SubViewport.new()
	game_viewport.size = Vector2i(960, 540)
	game_viewport.msaa_3d = Viewport.MSAA_4X
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.handle_input_locally = false
	add_child(game_viewport)
	viewport_texture = TextureRect.new()
	viewport_texture.position = Vector2.ZERO
	viewport_texture.size = VIEW_SIZE
	viewport_texture.texture = game_viewport.get_texture()
	viewport_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewport_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	viewport_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(viewport_texture)
	move_child(viewport_texture, 0)

	world_3d = Node3D.new()
	game_viewport.add_child(world_3d)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#111923")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c6c9c4")
	env.ambient_light_energy = 0.62
	environment.environment = env
	world_3d.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world_3d.add_child(sun)
	create_3d_box(Vector3(0, -0.35, -3), Vector3(24, 0.7, 30), Color("#354044"), true)
	create_3d_box(Vector3(0, 2.5, -18), Vector3(24, 5, 0.8), Color("#4a5052"), true)
	create_3d_box(Vector3(-12, 2.5, -3), Vector3(0.8, 5, 30), Color("#41494c"), true)
	create_3d_box(Vector3(12, 2.5, -3), Vector3(0.8, 5, 30), Color("#41494c"), true)
	create_3d_box(Vector3(0, 2.5, 12), Vector3(24, 5, 0.8), Color("#353d41"), true)
	for x in [-8.0, -4.0, 0.0, 4.0, 8.0]:
		create_3d_box(Vector3(x, 0.02, -3), Vector3(0.035, 0.03, 28), Color("#73796c"), false)
	build_fps_player()
	build_club_leader_boss_3d()


func build_fps_player() -> void:
	fps_player = CharacterBody3D.new()
	fps_player.position = Vector3(0, 1.05, 8)
	world_3d.add_child(fps_player)
	fps_player_collision = CollisionShape3D.new()
	fps_player_capsule = CapsuleShape3D.new()
	fps_player_capsule.radius = 0.38
	fps_player_capsule.height = 1.8
	fps_player_collision.shape = fps_player_capsule
	fps_player.add_child(fps_player_collision)
	fps_camera = Camera3D.new()
	fps_camera.position = Vector3(0, 0.62, 0)
	fps_camera.fov = 74
	fps_camera.current = true
	fps_player.add_child(fps_camera)
	fps_gun = Node3D.new()
	fps_gun.position = Vector3(0.48, -0.37, -0.82)
	fps_camera.add_child(fps_gun)
	var rifle_body := make_mesh_box(Vector3(0.2, 0.19, 0.95), Color("#262d3a"))
	rifle_body.position = Vector3(0, 0, -0.35)
	fps_gun.add_child(rifle_body)
	var barrel := make_mesh_box(Vector3(0.09, 0.09, 0.7), Color("#64748b"))
	barrel.position = Vector3(0, 0.04, -1.12)
	fps_gun.add_child(barrel)
	var magazine := make_mesh_box(Vector3(0.18, 0.42, 0.25), Color("#111827"))
	magazine.position = Vector3(0, -0.27, -0.25)
	magazine.rotation_degrees.x = -12
	fps_gun.add_child(magazine)
	fps_muzzle = OmniLight3D.new()
	fps_muzzle.position = Vector3(0, 0.04, -1.48)
	fps_muzzle.light_color = Color("#fbbf24")
	fps_muzzle.light_energy = 0.0
	fps_muzzle.omni_range = 4
	fps_gun.add_child(fps_muzzle)
	fps_muzzle_flash = Node3D.new()
	fps_muzzle_flash.position = Vector3(0, 0.04, -1.50)
	fps_muzzle_flash.visible = false
	fps_gun.add_child(fps_muzzle_flash)
	var flash_core := make_mesh_sphere(0.13, Color("#fff4b0"))
	flash_core.material_override = make_glow_material(Color("#fff4b0"), 8.0)
	flash_core.scale = Vector3(0.8, 0.8, 2.4)
	fps_muzzle_flash.add_child(flash_core)
	for angle in [0.0, 60.0, 120.0]:
		var flare := make_mesh_box(Vector3(0.035, 0.48, 0.035), Color("#ff9f1c"))
		flare.material_override = make_glow_material(Color("#ff9f1c"), 7.0)
		flare.rotation_degrees.z = angle
		fps_muzzle_flash.add_child(flare)


func build_club_leader_boss_3d() -> void:
	# Blender + MPFB에서 제작한 실제 인체 메시, 얼굴 모프, 머리카락과 의상을 사용한다.
	boss_body = StaticBody3D.new()
	boss_body.position = Vector3(0, 0, -14)
	boss_body.collision_layer = 2
	boss_body.collision_mask = 1
	world_3d.add_child(boss_body)
	boss_visual = Node3D.new()
	boss_body.add_child(boss_visual)
	var imported_model := CLUB_LEADER_3D_SCENE.instantiate() as Node3D
	imported_model.name = "ClubLeaderBossRebuiltModel"
	imported_model.scale = Vector3.ONE * 3.05
	boss_visual.add_child(imported_model)
	configure_boss_skin(imported_model)
	boss_skeleton = find_skeleton_3d(imported_model)
	if is_instance_valid(boss_skeleton):
		boss_head_bone = boss_skeleton.find_bone("head")
		boss_left_arm_bone = boss_skeleton.find_bone("upperarm01.L")
		boss_right_arm_bone = boss_skeleton.find_bone("upperarm01.R")
		boss_bone_controls.clear()
		boss_rest_poses.clear()
		for bone_name in ["head", "spine03", "upperarm01.L", "upperarm01.R", "lowerarm01.L", "lowerarm01.R", "upperleg01.L", "upperleg01.R", "lowerleg01.L", "lowerleg01.R"]:
			var bone_index := boss_skeleton.find_bone(bone_name)
			if bone_index >= 0:
				boss_bone_controls[bone_name] = bone_index
				boss_rest_poses[bone_name] = boss_skeleton.get_bone_pose_rotation(bone_index)
	boss_stride = 0.0
	boss_walk_blend = 0.0
	boss_turning = false
	boss_animation_player = find_boss_animation_player(imported_model)
	boss_motion_clips.clear()
	if is_instance_valid(boss_animation_player):
		for clip in ["Idle","Walk","StrafeLeft","StrafeRight","Cast","Dash"]:
			for animation_name in boss_animation_player.get_animation_list():
				if String(animation_name).contains("Boss_" + clip):
					boss_motion_clips[clip] = animation_name
					boss_animation_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR if clip in ["Idle","Walk","StrafeLeft","StrafeRight"] else Animation.LOOP_NONE
		play_boss_motion("Idle",0.0)
	# 기존 시전 코드와 호환되는 제어용 피벗. 실제 팔/머리는 Skeleton3D가 움직인다.
	boss_spine = Node3D.new()
	boss_visual.add_child(boss_spine)
	boss_head_pivot = Node3D.new()
	boss_visual.add_child(boss_head_pivot)
	boss_left_arm = Node3D.new()
	boss_visual.add_child(boss_left_arm)
	boss_right_arm = Node3D.new()
	boss_visual.add_child(boss_right_arm)
	boss_left_forearm = Node3D.new()
	boss_visual.add_child(boss_left_forearm)
	boss_right_forearm = Node3D.new()
	boss_visual.add_child(boss_right_forearm)
	boss_left_leg = Node3D.new()
	boss_visual.add_child(boss_left_leg)
	boss_right_leg = Node3D.new()
	boss_visual.add_child(boss_right_leg)
	boss_left_knee = Node3D.new()
	boss_visual.add_child(boss_left_knee)
	boss_right_knee = Node3D.new()
	boss_visual.add_child(boss_right_knee)
	boss_aura = OmniLight3D.new()
	boss_aura.position = Vector3(0, 3.0, 0.5)
	boss_aura.light_color = Color("#bbc5d8")
	boss_aura.light_energy = 0.18
	boss_aura.omni_range = 8.0
	boss_visual.add_child(boss_aura)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.5, 5.8, 2.0)
	collision.shape = shape
	collision.position.y = 2.5
	boss_body.add_child(collision)


func find_boss_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found := find_boss_animation_player(child)
		if found != null: return found
	return null


func play_boss_motion(kind: String, blend := 0.18) -> void:
	if phase != "shooter": return
	if not is_instance_valid(boss_animation_player) or not boss_motion_clips.has(kind): return
	var clip: StringName = boss_motion_clips[kind]
	if boss_animation_player.current_animation == clip and boss_animation_player.is_playing(): return
	boss_animation_player.speed_scale = 1.0
	boss_animation_player.play(clip,blend)


func boss_motion_locked() -> bool:
	return is_instance_valid(boss_animation_player) and boss_animation_player.is_playing() and boss_animation_player.current_animation in [boss_motion_clips.get("Cast",""),boss_motion_clips.get("Dash","")]


func update_boss_motion(velocity: Vector3) -> void:
	if phase != "shooter": return
	if boss_motion_locked(): return
	var speed := Vector2(velocity.x,velocity.z).length()
	if speed < 0.2:
		play_boss_motion("Idle")
		boss_animation_player.speed_scale = 1.0
	else:
		play_boss_motion("Walk")
		boss_animation_player.speed_scale = clampf(speed/BOSS_CAPTURED_WALK_SPEED,0.35,1.8)


func configure_boss_skin(node: Node) -> void:
	if node is MeshInstance3D:
		for index in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(index) as StandardMaterial3D
			if source != null and source.resource_name == "Boss_Skin_PBR":
				var skin := source.duplicate() as StandardMaterial3D
				# The GLB contains complexion COLOR_0; Godot does not enable it automatically.
				skin.vertex_color_use_as_albedo = true
				node.set_surface_override_material(index,skin)
	for child in node.get_children(): configure_boss_skin(child)


func find_skeleton_3d(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := find_skeleton_3d(child)
		if found != null:
			return found
	return null


func update_shooter(delta: float) -> void:
	if not is_instance_valid(fps_player): return
	shot_timer = maxf(0.0, shot_timer - delta)
	gun_sound_timer = maxf(0.0, gun_sound_timer - delta)
	slow_timer = maxf(0.0, slow_timer - delta)
	freeze_timer = maxf(0.0, freeze_timer - delta)
	blind_timer = maxf(0.0, blind_timer - delta)
	blind_overlay.modulate.a = minf(1.0, blind_timer / 0.55)
	roll_cooldown = maxf(0.0, roll_cooldown - delta)
	roll_time_left = maxf(0.0, roll_time_left - delta)
	if reload_timer > 0.0:
		reload_timer -= delta
		reload_bar.value = 1.35 - maxf(0.0, reload_timer)
		if reload_timer <= 0.0:
			var loaded := mini(30 - ammo, reserve_ammo)
			ammo += loaded
			reserve_ammo -= loaded
			fps_gun.position = Vector3(0.48, -0.37, -0.82)
			reload_bar.visible = false
	reload_hint.visible = reload_timer > 0.0
	if reload_hint.visible: reload_hint.text = "재장전 · %.1f초" % reload_timer
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): shoot_boss()
	# A killing shot changes phase inside shoot_boss. Do not restart walking below.
	if phase != "shooter": return
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vector.x = -1
	if Input.is_key_pressed(KEY_D): input_vector.x = 1
	if Input.is_key_pressed(KEY_W): input_vector.y = -1
	if Input.is_key_pressed(KEY_S): input_vector.y = 1
	fps_is_crouching = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	var rolling := roll_time_left > 0.0
	var roll_progress := 1.0 - roll_time_left / ROLL_DURATION if rolling else 0.0
	var roll_curve := sin(roll_progress * PI) if rolling else 0.0
	var camera_height := 0.62 - roll_curve * 0.48 if rolling else (0.20 if fps_is_crouching else 0.62)
	fps_camera.position.y = move_toward(fps_camera.position.y, camera_height, delta * 5.5)
	var bank := -signf(roll_local.x) * roll_curve * 0.55 if roll_kind == "side" else 0.0
	fps_camera.rotation.z = lerpf(fps_camera.rotation.z, bank, minf(delta * 16, 1.0))
	if rolling and roll_kind == "forward":
		fps_camera.rotation.x = pitch - TAU * smoothstep(0.0,1.0,roll_progress)
	elif rolling and roll_kind == "back":
		fps_camera.rotation.x = pitch + roll_curve * 0.75
	else:
		fps_camera.rotation.x = pitch
	fps_player_capsule.height = 1.0 if rolling else (1.12 if fps_is_crouching else 1.8)
	fps_player_collision.position.y = -0.40 if rolling else (-0.34 if fps_is_crouching else 0.0)
	var forward := -fps_player.global_transform.basis.z
	var right := fps_player.global_transform.basis.x
	forward.y = 0
	right.y = 0
	var movement := (right * input_vector.x - forward * input_vector.y).normalized()
	var speed := SHOOTER_SPEED * (0.48 if fps_is_crouching else 1.0) * (0.55 if slow_timer > 0 else 1.0)
	fps_player.velocity.x = movement.x * speed
	fps_player.velocity.z = movement.z * speed
	if rolling:
		var roll_speed := roll_curve * 14.0
		fps_player.velocity.x = roll_direction.x * roll_speed
		fps_player.velocity.z = roll_direction.z * roll_speed
	if freeze_timer > 0.0:
		fps_player.velocity.x = 0
		fps_player.velocity.z = 0
	roll_label.text = "구르는 중 · 공격 회피" if rolling else ("SHIFT 구르기 · %.1f초" % roll_cooldown if roll_cooldown > 0 else "SHIFT 구르기 · 준비 완료")
	if freeze_timer > 0: roll_label.text = "빙결 · %.1f초 후 이동 가능" % freeze_timer
	if not fps_player.is_on_floor(): fps_player.velocity.y -= SHOOTER_GRAVITY * delta
	elif fps_player.velocity.y < 0: fps_player.velocity.y = 0
	fps_player.move_and_slide()
	if not boss_casting:
		boss_attack_timer -= delta
	if boss_attack_timer <= 0.0 and not boss_casting and combat_render_ready:
		var health_ratio := float(boss_health) / float(FINAL_BOSS_MAX_HEALTH)
		if health_ratio > 0.70:
			boss_attack_timer = randf_range(2.45, 3.05)
		elif health_ratio > 0.35:
			boss_attack_timer = randf_range(1.95, 2.55)
		else:
			boss_attack_timer = randf_range(1.55, 2.05)
		cast_boss_spell()
	update_arena_attacks(delta)
	update_burning_zones(delta)
	camera_shake = maxf(0.0, camera_shake - delta)
	if camera_shake > 0.0:
		fps_camera.h_offset = randf_range(-0.08, 0.08) * camera_shake * 4.0
		fps_camera.v_offset = randf_range(-0.06, 0.06) * camera_shake * 4.0
	else:
		fps_camera.h_offset = 0.0
		fps_camera.v_offset = 0.0
	boss_move_time += delta
	var previous_boss_position := boss_body.position
	if is_instance_valid(boss_body) and not boss_casting and not boss_motion_locked():
		var desired := Vector3(sin(boss_move_time * 0.72) * 7.5, 0.0, -13.0 + cos(boss_move_time * 0.48) * 2.2)
		var to_goal := desired-boss_body.position
		var distance := Vector2(to_goal.x,to_goal.z).length()
		if distance > 0.12:
			var target_yaw := atan2(to_goal.x,to_goal.z)
			var error := absf(angle_difference(boss_body.rotation.y,target_yaw))
			if error > 0.55: boss_turning = true
			if boss_turning and error < 0.10: boss_turning = false
			boss_body.rotation.y = rotate_toward(boss_body.rotation.y,target_yaw,delta*2.8)
			if not boss_turning:
				boss_body.position += boss_body.global_basis.z * minf(distance,delta*2.8)
	var travel := boss_body.position.distance_to(previous_boss_position)
	boss_stride += travel * 2.8
	boss_walk_blend = move_toward(boss_walk_blend, clampf(travel / maxf(delta, 0.001) / 3.5, 0.0, 1.0), delta * 5.0)
	if is_instance_valid(boss_animation_player):
		var local_velocity := boss_body.global_basis.inverse() * (boss_body.position-previous_boss_position) / maxf(delta,0.001)
		update_boss_motion(local_velocity)
	elif is_instance_valid(boss_visual):
		var idle_time := Time.get_ticks_msec() * 0.001
		var step := sin(idle_time * 4.5)
		var breath := sin(idle_time * 1.7)
		boss_visual.position.y = abs(step) * 0.025 + breath * 0.025
		boss_visual.rotation_degrees.z = sin(idle_time * 2.25) * 0.45
		if not boss_casting:
			boss_spine.rotation_degrees.x = breath * 0.7
			boss_spine.rotation_degrees.y = sin(idle_time * 2.25) * 1.6
			boss_left_arm.rotation_degrees = Vector3(step * 8.0, 0, -7.0 + breath * 1.0)
			boss_right_arm.rotation_degrees = Vector3(-step * 8.0, 0, 7.0 - breath * 1.0)
			boss_left_forearm.rotation_degrees.x = maxf(0.0, -step) * -10.0
			boss_right_forearm.rotation_degrees.x = maxf(0.0, step) * -10.0
			boss_left_leg.rotation_degrees.x = -step * 6.5
			boss_right_leg.rotation_degrees.x = step * 6.5
			boss_left_knee.rotation_degrees.x = maxf(0.0, step) * 11.0
			boss_right_knee.rotation_degrees.x = maxf(0.0, -step) * 11.0
			if is_instance_valid(boss_head_pivot):
				boss_head_pivot.rotation_degrees.y = sin(idle_time * 0.72) * 3.2
				boss_head_pivot.rotation_degrees.x = -breath * 0.9
				boss_head_pivot.rotation_degrees.z = sin(idle_time * 1.05) * 0.8
		update_realistic_boss_skeleton(step, breath)
	update_shooter_hud()


func begin_roll(forced_direction := Vector3.ZERO, forced := false) -> void:
	if phase != "shooter": return
	if not forced and (roll_cooldown > 0.0 or freeze_timer > 0.0 or not fps_player.is_on_floor()): return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input.x = -1
	if Input.is_key_pressed(KEY_D): input.x = 1
	if Input.is_key_pressed(KEY_W): input.y = -1
	if Input.is_key_pressed(KEY_S): input.y = 1
	if input.length_squared() < 0.01: input.y = -1
	roll_local = input.normalized()
	roll_kind = "forward" if input.y < -0.25 else ("back" if input.y > 0.25 else "side")
	var forward := -fps_player.global_transform.basis.z
	var right := fps_player.global_transform.basis.x
	roll_direction = (right * input.x - forward * input.y).normalized()
	roll_direction.y = 0
	if forced:
		roll_direction = forced_direction.normalized()
		roll_direction.y = 0
		roll_local = Vector2(0,1)
		roll_kind = "back"
	roll_time_left = ROLL_DURATION
	roll_cooldown = ROLL_COOLDOWN
	Sfx.play("boss_charge", -17, 1.3)


func update_realistic_boss_skeleton(step: float, breath: float) -> void:
	if is_instance_valid(boss_animation_player): return
	if not is_instance_valid(boss_skeleton):
		return
	var cast_curve := sin(boss_cast_pose * PI)
	var gait := sin(boss_stride) * boss_walk_blend * (1.0 - cast_curve * 0.7)
	pose_boss_bone("head", Vector3(-breath * 0.018, sin(boss_move_time * 0.65) * 0.025, -step * 0.008))
	pose_boss_bone("spine03", Vector3(-cast_curve * 0.12 + breath * 0.012, gait * 0.025, 0))
	point_boss_arm("upperarm01.L", Vector3(0.12 + cast_curve * 0.32, -1.0 + cast_curve * 0.80, cast_curve * 0.85 + gait * 0.14))
	point_boss_arm("upperarm01.R", Vector3(-0.12 - cast_curve * 0.32, -1.0 + cast_curve * 0.80, cast_curve * 0.95 - gait * 0.14))
	pose_boss_bone("lowerarm01.L", Vector3(-0.06 - cast_curve * 0.45, 0, 0))
	pose_boss_bone("lowerarm01.R", Vector3(-0.06 - cast_curve * 0.55, 0, 0))
	pose_boss_bone("upperleg01.L", Vector3(gait * 0.22, 0, 0))
	pose_boss_bone("upperleg01.R", Vector3(-gait * 0.22, 0, 0))
	pose_boss_bone("lowerleg01.L", Vector3(maxf(0.0, -gait) * 0.32, 0, 0))
	pose_boss_bone("lowerleg01.R", Vector3(maxf(0.0, gait) * 0.32, 0, 0))


func pose_boss_bone(bone_name: String, angles: Vector3) -> void:
	if boss_bone_controls.has(bone_name):
		var base_rotation: Quaternion = boss_rest_poses[bone_name]
		boss_skeleton.set_bone_pose_rotation(int(boss_bone_controls[bone_name]), base_rotation * Quaternion.from_euler(angles))


func point_boss_arm(bone_name: String, direction: Vector3) -> void:
	if not boss_bone_controls.has(bone_name):
		return
	var bone_index := int(boss_bone_controls[bone_name])
	var parent_index := boss_skeleton.get_bone_parent(bone_index)
	var parent_basis := boss_skeleton.get_bone_global_pose(parent_index).basis if parent_index >= 0 else Basis.IDENTITY
	var rest_basis := boss_skeleton.get_bone_rest(bone_index).basis
	var world_basis := boss_skeleton.global_basis * parent_basis * rest_basis
	var desired := world_basis.inverse() * (boss_body.global_basis * direction)
	boss_skeleton.set_bone_pose_rotation(bone_index, Quaternion(Vector3.UP, desired.normalized()))


func cast_boss_spell() -> void:
	if phase != "shooter": return
	boss_casting = true
	var cast_lock_time := 0.62
	if is_instance_valid(boss_visual) and not is_instance_valid(boss_animation_player):
		# 주문마다 옆으로 미끄러지며 몸을 낮추고 힘을 모은다. 정지한 채 그림만
		# 나타나는 느낌을 피하고, 예고 범위와 보스 동작을 한 흐름으로 연결한다.
		var cast_tween := create_tween()
		cast_tween.tween_property(boss_visual, "scale", Vector3(1.08, 0.88, 1.08), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		cast_tween.tween_property(boss_visual, "scale", Vector3(0.94, 1.16, 0.94), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cast_tween.tween_property(boss_visual, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(boss_body) and not is_instance_valid(boss_animation_player):
		var strafe_target := clampf(boss_body.position.x + randf_range(-3.0, 3.0), -8.5, 8.5)
		boss_body.create_tween().tween_property(boss_body, "position:x", strafe_target, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var spell_roll := randf()
	if spell_roll < 0.25:
		Sfx.play_unique("boss_ice", -5.0, 0.94, 0.025)
		animate_boss_cast("ice")
		status_label.text = "얼음 파동! 표시된 원 밖으로 나가거나 점프하세요"
		var target := Vector3(fps_player.position.x, 0.08, fps_player.position.z)
		var node := make_spell_disc(target, Color("#67e8f9aa"), 7.5)
		arena_attacks.append({"kind": "ice", "time": 1.25, "pos": target, "node": node})
	elif spell_roll < 0.53:
		Sfx.play_unique("boss_fire", -7.0, 0.96, 0.025)
		animate_boss_cast("fire")
		status_label.text = "화염 낙하! 표시된 바닥에서 벗어나세요"
		for offset in [-2.3, 0.0, 2.3]:
			var target := Vector3(fps_player.position.x + offset, 0.08, fps_player.position.z)
			var node := make_spell_disc(target, Color("#fb718588"), 1.7)
			arena_attacks.append({"kind": "fire", "time": 1.0, "pos": target, "node": node})
	elif spell_roll < 0.80:
		Sfx.play_unique("boss_lightning", -5.0, 0.92, 0.025)
		animate_boss_cast("lightning")
		status_label.text = "추적 번개! 보스와 나를 잇는 빛의 경로에서 벗어나세요"
		var lightning_start := Vector3(boss_body.position.x, 0.08, boss_body.position.z)
		var lightning_direction := Vector3(fps_player.position.x, 0.08, fps_player.position.z) - lightning_start
		var lightning_target := lightning_start + lightning_direction.normalized() * minf(21.0, lightning_direction.length() + 4.0)
		lightning_target.x = clampf(lightning_target.x, -11.0, 11.0)
		lightning_target.z = clampf(lightning_target.z, -17.0, 11.0)
		var node := make_charge_lane(lightning_start, lightning_target, Color("#fde047bb"), 1.8)
		arena_attacks.append({"kind": "lightning", "time": 0.92, "start": lightning_start, "pos": lightning_target, "node": node})
	else:
		Sfx.play_unique("boss_charge", -8.0, 0.94, 0.02)
		animate_boss_cast("charge")
		status_label.text = "보스 돌진! 붉은 경로 옆으로 피하세요"
		var charge_start := boss_body.position
		var charge_direction := fps_player.position - charge_start
		charge_direction.y = 0.0
		var charge_target := charge_start + charge_direction.normalized() * minf(15.0, charge_direction.length() + 2.5)
		charge_target.x = clampf(charge_target.x, -10.5, 10.5)
		charge_target.z = clampf(charge_target.z, -16.0, 10.0)
		var node := make_charge_lane(charge_start, charge_target, Color("#ff3b30cc"), 2.5)
		arena_attacks.append({"kind": "charge", "time": 1.0, "start": charge_start, "pos": charge_target, "node": node})
		cast_lock_time = BOSS_TELEGRAPH_TIME + 0.55
	get_tree().create_timer(cast_lock_time, false).timeout.connect(func() -> void: boss_casting = false)


func animate_boss_cast(kind: String) -> void:
	if phase != "shooter": return
	if not is_instance_valid(boss_left_arm) or not is_instance_valid(boss_right_arm): return
	var color := Color("#38bdf8") if kind == "ice" else Color("#fb4b24") if kind == "fire" else Color("#ef4444") if kind == "charge" else Color("#fde047")
	if is_instance_valid(boss_animation_player):
		var toward_player := fps_player.position-boss_body.position
		var target_yaw := lerp_angle(boss_body.rotation.y,atan2(toward_player.x,toward_player.z),1.0)
		if boss_turn_tween != null and boss_turn_tween.is_valid(): boss_turn_tween.kill()
		boss_turn_tween = boss_body.create_tween()
		boss_turn_tween.tween_property(boss_body,"rotation:y",target_yaw,0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		play_boss_motion("Dash" if kind == "charge" else "Cast",0.12)
		boss_aura.light_color = color
		if boss_glow_tween != null and boss_glow_tween.is_valid(): boss_glow_tween.kill()
		boss_glow_tween = create_tween()
		boss_glow_tween.tween_property(boss_aura,"light_energy",1.4,0.2)
		boss_glow_tween.tween_property(boss_aura,"light_energy",0.18,0.65)
		return
	boss_aura.light_color = color
	boss_aura.light_energy = 2.4
	boss_cast_pose = 0.0
	var skeleton_tween := create_tween()
	skeleton_tween.tween_property(self, "boss_cast_pose", 0.55, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	skeleton_tween.tween_property(self, "boss_cast_pose", 1.0, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	skeleton_tween.tween_property(self, "boss_cast_pose", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var start_rotation := boss_visual.rotation_degrees.y
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(boss_left_arm, "rotation_degrees", Vector3(-38, -18, 38), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(boss_right_arm, "rotation_degrees", Vector3(-96, 12, -62), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(boss_visual, "rotation_degrees:y", start_rotation - 16.0, 0.16)
	tween.chain().set_parallel(true)
	tween.tween_property(boss_left_arm, "rotation_degrees", Vector3(-88, 0, 70), 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_right_arm, "rotation_degrees", Vector3(-68, 0, -78), 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_visual, "rotation_degrees:y", start_rotation + 22.0, 0.13).set_trans(Tween.TRANS_EXPO)
	tween.chain().set_parallel(true)
	tween.tween_property(boss_left_arm, "rotation_degrees", Vector3(0, 0, -7), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_right_arm, "rotation_degrees", Vector3(0, 0, 7), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(boss_visual, "rotation_degrees:y", start_rotation, 0.34)
	tween.tween_property(boss_aura, "light_energy", 0.55, 0.42)


func update_arena_attacks(delta: float) -> void:
	for attack in arena_attacks:
		attack.time = float(attack.time) - delta
		if attack.time <= 0.0 and not attack.get("done", false):
			attack.done = true
			spawn_spell_impact(str(attack.kind), attack.pos, attack.get("start", attack.pos))
			if attack.kind == "fire" and Vector2(fps_player.position.x, fps_player.position.z).distance_to(Vector2(attack.pos.x, attack.pos.z)) < 1.75:
				apply_spell_hit("fire",attack.get("start",attack.pos))
			if attack.kind == "fire": spawn_burning_zone(attack.pos)
			if attack.kind == "ice" and Vector2(fps_player.position.x, fps_player.position.z).distance_to(Vector2(attack.pos.x, attack.pos.z)) <= 7.5 and fps_player.position.y < 1.45:
				apply_spell_hit("ice",attack.pos)
			if attack.kind == "lightning":
				var player_2d := Vector2(fps_player.position.x, fps_player.position.z)
				var start_2d := Vector2(attack.start.x, attack.start.z)
				var end_2d := Vector2(attack.pos.x, attack.pos.z)
				if distance_to_segment(player_2d, start_2d, end_2d) < 1.0:
					apply_spell_hit("lightning",attack.start)
			if attack.kind == "charge":
				perform_boss_charge(attack.start, attack.pos)
				var player_2d := Vector2(fps_player.position.x, fps_player.position.z)
				var start_2d := Vector2(attack.start.x, attack.start.z)
				var end_2d := Vector2(attack.pos.x, attack.pos.z)
				if distance_to_segment(player_2d, start_2d, end_2d) < 1.45:
					apply_spell_hit("charge",attack.start)
			if is_instance_valid(attack.node): attack.node.queue_free()
	arena_attacks = arena_attacks.filter(func(item: Dictionary) -> bool: return not item.get("done", false))


func apply_spell_hit(kind: String, source: Vector3) -> bool:
	var damage: int = {"fire":14,"ice":18,"lightning":22,"charge":26}[kind]
	var tint: Color = {"fire":Color("#ff6b36"),"ice":Color("#67e8f9"),"lightning":Color("#fff38a"),"charge":Color("#ff3b30")}[kind]
	if not damage_fps_player(damage,tint): return false
	if kind == "ice":
		freeze_timer = 2.0
		roll_time_left = 0
		status_label.text = "빙결! 2초 동안 이동 불가"
	elif kind == "lightning":
		blind_timer = 1.0
		blind_overlay.modulate.a = 1.0
		status_label.text = "번개! 1초 동안 시야 차단"
	elif kind == "charge":
		freeze_timer = 0
		var away := fps_player.position - source
		away.y = 0
		if away.length_squared() < 0.01: away = fps_player.global_transform.basis.z
		begin_roll(away,true)
		status_label.text = "돌진에 밀려 뒤로 굴렀습니다!"
	return true


func spawn_burning_zone(at: Vector3) -> void:
	var node := Node3D.new()
	node.position = at
	world_3d.add_child(node)
	spawn_fire_volume_particles(node,55,1.5)
	for child in node.get_children():
		if child is GPUParticles3D: child.one_shot = false
	burning_zones.append({"node":node,"pos":at,"time":2.0})
	burn_damage_cooldown = maxf(burn_damage_cooldown,0.4)


func update_burning_zones(delta: float) -> void:
	burn_damage_cooldown = maxf(0,burn_damage_cooldown-delta)
	for zone in burning_zones:
		zone.time = float(zone.time)-delta
		if zone.time <= 0: continue
		if burn_damage_cooldown <= 0 and fps_player.position.y < 1.65 and Vector2(fps_player.position.x,fps_player.position.z).distance_to(Vector2(zone.pos.x,zone.pos.z)) < 1.75:
			if damage_fps_player(7,Color("#ff6b36")):
				burn_damage_cooldown = 0.5
				status_label.text = "바닥의 불에 닿았습니다! · -7 HP"
	for zone in burning_zones:
		if zone.time <= 0 and is_instance_valid(zone.node): zone.node.queue_free()
	burning_zones = burning_zones.filter(func(z:Dictionary)->bool:return float(z.time)>0)


func clear_burning_zones() -> void:
	for zone in burning_zones:
		if is_instance_valid(zone.node): zone.node.queue_free()
	burning_zones.clear()


func shoot_boss() -> void:
	if phase != "shooter" or shot_timer > 0.0 or reload_timer > 0.0: return
	if ammo <= 0:
		begin_boss_reload()
		return
	shot_timer = 0.095
	ammo -= 1
	# A short, faded tail overlaps naturally; do not repeatedly cut a live sound.
	Sfx.play("gunshot_auto", -10.0, 0.98, 0.015)
	fps_muzzle.light_energy = 5.0
	fps_muzzle_flash.visible = true
	fps_muzzle_flash.rotation_degrees.z = randf_range(0.0, 180.0)
	fps_muzzle_flash.scale = Vector3(0.45, 0.45, 0.75)
	fps_muzzle_flash.create_tween().tween_property(fps_muzzle_flash, "scale", Vector3(1.15, 1.15, 1.55), 0.035)
	get_tree().create_timer(0.045, false).timeout.connect(func() -> void:
		if is_instance_valid(fps_muzzle): fps_muzzle.light_energy = 0.0
		if is_instance_valid(fps_muzzle_flash): fps_muzzle_flash.visible = false
	)
	var origin := fps_camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -fps_camera.global_transform.basis.z * 80.0)
	query.exclude = [fps_player.get_rid()]
	query.collision_mask = 3
	var result := fps_camera.get_world_3d().direct_space_state.intersect_ray(query)
	var bullet_end: Vector3 = result.position if not result.is_empty() else origin + -fps_camera.global_transform.basis.z * 55.0
	spawn_player_bullet(fps_muzzle.global_position, bullet_end)
	GUN_EFFECTS.casing(world_3d, fps_gun.global_position, fps_camera.global_transform.basis.x)
	if not result.is_empty() and result.collider == boss_body:
		Sfx.play("hit", -5.0, 0.84, 0.03)
		boss_health -= 30
		status_label.text = "보스 명중 · 30 DAMAGE"
		if is_instance_valid(boss_visual) and not is_instance_valid(boss_animation_player):
			var tween := create_tween()
			tween.tween_property(boss_visual, "scale", Vector3(1.08, 0.94, 1.08), 0.04)
			tween.tween_property(boss_visual, "scale", Vector3.ONE, 0.08)
		if boss_health <= 0: defeat_final_boss()
	if ammo == 0 and reserve_ammo > 0: begin_boss_reload()


func spawn_player_bullet(start: Vector3, target: Vector3) -> void:
	# 판정은 즉시 처리하되 화면에는 밝은 탄두와 잔상이 목표까지 날아간다.
	var distance := start.distance_to(target)
	if distance < 0.05:
		return
	var direction := (target - start).normalized()
	var projectile := Node3D.new()
	projectile.position = start
	world_3d.add_child(projectile)
	var bullet := make_mesh_capsule(0.035, 0.42, Color("#fff2a8"))
	bullet.material_override = make_glow_material(Color("#fff2a8"), 9.0)
	bullet.rotation_degrees.x = 90.0
	projectile.add_child(bullet)
	projectile.look_at(target, Vector3.UP, true)
	var trail := MeshInstance3D.new()
	var trail_mesh := ImmediateMesh.new()
	trail_mesh.surface_begin(Mesh.PRIMITIVE_LINES, make_glow_material(Color("#ffb020cc"), 7.0))
	trail_mesh.surface_add_vertex(Vector3.ZERO)
	trail_mesh.surface_add_vertex(Vector3(0, 0, 1.15))
	trail_mesh.surface_end()
	trail.mesh = trail_mesh
	projectile.add_child(trail)
	var flight_time := clampf(distance / 115.0, 0.055, 0.15)
	var tween := projectile.create_tween()
	tween.tween_property(projectile, "position", target, flight_time).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func() -> void:
		if not is_instance_valid(projectile): return
		var spark := make_mesh_sphere(0.10, Color("#fff7c2"))
		spark.material_override = make_glow_material(Color("#ffb020"), 7.0)
		spark.position = projectile.position
		world_3d.add_child(spark)
		spark.scale = Vector3(0.25, 0.25, 0.25)
		var impact_tween := spark.create_tween()
		impact_tween.tween_property(spark, "scale", Vector3(1.8, 1.8, 1.8), 0.055)
		impact_tween.tween_property(spark, "scale", Vector3.ZERO, 0.09)
		impact_tween.tween_callback(spark.queue_free)
		projectile.queue_free()
	)


func begin_boss_reload() -> void:
	if reload_timer > 0.0 or ammo == 30 or reserve_ammo <= 0: return
	reload_timer = 1.35
	Sfx.play("reload", -9.0, 1.0)
	reload_bar.value = 0.0
	reload_bar.visible = true
	fps_gun.position = Vector3(0.34, -0.9, -0.65)
	status_label.text = "재장전 중..."


func damage_fps_player(amount: int, hit_color: Color = Color("#ff453a")) -> bool:
	var roll_elapsed := ROLL_DURATION - roll_time_left
	if roll_time_left > 0.0 and roll_elapsed >= 0.07 and roll_elapsed <= 0.40:
		status_label.text = "DODGE · 구르기로 회피!"
		return false
	fps_health -= amount
	Sfx.play("player_hit", 0.0, 0.78, 0.05)
	status_label.text = "보스의 공격에 맞았습니다 · -%d HP" % amount
	camera_shake = maxf(camera_shake, 0.72)
	if is_instance_valid(damage_flash):
		damage_flash.color = Color(hit_color.r, hit_color.g, hit_color.b, 0.38)
		var flash := damage_flash.create_tween()
		flash.tween_property(damage_flash, "color:a", 0.0, 0.34).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if is_instance_valid(damage_indicator):
		damage_indicator.text = "HIT  -%d" % amount
		damage_indicator.modulate = Color(hit_color.r, hit_color.g, hit_color.b, 1.0)
		damage_indicator.scale = Vector2(1.28, 1.28)
		var indicator_tween := damage_indicator.create_tween().set_parallel(true)
		indicator_tween.tween_property(damage_indicator, "modulate:a", 0.0, 0.46).set_delay(0.10)
		indicator_tween.tween_property(damage_indicator, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(health_label):
		health_label.modulate = Color("#ff5a52")
		health_label.scale = Vector2(1.28, 1.28)
		var health_tween := health_label.create_tween().set_parallel(true)
		health_tween.tween_property(health_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		health_tween.tween_property(health_label, "modulate", Color.WHITE, 0.38)
	if is_instance_valid(fps_gun):
		fps_gun.rotation_degrees.z = randf_range(-9.0, 9.0)
		fps_gun.create_tween().tween_property(fps_gun, "rotation_degrees:z", 0.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if fps_health <= 0:
		fps_health = 100
		fps_player.position = Vector3(0, 1.05, 8)
		status_label.text = "다시 일어섰습니다 · 보스전 재개"
	return true


func defeat_final_boss() -> void:
	if phase != "shooter": return
	phase = "defeated"
	defeat_elapsed = 0.0
	defeat_pose_settled = false
	for motion in [boss_dash_tween,boss_turn_tween,boss_recover_tween,boss_glow_tween]:
		if motion != null and motion.is_valid(): motion.kill()
	if is_instance_valid(boss_animation_player):
		boss_animation_player.stop(true)
		boss_animation_player.active = false
	boss_turning = false
	boss_aura.light_energy = 0
	boss_casting = false
	clear_burning_zones()
	for attack in arena_attacks:
		if is_instance_valid(attack.node): attack.node.queue_free()
	arena_attacks.clear()
	freeze_timer = 0
	blind_timer = 0
	blind_overlay.modulate.a = 0
	roll_time_left = 0
	fps_camera.rotation = Vector3(pitch,0,0)
	boss_body.collision_layer = 0
	status_label.text = "이상민을 쓰러뜨렸습니다"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	boss_bar.visible = false
	health_label.visible = false
	ammo_label.visible = false
	reload_bar.visible = false
	reload_hint.visible = false
	roll_label.visible = false
	# Use the established rig: buckle the knees, lose balance, then settle on the floor.
	boss_visual.scale = Vector3.ONE


func update_boss_defeat(delta: float) -> void:
	defeat_elapsed += delta
	if not defeat_pose_settled:
		var knees := smoothstep(0.0,0.65,defeat_elapsed)
		var fall := smoothstep(0.45,1.4,defeat_elapsed)
		pose_boss_bone("lowerleg01.L",Vector3(knees*0.9,0,0))
		pose_boss_bone("lowerleg01.R",Vector3(knees*0.65,0,0))
		pose_boss_bone("upperleg01.L",Vector3(-knees*0.55,0,0))
		pose_boss_bone("upperleg01.R",Vector3(-knees*0.4,0,0))
		pose_boss_bone("spine03",Vector3(knees*0.2,0,0))
		pose_boss_bone("upperarm01.L",Vector3(-0.45*knees,0,-0.25*knees))
		pose_boss_bone("upperarm01.R",Vector3(-0.3*knees,0,0.35*knees))
		boss_visual.rotation.x = -fall * PI * 0.48
		boss_visual.rotation.z = fall * 0.12
		# Fit the posed body to the floor instead of lifting the rotated model by a constant.
		boss_visual.position.y = 0.0
		if is_instance_valid(boss_skeleton):
			boss_skeleton.force_update_all_bone_transforms()
			var lowest := INF
			for contact in [["head",0.095],["spine03",0.13],["spine02",0.12],["pelvis",0.105],["upperleg01.L",0.09],["upperleg01.R",0.09],["lowerleg01.L",0.065],["lowerleg01.R",0.065],["foot.L",0.05],["foot.R",0.05]]:
				var bone := boss_skeleton.find_bone(contact[0])
				if bone < 0: continue
				var at := boss_skeleton.to_global(boss_skeleton.get_bone_global_pose(bone).origin)
				lowest = minf(lowest,at.y - float(contact[1])*3.05)
			if lowest < INF: boss_visual.position.y = (0.025-lowest)*fall
		if defeat_elapsed >= 1.4: defeat_pose_settled = true
	update_defeated_player(delta)
	if defeat_elapsed < 4.4: return # Fall for 1.4 seconds, hold the final pose for 3 seconds.
	show_story([
		"보스|카드도, 추격도, 공격도, 부하들도... 전부 졌다.",
		"나|판돈은 돌려받았고, 이제 도망도 끝이야.",
		"딜러|신고를 받고 경찰이 도착했습니다. 함께 가시죠.",
		"보스|잠깐… 조커 한 장 때문에 여기까지 온 거야?"
	], "ending")


func update_defeated_player(delta: float) -> void:
	var movement := Input.get_vector("ui_left","ui_right","ui_up","ui_down")
	if Input.is_key_pressed(KEY_A): movement.x = -1
	if Input.is_key_pressed(KEY_D): movement.x = 1
	if Input.is_key_pressed(KEY_W): movement.y = -1
	if Input.is_key_pressed(KEY_S): movement.y = 1
	var direction := fps_player.global_basis * Vector3(movement.x,0,movement.y).normalized()
	fps_player.velocity.x = direction.x * SHOOTER_SPEED
	fps_player.velocity.z = direction.z * SHOOTER_SPEED
	if not fps_player.is_on_floor(): fps_player.velocity.y -= SHOOTER_GRAVITY*delta
	elif fps_player.velocity.y < 0: fps_player.velocity.y = 0
	fps_player.move_and_slide()
	fps_camera.position.y = move_toward(fps_camera.position.y,0.62,delta*5.5)
	fps_camera.rotation = Vector3(pitch,0,0)
	fps_camera.h_offset = 0
	fps_camera.v_offset = 0


func start_ending() -> void:
	rhythm_music.stop()
	ending_music.play()
	hide_combat_ui()
	phase = "ending"
	story_panel.visible = false
	ending_time = 0.0
	finish_button.visible = false
	finish_button.position = Vector2(615, 470)
	finish_button.text = "크레딧 건너뛰기 · 복도로"
	finish_button.add_theme_font_size_override("font_size", 16)
	credits_mask.visible = true
	credits_label.position.y = credits_mask.size.y
	credits_label.size.y = maxf(830, credits_label.get_minimum_size().y)
	roll_label.visible = false
	reload_hint.visible = false
	if is_instance_valid(viewport_texture): viewport_texture.visible = false
	title_label.text = "THE END"
	phase_label.text = "FINAL CLEAR"
	status_label.text = "판돈 회수 완료 · 도망자 체포"
	help_label.text = ""
	queue_redraw()


func hide_combat_ui() -> void:
	if is_instance_valid(boss_card_room): boss_card_room.stop_game()
	clear_burning_zones()
	blind_overlay.modulate.a = 0
	blind_timer = 0
	freeze_timer = 0
	for control in [boss_bar, health_label, ammo_label, reload_bar, reload_hint, roll_label]:
		control.visible = false
	damage_flash.color.a = 0.0
	damage_indicator.modulate.a = 0.0
	if is_instance_valid(viewport_texture): viewport_texture.visible = false


func update_ending(delta: float) -> void:
	var before := ending_time
	ending_time += delta
	if before < 2.8 and ending_time >= 2.8: Sfx.play("reload", -8, 0.95)
	credits_label.position.y = credits_mask.size.y - maxf(0.0, ending_time - 3.5) * 48.0
	finish_button.visible = ending_time > 6.0
	if credits_label.position.y + credits_label.size.y < 0:
		credits_label.position.y = -credits_label.size.y
		finish_button.text = "감사합니다 · 복도로"


func update_shooter_hud() -> void:
	boss_bar.value = maxi(0, boss_health)
	health_label.text = "HP  %d / 100" % maxi(0, fps_health)
	ammo_label.text = "재장전..." if reload_timer > 0.0 else "탄창 %d  |  예비 %d" % [ammo, reserve_ammo]


func skip_current_chapter() -> void:
	match phase:
		"story":
			story_panel.visible = false
			start_named_phase(next_phase)
		"card", "card_result":
			for button in card_buttons: button.visible = false
			start_chase_phase()
		"chase":
			show_story(["나|도망자를 따라잡았다. 이제 공격을 피하며 접근한다."], "rhythm")
		"rhythm":
			start_rogue_phase()
		"rogue":
			rogue_room_game.stop_boss_gauntlet()
			show_story(["나|부하들을 돌파했다. 이제 마지막 결투다."], "shooter")
		"shooter":
			defeat_final_boss()
		"defeated":
			update_boss_defeat(4.4)
		"ending":
			finish_room()


func _input(event: InputEvent) -> void:
	if not visible or get_tree().paused: return
	if event is InputEventMouseMotion and phase in ["shooter","defeated"] and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.2, 1.2)
		fps_player.rotation.y = yaw
		if roll_time_left <= 0.0: fps_camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if phase == "story": advance_story()
		elif phase == "shooter": shoot_boss()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F3:
			skip_current_chapter()
			get_viewport().set_input_as_handled()
		elif phase == "rhythm" and event.keycode in [KEY_Q,KEY_W,KEY_E]:
			rhythm_dodge([KEY_Q,KEY_W,KEY_E].find(event.keycode))
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			if phase == "story": advance_story()
			elif phase == "chase" and chase_on_floor:
				chase_velocity_y = -CHASE_JUMP_SPEED
				chase_on_floor = false
				spawn_chase_particles(chase_player_pos + Vector2(21, 46), Color("#dfd6bc"), 8)
				Sfx.play("jump", -6)
			elif phase in ["shooter","defeated"] and fps_player.is_on_floor() and not fps_is_crouching and freeze_timer <= 0.0: fps_player.velocity.y = 7.0
		elif event.keycode == KEY_R and phase == "shooter": begin_boss_reload()
		elif event.keycode == KEY_SHIFT and phase == "shooter":
			begin_roll()
			get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#080b18"))
	if phase in ["story", "card", "card_result"]:
		if phase == "story" and next_phase == "chase": draw_escape_scene()
		elif phase == "story" and next_phase == "rhythm": draw_confrontation_scene()
		elif phase == "story" and next_phase == "rhythm_play": draw_rhythm()
		else: draw_card_room()
	elif phase == "chase":
		draw_chase()
	elif phase == "rhythm":
		draw_rhythm()
	elif phase == "rogue":
		draw_rogue()
	elif phase == "ending":
		draw_ending()


func draw_card_room() -> void:
	draw_texture_rect(CARD_LOUNGE_ART, Rect2(0, 0, 960, 540), false)
	draw_rect(Rect2(0, 0, 960, 95), Color("#0c111ab0"))
	var frame_width := float(CLUB_LEADER_IDLE_TEXTURE.get_width()) / 4.0
	var frame := int(Time.get_ticks_msec() * 0.0032) % 4
	# Only the seated opponent's upper body is visible behind the rail.
	draw_texture_rect_region(CLUB_LEADER_IDLE_TEXTURE, Rect2(420, 98, 120, 100), Rect2(frame_width * frame, 0, frame_width, CLUB_LEADER_IDLE_TEXTURE.get_height() * 0.54))
	for i in boss_card_pairs.size():
		var at := Vector2(265 + i * 72, 365)
		draw_style_box(card_pair_style(), Rect2(at, Vector2(58, 38)))
		draw_string(ThemeDB.fallback_font, at + Vector2(9, 26), boss_card_pairs[i] + " ×2", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#243431"))


func card_pair_style() -> StyleBoxFlat:
	if card_pair_panel == null:
		card_pair_panel = StyleBoxFlat.new()
		card_pair_panel.bg_color = Color("#e8e1ca")
		card_pair_panel.set_corner_radius_all(4)
	return card_pair_panel


func draw_escape_scene() -> void:
	# 카드 승부가 끝난 뒤에는 도박장이 아니라 건물 밖 추격로를 보여준다.
	draw_texture_rect(EXIT_ART, Rect2(0, 0, 960, 540), false)
	draw_rect(Rect2(0, 0, 960, 95), Color("#0c111a80"))
	draw_story_hero(Vector2(230, 375))
	draw_animated_boss(Vector2(760, 385), 0.65, true)


func draw_chase() -> void:
	# Shared hand-authored art, with a slower distant layer for depth.
	var offset := fposmod(chase_camera_x * 0.28, 960.0)
	for i in 2:
		draw_texture_rect(GARDEN_TEXTURE, Rect2(float(i) * 960.0 - offset, -70, 960, 540), false, Color("#d0d5cc"))
	for surface in chase_surfaces:
		var screen_rect := Rect2(surface.position - Vector2(chase_camera_x, 0), surface.size)
		if screen_rect.end.x >= 0 and screen_rect.position.x <= 960:
			draw_rect(Rect2(screen_rect.position + Vector2(3, 5), screen_rect.size), Color("#14251a55"))
			for row in range(0, int(surface.size.y), 48):
				for column in range(0, int(surface.size.x), 128):
					var tile_size := Vector2(minf(128, surface.size.x - column), minf(48, surface.size.y - row))
					draw_texture_rect_region(LEDGE_TEXTURE, Rect2(screen_rect.position + Vector2(column, row), tile_size), Rect2(Vector2.ZERO, tile_size))
	for hazard in chase_hazards:
		var start := hazard.position - Vector2(chase_camera_x, 0)
		for spike_x in range(0, int(hazard.size.x), 20):
			draw_colored_polygon(PackedVector2Array([start + Vector2(spike_x, 25), start + Vector2(spike_x + 10, 0), start + Vector2(spike_x + 20, 25)]), Color("#e2e8f0"))
	var blink := chase_invincible > 0.0 and int(chase_invincible * 12) % 2 == 0
	if not blink:
		var player_screen := chase_player_pos - Vector2(chase_camera_x, 0)
		var frame_width := float(HERO_TEXTURE.get_width()) / 4.0
		var walking := absf(Input.get_axis("ui_left", "ui_right")) > 0.0 or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_D)
		var frame := int(chase_time * 9.0) % 4 if walking and chase_on_floor else 0
		var lean := chase_last_direction * 0.05 if not chase_on_floor else 0.0
		draw_set_transform(player_screen + Vector2(21, 46), lean, Vector2(chase_last_direction, 1))
		draw_texture_rect_region(HERO_TEXTURE, Rect2(-26, -55, 52, 58), Rect2(frame_width * frame, 0, frame_width, HERO_TEXTURE.get_height()))
		draw_set_transform(Vector2.ZERO)
	for enemy in chase_enemies:
		var enemy_screen: Vector2 = enemy.pos - Vector2(chase_camera_x, 0)
		var squash := sin(chase_time * 7.0 + enemy.pos.x * 0.03) * 2.0
		draw_texture_rect(SLIME_TEXTURE, Rect2(enemy_screen + Vector2(-27, -39 + squash), Vector2(54, 43 - squash)), false)
	for particle in chase_particles:
		draw_circle(particle.pos - Vector2(chase_camera_x, 0), 2, Color(particle.color, float(particle.life) / 0.45))
	var boss_screen := Vector2(2700.0 - chase_camera_x, 352)
	if boss_screen.x < 1040:
		draw_animated_boss(boss_screen, 0.68, not chase_reached_boss)
		draw_string(ThemeDB.fallback_font, boss_screen + Vector2(-95, -105), "여기까지 올 수 있겠어?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func draw_confrontation_scene() -> void:
	draw_texture_rect(EXIT_ART, Rect2(-180, -45, 1140, 640), false, Color("#a7a7a4"))
	draw_rect(Rect2(0, 0, 960, 95), Color("#0c111a90"))
	draw_story_hero(Vector2(230, 345))
	draw_animated_boss(Vector2(730, 345), 0.9)
	draw_line(Vector2(315, 390), Vector2(640, 390), Color("#fbbf2466"), 3)


func draw_story_hero(at: Vector2) -> void:
	var width := float(HERO_TEXTURE.get_width()) / 4.0
	draw_texture_rect_region(HERO_TEXTURE, Rect2(at - Vector2(35, 45), Vector2(70, 94)), Rect2(0, 0, width, HERO_TEXTURE.get_height()))


func draw_rhythm() -> void:
	draw_texture_rect(GARDEN_TEXTURE, Rect2(0, 0, 960, 540), false, Color("#535b69"))
	draw_rect(Rect2(0, 95, 960, 445), Color("#101725c0"))
	if rhythm_impact > 0.0:
		draw_rect(Rect2(0,95,960,445), Color(0.9,0.82,0.5,rhythm_impact * 0.09))
		draw_arc(Vector2(165,300), 22 + (1.0-rhythm_impact)*55, 0,TAU,64,Color(1.0,0.9,0.65,rhythm_impact),3,true)
	var pulse := pow(1.0 - fposmod(rhythm_time, BOSS_BEAT) / BOSS_BEAT, 3.0)
	draw_rect(Rect2(0,510,960,4 + pulse * 8),Color(0.92,0.73,0.36,0.15 + pulse * 0.45))
	for beat in 4:
		var active := int(floor(rhythm_time / BOSS_BEAT)) % 4 == beat
		draw_circle(Vector2(438 + beat * 28,480),5 + (pulse * 4 if active else 0.0),Color("#ffe3a3") if active else Color("#55505b"))
	for i in 4:
		draw_arc(Vector2(165, 300), 30 + float(i) * 16 + pulse * 8, 0, TAU, 64, Color(0.85, 0.73, 0.47, (0.22 - i * 0.04) * (0.5 + pulse)), 2, true)
	draw_circle(Vector2(165,300),27,Color(0.08,0.12,0.19,0.8))
	draw_arc(Vector2(165,300),27,0,TAU,64,Color("#ffe3a3"),4,true)
	draw_arc(Vector2(165,300),33 + pulse * 4,0,TAU,64,Color(1,0.86,0.55,0.3 + pulse*0.4),2,true)
	var hero_width := float(HERO_TEXTURE.get_width()) / 4.0
	var dodge := sin(clampf(rhythm_feedback_left / 0.5, 0, 1) * PI) * 12.0 if rhythm_feedback.begins_with("PERFECT") or rhythm_feedback.begins_with("GOOD") else 0.0
	draw_texture_rect_region(HERO_TEXTURE, Rect2(83, 277 - dodge, 48, 64), Rect2(0, 0, hero_width, HERO_TEXTURE.get_height()))
	draw_animated_boss(Vector2(835, 300), 0.7)
	for attack in rhythm_attacks:
		if attack.resolved: continue
		var color: Color = [Color("#fb7185"), Color("#67e8f9"), Color("#facc15")][int(attack.type)]
		var direction := (Vector2(850,float(attack.origin_y)) - Vector2(165,300)).normalized()
		for i in 6:
			draw_circle(Vector2(float(attack.x),float(attack.y)) + direction * i * 7, 10.0 - float(i), Color(color, 0.18 - i * 0.025))
		var at := Vector2(float(attack.x), float(attack.y))
		draw_string(ThemeDB.fallback_font,at+Vector2(-7,-35),["Q","W","E"][int(attack.type)],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		draw_circle(at, 25, Color(color, 0.28))
		if int(attack.type) == 0:
			var frame := int(rhythm_time * 20.0) % 16
			draw_texture_rect_region(RHYTHM_FIRE_ART, Rect2(at - Vector2(29, 29), Vector2(58, 58)), Rect2((frame % 4) * 128, floori(frame / 4.0) * 128, 128, 128))
		else:
			var texture := RHYTHM_ICE_ART if int(attack.type) == 1 else RHYTHM_LIGHTNING_ART
			var wobble := sin(rhythm_time * 9.0 + float(attack.time)) * 3.0
			draw_texture_rect(texture, Rect2(at - Vector2(27, 31 + wobble), Vector2(54, 62 + wobble * 2)), false)
	for particle in chase_particles:
		draw_circle(particle.pos, 2, Color(particle.color, float(particle.life) / 0.45))
	if rhythm_miss_flash > 0.0:
		draw_rect(Rect2(0,95,960,445),Color(0.9,0.03,0.04,rhythm_miss_flash * 0.22))
		draw_arc(Vector2(165,300),30 + (1.0-rhythm_miss_flash)*85,0,TAU,64,Color(1,0.2,0.2,rhythm_miss_flash),6,true)
		draw_string(ThemeDB.fallback_font,Vector2(370 + sin(rhythm_time * 100)*rhythm_jolt*9,225),"MISS · COMBO BREAK",HORIZONTAL_ALIGNMENT_LEFT,-1,32,Color("#ff7777"))
	for hp_index in 5:
		draw_circle(Vector2(115 + hp_index * 23,410),7,Color("#ff9a91") if hp_index < rhythm_hp else Color("#42343b"))
	if rhythm_feedback_left > 0 and (rhythm_feedback.begins_with("PERFECT") or rhythm_feedback.begins_with("GOOD")):
		draw_string(ThemeDB.fallback_font, Vector2(315, 225), rhythm_feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 28 + int(rhythm_impact * 4), Color("#ffe3a3"))
	draw_string(ThemeDB.fallback_font, Vector2(255, 445), "불 Q   ·   얼음 W   ·   번개 E", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#d5cebc"))


func draw_rogue() -> void:
	draw_rect(Rect2(0, 95, 960, 445), Color("#10211e"))
	for x in range(0, 961, 48): draw_line(Vector2(x, 95), Vector2(x, 540), Color("#164e3b"), 1)
	for y in range(95, 541, 48): draw_line(Vector2(0, y), Vector2(960, y), Color("#164e3b"), 1)
	draw_circle(rogue_player, 19, Color("#60a5fa"))
	draw_circle(rogue_player + Vector2(0, -18), 11, Color("#f1c7a5"))
	for enemy in rogue_enemies:
		draw_circle(enemy.pos, 18, Color("#a855f7"))
		draw_rect(Rect2(enemy.pos + Vector2(-9, -5), Vector2(18, 18)), Color("#581c87"))
	for projectile in rogue_projectiles:
		draw_circle(projectile.pos, 5 + int(skill_levels.fire), Color("#fb7185"))
	if int(skill_levels.ice) > 0: draw_arc(rogue_player, 34, 0, TAU, 32, Color("#67e8f9"), 2)


func draw_ending() -> void:
	draw_texture_rect(PRISON_ART, Rect2(0,0,960,540), false)
	var arrival := smoothstep(0.0,1.3,ending_time)
	draw_animated_boss(Vector2(lerpf(-80,280,arrival),356),1.05,ending_time<1.3)
	var closing := smoothstep(1.3,2.8,ending_time)
	draw_texture_rect(PRISON_GATE,Rect2(lerpf(-435,65,closing),95,430,355),false)
	draw_rect(Rect2(0,0,960,95),Color("#0b1017bb"))
	draw_string(ThemeDB.fallback_font,Vector2(95,490),"이상민, 결국 감옥으로…",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#e8dbc2"))


func draw_animated_boss(pos: Vector2, scale_value: float, running := false) -> void:
	var texture := CLUB_LEADER_RUN_TEXTURE if running else CLUB_LEADER_IDLE_TEXTURE
	var speed := 8.5 if running else 3.2
	var animation_time := Time.get_ticks_msec() * 0.001
	var frame := int(animation_time * speed) % 4
	var frame_width := float(texture.get_width()) / 4.0
	var boss_size := Vector2(150, 225) * scale_value
	var bob := sin(animation_time * (11.0 if running else 2.0)) * (3.0 if running else 1.8) * scale_value
	var lean := -0.045 if running else sin(animation_time * 1.25) * 0.012
	draw_set_transform(pos + Vector2(0, bob), lean, Vector2.ONE)
	draw_texture_rect_region(texture, Rect2(Vector2(-75, -145) * scale_value, boss_size), Rect2(frame_width * frame, 0, frame_width, texture.get_height()))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func create_3d_box(pos: Vector3, box_size: Vector3, color: Color, collision_enabled: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	world_3d.add_child(root)
	var surface := make_mesh_box(box_size, color)
	if collision_enabled:
		var stone := make_material(color)
		stone.albedo_texture = CONCRETE_DETAIL
		stone.uv1_triplanar = true
		stone.uv1_scale = Vector3(0.4, 0.4, 0.4)
		stone.roughness = 0.92
		surface.material_override = stone
	root.add_child(surface)
	if collision_enabled:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box_size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	return root


func make_mesh_box(box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = make_material(color)
	mesh_instance.mesh = mesh
	return mesh_instance


func make_mesh_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	mesh.material = make_material(color)
	mesh_instance.mesh = mesh
	return mesh_instance


func make_mesh_capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 24
	mesh.rings = 8
	mesh.material = make_material(color)
	mesh_instance.mesh = mesh
	return mesh_instance


func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func make_metal_material(color: Color, metalness: float = 0.75) -> StandardMaterial3D:
	var material := make_material(color)
	material.metallic = metalness
	material.roughness = 0.28
	return material


func make_glow_material(color: Color, energy: float = 2.5) -> StandardMaterial3D:
	var material := make_material(color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = energy
	return material


func make_spell_disc(pos: Vector3, color: Color, radius: float) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	world_3d.add_child(root)
	var fill := MeshInstance3D.new()
	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = radius
	fill_mesh.bottom_radius = radius
	fill_mesh.height = 0.025
	fill_mesh.material = make_glow_material(Color(color, 0.13), 1.8)
	fill.mesh = fill_mesh
	root.add_child(fill)
	for ring_scale in [1.0, 0.74, 0.46]:
		root.add_child(make_magic_circle_line(radius * ring_scale, color, 64))
	for i in 12:
		var rune := make_mesh_box(Vector3(radius * 0.28, 0.035, 0.08), Color(color, 0.9))
		rune.material_override = make_glow_material(Color(color, 0.9), 4.5)
		rune.position = Vector3(cos(TAU * i / 12.0) * radius * 0.72, 0.045, sin(TAU * i / 12.0) * radius * 0.72)
		rune.rotation.y = -TAU * i / 12.0
		root.add_child(rune)
	var light := OmniLight3D.new()
	light.position.y = 0.8
	light.light_color = color
	light.light_energy = 3.2
	light.omni_range = maxf(4.0, radius * 1.7)
	root.add_child(light)
	root.scale = Vector3(0.12, 1.0, 0.12)
	var pulse := root.create_tween().set_loops()
	pulse.tween_property(root, "scale", Vector3(1.04, 1.0, 1.04), 0.13).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(root, "scale", Vector3(0.94, 1.0, 0.94), 0.13).set_trans(Tween.TRANS_SINE)
	var spin := root.create_tween().set_loops()
	spin.tween_property(root, "rotation:y", TAU, 1.8)
	spin.tween_callback(func() -> void: root.rotation.y = 0.0)
	return root


func make_magic_circle_line(radius: float, color: Color, segments: int) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, make_glow_material(Color(color, 0.98), 6.0))
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var b := TAU * float(i + 1) / float(segments)
		mesh.surface_add_vertex(Vector3(cos(a) * radius, 0.055, sin(a) * radius))
		mesh.surface_add_vertex(Vector3(cos(b) * radius, 0.055, sin(b) * radius))
	mesh.surface_end()
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node


func make_spell_lane(target_x: float, color: Color) -> Node3D:
	var lane := Node3D.new()
	lane.position = Vector3(target_x, 0.08, -3)
	var glow := make_mesh_box(Vector3(1.8, 0.025, 28.0), Color(color, 0.16))
	glow.material_override = make_glow_material(Color(color, 0.16), 2.0)
	lane.add_child(glow)
	for side in [-0.9, 0.9]:
		var border := make_mesh_box(Vector3(0.09, 0.075, 28.0), Color(color, 0.98))
		border.material_override = make_glow_material(Color(color, 0.98), 7.0)
		border.position = Vector3(side, 0.05, 0)
		lane.add_child(border)
	for z in range(-13, 14, 2):
		var chevron := make_mesh_box(Vector3(1.55, 0.045, 0.08), Color("#fff7aecc"))
		chevron.material_override = make_glow_material(Color("#fff7aecc"), 5.5)
		chevron.position = Vector3(0, 0.06, z)
		chevron.rotation.y = 0.34 if z % 4 == 0 else -0.34
		lane.add_child(chevron)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.0, 0)
	light.light_color = color
	light.light_energy = 4.2
	light.omni_range = 8.0
	lane.add_child(light)
	world_3d.add_child(lane)
	lane.scale.x = 0.08
	var pulse := lane.create_tween().set_loops()
	pulse.tween_property(lane, "scale:x", 1.12, 0.10)
	pulse.tween_property(lane, "scale:x", 0.92, 0.10)
	return lane


func make_charge_lane(start: Vector3, target: Vector3, color: Color, width: float) -> Node3D:
	var lane := Node3D.new()
	var flat_start := Vector3(start.x, 0.085, start.z)
	var flat_target := Vector3(target.x, 0.085, target.z)
	var length := flat_start.distance_to(flat_target)
	lane.position = (flat_start + flat_target) * 0.5
	world_3d.add_child(lane)
	lane.look_at(flat_target, Vector3.UP)
	var glow := make_mesh_box(Vector3(width, 0.025, length), Color(color, 0.13))
	glow.material_override = make_glow_material(Color(color, 0.13), 2.5)
	lane.add_child(glow)
	for side in [-width * 0.5, width * 0.5]:
		var border := make_mesh_box(Vector3(0.085, 0.07, length), Color(color, 0.95))
		border.material_override = make_glow_material(Color(color, 0.95), 7.0)
		border.position.x = side
		lane.add_child(border)
	for marker_index in 8:
		var marker := make_mesh_box(Vector3(width * 0.72, 0.055, 0.10), Color("#ffd1c7dd"))
		marker.material_override = make_glow_material(Color("#ffd1c7dd"), 5.0)
		marker.position.z = -length * 0.5 + (float(marker_index) + 0.5) * length / 8.0
		marker.rotation.y = -0.42 if marker_index % 2 == 0 else 0.42
		lane.add_child(marker)
	lane.scale.x = 0.06
	var reveal := lane.create_tween().set_loops()
	reveal.tween_property(lane, "scale:x", 1.04, 0.13).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	reveal.tween_property(lane, "scale:x", 0.92, 0.12)
	return lane


func spawn_spell_impact(kind: String, pos: Vector3, start: Vector3 = Vector3.ZERO) -> void:
	var color := Color("#fb3f2f") if kind == "fire" else Color("#67e8f9") if kind == "ice" else Color("#ef4444") if kind == "charge" else Color("#fde047")
	camera_shake = 0.32 if kind == "fire" else 0.42 if kind == "lightning" else 0.48 if kind == "charge" else 0.32
	if kind == "lightning":
		spawn_lightning_barrage(start, pos, color)
	elif kind == "fire":
		spawn_fire_vortex(pos, color)
	elif kind == "ice":
		spawn_ice_eruption(pos, color)
	else:
		spawn_charge_impact(pos, color)


func spawn_fire_vortex(pos: Vector3, color: Color) -> void:
	var impact := Node3D.new()
	impact.position = pos
	world_3d.add_child(impact)
	# 낡은 불꽃 그림 대신 서로 다른 속도로 회전하는 실제 3D 불꽃 나선.
	for i in 4:
		var spiral := make_fire_spiral(0.75 + i * 0.30, 4.2 + i * 0.55, 1.7 + i * 0.22, 0.24 + i * 0.035, Color(1.0, 0.16 + i * 0.08, 0.015, 0.58))
		spiral.rotation.y = TAU * float(i) / 4.0
		spiral.scale = Vector3(0.12, 0.08, 0.12)
		impact.add_child(spiral)
		var spiral_tween := spiral.create_tween().set_parallel(true)
		spiral_tween.tween_property(spiral, "scale", Vector3.ONE, 0.30 + i * 0.025).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		spiral_tween.tween_property(spiral, "rotation:y", spiral.rotation.y + TAU * (1.2 + i * 0.18), 1.15).set_trans(Tween.TRANS_QUAD)
		spiral_tween.tween_property(spiral, "transparency", 1.0, 0.50).set_delay(0.72)
	for ring_radius in [0.9, 1.7, 2.5]:
		var heat_ring := make_magic_circle_line(ring_radius, Color("#ff8a2add"), 72)
		heat_ring.scale = Vector3(0.12, 1.0, 0.12)
		impact.add_child(heat_ring)
		var ring_tween := heat_ring.create_tween().set_parallel(true)
		ring_tween.tween_property(heat_ring, "scale", Vector3(1.35, 1.0, 1.35), 0.46).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ring_tween.tween_property(heat_ring, "transparency", 1.0, 0.55).set_delay(0.24)
	spawn_fire_volume_particles(impact, 360, 2.65)
	spawn_vfx_particles(impact, Color("#ffd36a"), 170, 4.8)
	add_impact_light(impact, color, 11.0, 10.0, 0.62)
	get_tree().create_timer(1.95, false).timeout.connect(impact.queue_free)


func spawn_ice_eruption(pos: Vector3, color: Color) -> void:
	var impact := Node3D.new()
	impact.position = pos
	world_3d.add_child(impact)
	for ring_radius in [2.7, 5.3, 7.8]:
		var ring := make_magic_circle_line(ring_radius, Color("#b9f6ffcc"), 80)
		ring.scale = Vector3(0.08, 1.0, 0.08)
		impact.add_child(ring)
		var ring_spread := ring.create_tween().set_parallel(true)
		ring_spread.tween_property(ring, "scale", Vector3.ONE, 0.34 + ring_radius * 0.025).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		ring_spread.tween_property(ring, "transparency", 1.0, 0.72).set_delay(0.42)
	# 납작한 빙결 그림 대신 실제 육각뿔 메시를 범위 전체에 분산한다.
	for i in 38:
		var angle := TAU * float(i) / 38.0 + randf_range(-0.16, 0.16)
		var radial_distance := sqrt(randf()) * 7.8
		var spike_height := randf_range(2.0, 6.3) * (1.18 - radial_distance / 14.5)
		var spike := make_ice_spike(spike_height, randf_range(0.20, 0.52))
		spike.position = Vector3(cos(angle) * radial_distance, spike_height * 0.5, sin(angle) * radial_distance)
		spike.rotation.y = randf_range(0.0, TAU)
		spike.rotation.z = randf_range(-0.16, 0.16)
		spike.scale = Vector3(0.12, 0.02, 0.12)
		impact.add_child(spike)
		var erupt := spike.create_tween().set_parallel(true)
		erupt.tween_property(spike, "scale", Vector3.ONE, 0.22).set_delay(float(i) * 0.014).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		erupt.tween_property(spike, "position:y", spike_height * 0.5, 0.22).set_delay(float(i) * 0.014)
	spawn_vfx_particles(impact, Color("#d9fbff"), 260, 9.0)
	add_impact_light(impact, color, 17.0, 19.0, 0.92)
	get_tree().create_timer(2.35, false).timeout.connect(impact.queue_free)


func spawn_charge_impact(pos: Vector3, color: Color) -> void:
	var impact := Node3D.new()
	impact.position = pos
	world_3d.add_child(impact)
	for ring_radius in [0.8, 1.45, 2.2]:
		var ring := make_magic_circle_line(ring_radius, Color(color, 0.88), 48)
		ring.scale = Vector3(0.08, 1.0, 0.08)
		impact.add_child(ring)
		var shock := ring.create_tween().set_parallel(true)
		shock.tween_property(ring, "scale", Vector3(1.7, 1.0, 1.7), 0.28).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		shock.tween_property(ring, "transparency", 1.0, 0.34).set_delay(0.08)
	spawn_vfx_particles(impact, Color("#ffb09f"), 190, 3.4)
	add_impact_light(impact, color, 14.0, 9.0, 0.34)
	get_tree().create_timer(0.85, false).timeout.connect(impact.queue_free)


func perform_boss_charge(start: Vector3, target: Vector3) -> void:
	if phase != "shooter" or not is_instance_valid(boss_body): return
	boss_casting = true
	boss_body.position = start
	boss_body.look_at(Vector3(target.x, start.y, target.z), Vector3.UP, true)
	if is_instance_valid(boss_visual):
		boss_visual.rotation_degrees.x = -18.0
		boss_left_arm.rotation_degrees = Vector3(38, 0, 52)
		boss_right_arm.rotation_degrees = Vector3(38, 0, -52)
	if boss_dash_tween != null and boss_dash_tween.is_valid(): boss_dash_tween.kill()
	boss_dash_tween = boss_body.create_tween()
	boss_dash_tween.tween_property(boss_body, "position", target, 0.20).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	boss_dash_tween.tween_callback(func() -> void:
		if phase != "shooter": return
		camera_shake = 0.62
		if is_instance_valid(boss_visual):
			boss_recover_tween = boss_visual.create_tween()
			boss_recover_tween.tween_property(boss_visual, "rotation_degrees:x", 0.0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	)


func distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001: return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func spawn_lightning_barrage(start: Vector3, target: Vector3, color: Color) -> void:
	var barrage := Node3D.new()
	var flat_start := Vector3(start.x, 0.08, start.z)
	var flat_target := Vector3(target.x, 0.08, target.z)
	var lane_length := maxf(2.0, flat_start.distance_to(flat_target))
	barrage.position = (flat_start + flat_target) * 0.5
	world_3d.add_child(barrage)
	barrage.look_at(flat_target, Vector3.UP)
	var bolt_count := maxi(3, ceili(lane_length / 2.0))
	for bolt_index in bolt_count:
		var bolt_root := Node3D.new()
		var lane_progress := (float(bolt_index) + 0.5) / float(bolt_count)
		bolt_root.position = Vector3(randf_range(-0.48, 0.48), 0, -lane_length * 0.5 + lane_progress * lane_length)
		barrage.add_child(bolt_root)
		var delay := randf_range(0.0, 0.10)
		for flash_index in 3:
			var bolt := make_procedural_lightning(8.5, 0.9, 12)
			bolt.position = Vector3(randf_range(-0.18, 0.18), 0.05, randf_range(-0.10, 0.10))
			bolt.scale = Vector3(1.0, 0.72, 1.0)
			bolt.transparency = 1.0
			bolt_root.add_child(bolt)
			var flicker := bolt.create_tween()
			flicker.tween_interval(delay + flash_index * 0.075)
			flicker.tween_property(bolt, "transparency", 0.0, 0.012)
			flicker.tween_property(bolt, "scale:y", 1.0, 0.035).set_trans(Tween.TRANS_EXPO)
			flicker.tween_property(bolt, "transparency", 1.0, 0.055)
	var flash := OmniLight3D.new()
	flash.position = Vector3(0, 2.2, 0)
	flash.light_color = color
	flash.light_energy = 2.0
	flash.omni_range = 18.0
	barrage.add_child(flash)
	spawn_vfx_particles(barrage, color, 150, 7.0)
	var flash_tween := flash.create_tween()
	flash_tween.tween_property(flash, "light_energy", 15.0, 0.025)
	flash_tween.tween_property(flash, "light_energy", 2.0, 0.055)
	flash_tween.tween_property(flash, "light_energy", 11.0, 0.025)
	flash_tween.tween_property(flash, "light_energy", 0.0, 0.22)
	get_tree().create_timer(0.92, false).timeout.connect(barrage.queue_free)


func make_fire_spiral(radius: float, height: float, turns: float, width: float, color: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	var material := make_glow_material(color, 7.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	var segments := 42
	for i in segments:
		var progress_a := float(i) / float(segments)
		var progress_b := float(i + 1) / float(segments)
		var angle_a := progress_a * TAU * turns
		var angle_b := progress_b * TAU * turns
		var taper_a := 1.0 - progress_a * 0.64
		var taper_b := 1.0 - progress_b * 0.64
		var inner_a := maxf(0.03, radius * taper_a - width)
		var outer_a := radius * taper_a + width
		var inner_b := maxf(0.03, radius * taper_b - width)
		var outer_b := radius * taper_b + width
		var a_inner := Vector3(cos(angle_a) * inner_a, progress_a * height, sin(angle_a) * inner_a)
		var a_outer := Vector3(cos(angle_a) * outer_a, progress_a * height, sin(angle_a) * outer_a)
		var b_inner := Vector3(cos(angle_b) * inner_b, progress_b * height, sin(angle_b) * inner_b)
		var b_outer := Vector3(cos(angle_b) * outer_b, progress_b * height, sin(angle_b) * outer_b)
		mesh.surface_add_vertex(a_inner)
		mesh.surface_add_vertex(a_outer)
		mesh.surface_add_vertex(b_outer)
		mesh.surface_add_vertex(a_inner)
		mesh.surface_add_vertex(b_outer)
		mesh.surface_add_vertex(b_inner)
	mesh.surface_end()
	var spiral := MeshInstance3D.new()
	spiral.mesh = mesh
	return spiral


func make_flipbook_vfx(sheets: Array, world_width: float, fps: float, billboard_enabled: bool) -> AnimatedSprite3D:
	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", fps)
	for sheet_texture in sheets:
		for frame_index in 16:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet_texture
			atlas.region = Rect2((frame_index % 4) * 128, floori(float(frame_index) / 4.0) * 128, 128, 128)
			atlas.filter_clip = true
			frames.add_frame("default", atlas)
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.pixel_size = world_width / 128.0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED if billboard_enabled else BaseMaterial3D.BILLBOARD_DISABLED
	sprite.no_depth_test = false
	sprite.shaded = false
	# 반투명한 검은 픽셀과 아틀라스 경계가 사각형으로 드러나지 않게 자른다.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.08
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.play("default")
	return sprite


func make_ice_spike(height: float, radius: float) -> MeshInstance3D:
	var spike := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.material = make_glow_material(Color(0.50, 0.86, 1.0, 0.82), 3.2)
	spike.mesh = mesh
	return spike


func make_procedural_lightning(height: float, jitter: float, segments: int) -> MeshInstance3D:
	var points: Array[Vector2] = []
	for i in segments + 1:
		var progress := float(i) / float(segments)
		var edge_fade := sin(progress * PI)
		points.append(Vector2(randf_range(-jitter, jitter) * edge_fade, height * (1.0 - progress)))
	var mesh := ImmediateMesh.new()
	var material := make_glow_material(Color("#fffce0"), 10.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	add_lightning_ribbon(mesh, points, 0.10)
	# 굵은 본체에서 갈라지는 짧은 가지가 매번 다른 실루엣을 만든다.
	for branch_index in [3, 6, 8]:
		if branch_index >= points.size() - 1: continue
		var branch_start: Vector2 = points[branch_index]
		var branch_points: Array[Vector2] = [branch_start]
		for j in 4:
			branch_points.append(branch_start + Vector2((j + 1) * randf_range(-0.42, 0.42), -(j + 1) * 0.28))
		add_lightning_ribbon(mesh, branch_points, 0.045)
	mesh.surface_end()
	var bolt := MeshInstance3D.new()
	bolt.mesh = mesh
	return bolt


func add_lightning_ribbon(mesh: ImmediateMesh, points: Array[Vector2], half_width: float) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var direction := (b - a).normalized()
		var normal := Vector2(-direction.y, direction.x) * half_width
		mesh.surface_add_vertex(Vector3(a.x + normal.x, a.y + normal.y, 0))
		mesh.surface_add_vertex(Vector3(a.x - normal.x, a.y - normal.y, 0))
		mesh.surface_add_vertex(Vector3(b.x + normal.x, b.y + normal.y, 0))
		mesh.surface_add_vertex(Vector3(b.x + normal.x, b.y + normal.y, 0))
		mesh.surface_add_vertex(Vector3(a.x - normal.x, a.y - normal.y, 0))
		mesh.surface_add_vertex(Vector3(b.x - normal.x, b.y - normal.y, 0))


func add_impact_light(parent: Node3D, color: Color, energy: float, light_range: float, fade_time: float) -> void:
	var light := OmniLight3D.new()
	light.position.y = 1.4
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	parent.add_child(light)
	light.create_tween().tween_property(light, "light_energy", 0.0, fade_time).set_trans(Tween.TRANS_EXPO)


func make_soft_particle_texture(inner_color: Color, edge_color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.22, 0.62, 1.0])
	gradient.colors = PackedColorArray([
		inner_color,
		Color(inner_color.r, inner_color.g, inner_color.b, inner_color.a * 0.95),
		Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.48),
		Color(edge_color.r, edge_color.g, edge_color.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	return texture


func make_soft_particle_material(color: Color, energy: float) -> StandardMaterial3D:
	var cache_key := color.to_html() + ":" + str(energy)
	if vfx_material_cache.has(cache_key): return vfx_material_cache[cache_key]
	var texture := make_soft_particle_texture(Color(1.0, 1.0, 1.0, color.a), Color(color.r, color.g, color.b, color.a))
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.albedo_texture = texture
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = energy
	material.emission_texture = texture
	vfx_material_cache[cache_key] = material
	return material


func spawn_fire_volume_particles(parent: Node3D, amount: int, radius: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 1.35
	particles.one_shot = true
	particles.explosiveness = 0.18
	particles.randomness = 0.82
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = radius
	process.emission_ring_inner_radius = 0.15
	process.emission_ring_height = 0.35
	process.direction = Vector3(0, 1, 0)
	process.spread = 34.0
	process.initial_velocity_min = 1.8
	process.initial_velocity_max = 5.4
	process.gravity = Vector3(0, 1.2, 0)
	process.scale_min = 0.32
	process.scale_max = 1.15
	var lifetime_gradient := Gradient.new()
	lifetime_gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.58, 1.0])
	lifetime_gradient.colors = PackedColorArray([
		Color(1.0, 0.92, 0.54, 0.0),
		Color(1.0, 0.78, 0.22, 1.0),
		Color(1.0, 0.20, 0.035, 0.72),
		Color(0.22, 0.015, 0.01, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = lifetime_gradient
	process.color_ramp = color_ramp
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.82, 1.12)
	quad.material = make_soft_particle_material(Color(1.0, 0.40, 0.06, 0.92), 7.5)
	particles.draw_pass_1 = quad
	parent.add_child(particles)
	particles.emitting = true


func spawn_vfx_particles(parent: Node3D, color: Color, amount: int, radius: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 0.92
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = radius * 0.28
	process.direction = Vector3(0, 1, 0)
	process.spread = 78.0
	process.initial_velocity_min = radius * 0.8
	process.initial_velocity_max = radius * 2.0
	process.gravity = Vector3(0, -5.5, 0)
	process.scale_min = 0.08
	process.scale_max = 0.24
	process.color = color
	particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.30)
	quad.material = make_soft_particle_material(color, 6.0)
	particles.draw_pass_1 = quad
	parent.add_child(particles)
	particles.emitting = true


func make_label(pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func finish_room() -> void:
	ending_music.stop()
	visible = false
	finish_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_won.emit()
