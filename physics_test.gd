extends Node2D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	$SGRigidBody2D.move_and_slide()
	$SGRigidBody2D2.move_and_slide()
