extends Player

enum Intention {
	Block,
	Reposition,
	Return,
	Set,
	Spike,
	Wait
}
var intention: Intention = Intention.Wait
var actpoints: Array[Array] = [] # [t, L, R, U, D, J, Z, X, C]
var ball_target: Array = [] # [t, x, y, z]

const SPIKE_THRESHOLD_V = 20
const SPIKE_THRESHOLD_Y = 6
var x = 0
var y = 0.

var ball_predictions: Array[Vector3] = []
var player_predictions: Array[Vector3] = []

var can_kick := true
var started := false

var ball: Node3D

func cpu_init(world_ball: Node3D, _world_players: Array[Node]) -> void:
	ball = world_ball

func update_game_state(game_running: bool) -> void:
	started = game_running

func _physics_process(delta: float) -> void:
	super(delta)
	
	# Only run CPU on authority (server)
	if not %ActionSync.is_multiplayer_authority():
		return

	if !started:
		return
	
	ball_predictions = predict_ball_locations(delta)
	
	# Cancel intention if something changed.
	if not Vector3(ball_target[1], ball_target[2], ball_target[3]).is_equal_approx(ball_predictions[ball_target[0]]):
		intention = Intention.Wait
		actpoints = []
		ball_target = []
	
	var gravity = get_gravity()
	# Check each prediction
	player_predictions = []
	for i in len(ball_predictions):
		var p = ball_predictions[i]
		if abs(p.x) <= 0.5 and p.y < SPIKE_THRESHOLD_Y:
			if abs(global_position.x - p.x) - 0.75 * MOVEMENT_SPEED <= i:
				var dropf20 = ceil(SPIKE_THRESHOLD_V / abs(14 * gravity.y) / delta)
				var u_y = 10 if linear_velocity.y > 0 else linear_velocity.y
				if i < dropf20 + ceil((sqrt(pow(linear_velocity.y, 2) + (2 * gravity.y * (p.y - global_position.x + (0.5*14 * gravity.y * pow(dropf20,2))))) - linear_velocity.y) / gravity.y):
					net_spike(delta)
		
		player_predictions.push_back(
			global_position +
			Vector3(0, JUMP_POWER * delta * 5 * (i+1) + gravity.y * (i+1) * (i+1) * delta * 2.5, 0)
		)
		# Will jumping put us in a good position?
		if (
			i >= 1 and
			player_predictions[i].y > position.y + 2. and
			p.y < player_predictions[i].y and
			p.y > player_predictions[i-1].y and 
			on_floor and 
			can_jump and
			abs(p.x - position.x) < 2.
		):
			%ActionSync.jump.rpc()
			can_jump = false
			
	if global_position.distance_squared_to(ball.global_position) >= 1.75:
		can_kick = true
	if (
		global_position.distance_squared_to(ball.global_position) <= 1 and
		ball.global_position < global_position + Vector3(1.5,0.,0.) and
		can_kick
	):
		%ActionSync.kick.rpc()
	
	%ActionSync.direction = Vector2(get_direction(), 0)

func get_direction() -> int:
	# If we have no predictions, do nothing
	if ball_predictions.is_empty():
		return 0
	
	# Pick the latest prediction
	var choice = ball_predictions.back() + Vector3(0.25,0.0,0.0)
	
	if abs(choice.x - self.position.x) < 0.5:
		return 0
	
	if (choice.x < self.position.x):
		return -1
	elif (choice.x == self.position.x):
		return 0
	else:
		return 1
	
func predict_ball_locations(delta: float) -> Array[Vector3]:
	var g = ball.gravity_scale * get_gravity()
	var p = ball.position
	var v = ball.linear_velocity
	var t = delta
	var predictions: Array[Vector3] = []
	for i in range(0,100):
		var new_pos = p + v * t + 0.5 * g * t * t
		
		if new_pos.x < -11.5:
			new_pos.x = -(new_pos.x + 11.5) - 11.5
		if new_pos.x > 11.5:
			new_pos.x = -(new_pos.x - 11.5) + 11.5
				
		predictions.push_back(new_pos)
		if new_pos.y > 1.5:
			t += delta
		else:
			return predictions
	return predictions

func net_spike(delta: float):
	intention = Intention.Spike
	actpoints = []
	
	
