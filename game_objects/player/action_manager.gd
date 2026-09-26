extends MultiplayerSynchronizer


## Client's target for movement (except jumping).
@export var direction = Vector2i.ZERO

## Simulated on_action_just_pressed via rpc.
## Reset per-client in _physics_process of player.
@export var kicking = false
@export var jumping = false
@export var supering = false

@rpc("call_local")
func kick() -> void:
	kicking = true

@rpc("call_local")
func jump() -> void:
	jumping = true

@rpc("call_local")
func trigger_super() -> void:
	supering = true

func _ready():
	set_process(get_multiplayer_authority() == multiplayer.get_unique_id())

## Only runs on client, see _ready.
## TODO: Add multiple inputs.
func _process(_delta: float) -> void:
	direction = Input.get_vector("left", "right", "down", "up")
	if direction.y > 0: # Jumping is handled by 
		direction.y = 0
	
	if Input.is_action_just_pressed("up"):
		jump.rpc()
	if Input.is_action_just_pressed("kick"):
		kick.rpc()
	if Input.is_action_just_pressed("super"):
		trigger_super.rpc()
