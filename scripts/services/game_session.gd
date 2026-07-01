extends Node

var is_multiplayer_launch := false


func start_singleplayer() -> void:
	is_multiplayer_launch = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


func start_multiplayer() -> void:
	is_multiplayer_launch = true


func clear() -> void:
	is_multiplayer_launch = false
