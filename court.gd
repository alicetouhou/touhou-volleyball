extends Node3D
class_name Game

var players_turn = 1
var round_playing = false

func _ready() -> void:
	start_round()

func _on_player_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)


func _on_player_3d_on_hit_ball() -> void:
	%FxManager.create_with_parent_3D(FXManager.pressure_ring, %Ball3d)
	
	var ball_speed = %Ball3d.linear_velocity
	
	if %Ball3d.linear_velocity.length() > 10:
		%Camera3D.add_trauma(.1)
	else:
		%Camera3D.add_trauma(.05)



func _on_ball_3d_create_fx(fx: PackedScene, pos: Vector3) -> void:
	%FxManager.create_at_pos(fx, pos)

func start_round():
	%Ball3d.linear_velocity = Vector3.ZERO
	%Ball3d.angular_velocity = Vector3.ZERO
	%Player1.linear_velocity = Vector3.ZERO
	%Player2.linear_velocity = Vector3.ZERO
	%Ball3d.process_mode = Node.PROCESS_MODE_DISABLED

	if players_turn == 1:
		%Ball3d.position = %P1BallSpawnPoint.position
	if players_turn == 2:
		%Ball3d.position = %P2BallSpawnPoint.position
	
	%Player1.position = %P1SpawnPoint.position
	%Player2.position = %P2SpawnPoint.position

	await get_tree().create_timer(1).timeout

	round_playing = true

	%Ball3d.process_mode = Node.PROCESS_MODE_INHERIT

func end_round():
	if %Ball3d.position.x >= 0:
		players_turn = 1
	if %Ball3d.position.x < 0:
		players_turn = 2

	if not round_playing:
		return

	round_playing = false
	%Score.show()

	await get_tree().create_timer(.75).timeout
	%Score.hide()

	start_round()

func _on_ball_3d_body_entered(body: Node) -> void:
	if body.is_in_group("ground"):
		end_round()

func get_ball() -> RigidBody3D:
	return %Ball3d

func _on_player_1_super_used() -> void:
	Supers.run(self, %Player1)


func _on_player_2_super_used() -> void:
	Supers.run(self, %Player2)


func _on_player_1_super_charge_updated(value: float) -> void:
	%PlayerOneSuperCharge.set_charge(value)


func _on_player_2_super_charge_updated(value: float) -> void:
	%PlayerTwoSuperCharge.set_charge(value)
