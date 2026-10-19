extends Node2D

var frame = 0


func _physics_process(delta: float):
	$Label.text = str(frame)

	$SGRigidBody2D.move_and_slide()
	$BallInfo.text = "V: " + str($SGRigidBody2D.velocity.y)

func _input(event: InputEvent) -> void:
	print("apply impulse")
	$SGRigidBody2D.apply_central_impulse(SGFixed.vector2(0, -10 * SGFixed.ONE))
