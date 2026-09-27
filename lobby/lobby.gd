extends Node


signal server_started
signal players_updated(player_dict)
signal server_failed
signal server_connected
signal connection_stopped

const PORT = 7000
const IP_ADDRESS = "127.0.0.1"
const MAX_PLAYERS = 2
const DEFAULT_PLAYER = {"character": "alice_margatroid.tres"}
const COLORS = [Color.RED, Color.BLUE]

var connected = false
var players: Dictionary[int, Dictionary] = {}

var lobby_id: int

func host_game() -> void:
	Steam.lobby_created.connect(lobby_created)
	Steam.createLobby(Steam.LOBBY_TYPE_FRIENDS_ONLY)

func lobby_created(status, new_id) -> void:
	if status != 1:
		print("Lobby failed to create :(")
		return
	lobby_id = new_id
	Steam.activateGameOverlay("friend")

	var server = SteamMultiplayerPeer.new()
	var err = server.create_host(0)
	if not err:
		server_started.emit()
		multiplayer.peer_connected.connect(peer_connected)
		multiplayer.peer_disconnected.connect(peer_disconnected)
		peer_connected(1)
		connected = true
		multiplayer.multiplayer_peer = server

func join_game() -> void:
	pass

func lobby_joined(lobby: int, _permissions: int, locked: int, response: int) -> void:
	if response != Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		print("Joining lobby failed")
		return
	var new_owner = Steam.getLobbyOwner(lobby)
	
	var client = SteamMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(server_connected.emit)
	multiplayer.connection_failed.connect(server_failed.emit)
	multiplayer.server_disconnected.connect(stop_connection)
	
	var err = client.create_client(new_owner)
	if not err:
		connected = true
		multiplayer.multiplayer_peer = client

func stop_connection() -> void:
	# Test signal connections as multiplayer.is_server may be invalid by now.
	if multiplayer.peer_connected.is_connected(peer_connected):
		multiplayer.peer_connected.disconnect(peer_connected)
		multiplayer.peer_disconnected.disconnect(peer_disconnected)
	elif multiplayer.connected_to_server.is_connected(server_connected.emit):
		multiplayer.connected_to_server.disconnect(server_connected.emit)
		multiplayer.connection_failed.disconnect(server_failed.emit)
		multiplayer.server_disconnected.disconnect(stop_connection)
	
	connected = false
	
	connection_stopped.emit()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {}

func peer_connected(id: int) -> void:
	players[id] = DEFAULT_PLAYER.duplicate()
	players[id]["number"] = len(players)
	players[id]["color"] = COLORS[len(players) - 1]
	if id == 1:
		players[id]["character"] = (%Characters.selected.resource_path.split("/") as Array).back()
	on_players_updated.rpc(players)

func peer_disconnected(id: int) -> void:
	players.erase(id)
	on_players_updated.rpc(players)

@rpc("any_peer", "call_local")
func set_player_character(resource_path: String) -> void:
	players[multiplayer.get_remote_sender_id()]["character"] = resource_path
	players_updated.emit(players)

@rpc("call_local")
func on_players_updated(new_player_dict: Dictionary) -> void:
	players = new_player_dict
	players_updated.emit(players)

func start_game() -> void:
	%UI.show()
	%LobbyOverlay.hide()
	$Level.start_game.rpc_id(1)
