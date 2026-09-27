class_name PlayerPeer

extends Node

var peer_id: int = 0

# -99 is any controller
# -1 and greater restrict to a specific controller
var input_device = -99
var character: String = "alice_margatroid.tres"
var color: Color
var number: int
var is_local: bool = false

static func new_player(id) -> PlayerPeer:
	var p = PlayerPeer.new()
	p.peer_id = id
	return p

static func new_local_player(id) -> PlayerPeer:
	var p = PlayerPeer.new()
	p.peer_id = id
	p.is_local = true
	return p

static func new_cpu_player():
	var p = PlayerPeer.new()
	p.peer_id = -1
	return p
