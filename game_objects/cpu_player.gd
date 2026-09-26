extends Player

var ball_predictions: Array[Vector3] = []
var player_predictions: Array[Vector3] = []
var previews = []
var can_kick = true
var lined_up = false
var started = false
var time = 0.

func _ready() -> void:
	player_device = -99
	
func _physics_process(delta: float) -> void:
	super(delta)
	ball_predictions = predict_ball_locations(delta)
	
	if !started:
		return
		
	var gravity = get_gravity()
	# check through each prediction
	player_predictions = []
	for i in range(0,len(ball_predictions)):
		player_predictions.push_back(position + Vector3(0,JUMP_POWER*delta*5*(i+1)+gravity.y*(i+1)*(i+1)*delta*2.5,0))
		# see if we can get there by jumping
		var p = ball_predictions[i]
		if i>=1 and player_predictions[i].y>position.y+2. and p.y<player_predictions[i].y and p.y>player_predictions[i-1].y:
			if (on_floor and can_jump and abs(p.x-position.x)<2.):
				apply_central_impulse(Vector3(0, JUMP_POWER, 0))
				can_jump = false
				#lined_up = true
			
	if abs(position - ball.position).length() >= 1:
		can_kick = true
	if abs(position - ball.position).length() <= 1 and ball.position < position and can_kick:
		var ball = kick(7)
		if ball:
			can_kick = false

func _process(delta: float) -> void:
	pass
	for p in previews:
		p.queue_free()
		previews.erase(p)
	for i in ball_predictions + player_predictions:
		var p = $"../PredictionSpot".duplicate()
		$"..".add_child(p)
		p.position = i
		previews.push_back(p)

func is_up_pressed():
	return false
	
func get_left_right() -> float:
	
	# extra case if we are already in the right spot
	if lined_up:
		return 0
	
	# Predict and track ball
	if len(ball_predictions) == 0:
		return 0
	var choice = ball_predictions[-1] + Vector3(0.25,0.0,0.0)
	
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
	var t = delta * 5
	var predictions: Array[Vector3] = []
	for i in range(0,20):
		var new_pos = p + v * t + 0.5 * g * t * t
		
		if new_pos.x < -11.5:
			new_pos.x = -(new_pos.x + 11.5) - 11.5
		if new_pos.x > 11.5:
			new_pos.x = -(new_pos.x - 11.5) + 11.5
				
		predictions.push_back(new_pos)
		if new_pos.y > 1.5:
			t += delta * 5
		else:
			return predictions
	return predictions
	
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var input_direction = get_left_right()
	linear_velocity.x = input_direction * MOVEMENT_SPEED

	# https://forum.godotengine.org/t/how-to-check-if-rigid-body-is-on-floor/65679/3
	var i := 0
	on_floor = false
	floor = null
	while i < state.get_contact_count():
		var normal := state.get_contact_local_normal(i)
		#  1.0 would be perfectly straight up
		#  0.0 is a wall
		# -1.0 is a ceiling
		if normal.dot(Vector3.UP) > 0.3: # this can be dialed in
			floor = state.get_contact_collider_object(i)
			on_floor = true
		i += 1
