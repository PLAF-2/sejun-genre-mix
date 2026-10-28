extends Control

signal game_won

const GAME_DURATION := 50.0
const ENEMY_COUNT := 8
const MAGAZINE_SIZE := 30
const RELOAD_TIME := 1.45
const PLAYER_SPEED := 6.2
const MOUSE_SENSITIVITY := 0.0022
const GRAVITY := 18.0
const JUMP_SPEED := 7.0
const ROBOT_ARMOR_TEXTURE := preload("res://assets/characters/enemy_robot_armor_texture.png")
const GUN_EFFECTS := preload("res://scripts/gun_effects.gd")
const CONCRETE_DETAIL := preload("res://assets/platform/concrete_detail.tres")
const LAN_PORT := 7005
const HUMAN_SPAWN_KILLS := ENEMY_COUNT
const HOST_DUEL_SPAWN := Vector3(0, 1.05, 8)
const ENEMY_DUEL_SPAWN := Vector3(0, 1.05, -12)

var game_viewport: SubViewport
var world_3d: Node3D
var player: CharacterBody3D
var player_collision: CollisionShape3D
var player_capsule: CapsuleShape3D
var camera: Camera3D
var gun: Node3D
var fists: Node3D
var knife: Node3D
var weapon_slot := 2
var attack_timer := 0.0
var reload_motion: Tween
var weapon_label: Label
var muzzle_flash: OmniLight3D
var muzzle_mesh: MeshInstance3D
var targets: Array[Dictionary] = []
var state := "idle"
var elapsed := 0.0
var health := 100
var ammo := MAGAZINE_SIZE
var reserve_ammo := 24
var reload_timer := 0.0
var enemy_left := ENEMY_COUNT
var score := 0
var yaw := 0.0
var pitch := 0.0
var shot_kick := 0.0
var is_crouching := false
var role := "solo"
var ai_kills := 0
var remote_peer_id := 0
var remote_enemy_active := false
var remote_enemy: CharacterBody3D
var remote_host_avatar: CharacterBody3D
var network_signals_connected := false
var timer_label: Label
var health_label: Label
var ammo_label: Label
var mission_label: Label
var score_label: Label
var message_label: Label
var reload_bar: ProgressBar
var reload_label: Label
var damage_overlay: ColorRect
var fail_overlay: ColorRect
var clear_overlay: ColorRect
var lan_overlay: ColorRect
var lan_status: Label
var ip_input: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_interface()
	visible = false


func build_interface() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	game_viewport = SubViewport.new()
	game_viewport.size = Vector2i(960, 540)
	game_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	game_viewport.handle_input_locally = false
	game_viewport.own_world_3d = true
	game_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(game_viewport)
	var top := ColorRect.new()
	top.color = Color("#07111dcc")
	top.size = Vector2(960, 70)
	top.z_index = 40
	add_child(top)
	timer_label = make_label(Vector2(18, 13), Vector2(145, 42), 22, Color("#fde68a"))
	health_label = make_label(Vector2(175, 13), Vector2(180, 42), 21, Color("#fb7185"))
	ammo_label = make_label(Vector2(340, 9), Vector2(280, 50), 22, Color.WHITE)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label = make_label(Vector2(620, 13), Vector2(155, 42), 16, Color("#d4c7a5"))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label in [timer_label, health_label, ammo_label, score_label]: top.add_child(label)
	mission_label = make_label(Vector2(20, 83), Vector2(300, 36), 19, Color("#7dd3fc"))
	message_label = make_label(Vector2(235, 83), Vector2(490, 40), 18, Color.WHITE)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_outline_color", Color("#020617"))
	message_label.add_theme_constant_override("outline_size", 6)
	for label in [mission_label, message_label]:
		label.z_index = 45
		add_child(label)
	reload_bar = ProgressBar.new()
	reload_bar.position = Vector2(350, 130)
	reload_bar.size = Vector2(260, 15)
	reload_bar.max_value = RELOAD_TIME
	reload_bar.value = 0
	reload_bar.show_percentage = false
	reload_bar.visible = false
	reload_bar.z_index = 46
	add_child(reload_bar)
	reload_label = make_label(Vector2(350, 147), Vector2(260, 24), 15, Color("#fde68a"))
	reload_label.text = "RELOADING"
	reload_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reload_label.visible = false
	reload_label.z_index = 46
	add_child(reload_label)
	build_crosshair()
	damage_overlay = ColorRect.new()
	damage_overlay.color = Color("#ef444400")
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_overlay.z_index = 70
	add_child(damage_overlay)
	build_end_overlays()
	build_lan_overlay()
	connect_network_signals()


func build_crosshair() -> void:
	for data in [[Vector2(463, 269), Vector2(8, 2)], [Vector2(489, 269), Vector2(8, 2)], [Vector2(479, 253), Vector2(2, 8)], [Vector2(479, 279), Vector2(2, 8)]]:
		var line := ColorRect.new()
		line.color = Color("#ffffffdd")
		line.position = data[0]
		line.size = data[1]
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.z_index = 50
		add_child(line)
	var dot := ColorRect.new()
	dot.color = Color("#38bdf8")
	dot.position = Vector2(478, 268)
	dot.size = Vector2(4, 4)
	dot.z_index = 51
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dot)


func build_end_overlays() -> void:
	fail_overlay = make_overlay("MISSION FAILED", Color("#fb7185"))
	var retry := make_button(Vector2(255, 300), "다시 도전")
	retry.pressed.connect(start_game)
	fail_overlay.add_child(retry)
	var exit := make_button(Vector2(500, 300), "복도로 돌아가기")
	exit.pressed.connect(_exit_to_corridor)
	fail_overlay.add_child(exit)
	clear_overlay = make_overlay("ROOM 5 CLEAR!", Color("#4ade80"))
	var summary := make_label(Vector2(205, 205), Vector2(550, 70), 20, Color("#e2e8f0"))
	summary.name = "Summary"
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_overlay.add_child(summary)
	var return_button := make_button(Vector2(377, 325), "복도로 돌아가기")
	return_button.pressed.connect(_finish_room)
	clear_overlay.add_child(return_button)


func build_lan_overlay() -> void:
	lan_overlay = ColorRect.new()
	lan_overlay.color = Color("#020617f2")
	lan_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lan_overlay.z_index = 120
	lan_overlay.visible = false
	add_child(lan_overlay)
	var title := make_label(Vector2(190, 42), Vector2(580, 62), 34, Color("#67e8f9"))
	title.text = "ROOM 5 · LAN BATTLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_overlay.add_child(title)
	lan_status = make_label(Vector2(180, 108), Vector2(600, 62), 17, Color("#cbd5e1"))
	lan_status.text = "같은 와이파이에서 한 명은 서버, 한 명은 적 참가를 선택하세요"
	lan_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lan_overlay.add_child(lan_status)
	var host := make_button(Vector2(115, 205), "플레이어 서버 열기")
	host.size = Vector2(225, 62)
	host.pressed.connect(host_lan_game)
	lan_overlay.add_child(host)
	var solo := make_button(Vector2(115, 292), "혼자 테스트")
	solo.size = Vector2(225, 58)
	solo.pressed.connect(start_solo_game)
	lan_overlay.add_child(solo)
	ip_input = LineEdit.new()
	ip_input.position = Vector2(420, 204)
	ip_input.size = Vector2(330, 48)
	ip_input.placeholder_text = "서버 IP (예: 192.168.0.10)"
	ip_input.text = "127.0.0.1"
	ip_input.add_theme_font_size_override("font_size", 17)
	lan_overlay.add_child(ip_input)
	var join := make_button(Vector2(480, 275), "적으로 참가")
	join.size = Vector2(210, 60)
	join.pressed.connect(join_lan_game)
	lan_overlay.add_child(join)
	if OS.has_feature("web"):
		host.disabled = true
		join.disabled = true
		ip_input.editable = false
		solo.text = "혼자 플레이"
		lan_status.text = "웹에서는 혼자 플레이할 수 있습니다. 같은 와이파이 대전은 Windows 버전을 이용하세요."
	var exit := make_button(Vector2(377, 410), "복도로 돌아가기")
	exit.pressed.connect(_exit_to_corridor)
	lan_overlay.add_child(exit)


func connect_network_signals() -> void:
	if network_signals_connected: return
	network_signals_connected = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func make_overlay(title_text: String, title_color: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = Color("#020617ed")
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.z_index = 100
	add_child(overlay)
	var title := make_label(Vector2(190, 115), Vector2(580, 80), 43, title_color)
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(title)
	return overlay


func start_game() -> void:
	visible = true
	fail_overlay.visible = false
	clear_overlay.visible = false
	lan_overlay.visible = true
	state = "lobby"
	role = "solo"
	lan_status.text = "같은 와이파이에서 한 명은 서버, 한 명은 적 참가를 선택하세요"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--shooter-auto-host" in OS.get_cmdline_args() or "--shooter-auto-host" in OS.get_cmdline_user_args():
		call_deferred("host_lan_game")
	elif "--shooter-auto-client" in OS.get_cmdline_args() or "--shooter-auto-client" in OS.get_cmdline_user_args():
		ip_input.text = "127.0.0.1"
		call_deferred("join_lan_game")
	elif "--shooter-auto-fire" in OS.get_cmdline_args() or "--shooter-auto-fire" in OS.get_cmdline_user_args():
		call_deferred("start_solo_game")


func begin_player_game(selected_role: String) -> void:
	role = selected_role
	lan_overlay.visible = false
	state = "playing"
	elapsed = 0.0
	health = 100
	ammo = MAGAZINE_SIZE
	reserve_ammo = 120
	attack_timer = 0
	reload_timer = 0.0
	enemy_left = ENEMY_COUNT
	score = 0
	yaw = 0.0
	pitch = 0.0
	shot_kick = 0.0
	is_crouching = false
	ai_kills = 0
	remote_enemy_active = false
	build_3d_world()
	message_label.text = "WASD 이동 · 클릭 발사 · R 재장전 · Space 점프 · Ctrl 웅크리기 · 적 8명 처치"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_hud()
	if "--shooter-auto-fire" in OS.get_cmdline_args() or "--shooter-auto-fire" in OS.get_cmdline_user_args():
		call_deferred("_debug_auto_fire")


func start_solo_game() -> void:
	close_network()
	begin_player_game("solo")


func host_lan_game() -> void:
	close_network()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(LAN_PORT, 2)
	if error != OK:
		lan_status.text = "서버를 열지 못했습니다. 포트 %d 사용 여부를 확인하세요." % LAN_PORT
		return
	multiplayer.multiplayer_peer = peer
	begin_player_game("host")
	message_label.text = "LAN 서버 %s:%d · 적 플레이어 접속 대기" % [get_lan_address(), LAN_PORT]


func join_lan_game() -> void:
	close_network()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(ip_input.text.strip_edges(), LAN_PORT)
	if error != OK:
		lan_status.text = "서버 연결을 시작하지 못했습니다"
		return
	role = "enemy"
	state = "waiting"
	multiplayer.multiplayer_peer = peer
	lan_status.text = "서버에 연결 중..."


func get_lan_address() -> String:
	for address in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			return address
	return "내부 IP"


func close_network() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _debug_auto_fire() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not targets.is_empty():
		var test_target: Dictionary = targets[2]
		camera.look_at(test_target.node.global_position + Vector3(0, 1.05, 0), Vector3.UP)
		await get_tree().physics_frame
		var hp_before: int = test_target.hp
		shoot()
		if int(test_target.hp) == hp_before:
			push_error("Shooter hit test failed: aimed shot did not damage target")
		return
	shoot()


func build_3d_world(with_ai: bool = true) -> void:
	if is_instance_valid(world_3d): world_3d.queue_free()
	world_3d = Node3D.new()
	game_viewport.add_child(world_3d)
	targets.clear()
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#75b9d1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#dbeafe")
	env.ambient_light_energy = 0.72
	environment.environment = env
	world_3d.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	world_3d.add_child(sun)
	build_map()
	build_player()
	if with_ai:
		spawn_mission_targets()


func _on_peer_connected(id: int) -> void:
	if role != "host": return
	remote_peer_id = id
	message_label.text = "적 플레이어 연결됨 · 일반 적 8명 처치 후 최종 대전"
	if "--shooter-auto-host" in OS.get_cmdline_args() or "--shooter-auto-host" in OS.get_cmdline_user_args():
		ai_kills = HUMAN_SPAWN_KILLS
	if ai_kills >= HUMAN_SPAWN_KILLS:
		activate_remote_enemy()


func _on_peer_disconnected(id: int) -> void:
	if id == remote_peer_id:
		remote_peer_id = 0
		message_label.text = "적 플레이어 연결이 끊어졌습니다"


func _on_connected_to_server() -> void:
	lan_status.text = "연결 완료 · 상대가 일반 적 8명을 처치할 때까지 대기 중"


func _on_connection_failed() -> void:
	lan_status.text = "연결 실패 · IP와 같은 와이파이인지 확인하세요"
	close_network()
	state = "lobby"


func _on_server_disconnected() -> void:
	fail_game("서버 연결이 종료되었습니다")


func activate_remote_enemy() -> void:
	if role != "host" or remote_peer_id == 0 or remote_enemy_active: return
	remote_enemy_active = true
	health = 100
	elapsed = 0.0
	player.position = HOST_DUEL_SPAWN
	player.velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	spawn_target(Vector3(ENEMY_DUEL_SPAWN.x, 0, ENEMY_DUEL_SPAWN.z), true)
	remote_enemy = targets.back().node
	enemy_left += 1
	activate_enemy_controller.rpc_id(remote_peer_id)
	message_label.text = "HP 완전 회복 · 반대편 플레이어와 최종 1대1!"
	update_hud()


@rpc("authority", "call_remote", "reliable")
func activate_enemy_controller() -> void:
	role = "enemy"
	lan_overlay.visible = false
	state = "playing_enemy"
	health = 100
	ammo = MAGAZINE_SIZE
	reserve_ammo = 48
	reload_timer = 0
	build_3d_world(false)
	player.position = ENEMY_DUEL_SPAWN
	player.rotation.y = PI
	yaw = PI
	pitch = 0.0
	remote_host_avatar = create_remote_host_avatar()
	remote_host_avatar.position = HOST_DUEL_SPAWN
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	message_label.text = "반대편에 상대 등장 · 최종 1대1 시작!"


func create_remote_host_avatar() -> CharacterBody3D:
	var avatar := CharacterBody3D.new()
	world_3d.add_child(avatar)
	var body := create_mesh_box(Vector3(0.8, 1.15, 0.5), Color("#e2e8f0"))
	body.position.y = 1.05
	avatar.add_child(body)
	var head := create_mesh_sphere(0.4, Color("#f1c7a5"))
	head.position.y = 1.88
	avatar.add_child(head)
	add_network_hitbox(avatar, "head", Vector3(0, 1.88, 0), Vector3(0.72, 0.72, 0.72))
	add_network_hitbox(avatar, "body", Vector3(0, 1.05, 0), Vector3(0.85, 1.15, 0.55))
	add_network_hitbox(avatar, "legs", Vector3(0, 0.38, 0), Vector3(0.65, 0.72, 0.5))
	return avatar


@rpc("any_peer", "call_remote", "unreliable")
func sync_enemy_transform(position_value: Vector3, rotation_y: float) -> void:
	if role == "host" and remote_enemy_active and is_instance_valid(remote_enemy):
		remote_enemy.position = position_value
		remote_enemy.rotation.y = rotation_y


@rpc("authority", "call_remote", "unreliable")
func sync_host_transform(position_value: Vector3, rotation_y: float) -> void:
	if role == "enemy" and is_instance_valid(remote_host_avatar):
		remote_host_avatar.position = position_value
		remote_host_avatar.rotation.y = rotation_y


@rpc("any_peer", "call_remote", "reliable")
func request_host_damage(hit_zone: String) -> void:
	if role == "host":
		damage_player(zone_damage(hit_zone))


@rpc("authority", "call_remote", "reliable")
func enemy_defeated() -> void:
	fail_game("상대 플레이어에게 처치되었습니다")


@rpc("authority", "call_remote", "reliable")
func host_defeated() -> void:
	state = "clear"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_overlay.get_node("Summary").text = "최종 1대1 승리! 상대 플레이어를 쓰러뜨렸습니다"
	clear_overlay.visible = true


func build_map() -> void:
	create_box(Vector3(0, -0.3, -2), Vector3(25, 0.6, 26), Color("#172033"), true)
	create_box(Vector3(0, 2.5, -15), Vector3(25, 5, 0.7), Color("#26364f"), true)
	create_box(Vector3(-12.5, 2.5, -2), Vector3(0.7, 5, 26), Color("#223047"), true)
	create_box(Vector3(12.5, 2.5, -2), Vector3(0.7, 5, 26), Color("#223047"), true)
	create_box(Vector3(0, 2.5, 11), Vector3(25, 5, 0.7), Color("#1f2937"), true)
	for data in [[Vector3(-7.8, 1.5, -9.5), Vector3(5, 3, 3.8), Color("#334155")], [Vector3(7, 2, -8), Vector3(4.5, 4, 4), Color("#243b53")], [Vector3(-8, 1.2, 1), Vector3(3.2, 2.4, 5), Color("#3f3c5e")], [Vector3(7.8, 1.4, 2.5), Vector3(4, 2.8, 4), Color("#35445c")], [Vector3(0, 1, -3), Vector3(3, 2, 2.6), Color("#293548")]]:
		create_box(data[0], data[1], data[2], true)
	for p in [Vector3(-3, 0.6, -10), Vector3(4, 0.6, 5), Vector3(-4, 0.6, 6), Vector3(9, 0.6, -3)]:
		create_box(p, Vector3(1.2, 1.2, 1.2), Color("#475569"), true)
	# 푸른 잔디맵 대신 네온 격자와 창문이 있는 캠퍼스 훈련장 분위기.
	for x in range(-12, 13, 2):
		create_box(Vector3(float(x), 0.015, -2), Vector3(0.025, 0.025, 25), Color("#38414b"), false)
	for z in range(-14, 11, 2):
		create_box(Vector3(0, 0.018, float(z)), Vector3(24, 0.025, 0.025), Color("#38414b"), false)
	for x in [-9.0, -6.0, 5.0, 8.0]:
		create_box(Vector3(x, 2.4, -14.62), Vector3(1.6, 1.1, 0.04), Color("#38bdf8"), false)


func build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 1.05, 8)
	world_3d.add_child(player)
	player_collision = CollisionShape3D.new()
	player_capsule = CapsuleShape3D.new()
	player_capsule.radius = 0.38
	player_capsule.height = 1.8
	player_collision.shape = player_capsule
	player.add_child(player_collision)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.62, 0)
	camera.fov = 74
	camera.current = true
	player.add_child(camera)
	gun = Node3D.new()
	gun.position = Vector3(0.48, -0.36, -0.75)
	camera.add_child(gun)
	for data in [[Vector3(0, 0, -0.15), Vector3(0.22, 0.18, 0.62), Color("#202936")], [Vector3(0, 0.05, -0.62), Vector3(0.12, 0.12, 0.54), Color("#475569")], [Vector3(0, -0.24, 0.02), Vector3(0.15, 0.38, 0.18), Color("#7c3f2c")]]:
		var part := create_mesh_box(data[1], data[2])
		part.position = data[0]
		gun.add_child(part)
	muzzle_flash = OmniLight3D.new()
	muzzle_flash.position = Vector3(0, 0.05, -0.94)
	muzzle_flash.light_color = Color("#fbbf24")
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 3.0
	gun.add_child(muzzle_flash)
	muzzle_mesh = create_mesh_sphere(0.085, Color("#fff0cb"))
	muzzle_mesh.material_override = GUN_EFFECTS.glow(Color("#ffdc90"), 5.0)
	muzzle_mesh.position = muzzle_flash.position
	muzzle_mesh.scale = Vector3(0.5, 0.5, 1.9)
	muzzle_mesh.visible = false
	gun.add_child(muzzle_mesh)
	for x in [-0.07, 0.07]:
		var sight := create_mesh_box(Vector3(0.025, 0.05, 0.035), Color("#10171d"))
		sight.position = Vector3(x, 0.14, 0.05)
		gun.add_child(sight)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.055
	barrel_mesh.bottom_radius = 0.055
	barrel_mesh.height = 0.49
	barrel_mesh.radial_segments = 16
	barrel.mesh = barrel_mesh
	barrel.material_override = make_material(Color("#252a2c"))
	barrel.position = Vector3(0, 0.05, -0.68)
	barrel.rotation_degrees.x = 90
	gun.add_child(barrel)
	for i in 5:
		var groove := create_mesh_box(Vector3(0.226, 0.013, 0.025), Color("#111619"))
		groove.position = Vector3(0, 0.098, 0.07 - i * 0.045)
		gun.add_child(groove)
	var port := create_mesh_box(Vector3(0.012, 0.065, 0.13), Color("#0c1215"))
	port.position = Vector3(0.115, 0.03, -0.25)
	gun.add_child(port)
	var hand := create_mesh_sphere(0.12, Color("#b79479"))
	hand.scale = Vector3(0.85, 1.6, 1.0)
	hand.position = Vector3(0.02, -0.26, 0.04)
	gun.add_child(hand)
	build_melee_weapons()
	select_weapon(2)


func build_melee_weapons() -> void:
	fists = Node3D.new()
	fists.position = Vector3(0,-0.32,-0.58)
	camera.add_child(fists)
	for side in [-1,1]:
		var fist := create_mesh_sphere(0.115,Color("#bc9377"))
		fist.position = Vector3(side*0.26,0,0)
		fist.scale = Vector3(0.8,0.85,1.3)
		fists.add_child(fist)
		for i in 4:
			var knuckle := create_mesh_sphere(.026,Color("#cba68b"))
			knuckle.position = Vector3(side*.26+(i-1.5)*.037,.04,-.105)
			fists.add_child(knuckle)
	knife = Node3D.new()
	knife.position = Vector3(.37,-.30,-.62)
	camera.add_child(knife)
	var grip := create_mesh_box(Vector3(.075,.075,.25),Color("#202b2b"))
	knife.add_child(grip)
	var guard := create_mesh_box(Vector3(.19,.035,.045),Color("#909da3"))
	guard.position.z = -.15
	knife.add_child(guard)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := [Vector3(-.06,0,-.16),Vector3(.06,0,-.16),Vector3(.045,0,-.46),Vector3(0,0,-.65),Vector3(-.045,0,-.46),Vector3(0,.018,-.30)]
	for face in [[0,1,5],[1,2,5],[2,3,5],[3,4,5],[4,0,5]]:
		for index in face: surface.add_vertex(verts[index])
	surface.generate_normals()
	var blade := MeshInstance3D.new()
	blade.mesh = surface.commit()
	var steel := make_material(Color("#c4d1d6"))
	steel.metallic = .85
	steel.roughness = .25
	steel.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.material_override = steel
	knife.add_child(blade)
	if not is_instance_valid(weapon_label):
		weapon_label = make_label(Vector2(22,473),Vector2(910,34),18,Color("#e8ded0"))
		add_child(weapon_label)


func select_weapon(slot: int) -> void:
	if reload_motion != null and reload_motion.is_valid(): reload_motion.kill()
	weapon_slot = slot
	reload_timer = 0
	reload_bar.visible = false
	reload_label.visible = false
	gun.visible = slot == 2
	fists.visible = slot == 1
	knife.visible = slot == 3
	gun.position = Vector3(.48,-.36,-.75)
	gun.rotation_degrees = Vector3.ZERO
	weapon_label.text = "1 맨손   ·   2 자동사격 총   ·   3 칼   |   선택: " + ["맨손","총","칼"][slot-1]
	message_label.text = ["맨손 장착 · 가까이서 클릭","총 장착 · 클릭 유지로 연사 / R 재장전","칼 장착 · 가까이서 클릭"][slot-1]
	update_hud()


func use_weapon() -> void:
	if attack_timer > 0: return
	if weapon_slot == 2: shoot()
	else: melee_attack()


func melee_attack() -> void:
	attack_timer = .42 if weapon_slot == 1 else .62
	var visual := fists if weapon_slot == 1 else knife
	var home := visual.position
	var swing := visual.create_tween()
	swing.tween_property(visual,"position",home+Vector3(-.12,.04,-.23),.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.tween_property(visual,"position",home,.20).set_trans(Tween.TRANS_SINE)
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*(2.0 if weapon_slot==1 else 2.7),3)
	query.collide_with_areas = true
	var exclusions: Array[RID] = [player.get_rid()]
	for target in targets:
		if is_instance_valid(target.node): exclusions.append(target.node.get_rid())
	query.exclude = exclusions
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	Sfx.play("hit",-15,1.3)
	if result.is_empty(): return
	var zone := "fist" if weapon_slot == 1 else "knife"
	if result.collider.has_meta("network_player") and role == "enemy":
		request_host_damage.rpc_id(1,zone)
	elif result.collider.has_meta("target_id"):
		var index: int = result.collider.get_meta("target_id")
		if index >= 0 and index < targets.size(): hit_target(targets[index],zone)


func spawn_mission_targets() -> void:
	for p in [Vector3(-10, 0, -12), Vector3(-4, 0, -12), Vector3(3.5, 0, -12), Vector3(10, 0, -11), Vector3(-10, 0, -3), Vector3(10, 0, -1), Vector3(-5, 0, 7), Vector3(6, 0, 7)]:
		spawn_target(p)


func spawn_target(position_value: Vector3, human_controlled: bool = false) -> void:
	var root := CharacterBody3D.new()
	root.position = position_value
	world_3d.add_child(root)
	var palette := [Color("#d8b4fe"), Color("#a5f3fc"), Color("#fde68a")]
	var color: Color = palette[targets.size() % palette.size()]
	var body_mesh := create_mesh_box(Vector3(0.82, 1.12, 0.52), color, ROBOT_ARMOR_TEXTURE)
	body_mesh.position.y = 1.05
	root.add_child(body_mesh)
	var head := create_mesh_sphere(0.42, Color("#182235"))
	head.position.y = 1.88
	root.add_child(head)
	var visor := create_mesh_box(Vector3(0.56, 0.14, 0.09), color)
	visor.position = Vector3(0, 1.92, 0.38)
	root.add_child(visor)
	for side in [-1.0, 1.0]:
		var arm := create_mesh_box(Vector3(0.25, 0.82, 0.25), color, ROBOT_ARMOR_TEXTURE)
		arm.position = Vector3(0.42 * side, 1.24, 0.25)
		arm.rotation_degrees.x = -58
		arm.rotation_degrees.z = -8 * side
		root.add_child(arm)
		var leg := create_mesh_box(Vector3(0.29, 0.8, 0.32), color, ROBOT_ARMOR_TEXTURE)
		leg.position = Vector3(0.22 * side, 0.4, 0)
		root.add_child(leg)
	var enemy_weapon := Node3D.new()
	enemy_weapon.name = "EnemyWeapon"
	enemy_weapon.position = Vector3(0.12, 1.28, 0.42)
	root.add_child(enemy_weapon)
	var enemy_gun := create_mesh_box(Vector3(0.20, 0.20, 0.92), Color("#111827"), ROBOT_ARMOR_TEXTURE)
	enemy_gun.position.z = 0.30
	enemy_weapon.add_child(enemy_gun)
	var gun_stock := create_mesh_box(Vector3(0.30, 0.30, 0.30), Color("#334155"))
	gun_stock.position = Vector3(0, -0.08, -0.24)
	enemy_weapon.add_child(gun_stock)
	var gun_sight := create_mesh_box(Vector3(0.08, 0.10, 0.18), color)
	gun_sight.position = Vector3(0, 0.14, 0.18)
	enemy_weapon.add_child(gun_sight)
	var enemy_muzzle := Node3D.new()
	enemy_muzzle.name = "Muzzle"
	enemy_muzzle.position = Vector3(0, 0, 0.82)
	enemy_weapon.add_child(enemy_muzzle)
	var shape_node := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 2.25
	shape_node.shape = shape
	shape_node.position.y = 1.1
	root.add_child(shape_node)
	var target_id := targets.size()
	add_target_hitbox(root, target_id, "head", Vector3(0, 1.88, 0), Vector3(0.72, 0.72, 0.72))
	add_target_hitbox(root, target_id, "body", Vector3(0, 1.05, 0), Vector3(0.86, 1.12, 0.58))
	add_target_hitbox(root, target_id, "legs", Vector3(0, 0.38, 0), Vector3(0.68, 0.72, 0.52))
	var move_direction := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	targets.append({"node": root, "collider": root, "hp": 100, "alive": true, "human": human_controlled,
		"attack": randf_range(2.5, 4.5), "burst_left": 0, "move_timer": randf_range(1.2, 2.8),
		"move_direction": move_direction, "speed": randf_range(0.65, 1.15)})


func add_target_hitbox(root: Node3D, target_id: int, zone: String, position_value: Vector3, size_value: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.position = position_value
	area.set_meta("target_id", target_id)
	area.set_meta("hit_zone", zone)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	area.add_child(collision)
	root.add_child(area)


func add_network_hitbox(root: Node3D, zone: String, position_value: Vector3, size_value: Vector3) -> void:
	var area := Area3D.new()
	area.collision_layer = 2
	area.collision_mask = 0
	area.position = position_value
	area.set_meta("network_player", true)
	area.set_meta("hit_zone", zone)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	area.add_child(collision)
	root.add_child(area)


func _physics_process(delta: float) -> void:
	if not visible or state not in ["playing", "playing_enemy"] or not is_instance_valid(player): return
	if state == "playing": elapsed += delta
	attack_timer = maxf(0,attack_timer-delta)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: use_weapon()
	if reload_timer > 0:
		reload_timer -= delta
		reload_bar.value = RELOAD_TIME - maxf(0, reload_timer)
		if reload_timer <= 0:
			Sfx.play("reload", -1.0, 1.12)
			var loaded := mini(MAGAZINE_SIZE - ammo, reserve_ammo)
			ammo += loaded
			reserve_ammo -= loaded
			reload_bar.visible = false
			reload_label.visible = false
			gun.position = Vector3(0.48, -0.36, -0.75)
			gun.rotation_degrees = Vector3.ZERO
			message_label.text = "재장전 완료"
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_key_pressed(KEY_A): input_vector.x = -1
	if Input.is_key_pressed(KEY_D): input_vector.x = 1
	if Input.is_key_pressed(KEY_W): input_vector.y = -1
	if Input.is_key_pressed(KEY_S): input_vector.y = 1
	is_crouching = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	var target_camera_y := 0.20 if is_crouching else 0.62
	camera.position.y = move_toward(camera.position.y, target_camera_y, delta * 2.8)
	player_capsule.height = 1.12 if is_crouching else 1.8
	player_collision.position.y = -0.34 if is_crouching else 0.0
	var forward := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	forward.y = 0
	right.y = 0
	var direction := (right * input_vector.x - forward * input_vector.y).normalized()
	var current_speed := PLAYER_SPEED * (0.48 if is_crouching else 1.0)
	player.velocity.x = direction.x * current_speed
	player.velocity.z = direction.z * current_speed
	if not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
	elif player.velocity.y < 0:
		player.velocity.y = 0
	player.move_and_slide()
	if role == "enemy":
		sync_enemy_transform.rpc_id(1, player.position, player.rotation.y)
	elif state == "playing":
		update_targets(delta)
		if role == "host" and remote_peer_id != 0:
			sync_host_transform.rpc_id(remote_peer_id, player.position, player.rotation.y)
	shot_kick = move_toward(shot_kick, 0, delta * 65)
	if reload_timer <= 0.0:
		gun.rotation_degrees.x = shot_kick
	if state == "playing" and elapsed >= GAME_DURATION: fail_game("제한 시간 안에 적 로봇을 모두 처치하지 못했습니다")
	update_hud()


func _input(event: InputEvent) -> void:
	if not visible or state not in ["playing", "playing_enemy"]: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENSITIVITY
		pitch = clampf(pitch - event.relative.y * MOUSE_SENSITIVITY, -1.25, 1.25)
		player.rotation.y = yaw
		camera.rotation.x = pitch
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		use_weapon()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if player.is_on_floor() and not is_crouching:
			player.velocity.y = JUMP_SPEED
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1,KEY_2,KEY_3]:
		select_weapon(int(event.keycode-KEY_1)+1)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and weapon_slot == 2:
		begin_reload()
		get_viewport().set_input_as_handled()


func shoot() -> void:
	if reload_timer > 0 or attack_timer > 0 or weapon_slot != 2: return
	attack_timer = .12
	if ammo <= 0:
		begin_reload()
		return
	ammo -= 1
	Sfx.play("gunshot_auto", -10.0, 1.0, 0.02)
	shot_kick = 9
	muzzle_flash.light_energy = 5
	create_tween().tween_property(muzzle_flash, "light_energy", 0, 0.08)
	muzzle_mesh.visible = true
	get_tree().create_timer(0.045, false).timeout.connect(func() -> void:
		if is_instance_valid(muzzle_mesh): muzzle_mesh.visible = false
	)
	GUN_EFFECTS.casing(world_3d, gun.global_position, camera.global_transform.basis.x)
	var origin := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, origin + -camera.global_transform.basis.z * 80)
	query.collide_with_areas = true
	query.collision_mask = 3
	var exclusions: Array[RID] = [player.get_rid()]
	for target in targets:
		if is_instance_valid(target.node): exclusions.append(target.node.get_rid())
	query.exclude = exclusions
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	var endpoint: Vector3 = result.position if not result.is_empty() else origin - camera.global_transform.basis.z * 60.0
	# A close wall can block the muzzle even when the camera sees past it.
	var muzzle_query := PhysicsRayQueryParameters3D.create(muzzle_flash.global_position, endpoint, 1, exclusions)
	var muzzle_hit := camera.get_world_3d().direct_space_state.intersect_ray(muzzle_query)
	if not muzzle_hit.is_empty() and muzzle_flash.global_position.distance_to(muzzle_hit.position) < muzzle_flash.global_position.distance_to(endpoint) - 0.08:
		result = muzzle_hit
		endpoint = muzzle_hit.position
	GUN_EFFECTS.shot(world_3d, muzzle_flash.global_position, endpoint, not result.is_empty())
	if not result.is_empty() and result.collider.has_meta("network_player") and role == "enemy":
		request_host_damage.rpc_id(1, str(result.collider.get_meta("hit_zone")))
		message_label.text = "%s 명중!" % zone_name(str(result.collider.get_meta("hit_zone")))
	elif not result.is_empty() and result.collider.has_meta("target_id"):
		var target_id: int = result.collider.get_meta("target_id")
		if target_id >= 0 and target_id < targets.size():
			hit_target(targets[target_id], str(result.collider.get_meta("hit_zone")))
	else: message_label.text = "MISS"
	if ammo == 0 and reserve_ammo > 0: message_label.text = "탄창이 비었습니다 · R 재장전"


func hit_target(target: Dictionary, hit_zone: String) -> void:
	if not target.alive: return
	var damage := zone_damage(hit_zone)
	Sfx.play("hit", -6.0, 1.1 if hit_zone == "head" else 0.95, 0.04)
	target.hp = int(target.hp) - damage
	score += 100
	message_label.text = "%s 명중 · %d DAMAGE" % [zone_name(hit_zone), damage]
	if target.hp <= 0:
		Sfx.play("enemy_down", -2.0, 0.9, 0.05)
		target.alive = false
		target.collider.collision_layer = 0
		target.collider.collision_mask = 0
		enemy_left -= 1
		if target.human:
			enemy_defeated.rpc_id(remote_peer_id)
		else:
			ai_kills += 1
			if ai_kills >= HUMAN_SPAWN_KILLS:
				activate_remote_enemy()
		score += 400
		var node: CharacterBody3D = target.node
		var fall := create_tween()
		fall.set_parallel(true)
		fall.tween_property(node, "rotation_degrees:z", 88, 0.35)
		fall.tween_property(node, "position:y", -0.7, 0.35)
		if remote_enemy_active and not target.human and ai_kills == HUMAN_SPAWN_KILLS:
			message_label.text = "HP 완전 회복 · 반대편 플레이어와 최종 1대1!"
		else:
			message_label.text = "적 로봇 처치! 남은 수 %d" % enemy_left
		if enemy_left <= 0: complete_game()


func zone_damage(hit_zone: String) -> int:
	if hit_zone == "fist": return 25
	if hit_zone == "knife": return 55
	if hit_zone == "head": return 60
	if hit_zone == "legs": return 22
	return 34


func zone_name(hit_zone: String) -> String:
	if hit_zone == "fist": return "PUNCH"
	if hit_zone == "knife": return "KNIFE"
	if hit_zone == "head": return "HEAD"
	if hit_zone == "legs": return "LEGS"
	return "BODY"


func update_targets(delta: float) -> void:
	for target in targets:
		if not target.alive: continue
		if target.human: continue
		var node: CharacterBody3D = target.node
		target.move_timer = float(target.move_timer) - delta
		if target.move_timer <= 0:
			target.move_timer = randf_range(1.1, 2.7)
			target.move_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		node.velocity.x = target.move_direction.x * float(target.speed)
		node.velocity.z = target.move_direction.z * float(target.speed)
		node.velocity.y = -0.5
		node.move_and_slide()
		for collision_index in node.get_slide_collision_count():
			if absf(node.get_slide_collision(collision_index).get_normal().y) < .5:
				target.move_direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
				target.move_timer = randf_range(0.7, 1.5)
		if absf(node.position.x) > 11.2:
			node.position.x = clampf(node.position.x, -11.2, 11.2)
			var bounced_x: Vector3 = target.move_direction
			bounced_x.x *= -1
			target.move_direction = bounced_x
		if node.position.z < -13.8 or node.position.z > 9.8:
			node.position.z = clampf(node.position.z, -13.8, 9.8)
			var bounced_z: Vector3 = target.move_direction
			bounced_z.z *= -1
			target.move_direction = bounced_z
		node.look_at(Vector3(player.global_position.x, node.global_position.y, player.global_position.z), Vector3.UP, true)
		target.attack = float(target.attack) - delta
		if target.attack <= 0 and node.global_position.distance_to(player.global_position) < 18:
			if int(target.burst_left) <= 0: target.burst_left = 3
			target.burst_left = int(target.burst_left)-1
			target.attack = .18 if int(target.burst_left)>0 else randf_range(3.0,4.5)
			enemy_shoot(node)


func enemy_shoot(enemy: Node3D) -> void:
	Sfx.play("gunshot", -12.0, 0.66, 0.07)
	var hit := randf() < 0.12
	var target_position := player.global_position + Vector3(0, 0.65, 0)
	if not hit:
		target_position += Vector3(randf_range(-3.8, 3.8), randf_range(-2.0, 2.8), randf_range(-2.0, 2.0))
	var body_origin := enemy.global_position + Vector3(0, 1.3, 0)
	var muzzle := enemy.get_node_or_null("EnemyWeapon/Muzzle") as Node3D
	var from := muzzle.global_position if muzzle != null else body_origin
	# Also check the barrel's path so a barrel poking through cover cannot shoot through it.
	var barrel_hit := trace_enemy_shot(enemy, body_origin, from)
	if not barrel_hit.is_empty():
		GUN_EFFECTS.shot(world_3d, body_origin, barrel_hit.position, true)
		return
	var result := trace_enemy_shot(enemy, from, target_position)
	var endpoint: Vector3 = result.position if not result.is_empty() else target_position
	GUN_EFFECTS.shot(world_3d, from, endpoint, not result.is_empty(), Color("#ffd3a0"))
	if hit and not result.is_empty() and result.collider == player:
		damage_player(randi_range(10, 16))


func trace_enemy_shot(enemy: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var ignored: Array[RID] = []
	if enemy is CollisionObject3D: ignored.append(enemy.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, ignored)
	query.collide_with_areas = false
	return world_3d.get_world_3d().direct_space_state.intersect_ray(query)


func spawn_enemy_tracer(from: Vector3, to: Vector3) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#facc15")
	material.emission_enabled = true
	material.emission = Color("#f59e0b")
	var line_mesh := ImmediateMesh.new()
	line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	line_mesh.surface_add_vertex(from)
	line_mesh.surface_add_vertex(to)
	line_mesh.surface_end()
	var tracer := MeshInstance3D.new()
	tracer.mesh = line_mesh
	world_3d.add_child(tracer)
	get_tree().create_timer(0.12, false).timeout.connect(tracer.queue_free)


func damage_player(amount: int = 12) -> void:
	health -= amount
	Sfx.play("player_hit", -1.0, 0.86, 0.05)
	flash_damage(Color("#ef4444"), 0.28)
	message_label.text = "적의 총알에 맞았습니다 · -%d HP" % amount
	if health <= 0:
		if role == "host" and remote_enemy_active and remote_peer_id != 0:
			host_defeated.rpc_id(remote_peer_id)
			fail_game("상대 플레이어에게 처치되었습니다")
		else:
			fail_game("적 로봇의 공격에 쓰러졌습니다")


func begin_reload() -> void:
	if weapon_slot != 2 or reload_timer > 0 or ammo == MAGAZINE_SIZE or reserve_ammo <= 0: return
	reload_timer = RELOAD_TIME
	Sfx.play("reload", -5.0, 0.82)
	reload_bar.value = 0
	reload_bar.visible = true
	reload_label.visible = true
	message_label.text = "재장전 중..."
	var reload_tween := create_tween()
	reload_motion = reload_tween
	reload_tween.tween_property(gun, "position", Vector3(0.24, -0.82, -0.58), 0.35)
	reload_tween.parallel().tween_property(gun, "rotation_degrees", Vector3(-42, 0, 22), 0.35)
	reload_tween.tween_interval(RELOAD_TIME - 0.70)
	reload_tween.tween_property(gun, "position", Vector3(0.48, -0.36, -0.75), 0.35)
	reload_tween.parallel().tween_property(gun, "rotation_degrees", Vector3.ZERO, 0.35)


func flash_damage(color: Color, alpha: float) -> void:
	damage_overlay.color = Color(color, alpha)
	create_tween().tween_property(damage_overlay, "color:a", 0, 0.22)


func complete_game() -> void:
	state = "clear"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	clear_overlay.get_node("Summary").text = "적 로봇 전원 처치 · 점수 %d · 남은 시간 %.1f초" % [score, GAME_DURATION - elapsed]
	clear_overlay.visible = true


func fail_game(reason: String) -> void:
	if state not in ["playing", "playing_enemy", "waiting"]: return
	state = "failed"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	message_label.text = reason
	fail_overlay.visible = true


func update_hud() -> void:
	var remaining := maxi(0, int(ceil(GAME_DURATION - elapsed)))
	timer_label.text = "TIME  %02d:%02d" % [remaining / 60, remaining % 60]
	health_label.text = "HP  %d / 100" % maxi(0, health)
	ammo_label.text = ("재장전 중..." if reload_timer > 0 else "탄창 %d  |  예비 %d" % [ammo, reserve_ammo]) if weapon_slot == 2 else ("맨손 · 25 피해" if weapon_slot == 1 else "칼 · 55 피해")
	mission_label.text = "ENEMY  %d / %d" % [enemy_left, ENEMY_COUNT]
	score_label.text = "SCORE  %06d" % score


func create_box(p: Vector3, size_value: Vector3, color: Color, collision_enabled: bool) -> Node3D:
	var root := Node3D.new()
	root.position = p
	world_3d.add_child(root)
	root.add_child(create_mesh_box(size_value, color))
	if collision_enabled:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_value
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	return root


func create_mesh_box(size_value: Vector3, color: Color, texture: Texture2D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = make_material(color, texture)
	if texture == null and size_value.length() > 2.5:
		mesh.material.albedo_texture = CONCRETE_DETAIL
		mesh.material.uv1_triplanar = true
		mesh.material.uv1_scale = Vector3(0.6, 0.6, 0.6)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func create_mesh_sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = make_material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func make_material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if texture != null:
		material.albedo_texture = texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	material.roughness = 0.82
	return material


func _finish_room() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_network()
	game_won.emit()


func _exit_to_corridor() -> void:
	visible = false
	state = "idle"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_network()


func make_button(position_value: Vector2, text_value: String) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = Vector2(205, 60)
	button.text = text_value
	button.add_theme_font_size_override("font_size", 19)
	return button


func make_label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
