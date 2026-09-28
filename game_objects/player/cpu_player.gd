extends Player

enum Intention {
	COUNTERSPIKE,
	COUNTERSET,
	REPOSITION,
	RETURN,
	SET,
	SPIKE,
	STANDBY
}
var intention: Intention = Intention.STANDBY
var actpoints: Array[Array] = [] # [t, x, J, D, Z, X, C]
var ball_target # [t, x, y, z]

# These are basically cached calculations.
var MAX_JUMP: float
var MAX_JUMP_TIME: float
var I: int
var intention_cache

const COUNTERSPIKE_THRESHOLD_V = 8
const COUNTERSPIKE_THRESHOLD_Y_MIN = 3.25
const COUNTERSPIKE_THRESHOLD_Y_MAX = 6.5
const SPIKE_Y_MIN = 3.5
var x = 0
var y = 0.

var ball_predictions: Array[Vector3] = []
var player_predictions: Array[Vector3] = []

var can_kick := true
var started := false

var ball: Node3D

func cpu_init(world_ball: Node3D, _world_players: Array[Node]) -> void:
	ball = world_ball
	print(time, " init")
	
	var u = JUMP_POWER / mass
	MAX_JUMP_TIME = u / -get_gravity().y
	MAX_JUMP = (u * MAX_JUMP_TIME) + (0.5 * pow(MAX_JUMP_TIME, 2) * get_gravity().y)

func update_game_state(game_running: bool) -> void:
	started = game_running
	I = sign(global_position.x)

func _physics_process(delta: float) -> void:
	%Debug1.text = ["Counterspike", "Counterset", "Reposition", "Return", "Set", "Spike", "Wait"][intention] + (str(ball_target[0]) if ball_target else "")
	%Debug2.text = str(MAX_JUMP) + "\n" + (str(intention_cache * 60) if intention_cache else "")
	
	for act in actpoints:
		act[0] -= 1
		if act[0] == 0:
			actpoints.pop_front()
	if ball_target:
		ball_target[0] -= 1
		if ball_target[0] < 0:
			ball_target = []
			print(time, " cancel")
			reset_intentions()
	
	if !started:
		return
	
	ball_predictions = predict_ball_locations(delta)
	
	# Cancel intention if something changed.
	if ball_target:
		if ball_predictions.size() <= ball_target[0]:
			reset_intentions()
		elif (Vector3(ball_target[1], ball_target[2], ball_target[3]) - ball_predictions[ball_target[0]]).length() > 0.01:
			var min_diff = 999999.
			var min_i = 0
			for i in range(ball_target[0], ball_target[0] + 5):
				if i < 0 or i >= ball_predictions.size():
					continue
				var diff = Vector3(ball_target[1], ball_target[2], ball_target[3]).distance_to(ball_predictions[i])
				if diff < min_diff:
					min_diff = diff
					min_i = i
			if min_diff > 0.2:
				reset_intentions()
			else:
				ball_target = [min_i, ball_predictions[min_i].x, ball_predictions[min_i].y, ball_predictions[min_i].z]
	
	var direction = Vector2.ZERO
	var gravity = get_gravity()
	if intention == Intention.STANDBY:
		# Check each prediction
		player_predictions = []
		var target_selected = false
		for i in len(ball_predictions):
			if target_selected:
				continue
			var p = ball_predictions[i]
			if abs(p.x + 0.2*I) <= 0.6 and p.y >= p.x*I + COUNTERSPIKE_THRESHOLD_Y_MIN*I and p.y < COUNTERSPIKE_THRESHOLD_Y_MAX:
				if not ((global_position.x - p.x - 1.5*I) * MOVEMENT_SPEED > i * delta and (p.x + 1.*I - global_position.x) > i * delta):
					var dropfv = ceil(COUNTERSPIKE_THRESHOLD_V / abs(14 * gravity.y) / delta)
					var u_y = 10. if linear_velocity.y <= 0. else linear_velocity.y
					if i > dropfv + ceil((sqrt(pow(u_y, 2) + (2 * gravity.y * (p.y - global_position.y + (0.5*14 * -gravity.y * pow(dropfv * delta,2))))) - u_y) / gravity.y) + (ceil(sqrt(pow(u_y, 2) + (2*14*gravity.y*global_position.y) - u_y) if linear_velocity.y < 0. else 0.)):
						if not (linear_velocity.y > 0 and i * delta < (u_y + sqrt(pow(u_y, 2) + 2 * gravity.y * (p.y - global_position.y))) / 2 * gravity.y):
							counterspike(i, p)
							target_selected = true
		
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
				#%ActionSync.jump.rpc()
				can_jump = false
		direction.x = get_direction()
		if not on_floor:
			direction.y = -1
		if (
			global_position.distance_squared_to(ball.global_position) <= 1.75 and
			ball.global_position < global_position + Vector3(1.5,0.,0.)
		):
			%ActionSync.kick.rpc()
	if intention == Intention.COUNTERSPIKE:
		var target = ball_predictions[ball_target[0]]
		if ball_target[0] <= ceil(sqrt(2 * (target.y - global_position.y) / (14 * gravity.y))) / delta:
			spike()
		else:
			if ball_target[0] < 2 or target.x + 1.5*I < global_position.x:
				direction.x = -1
			elif target.x + 1.*I > global_position.x:
				direction.x = 1
			if on_floor and ball_target[0] <= (MAX_JUMP_TIME + intention_cache) / delta:
				%ActionSync.jump.rpc()
	if intention == Intention.SPIKE:
		var target = ball_predictions[ball_target[0]]
		direction.y = -1
		
		if ball_target[0] < 2 or target.x + 1.5*I < global_position.x:
			direction.x = -1
		elif target.x + 1.*I > global_position.x:
			direction.x = 1
		
		if ball_target[0] == 0:
			%ActionSync.kick.rpc()
	
	%ActionSync.direction = direction
	%Debug3.text = str(ball_target)
	super(delta)

func get_direction() -> int:
	# If we have no predictions, do nothing
	if ball_predictions.is_empty():
		return 0
	
	# Pick the latest prediction
	var choice = ball_predictions.back() + Vector3(0.25,0.0,0.0)
	
	if abs(choice.x + 0.5 - self.position.x) < 0.5:
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
	var t = 1
	var predictions: Array[Vector3] = []
	for i in range(0,250):
		var T = t * delta
		var new_pos = p + v * T + 0.5 * g * T * T
		
		if new_pos.x < -11.54:
			new_pos.x = -(new_pos.x + 11.54) - 11.54
		if new_pos.x > 11.54:
			new_pos.x = -(new_pos.x - 11.54) + 11.54
		
		predictions.push_back(new_pos)
		
		if new_pos.y > 1.5:
			t += 1
		else:
			return predictions
	return predictions

func reset_intentions():
	print(time, " standby")
	intention = Intention.STANDBY
	actpoints = []
	ball_target = null

func counterspike(t: int, p: Vector3):
	print(time, " counterspike")
	intention = Intention.COUNTERSPIKE
	ball_target = [t, p.x, p.y, p.z]
	print(ball_target)
	# Max spike time
	intention_cache = sqrt(2 * (p.y - MAX_JUMP) / get_gravity().y)

func spike():
	print(time, " spike")
	intention = Intention.SPIKE
	intention_cache = null
