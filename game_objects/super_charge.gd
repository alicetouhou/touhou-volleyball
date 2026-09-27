extends Control


@rpc("call_local")
func set_charge(value: float):
	%ProgressBar.value = value
