extends Node

const SOUND_PATHS := {
	"ui_select": "res://assets/audio/sfx/ui_select.ogg",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.ogg",
	"ui_error": "res://assets/audio/sfx/ui_error.ogg",
	"jump": "res://assets/audio/sfx/jump.ogg",
	"card_shuffle": "res://assets/audio/sfx/card_shuffle.ogg",
	"card_draw": "res://assets/audio/sfx/card_draw.ogg",
	"card_pair": "res://assets/audio/sfx/card_pair.ogg",
	"coin": "res://assets/audio/sfx/coin.ogg",
	"reload": "res://assets/audio/sfx/reload.ogg",
	"hit": "res://assets/audio/sfx/hit.ogg",
	"player_hit": "res://assets/audio/sfx/player_hit.ogg",
	"enemy_down": "res://assets/audio/sfx/enemy_down.ogg",
	"gunshot": "res://assets/audio/sfx/gunshot.ogg",
	"gunshot_auto": "res://assets/audio/sfx/gunshot_auto.wav",
	"boss_fire": "res://assets/audio/sfx/boss_fire.ogg",
	"boss_ice": "res://assets/audio/sfx/boss_ice.ogg",
	"boss_lightning": "res://assets/audio/sfx/boss_lightning.ogg",
	"boss_charge": "res://assets/audio/sfx/boss_charge_clean.wav",
}

const PLAYER_COUNT := 14
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var unique_players: Dictionary = {}


func _ready() -> void:
	ensure_sfx_bus()
	for key in SOUND_PATHS:
		streams[key] = load(SOUND_PATHS[key])
	for index in PLAYER_COUNT:
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % index
		player.bus = "SFX"
		add_child(player)
		players.append(player)


func play(sound_name: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.0) -> void:
	if not streams.has(sound_name) or players.is_empty():
		return
	var player := find_available_player()
	player.stream = streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.2, pitch + randf_range(-pitch_jitter, pitch_jitter))
	player.play()


func play_unique(sound_name: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.0) -> void:
	if not streams.has(sound_name) or players.is_empty():
		return
	# Exclusive sounds must never retain a voice that the shared pool can reuse.
	if not unique_players.has(sound_name):
		var dedicated := AudioStreamPlayer.new()
		dedicated.bus = "SFX"
		add_child(dedicated)
		unique_players[sound_name] = dedicated
	var player: AudioStreamPlayer = unique_players[sound_name]
	player.stream = streams[sound_name]
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.2, pitch + randf_range(-pitch_jitter, pitch_jitter))
	player.play()


func find_available_player() -> AudioStreamPlayer:
	for offset in players.size():
		var index := (next_player + offset) % players.size()
		if not players[index].playing:
			next_player = (index + 1) % players.size()
			return players[index]
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	return player


func ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus(AudioServer.bus_count)
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
