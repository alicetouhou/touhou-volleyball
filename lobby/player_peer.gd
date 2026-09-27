class_name PlayerPeer

extends Node

var peer_id: int = 0

# -99 is any controller
# -1 and greater restrict to a specific controller
var input_device = -99
var character: String = "alice_margatroid.tres"
var color: Color
var number: int
var local_co_op := false

static func new_player(id) -> PlayerPeer:
	var p = PlayerPeer.new()
	p.peer_id = id
	return p

static func new_cpu_player():
	var p = PlayerPeer.new()
	p.peer_id = -1
	return p

static func serialize(players: Array[PlayerPeer]):
	var out = []
	
	for p in players:
		out.push_back({
			"peer_id": p.peer_id,
			"input_device": p.input_device,
			"character": p.character,
			"color": p.color,
			"number": p.number,
			"local_co_op": p.local_co_op,
		})
	
	return out

static func parse(players: Array) -> Array[PlayerPeer]:
	var out: Array[PlayerPeer] = []

	for info in players:
		var p = PlayerPeer.new()
		p.peer_id = info["peer_id"]
		p.input_device = info["input_device"]
		p.character = info["character"]
		p.color = Color(info["color"])
		p.number = info["number"]
		p.local_co_op = info["local_co_op"]
		out.push_back(p)
	
	return out
		
