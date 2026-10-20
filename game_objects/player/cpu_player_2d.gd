extends Player2D

enum Intention {
	COUNTERSPIKE,
	COUNTERSET,
	HARASS,
	REPOSITION,
	RETURN,
	SET,
	SPIKE,
	STANDBY
}
var intention: Intention = Intention.STANDBY
var actpoints: Array[Array] = [] # [t, x, J, D, Z, X, C]
var ball_target # [t, x, y, z]
var tolerance: int = 0
var previews = []
var prev: SGFixedVector2
var tracker: Array[Array] = []

# These are basically cached calculations.
var MAX_JUMP: float
var MAX_JUMP_TIME: float
var I: int
var intention_cache

const COUNTERSPIKE_THRESHOLD_V_Y = 15 * SGFixed.ONE
const COUNTERSPIKE_THRESHOLD_Y_MIN = 3.25 * SGFixed.ONE
const COUNTERSPIKE_THRESHOLD_Y_MAX = 6.5 * SGFixed.ONE
const SPIKE_Y_MIN = 3.5 * SGFixed.ONE

const DELTA = 2185

var x = 0
var y = 0.

var ball_predictions: Array[SGFixedVector2] = []
var player_predictions: Array[SGFixedVector2] = []

var can_kick := true
var started := false
var can_jump := false

func cpu_init(world_ball: Ball2D, _world_players: Array[Node]) -> void:
	ball = world_ball
	print(SYNCED_ticks, " init")
	
	var u = JUMP / mass
	MAX_JUMP_TIME = u / -gravity_y
	MAX_JUMP = (u * MAX_JUMP_TIME) + (0.5 * pow(MAX_JUMP_TIME, 2) * gravity_y)

func update_game_state(game_running: bool) -> void:
	started = game_running
	I = sign(fixed_position.x)

func _network_process(_input) -> void:
	%Debug1.text = ["Counterspike", "Counterset", "Harrass", "Reposition", "Return", "Set", "Spike", "Wait"][intention] + (str(ball_target[0]) if ball_target else "")
	%Debug2.text = str(MAX_JUMP) + "\n" + (str(intention_cache * 60) if intention_cache else "")

	for act in actpoints:
		act[0] -= 1
		if act[0] == 0:
			actpoints.pop_front()
	if ball_target:
		ball_target[0] -= 1
		if ball_target[0] < 0:
			ball_target = []
			print(SYNCED_ticks, " cancel")
			reset_intentions()
	
	if !started:
		return
	
	if not ball:
		ball = get_tree().get_first_node_in_group("ball")

	ball_predictions = predict_ball_locations(ball.velocity, 20)
	# I cound not get the code working past this point -jake
	return
	
	# Cancel intention if something changed.
	if ball_target:
		if ball_predictions.size() <= ball_target[0]:
			reset_intentions()
		elif (SGFixed.vector2(ball_target[1], ball_target[2]).sub(ball_predictions[ball_target[0]])).length() > 0.01:
			var min_diff = 999999. * SGFixed.ONE
			var min_i = 0
			for i in range(ball_target[0], ball_target[0] + 5):
				if i < 0 or i >= ball_predictions.size():
					continue
				var diff = SGFixed.vector2(ball_target[1], ball_target[2]).distance_to(ball_predictions[i])
				if diff < min_diff:
					min_diff = diff
					min_i = i
			if min_diff > 0.2:
				reset_intentions()
			else:
				ball_target = [min_i, ball_predictions[min_i].x, ball_predictions[min_i].y, ball_predictions[min_i].z]
	
	var direction = Vector2.ZERO
	if intention == Intention.STANDBY:
		# Check each prediction
		player_predictions = []
		var target_selected = false
		for i in len(ball_predictions):
			if target_selected:
				continue
			var p = ball_predictions[i]
			# Harass Decision
			# Counterspike decision
			if abs(p.x + 0.2*I) <= 0.6 and p.y >= p.x*I + COUNTERSPIKE_THRESHOLD_Y_MIN*I and p.y < COUNTERSPIKE_THRESHOLD_Y_MAX:
				if not ((fixed_position.x - p.x - 1.5*I) * SPEED > i * DELTA and (p.x + 1.*I - fixed_position.x) > i * DELTA):
					var dropfv = ceil(COUNTERSPIKE_THRESHOLD_V_Y / abs(14 * gravity_y) / DELTA)
					var u_y = 10. if velocity.y <= 0. else velocity.y
					if i > dropfv + ceil((sqrt(pow(u_y, 2) + (2 * gravity_y * (p.y - fixed_position.y + (0.5*14 * -gravity_y * pow(dropfv * DELTA,2))))) - u_y) / gravity_y) + (ceil(sqrt(pow(u_y, 2) + (2*14*gravity_y*fixed_position.y) - u_y) if velocity.y < 0. else 0.)):
						if not (velocity.y > 0 and i * DELTA < (u_y + sqrt(pow(u_y, 2) + 2 * gravity_y * (p.y - fixed_position.y))) / 2 * gravity_y):
							counterspike(i, p)
							target_selected = true
		
			player_predictions.push_back(
				fixed_position.add(
				SGFixed.vector2(0, JUMP * DELTA * 5 * (i+1) + gravity_y * (i+1) * (i+1) * DELTA * 2.5))
			)
			# Will jumping put us in a good position?
			if (
				i >= 1 and
				player_predictions[i].y > position.y + 2. and
				p.y < player_predictions[i].y and
				p.y > player_predictions[i-1].y and 
				SYNCED_is_on_floor_USE_THIS_ONE and 
				can_jump and
				abs(p.x - position.x) < 2.
			):
				#%ActionSync.jump.rpc()
				can_jump = false
		direction.x = get_direction()
		if not SYNCED_is_on_floor_USE_THIS_ONE:
			direction.y = -1
		if (
			fixed_position.distance_squared_to(ball.fixed_position) <= 1.75 and
			ball.fixed_position.length() < fixed_position.add(SGFixed.vector2(SGFixed.ONE + SGFixed.HALF,0.)).length() and
			(SYNCED_is_on_floor_USE_THIS_ONE or ball.fixed_position.x < fixed_position.x)
		):
			SYNCED_kicking_for_ticks += 1
	if intention == Intention.COUNTERSPIKE:
		var target = ball_predictions[ball_target[0]]
		if ball_target[0] <= ceil(sqrt(2 * (target.y - fixed_position.y) / (gravity_y * (14. if direction.y != -1 else 1.))) / DELTA):
			spike()
		else:
			if ball_target[0] < 2 or target.x + 1.5*I < fixed_position.x:
				direction.x = -1
			elif target.x + 1.*I > fixed_position.x:
				direction.x = 1
			if SYNCED_is_on_floor_USE_THIS_ONE and ball_target[0] <= (MAX_JUMP_TIME + intention_cache) / DELTA:
				SYNCED_jumping_for_ticks += 1
	if intention == Intention.SPIKE:
		var target = ball_predictions[ball_target[0]]
		direction.y = -1
		
		if ball_target[0] < 1 or target.x + 1.5*I < fixed_position.x:
			direction.x = -1
		elif target.x + 1.*I > fixed_position.x:
			direction.x = 1
		
		if fixed_position.x*I > ball.fixed_position.x*I and abs(fixed_position.x - ball.fixed_position.x) <= 1.56 * SGFixed.ONE and abs(fixed_position.y - ball.fixed_position.y) <= SGFixed.ONE:
			var kick_preds = predict_ball_locations(fixed_position.direction_to(ball.fixed_position).mul(KICK_POWER), 40)
			var can_kick = true
			for pred in kick_preds:
				# If it hits the net:
				if can_kick and ball.fixed_position.x*I > 0 and pred.x*I > 0 and pred.x*I <= 0.46 * SGFixed.ONE and pred.y < 2.75 * SGFixed.ONE:
					can_kick = false
			if can_kick:
				if kick_preds[0].y > ball.fixed_position.y:
					direction.y = 0
				# I'm not sure where velocity is added to the ball.
				# This just emits a signal that creates the particles for kicking.
				kick.emit(true)
	
	# %ActionSync.direction = direction
	
	var FRAMES = 10
	var txt = ""
	var curr = ball.fixed_position
	var vel = ball.velocity
	var k = 0.5 * gravity_y * pow(DELTA,2)
	prev = ball_predictions[0]
	while tracker.size() <= FRAMES:
		tracker.push_back([])
	for i in range(FRAMES):
		while tracker[i].size() <= i:
			tracker[i].push_back(null)
	for i in range(FRAMES):
		if tracker[i][0]:
			txt += str(round((curr.y-tracker[i][0].y) / k))
		else:
			txt += "--"
		if not i == FRAMES - 1:
			txt += " | "
			
	%Debug3.text = txt
	
	for i in range(FRAMES):
		for j in range(i):
			tracker[i][j] = tracker[i][j+1]
		tracker[i][i] = (ball_predictions[i] if ball_predictions.size() > i else null)
	
	super(_input)

func get_direction() -> int:
	# If we have no predictions, do nothing
	if ball_predictions.is_empty():
		return 0
	
	# Pick the latest prediction
	var choice = ball_predictions.back().add(SGFixed.vector2(SGFixed.ONE * .25, 0))
	
	if abs(choice.x + 0.25 * SGFixed.ONE - self.fixed_position.x) < 0.25 * SGFixed.ONE:
		return 0

	if (choice.x < self.fixed_position.x):
		return -1
	elif (choice.x == self.fixed_position.x):
		return 0
	else:
		return 1

func predict_ball_locations(v: SGFixedVector2, n: int, step_size: int = 50) -> Array[SGFixedVector2]:
	var g := SGFixed.vector2(ball.gravity_x, ball.gravity_y)
	var p := ball.fixed_position
	var t := 1
	var predictions: Array[SGFixedVector2] = []
	
	for i in range(0,n):
		var T: int = t * DELTA

		var vt = v.mul(T)
		var half_g = g.mul(SGFixed.HALF)
		var half_g_t_squared = half_g.mul(SGFixed.pow(T, SGFixed.TWO))
		var i_plus_one = SGFixed.ONE * (i + 1)
		var half_i_plus_one_g_delta_squared = g.mul(SGFixed.mul(SGFixed.mul(i_plus_one, SGFixed.HALF), SGFixed.pow(DELTA, SGFixed.TWO)))

		var new_pos = p.add(vt).add(half_g_t_squared).add(half_i_plus_one_g_delta_squared)

		# Bouncing?
		if new_pos.x < -3000000:
			new_pos.x = -(new_pos.x + 3000000) - 3000000
		if new_pos.x > 129099248:
			new_pos.x = -(new_pos.x - 129099248) + 129099248
		if new_pos.y > 59000000:
			new_pos.y = -(new_pos.y - 59000000) + 59000000
		
		predictions.push_back(new_pos)
		
		if new_pos.y > (SGFixed.ONE + SGFixed.HALF):
			# Step is large to reduce lag
			t += step_size
		else:
			visualize_predictions()
			return predictions

	visualize_predictions()
	return predictions

func visualize_predictions():
	for p in previews:
		p.queue_free()
		previews.erase(p)
	for i in ball_predictions + player_predictions:
		var p = $"Pred".duplicate()
		$"..".add_child(p)
		p.position = i.to_float()
		previews.push_back(p)
	if ball_target:
		%Target.global_position = Vector2(SGFixed.to_float(ball_target[1]), SGFixed.to_float(ball_target[2]))
	else:
		%Target.global_position = Vector2.ZERO

func reset_intentions():
	print(SYNCED_ticks, " standby")
	intention = Intention.STANDBY
	actpoints = []
	ball_target = null

func counterspike(t: int, p: SGFixedVector2):
	print(SYNCED_ticks, " counterspike")
	intention = Intention.COUNTERSPIKE
	ball_target = [t, p.x, p.y]
	# Max spike time
	intention_cache = sqrt(2 * (p.y - MAX_JUMP) / gravity_y)

func spike():
	print(SYNCED_ticks, " spike")
	intention = Intention.SPIKE
	intention_cache = null
