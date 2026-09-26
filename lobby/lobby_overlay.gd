extends Control


@rpc("call_local")
func hide_overlay() -> void:
	print("Hiding")
	hide()
