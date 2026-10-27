class_name CardGame
extends Control

signal game_won

const OPPONENT_TEXTURE := preload("res://assets/characters/club_leader_boss_idle_v4.png")
const CARD_SIZE := Vector2(92, 128)
const CARD_GAP := 18.0
const NORMAL_RANKS := ["J", "Q", "K", "A"]

var player_hand: Array[String] = []
var opponent_hand: Array[String] = []
var matched_ranks: Array[String] = []
var player_card_nodes: Array[Button] = []
var opponent_card_nodes: Array[Button] = []
var turn_busy := false
var last_result_was_win := false

var status_label: Label
var opponent_cards: Control
var player_cards: Control
var matched_cards: Control
var result_overlay: ColorRect
var result_title: Label
var result_message: Label
var result_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build_interface()
	visible = false


func build_interface() -> void:
	var background := ColorRect.new()
	background.color = Color("#07101f")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	var table := ColorRect.new()
	table.color = Color("#163d35")
	table.position = Vector2(25, 205)
	table.size = Vector2(910, 315)
	table.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(table)

	var portrait := TextureRect.new()
	var portrait_crop := AtlasTexture.new()
	portrait_crop.atlas = OPPONENT_TEXTURE
	portrait_crop.region = Rect2(105, 0, float(OPPONENT_TEXTURE.get_width()) / 4.0 - 145.0, 560)
	portrait.texture = portrait_crop
	portrait.position = Vector2(42, 20)
	portrait.size = Vector2(190, 178)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)

	var opponent_name := Label.new()
	opponent_name.position = Vector2(42, 172)
	opponent_name.size = Vector2(190, 30)
	opponent_name.text = "상대 (임시 캐릭터)"
	opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	opponent_name.add_theme_font_size_override("font_size", 16)
	opponent_name.add_theme_color_override("font_color", Color("#fca5a5"))
	add_child(opponent_name)

	opponent_cards = Control.new()
	opponent_cards.position = Vector2(260, 52)
	opponent_cards.size = Vector2(670, 135)
	add_child(opponent_cards)

	status_label = Label.new()
	status_label.position = Vector2(220, 206)
	status_label.size = Vector2(520, 48)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 22)
	status_label.add_theme_color_override("font_color", Color("#f8fafc"))
	add_child(status_label)

	var matched_label := Label.new()
	matched_label.position = Vector2(42, 266)
	matched_label.size = Vector2(150, 28)
	matched_label.text = "맞춘 카드"
	matched_label.add_theme_font_size_override("font_size", 17)
	matched_label.add_theme_color_override("font_color", Color("#a7f3d0"))
	add_child(matched_label)

	matched_cards = Control.new()
	matched_cards.position = Vector2(190, 258)
	matched_cards.size = Vector2(720, 90)
	add_child(matched_cards)

	var player_label := Label.new()
	player_label.position = Vector2(42, 363)
	player_label.size = Vector2(150, 28)
	player_label.text = "내 카드 (앞면)"
	player_label.add_theme_font_size_override("font_size", 17)
	player_label.add_theme_color_override("font_color", Color("#bfdbfe"))
	add_child(player_label)

	player_cards = Control.new()
	player_cards.position = Vector2(200, 365)
	player_cards.size = Vector2(720, 145)
	add_child(player_cards)

	result_overlay = ColorRect.new()
	result_overlay.color = Color("#020617ed")
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	add_child(result_overlay)

	result_title = Label.new()
	result_title.position = Vector2(180, 140)
	result_title.size = Vector2(600, 90)
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 52)
	result_overlay.add_child(result_title)

	result_message = Label.new()
	result_message.position = Vector2(220, 250)
	result_message.size = Vector2(520, 55)
	result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_message.add_theme_font_size_override("font_size", 21)
	result_overlay.add_child(result_message)

	result_button = Button.new()
	result_button.position = Vector2(350, 340)
	result_button.size = Vector2(260, 62)
	result_button.add_theme_font_size_override("font_size", 20)
	result_button.pressed.connect(_on_result_button_pressed)
	result_overlay.add_child(result_button)


func start_game() -> void:
	visible = true
	Sfx.play("card_shuffle", -3.0, 1.0, 0.03)
	result_overlay.visible = false
	turn_busy = true
	player_hand.assign(NORMAL_RANKS)
	opponent_hand.assign(NORMAL_RANKS)
	opponent_hand.append("JOKER")
	player_hand.shuffle()
	opponent_hand.shuffle()
	matched_ranks.clear()
	status_label.text = "상대가 먼저 내 카드를 뽑습니다"
	refresh_all_cards()
	call_deferred("opponent_turn")


func opponent_turn() -> void:
	if not visible or player_hand.is_empty():
		check_game_over()
		return
	turn_busy = true
	set_opponent_cards_enabled(false)
	status_label.text = "상대가 카드를 고르는 중..."
	await get_tree().create_timer(0.75).timeout

	var chosen_index := randi_range(0, player_hand.size() - 1)
	var rank := player_hand[chosen_index]
	var source_position := player_cards.position + player_card_nodes[chosen_index].position
	var target_position := opponent_cards.position + Vector2(250, 2)
	await animate_draw(source_position, target_position, rank, true)
	Sfx.play("card_draw", -2.0, 0.94, 0.04)
	player_hand.remove_at(chosen_index)
	opponent_hand.append(rank)
	status_label.text = "상대가 %s 카드를 뽑았습니다" % rank
	refresh_all_cards()
	await get_tree().create_timer(0.45).timeout

	if remove_pair(opponent_hand, rank):
		Sfx.play("card_pair", -1.0, 0.95, 0.04)
		status_label.text = "%s 한 쌍이 완성됐습니다!" % rank
		await animate_pair_to_pile(rank, target_position)
		matched_ranks.append(rank)
		refresh_all_cards()

	if check_game_over():
		return
	opponent_hand.shuffle()
	refresh_all_cards()
	status_label.text = "상대의 뒷면 카드 중 한 장을 고르세요"
	turn_busy = false
	set_opponent_cards_enabled(true)


func _on_opponent_card_pressed(index: int) -> void:
	if turn_busy or index < 0 or index >= opponent_hand.size():
		return
	player_turn(index)


func player_turn(chosen_index: int) -> void:
	turn_busy = true
	set_opponent_cards_enabled(false)
	var rank := opponent_hand[chosen_index]
	var source_position := opponent_cards.position + opponent_card_nodes[chosen_index].position
	var target_position := player_cards.position + Vector2(250, 4)
	status_label.text = "카드를 뽑는 중..."
	await animate_draw(source_position, target_position, rank, false)
	Sfx.play("card_draw", -1.0, 1.04, 0.04)
	opponent_hand.remove_at(chosen_index)
	player_hand.append(rank)
	status_label.text = "%s 카드를 뽑았습니다" % rank
	refresh_all_cards()
	await get_tree().create_timer(0.4).timeout

	if remove_pair(player_hand, rank):
		Sfx.play("card_pair", 0.0, 1.05, 0.04)
		status_label.text = "%s 한 쌍을 맞췄습니다!" % rank
		await animate_pair_to_pile(rank, target_position)
		matched_ranks.append(rank)
		refresh_all_cards()

	if check_game_over():
		return
	status_label.text = "다시 상대 차례입니다"
	await get_tree().create_timer(0.65).timeout
	opponent_turn()


func remove_pair(hand: Array[String], rank: String) -> bool:
	if rank == "JOKER" or hand.count(rank) < 2:
		return false
	hand.erase(rank)
	hand.erase(rank)
	return true


func check_game_over() -> bool:
	if not player_hand.is_empty() and not opponent_hand.is_empty():
		return false
	var player_lost := player_hand.has("JOKER")
	show_result(not player_lost)
	return true


func show_result(player_won: bool) -> void:
	turn_busy = true
	last_result_was_win = player_won
	result_overlay.visible = true
	if player_won:
		Sfx.play("ui_confirm", 1.0, 0.9)
		result_title.text = "YOU WIN!"
		result_title.add_theme_color_override("font_color", Color("#4ade80"))
		result_message.text = "상대에게 조커가 남았습니다"
		result_button.text = "복도로 돌아가기"
	else:
		Sfx.play("ui_error", 0.0, 0.88)
		result_title.text = "YOU LOSE"
		result_title.add_theme_color_override("font_color", Color("#fb7185"))
		result_message.text = "내 손에 조커가 남았습니다"
		result_button.text = "재도전"


func _on_result_button_pressed() -> void:
	if last_result_was_win:
		visible = false
		game_won.emit()
	else:
		start_game()


func refresh_all_cards() -> void:
	clear_holder(opponent_cards)
	clear_holder(player_cards)
	clear_holder(matched_cards)
	opponent_card_nodes.clear()
	player_card_nodes.clear()

	var opponent_width: float = float(opponent_hand.size()) * CARD_SIZE.x + float(maxi(0, opponent_hand.size() - 1)) * CARD_GAP
	var opponent_start: float = maxf(0.0, (opponent_cards.size.x - opponent_width) / 2.0)
	for i in opponent_hand.size():
		var card := create_card(opponent_hand[i], false, true)
		card.position = Vector2(opponent_start + i * (CARD_SIZE.x + CARD_GAP), 0)
		card.pressed.connect(_on_opponent_card_pressed.bind(i))
		opponent_cards.add_child(card)
		opponent_card_nodes.append(card)

	var player_width: float = float(player_hand.size()) * CARD_SIZE.x + float(maxi(0, player_hand.size() - 1)) * CARD_GAP
	var player_start: float = maxf(0.0, (player_cards.size.x - player_width) / 2.0)
	for i in player_hand.size():
		var card := create_card(player_hand[i], true, false)
		card.position = Vector2(player_start + i * (CARD_SIZE.x + CARD_GAP), 0)
		player_cards.add_child(card)
		player_card_nodes.append(card)

	for i in matched_ranks.size():
		var pair_group := Control.new()
		pair_group.position = Vector2(i * 128.0, 0)
		pair_group.size = Vector2(112, 82)
		matched_cards.add_child(pair_group)
		var left_card := create_card(matched_ranks[i], true, false)
		left_card.scale = Vector2(0.55, 0.55)
		left_card.position = Vector2(0, 5)
		pair_group.add_child(left_card)
		var right_card := create_card(matched_ranks[i], true, false)
		right_card.scale = Vector2(0.55, 0.55)
		right_card.position = Vector2(50, 5)
		pair_group.add_child(right_card)

	set_opponent_cards_enabled(not turn_busy)


func clear_holder(holder: Control) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()


func set_opponent_cards_enabled(enabled: bool) -> void:
	for card in opponent_card_nodes:
		card.disabled = not enabled


func create_card(rank: String, face_up: bool, clickable: bool) -> Button:
	var card := Button.new()
	card.size = CARD_SIZE
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if clickable else Control.CURSOR_ARROW
	apply_card_face(card, rank, face_up)
	return card


func apply_card_face(card: Button, rank: String, face_up: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3

	if face_up:
		style.bg_color = Color("#f8fafc")
		style.border_color = Color("#cbd5e1")
		card.text = rank
		card.add_theme_color_override("font_color", Color("#dc2626") if rank == "JOKER" else Color("#0f172a"))
		card.add_theme_color_override("font_disabled_color", Color("#dc2626") if rank == "JOKER" else Color("#0f172a"))
	else:
		style.bg_color = Color("#7f1d3d")
		style.border_color = Color("#fda4af")
		card.text = "◆\n◆"
		card.add_theme_color_override("font_color", Color("#fecdd3"))
		card.add_theme_color_override("font_disabled_color", Color("#fecdd3"))

	card.add_theme_font_size_override("font_size", 22 if rank == "JOKER" and face_up else 34)
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("disabled", style)
	var hover_style: StyleBoxFlat = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.12)
	card.add_theme_stylebox_override("hover", hover_style)
	card.add_theme_stylebox_override("pressed", hover_style)


func animate_draw(source: Vector2, target: Vector2, rank: String, starts_face_up: bool) -> void:
	var floating := create_card(rank, starts_face_up, false)
	floating.position = source
	floating.z_index = 20
	add_child(floating)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(floating, "position", target, 0.48)
	if not starts_face_up:
		tween.tween_property(floating, "scale:x", 0.0, 0.1)
		tween.tween_callback(apply_card_face.bind(floating, rank, true))
		tween.tween_property(floating, "scale:x", 1.0, 0.1)
	await tween.finished
	floating.queue_free()


func animate_pair_to_pile(rank: String, source: Vector2) -> void:
	var destination := matched_cards.position + Vector2(matched_ranks.size() * 128.0, 8)
	var first := create_card(rank, true, false)
	var second := create_card(rank, true, false)
	first.position = source
	second.position = source + Vector2(22, 0)
	first.z_index = 21
	second.z_index = 22
	add_child(first)
	add_child(second)
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(first, "position", destination, 0.5)
	tween.tween_property(second, "position", destination + Vector2(48, 0), 0.5)
	tween.tween_property(first, "scale", Vector2(0.55, 0.55), 0.5)
	tween.tween_property(second, "scale", Vector2(0.55, 0.55), 0.5)
	await tween.finished
	first.queue_free()
	second.queue_free()
