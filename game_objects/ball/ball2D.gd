class_name Ball2D

extends SyncedRigidBody

var kick_requests = []

func add_kick_request(force: SGFixedVector2, direction: SGFixedVector2):
	kick_requests.push_back(
		{
			"force_x": force.x,
			"force_y": force.y,
			"direction_x": direction.x,
			"direction_y": direction.y,
		}
	)

func _network_postprocess(_input):
	for k in kick_requests:
		apply_impulse(
			SGFixed.vector2(k["force_x"], k["force_y"]),
			SGFixed.vector2(k["direction_x"], k["direction_y"])
		)
	kick_requests = []
	
	super._network_process()

func _save_state() -> Dictionary:
	var state = super._save_state()
	state["kick_requests"] = kick_requests.duplicate_deep()
	return state

func _load_state(state):
	kick_requests = state["kick_requests"]
	super._load_state(state)
