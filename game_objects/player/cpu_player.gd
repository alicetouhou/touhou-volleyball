extends Player

enum Intention {
	COUNTERSET,
	COUNTERSPIKE,
	DJUMP,
	HARASS,
	REPOSITION,
	RETURN,
	SET,
	SPIKE,
	START,
	STANDBY
}
var intention: Intention = Intention.STANDBY
var actpoints: Array[Array] = [] # [t, x, J, D, Z, X, C]
var ball_target # [t, x, y, z]
var harassment: bool = true
var previews = [] # Debug
var prev: Vector3 # Debug
var tracker: Array[Array] = [] # Debug

# These are basically cached calculations.
var ALLIES: Array[Player] = []
var OPPONENTS: Array[Player] = []
var MAX_JUMP: float
var MAX_JUMP_TIME: float
var F_NET: int
var I: int # Which side is this on
var intention_cache
var jumped = false # Debug

const COUNTERSPIKE_THRESHOLD_V_Y = 15
const COUNTERSPIKE_THRESHOLD_Y_MIN = 3.25
const COUNTERSPIKE_THRESHOLD_Y_MAX = 5
const SPIKE_Y_MIN = 3.5

var ball_predictions: Array[Vector3] = []
var player_predictions: Array[Vector3] = []

var can_kick := true
var started := false

var ball: Node3D

func cpu_init(world_ball: Node3D, world_players: Array[Node]) -> void:
	ball = world_ball
	
	var me: int
	for i in len(world_players):
		if world_players[i] == self:
			me = i
	for i in len(world_players):
		var player = world_players[i]
		if i == me:
			continue
		if player.side == side:
			ALLIES.push_back(player)
		else:
			OPPONENTS.push_back(player)
	#I = floor((s + 1) / 2)
	
	var u = JUMP_POWER / mass
	MAX_JUMP_TIME = u / -get_gravity().y
	MAX_JUMP = (u * MAX_JUMP_TIME) + (0.5 * pow(MAX_JUMP_TIME, 2) * get_gravity().y)

func update_game_state(game_running: bool) -> void:
	started = game_running
	
	I = sign(global_position.x)

func _physics_process(delta: float) -> void:
	%Debug1.text = ["Counterset", "Counterspike", "DJump", "Harass", "Reposition", "Return", "Set", "Spike", "Start", "Standby"][intention] + (str(ball_target[0]) if ball_target else "")
	%Debug2.text = str(MAX_JUMP) + "\n" + (str(intention_cache * 60) if (intention_cache and not intention_cache is bool) else "")
	
	for act in actpoints:
		act[0] -= 1
		if act[0] == 0:
			actpoints.pop_front()
	if ball_target:
		ball_target[0] -= 1
		if ball_target[0] < 0:
			ball_target = []
			reset_intentions()
	
	if !started:
		intention = Intention.START
		intention_cache = true
	
	ball_predictions = predict_ball_locations(delta, ball.linear_velocity, 100)
	
	# Cancel intention if something changed.
	if ball_target:
		if ball_predictions.size() <= ball_target[0]:
			reset_intentions()
		elif (Vector3(ball_target[1], ball_target[2], ball_target[3]) - ball_predictions[ball_target[0]]).length() > 0.01:
			var min_diff = 999999.
			var min_i = 0
			for i in range(ball_target[0] - 2, ball_target[0] + 2):
				if i < 0 or i >= ball_predictions.size():
					continue
				var diff = Vector3(ball_target[1], ball_target[2], ball_target[3]).distance_to(ball_predictions[i])
				if diff < min_diff:
					min_diff = diff
					min_i = i
			if min_diff > 0.002:
				reset_intentions()
			else:
				ball_target = [min_i, ball_predictions[min_i].x, ball_predictions[min_i].y, ball_predictions[min_i].z]
	
	var direction = Vector2.ZERO
	var gravity = get_gravity()
	if intention == Intention.DJUMP:
		if on_floor or intention_cache[3]:
			intention_cache[0] -= 1
		if intention_cache[0] == F_NET or intention_cache == 0:
			%ActionSync.jump.rpc()
		if intention_cache == F_NET+1 or intention_cache[0] <= 1:
			direction.y = -1
		if (sign(global_position.x == sign(ball_target[1])) and abs(global_position.x) > .32) or (sign(global_position.x) != sign(ball_target[1]) and global_position.x * sign(ball_target[1]) < 0.32):
			direction.x = -sign(global_position.x)
	if intention == Intention.START:
		if not jumped and on_floor:
			intention_cache = true
			%ActionSync.jump.rpc()
			jumped = true
		else:
			jumped = false
		if global_position.y > 2.75:
			intention_cache = false
		if not intention_cache:
			direction.y = -1
		if abs(global_position.x) > .2:
			direction.x = -sign(global_position.x)
		direction.x = -sign(global_position.x)
		print([global_position.y,on_floor,linear_velocity.y,direction.y,jumped])
	if intention == Intention.STANDBY:
		# Check each prediction
		player_predictions = []
		var target_selected = false
		for i in len(ball_predictions):
			if target_selected:
				continue
			var p = ball_predictions[i]
			var dp = dp(global_position, p)
			var dtx = dtx(global_position.x, p.x, MOVEMENT_SPEED)
			var dty = dty(global_position.y, p.y, JUMP_POWER / mass if on_floor else linear_velocity.y, gravity.y)
			# Harass Decision
			var harassable = harassment
			for player in OPPONENTS:
				if not harassable:
					continue
				#print([p.x,I,max(abs(p.x - global_position.x) + (1./MOVEMENT_SPEED if sign(p.x-global_position.x) == sign(p.x-player.global_position.x) else 0)),max(abs(p.x - player.global_position.x))])
				if sign(p.x) == I or max((abs(dp.x) + (1 if sign(dp.x) == sign(p.x-player.global_position.x) else 0)) / MOVEMENT_SPEED, dty) > max(abs(p.x - player.global_position.x) / player.MOVEMENT_SPEED, 0):
					harassable = false
			if harassable:
				harass(i, p)
				target_selected = true
			# Counterspike decision
			if abs(p.x + 0.2*I) <= 0.6 and p.y >= p.x*I + COUNTERSPIKE_THRESHOLD_Y_MIN*I and p.y < COUNTERSPIKE_THRESHOLD_Y_MAX:
				if not ((global_position.x - p.x - 1.5*I) * MOVEMENT_SPEED > i * delta and (p.x + 1.*I - global_position.x) > i * delta):
					var dropfv = ceil(COUNTERSPIKE_THRESHOLD_V_Y / abs(14 * gravity.y) / delta)
					var u_y = 10. if linear_velocity.y <= 0. else linear_velocity.y
					if i > dropfv + ceil((sqrt(pow(u_y, 2) + (2 * gravity.y * (p.y - global_position.y + (0.5*14 * -gravity.y * pow(dropfv * delta,2))))) - u_y) / gravity.y) + (ceil(sqrt(pow(u_y, 2) + (2*14*gravity.y*global_position.y) - u_y) if linear_velocity.y < 0. else 0.)):
						if not (linear_velocity.y > 0 and i * delta < (u_y + sqrt(pow(u_y, 2) + 2 * gravity.y * (p.y - global_position.y))) / 2 * gravity.y):
							counterspike(i, p)
							target_selected = true
							continue
		
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
			ball.global_position < global_position + Vector3(1.5,0.,0.) and
			(on_floor or ball.global_position.x < global_position.x) and 
			ball.global_position.x*I >= 0
		):
			cpu_kick(direction)
	if intention == Intention.HARASS:
		var target = ball_predictions[ball_target[0]]
		if ball_target[0] <= ceil(sqrt(2 * (target.y - global_position.y) / (gravity.y * (14. if direction.y != -1 else 1.))) / delta):
			spike()
		else:
			var onefm = MOVEMENT_SPEED * delta
			var dp = dp(global_position, target)
			var ball_sandwiched = false # Only by opponents
			if len(OPPONENTS) > 1:
				var side
				for player in OPPONENTS:
					var this_side = sign(dp(player.global_position, target).x)
					if ball_sandwiched:
						continue
					if side and side != this_side:
						ball_sandwiched = true
					side = this_side
			if ball_sandwiched and abs(dp.x) >= onefm:
					direction = -sign(dp.x)
			else:
				var opponent_side = sign(dp(OPPONENTS[0].global_position, target).x)
				if sign(dp.x) != opponent_side and abs(dp.x) > 1.4:
					direction.x = -1
				elif sign(dp.x) == opponent_side and abs(dp.x) > 1.4:
					direction.x = 1
	if intention == Intention.COUNTERSPIKE:
		var target = ball_predictions[ball_target[0]]
		if ball_target[0] <= ceil(sqrt(2 * (target.y - global_position.y) / (gravity.y * (14. if direction.y != -1 else 1.))) / delta):
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
		
		if ball_target[0] < 1 or target.x + 1.5*I < global_position.x:
			direction.x = -1
		elif target.x + 1.*I > global_position.x:
			direction.x = 1
		
		if global_position.x*I > ball.global_position.x*I and abs(global_position.x - ball.global_position.x) <= 1.56 and abs(global_position.y - ball.global_position.y) <= 1:
			var kick_preds = predict_ball_locations(delta, KICK_VELOCITY * global_position.direction_to(ball.global_position), 40)
			var can_kick = true
			for pred in kick_preds:
				# If it hits the net:
				if can_kick and ball.global_position.x*I > 0 and pred.x*I > 0 and pred.x*I <= 0.46 and pred.y < 2.75:
					can_kick = false
			if can_kick:
				if kick_preds[0].y > ball.global_position.y:
					direction.y = 0
				cpu_kick(direction)
	
	%ActionSync.direction = direction
	
	var FRAMES = 10
	var txt = ""
	var curr = ball.global_position
	var vel = ball.linear_velocity
	var k = 0.5 * gravity.y * pow(delta,2)
	prev = ball_predictions[0]
	while tracker.size() <= FRAMES:
		tracker.push_back([])
	for i in range(FRAMES):
		while tracker[i].size() <= i:
			tracker[i].push_back(null)
	for i in range(FRAMES):
		if tracker[i][0]:
			txt += "" if (curr.x-tracker[i][0].x) < 0 else "+" +  str((curr.x-tracker[i][0].x))
		else:
			txt += "--"
		if not i == FRAMES - 1:
			txt += "\n"
			
	%Debug3.text = txt
	
	for i in range(FRAMES):
		for j in range(i):
			tracker[i][j] = tracker[i][j+1]
		tracker[i][i] = (ball_predictions[i] if ball_predictions.size() > i else null)
	
	visualize_predictions()
	super(delta)

func cpu_kick(direction: Vector2):
	%KickCollider.rotation.y = 90 - (90 * direction.x)
	%ActionSync.kick.rpc()

func get_direction() -> int:
	# If we have no predictions, do nothing
	if ball_predictions.is_empty():
		return 0
	
	# Pick the latest prediction
	var choice = ball_predictions.back() + Vector3(0.25,0.0,0.0)
	
	if abs(choice.x + 0.25 - self.position.x) < 0.25:
		return 0
	
	if (choice.x < self.position.x):
		return -1
	elif (choice.x == self.position.x):
		return 0
	else:
		return 1

func predict_ball_locations(delta: float, v: Vector3, n: int):
	return foresight(delta, ball.position, v, ball.get_gravity(), n)

func foresight(delta: float, p: Vector3, v: Vector3, g: Vector3, n: int) -> Array[Vector3]:
	var predictions: Array[Vector3] = []
	for i in range(0,n):
		var new_pos = p + v * delta + g * pow(delta, 2)
		
		if abs(new_pos.x) > 11.:
			v.x *= -ball.physics_material_override.bounce
		if new_pos.y > 10.:
			v.y *= -1
		
		predictions.push_back(new_pos)
		
		if new_pos.y > 1.5:
			p = new_pos
			v += g * delta
		else:
			return predictions
	return predictions

func visualize_predictions():
	for p in previews:
		p.queue_free()
		previews.erase(p)
	for i in ball_predictions + player_predictions:
		var p = $"Pred".duplicate()
		$"..".add_child(p)
		p.position = i
		previews.push_back(p)
	if ball_target:
		%Target.global_position = Vector3(ball_target[1], ball_target[2], ball_target[3])
	else:
		%Target.global_position = Vector3.ZERO

func dp(here: Vector3, target: Vector3) -> Vector3:
	return target - here

func dt(here: Vector3, target: Vector3, v: Vector3, g: Vector3) -> float:
	return max(dtx(here.x, target.x, v.x), dty(here.y, target.y, v.y, g.y))

func dtx(herex: float, targetx: float, vx: float) -> float:
	return abs(targetx - herex) / vx

func dty(herey: float, targety: float, vy: float, gy: float) -> float:
	var u2as = pow(vy,2) + (2*gy*(targety - herey))
	if u2as < 0:
		return -1
		
	var result
	for i in [-1,1]:
		var t = (u2as - vy) / gy
		if t < 0 or (result and result < t):
			continue
		result = t
	
	if result:
		return result
	return -1

func reset_intentions():
	intention = Intention.STANDBY
	actpoints = []
	ball_target = null

func counterspike(t: int, p: Vector3):
	intention = Intention.COUNTERSPIKE
	ball_target = [t, p.x, p.y, p.z]
	# Max spike time
	intention_cache = sqrt(2 * (p.y - MAX_JUMP) / get_gravity().y)

func spike():
	intention = Intention.SPIKE
	intention_cache = null

func harass(t: int, p: Vector3):
	intention = Intention.HARASS
	ball_target = [t, p.x, p.y, p.z]

func djump():
	intention_cache = [F_NET+1, intention, intention_cache, on_floor]
