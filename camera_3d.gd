extends Camera3D

@export var decay = 0.5  # How quickly the shaking stops [0, 1].
@export var max_offset = Vector2(1, .75)  # Maximum hor/ver shake in pixels.
@export var max_roll = 0.1  # Maximum rotation in radians (use sparingly).

var trauma = 0.0  # Current shake strength.
var trauma_power = 1  # Trauma exponent. Use [2, 3].
var target_object: Node3D

func add_trauma(amount: float):
	trauma = min(trauma + amount, 1.0)

func shake():
	var amount = trauma
	rotation.z = max_roll * amount * randf_range(-1, 1)
	h_offset = max_offset.x * amount * randf_range(-1, 1)
	v_offset = max_offset.y * amount * randf_range(-1, 1)

func new_target_object(object: Node3D) -> void:
	target_object = object

func _ready():
	make_current()
	randomize()

func _process(delta):
	if trauma:
		trauma = max(trauma - decay * delta, 0)
		shake()

func _physics_process(_delta: float) -> void:
	if not target_object:
		return
	var target_position = target_object.position
	
	position.x = -1 * sign(target_position.x) * pow(abs(target_position.x), 1. / 3.) / 20.
	
	look_at(Vector3(-position.x, position.y, 0))
