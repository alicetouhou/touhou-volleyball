extends MultiplayerSynchronizer


## If true, blocks client input.
@export var disable_input := false
@export var input_device := -99

## Direction is the authoritive direction sent to the server.
@export var direction := Vector2.ZERO
## Local direction is purely local and is used by the player on our client to reduce percieved delay.
var local_direction := Vector2.ZERO
var action_strength := Vector4.ZERO

## Simulated on_action_just_pressed via rpc.
## Reset per-client in _physics_process of player.
@export var kicking := false
@export var jumping := false
@export var supering := false

@rpc("call_local")
func kick() -> void:
	kicking = true

@rpc("call_local")
func jump() -> void:
	jumping = true

@rpc("call_local")
func trigger_super() -> void:
	supering = true

func _process(_delta: float) -> void:
	if not is_multiplayer_authority() or disable_input:
		return
	
	local_direction = Vector2(
		action_strength.y - action_strength.x,
		action_strength.z - action_strength.w,
	)
	direction = local_direction
