extends Label


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if multiplayer.is_server():
		return
	var ping = multiplayer.multiplayer_peer.get_peer(1).get_statistic(
		ENetPacketPeer.PEER_ROUND_TRIP_TIME
	)

	text = "%sms" % ping
